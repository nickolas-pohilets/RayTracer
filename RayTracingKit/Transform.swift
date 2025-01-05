//
//  Transform.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 03/01/2025.
//
import Foundation

public struct Transform3D {
    public let rotation: Quaternion
    public let translation: Vector3D

    public static var identity: Transform3D { .init() }

    public init(rotation: Quaternion = .identity, translation: Vector3D = .zero) {
        self.rotation = rotation
        self.translation = translation
    }

    public static func *(_ lhs: Self, _ rhs: Self) -> Self {
        Transform3D(
            rotation: lhs.rotation * rhs.rotation,
            translation: lhs.rotation.rotate(rhs.translation) + lhs.translation
        )
    }

    public var inverse: Transform3D {
        Transform3D(rotation: rotation.inverse, translation: -translation)
    }

    public func transform(_ p: Point3D) -> Point3D {
        return rotation.rotate(p) + translation
    }

    public func pow(_ t: Double) -> Self {
        return Transform3D(rotation: rotation.pow(t), translation: t * translation)
    }

    public static func interpolate(_ t0: Self, _ t1: Self, t: Double) -> Self {
        return Transform3D(
            rotation: .interpolate(t0.rotation, t1.rotation, t: t),
            translation: .interpolate(t0.translation, t1.translation, t: t)
        )
    }

    public func boundingBox(for p: Point3D) -> AABB {
        let p1 = rotation.rotate(p)
        let p2 = p1 + translation
        var result = AABB(p, p2)
        if !rotation.isIdentity {
            let θ = rotation.radians
            // p(t) = (sin((1-t)*θ)*p + sin(t*θ)*p1)/sin(θ) + t * translation
            // p(t) = (sin(θ)*cos(t*θ)*p - cos(θ)*sin(t*θ)*p + sin(t*θ)*p1)/sin(θ) + t * translation
            // For each axis s ∈ {.x, .y, .z} find tₛ which gives an extemum of p(t)ₛ
            // p(tₛ) = (sin(θ)*cos(tₛ*θ)*pₛ - cos(θ)*sin(tₛ*θ)*pₛ + sin(tₛ*θ)*p1ₛ)/sin(θ) + t * translationₛ
            // dp(tₛ)/dtₛ = (-sin(θ)*θ*sin(tₛ*θ)*pₛ - cos(θ)*θ*cos(tₛ*θ)*pₛ + θ*cos(tₛ*θ)*p1ₛ) / sin(θ) + translationₛ = 0
            // -sin(θ)*θ*sin(tₛ*θ)*pₛ - cos(θ)*θ*cos(tₛ*θ)*pₛ + θ*cos(tₛ*θ)*p1ₛ = -translationₛ * sin(θ)
            // (sin(θ)*θ*pₛ) * sin(tₛ*θ) + (cos(θ)*θ*pₛ - θ*p1ₛ) * cos(tₛ*θ) = translationₛ * sin(θ)
            // A = sin(θ) * θ * pₛ
            // B = θ * (cos(θ) * pₛ - p1ₛ)
            // C = translationₛ * sin(θ)
            // A * sin(tₛ*θ) + B * cos(tₛ*θ) = C
            // A = Z * sin(φ), B = Z * cos(φ)
            // cos(tₛ*θ - φ) = C / sqrt(A² + B²)
            // tₛ*θ - φ = ± acos(C / sqrt(A² + B²)) + 2πn
            // tₛ - φ = (atan2(B, A) ± acos(C / sqrt(A² + B²)) + 2πn)/θ
            // Choose n such that 0 ≤ tₛ*θ ≤ π
            let sinθ = sin(θ)
            let cosθ = cos(θ)
            func getP(_ t: Double) -> Point3D {
                (sin((1 - t) * θ)/sinθ) * p + (sin(t * θ) / sinθ) * p1 + t * translation
            }
            for axis in Axis3D.allCases {
                let A = θ * sinθ * p[axis]
                let B = θ * (cosθ * p[axis] - p1[axis])
                let C = translation[axis] * sinθ
                let Z = C / sqrt(A * A + B * B)
                if !Z.isFinite { continue }
                if abs(Z) > 1 { continue }
                let φ = atan2(A, B)
                let acosZ = acos(Z)
                let t1 = normalizeAngle(φ + acosZ) / θ
                let t2 = normalizeAngle(φ - acosZ) / θ
                if t1.isFinite && (0...1).contains(t1) {
                    result.add(getP(t1))
                }
                if t2.isFinite && (0...1).contains(t2) {
                    result.add(getP(t2))
                }
            }
        }
        return result


    }
}

