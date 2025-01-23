//
//  CylinderTests.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 15/01/2025.
//

import XCTest

class CylinderTests: XCTestCase {
    func testNoTransform() {
        let sut = __Cylinder(
            transform: __Transform(
                rotation: matrix_identity_float3x3,
                translation: .zero
            ),
            radius: 0.5,
            height: 2,
            bottom_material_offset: 5,
            top_material_offset: 7,
            side_material_offset: 9
        )

        do {
            var e = __Cylinder.HitEnumerator(sut, Ray3D(float3(0, -5, 0), float3(0, 1, 0)))
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.isExit(), false)
            XCTAssertEqual(e.t(), 5.0, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(0, 0, 0))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, -1, 0))
            XCTAssertEqual(e.material_offset(), 5)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.5, 0.5))
            e.move()
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.isExit(), true)
            XCTAssertEqual(e.t(), 7.0, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(0, 2, 0))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, 1, 0))
            XCTAssertEqual(e.material_offset(), 7)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.5, 0.5))
            e.move()
            XCTAssertFalse(e.hasNext())
        }

        do {
            var e = __Cylinder.HitEnumerator(sut, Ray3D(float3(0.25, -5, 0.25), float3(0, 1, 0)))
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.isExit(), false)
            XCTAssertEqual(e.t(), 5.0, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(0.25, 0, 0.25))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, -1, 0))
            XCTAssertEqual(e.material_offset(), 5)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.25, 0.75))
            e.move()
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.isExit(), true)
            XCTAssertEqual(e.t(), 7.0, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(0.25, 2, 0.25))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, 1, 0))
            XCTAssertEqual(e.material_offset(), 7)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.75, 0.75))
            e.move()
            XCTAssertFalse(e.hasNext())
        }

        do {
            var e = __Cylinder.HitEnumerator(sut, Ray3D(float3(-0.25, -5, -0.25), float3(0, 1, 0)))
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.isExit(), false)
            XCTAssertEqual(e.t(), 5.0, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(-0.25, 0, -0.25))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, -1, 0))
            XCTAssertEqual(e.material_offset(), 5)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.75, 0.25))
            e.move()
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.isExit(), true)
            XCTAssertEqual(e.t(), 7.0, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(-0.25, 2, -0.25))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, 1, 0))
            XCTAssertEqual(e.material_offset(), 7)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.25, 0.25))
            e.move()
            XCTAssertFalse(e.hasNext())
        }

        do {
            let e = __Cylinder.HitEnumerator(sut, Ray3D(float3(1, -5, 1), float3(0, 1, 0)))
            XCTAssertFalse(e.hasNext())
        }

        do {
            var e = __Cylinder.HitEnumerator(sut, Ray3D(float3(-5, 1, 0), float3(1, 0, 0)))
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.isExit(), false)
            XCTAssertEqual(e.t(), 4.5, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(-0.5, 1, 0))
            XCTAssertAlmostEqualVectors(e.normal(), float3(-1, 0, 0))
            XCTAssertEqual(e.material_offset(), 9)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.5, 0.5))
            e.move()
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.isExit(), true)
            XCTAssertEqual(e.t(), 5.5, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(+0.5, 1, 0))
            XCTAssertAlmostEqualVectors(e.normal(), float3(+1, 0, 0))
            XCTAssertEqual(e.material_offset(), 9)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(1.0, 0.5))
            e.move()
            XCTAssertFalse(e.hasNext())
        }

        do {
            var e = __Cylinder.HitEnumerator(sut, Ray3D(float3(0, 0.5, +5), float3(0, 0, -1)))
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.isExit(), false)
            XCTAssertEqual(e.t(), 4.5, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(0, 0.5, +0.5))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, 0, +1))
            XCTAssertEqual(e.material_offset(), 9)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.75, 0.25))
            e.move()
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.isExit(), true)
            XCTAssertEqual(e.t(), 5.5, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(0, 0.5, -0.5))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, 0, -1))
            XCTAssertEqual(e.material_offset(), 9)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.25, 0.25))
            e.move()
            XCTAssertFalse(e.hasNext())
        }

        do {
            let e = __Cylinder.HitEnumerator(sut, Ray3D(float3(-5, -1, 0), float3(1, 0, 0)))
            XCTAssertFalse(e.hasNext())
        }

        do {
            let e = __Cylinder.HitEnumerator(sut, Ray3D(float3(-5, 3, 0), float3(1, 0, 0)))
            XCTAssertFalse(e.hasNext())
        }
    }

    func testTransform() {
        let angle = Float(Double.pi / 3)
        let q = simd_quatf(angle: angle, axis: float3(0, 0, 1))
        let sut = __Cylinder(
            transform: __Transform(
                rotation: simd_matrix3x3(q),
                translation: .zero
            ),
            radius: 0.5,
            height: 2,
            bottom_material_offset: 5,
            top_material_offset: 7,
            side_material_offset: 9
        )

        do {
            var e = __Cylinder.HitEnumerator(sut, Ray3D(float3(0, -5, 0), float3(0, 1, 0)))
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.isExit(), false)
            XCTAssertEqual(e.t(), 5.0, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(0, 0, 0))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0.866025, -0.5, 0))
            do {
                let n = sut.transform.rotation * float3(0, -1, 0)
                XCTAssertAlmostEqualVectors(e.normal(), n)
            }
            XCTAssertEqual(e.material_offset(), 5)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.5, 0.5))
            e.move()
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.isExit(), true)
            XCTAssertEqual(e.t(), 5.57735, accuracy: .defaultTestAccuracy)
            XCTAssertAlmostEqualVectors(e.point(), float3(0, 0.57735, 0))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0.5, 0.866025, 0))
            do {
                let n = sut.transform.rotation * float3(1, 0, 0)
                XCTAssertAlmostEqualVectors(e.normal(), n)
            }
            XCTAssertEqual(e.material_offset(), 9)
            XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(1.0, 0.14433756))
            e.move()
            XCTAssertFalse(e.hasNext())
        }
    }
}

