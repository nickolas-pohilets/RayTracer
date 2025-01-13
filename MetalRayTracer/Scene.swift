//
//  Scene.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 12/01/2025.
//
import Metal

struct Scene {
    var camera: CameraConfig
    var objects: [any Renderable]

    public init(camera: CameraConfig, objects: [any Renderable]) {
        self.camera = camera
        self.objects = objects
    }

    static var simpleBalls: Scene {
        let ground = Lambertian(albedo: vector_float3(0.8, 0.8, 0.0));
        let center = Lambertian(albedo: vector_float3(0.1, 0.2, 0.5));
        let left   = Dielectric(refractionIndex: 1.50);
        let right  = Metal(albedo: vector_float3(0.8, 0.6, 0.2), fuzz: 1.0);
        return Scene(
            camera: CameraConfig(),
            objects: [
                Sphere(center: [-1.0, 0.0, -1], radius: 0.5, material: left),
                Sphere(center: [0.0, 0.0, -1.2], radius: 0.5, material: center),
                Sphere(center: [+1.0, 0.0, -1], radius: 0.5, material: right),
                Sphere(center: [0, -100.5, -1], radius: 100, material: ground),
            ]
        )
    }
}

