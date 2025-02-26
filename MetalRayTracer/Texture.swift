//
//  Texture.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 21/01/2025.
//

import Metal
import MetalKit

class TextureLoader {
    private(set) var textures: [ImageTexture: MTLTexture] = [:]
    private var placeholderTexture: MTLTexture?
    private let mtkLoader: MTKTextureLoader

    init(device: MTLDevice) {
        mtkLoader = MTKTextureLoader(device: device)
    }

    func load(_ texture: ImageTexture) -> MTLTexture {
        if let existing = textures[texture] {
            return existing
        }
        let new = doLoad(texture)
        textures[texture] = new
        return new
    }

    func doLoad(_ texture: ImageTexture) -> MTLTexture {
        guard let url = Bundle.main.url(forResource: texture.name, withExtension: nil) else {
            return getPlaceholder()
        }

        do {
            return try mtkLoader.newTexture(URL: url, options: [
                .origin: MTKTextureLoader.Origin.bottomLeft
            ])
        } catch {
            return getPlaceholder()
        }
    }

    func getPlaceholder() -> MTLTexture {
        if let placeholderTexture { return placeholderTexture }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 1, height: 1, mipmapped: false)
        let texture = mtkLoader.device.makeTexture(descriptor: descriptor)!
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: 1, height: 1, depth: 1))
        var magenta: UInt32 = 0xff_ff_00_ff
        withUnsafeBytes(of: &magenta) { buffer in
            texture.replace(region: region, mipmapLevel: 0, withBytes: buffer.baseAddress!, bytesPerRow: 4)
        }
        self.placeholderTexture = texture
        return texture
    }
}

public struct ImageTexture: Hashable {
    var name: String
}


extension PerlinNoiseTexture {
    static func generate(from color0: vector_float3, to color1: vector_float3, frequency: Float = 1.0, turbulence: Int = 0, using rng: inout some RandomNumberGenerator) -> Self {
        var result = Self()
        result.colors = (color0, color1)
        result.frequency = frequency
        result.turbulence = UInt32(turbulence)
        withUnsafeMutableBytes(of: &result.vectors) { buffer in
            buffer.withMemoryRebound(to: vector_float3.self) { ptr in
                for i in 0..<ptr.count {
                    ptr[i] = rng.nextUnitVector()
                }
            }
        }
        withUnsafeMutableBytes(of: &result.permutations) { buffer in
            buffer.withMemoryRebound(to: UInt8.self) { ptr in
                assert(ptr.count == 3 * 256)
                for i in 0..<256 {
                    ptr[i] = UInt8(i)
                    ptr[256 + i] = UInt8(i)
                    ptr[512 + i] = UInt8(i)
                }
                for i in 0..<3 {
                    var px = UnsafeMutableBufferPointer(start: ptr.baseAddress! + 256 * i, count: 256)
                    px.shuffle(using: &rng)
                }
            }
        }
        return result
    }
}

extension RandomNumberGenerator {
    mutating func nextUnitVector() -> vector_float3 {
        while (true) {
            var x = Float.random(in: -1...1, using: &self)
            var y = Float.random(in: -1...1, using: &self)
            var z = Float.random(in: -1...1, using: &self)
            var v = vector_float3(x, y, z)
            if length_squared(v) <= 1 {
                return v
            }
        }
    }
}
