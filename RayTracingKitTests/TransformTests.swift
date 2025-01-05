//
//  RayTracingKitTests.swift
//  RayTracingKitTests
//
//  Created by Mykola Pokhylets on 05/01/2025.
//

import Testing
@testable import RayTracingKit

private let eps: Double = 1e-6

struct TransformTests {
    @Test func testInverse() {
        do {
            let tr = Transform3D.rotation(degrees: 72, axis: .y)
            #expect(tr.inverse == .rotation(degrees: -72, axis: .y))
        }
        do {
            let tr = Transform3D.translation(x: 1, y: 2, z: 3)
            #expect(tr.inverse == .translation(x: -1, y: -2, z: -3))
        }
        do {
            let tr = Transform3D(rotation: .init(degrees: 72, axis: .y), translation: .init(x: 1, y: 2, z: 3))
            let trInv = tr.inverse
            let p = Point3D(x: 10, y: 2, z: -1)
            let pT = tr.transform(p)
            let pRec = trInv.transform(pT)
            #expect((p - pRec).lengthSquared < eps * eps)
        }
    }
    @Test func testAABB() {
        do {
            let tr = Transform3D(rotation: .init(degrees: 120, axis: Vector3D(axis: .z), normalized: true))
            let box = tr.boundingBox(for: Point3D(x: 10, y: 0, z: 0))
            #expect((box.size - Vector3D(x: 15, y: 10, z: 0)).lengthSquared < eps * eps)
        }
        do {
            let tr = Transform3D(
                rotation: .init(degrees: 120, axis: Vector3D(axis: .z), normalized: true),
                translation: Vector3D(x: -5, y: -5, z: 0)
            )
            let p = Point3D(x: 10, y: 0, z: 0)
            let box = tr.boundingBox(for: p)
            for i in 0..<100 {
                let t = Double(i) * 0.01
                let tri = tr.pow(t)
                let pi = tri.transform(p)
                #expect(box.contains(pi, threshold: eps))
            }
        }
    }
}
