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

bool lambertian_scatter(constant LambertianMaterial const * material, Ray3D ray, Payload payload, thread RNG* rng, thread float3 & attenuation, thread Ray3D & scattered) {
    while (true) {
        float3 d = payload.normal + rng->random_unit_vector_3d();
        float lenSq = length_squared(d);
        if (lenSq > min_vector_length_squared) {
            float3 direction = d / sqrt(lenSq);
            scattered = Ray3D(payload.point, direction);
            break;
        }
    }
    attenuation = material->albedo;
    return true;
}

bool metal_scatter(constant MetalMaterial const * material, Ray3D ray, Payload payload, thread RNG* rng, thread float3 & attenuation, thread Ray3D & scattered) {
    float3 reflected = reflect(ray.direction, payload.normal) + material->fuzz * rng->random_unit_vector_3d();
    if (dot(reflected, payload.normal) < 0) { return false; }
    attenuation = material->albedo;
    scattered = Ray3D(payload.point, normalize(reflected));
    return true;
}

bool dielectric_scatter(constant DielectricMaterial const * material, Ray3D ray, Payload payload, thread RNG* rng, thread float3 & attenuation, thread Ray3D & scattered) {
    float ηRatio = payload.face == face::front ? 1.0 / material->refraction_index : material->refraction_index;
    float3 refracted = refract_or_reflect(ray.direction, payload.normal, ηRatio, rng->random_f());
    attenuation = 1;
    scattered = Ray3D(payload.point, refracted);
    return true;
}

bool scatter(constant void const * material, Ray3D ray, Payload payload, thread RNG* rng, thread float3 & attenuation, thread Ray3D & scattered) {
    MaterialKind kind = *reinterpret_cast<constant MaterialKind const*>(material);
    switch (kind) {
        case material_kind_lambertian:
            return lambertian_scatter(reinterpret_cast<constant LambertianMaterial const *>(material), ray, payload, rng, attenuation, scattered);
        case material_kind_metal:
            return metal_scatter(reinterpret_cast<constant MetalMaterial const *>(material), ray, payload, rng, attenuation, scattered);
        case material_kind_dielectric:
            return dielectric_scatter(reinterpret_cast<constant DielectricMaterial const *>(material), ray, payload, rng, attenuation, scattered);
    }
}

#endif // MATERIALS_IMPL_H
