//
//  Hittable.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//

public enum Face {
    case front
    case back
}

public struct HitRecord {
    var point: Point3D
    var normal: Vector3D
    var t: Double
    var face: Face
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
        if !range.contains(t) { return nil }
        let point = ray[t]
        var normal = (point - center) / radius
        var face: Face = .front
        if normal • ray.direction > 0 {
            normal = -normal
            face = .back
        }
        return HitRecord(point: point, normal: normal, t: t, face: face)
    }
}

extension Array: Hittable where Element == any Hittable {
    public func hit(ray: Ray3D, range: Range<Double>) -> HitRecord? {
        var result: HitRecord?
        for item in self {
            let itemRange = range.lowerBound..<(result?.t ?? range.upperBound)
            if let hit = item.hit(ray: ray, range: itemRange) {
                result = hit
            }
        }
        return result
    }
}
