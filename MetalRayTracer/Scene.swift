//
//  Scene.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 12/01/2025.
//
import Metal

struct Scene {
    var camera: CameraConfig
    var objects: [[Sphere]] // TODO: Handle heterogeneous objects

    static var simpleBalls: Scene {
        Scene(
            camera: CameraConfig(),
            objects: [
                [
                    Sphere(center: [-0.25, 0.4, -1], radius: 0.2),
                    Sphere(center: [+0.25, 0.4, -1], radius: 0.2),
                ],
                [
                    Sphere(center: [-0.25, 0.0, -1], radius: 0.2),
                    Sphere(center: [+0.25, 0.0, -1], radius: 0.2),
                ],
                [
                    Sphere(center: [0, -100.2, -1], radius: 100),
                ]
            ]
        )
    }
}

protocol Renderable {
    var boundingBox: MTLAxisAlignedBoundingBox { get }
}
