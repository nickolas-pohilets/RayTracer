//
//  Material.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 12/01/2025.
//

public protocol Material {
    associatedtype Impl
    func asImpl(_ encoder: inout MaterialEncoder) -> Impl
}

extension Material {
    var size: Int { MemoryLayout<Impl>.stride }
    func encode(to encoder: inout MaterialEncoder) {
        let impl = asImpl(&encoder)
        encoder.write(impl)
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
    let textureLoader: TextureLoader

    init(availableSize: Int, pointer: UnsafeMutableRawPointer, textureLoader: TextureLoader) {
        self.availableSize = availableSize
        self.pointer = pointer
        self.offset = 0
        self.textureLoader = textureLoader
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

public struct ColoredLambertian: Material {
    public var albedo: vector_float3

    public init(albedo: vector_float3) {
        self.albedo = albedo
    }

    public func asImpl(_ encoder: inout MaterialEncoder) -> __ColoredLambertianMaterial {
        __ColoredLambertianMaterial(kind: .material_kind_lambertian_colored, albedo: albedo)
    }
}

public struct TexturedLambertian: Material {
    public var albedo: ImageTexture

    public init(albedo: ImageTexture) {
        self.albedo = albedo
    }

    public func asImpl(_ encoder: inout MaterialEncoder) -> __TexturedLambertianMaterial {
        let metalTexture = encoder.textureLoader.load(albedo)
        let texture = __ImageTexture(texture_ptr: metalTexture.gpuResourceID)
        return __TexturedLambertianMaterial(kind: .material_kind_lambertian_textured, albedo: texture)
    }
}

public struct PerlinNoiseLambertian: Material {
    public var albedo: PerlinNoiseTexture

    public init(albedo: PerlinNoiseTexture) {
        self.albedo = albedo
    }

    public func asImpl(_ encoder: inout MaterialEncoder) -> __PerlinNoiseLambertianMaterial {
        return __PerlinNoiseLambertianMaterial(kind: .material_kind_lambertian_perlin_noise, albedo: albedo)
    }
}

public struct ColoredMetal: Material {
    public var albedo: vector_float3
    public var fuzz: Float

    public init(albedo: vector_float3, fuzz: Float) {
        assert((0...1).contains(fuzz))
        self.albedo = albedo
        self.fuzz = fuzz
    }

    public func asImpl(_ encoder: inout MaterialEncoder) -> __ColoredMetalMaterial {
        __ColoredMetalMaterial(kind: .material_kind_metal_colored, albedo: albedo, fuzz: fuzz)
    }
}

public struct TexturedMetal: Material {
    public var albedo: ImageTexture
    public var fuzz: Float

    public init(albedo: ImageTexture, fuzz: Float) {
        assert((0...1).contains(fuzz))
        self.albedo = albedo
        self.fuzz = fuzz
    }

    public func asImpl(_ encoder: inout MaterialEncoder) -> __TexturedMetalMaterial {
        let metalTexture = encoder.textureLoader.load(albedo)
        let texture = __ImageTexture(texture_ptr: metalTexture.gpuResourceID)
        return __TexturedMetalMaterial(kind: .material_kind_metal_textured, albedo: texture, fuzz: fuzz)
    }
}

public struct PerlinNoiseMetal: Material {
    public var albedo: PerlinNoiseTexture
    public var fuzz: Float

    public init(albedo: PerlinNoiseTexture, fuzz: Float) {
        assert((0...1).contains(fuzz))
        self.albedo = albedo
        self.fuzz = fuzz
    }

    public func asImpl(_ encoder: inout MaterialEncoder) -> __PerlinNoiseMetalMaterial {
        return __PerlinNoiseMetalMaterial(kind: .material_kind_metal_perlin_noise, albedo: albedo, fuzz: fuzz)
    }
}

public struct Dielectric: Material {
    public var refractionIndex: Float

    public init(refractionIndex: Float) {
        assert(refractionIndex > 0)
        self.refractionIndex = refractionIndex
    }

    public func asImpl(_ encoder: inout MaterialEncoder) -> __DielectricMaterial {
        __DielectricMaterial(kind: .material_kind_dielectric, refraction_index: refractionIndex)
    }
}

public struct ColoredEmissive: Material {
    public var albedo: vector_float3

    public func asImpl(_ encoder: inout MaterialEncoder) -> __ColoredEmissiveMaterial {
        __ColoredEmissiveMaterial(kind: .material_kind_emissive_colored, albedo: albedo)
    }
}

public struct ColoredIsotropic: Material {
    public var albedo: vector_float3

    public func asImpl(_ encoder: inout MaterialEncoder) -> __ColoredIsotropicMaterial {
        __ColoredIsotropicMaterial(kind: .material_kind_isotropic_colored, albedo: albedo)
    }
}
