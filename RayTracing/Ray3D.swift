//
//  Ray3D.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//

public struct Ray3D {
    public var origin: Point3D
    public var direction: Vector3D

    public init(origin: Point3D, direction: Vector3D) {
        self.origin = origin
        self.direction = direction
    }

    public init(origin: Point3D, target: Point3D, normalized: Bool = false) {
        self.origin = origin
        let dir = (target - origin)
        self.direction = normalized ? dir.normalized() : dir
    }

    public subscript(_ t: Double) -> Point3D {
        return origin + direction * t
    }

    func projection(of point: Point3D) -> Point3D {
        // dist² = |(o - p) + d * t|²
        // dist² = (o - p)² + 2d • (o - p)*t + d²t²
        // d(dist²)/dt = 2d • (o - p) + 2d²t
        // set to 0 to find shortest distance
        // t = d • (p - o) / d²
        let t = direction • (point - origin) / direction.lengthSquared
        return self[t]
    }

    func distance(to point: Point3D) -> Double {
        return distanceSquared(to: point).squareRoot()
    }

    func distanceSquared(to point: Point3D) -> Double {
        return (point - projection(of: point)).lengthSquared
    }
}
