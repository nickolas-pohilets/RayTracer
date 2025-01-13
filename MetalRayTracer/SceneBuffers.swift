//
//  SceneBuffers.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 12/01/2025.
//
import Metal

struct SceneBuffers {
    let accelerationStructure: any MTLAccelerationStructure
    let spheresBuffers: [any MTLBuffer]

    init(scene: Scene, device: MTLDevice, commandQueue: MTLCommandQueue) {
        // Create a primitive acceleration structure descriptor
        let accelerationStructureDescriptor = MTLPrimitiveAccelerationStructureDescriptor()

        var geometryDescriptors: [MTLAccelerationStructureGeometryDescriptor] = []
        var spheresBuffers: [any MTLBuffer] = []

        for group in scene.objects {
            // Create one or more bounding box geometry descriptors:
            let geometryDescriptor = MTLAccelerationStructureBoundingBoxGeometryDescriptor()

            let boundingBoxBuffer = device.makeBuffer(length: MemoryLayout<MTLAxisAlignedBoundingBox>.stride * group.count)!
            let spheresBuffer = device.makeBuffer(length: MemoryLayout<Sphere>.stride * group.count)!
            var pBox = boundingBoxBuffer.contents().assumingMemoryBound(to: MTLAxisAlignedBoundingBox.self)
            var pSphere = spheresBuffer.contents().assumingMemoryBound(to: Sphere.self)
            for obj in group {
                pSphere.pointee = obj
                pSphere += 1
                pBox.pointee = obj.boundingBox
                pBox += 1
            }
            geometryDescriptor.boundingBoxBuffer = boundingBoxBuffer
            geometryDescriptor.boundingBoxCount = group.count
            geometryDescriptor.intersectionFunctionTableOffset = spheresBuffers.count

            spheresBuffers.append(spheresBuffer)
            geometryDescriptors.append(geometryDescriptor)
        }

        self.spheresBuffers = spheresBuffers
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
