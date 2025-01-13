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
        var functions = sceneBuffers.renderables.mapValues { r in
            lib.makeFunction(name: r.intersectionFunctionName)!
        }
        var functionsTableSize = functions.keys.max().map { $0 + 1 } ?? 0

        // Attach functions to ray tracing compute pipeline descriptor
        let linkedFunctions = MTLLinkedFunctions()
        linkedFunctions.functions = Array(functions.values)

        let pipelineDescriptor = MTLComputePipelineDescriptor()
        pipelineDescriptor.computeFunction = kernel
        pipelineDescriptor.linkedFunctions = linkedFunctions

        self.pipeline = try! device.makeComputePipelineState(descriptor: pipelineDescriptor, options: [], reflection: nil)

        do {
            // Allocate intersection function table
            let descriptor = MTLIntersectionFunctionTableDescriptor()
            descriptor.functionCount = functionsTableSize

            let functionTable = pipeline.makeIntersectionFunctionTable(descriptor: descriptor)!
            for i in 0..<functionsTableSize {
                guard let f = functions[i] else { continue }
                // Get a handle to the linked intersection function in the pipeline state
                let functionHandle = pipeline.functionHandle(function: f)

                // Insert the function handle into the table
                functionTable.setFunction(functionHandle, index: i)
            }

            // Bind intersection function resources
            for (index, r) in sceneBuffers.renderables {
                functionTable.setBuffer(r.buffer, offset: 0, index: index)
            }

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
        renderEncoder.setTexture(drawable.texture, index: Int(kernel_buffers.output_texture.rawValue))
        var camera = scene.camera
        renderEncoder.setBytes(&camera, length: MemoryLayout<CameraConfig>.stride, index: Int(kernel_buffers.camera_config.rawValue))
        var renderConfig = RenderConfig(samplesPerPixel: 20, maxDepth: 20)
        renderEncoder.setBytes(&renderConfig, length: MemoryLayout<RenderConfig>.stride, index: Int(kernel_buffers.render_config.rawValue))
        renderEncoder.setAccelerationStructure(sceneBuffers.accelerationStructure, bufferIndex: Int(kernel_buffers.acceleration_structure.rawValue))
        renderEncoder.setIntersectionFunctionTable(intersectionFunctionsTable, bufferIndex: Int(kernel_buffers.function_table.rawValue))
        renderEncoder.setBuffer(sceneBuffers.materialsBuffer, offset: 0, index: Int(kernel_buffers.materials.rawValue))

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

