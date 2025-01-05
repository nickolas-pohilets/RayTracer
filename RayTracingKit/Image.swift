//
//  Image.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//
import Foundation
import UniformTypeIdentifiers
import CoreGraphics

public struct ColorU8 {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    private var _padding: UInt8 = 0

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    public static var black: Self { .init(r: .zero, g: .zero, b: .zero) }
    public static var white: Self { .init(r: .max, g: .max, b: .max) }

    public var asF: ColorF {
        ColorF(x: Double(r), y: Double(g), z: Double(b)) / 255.0
    }
}

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

public struct Image {
    public let width: Int
    public let height: Int
    private var data: [ColorU8]

    public init(width: Int, height: Int, fillColor: ColorU8 = .black) {
        self.width = width
        self.height = height
        self.data = [ColorU8].init(repeating: fillColor, count: width * height)
    }

    public subscript(_ i: Int, _ j: Int) -> ColorU8 {
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
        assert(i >= 0 && i < height)
    }

    mutating func withContext<R>(_ block: (CGContext) throws -> R) rethrows -> R {
        try data.withUnsafeMutableBufferPointer { buffer in
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * MemoryLayout<ColorU8>.stride,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue
            )!
            return try block(context)
        }
    }

    public func writePPM<Target: TextOutputStream>(to target: inout Target) {
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

    public func writePPM(to url: URL) throws {
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

extension Image {
    public static func load(url: URL) throws -> Image {
        let cgImage = try CGImage.load(url: url)
        var image = Image(width: cgImage.width, height: cgImage.height)
        image.withContext { cgContext in
            cgContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        }
        return image
    }
}

private extension CGImage {
    static func load(url: URL) throws -> CGImage {
        let image: CGImage?
        let uti = UTType(filenameExtension: url.pathExtension)
        switch uti {
        case .some(.jpeg):
            image = CGImage(
                jpegDataProviderSource: try getDataProvider(url: url),
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        case .some(.png):
            image = CGImage(
                pngDataProviderSource: try getDataProvider(url: url),
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        default:
            throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError)
        }
        guard let image else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError)
        }
        return image
    }
}

private func getDataProvider(url: URL) throws -> CGDataProvider {
    guard let dataProvider = CGDataProvider(url: url as CFURL) else {
        throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError)
    }
    return dataProvider
}