private func normalizeAngle(_ x: Double) -> Double {
    var result = x
    let tau: Double = 2 * .pi
    if result < 0 {
        result += tau
    } else if result >= tau {
        result -= tau
    }
    return result
}

/// Unit quaternion representing orientation
public struct Quaternion {
    public let w: Double
    public let v: Vector3D

    private init(w: Double, x: Double, y: Double, z: Double) {
        self.w = w
        self.v = Vector3D(x: x, y: y, z: z)
    }

    private init(w: Double, v: Vector3D) {
        self.w = w
        self.v = v
    }

    public static var identity: Self { Quaternion(w: 1, v: .zero) }

    public init(degrees: Double, axis: Vector3D, normalized: Bool) {
        let radians = degrees / 180.0 * .pi
        self.init(radians: radians, axis: axis, normalized: normalized)
    }

    public init(radians: Double, axis: Vector3D, normalized: Bool) {
        let cosA = cos(radians / 2)
        w = abs(cosA)
        var scale = sin(radians / 2) * (cosA < 0 ? -1 : +1)
        if !normalized {
            scale /= axis.length
        }
        v = axis * scale
    }

    public var x: Double { v.x }
    public var y: Double { v.y }
    public var z: Double { v.z }

    public var inverse: Quaternion {
        Quaternion(w: w, v: -v)
    }

    public var isIdentity: Bool {
        return w == 1.0
    }

    public var radians: Double {
        return 2*acos(w)
    }

    public var degrees: Double {
        return radians * 180 / .pi
    }

    public func rotate(_ v: Vector3D) -> Vector3D {
        let r = (self * Quaternion(w: 0, v: v) * inverse)
        assert(abs(r.w) < 1e-8)
        return r.v
    }

    public static func *(_ lhs: Self, _ rhs: Self) -> Self {
        Quaternion(
            w: lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z,  // 1
            x: lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,  // i
            y: lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x,  // j
            z: lhs.w * rhs.z + lhs.x * rhs.y - lhs.y * rhs.x + lhs.z * rhs.w   // k
        )
    }

    public func pow(_ t: Double) -> Self {
        let θ = acos(w) // θ/2 actually
        let sinθ = sqrt(1 - w * w)
        let w2 = cos(θ * t)
        let scale = sin(θ * t) / sinθ
        return Quaternion(w: w2, v: scale.isFinite ? v * scale : .zero)
    }

    public static func interpolate(_ q0: Self, _ q1: Self, t: Double) -> Self {
        let Ω = acos(q0.w * q1.w + q0.v • q1.v)
        let sinΩ = sin(Ω)
        let a = sin(Ω - t * Ω) / sinΩ
        let b = sin(t * Ω) / sinΩ
        return Quaternion(w: a * q0.w + b * q1.w, v: a * q0.v + b * q1.v)
    }
}

/// Unused for now
struct Matrix3D {
    var xx, xy, xz: Double
    var yx, yy, yz: Double
    var zx, zy, zz: Double

    static var zero: Self {
        Matrix3D(
            xx: 0, xy: 0, xz: 0,
            yx: 0, yy: 0, yz: 0,
            zx: 0, zy: 0, zz: 0
        )
    }

    static var identity: Self {
        Matrix3D(
            xx: 1, xy: 0, xz: 0,
            yx: 0, yy: 1, yz: 0,
            zx: 0, zy: 0, zz: 1
        )
    }

    static func scale(x: Double = 1, y: Double = 1, z: Double = 1) -> Self {
        Matrix3D(
            xx: x, xy: 0, xz: 0,
            yx: 0, yy: y, yz: 0,
            zx: 0, zy: 0, zz: z
        )
    }

    static func scale(_ v: Vector3D) -> Self {
        Matrix3D(
            xx: v.x, xy: 0, xz: 0,
            yx: 0, yy: v.y, yz: 0,
            zx: 0, zy: 0, zz: v.z
        )
    }

    static func rotate(degrees: Double, axis: Axis3D) -> Self {
        return rotate(radians: degrees * .pi / 180, axis: axis)
    }

