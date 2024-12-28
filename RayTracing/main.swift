//
//  main.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//

import Foundation

private let ground = Lambertian(albedo: ColorF(x: 0.8, y: 0.8, z: 0.0))
private let center = Lambertian(albedo: ColorF(x: 0.1, y: 0.2, z: 0.5))
private let left   = Dielectric(refractionIndex: 1.5)
private let bubble = Dielectric(refractionIndex: 1/1.5)
private let right  = Metal(albedo: ColorF(x: 0.8, y: 0.6, z: 0.2), fuzz: 0.2)


private let glass = Composition(
    operation: .subtract,
    items: [
        Cylinder(
            bottomCenter: Point3D(x: 0, y: 0, z: 0),
            topCenter: Point3D(x: 0, y: 12, z: 0),
            radius: 4,
            material: Dielectric(refractionIndex: 1.5)
        ),
        Cylinder(
            bottomCenter: Point3D(x: 0, y: 1, z: 0),
            topCenter: Point3D(x: 0, y: 13, z: 0),
            radius: 3.5,
            material: Dielectric(refractionIndex: 1.5)
        )
    ]
)

private let water = Cylinder(
    bottomCenter: Point3D(x: 0, y: 1.001, z: 0),
    topCenter: Point3D(x: 0, y: 8, z: 0),
    radius: 3.5-0.001,
    material: Dielectric(refractionIndex: 1.33)
)

let alpha = Double.pi / 6

let p1 = Point3D(x: -3.4 * cos(alpha), y: 1.1, z: -3.4*sin(alpha))
let p2 = Point3D(x: 0, y: 12, z: 3.4)
let p3 = p1 + (p2 - p1) * (13.0/11.0)

private let pencil = Cylinder(
    bottomCenter: p1,
    topCenter: p3,
    radius: 0.1,
    material: center
)


let r = 0.0 ..< Double.infinity
//print(c.hit(ray: Ray3D(origin: Point3D(x: 0, y: 0, z: -2), direction: Vector3D(x: 0, y: 0, z: 1)), range: r))
//print(c.hit(ray: Ray3D(origin: Point3D(x: 0.5, y: 0.5, z: -2), direction: Vector3D(x: 0, y: 0, z: 1)), range: r))
//print(c.hit(ray: Ray3D(origin: Point3D(x: 1, y: 1, z: -2), direction: Vector3D(x: 0, y: 0, z: 1)), range: r))
//print(c.hit(ray: Ray3D(origin: Point3D(x: -5, y: -5, z: 6), direction: Vector3D(x: 1, y: 1, z: 0)), range: r))
//print(c.hit(ray: Ray3D(origin: Point3D(x: -10, y: 0.8, z: 6), direction: Vector3D(x: 1, y: 0, z: 0)), range: r))


//let water: Double = 1.33
//let glass: Double = 1.5

private let world: [any Hittable] = [
//    Cylinder(
//        bottomCenter: Point3D(x: 0, y: 0, z: 0),
//        topCenter: Point3D(x: 0, y: 10, z: 0),
//        radius: 2,
//        material: Dielectric(refractionIndex: glass)
//    ),
//    Cylinder(
//        bottomCenter: Point3D(x: 0, y: 0.5, z: 0),
//        topCenter: Point3D(x: 0, y: 6, z: 0),
//        radius: 1.5,
//        material: Dielectric(refractionIndex: glass)
//    ),
    Sphere(center: Point3D(x:    0, y: -500.5, z: -1  ), radius: 500.0, material: ground),
    glass,
    water,
    pencil
//    Sphere(center: Point3D(x:    0, y:  7.5, z: 0), radius:   2, material: center),
//    Sphere(center: Point3D(x: -1.0, y:      0, z: -1.0), radius:   0.5, material: left),
//    Cylinder(
//        bottomCenter: Point3D(x: -1, y: 0, z: +0),
//        topCenter: Point3D(x: -1, y: 0, z: -2),
//        radius: 0.5,
//        material: left
//    ),
//    Sphere(center: Point3D(x: -1.0, y:      0, z: -1.0), radius:   0.4, material: bubble),
//    Sphere(center: Point3D(x: +1.0, y:      0, z: -1.0), radius:   0.5, material: right),
//    Cylinder(
//        bottomCenter: Point3D(x: +1, y: -0.5, z: -1.0),
//        topCenter: Point3D(x: +1, y: +0.5, z: -1.0),
//        radius: 0.5,
//        material: right
//    )
]

private let camera = Camera(
    imageWidth: 200,
    imageHeight: 225,
    verticalFOV: 60,
    lookFrom: Point3D(x: -15, y: 14, z: 0),
    lookAt: Point3D(x: 8, y: 3, z: 0)
)
private let image = camera.render(world: world)

try image.writePPM(to: getURL("results/glass-pencil.ppm"))

private func getURL(_ path: String) -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: path)
}


