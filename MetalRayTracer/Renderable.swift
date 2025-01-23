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

extension __Sphere: RenderableImpl {
    static var intersectionFunctionName: String { "sphereIntersectionFunction" }
}

struct Sphere: Renderable {
    var transform: Transform
    var radius: Float
    var material: any Material

    init(transform: Transform, radius: Float, material: any Material) {
        self.transform = transform
        self.radius = radius
        self.material = material
    }

    init(center: vector_float3, radius: Float, material: any Material) {
        self.transform = Transform(rotation: .init(real: 1, imag: .zero), translation: center)
        self.radius = radius
        self.material = material
    }

    var boundingBox: MTLAxisAlignedBoundingBox {
        let r = vector_float3(radius, radius, radius)
        let center = transform.translation
        return MTLAxisAlignedBoundingBox(min: center - r, max: center + r)
    }

    func visitMaterials(_ reserver: inout MaterialReserver) {
        reserver.accept(material)
    }

    func asImpl(_ encoder: inout MaterialEncoder) -> __Sphere {
        let materialOffset = encoder.encode(material)
        return __Sphere(transform: transform.asImpl, radius: radius, material_offset: materialOffset)
    }
}

extension __Cylinder: RenderableImpl {
    static var intersectionFunctionName: String { "cylinderIntersectionFunction" }
}

struct Cylinder: Renderable {
    var transform: Transform = .init()
    var radius: Float
    var height: Float
    var bottom: any Material
    var top: any Material
    var side: any Material

    init(transform: Transform = .init(), radius: Float, height: Float, bottom: any Material, top: any Material, side: any Material) {
        self.transform = transform
        self.radius = radius
        self.height = height
        self.bottom = bottom
        self.top = top
        self.side = side
    }

    init(transform: Transform = .init(), radius: Float, height: Float, material: any Material) {
        self.transform = transform
        self.radius = radius
        self.height = height
        self.bottom = material
        self.top = material
        self.side = material
    }

    init(
        bottomCenter: vector_float3,
        topCenter: vector_float3,
        radius: Float,
        vRight: vector_float3 = [1, 0, 0],
        material: any Material
    ) {
        self.init(bottomCenter: bottomCenter, topCenter: topCenter, radius: radius, bottom: material, top: material, side: material)
    }

    init(
        bottomCenter: vector_float3,
        topCenter: vector_float3,
        radius: Float,
        vRight: vector_float3 = [1, 0, 0],
        bottom: any Material,
        top: any Material,
        side: any Material
    ) {
        var v = topCenter - bottomCenter
        self.height = length(topCenter - bottomCenter)
        v /= height
        let w = normalize(cross(vRight, v))
        let q1 = simd_quatf(from: v, to: vector_float3(0, 1, 0))
        let w1 = q1.act(w)
        let q2 = simd_quatf(from: w1, to: vector_float3(0, 0, 1))
        let q = (q2 * q1).inverse
        self.transform = Transform(
            rotation: q,
            translation: bottomCenter
        )
        self.radius = radius
        self.bottom = bottom
        self.top = top
        self.side = side
    }

    var boundingBox: MTLAxisAlignedBoundingBox {
        // See https://iquilezles.org/articles/diskbbox
        let normal = transform.rotation.act(vector_float3(0, 1, 0))
        let radiusProjection = (1.0 - normal * normal).squareRoot() * radius

        let bottomCenter = transform.translation
        let topCenter = bottomCenter + height * normal
        return MTLAxisAlignedBoundingBox(
            bottomCenter + radiusProjection,
            bottomCenter - radiusProjection,
            topCenter + radiusProjection,
            topCenter - radiusProjection
        )
    }

    func visitMaterials(_ reserver: inout MaterialReserver) {
        reserver.accept(bottom)
        reserver.accept(top)
        reserver.accept(side)
    }

    func asImpl(_ encoder: inout MaterialEncoder) -> __Cylinder {
        let bottomOffset = encoder.encode(bottom)
        let topOffset = encoder.encode(top)
        let sideOffset = encoder.encode(side)
        return __Cylinder(
            transform: transform.asImpl,
            radius: radius,
            height: height,
            bottom_material_offset: bottomOffset,
            top_material_offset: topOffset,
            side_material_offset: sideOffset
        )
    }
}

struct __SubtractImpl<LHS: RenderableImpl, RHS: RenderableImpl>: RenderableImpl {
    var lhs: LHS
    var rhs: RHS

    static var intersectionFunctionName: String {
        let suffix = "IntersectionFunction"
        let lhsName = LHS.intersectionFunctionName.removingSuffix(suffix)
        let rhsName = RHS.intersectionFunctionName.removingSuffix(suffix)
        return "subtract_\(lhsName)_\(rhsName)_\(suffix)"
    }
}

struct Subtract<LHS: Renderable, RHS: Renderable>: Renderable {
    var lhs: LHS
    var rhs: RHS

    var boundingBox: MTLAxisAlignedBoundingBox {
        lhs.boundingBox
    }

    func visitMaterials(_ reserver: inout MaterialReserver) {
        lhs.visitMaterials(&reserver)
        rhs.visitMaterials(&reserver)
    }

    func asImpl(_ encoder: inout MaterialEncoder) -> __SubtractImpl<LHS.Impl, RHS.Impl> {
        let lhsImpl = lhs.asImpl(&encoder)
        let rhsImpl = rhs.asImpl(&encoder)
        return __SubtractImpl(lhs: lhsImpl, rhs: rhsImpl)
    }
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

    init(_ points: vector_float3...) {
        self.init(
            min: vector_float3(repeating: Float.infinity),
            max: vector_float3(repeating: -Float.infinity)
        )
        for p in points {
            add(p)
        }
    }

    mutating func add(_ point: vector_float3) {
        self.min = simd.min(min.asUnpacked, point).asPacked
        self.max = simd.max(max.asUnpacked, point).asPacked
    }
}

extension String {
    func removingSuffix(_ suffix: String) -> Substring {
        let range = self.range(of: suffix)!
        assert(range.upperBound == self.endIndex)
        return self[..<range.lowerBound]
    }
}
