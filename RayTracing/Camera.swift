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
                let pixelCenter = viewportCenter
                    + ((Double(i) + 0.5) / Double(image.height) - 0.5) * viewportV
                    + ((Double(j) + 0.5) / Double(image.width) - 0.5) * viewportU
                let ray = Ray3D(origin: cameraCenter, target: pixelCenter, normalized: true)
                let colorF = rayColor(ray, world: world)
                image[i, j] = colorF.asU8
            }
        }
        return image
    }

    private func rayColor(_ ray: Ray3D, world: some Hittable) -> ColorF {
        if let hit = world.hit(ray: ray, range: 0..<Double.infinity) {
            return 0.5 * (hit.normal + Vector3D(x: 1, y: 1, z: 1))
        }

        let a = 0.5 * (ray.direction.y + 1.0)
        return (1 - a) * ColorF(x: 1, y: 1, z: 1) + a * ColorF(x: 0.5, y: 0.7, z: 1.0)
    }
}
