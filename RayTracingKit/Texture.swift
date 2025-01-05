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

public struct ImageTexture: Texture {
    public var image: Image
    public let originX: Int
    public let originY: Int
    public let width: Int
    public let height: Int
    public let invertX: Bool
    public let invertY: Bool
    public let wrapX: Bool
    public let wrapY: Bool

    public init(image: Image, wrapX: Bool = true, wrapY: Bool = true) {
        self.init(image: image, originX: 0, originY: image.height - 1, width: image.width, height: -image.height)
    }

    public init(image: Image, originX: Int, originY: Int, width: Int, height: Int, wrapX: Bool = true, wrapY: Bool = true) {
        self.image = image
        self.originX = originX
        self.originY = originY
        self.width = abs(width)
        self.height = abs(height)
        self.invertX = width < 0
        self.invertY = height < 0
        self.wrapX = wrapX
        self.wrapY = wrapY
    }

    public subscript(_ coordinates: Point2D, point point: Point3D) -> ColorF {
        let i: Double = coordinates.v * Double(height) - 0.5
        let j: Double = coordinates.u * Double(width) - 0.5
        let i1 = Int(i.rounded(.down)), i2 = i1 + 1
        let j1 = Int(j.rounded(.down)), j2 = j1 + 1
        let a = (i - Double(i1))
        let b = (j - Double(j1))

        let c1 = getPixel(i1, j1) * (1 - b) + getPixel(i1, j2) * b
        let c2 = getPixel(i2, j1) * (1 - b) + getPixel(i2, j2) * b
        let r = c1 * (1 - a) + c2 * a
        r.validate()
        return r
    }

    private func getPixel(_ i: Int, _ j: Int) -> ColorF {
        let ix = originY + Self.clip(i, height, wrapY) * (invertY ? -1 : +1)
        let jx = originX + Self.clip(j, width, wrapX) * (invertX ? -1 : +1)
        let r = image[ix, jx].asF
        r.validate()
        return r
    }

    static func clip(_ index: Int, _ size: Int, _ wrap: Bool) -> Int {
        assert(size > 0)
        if index < 0 {
            if wrap {
                return size + (index % size)
            } else {
                return 0
            }
        } else if index >= size {
            if wrap {
                return (index % size)
            } else {
                return size - 1
            }
        } else {
            return index
        }
    }

//    private func toIndexY(_ i: Double) -> Int {
//        let top = min(originY, originY + height)
//        let bottom = max(originY, originY + height)
//        let ix = Int(i - 0.5)
//
//
//    }
//
//    private func toIndexX(_ j: Double) -> Int {
//
//    }

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
