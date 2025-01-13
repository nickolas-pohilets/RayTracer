//
//  Renderable.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 12/01/2025.
//
import Metal

extension RenderableKind: Hashable {}

protocol Renderable {
    var boundingBox: MTLAxisAlignedBoundingBox { get }

    func visitMaterials(_ reserver: inout MaterialReserver)

    associatedtype Impl: RenderableImpl
    func asImpl(_ encoder: inout MaterialEncoder) -> Impl
}

extension Renderable {
    var implType: RenderableImpl.Type { Impl.self }
}

protocol RenderableImpl {
    static var intersectionFunctionName: String { get }
    static var kind: RenderableKind { get }
}

extension RenderableImpl {
    static var size: Int { MemoryLayout<Self>.stride }
}


extension __Sphere: RenderableImpl {
    static var intersectionFunctionName: String { "sphereIntersectionFunction" }
    static var kind: RenderableKind { .renderable_kind_sphere }
}

struct Sphere: Renderable {
    var center: vector_float3
    var radius: Float
    var material: any Material

    var boundingBox: MTLAxisAlignedBoundingBox {
        let r = vector_float3(radius, radius, radius)
        return MTLAxisAlignedBoundingBox(min: center - r, max: center + r)
    }

    func visitMaterials(_ reserver: inout MaterialReserver) {
        reserver.accept(material)
    }

    func asImpl(_ encoder: inout MaterialEncoder) -> __Sphere {
        let materialOffset = encoder.encode(material)
        return __Sphere(center: center, radius: radius, material_offset: materialOffset)
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
