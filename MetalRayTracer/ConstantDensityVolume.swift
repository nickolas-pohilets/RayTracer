//
//  ConstantDensityVolume.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 28/01/2025.
//

struct __ConstantDensityVolumeImpl<Base: RenderableImpl>: RenderableImpl {
    var base: Base
    var density: Float

    static var intersectionFunctionName: String {
        getIntersectionFunctionName(operation: "cdv", operands: (Base.self))
    }
}

struct ConstantDensityVolume<Base: Renderable>: Renderable {
    var base: Base
    var density: Float

    var boundingBox: MTLAxisAlignedBoundingBox {
        base.boundingBox
    }

    func visitMaterials(_ reserver: inout MaterialReserver) {
        base.visitMaterials(&reserver)
    }

    func asImpl(_ encoder: inout MaterialEncoder) -> __ConstantDensityVolumeImpl<Base.Impl> {
        let baseImpl = base.asImpl(&encoder)
        return __ConstantDensityVolumeImpl(base: baseImpl, density: density)
    }
}
