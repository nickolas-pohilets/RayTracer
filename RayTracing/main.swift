//
//  main.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//

import Foundation


let ground = Lambertian(albedo: ColorF(x: 0.8, y: 0.8, z: 0.0))
let center = Lambertian(albedo: ColorF(x: 0.1, y: 0.2, z: 0.5))
let left   = Metal(albedo: ColorF(x: 0.8, y: 0.8, z: 0.8))
let right  = Metal(albedo: ColorF(x: 0.8, y: 0.6, z: 0.2))

private let world: [any Hittable] = [
    Sphere(center: Point3D(x:    0, y: -100.5, z: -1  ), radius: 100.0, material: ground),
    Sphere(center: Point3D(x:    0, y:      0, z: -1.2), radius:   0.5, material: center),
    Sphere(center: Point3D(x: -1.0, y:      0, z: -1.0), radius:   0.5, material: left),
    Sphere(center: Point3D(x: +1.0, y:      0, z: -1.0), radius:   0.5, material: right)
]

private let camera = Camera(imageWidth: 400, imageHeight: 400 * 9 / 16)
private let image = camera.render(world: world)

try image.writePPM(to: getURL("results/sphere-shiny.ppm"))

func getURL(_ path: String) -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: path)
}


