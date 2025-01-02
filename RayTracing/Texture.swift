//
//  Texture.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 03/01/2025.
//

public protocol Texture {
    subscript(u u: Double, v v: Double, point point: Point3D) -> ColorF { get }
}

public struct SolidColor: Texture {
    public var albedo: ColorF

    public init(albedo: ColorF) {
        self.albedo = albedo
    }

    public init(r: Double, g: Double, b: Double) {
        self.albedo = ColorF(x: r, y: g, z: b)
    }

    public subscript(u u: Double, v v: Double, point point: Point3D) -> ColorF { albedo }
}

class CheckerTexture: Texture {
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

    public subscript(u u: Double, v v: Double, point point: Point3D) -> ColorF {
        let xInteger = Int((invScale * point.x).rounded(.down))
        let yInteger = Int((invScale * point.y).rounded(.down))
        let zInteger = Int((invScale * point.z).rounded(.down))
        let isEven = (xInteger + yInteger + zInteger) % 2 == 0
        return isEven ? even[u: u, v: v, point: point] : odd[u: u, v: v, point: point]
    }
};
