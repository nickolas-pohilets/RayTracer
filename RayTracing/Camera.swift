//
//  Camera.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//

struct Camera {
    private var imageWidth: Int
    private var imageHeight: Int
    private var cameraCenter: Point3D
    private var viewportCenter: Point3D
    private var viewportU: Vector3D
    private var viewportV: Vector3D
    private var samplesPerPixel = 20 // Count of random samples for each pixel
    private var maxDepth = 10

    init(imageWidth: Int, imageHeight: Int) {
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        let focalLength = 1.0
        let viewportHeight = 2.0
        let viewportWidth = viewportHeight * Double(imageWidth) / Double(imageHeight)
        self.cameraCenter = Point3D.zero

        self.viewportU = Vector3D(x: viewportWidth, y: 0, z: 0)
        self.viewportV = Vector3D(x: 0, y: -viewportHeight, z: 0)
        self.viewportCenter = cameraCenter - Vector3D(x: 0, y: 0, z: focalLength)
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
                image[i, j] = (color / Double(samplesPerPixel)).asU8
            }
        }
        return image
    }

    private func getRay(_ i: Int, _ j: Int) -> Ray3D {
        let offsetX = Double.random(in: 0..<1)
        let offsetY = Double.random(in: 0..<1)
        let pixelSample = viewportCenter
            + ((Double(i) + offsetY) / Double(imageHeight) - 0.5) * viewportV
            + ((Double(j) + offsetX) / Double(imageWidth) - 0.5) * viewportU
        return Ray3D(origin: cameraCenter, target: pixelSample, normalized: true)
    }

    private func rayColor(_ ray: Ray3D, world: some Hittable, depth: Int) -> ColorF {
        if depth <= 0 {
            return .zero
        }
        if let hit = world.hit(ray: ray, range: 0.001..<Double.infinity) {
            let direction = Vector3D.randomUnitVector().align(with: hit.normal)
            return 0.5 * rayColor(Ray3D(origin: hit.point, direction: direction), world: world, depth: depth - 1)
        }

        let a = 0.5 * (ray.direction.y + 1.0)
        return (1 - a) * ColorF(x: 1, y: 1, z: 1) + a * ColorF(x: 0.5, y: 0.7, z: 1.0)
    }
}