    static func rotate(radians: Double, axis: Axis3D) -> Self {
        let c = cos(radians)
        let s = sin(radians)

        switch axis {
        case .x:
            return Matrix3D(
                xx: 1, xy: 0, xz: 0,
                yx: 0, yy: c, yz: -s,
                zx: 0, zy: s, zz: c
            )
        case .y:
            return Matrix3D(
                xx: c, xy: 0, xz: s,
                yx: 0, yy: 1, yz: 0,
                zx: -s, zy: 0, zz: c
            )
        case .z:
            return Matrix3D(
                xx: c, xy: -s, xz: 0,
                yx: s, yy: c, yz: 0,
                zx: 0, zy: 0, zz: 1
            )
        }
    }

    public subscript(_ row: Axis3D, _ column: Axis3D) -> Double {
        get {
            switch (row, column) {
            case (.x, .x): return xx
            case (.x, .y): return xy
            case (.x, .z): return xz
            case (.y, .x): return yx
            case (.y, .y): return yy
            case (.y, .z): return yz
            case (.z, .x): return zx
            case (.z, .y): return zy
            case (.z, .z): return zz
            }
        }
        set {
            switch (row, column) {
            case (.x, .x): xx = newValue
            case (.x, .y): xy = newValue
            case (.x, .z): xz = newValue
            case (.y, .x): yx = newValue
            case (.y, .y): yy = newValue
            case (.y, .z): yz = newValue
            case (.z, .x): zx = newValue
            case (.z, .y): zy = newValue
            case (.z, .z): zz = newValue
            }
        }
    }

    public static func *(_ lhs: Self, _ rhs: Self) -> Self {
        var result: Self = .zero
        for i in Axis3D.allCases {
            for j in Axis3D.allCases {
                var t: Double = 0
                for k in Axis3D.allCases {
                    t += lhs[i, k] * rhs[k, j]
                }
                result[i, j] = t
            }
        }
        return result
    }

    public static func *(_ lhs: Self, _ rhs: Double) -> Self {
        Matrix3D(
            xx: lhs.xx * rhs, xy: lhs.xy * rhs, xz: lhs.xz * rhs,
            yx: lhs.yx * rhs, yy: lhs.yy * rhs, yz: lhs.yz * rhs,
            zx: lhs.zx * rhs, zy: lhs.zy * rhs, zz: lhs.zz * rhs
        )
    }

    public static func *(_ lhs: Double, _ rhs: Self) -> Self {
        return rhs * lhs
    }

    public static func *(_ lhs: Self, _ rhs: Vector3D) -> Vector3D {
        Vector3D(
            x: lhs.xx * rhs.x + lhs.xy * rhs.y + lhs.xz * rhs.z,
            y: lhs.yx * rhs.x + lhs.yy * rhs.y + lhs.yz * rhs.z,
            z: lhs.zx * rhs.x + lhs.zy * rhs.y + lhs.zz * rhs.z
        )
    }

    public var transposed: Self {
        Matrix3D(
            xx: xx, xy: yz, xz: zx,
            yx: xy, yy: yy, yz: zy,
            zx: xz, zy: yz, zz: zz
        )
    }

    public var det: Double {
        xx*yy*zz + xy*yz*zx + xz*yx*zy - xx*yz*zy - xy*yx*zz - xz*yy*zx
    }

    public var inverse: Self? {
        let det = self.det
        if det == 0 { return nil }

        let xx = (yy * zz - yz * zy) / det
        let xy = (xz * zy - xy * zz) / det
        let xz = (xy * yz - xz * yy) / det
        let yx = (yz * zx - yx * zz) / det
        let yy = (xx * zz - xz * zx) / det
        let yz = (xz * yx - xx * yz) / det
        let zx = (yx * zy - yy * zx) / det
        let zy = (xy * zx - xx * zy) / det
        let zz = (xx * yy - xy * yx) / det

        if xx.isFinite && xy.isFinite && xz.isFinite && yx.isFinite && yy.isFinite && yz.isFinite && zx.isFinite && zy.isFinite && zz.isFinite {
            return Matrix3D(xx: xx, xy: xy, xz: xz, yx: yx, yy: yy, yz: yz, zx: zx, zy: zy, zz: zz)
        } else {
            return nil
        }
    }
}
