//
//  ContentView.swift
//  MetalRayTracer
//
//  Created by Mykola Pokhylets on 09/01/2025.
//

import SwiftUI
import Metal
import MetalKit

struct ContentView: NSViewRepresentable {
    func makeCoordinator() -> Renderer {
        Renderer(self)
    }
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true

        if let metalDevice = MTLCreateSystemDefaultDevice() {
            mtkView.device = metalDevice
        }

        mtkView.framebufferOnly = false
        mtkView.drawableSize = mtkView.bounds.size
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // No-op
    }
}

class Renderer: NSObject, MTKViewDelegate {
    var parent: ContentView
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipeline: MTLComputePipelineState
    var accelerationStructure: any MTLAccelerationStructure
    var spheresBuffer: any MTLBuffer
    var intersectionFunctionsTable: any MTLIntersectionFunctionTable

    init(_ parent: ContentView) {

        self.parent = parent
        if let device = MTLCreateSystemDefaultDevice() {
            self.device = device
        }
        self.commandQueue = device.makeCommandQueue()

        do {
            let spheres = [
                Sphere(center: [-0.2, -0.2, -1], radius: 0.2),
                Sphere(center: [+0.2, +0.2, -1], radius: 0.2),
            ]

            // Create a primitive acceleration structure descriptor
            let accelerationStructureDescriptor = MTLPrimitiveAccelerationStructureDescriptor()

            // Create one or more bounding box geometry descriptors:
            let geometryDescriptor = MTLAccelerationStructureBoundingBoxGeometryDescriptor()

            let boundingBoxBuffer = device.makeBuffer(length: MemoryLayout<MTLAxisAlignedBoundingBox>.stride * spheres.count)!
            spheresBuffer = device.makeBuffer(length: MemoryLayout<Sphere>.stride * spheres.count)!
            var pBox = boundingBoxBuffer.contents().assumingMemoryBound(to: MTLAxisAlignedBoundingBox.self)
            var pSphere = spheresBuffer.contents().assumingMemoryBound(to: Sphere.self)
            for s in spheres {
                pSphere.pointee = s
                pSphere += 1
                pBox.pointee = s.boundingBox
                pBox += 1
            }
            geometryDescriptor.boundingBoxBuffer = boundingBoxBuffer
            geometryDescriptor.boundingBoxCount = spheres.count

            accelerationStructureDescriptor.geometryDescriptors = [ geometryDescriptor ]

            // Query for the sizes needed to store and build the acceleration structure.
            let accelSizes = device.accelerationStructureSizes(descriptor: accelerationStructureDescriptor)

            // Allocate an acceleration structure large enough for this descriptor. This method
            // doesn't actually build the acceleration structure, but rather allocates memory.
            accelerationStructure = device.makeAccelerationStructure(size: accelSizes.accelerationStructureSize)!

            // Allocate scratch space Metal uses to build the acceleration structure.
            // Use MTLResourceStorageModePrivate for the best performance because the sample
            // doesn't need access to buffer's contents.
            let scratchBuffer = device.makeBuffer(length: accelSizes.buildScratchBufferSize, options: .storageModePrivate)!

            // Create a command buffer that performs the acceleration structure build.
            let commandBuffer = commandQueue.makeCommandBuffer()!

            // Create an acceleration structure command encoder.
            let commandEncoder = commandBuffer.makeAccelerationStructureCommandEncoder()!

            commandEncoder.build(
                accelerationStructure: accelerationStructure,
                descriptor: accelerationStructureDescriptor,
                scratchBuffer: scratchBuffer,
                scratchBufferOffset: 0
            )

            commandEncoder.endEncoding()
            commandBuffer.commit()
        }

        let lib = device.makeDefaultLibrary()!
        let kernel = lib.makeFunction(name: "ray_tracing_kernel")!

        // Load functions from Metal library
        let sphereIntersectionFunction = lib.makeFunction(name: "sphereIntersectionFunction")!

        // Attach functions to ray tracing compute pipeline descriptor
        let linkedFunctions = MTLLinkedFunctions()
        linkedFunctions.functions = [ sphereIntersectionFunction ]

        let pipelineDescriptor = MTLComputePipelineDescriptor()
        pipelineDescriptor.computeFunction = kernel
        pipelineDescriptor.linkedFunctions = linkedFunctions

        self.pipeline = try! device.makeComputePipelineState(descriptor: pipelineDescriptor, options: [], reflection: nil)

        do {
            // Allocate intersection function table
            let descriptor = MTLIntersectionFunctionTableDescriptor()

            let intersectionFunctions = [sphereIntersectionFunction ]

            descriptor.functionCount = intersectionFunctions.count

            let functionTable = pipeline.makeIntersectionFunctionTable(descriptor: descriptor)!

            for i in 0 ..< intersectionFunctions.count {
                // Get a handle to the linked intersection function in the pipeline state
                let functionHandle = pipeline.functionHandle(function: intersectionFunctions[i])

                // Insert the function handle into the table
                functionTable.setFunction(functionHandle, index: i)
            }

            // Bind intersection function resources
            functionTable.setBuffer(spheresBuffer, offset: 0, index: 0)
            self.intersectionFunctionsTable = functionTable
        }

        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {

    }

    func draw(in view: MTKView) {

        guard let drawable = view.currentDrawable else {
            return
        }

        let commandBuffer = commandQueue.makeCommandBuffer()!

        let renderEncoder = commandBuffer.makeComputeCommandEncoder()!
        renderEncoder.setComputePipelineState(pipeline)
        renderEncoder.setTexture(drawable.texture, index: 0)
        renderEncoder.setAccelerationStructure(accelerationStructure, bufferIndex: 1)
        renderEncoder.setIntersectionFunctionTable(intersectionFunctionsTable, bufferIndex: 2)

        let threadGroupWidth = pipeline.threadExecutionWidth
        let threadGroupHeight = pipeline.maxTotalThreadsPerThreadgroup / threadGroupWidth
        let threadGroupSize = MTLSize(width: threadGroupWidth, height: threadGroupHeight, depth: 1)

        let gridSize = MTLSize(width: Int(view.drawableSize.width), height: Int(view.drawableSize.height), depth: 1)

        renderEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)

        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

