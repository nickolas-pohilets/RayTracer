//
//  RayTracingKitTests.swift
//  RayTracingKitTests
//
//  Created by Mykola Pokhylets on 05/01/2025.
//

import Testing
@testable import RayTracingKit

struct TransformTests {
    @Test func testAABB() async throws {
        do {
            let tr = Transform3D(rotation: .init(degrees: 120, axis: Vector3D(axis: .z), normalized: true))
            let box = tr.boundingBox(for: Point3D(x: 10, y: 0, z: 0))
            #expect((box.size - Vector3D(x: 15, y: 10, z: 0)).lengthSquared < 1e10)
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
                #expect(box.contains(pi, threshold: 1e-6))
            }
        }
    }

}
