//
//  Types.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 11/01/2025.
//
import Metal

extension Sphere {
    var boundingBox: MTLAxisAlignedBoundingBox {
        let r = vector_float3(radius, radius, radius)
        return MTLAxisAlignedBoundingBox(min: center - r, max: center + r)
    }
}

extension vector_float3 {
    var asPacked: MTLPackedFloat3 {
        return MTLPackedFloat3Make(self.x, self.y, self.z)
    }
}

extension MTLAxisAlignedBoundingBox {
    init(min: vector_float3, max: vector_float3) {
        self.init(min: min.asPacked, max: max.asPacked)
    }
}
