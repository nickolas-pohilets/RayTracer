//
//  Material.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 12/01/2025.
//

public protocol Material {
    associatedtype Impl
    var asImpl: Impl { get }
}

extension Material {
    var size: Int { MemoryLayout<Impl>.stride }
    func encode(to encoder: inout MaterialEncoder) {
        encoder.write(asImpl)
    }
}

struct MaterialReserver {
    private(set) var totalSize: Int

    public init() {
        totalSize = 0
    }

    mutating func accept(_ material: some Material) {
        totalSize += material.size
    }
}

public struct MaterialEncoder {
    private var availableSize: Int
    private var pointer: UnsafeMutableRawPointer
    private var offset: Int

    init(availableSize: Int, pointer: UnsafeMutableRawPointer) {
        self.availableSize = availableSize
        self.pointer = pointer
        self.offset = 0
    }

    mutating func encode(_ material: some Material) -> Int {
        let result = offset
        let size = material.size
        precondition(size <= availableSize)
        let oldPointer = pointer
        material.encode(to: &self)
        precondition(pointer == oldPointer + size)
        availableSize -= size
        offset += size
        return result
    }

    mutating func write<T>(_ value: T) {
        pointer.assumingMemoryBound(to: T.self).pointee = value
        pointer += MemoryLayout<T>.stride
    }
}

public struct Lambertian: Material {
    public var albedo: vector_float3

    public init(albedo: vector_float3) {
        self.albedo = albedo
    }

    public var asImpl: __LambertianMaterial {
        __LambertianMaterial(kind: .material_kind_lambertian, albedo: albedo)
    }
}

public struct Metal: Material {
    public var albedo: vector_float3
    public var fuzz: Float

    public init(albedo: vector_float3, fuzz: Float) {
        assert((0...1).contains(fuzz))
        self.albedo = albedo
        self.fuzz = fuzz
    }

    public var asImpl: __MetalMaterial {
        __MetalMaterial(kind: .material_kind_metal, albedo: albedo, fuzz: fuzz)
    }
}

public struct Dielectric: Material {
    public var refractionIndex: Float

    public init(refractionIndex: Float) {
        assert(refractionIndex > 0)
        self.refractionIndex = refractionIndex
    }

    public var asImpl: __DielectricMaterial {
        __DielectricMaterial(kind: .material_kind_dielectric, refraction_index: refractionIndex)
    }
}
