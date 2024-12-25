//
//  Material.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 25/12/2024.
//

public protocol Material {
    func scatter(ray: Ray3D, hit: HitRecord) -> (attenuation: ColorF, scattered: Ray3D)?
}

public struct Lambertian: Material {
    public var albedo: ColorF

    public init(albedo: ColorF) {
        self.albedo = albedo
    }

    public func scatter(ray: Ray3D, hit: HitRecord) -> (attenuation: ColorF, scattered: Ray3D)? {
        let direction: Vector3D
        while true {
            let d = Vector3D.randomUnitVector() + hit.normal
            let lenSq = d.lengthSquared
            if lenSq > 1e-160 {
                direction = d / lenSq.squareRoot()
                break
            }
        }
        return .some((attenuation: albedo, scattered: Ray3D(origin: hit.point, direction: direction)))
    }
}

public struct Metal: Material {
    public var albedo: ColorF

    public init(albedo: ColorF) {
        self.albedo = albedo
    }

    public func scatter(ray: Ray3D, hit: HitRecord) -> (attenuation: ColorF, scattered: Ray3D)? {
        let reflected = ray.direction.reflected(normal: hit.normal)
        return .some((attenuation: albedo, scattered: Ray3D(origin: hit.point, direction: reflected)))
    }
}
