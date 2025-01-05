//
//  Texture.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 03/01/2025.
//
import Foundation

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

public struct NoiseTexture: Texture {
    var noise: PerlinNoise
    var scale: Double

    public init(noise: PerlinNoise, scale: Double) {
        self.noise = noise
        self.scale = scale
    }

    public subscript(_ coordinates: Point2D, point point: Point3D) -> ColorF {
        let grey = abs(noise[scale * point, turbulence: 7])
        return ColorF(x: grey, y: grey, z: grey)
    }
}

public struct Marble: Texture {
    var noise: PerlinNoise
    var scale: Double

    public init(noise: PerlinNoise, scale: Double) {
        self.noise = noise
        self.scale = scale
    }

    public subscript(_ coordinates: Point2D, point point: Point3D) -> ColorF {
        let grey = (1 + sin(scale * point.z + 10 * noise[point, turbulence: 7])) * 0.5
        return ColorF(x: grey, y: grey, z: grey)
    }
}

public struct PerlinNoise {
    private var vectors: [Vector3D]
    private var permX: [UInt8]
    private var permY: [UInt8]
    private var permZ: [UInt8]

    public init(using rng: inout some RandomNumberGenerator) {
        vectors = (0..<256).map { _ in
            Vector3D.random(in: (-1)...1, using: &rng)
        }
        permX = Array(0...255)
        permX.shuffle(using: &rng)
        permY = Array(0...255)
        permY.shuffle(using: &rng)
        permZ = Array(0...255)
        permZ.shuffle(using: &rng)
    }

    subscript(point: Point3D) -> Double {
        let u = point.x - floor(point.x)
        let v = point.y - floor(point.y)
        let w = point.z - floor(point.z)

        let uu = hermitian(u)
        let vv = hermitian(v)
        let ww = hermitian(w)

        let i = Int(point.x)
        let j = Int(point.y)
        let k = Int(point.z)

        var result: Double = 0.0
        for di in 0..<2 {
            for dj in 0..<2 {
                for dk in 0..<2 {
                    let index = Int(permX[(i + di) & 255] ^ permY[(j + dj) & 255] ^ permZ[(k + dk) & 255])
                    let weight = (di == 0 ? 1 - uu : uu) * (dj == 0 ? 1 - vv : vv) * (dk == 0 ? 1 - ww : ww)
                    result += weight * (vectors[index] • Vector3D(x: u - Double(di), y: v - Double(dj), z: w - Double(dk)))
                }
            }
        }
        assert(((-1)...1).contains(result))
        return result
    }

    subscript(point: Point3D, turbulence turbulence: Int) -> Double {
        var accum = 0.0
        var p = point
        var weight = 1.0

        for _ in 0..<turbulence {
            accum += weight * self[p]
            weight *= 0.5
            p = p * 2.0
        }
        assert(((-1)...1).contains(accum))
        return accum
    }
}

/// Hermitian Smoothing
private func hermitian(_ x: Double) -> Double {
    return x * x * (3 - 2 * x)
}
