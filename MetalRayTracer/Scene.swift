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
        let ground = ColoredLambertian(albedo: vector_float3(0.8, 0.8, 0.0));
        let center = ColoredLambertian(albedo: vector_float3(0.1, 0.2, 0.5));
        let left   = Dielectric(refractionIndex: 1.50);
        let right  = ColoredMetal(albedo: vector_float3(0.8, 0.6, 0.2), fuzz: 1.0);
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

    static var singleCylinder: Scene {
        let ground = ColoredLambertian(albedo: vector_float3(0.5, 0.8, 0.0))
        return Scene(
            camera: CameraConfig(),
            objects: [
                Cylinder(
                    transform: .translation(0, 0, -1) * .rotation(degrees: 15, axis: .x),
                    radius: 0.2,
                    height: 0.5,
                    material: ground
                )
            ]
        )
    }

    static var simpleCylinders: Scene {
        let ground = ColoredLambertian(albedo: vector_float3(0.8, 0.8, 0.0));
        let center = ColoredLambertian(albedo: vector_float3(0.1, 0.2, 0.5));
        let left   = Dielectric(refractionIndex: 1.50);
        let right  = ColoredMetal(albedo: vector_float3(0.8, 0.6, 0.2), fuzz: 0.1);
        return Scene(
            camera: CameraConfig(),
            objects: [
                Cylinder(
                    transform: .translation(-0.5, 0, -1) * .rotation(degrees: 90, axis: .x) * .translation(0, -0.3, 0),
                    radius: 0.2,
                    height: 0.6,
                    material: left
                ),
                Cylinder(
                    transform: .translation(0, -0.2, -1.2),
                    radius: 0.2,
                    height: 0.4,
                    material: center
                ),
                Cylinder(
                    transform: .translation(+0.5, 0, -1) * .rotation(degrees: 90, axis: .z) * .translation(0, -0.2, 0),
                    radius: 0.2,
                    height: 0.4,
                    material: right
                ),
                Sphere(center: [0, -100.5, -1], radius: 100, material: ground),
            ]
        )
    }

    static var texturedCylinders: Scene {
        let ground = ColoredLambertian(albedo: vector_float3(1.8, 1.8, 1.0));
        let left   = Dielectric(refractionIndex: 1.50);
        let right  = ColoredMetal(albedo: vector_float3(0.8, 0.6, 0.2), fuzz: 0.1);
        return Scene(
            camera: CameraConfig(),
            objects: [
                Cylinder(
                    transform: .translation(-0.5, 0, -1) * .rotation(degrees: 90, axis: .x) * .translation(0, -0.3, 0),
                    radius: 0.2,
                    height: 0.6,
                    material: left
                ),
                Cylinder(
                    transform: .translation(0, -0.2, -1.2),
                    radius: 0.2,
                    height: 0.4,
                    bottom: TexturedLambertian(albedo: ImageTexture(name: "barrel-bottom.jpg")),
                    top: TexturedLambertian(albedo: ImageTexture(name: "barrel-top.jpg")),
                    side: TexturedLambertian(albedo: ImageTexture(name: "barrel-side.jpg"))
                ),
                Sphere(
                    center: [0, 0.8, -1.2],
                    radius: 0.3,
                    material: TexturedLambertian(albedo: ImageTexture(name: "earthmap.jpg"))
                ),
                Cylinder(
                    transform: .translation(+0.5, 0, -1) * .rotation(degrees: 90, axis: .z) * .translation(0, -0.2, 0),
                    radius: 0.2,
                    height: 0.4,
                    material: right
                ),
                Sphere(
                    center: [0, -100.5, -1],
                    radius: 100,
                    material: ground
                ),
            ]
        )
    }

    static var pencilInGlass: Scene {
        let ground = ColoredLambertian(albedo: vector_float3(0.8, 0.8, 0.0))
        let center = ColoredLambertian(albedo: vector_float3(0.1, 0.2, 0.5))
//        let left   = Dielectric(refractionIndex: 1.5)
//        let bubble = Dielectric(refractionIndex: 1/1.5)
//        let right  = ColoredMetal(albedo: vector_float3(0.8, 0.6, 0.2), fuzz: 0.2)

        let glass = Subtract(
            lhs: Cylinder(
                bottomCenter: vector_float3(0, 0, 0),
                topCenter: vector_float3(0, 12, 0),
                radius: 4,
                material: Dielectric(refractionIndex: 1.5)
            ),
            rhs: Cylinder(
                bottomCenter: vector_float3(0, 1, 0),
                topCenter: vector_float3(0, 13, 0),
                radius: 3.5,
                material: Dielectric(refractionIndex: 1.5)
            )
        )


        let water = Cylinder(
            bottomCenter: vector_float3(0, 1.001, 0),
            topCenter: vector_float3(0, 8, 0),
            radius: 3.5-0.001,
            material: Dielectric(refractionIndex: 1.33)
        )

        let alpha = Float(Double.pi / 6)
        let p1 = vector_float3(-3.4 * cos(alpha), 1.1, -3.4*sin(alpha))
        let p2 = vector_float3(0, 12, 3.4)
        let p3 = p1 + (p2 - p1) * (13.0/11.0)

        let pencil = Cylinder(
            bottomCenter: p1,
            topCenter: p3,
            radius: 0.1,
            material: center
        )

        return Scene(
            camera: CameraConfig(
                verticalFOV: 60,
                lookFrom: vector_float3(-15, 14, 0),
                lookAt: vector_float3(8, 3, 0)
            ),
            objects: [
                Sphere(center: vector_float3(0, -500.5, -1), radius: 500.0, material: ground),
                glass,
                water,
                pencil
            ]
        )
    }

    static var compositionDemo: Scene {
        let ground = ColoredLambertian(albedo: vector_float3(0.5, 0.5, 0.5))

        let red = ColoredLambertian(albedo: vector_float3(1, 0, 0))
        let green = ColoredLambertian(albedo: vector_float3(0, 1, 0))
        let blue = ColoredLambertian(albedo: vector_float3(0, 0, 1))

        let box = Cuboid(
            transform: .translation(-1, -1, -1),
            size: vector_float3(2, 2, 2),
            material: red
        )
        let sphere = Sphere(center: .zero, radius: 1.3, material: blue)
        let cyl1  = Cylinder(transform: .translation(0, -2, 0), radius: 0.55, height: 4, material: green)
        let cyl2  = Cylinder(transform: .rotation(degrees: 90, axis: .x) * .translation(0, -2, 0), radius: 0.55, height: 4, material: green)
        let cyl3  = Cylinder(transform: .rotation(degrees: 90, axis: .z) * .translation(0, -2, 0), radius: 0.55, height: 4, material: green)

        let object = Subtract(
            lhs: Intersection(box, sphere),
            rhs: Union(cyl1, cyl2, cyl3)
        )

        return Scene(
            camera: CameraConfig(
                verticalFOV: 90,
                lookFrom: vector_float3(3, 3, 3),
                lookAt: vector_float3(0, 0, 0)
            ),
            objects: [
                Sphere(center: vector_float3(0, -501, -1), radius: 500.0, material: ground),
                object,
            ]
        )
    }
}

