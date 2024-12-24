//
//  main.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//

import Foundation


func makeGradient() -> Image {
    let imageWidth = 400
    let desiredAspectRatio = 16.0 / 9.0
    let imageHeight = max(1, Int((Double(imageWidth) / desiredAspectRatio).rounded()))

    let focalLength = 1.0
    let viewportHeight = 2.0
    let viewportWidth = viewportHeight * Double(imageWidth) / Double(imageHeight)
    let cameraCenter = Point3D.zero

    let viewportU = Vector3D(x: viewportWidth, y: 0, z: 0)
    let viewportV = Vector3D(x: 0, y: -viewportHeight, z: 0)

    let viewportCenter = cameraCenter - Vector3D(x: 0, y: 0, z: focalLength)

    var image = Image(width: imageWidth, height: imageHeight)
    for i in 0..<image.height {
        for j in 0..<image.width {
            let pixelCenter = viewportCenter
                + ((Double(i) + 0.5) / Double(imageHeight) - 0.5) * viewportV
                + ((Double(j) + 0.5) / Double(imageWidth) - 0.5) * viewportU
            let ray = Ray3D(origin: cameraCenter, target: pixelCenter, normalized: true)
            let colorF = rayColor(ray)
            image[i, j] = colorF.asU8
        }
    }
    return image
}

func rayColor(_ ray: Ray3D) -> ColorF {
    let a = 0.5 * (ray.direction.y + 1.0)
    return (1 - a) * ColorF(x: 1, y: 1, z: 1) + a * ColorF(x: 0.5, y: 0.7, z: 1.0)
}

func getURL(_ path: String) -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: path)
}

try makeGradient().writePPM(to: getURL("results/gradient.ppm"))


