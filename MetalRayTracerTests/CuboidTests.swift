//
//  CuboidTests.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 23/01/2025.
//
import XCTest

class CuboidTests: XCTestCase {
    func testNoTransform() {
        let sut = __Cuboid(
            transform: __Transform(
                rotation: matrix_identity_float3x3,
                translation: .zero
            ),
            size: float3(2, 3, 4),
            material_offset: (5, 7, 9, 11, 13, 15)
        )

        do {
            var e = __Cuboid.HitEnumerator(sut, Ray3D(float3(-1, 1.2, 2.8), float3(1, 0, 0)))
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 1, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(0, 1.2, 2.8))
            XCTAssertAlmostEqualVectors(e.normal(), float3(-1, 0, 0))
            XCTAssertEqual(e.material_offset(), 5)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.3, 0.4))
            e.move()
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 3, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(2, 1.2, 2.8))
            XCTAssertAlmostEqualVectors(e.normal(), float3(+1, 0, 0))
            XCTAssertEqual(e.material_offset(), 7)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.7, 0.4))
            e.move()
            XCTAssertFalse(e.hasNext())
        }

        do {
            var e = __Cuboid.HitEnumerator(sut, Ray3D(float3(1.2, 2.7, -1), float3(0, 0, 1)))
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 1, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(1.2, 2.7, 0))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, 0, -1))
            XCTAssertEqual(e.material_offset(), 13)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.4, 0.9))
            e.move()
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 5, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(1.2, 2.7, 4))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, 0, +1))
            XCTAssertEqual(e.material_offset(), 15)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.6, 0.9))
            e.move()
            XCTAssertFalse(e.hasNext())
        }

        do {
            var e = __Cuboid.HitEnumerator(sut, Ray3D(float3(1.4, -1, 1.6), float3(0, 1, 0)))
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 1, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(1.4, 0, 1.6))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, -1, 0))
            XCTAssertEqual(e.material_offset(), 9)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.7, 0.6))
            e.move()
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 4, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(1.4, 3, 1.6))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, +1, 0))
            XCTAssertEqual(e.material_offset(), 11)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.7, 0.4))
            e.move()
            XCTAssertFalse(e.hasNext())
        }

        do {
            let e = __Cuboid.HitEnumerator(sut, Ray3D(float3(-1, -1, -1), float3(1, 0, 0)))
            XCTAssertFalse(e.hasNext())
        }
        do {
            let e = __Cuboid.HitEnumerator(sut, Ray3D(float3(-1, -1, -1), float3(0, 1, 0)))
            XCTAssertFalse(e.hasNext())
        }
        do {
            let e = __Cuboid.HitEnumerator(sut, Ray3D(float3(-1, -1, -1), float3(0, 0, 1)))
            XCTAssertFalse(e.hasNext())
        }

        do {
            let e = __Cuboid.HitEnumerator(sut, Ray3D(float3(10, 10, 10), float3(-1, 0, 0)))
            XCTAssertFalse(e.hasNext())
        }
        do {
            let e = __Cuboid.HitEnumerator(sut, Ray3D(float3(10, 10, 10), float3(0, -1, 0)))
            XCTAssertFalse(e.hasNext())
        }
        do {
            let e = __Cuboid.HitEnumerator(sut, Ray3D(float3(10, 10, 10), float3(0, 0, -1)))
            XCTAssertFalse(e.hasNext())
        }
    }

    func testTransform() {
        let q1 = simd_quatf(angle: Float(Double.pi / 3), axis: float3(0, 1, 0))
        let q2 = simd_quatf(angle: Float(Double.pi / 4), axis: float3(0, 0, 1))

        let sut = __Cuboid(
            transform: __Transform(
                rotation: simd_matrix3x3(q2 * q1),
                translation: float3(1, 2, 3)
            ),
            size: float3(2, 3, 4),
            material_offset: (5, 7, 9, 11, 13, 15)
        )

        do {
            var e = __Cuboid.HitEnumerator(sut, Ray3D(float3(1.4, -1, 1.6), float3(0, 1, 0)))
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 3.7430952, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(1.4, 2.7430952, 1.6))
            XCTAssertAlmostEqualVectors(e.normal(), float3(-0.61237234, -0.61237246, -0.5))
            XCTAssertEqual(e.material_offset(), 13)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.19170964, 0.08086828))
            e.move()
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 4.827569, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(1.4, 3.827569, 1.6))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0.35355335, 0.3535534, -0.8660254))
            XCTAssertEqual(e.material_offset(), 7)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.16602547, 0.3364812))
            e.move()
            XCTAssertFalse(e.hasNext())
        }
    }
}
