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
    var scene: Scene

    func makeCoordinator() -> Renderer {
        Renderer(scene)
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
        context.coordinator.scene = scene
        nsView.setNeedsDisplay(nsView.bounds)
    }
}

class Renderer: NSObject, MTKViewDelegate {
    var scene: Scene
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var sceneBuffers: SceneBuffers
    var pipeline: MTLComputePipelineState
    var intersectionFunctionsTable: any MTLIntersectionFunctionTable

    init(_ scene: Scene) {

        self.scene = scene
        if let device = MTLCreateSystemDefaultDevice() {
            self.device = device
        }
        self.commandQueue = device.makeCommandQueue()

        sceneBuffers = SceneBuffers(scene: scene, device: device, commandQueue: commandQueue)

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
            functionTable.setBuffer(sceneBuffers.spheresBuffer, offset: 0, index: 0)
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
        var camera = scene.camera
        renderEncoder.setBytes(&camera, length: MemoryLayout<CameraConfig>.stride, index: 1)
        var renderConfig = RenderConfig(samplesPerPixel: 20, maxDepth: 20)
        renderEncoder.setBytes(&renderConfig, length: MemoryLayout<RenderConfig>.stride, index: 2)
        renderEncoder.setAccelerationStructure(sceneBuffers.accelerationStructure, bufferIndex: 3)
        renderEncoder.setIntersectionFunctionTable(intersectionFunctionsTable, bufferIndex: 4)

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

