//
//  SphereTests.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 23/01/2025.
//

import XCTest

func XCTAssertIsValidTextureCoord(_ x: Float, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssert(x > 0 - .defaultTestAccuracy && x < 1 + .defaultTestAccuracy, file: file, line: line)
}

class SphereTests: XCTestCase {
    func testNoTransform() {
        let sut = __Sphere(
            transform: __Transform(
                rotation: matrix_identity_float3x3,
                translation: .zero
            ),
            radius: 0.5,
            material_offset: 42
        )

        do {
            var e = __Sphere.HitEnumerator(sut, Ray3D(float3(0, -5, 0), float3(0, 1, 0)))
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 4.5, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(0, -0.5, 0))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, -1, 0))
            XCTAssertEqual(e.material_offset(), 42)
            XCTAssertIsValidTextureCoord(e.texture_coordinates().x)
            XCTAssertEqual(e.texture_coordinates().y, 0, accuracy: .defaultTestAccuracy)
            e.move()
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 5.5, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(0, +0.5, 0))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, +1, 0))
            XCTAssertEqual(e.material_offset(), 42)
            XCTAssertIsValidTextureCoord(e.texture_coordinates().x)
            XCTAssertEqual(e.texture_coordinates().y, 1, accuracy: .defaultTestAccuracy)
            e.move()
            XCTAssertFalse(e.hasNext())
        }

        do {
            let e = __Sphere.HitEnumerator(sut, Ray3D(float3(1, -5, 1), float3(0, 1, 0)))
            XCTAssert(!e.hasNext())
        }

        do {
            var e = __Sphere.HitEnumerator(sut, Ray3D(float3(2, 0, 0), float3(-1, 0, 0)))
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 1.5, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(0.5, 0, 0))
            XCTAssertAlmostEqualVectors(e.normal(), float3(1, 0, 0))
            XCTAssertEqual(e.material_offset(), 42)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(1.0, 0.5))
            e.move()
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 2.5, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(-0.5, 0, 0))
            XCTAssertAlmostEqualVectors(e.normal(), float3(-1, 0, 0))
            XCTAssertEqual(e.material_offset(), 42)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.5, 0.5))
            e.move()
            XCTAssertFalse(e.hasNext())
        }

        do {
            let sqrt_1_3: Float = sqrt(1/3)
            var e = __Sphere.HitEnumerator(sut, Ray3D(float3(-1, +1, -1), float3(+sqrt_1_3, -sqrt_1_3, +sqrt_1_3)))
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), sqrt(3) - 0.5, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(-sqrt_1_3, +sqrt_1_3, -sqrt_1_3) / 2)
            XCTAssertAlmostEqualVectors(e.normal(), float3(-sqrt_1_3, +sqrt_1_3, -sqrt_1_3))
            XCTAssertEqual(e.material_offset(), 42)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.375, 0.6959132760153036))
            e.move()
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), sqrt(3) + 0.5, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(+sqrt_1_3, -sqrt_1_3, +sqrt_1_3) / 2)
            XCTAssertAlmostEqualVectors(e.normal(), float3(+sqrt_1_3, -sqrt_1_3, +sqrt_1_3))
            XCTAssertEqual(e.material_offset(), 42)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.875, 0.3040867239846964))
            e.move()
            XCTAssertFalse(e.hasNext())
        }
    }

    func testTransform() {
        let q1 = simd_quatf(angle: Float(Double.pi / 3), axis: float3(0, 1, 0))
        let q2 = simd_quatf(angle: Float(Double.pi / 4), axis: float3(0, 0, 1))
        let sut = __Sphere(
            transform: __Transform(
                rotation: simd_matrix3x3(q2 * q1),
                translation: float3(1, 2, 3)
            ),
            radius: 0.5,
            material_offset: 42
        )

        do {
            var e = __Sphere.HitEnumerator(sut, Ray3D(float3(1, 2.3, -3), float3(0, 0, 1)))
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 5.6, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(1, 2.3, 2.6))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, 0.6, -0.8))
            XCTAssertEqual(e.material_offset(), 42)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.005726772, 0.6394671))
            e.move()
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 6.4, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(1, 2.3, 3.4))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, 0.6, +0.8))
            XCTAssertEqual(e.material_offset(), 42)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.66093993, 0.6394671))
            e.move()
            XCTAssertFalse(e.hasNext())
        }
    }
}
