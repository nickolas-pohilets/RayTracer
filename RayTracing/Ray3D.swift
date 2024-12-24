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
}
