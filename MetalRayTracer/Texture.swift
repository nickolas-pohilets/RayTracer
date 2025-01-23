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
