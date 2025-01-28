//
//  ConstantDensityVolumeTests.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 28/01/2025.
//
import XCTest

class ConstantDensityVolumeTests: XCTestCase {
    func testNoTransform() {
        let sut = CuboidFog(
            __Cuboid(
                transform: __Transform(
                    rotation: matrix_identity_float3x3,
                    translation: .zero
                ),
                size: float3(2, 3, 4),
                material_offset: (5, 7, 9, 11, 13, 15)
            ),
            0.5
        )

        do {
            var rng = RNG([0.5])
            var e = CuboidFog.HitEnumerator(sut, Ray3D(float3(3, 1.5, 3), float3(-0.70710678, 0, -0.70710678)), &rng)
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 2.800508, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(1.0197418, 1.5, 1.0197418))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0.70710677, 0.0, 0.70710677))
            XCTAssertEqual(e.material_offset(), 7)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.5, 0.5))
            e.move()
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 4.242641, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(0, 1.5, 0))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, 0, -1))
            XCTAssertEqual(e.material_offset(), 13)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(1.0, 0.5))
            e.move()
            XCTAssertFalse(e.hasNext())
        }

        do {
            var rng = RNG([0.756884]) //0.75688328866334664
            let e = CuboidFog.HitEnumerator(sut, Ray3D(float3(3, 1.5, 3), float3(-0.70710678, 0, -0.70710678)), &rng)
            XCTAssertFalse(e.hasNext())
        }

        do {
            var rng = RNG([(1 as Float).nextDown])
            let e = CuboidFog.HitEnumerator(sut, Ray3D(float3(3, 1.5, 3), float3(-0.70710678, 0, -0.70710678)), &rng)
            XCTAssertFalse(e.hasNext())
        }

        do {
            var rng = RNG([0.0])
            let e = CuboidFog.HitEnumerator(sut, Ray3D(float3(3, 1.5, 3), float3(-0.70710678, 0, -0.70710678)), &rng)
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 1.41421356, accuracy: .defaultTestAccuracy)
        }
    }
}
