//
//  Vector3D.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//

infix operator • : MultiplicationPrecedence
infix operator ⨯ : MultiplicationPrecedence

public typealias Point3D = Vector3D
public typealias ColorF = Vector3D

public struct Vector3D {
    public var x: Double
    public var y: Double
    public var z: Double

    public static var zero: Self { .init(x: 0, y: 0, z: 0) }

    public init(x: Double, y: Double, z: Double) {
        assert(!x.isNaN && !y.isNaN && !z.isNaN)
        self.x = x
        self.y = y
        self.z = z
    }

    public var length: Double {
        return lengthSquared.squareRoot()
    }

    public var lengthSquared: Double {
        return self • self
    }

    public func normalized() -> Self {
        let L = self.length
        return .init(x: x / L, y: y / L, z: z / L)
    }

    public subscript(_ index: Int) -> Double {
        get {
            switch index {
            case 0: self.x
            case 1: self.y
            case 2: self.z
            default: fatalError("Index \(index) is out of bounds")
            }
        }
        set {
            switch index {
            case 0: self.x = newValue
            case 1: self.y = newValue
            case 2: self.z = newValue
            default: fatalError("Index \(index) is out of bounds")
            }
        }
    }

    public static prefix func -(_ v: Self) -> Self { .init(x: -v.x, y: -v.y, z: -v.z) }
    public static func +(_ lhs: Self, _ rhs: Self) -> Self {
        .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }
    public static func -(_ lhs: Self, _ rhs: Self) -> Self {
        .init(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }
    public static func *(_ lhs: Self, _ rhs: Double) -> Self {
        .init(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }
    public static func *(_ lhs: Double, _ rhs: Self) -> Self {
        .init(x: lhs * rhs.x, y: lhs * rhs.y, z: lhs * rhs.z)
    }
    public static func /(_ lhs: Self, _ rhs: Double) -> Self {
        .init(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
    }

    public static func •(_ lhs: Self, _ rhs: Self) -> Double {
        return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
    }

    public static func ⨯(_ lhs: Self, _ rhs: Self) -> Self {
        .init(
            x: lhs.y * rhs.z - lhs.z * rhs.y,
            y: lhs.z * rhs.x - lhs.x * rhs.z,
            z: lhs.x * rhs.y - lhs.y * rhs.x
        )
    }

    public static func randomUnitVector<T: RandomNumberGenerator>(
        using generator: inout T
    ) -> Self {
        while (true) {
            let v = Vector3D(
                x: .random(in: -1...1, using: &generator),
                y: .random(in: -1...1, using: &generator),
                z: .random(in: -1...1, using: &generator)
            )
            let lenSq = v.lengthSquared
            if 1e-160 < lenSq && lenSq <= 1 {
                return v / lenSq.squareRoot()
            }
        }
    }

    public static func randomUnitVector() -> Self {
        var g = SystemRandomNumberGenerator()
        return randomUnitVector(using: &g)
    }

    public func align(with normal: Vector3D) -> Self {
        if self • normal < 0 {
            return -self
        }
        return self
    }
}

extension ColorF {
    var asU8: ColorU8 {
        .init(r: toU8(x), g: toU8(y), b: toU8(z))
    }

    func linearToGamma() -> Self {
        .init(x: x.squareRoot(), y: y.squareRoot(), z: z.squareRoot())
    }
}

private func toU8(_ x: Double) -> UInt8 {
    return UInt8(exactly: ((256.0).nextDown * x).rounded(.down))!
}
