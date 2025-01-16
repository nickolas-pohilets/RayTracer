//
//  RenderableTests.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 15/01/2025.
//

import XCTest

class RenderableTests: XCTestCase {
    func testCylinderNoTransform() {
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
            var e = __Cylinder.HitEnumerator(sut, Ray3D(float3(0, -5, 0), float3(0, 1, 0)));
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 5.0, accuracy: 1e-6)
            XCTAssertAlmostEqualVectors(e.point(), float3(0, 0, 0))
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, -1, 0))
            XCTAssertEqual(e.material_offset(), 5)
            e.move()
            XCTAssert(e.hasNext())
            XCTAssertEqual(e.t(), 7.0, accuracy: 1e-6)
            XCTAssertAlmostEqualVectors(e.point(), float3(0, 2, 0));
            XCTAssertAlmostEqualVectors(e.normal(), float3(0, 1, 0))
            XCTAssertEqual(e.material_offset(), 7);
            e.move();
            XCTAssertFalse(e.hasNext());
        }

        do {
            let e = __Cylinder.HitEnumerator(sut, Ray3D(float3(1, -5, 1), float3(0, 1, 0)));
            XCTAssertFalse(e.hasNext());
        }

        do {
            var e = __Cylinder.HitEnumerator(sut, Ray3D(float3(-5, 1, 0), float3(1, 0, 0)));
            XCTAssert(e.hasNext());
            XCTAssertEqual(e.t(), 4.5, accuracy: 1e-6)
            XCTAssertEqual(e.point().x, -0.5, accuracy: 1e-6)
            XCTAssertEqual(e.point().y, 1, accuracy: 1e-6)
            XCTAssertEqual(e.point().z, 0, accuracy: 1e-6)
            XCTAssertEqual(e.normal().x, -1, accuracy: 1e-6)
            XCTAssertEqual(e.normal().y, 0, accuracy: 1e-6)
            XCTAssertEqual(e.normal().z, 0, accuracy: 1e-6)
            XCTAssertEqual(e.material_offset(), 9);
            e.move();
            XCTAssert(e.hasNext());
            XCTAssertEqual(e.t(), 5.5, accuracy: 1e-6)
            XCTAssertEqual(e.point().x, +0.5, accuracy: 1e-6)
            XCTAssertEqual(e.point().y, 1, accuracy: 1e-6)
            XCTAssertEqual(e.point().z, 0, accuracy: 1e-6)
            XCTAssertEqual(e.normal().x, 1, accuracy: 1e-6)
            XCTAssertEqual(e.normal().y, 0, accuracy: 1e-6)
            XCTAssertEqual(e.normal().z, 0, accuracy: 1e-6)
            XCTAssertEqual(e.material_offset(), 9);
            e.move();
            XCTAssertFalse(e.hasNext());
        }

        do {
            let e = __Cylinder.HitEnumerator(sut, Ray3D(float3(-5, -1, 0), float3(1, 0, 0)));
            XCTAssertFalse(e.hasNext());
        }

        do {
            let e = __Cylinder.HitEnumerator(sut, Ray3D(float3(-5, 3, 0), float3(1, 0, 0)));
            XCTAssertFalse(e.hasNext());
        }
    }

    func testCylinderTransform() {
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
            XCTAssert(e.hasNext());
            XCTAssertEqual(e.t(), 5.0, accuracy: 1e-6)
            XCTAssertEqual(e.point().x, 0, accuracy: 1e-6)
            XCTAssertEqual(e.point().y, 0, accuracy: 1e-6)
            XCTAssertEqual(e.point().z, 0, accuracy: 1e-6)
            XCTAssertEqual(e.normal().x, 0.866025, accuracy: 1e-6)
            XCTAssertEqual(e.normal().y, -0.5, accuracy: 1e-6)
            XCTAssertEqual(e.normal().z, 0, accuracy: 1e-6)
            do {
                let n = sut.transform.rotation * float3(0, -1, 0)

                XCTAssertEqual(e.normal().x, n.x, accuracy: 1e-6)
                XCTAssertEqual(e.normal().y, n.y, accuracy: 1e-6)
                XCTAssertEqual(e.normal().z, n.z, accuracy: 1e-6)
            }
            XCTAssertEqual(e.material_offset(), 5);
            e.move();
            XCTAssert(e.hasNext());
            XCTAssertEqual(e.t(), 5.57735, accuracy: 1e-6)
            XCTAssertEqual(e.point().x, 0, accuracy: 1e-6)
            XCTAssertEqual(e.point().y, 0.57735, accuracy: 1e-6)
            XCTAssertEqual(e.point().z, 0, accuracy: 1e-6)
            XCTAssertEqual(e.normal().x, 0.5, accuracy: 1e-6)
            XCTAssertEqual(e.normal().y, 0.866025, accuracy: 1e-6)
            XCTAssertEqual(e.normal().z, 0, accuracy: 1e-6)
            do {
                let n = sut.transform.rotation * float3(1, 0, 0);
                XCTAssertEqual(e.normal().x, n.x, accuracy: 1e-6)
                XCTAssertEqual(e.normal().y, n.y, accuracy: 1e-6)
                XCTAssertEqual(e.normal().z, n.z, accuracy: 1e-6)
            }
            XCTAssertEqual(e.material_offset(), 9);
            e.move();
            XCTAssertFalse(e.hasNext());
        }
    }
}

