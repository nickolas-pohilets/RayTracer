//
//  CSG.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 28/01/2025.
//

struct __SubtractImpl<LHS: RenderableImpl, RHS: RenderableImpl>: RenderableImpl {
    var lhs: LHS
    var rhs: RHS

    static var intersectionFunctionName: String {
        getIntersectionFunctionName(operation: "subtract", operands: (LHS.self, RHS.self))
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

struct __UnionImpl<each T: RenderableImpl>: RenderableImpl {
    var items: (repeat each T)

    private static var count: Int {
        var result = 0
        for _ in repeat (each T).self {
            result += 1
        }
        return result
    }

    static var intersectionFunctionName: String {
        getIntersectionFunctionName(operation: "union\(Self.count)", operands: (repeat (each T).self))
    }
}

struct Union<each T: Renderable>: Renderable {
    var items: (repeat each T)

    init(_ item: repeat each T) {
        self.items = (repeat (each item))
    }

    var boundingBox: MTLAxisAlignedBoundingBox {
        var result: MTLAxisAlignedBoundingBox = .empty
        for item in repeat (each items) {
            result.unite(with: item.boundingBox)
        }
        return result
    }

    func visitMaterials(_ reserver: inout MaterialReserver) {
        for item in repeat (each items) {
            item.visitMaterials(&reserver)
        }
    }

    func asImpl(_ encoder: inout MaterialEncoder) -> __UnionImpl<repeat (each T).Impl> {
        return __UnionImpl(items: (repeat (each items).asImpl(&encoder)))
    }
}

struct __IntersectionImpl<each T: RenderableImpl>: RenderableImpl {
    var items: (repeat each T)

    private static var count: Int {
        var result = 0
        for _ in repeat (each T).self {
            result += 1
        }
        return result
    }

    static var intersectionFunctionName: String {
        getIntersectionFunctionName(operation: "intersection\(Self.count)", operands: (repeat (each T).self))
    }
}

struct Intersection<each T: Renderable>: Renderable {
    var items: (repeat each T)

    init(_ item: repeat each T) {
        self.items = (repeat (each item))
    }

    var boundingBox: MTLAxisAlignedBoundingBox {
        var result: MTLAxisAlignedBoundingBox = .unlimited
        for item in repeat (each items) {
            result.intersect(with: item.boundingBox)
        }
        return result
    }

    func visitMaterials(_ reserver: inout MaterialReserver) {
        for item in repeat (each items) {
            item.visitMaterials(&reserver)
        }
    }

    func asImpl(_ encoder: inout MaterialEncoder) -> __IntersectionImpl<repeat (each T).Impl> {
        return __IntersectionImpl(items: (repeat (each items).asImpl(&encoder)))
    }
}
