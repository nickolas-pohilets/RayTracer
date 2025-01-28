//
//  Renderable.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 12/01/2025.
//
import Metal

public enum Axis3D: Int, CaseIterable, Equatable {
    case x
    case y
    case z
}

extension vector_float3 {
    init(axis: Axis3D) {
        switch axis {
        case .x:
            self.init(1, 0, 0)
        case .y:
            self.init(0, 1, 0)
        case .z:
            self.init(0, 0, 1)
        }
    }
}

extension simd_quatf {
    static var identity: Self {
        .init(ix: 0, iy: 0, iz: 0, r: 1)
    }
}

struct Transform {
    var rotation: simd_quatf = .identity
    var translation: vector_float3 = .zero

    static var identity: Self { .init() }

    static func rotation(degrees: Float, axis: Axis3D) -> Self {
        .init(rotation: .init(angle: degrees * .pi / 180, axis: .init(axis: axis)))
    }

    static func translation(_ v: vector_float3) -> Self {
        .init(translation: v)
    }

    static func translation(_ x: Float, _ y: Float, _ z: Float) -> Self {
        .init(translation: .init(x, y, z))
    }

    public static func *(_ lhs: Self, _ rhs: Self) -> Self {
        Transform(
            rotation: lhs.rotation * rhs.rotation,
            translation: lhs.rotation.act(rhs.translation) + lhs.translation
        )
    }

    public var inverse: Transform {
        // Ri * (R * p + T) + Ti = p
        // (Ri * R * p) + Ri * T + Ti = p
        // Ti = -Ri * T
        let rInv = rotation.inverse
        return Transform(rotation: rInv, translation: -rInv.act(translation))
    }

    var asImpl: __Transform {
        return __Transform(rotation: simd_float3x3(rotation), translation: translation)
    }
}

protocol Renderable {
    var boundingBox: MTLAxisAlignedBoundingBox { get }

    func visitMaterials(_ reserver: inout MaterialReserver)

    associatedtype Impl: RenderableImpl
    func asImpl(_ encoder: inout MaterialEncoder) -> Impl
}

extension Renderable {
    var implType: RenderableImpl.Type { Impl.self }
}

protocol RenderableImpl {
    static var intersectionFunctionName: String { get }
}

extension RenderableImpl {
    static var size: Int { MemoryLayout<Self>.stride }
}

extension vector_float3 {
    var asPacked: MTLPackedFloat3 {
        return MTLPackedFloat3Make(self.x, self.y, self.z)
    }
}

extension MTLPackedFloat3 {
    var asUnpacked: vector_float3 {
        vector_float3(x, y, z)
    }
}

extension MTLAxisAlignedBoundingBox {
    init(min: vector_float3, max: vector_float3) {
        self.init(min: min.asPacked, max: max.asPacked)
    }

    static var empty: Self {
        self.init(
            min: vector_float3(repeating: +Float.infinity),
            max: vector_float3(repeating: -Float.infinity)
        )
    }

    static var unlimited: Self {
        self.init(
            min: vector_float3(repeating: -Float.infinity),
            max: vector_float3(repeating: +Float.infinity)
        )
    }

    init(_ points: vector_float3...) {
        self = .empty
        for p in points {
            add(p)
        }
    }

    init(_ boxes: MTLAxisAlignedBoundingBox...) {
        self.init(
            min: vector_float3(repeating: Float.infinity),
            max: vector_float3(repeating: -Float.infinity)
        )
        for b in boxes {
            unite(with: b)
        }
    }

    mutating func add(_ point: vector_float3) {
        self.min = simd.min(min.asUnpacked, point).asPacked
        self.max = simd.max(max.asUnpacked, point).asPacked
    }

    mutating func unite(with box: MTLAxisAlignedBoundingBox) {
        add(box.min.asUnpacked)
        add(box.max.asUnpacked)
    }

    mutating func intersect(with box: MTLAxisAlignedBoundingBox) {
        self.min = simd.max(min.asUnpacked, box.min.asUnpacked).asPacked
        self.max = simd.min(max.asUnpacked, box.max.asUnpacked).asPacked
    }
}

func getIntersectionFunctionName<each T: RenderableImpl>(operation: String, operands: (repeat (each T).Type)) -> String {
    let suffix = "IntersectionFunction"
    var result = operation
    for name in repeat (each operands).intersectionFunctionName {
        result += "_\(name.removingSuffix(suffix))"
    }
    result += "_\(suffix)"
    return result
}

extension String {
    func removingSuffix(_ suffix: String) -> Substring {
        let range = self.range(of: suffix)!
        assert(range.upperBound == self.endIndex)
        return self[..<range.lowerBound]
    }
}
