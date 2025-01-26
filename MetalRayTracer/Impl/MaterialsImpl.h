//
//  MaterialsImpl.h
//  RayTracing
//
//  Created by Mykola Pokhylets on 14/01/2025.
//

#ifndef MATERIALS_IMPL_H
#define MATERIALS_IMPL_H

#include "../Materials.h"
#include "HitTesting.h"
#include "RNG.h"
#include "Defines.h"

float reflectance(float cosθ, float ηRatio) {
    // Use Schlick's approximation for reflectance.
    float sqR0 = ((1 - ηRatio) / (1 + ηRatio));
    float R0 = sqR0 * sqR0;
    float x = (1 + cosθ); // In our case cosθ is inverted
    float x2 = x * x;
    float x4 = x2 * x2;
    return R0 + (1 - R0) * (x4 * x);
}

bool refract(float3 v, float3 normal, float ηRatio, float reflectance_random, thread float3 & result) {
    float cosθ = fmax(dot(v, normal), -1);
    float3 rPerp = ηRatio * (v - cosθ * normal);
    float rPerpLenSq = length_squared(rPerp);
    if (rPerpLenSq > 1) { return false; }
    if (reflectance_random <= 0) { return false; }
    if (reflectance_random < 1) {
        float r = reflectance(cosθ, ηRatio);
        if (r > reflectance_random) { return false; }
    }
    float3 rParallel = normal * -(sqrt(1 - rPerpLenSq));
    result = rPerp + rParallel;
    return true;
}

float3 refract_or_reflect(float3 v, float3 normal, float ηRatio, float reflectance_random) {
    float3 result;
    if (refract(v, normal, ηRatio, reflectance_random, result)) {
        return result;
    }
    return reflect(v, normal);
}

vector_float3 get_color(SolidColor color, vector_float2 coords) {
    return color;
}

float3 get_color(ImageTexture texture, vector_float2 coords) {
    static_assert(sizeof(texture.texture) == sizeof(MTLResourceID), "Bad texture size");
    static_assert(__alignof(texture.texture) == __alignof(MTLResourceID), "Bad texture alignment");
    constexpr sampler s(coord::normalized, filter::nearest);
    return texture.texture.sample(s, coords).rgb;
}

struct material_result {
    float3 emitted;
    float3 attenuation;
    Ray3D scattered;
};

template<class LambertianMaterial>
bool lambertian_scatter(constant LambertianMaterial const * material, Ray3D ray, Payload payload, thread RNG* rng, thread material_result & result) {
    result.emitted = 0;
    while (true) {
        float3 d = payload.normal + rng->random_unit_vector_3d();
        float lenSq = length_squared(d);
        if (lenSq > min_vector_length_squared) {
            float3 direction = d / sqrt(lenSq);
            result.scattered = Ray3D(payload.point, direction);
            break;
        }
    }
    result.attenuation = get_color(material->albedo, payload.texture_coordinates);
    return true;
}

template<class MetalMaterial>
bool metal_scatter(constant MetalMaterial const * material, Ray3D ray, Payload payload, thread RNG* rng, thread material_result & result) {
    result.emitted = 0;
    float3 reflected = reflect(ray.direction, payload.normal) + material->fuzz * rng->random_unit_vector_3d();
    if (dot(reflected, payload.normal) < 0) { return false; }
    result.attenuation = get_color(material->albedo, payload.texture_coordinates);
    result.scattered = Ray3D(payload.point, normalize(reflected));
    return true;
}

bool dielectric_scatter(constant DielectricMaterial const * material, Ray3D ray, Payload payload, thread RNG* rng, thread material_result & result) {
    result.emitted = 0;
    float ηRatio = payload.face == face::front ? 1.0 / material->refraction_index : material->refraction_index;
    float3 refracted = refract_or_reflect(ray.direction, payload.normal, ηRatio, rng->random_f());
    result.attenuation = 1;
    result.scattered = Ray3D(payload.point, refracted);
    return true;
}

bool emissive_scatter(constant ColoredEmissiveMaterial const * material, Ray3D ray, Payload payload, thread RNG* rng, thread material_result & result) {
    result.emitted = material->albedo;
    return false;
}

bool scatter(constant void const * material, Ray3D ray, Payload payload, thread RNG* rng, thread material_result & result) {
    MaterialKind kind = *reinterpret_cast<constant MaterialKind const*>(material);
    switch (kind) {
        case material_kind_lambertian_colored:
            return lambertian_scatter(reinterpret_cast<constant ColoredLambertianMaterial const *>(material), ray, payload, rng, result);
        case material_kind_lambertian_textured:
            return lambertian_scatter(reinterpret_cast<constant TexturedLambertianMaterial const *>(material), ray, payload, rng, result);
        case material_kind_metal_colored:
            return metal_scatter(reinterpret_cast<constant ColoredMetalMaterial const *>(material), ray, payload, rng, result);
        case material_kind_metal_textured:
            return metal_scatter(reinterpret_cast<constant TexturedMetalMaterial const *>(material), ray, payload, rng, result);
        case material_kind_dielectric:
            return dielectric_scatter(reinterpret_cast<constant DielectricMaterial const *>(material), ray, payload, rng, result);
        case material_kind_emissive_colored:
            return emissive_scatter(reinterpret_cast<constant ColoredEmissiveMaterial const *>(material), ray, payload, rng, result);
    }
}

#endif // MATERIALS_IMPL_H
