//
//  Config.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 11/01/2025.
//
import Metal

struct CameraConfig: Hashable {
    var impl: __CameraConfig

    struct RelativePosition {
        var yaw: Float
        var pitch: Float
        var distance: Float
    }

    init(
        verticalFOV: Float = 90,
        lookFrom: vector_float3 = [0, 0, 0],
        lookAt: vector_float3 = [0, 0, -1],
        up: vector_float3 = [0, 1, 0],
        defocusAngle: Float = 0, // Variation angle of rays through each pixel
        focusDistance: Float? = nil,
        background: BackgroundLighting = .background_lighting_sky
    ) {
        impl = .init(
            vertical_FOV: verticalFOV,
            look_from: lookFrom,
            look_at: lookAt,
            up: up,
            defocus_angle: defocusAngle,
            focus_distance: focusDistance ?? length(lookFrom - lookAt),
            background: background
        )
    }

    var verticalFOV: Float {
        get { impl.vertical_FOV }
        set { impl.vertical_FOV = newValue }
    }

    var relativePosition: RelativePosition {
        get {
            let v = impl.look_from - impl.look_at
            let d = length(v)
            let yaw = atan2(v.z, v.x) * 180 / .pi
            let pitch = atan2(v.y, sqrt(v.x * v.x + v.z * v.z)) * 180 / .pi
            return RelativePosition(yaw: yaw, pitch: pitch, distance: d)
        }
        set {
            let y = sin(newValue.pitch * .pi / 180)
            let h = cos(newValue.pitch * .pi / 180)
            let x = h * cos(newValue.yaw * .pi / 180)
            let z = h * sin(newValue.yaw * .pi / 180)
            let v = vector_float3(x, y, z) * newValue.distance
            impl.look_from = impl.look_at + v
        }
    }

    var defocusAngle: Float {
        get { impl.defocus_angle }
        set { impl.defocus_angle = newValue }
    }

    var focusDistance: Float {
        get { impl.focus_distance }
        set { impl.focus_distance = newValue }
    }
}

struct RenderConfig {
    var impl: __RenderConfig

    init(
        samplesPerPixel: Int = 10,
        maxDepth: Int = 10,
        passCounter: Int,
        rngSeed: UInt64
    ) {
        impl = .init(
            samples_per_pixel: UInt32(samplesPerPixel),
            max_depth: UInt32(maxDepth),
            pass_counter: UInt32(passCounter),
            rng_seed: rngSeed
        )
    }
}

extension __CameraConfig: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(vertical_FOV)
        hasher.combine(look_from)
        hasher.combine(look_at)
        hasher.combine(defocus_angle)
        hasher.combine(focus_distance)
    }
    
    public static func == (lhs: __CameraConfig, rhs: __CameraConfig) -> Bool {
        return lhs.vertical_FOV == rhs.vertical_FOV
            && lhs.look_from == rhs.look_from
            && lhs.look_at == rhs.look_at
            && lhs.up == rhs.up
            && lhs.defocus_angle == rhs.defocus_angle
            && lhs.focus_distance == rhs.focus_distance
    }
}


