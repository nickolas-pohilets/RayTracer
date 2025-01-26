//
//  SubtractTests.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 23/01/2025.
//
import XCTest

class SubtractTests: XCTestCase {
    let sut = CylinderDiff(
        __Cylinder(
            transform: __Transform(
                rotation: matrix_identity_float3x3,
                translation: .zero
            ),
            radius: 2,
            height: 4,
            bottom_material_offset: 5,
            top_material_offset: 7,
            side_material_offset: 9
        ),
        __Cylinder(
            transform: __Transform(
                rotation: matrix_identity_float3x3,
                translation: float3(0, 1, 0)
            ),
            radius: 1,
            height: 6,
            bottom_material_offset: 11,
            top_material_offset: 13,
            side_material_offset: 15
        )
    )

    func testABAB() {
        var e = CylinderDiff.HitEnumerator(sut, Ray3D(float3(0, -1, 0), float3(0, 1, 0)))
        XCTAssert(e.hasNext())
        XCTAssertEqual(e.isExit(), false)
        XCTAssertEqual(e.t(), 1, accuracy: .defaultTestAccuracy)
        XCTAssertAlmostEqualVectors(e.point(), float3(0, 0, 0))
        XCTAssertAlmostEqualVectors(e.normal(), float3(0, -1, 0))
        XCTAssertEqual(e.material_offset(), 5)
        XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.5, 0.5))
        e.move()
        XCTAssert(e.hasNext())
        XCTAssertEqual(e.isExit(), true)
        XCTAssertEqual(e.t(), 2.0, accuracy: .defaultTestAccuracy)
        XCTAssertAlmostEqualVectors(e.point(), float3(0, 1, 0))
        XCTAssertAlmostEqualVectors(e.normal(), float3(0, 1, 0))
        XCTAssertEqual(e.material_offset(), 11)
        XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.5, 0.5))
        e.move()
        XCTAssertFalse(e.hasNext())
    }

    func testBABA() {
        var e = CylinderDiff.HitEnumerator(sut, Ray3D(float3(0, 10, 0), float3(0, -1, 0)))
        XCTAssert(e.hasNext())
        XCTAssertEqual(e.isExit(), false)
        XCTAssertEqual(e.t(), 9, accuracy: .defaultTestAccuracy)
        XCTAssertAlmostEqualVectors(e.point(), float3(0, 1, 0))
        XCTAssertAlmostEqualVectors(e.normal(), float3(0, 1, 0))
        XCTAssertEqual(e.material_offset(), 11)
        XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.5, 0.5))
        e.move()
        XCTAssert(e.hasNext())
        XCTAssertEqual(e.isExit(), true)
        XCTAssertEqual(e.t(), 10, accuracy: .defaultTestAccuracy)
        XCTAssertAlmostEqualVectors(e.point(), float3(0, 0, 0))
        XCTAssertAlmostEqualVectors(e.normal(), float3(0, -1, 0))
        XCTAssertEqual(e.material_offset(), 5)
        XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.5, 0.5))
        e.move()
        XCTAssertFalse(e.hasNext())
    }

    func testABBA() {
        var e = CylinderDiff.HitEnumerator(sut, Ray3D(float3(0, 2, -5), float3(0, 0, 1)))
        XCTAssert(e.hasNext())
        XCTAssertEqual(e.isExit(), false)
        XCTAssertEqual(e.t(), 3, accuracy: .defaultTestAccuracy)
        XCTAssertAlmostEqualVectors(e.point(), float3(0, 2, -2))
        XCTAssertAlmostEqualVectors(e.normal(), float3(0, 0, -1))
        XCTAssertEqual(e.material_offset(), 9)
        XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.25, 0.5))
        e.move()
        XCTAssert(e.hasNext())
        XCTAssertEqual(e.isExit(), true)
        XCTAssertEqual(e.t(), 4, accuracy: .defaultTestAccuracy)
        XCTAssertAlmostEqualVectors(e.point(), float3(0, 2, -1))
        XCTAssertAlmostEqualVectors(e.normal(), float3(0, 0, +1))
        XCTAssertEqual(e.material_offset(), 15)
        XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.25, 1/6.0))
        e.move()
        XCTAssert(e.hasNext())
        XCTAssertEqual(e.isExit(), false)
        XCTAssertEqual(e.t(), 6, accuracy: .defaultTestAccuracy)
        XCTAssertAlmostEqualVectors(e.point(), float3(0, 2, +1))
        XCTAssertAlmostEqualVectors(e.normal(), float3(0, 0, -1))
        XCTAssertEqual(e.material_offset(), 15)
        XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.75, 1/6.0))
        e.move()
        XCTAssert(e.hasNext())
        XCTAssertEqual(e.isExit(), true)
        XCTAssertEqual(e.t(), 7, accuracy: .defaultTestAccuracy)
        XCTAssertAlmostEqualVectors(e.point(), float3(0, 2, +2))
        XCTAssertAlmostEqualVectors(e.normal(), float3(0, 0, +1))
        XCTAssertEqual(e.material_offset(), 9)
        XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.75, 0.5))
        e.move()
        XCTAssertFalse(e.hasNext())
    }

    func testAA() {
        var e = CylinderDiff.HitEnumerator(sut, Ray3D(float3(1.5, 2, 5), float3(0, 0, -1)))
        XCTAssert(e.hasNext())
        XCTAssertEqual(e.isExit(), false)
        XCTAssertEqual(e.t(), 3.6771245, accuracy: .defaultTestAccuracy)
        XCTAssertAlmostEqualVectors(e.point(), float3(1.5, 2, 1.3228755))
        XCTAssertAlmostEqualVectors(e.normal(), float3(0.75, 0, 0.6614377))
        XCTAssertEqual(e.material_offset(), 9)
        XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.88497335, 0.5))
        e.move()
        XCTAssert(e.hasNext())
        XCTAssertEqual(e.isExit(), true)
        XCTAssertEqual(e.t(), 6.3228755, accuracy: .defaultTestAccuracy)
        XCTAssertAlmostEqualVectors(e.point(), float3(1.5, 2, -1.3228755))
        XCTAssertAlmostEqualVectors(e.normal(), float3(0.75, 0, -0.6614377))
        XCTAssertEqual(e.material_offset(), 9)
        XCTAssertAlmostEqualVectors(e.texture_coordinates(), float2(0.11502672, 0.5))
        e.move()
        XCTAssertFalse(e.hasNext())
    }

    func testBB() {
        let e = CylinderDiff.HitEnumerator(sut, Ray3D(float3(0, 5, -5), float3(0, 0, 1)))
        XCTAssertFalse(e.hasNext())
    }

    func testCombo() {
        let box = __Cuboid(
            transform: __Transform(
                rotation: matrix_identity_float3x3,
                translation: float3(-1, -1, -1)
            ),
            size: float3(2, 2, 2),
            material_offset: (11, 12, 13, 14, 15, 16)
        )
        let sphere = __Sphere(
            transform: __Transform(
                rotation: matrix_identity_float3x3,
                translation: .zero
            ),
            radius: 1.2,
            material_offset: 21
        )
        let cyl = __Cylinder(
            transform: __Transform(
                rotation: matrix_identity_float3x3,
                translation: float3(0, -2, 0)
            ),
            radius: 0.5,
            height: 4,
            bottom_material_offset: 31,
            top_material_offset: 32,
            side_material_offset: 33
        )
        print(MemoryLayout<Combo>.size)
        print(MemoryLayout<Combo>.stride)
        print(MemoryLayout<Combo>.alignment)
        let sut = Combo(box, sphere, cyl)
        let e = Combo.HitEnumerator(sut, Ray3D(float3(0, 5, 0), float3(0, -1, 0)))
        XCTAssertFalse(e.hasNext())
    }
}
