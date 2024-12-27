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

let c = Cylinder(
    bottomCenter: Point3D(x: 0, y: 0, z: 0),
    topCenter: Point3D(x: 0, y: 0, z: 10),
    radius: 1,
    material: Dielectric(refractionIndex: 1.5)
)
let r = 0.0 ..< Double.infinity
//print(c.hit(ray: Ray3D(origin: Point3D(x: 0, y: 0, z: -2), direction: Vector3D(x: 0, y: 0, z: 1)), range: r))
//print(c.hit(ray: Ray3D(origin: Point3D(x: 0.5, y: 0.5, z: -2), direction: Vector3D(x: 0, y: 0, z: 1)), range: r))
//print(c.hit(ray: Ray3D(origin: Point3D(x: 1, y: 1, z: -2), direction: Vector3D(x: 0, y: 0, z: 1)), range: r))
//print(c.hit(ray: Ray3D(origin: Point3D(x: -5, y: -5, z: 6), direction: Vector3D(x: 1, y: 1, z: 0)), range: r))
//print(c.hit(ray: Ray3D(origin: Point3D(x: -10, y: 0.8, z: 6), direction: Vector3D(x: 1, y: 0, z: 0)), range: r))

private let world: [any Hittable] = [
    Sphere(center: Point3D(x:    0, y: -100.5, z: -1  ), radius: 100.0, material: ground),
    Sphere(center: Point3D(x:    0, y:      0, z: -1.2), radius:   0.5, material: center),
    //Sphere(center: Point3D(x: -1.0, y:      0, z: -1.0), radius:   0.5, material: left),
    Cylinder(
        bottomCenter: Point3D(x: -1, y: 0, z: +0),
        topCenter: Point3D(x: -1, y: 0, z: -2),
        radius: 0.5,
        material: left
    ),
    Sphere(center: Point3D(x: -1.0, y:      0, z: -1.0), radius:   0.4, material: bubble),
    //Sphere(center: Point3D(x: +1.0, y:      0, z: -1.0), radius:   0.5, material: right),
    Cylinder(
        bottomCenter: Point3D(x: +1, y: -0.5, z: -1.0),
        topCenter: Point3D(x: +1, y: +0.5, z: -1.0),
        radius: 0.5,
        material: right
    )
]

private let camera = Camera(
    imageWidth: 400,
    imageHeight: 400 * 9 / 16,
    verticalFOV: 60,
    lookFrom: Point3D(x: -2, y: 2, z: 0.5),
    lookAt: Point3D(x: 0, y: 0, z: -1)
)
private let image = camera.render(world: world)

try image.writePPM(to: getURL("results/oriented.ppm"))

private func getURL(_ path: String) -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: path)
}


