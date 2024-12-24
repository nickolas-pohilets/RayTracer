//
//  Hittable.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//

public struct HitRecord {
    var point: Point3D
    var normal: Vector3D
    var t: Double

}

public protocol Hittable {
    func hit(ray: Ray3D, range: Range<Double>) -> HitRecord?
}

public struct Sphere: Hittable {
    var center: Point3D
    var radius: Double

    public init(center: Point3D, radius: Double) {
        self.center = center
        self.radius = radius
    }

    public func hit(ray: Ray3D, range: Range<Double>) -> HitRecord? {
        // P = ray[t]
        // (ray.origin + ray.direction * t - C) • (ray.origin + ray.direction * t - C) = radius²
        // (ray.direction * t + (ray.origin - C)) • (ray.direction * t + (ray.origin - C)) = radius²
        // (ray.direction * t + (ray.origin - C)) • (ray.direction * t + (ray.origin - C)) = radius²
        // t² * ray.direction • ray.direction + t * (2 * ray.direction • (ray.origin - C)) + (ray.origin - C) • (ray.origin - C) - radius² = 0
        let oc = ray.origin - center
        let a = ray.direction • ray.direction
        let b_2 = ray.direction • oc
        let c = oc • oc - radius * radius
        let D_4 = b_2 * b_2 - a * c
        if D_4 < 0 { return nil }
        let t = (-b_2 - D_4.squareRoot()) / a
        let point = ray[t]
        let normal = (point - center) / radius
        return HitRecord(point: point, normal: normal, t: t)
    }
}
