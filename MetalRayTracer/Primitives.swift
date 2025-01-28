//
//  Primitives.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 28/01/2025.
//

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
        reserver.accept(self.bottom)
        reserver.accept(self.top)
        reserver.accept(self.side)
    }

    func asImpl(_ encoder: inout MaterialEncoder) -> __Cylinder {
        let bottomOffset = encoder.encode(self.bottom)
        let topOffset = encoder.encode(self.top)
        let sideOffset = encoder.encode(self.side)
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

extension __Cuboid: RenderableImpl {
    static var intersectionFunctionName: String { "cuboidIntersectionFunction" }
}

struct Cuboid: Renderable {
    var transform: Transform
    var size: vector_float3
    var material: any Material

    init(transform: Transform = .init(), size: vector_float3, material: any Material) {
        self.transform = transform
        self.size = size
        self.material = material
    }

    var boundingBox: MTLAxisAlignedBoundingBox {
        var result: MTLAxisAlignedBoundingBox = .empty
        for i in 0..<8 {
            var p: vector_float3 = .zero
            if (i & 1 != 0) {
                p.x = size.x
            }
            if (i & 2 != 0) {
                p.y = size.y
            }
            if (i & 4 != 0) {
                p.z = size.z
            }
            let px = transform.rotation.act(p) + transform.translation
            result.add(px)
        }
        return result
     }

    func visitMaterials(_ reserver: inout MaterialReserver) {
        reserver.accept(material)
    }

    func asImpl(_ encoder: inout MaterialEncoder) -> __Cuboid {
        let mat = encoder.encode(material)
        return __Cuboid(
            transform: transform.asImpl,
            size: size,
            material_offset: (mat, mat, mat, mat, mat, mat)
        )
    }
}

extension __Quad: RenderableImpl {
    static var intersectionFunctionName: String {
        "quadIntersectionFunction"
    }
}

struct Quad: Renderable {
    var origin: vector_float3
    var u: vector_float3
    var v: vector_float3
    var material: any Material

    init(
        transform: Transform = .init(),
        origin: vector_float3 = .init(),
        u: vector_float3,
        v: vector_float3,
        material: any Material
    ) {
        self.origin = transform.rotation.act(origin) + transform.translation
        self.u = transform.rotation.act(u)
        self.v = transform.rotation.act(v)
        self.material = material
    }

    init(
        transform: Transform = .init(),
        u: vector_float2,
        v: vector_float2,
        material: any Material
    ) {
        self.init(
            transform: transform,
            origin: .init(),
            u: vector_float3(u.x, u.y, 0),
            v: vector_float3(v.x, v.y, 0),
            material: material
        )
    }

    init(
        transform: Transform = .init(),
        width: Float,
        height: Float,
        material: any Material
    ) {
        self.init(
            transform: transform,
            origin: .init(),
            u: vector_float3(width, 0, 0),
            v: vector_float3(0, height, 0),
            material: material
        )
    }

    typealias Impl = __Quad

    var boundingBox: MTLAxisAlignedBoundingBox {
        var result: MTLAxisAlignedBoundingBox = .empty
        result.add(origin)
        result.add(origin + u)
        result.add(origin + v)
        result.add(origin + u + v)
        return result
    }

    func visitMaterials(_ reserver: inout MaterialReserver) {
        reserver.accept(material)
    }

    func asImpl(_ encoder: inout MaterialEncoder) -> __Quad {
        let materialOffset = encoder.encode(material)
        let n = cross(u, v)
        let lenSq = length_squared(n)
        let w = n / lenSq
        let normal = n / lenSq.squareRoot()
        let d = dot(origin, normal)
        return __Quad(origin: origin, u: u, v: v, w: w, normal: normal, d: d, material_offset: materialOffset)
    }
}
