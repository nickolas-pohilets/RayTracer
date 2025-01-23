//
//  SceneBuffers.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 12/01/2025.
//
import Metal

struct SceneBuffers {
    let accelerationStructure: any MTLAccelerationStructure
    let intersectionFunctions: [Int: String]
    let materialsBuffer: any MTLBuffer
    let textureLoader: TextureLoader

    init(scene: Scene, device: MTLDevice, commandQueue: MTLCommandQueue) {
        var reserver = MaterialReserver()
        for obj in scene.objects {
            obj.visitMaterials(&reserver)
        }
        textureLoader = TextureLoader(device: device)
        materialsBuffer = device.makeBuffer(length: reserver.totalSize)!
        var encoder = MaterialEncoder(availableSize: reserver.totalSize, pointer: materialsBuffer.contents(), textureLoader: textureLoader)

        var grouper = RenderableGrouper()
        for obj in scene.objects {
            grouper.add(obj, encoder: &encoder)
        }

        var geometryDescriptors: [MTLAccelerationStructureGeometryDescriptor] = []
        var intersectionFunctions: [Int: String] = [:]
        for group in grouper.groups.values {
            // Create one or more bounding box geometry descriptors:
            let geometryDescriptor = group.makeGeometryDescriptor(device: device)
            geometryDescriptors.append(geometryDescriptor)

            assert(intersectionFunctions[group.index] == nil)
            intersectionFunctions[group.index] = group.intersectionFunctionName
        }
        self.intersectionFunctions = intersectionFunctions

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
    var index: Int { get }
    var intersectionFunctionName: String { get }
    func makeGeometryDescriptor(device: MTLDevice) -> MTLAccelerationStructureBoundingBoxGeometryDescriptor
}

class RenderableGroup<Impl: RenderableImpl>: AnyRenderableGroup {
    var index: Int
    var objects: [(Impl, MTLAxisAlignedBoundingBox)] = []

    init(index: Int) {
        self.index = index
    }

    var intersectionFunctionName: String { Impl.intersectionFunctionName }

    func makeGeometryDescriptor(device: MTLDevice) -> MTLAccelerationStructureBoundingBoxGeometryDescriptor {
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
        geometryDescriptor.primitiveDataBuffer = renderablesBuffer
        geometryDescriptor.primitiveDataStride = MemoryLayout<Impl>.stride
        geometryDescriptor.primitiveDataElementSize = MemoryLayout<Impl>.size
        geometryDescriptor.intersectionFunctionTableOffset = index
        return geometryDescriptor
    }
}

struct RenderableGrouper {
    var groups: [ObjectIdentifier: AnyRenderableGroup] = [:]

    mutating func add<R: Renderable>(_ renderable: R, encoder: inout MaterialEncoder) {
        let g = group(for: R.Impl.self)
        g.objects.append((renderable.asImpl(&encoder), renderable.boundingBox))
    }

    private mutating func group<Impl: RenderableImpl>(for type: Impl.Type) -> RenderableGroup<Impl> {
        let key = ObjectIdentifier(type)
        if let g = groups[key] {
            return g as! RenderableGroup<Impl>
        } else {
            let new = RenderableGroup<Impl>(index: groups.count)
            groups[key] = new
            return new
        }
    }
}
