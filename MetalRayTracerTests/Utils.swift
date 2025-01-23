//
//  Utils.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 15/01/2025.
//
import XCTest

extension BinaryFloatingPoint {
    static var defaultTestAccuracy: Self {
        Self(1) / Self(1 << (7 * Self.significandBitCount / 8))
    }
}

protocol _Dist: SIMD {
    static func chebyshevDistance(_ a: Self, _ b: Self) -> Scalar
}

extension SIMD2<Float>: _Dist {
    static func chebyshevDistance(_ a: Self, _ b: Self) -> Float {
        return reduce_max(abs(a - b))
    }
}

extension SIMD3<Float>: _Dist {
    static func chebyshevDistance(_ a: Self, _ b: Self) -> Float {
        return reduce_max(abs(a - b))
    }
}

extension SIMD4<Float>: _Dist {
    static func chebyshevDistance(_ a: Self, _ b: Self) -> Float {
        return reduce_max(abs(a - b))
    }
}

func XCTAssertAlmostEqualVectors<V: _Dist>(_ a: V, _ b: V, accuracy: Float = .defaultTestAccuracy, message: String = "", file: StaticString = #filePath, line: UInt = #line) where V.Scalar == Float {
    let delta = V.chebyshevDistance(a, b)
    XCTAssertEqual(delta, 0, accuracy: accuracy, "Bla-bla-bla")
    if delta > accuracy {
        var msg = "XCTAssertAlmostEqualVectors failed: (\"\(a.description)\") is not equal to (\"\(b.description)\") +/- (\"\(accuracy)\")"
        if !message.isEmpty {
            msg += " - "
            msg += message
        }
        XCTFail(msg, file: file, line: line)
    }
}


class UtilsTests: XCTestCase {
    func testDefaultAccuracy() {
        let f = Float.defaultTestAccuracy
        XCTAssertLessThanOrEqual(f, 1e-6)
        XCTAssertLessThanOrEqual(1e-7, f)
        let d = Double.defaultTestAccuracy
        XCTAssertLessThanOrEqual(d, 1e-13)
        XCTAssertLessThanOrEqual(1e-14, d)
    }
}
