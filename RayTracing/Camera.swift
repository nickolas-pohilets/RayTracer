//
//  Camera.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//

import Foundation

struct Camera {
    private var imageWidth: Int
    private var imageHeight: Int
    private var cameraCenter: Point3D
    private var viewportCenter: Point3D
    private var viewportU: Vector3D
    private var viewportV: Vector3D
    private var samplesPerPixel = 100 // Count of random samples for each pixel
    private var maxDepth = 20
    private var defocusDisk: (u: Vector3D, v: Vector3D)? // Defocus disk axes

    init(
        imageWidth: Int,
        imageHeight: Int,
        verticalFOV: Double = 90,
        lookFrom: Point3D = Point3D(x: 0, y: 0, z: 0),
        lookAt: Point3D = Point3D(x: 0, y: 0, z: -1),
        up: Vector3D = Vector3D(x: 0, y: 1, z: 0),
        defocusAngle: Double = 0, // Variation angle of rays through each pixel
        focusDistance: Double? = nil
    ) {
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        let focalLength = focusDistance ?? (lookFrom - lookAt).length
        let θ = verticalFOV * .pi / 180
        let viewportHeight = 2.0 * tan(θ / 2) * focalLength
        let viewportWidth = viewportHeight * Double(imageWidth) / Double(imageHeight)
        self.cameraCenter = lookFrom

        let w = (lookFrom - lookAt).normalized()
        let u = (up ⨯ w).normalized()
        let v = w ⨯ u
        self.viewportU = viewportWidth * u
        self.viewportV = (-viewportHeight) * v
        self.viewportCenter = lookFrom - focalLength * w

        if defocusAngle > 0 {
            let defocusRadius = focalLength * tan(defocusAngle / 2 * .pi / 180)
            defocusDisk = (u: u * defocusRadius, v: v * defocusRadius)
        } else {
            defocusDisk = nil
        }
    }

    func render(world: some Hittable) -> Image {
        var image = Image(width: imageWidth, height: imageHeight)
        for i in 0..<imageHeight {
            for j in 0..<imageWidth {
                var color: ColorF = .zero
                for _ in 0..<samplesPerPixel {
                    let ray = getRay(i, j)
                    color = color + rayColor(ray, world: world, depth: maxDepth)
                }
                image[i, j] = (color / Double(samplesPerPixel)).linearToGamma() .asU8
            }
        }
        return image
    }

    private func getRay(_ i: Int, _ j: Int) -> Ray3D {
        let origin = getRayOrigin()
        let offsetX = Double.random(in: 0..<1)
        let offsetY = Double.random(in: 0..<1)
        let pixelSample = viewportCenter
            + ((Double(i) + offsetY) / Double(imageHeight) - 0.5) * viewportV
            + ((Double(j) + offsetX) / Double(imageWidth) - 0.5) * viewportU
        return Ray3D(origin: origin, target: pixelSample, normalized: true)
    }

    private func getRayOrigin() -> Vector3D {
        guard let defocusDisk else { return cameraCenter }
        let p = Vector3D.randomUnitVector2D()
        return cameraCenter + p.x * defocusDisk.u + p.y * defocusDisk.v
    }

    private func rayColor(_ ray: Ray3D, world: some Hittable, depth: Int) -> ColorF {
        if depth <= 0 {
            return .zero
        }
        if let hit = world.hit(ray: ray, range: 0.001..<Double.infinity) {
            if let (attenuation, scatered) = hit.material.scatter(ray: ray, hit: hit) {
                return attenuation * rayColor(scatered, world: world, depth: depth - 1)
            }
            return .zero
        }

        let a = 0.5 * (ray.direction.y + 1.0)
        return (1 - a) * ColorF(x: 1, y: 1, z: 1) + a * ColorF(x: 0.5, y: 0.7, z: 1.0)
    }
}
