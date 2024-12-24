//
//  Ray3D.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//

public struct Ray3D {
    public var origin: Point3D
    public var direction: Vector3D

    public subscript(_ t: Double) -> Point3D {
        return origin + direction * t
    }
}
