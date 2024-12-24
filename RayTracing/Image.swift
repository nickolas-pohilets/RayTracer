//
//  Image.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//
import Foundation

struct Color<T> {
    var r: T
    var g: T
    var b: T
}

extension Color where T: Numeric {
    static var black: Self { .init(r: .zero, g: .zero, b: .zero) }
}

extension Color where T: UnsignedInteger, T: FixedWidthInteger {
    static var white: Self { .init(r: .max, g: .max, b: .max) }
}

typealias ColorU8 = Color<UInt8>

extension OutputStream: @retroactive TextOutputStream {
    public func write(_ string: String) {
        var tmp = string
        tmp.withUTF8 { buffer in
            if let baseAddress = buffer.baseAddress, buffer.count > 0 {
                let n = self.write(baseAddress, maxLength: buffer.count)
                assert(n == buffer.count, "Unexpected IO error: \(self.streamError?.localizedDescription ?? "<unknown>")")
            }
        }
    }
}

struct Image {
    let width: Int
    var height: Int { data.count / width }
    private var data: [ColorU8]

    init(width: Int, height: Int, fillColor: ColorU8 = .black) {
        self.width = width
        self.data = [ColorU8].init(repeating: fillColor, count: width * height)
    }

    subscript(_ i: Int, _ j: Int) -> Color<UInt8> {
        get {
            checkBounds(i, j)
            return data[i * width + j]
        }
        set {
            checkBounds(i, j)
            data[i * width + j] = newValue
        }
    }

    private func checkBounds(_ i: Int, _ j : Int) {
        assert(j >= 0 && j < width)
        assert(i >= 0 && i * width < data.count)
    }

    func writePPM<Target: TextOutputStream>(to target: inout Target) {
        print("P3", to: &target)
        print(width, height, to: &target)
        print(255, to: &target)

        for i in 0..<height {
            for j in 0..<width {
                let c = self[i, j]
                print(c.r, c.g, c.b, to: &target)
            }
        }
    }

    func writePPM(to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let stream = OutputStream(url: url, append: false) {
            var s = stream
            s.open()
            if let error = s.streamError {
                throw error
            }
            writePPM(to: &s)
            if let error = s.streamError {
                throw error
            }
            s.close()
            if let error = s.streamError {
                throw error
            }
        }
    }
}
