//
//  main.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//

import Foundation
import RayTracingKit

func makeWorld1() throws -> some Hittable {
    var w: [any Hittable] = []

    let ground = Lambertian(albedo: ColorF(x: 0.5, y: 0.5, z: 0.5))
    w.append(Sphere(center: Point3D(x: 0, y: -1000, z: 0), radius: 1000, material: ground))

    let material1 = Dielectric(refractionIndex: 1.5)
    w.append(Sphere(center: Point3D(x: 0, y: 1, z: 0), radius: 1.0, material: material1))

    do {
        let image = try Image.load(url: getURL("textures/earthmap.jpg"))
        let material2 = Lambertian(texture: ImageTexture(image: image))
        let sphere = Sphere(center: .zero, radius: 1.0, material: material2)
        let t1 = Transformed(
            transform: .rotation(degrees: 23, axis: .z) * .rotation(degrees: 190, axis: .y),
            base: sphere
        )
        let t2 = Transformed(transform: .translation(x: -4, y: 1, z: 0), base: t1)
        w.append(t2)
    }

    let material3 = Metal(albedo: ColorF(x: 0.7, y: 0.6, z: 0.5), fuzz: 0.0)
    w.append(Sphere(center: Point3D(x: 4, y: 1, z: 0), radius: 1.0, material: material3))

    do {
        let image = try Image.load(url: getURL("textures/barrel.jpg"))
        let top = Lambertian(texture: ImageTexture(image: image, originX: 128, originY: 320, width: 192, height: 192))
        let bottom = Lambertian(texture: ImageTexture(image: image, originX: 320, originY: 320, width: 192, height: 192))
        let side = Lambertian(texture: ImageTexture(image: image, originX: 0, originY: 320, width: 512, height: -320))
        let c = Cylinder(radius: 0.5, height: 2, bottom: bottom, top: top, side: side)
        let t1 = Transformed(transform: .translation(x: 0, y: 0, z: 3), base: c)
        w.append(t1)
        let t2 = Transformed(transform: .translation(x: -1.2, y: 0, z: 2.7) * .rotation(degrees: 115, axis: .y), base: c)
        w.append(t2)
        let t3 = Transformed(
            transform: .translation(x: -1.7, y: 0.5, z: 3.5)
                        * .rotation(degrees: -30, axis: .y)
                        * .rotation(degrees: -90, axis: .z)
                        * .rotation(degrees: 90, axis: .y),
            base: c
        )
        w.append(t3)
    }

    return BoundingVolumeNode(items: w)
}

func makeCamera1() -> Camera {
    let imageWidth = 400
    return Camera(
        imageWidth: imageWidth,
        imageHeight: imageWidth * 9 / 16,
        verticalFOV: 20,
        lookFrom: Point3D(x: -10, y: 6, z: 8),
        lookAt: Point3D(x: 0, y: 0, z: 0),
        defocusAngle: 0.6,
        focusDistance: 10
    )
}

func makeWorld2() throws -> some Hittable {
    var w: [any Hittable] = []

    var rng = SystemRandomNumberGenerator()
    let noiseTex = NoiseTexture(noise: PerlinNoise(using: &rng), scale: 1.0)
    let marbleTex = Marble(noise: PerlinNoise(using: &rng), scale: 1.0)
    w.append(Sphere(center: Point3D(x: 0, y: -1000, z: 0), radius: 1000, material: Lambertian(texture: noiseTex)))
    w.append(Sphere(center: Point3D(x: 0, y: 2, z: 0), radius: 2, material: Lambertian(texture: marbleTex)))
    return BoundingVolumeNode(items: w)
}

func makeCamera2() -> Camera {
    Camera(
        imageWidth: 400,
        imageHeight: 225,
        verticalFOV: 20,
        lookFrom: Point3D(x: 13, y: 2, z: 3),
        lookAt: .zero
    )
}

private func getURL(_ path: String) -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: path)
}

func main() async throws {
    let world = try makeWorld1()
    let camera = makeCamera1()
    let t = Date()
    let image = await camera.render(world: world, config: .init(samplesPerPixel: 100, maxDepth: 50))
    let duration = Date().timeIntervalSince(t)
    print("Done in \(duration)s")
    try image.writePPM(to: getURL("results/barrel.ppm"))
}

try await main()

