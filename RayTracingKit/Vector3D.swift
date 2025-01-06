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

public enum Axis3D: Int, CaseIterable, Equatable {
    case x
    case y
    case z
}

public struct Vector3D: AdditiveArithmetic, Equatable {
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

    public init(axis: Axis3D) {
        switch axis {
        case .x:
            self.x = 1
            self.y = 0
            self.z = 0
        case .y:
            self.x = 0
            self.y = 1
            self.z = 0
        case .z:
            self.x = 0
            self.y = 0
            self.z = 1
        }
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

    public subscript(_ axis: Axis3D) -> Double {
        get {
            switch axis {
            case .x: self.x
            case .y: self.y
            case .z: self.z
            }
        }
        set {
            switch axis {
            case .x: self.x = newValue
            case .y: self.y = newValue
            case .z: self.z = newValue
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
    public static func *(_ lhs: Self, _ rhs: Self) -> Self {
        .init(x: lhs.x * rhs.x, y: lhs.y * rhs.y, z: lhs.z * rhs.z)
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

    public static func randomUnitVector2D<T: RandomNumberGenerator>(
        using generator: inout T
    ) -> Self {
        while (true) {
            let v = Vector3D(
                x: .random(in: -1...1, using: &generator),
                y: .random(in: -1...1, using: &generator),
                z: 0
            )
            let lenSq = v.lengthSquared
            if 1e-160 < lenSq && lenSq <= 1 {
                return v / lenSq.squareRoot()
            }
        }
    }

    public func aligned(with normal: Vector3D) -> Self {
        if self • normal < 0 {
            return -self
        }
        return self
    }

    public func reflected(normal: Vector3D) -> Self {
        return self - (2 * (self • normal)) * normal
    }

    public func refracted(normal: Vector3D, ηRatio: Double, reflectanceRandom: Double) -> Vector3D? {
        let cosθ = max(self • normal, -1.0)
        let rPerp = ηRatio * (self - cosθ * normal)
        let rPerpLenSq = rPerp.lengthSquared
        if rPerpLenSq > 1 { return nil }
        if reflectanceRandom <= 0 { return nil }
        if reflectanceRandom < 1 {
            let reflectance = reflectance(cosθ: cosθ, ηRatio: ηRatio)
            assert(reflectance >= 0 && reflectance < 1)
            if reflectance > reflectanceRandom { return nil }
        }
        let rParallel = normal * -((1 - rPerpLenSq).squareRoot())
        return .some(rPerp + rParallel)
    }

    public func refractedOrReflected(normal: Vector3D, ηRatio: Double, reflectanceRandom: Double) -> Vector3D {
        return refracted(normal: normal, ηRatio: ηRatio, reflectanceRandom: reflectanceRandom) ?? reflected(normal: normal)
    }

    public static func interpolate(_ v0: Self, _ v1: Self, t: Double) -> Self {
        return (1 - t) * v0 + t * v1
    }
}

extension ColorF {
    var asU8: ColorU8 {
        .init(r: toU8(x), g: toU8(y), b: toU8(z))
    }

    func linearToGamma() -> Self {
        .init(
            x: min(x.squareRoot(), 1),
            y: min(y.squareRoot(), 1),
            z: min(z.squareRoot(), 1)
        )
    }

    public static func random(in range: ClosedRange<Double> = 0...1, using rng: inout some RandomNumberGenerator) -> ColorF {
        return ColorF(
            x: .random(in: range, using: &rng),
            y: .random(in: range, using: &rng),
            z: .random(in: range, using: &rng)
        )
    }

    public func validate() {
        assert((0...1).contains(x))
        assert((0...1).contains(y))
        assert((0...1).contains(z))
    }
}

private func toU8(_ x: Double) -> UInt8 {
    precondition((0...1).contains(x), "Invalid color value: \(x)")
    return UInt8(exactly: ((256.0).nextDown * x).rounded(.down))!
}

private func reflectance(cosθ: Double, ηRatio: Double) -> Double {
    // Use Schlick's approximation for reflectance.
    let sqR0 = ((1 - ηRatio) / (1 + ηRatio))
    let R0 = sqR0 * sqR0
    let x = (1 + cosθ) // In our case cosθ is inverted
    let x2 = x * x
    let x4 = x2 * x2
    return R0 + (1 - R0) * (x4 * x)
}

extension Double {
    func squared() -> Double { self * self }
}
