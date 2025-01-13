//
//  SceneBuffers.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 12/01/2025.
//
import Metal

struct SceneBuffers {
    let accelerationStructure: any MTLAccelerationStructure
    typealias Renderables = [Int: (buffer: any MTLBuffer, intersectionFunctionName: String)]
    let renderables: Renderables
    let materialsBuffer: any MTLBuffer

    init(scene: Scene, device: MTLDevice, commandQueue: MTLCommandQueue) {
        var reserver = MaterialReserver()
        for obj in scene.objects {
            obj.visitMaterials(&reserver)
        }
        materialsBuffer = device.makeBuffer(length: reserver.totalSize)!
        var encoder = MaterialEncoder(availableSize: reserver.totalSize, pointer: materialsBuffer.contents())

        var grouper = RenderableGrouper()
        for obj in scene.objects {
            grouper.add(obj, encoder: &encoder)
        }

        var geometryDescriptors: [MTLAccelerationStructureGeometryDescriptor] = []
        var renderables: Renderables = [:]
        for (kind, group) in grouper.groups {
            // Create one or more bounding box geometry descriptors:
            let (geometryDescriptor, renderablesBuffer) = group.makeBuffers(device: device)
            geometryDescriptors.append(geometryDescriptor)

            let key = Int(kind.rawValue)
            assert(renderables[key] == nil)
            renderables[key] = (renderablesBuffer, group.intersectionFunctionName)
        }
        self.renderables = renderables

        // Create a primitive acceleration structure descriptor
        let accelerationStructureDescriptor = MTLPrimitiveAccelerationStructureDescriptor()
        accelerationStructureDescriptor.geometryDescriptors = geometryDescriptors

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
}

protocol AnyRenderableGroup: AnyObject {
    var kind: RenderableKind { get }
    var intersectionFunctionName: String { get }
    func makeBuffers(device: MTLDevice) -> (geometryDescriptor: MTLAccelerationStructureBoundingBoxGeometryDescriptor, renderablesBuffer: any MTLBuffer)
}

class RenderableGroup<Impl: RenderableImpl>: AnyRenderableGroup {
    var objects: [(Impl, MTLAxisAlignedBoundingBox)] = []

    var kind: RenderableKind { Impl.kind }
    var intersectionFunctionName: String { Impl.intersectionFunctionName }

    func makeBuffers(device: MTLDevice) -> (geometryDescriptor: MTLAccelerationStructureBoundingBoxGeometryDescriptor, renderablesBuffer: any MTLBuffer) {
        let boundingBoxBuffer = device.makeBuffer(length: MemoryLayout<MTLAxisAlignedBoundingBox>.stride * objects.count)!
        let renderablesBuffer = device.makeBuffer(length: MemoryLayout<Impl>.stride * objects.count)!
        var pBox = boundingBoxBuffer.contents().assumingMemoryBound(to: MTLAxisAlignedBoundingBox.self)
        var pSphere = renderablesBuffer.contents().assumingMemoryBound(to: Impl.self)
        for (obj, box) in objects {
            pSphere.pointee = obj
            pSphere += 1
            pBox.pointee = box
            pBox += 1
        }
        let geometryDescriptor = MTLAccelerationStructureBoundingBoxGeometryDescriptor()
        geometryDescriptor.boundingBoxBuffer = boundingBoxBuffer
        geometryDescriptor.boundingBoxCount = objects.count
        geometryDescriptor.intersectionFunctionTableOffset = Int(Impl.kind.rawValue)
        return (geometryDescriptor, renderablesBuffer)
    }
}

struct RenderableGrouper {
    var groups: [RenderableKind: AnyRenderableGroup] = [:]

    mutating func add<R: Renderable>(_ renderable: R, encoder: inout MaterialEncoder) {
        let g = group(for: R.Impl.self)
        g.objects.append((renderable.asImpl(&encoder), renderable.boundingBox))
    }

    private mutating func group<Impl: RenderableImpl>(for type: Impl.Type) -> RenderableGroup<Impl> {
        if let g = groups[type.kind] {
            return g as! RenderableGroup<Impl>
        } else {
            let new = RenderableGroup<Impl>()
            groups[type.kind] = new
            return new
        }
    }
}
