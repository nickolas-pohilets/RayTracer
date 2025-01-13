//
//  Config.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 11/01/2025.
//
import Metal

struct CameraConfig {
    var impl: __CameraConfig

    init(
        verticalFOV: Float = 90,
        lookFrom: vector_float3 = [0, 0, 0],
        lookAt: vector_float3 = [0, 0, -1],
        up: vector_float3 = [0, 1, 0],
        defocusAngle: Float = 0, // Variation angle of rays through each pixel
        focusDistance: Float? = nil
    ) {
        impl = .init(
            vertical_POV: verticalFOV,
            look_from: lookFrom,
            look_at: lookAt,
            up: up,
            defocus_angle: defocusAngle,
            focus_distance: focusDistance ?? length(lookFrom - lookAt)
        )
    }
}

struct RenderConfig {
    var impl: __RenderConfig

    init(
        samplesPerPixel: Int = 10,
        maxDepth: Int = 10
    ) {
        impl = .init(samples_per_pixel: UInt32(samplesPerPixel), max_depth: UInt32(maxDepth))
    }
}


