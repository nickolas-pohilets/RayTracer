//
//  Camera.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//

import Foundation

public struct Camera {
    public struct RenderConfig {
        var samplesPerPixel: Int // Count of random samples for each pixel
        var maxDepth: Int

        public init(samplesPerPixel: Int = 10, maxDepth: Int = 10) {
            self.samplesPerPixel = samplesPerPixel
            self.maxDepth = maxDepth
        }
    }

    private var imageWidth: Int
    private var imageHeight: Int
    private var cameraCenter: Point3D
    private var viewportCenter: Point3D
    private var viewportU: Vector3D
    private var viewportV: Vector3D
    private var defocusDisk: (u: Vector3D, v: Vector3D)? // Defocus disk axes

    public init(
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

    public func render(world: some Hittable, config: RenderConfig = .init()) async -> Image {
        var image = Image(width: imageWidth, height: imageHeight)
        await withTaskGroup(of: (Int, Image).self) { group in
            var rng = SystemRandomNumberGenerator()
            for i in 0..<imageHeight {
                let seed = rng.next()
                group.addTask {
                    let rowImage = self.render(row: i, seed: seed, world: world, config: config)
                    return (i, rowImage)
                }
            }
            for await (index, rowImage) in group {
                for j in 0..<imageWidth {
                    image[index, j] = rowImage[0, j]
                }
            }
        }
        return image
    }

    private func render(row i: Int, seed: UInt64, world: some Hittable, config: RenderConfig) -> Image {
        var rng = WyRand(seed: seed)
        var image = Image(width: imageWidth, height: 1)
        for j in 0..<imageWidth {
            var color: ColorF = .zero
            for _ in 0..<config.samplesPerPixel {
                let ray = getRay(i, j, using: &rng)
                let time = Double.random(in: 0...1, using: &rng)
                color = color + rayColor(ray, time: time, world: world, depth: config.maxDepth, using: &rng)
            }
            image[0, j] = (color / Double(config.samplesPerPixel)).linearToGamma() .asU8
        }
        return image
    }

    private func getRay(_ i: Int, _ j: Int, using rng: inout some RandomNumberGenerator) -> Ray3D {
        let origin = getRayOrigin(using: &rng)
        let offsetX = Double.random(in: 0..<1, using: &rng)
        let offsetY = Double.random(in: 0..<1, using: &rng)
        let pixelSample = viewportCenter
            + ((Double(i) + offsetY) / Double(imageHeight) - 0.5) * viewportV
            + ((Double(j) + offsetX) / Double(imageWidth) - 0.5) * viewportU
        return Ray3D(origin: origin, target: pixelSample, normalized: true)
    }

    private func getRayOrigin(using rng: inout some RandomNumberGenerator) -> Vector3D {
        guard let defocusDisk else { return cameraCenter }
        let p = Vector3D.randomUnitVector2D(using: &rng)
        return cameraCenter + p.x * defocusDisk.u + p.y * defocusDisk.v
    }

    private func rayColor(_ ray: Ray3D, time: Double, world: some Hittable, depth: Int, using rng: inout some RandomNumberGenerator) -> ColorF {
        if depth <= 0 {
            return .zero
        }
        if let hit = world.hit(ray: ray, time: time, range: 0.001..<Double.infinity) {
            if let (attenuation, scatered) = hit.material.scatter(ray: ray, hit: hit, using: &rng) {
                return attenuation * rayColor(scatered, time: time, world: world, depth: depth - 1, using: &rng)
            }
            return .zero
        }

        let a = 0.5 * (ray.direction.y + 1.0)
        return (1 - a) * ColorF(x: 1, y: 1, z: 1) + a * ColorF(x: 0.5, y: 0.7, z: 1.0)
    }
}
