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

    init(_ parent: ContentView) {

        self.parent = parent
        if let device = MTLCreateSystemDefaultDevice() {
            self.device = device
        }
        self.commandQueue = device.makeCommandQueue()

        let lib = device.makeDefaultLibrary()!
        let kernel = lib.makeFunction(name: "ray_tracing_kernel")!
        self.pipeline = try! device.makeComputePipelineState(function: kernel)

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

