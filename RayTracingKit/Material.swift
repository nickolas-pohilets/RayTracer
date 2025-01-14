//
//  Material.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 25/12/2024.
//

public protocol Material {
    func emitted(textureCoordinates: Point2D, point: Point3D) -> ColorF
    func scatter(ray: Ray3D, hit: HitRecord, using rng: inout some RandomNumberGenerator) -> (attenuation: ColorF, scattered: Ray3D)?
}

extension Material {
    public func emitted(textureCoordinates: Point2D, point: Point3D) -> ColorF { .zero }
}

public struct Lambertian: Material {
    public var texture: any Texture

    public init(albedo: ColorF) {
        self.texture = SolidColor(albedo: albedo)
    }

    public init(texture: any Texture) {
        self.texture = texture
    }

    public func scatter(ray: Ray3D, hit: HitRecord, using rng: inout some RandomNumberGenerator) -> (attenuation: ColorF, scattered: Ray3D)? {
        let direction: Vector3D
        while true {
            let d = Vector3D.randomUnitVector(using: &rng) + hit.normal
            let lenSq = d.lengthSquared
            if lenSq > 1e-160 {
                direction = d / lenSq.squareRoot()
                break
            }
        }
        let albedo = texture[hit.textureCoordinates, point: hit.point]
        return .some((attenuation: albedo, scattered: Ray3D(origin: hit.point, direction: direction)))
    }
}

public struct Metal: Material {
    public var albedo: ColorF
    public var fuzz: Double

    public init(albedo: ColorF, fuzz: Double) {
        assert((0...1).contains(fuzz))
        self.albedo = albedo
        self.fuzz = fuzz
    }

    public func scatter(ray: Ray3D, hit: HitRecord, using rng: inout some RandomNumberGenerator) -> (attenuation: ColorF, scattered: Ray3D)? {
        let reflected = ray.direction.reflected(normal: hit.normal).normalized() + fuzz * Vector3D.randomUnitVector(using: &rng)
        if reflected • hit.normal <= 0 { return nil }
        return .some((attenuation: albedo, scattered: Ray3D(origin: hit.point, direction: reflected)))
    }
}

public struct Dielectric: Material {
    public var refractionIndex: Double

    public init(refractionIndex: Double) {
        assert(refractionIndex > 0)
        self.refractionIndex = refractionIndex
    }

    public func scatter(ray: Ray3D, hit: HitRecord, using rng: inout some RandomNumberGenerator) -> (attenuation: ColorF, scattered: Ray3D)? {
        let ηRatio = hit.face == .front ? 1.0 / refractionIndex : refractionIndex
        let refracted = ray.direction.normalized().refractedOrReflected(normal: hit.normal, ηRatio: ηRatio, reflectanceRandom: .random(in: 0..<1, using: &rng))
        return .some((attenuation: ColorF(x: 1.0, y: 1.0, z: 1.0), scattered: Ray3D(origin: hit.point, direction: refracted)))
    }
}

public struct Emissive: Material {
    public var texture: any Texture

    public init(albedo: ColorF) {
        self.texture = SolidColor(albedo: albedo)
    }

    public init(texture: any Texture) {
        self.texture = texture
    }

    public func emitted(textureCoordinates: Point2D, point: Point3D) -> ColorF {
        return texture[textureCoordinates, point: point]
    }

    public func scatter(ray: Ray3D, hit: HitRecord, using rng: inout some RandomNumberGenerator) -> (attenuation: ColorF, scattered: Ray3D)? {
        return nil
    }
}
