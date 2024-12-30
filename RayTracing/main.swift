//
//  main.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//

import Foundation

func makeWorld() -> [any Hittable] {
    var w: [any Hittable] = []

    let ground = Lambertian(albedo: ColorF(x: 0.5, y: 0.5, z: 0.5))
    w.append(Sphere(center: Point3D(x: 0, y: -1000, z: 0), radius: 1000, material: ground))

    var rng = SystemRandomNumberGenerator()

    for a in -11..<11 {
        for b in -11..<11 {
            let chooseMat = Double.random(in: 0..<1)
            let center = Point3D(x: Double(a) + 0.9*Double.random(in: 0..<1), y: 0.2, z: Double(b) + 0.9*Double.random(in: 0..<1))

            if (center - Point3D(x: 4, y: 0.2, z: 0)).length > 0.9 {
                if (chooseMat < 0.8) {
                    // diffuse
                    let albedo = ColorF.random(using: &rng) * ColorF.random(using: &rng)
                    let material = Lambertian(albedo: albedo)

                    let center2 = center + Vector3D(x: 0, y: .random(in: 0...0.5, using: &rng), z: 0)
                    w.append(Sphere(centerStart: center, centerStop: center2, radius: 0.2, material: material))
                } else if (chooseMat < 0.95) {
                    // metal
                    let albedo = ColorF.random(in: 0.5...1, using: &rng)
                    let fuzz = Double.random(in: 0...0.5)
                    let material = Metal(albedo: albedo, fuzz: fuzz)
                    w.append(Sphere(center: center, radius: 0.2, material: material))
                } else {
                    // glass
                    let material = Dielectric(refractionIndex: 1.5);
                    w.append(Sphere(center: center, radius: 0.2, material: material))
                }
            }
        }
    }

    let material1 = Dielectric(refractionIndex: 1.5)
    w.append(Sphere(center: Point3D(x: 0, y: 1, z: 0), radius: 1.0, material: material1))

    let material2 = Lambertian(albedo: ColorF(x: 0.4, y: 0.2, z: 0.1))
    w.append(Sphere(center: Point3D(x: -4, y: 1, z: 0), radius: 1.0, material: material2))

    let material3 = Metal(albedo: ColorF(x: 0.7, y: 0.6, z: 0.5), fuzz: 0.0)
    w.append(Sphere(center: Point3D(x: 4, y: 1, z: 0), radius: 1.0, material: material3))

    return w
}

private func getURL(_ path: String) -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: path)
}

func main() async throws {
    let world = makeWorld()

    let imageWidth = 400
    let camera = Camera(
        imageWidth: imageWidth,
        imageHeight: imageWidth * 9 / 16,
        verticalFOV: 20,
        lookFrom: Point3D(x: 13, y: 2, z: 3),
        lookAt: Point3D(x: 0, y: 0, z: 0),
        defocusAngle: 0.6,
        focusDistance: 10
    )
    let t = Date()
    let image = await camera.render(world: world, config: .init(samplesPerPixel: 100, maxDepth: 50))
    let duration = Date().timeIntervalSince(t)
    print("Done in \(duration)s")
    try image.writePPM(to: getURL("results/dropping-balls.ppm"))
}

try await main()
