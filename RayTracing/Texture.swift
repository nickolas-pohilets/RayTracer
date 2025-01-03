//
//  Texture.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 03/01/2025.
//

public protocol Texture {
    subscript(_ coordinates: Point2D, point point: Point3D) -> ColorF { get }
}

public struct SolidColor: Texture {
    public var albedo: ColorF

    public init(albedo: ColorF) {
        self.albedo = albedo
    }

    public init(r: Double, g: Double, b: Double) {
        self.albedo = ColorF(x: r, y: g, z: b)
    }

    public subscript(_ coordinates: Point2D, point point: Point3D) -> ColorF { albedo }
}

struct CheckerTexture: Texture {
    var invScale: Double
    var even: any Texture
    var odd: any Texture

    public init(scale: Double, even: any Texture, odd: any Texture) {
        self.invScale = 1 / scale
        self.even = even
        self.odd = odd
    }

    public init(scale: Double, even: ColorF, odd: ColorF) {
        self.invScale = 1 / scale
        self.even = SolidColor(albedo: even)
        self.odd = SolidColor(albedo: odd)
    }

    public subscript(_ coordinates: Point2D, point point: Point3D) -> ColorF {
        let xInteger = Int((invScale * point.x).rounded(.down))
        let yInteger = Int((invScale * point.y).rounded(.down))
        let zInteger = Int((invScale * point.z).rounded(.down))
        let isEven = (xInteger + yInteger + zInteger) % 2 == 0
        return isEven ? even[coordinates, point: point] : odd[coordinates, point: point]
    }
}

struct ImageTexture: Texture {
    var image: Image

    public subscript(_ coordinates: Point2D, point point: Point3D) -> ColorF {
        let i: Double = (1.0 - min(1, max(coordinates.v, 0))) * Double(image.height) - 0.5
        let j: Double = min(1, max(coordinates.u, 0)) * Double(image.width) - 0.5
        let i1 = Int(i), i2 = min(i1 + 1, image.height - 1)
        let j1 = Int(j), j2 = min(j1 + 1, image.width - 1)
        let a = (i - Double(i1))
        let b = (j - Double(j1))

        let c1 = image[i1, j1].asF * (1 - b) + image[i1, j2].asF * b
        let c2 = image[i2, j1].asF * (1 - b) + image[i2, j2].asF * b
        return c1 * (1 - a) + c2 * a
    }

}
