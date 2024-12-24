//
//  main.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//

import Foundation

let world: [any Hittable] = [
    Sphere(center: Point3D(x: 0, y: 0, z: -1), radius: 0.5),
    Sphere(center: Point3D(x: 0, y: -100.5, z: -1), radius: 100)
]

let camera = Camera(imageWidth: 400, imageHeight: 400 * 9 / 16)
let image = camera.render(world: world)

try image.writePPM(to: getURL("results/sphere-normals.ppm"))

func getURL(_ path: String) -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: path)
}


