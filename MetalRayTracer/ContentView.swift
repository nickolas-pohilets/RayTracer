//
//  ContentView.swift
//  MetalRayTracer
//
//  Created by Mykola Pokhylets on 09/01/2025.
//

import SwiftUI
import Metal
import MetalKit

struct ContentView: View {
    @State var fov: Float
    // Degrees, [0, 360)
    @State var cameraYaw: Float
    // Degrees, [-90, +90]
    @State var cameraPitch: Float
    @State var cameraDistance: Float
    @State var focusDistance: Float
    @State var defocusAngle: Float

    var initialScene: Scene

    init(scene: Scene) {
        self.initialScene = scene
        let camera = scene.camera
        self.fov = camera.verticalFOV
        let relativePosition = camera.relativePosition
        self.cameraYaw = relativePosition.yaw
        self.cameraPitch = relativePosition.pitch
        self.cameraDistance = relativePosition.distance
        self.focusDistance = camera.focusDistance
        self.defocusAngle = camera.defocusAngle
    }

    var currentScene: Scene {
        var scene = initialScene
        var camera = scene.camera
        camera.verticalFOV = fov
        camera.relativePosition = .init(yaw: cameraYaw, pitch: cameraPitch, distance: cameraDistance)
        camera.defocusAngle = defocusAngle
        camera.focusDistance = focusDistance
        scene.camera = camera
        return scene
    }

    var body: some View {
        HStack {
            SceneView(scene: currentScene)
            VStack {
                Text("FOV: \(fov)")
                Slider(value: $fov, in: 1...180)
                Divider()
                Text("Yaw: \(cameraYaw)")
                Slider(value: $cameraYaw, in: -360...360)
                Divider()
                Text("Pitch: \(cameraPitch)")
                Slider(value: $cameraPitch, in: -90...90)
                Divider()
                Text("Distance: \(cameraDistance)")
                Slider(value: $cameraDistance, in: 0...20)
                Divider()
                Text("Focus Distance: \(focusDistance)")
                Slider(value: $focusDistance, in: 0.1...5)
                Divider()
                Text("Defocus Angle: \(defocusAngle)")
                Slider(value: $defocusAngle, in: 0...30)
                Spacer()
            }
            .padding()
            .frame(width: 200)
        }
    }
}

struct SceneView: NSViewRepresentable {
    var scene: Scene

    func makeCoordinator() -> Renderer {
        Renderer(scene)
    }
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        context.coordinator.view = mtkView
        mtkView.preferredFramesPerSecond = 60

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

@MainActor
class Renderer: NSObject, MTKViewDelegate {
    var view: MTKView?

    var scene: Scene {
        didSet {
            if oldValue.camera != scene.camera {
                setNeedsRedraw()
            }
        }
    }
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var sceneBuffers: SceneBuffers
    var pipeline: MTLComputePipelineState
    var intersectionFunctionsTable: any MTLIntersectionFunctionTable
    var passCounter: Int = 0
    var accumulator: MTLTexture?

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
        let functions = sceneBuffers.intersectionFunctions.mapValues { name in
            lib.makeFunction(name: name)!
        }
        let functionsTableSize = functions.keys.max().map { $0 + 1 } ?? 0

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

            self.intersectionFunctionsTable = functionTable
        }

        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.setNeedsRedraw()
    }

    @MainActor
    private func setNeedsRedraw() {
        passCounter = 0
        view?.isPaused = false
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else {
            return
        }

        passCounter += 1
        if passCounter >= 200 {
            view.isPaused = true
        }

        let commandBuffer = commandQueue.makeCommandBuffer()!

        let renderEncoder = commandBuffer.makeComputeCommandEncoder()!
        renderEncoder.setComputePipelineState(pipeline)
        let outputTexture = drawable.texture
        renderEncoder.setTexture(outputTexture, index: Int(kernel_buffers.output_texture.rawValue))
        renderEncoder.setTexture(getAccumulatorTexture(width: outputTexture.width, height: outputTexture.height), index: Int(kernel_buffers.accumulator_texture.rawValue))
        var camera = scene.camera
        renderEncoder.setBytes(&camera, length: MemoryLayout<CameraConfig>.stride, index: Int(kernel_buffers.camera_config.rawValue))
        var rng = SystemRandomNumberGenerator()
        var renderConfig = RenderConfig(samplesPerPixel: 1, maxDepth: 10, passCounter: passCounter, rngSeed: rng.next())
        renderEncoder.setBytes(&renderConfig, length: MemoryLayout<RenderConfig>.stride, index: Int(kernel_buffers.render_config.rawValue))
        renderEncoder.setAccelerationStructure(sceneBuffers.accelerationStructure, bufferIndex: Int(kernel_buffers.acceleration_structure.rawValue))
        renderEncoder.setIntersectionFunctionTable(intersectionFunctionsTable, bufferIndex: Int(kernel_buffers.function_table.rawValue))
        renderEncoder.setBuffer(sceneBuffers.materialsBuffer, offset: 0, index: Int(kernel_buffers.materials.rawValue))

        for texture in sceneBuffers.textureLoader.textures.values {
            renderEncoder.useResource(texture, usage: .read)
        }

        let threadGroupWidth = pipeline.threadExecutionWidth
        let threadGroupHeight = pipeline.maxTotalThreadsPerThreadgroup / threadGroupWidth
        let threadGroupSize = MTLSize(width: threadGroupWidth, height: threadGroupHeight, depth: 1)

        let gridSize = MTLSize(width: Int(view.drawableSize.width), height: Int(view.drawableSize.height), depth: 1)

        renderEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)

        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func getAccumulatorTexture(width: Int, height: Int) -> MTLTexture {
        if let accumulator, accumulator.width == width, accumulator.height == height {
            return accumulator
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgb10a2Uint, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        let texture = device.makeTexture(descriptor: descriptor)!
        self.accumulator = texture
        return texture
    }
}
