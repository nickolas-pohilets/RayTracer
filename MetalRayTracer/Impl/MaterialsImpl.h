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

vector_float3 get_color(SolidColor color, vector_float2 coords, vector_float3 point) {
    return color;
}

float3 get_color(ImageTexture texture, vector_float2 coords, vector_float3 point) {
    static_assert(sizeof(texture.texture) == sizeof(MTLResourceID), "Bad texture size");
    static_assert(__alignof(texture.texture) == __alignof(MTLResourceID), "Bad texture alignment");
    constexpr sampler s(coord::normalized, filter::nearest);
    return texture.texture.sample(s, coords).rgb;
}

uchar perlin_hash(constant PerlinNoiseTexture const & tex, uchar x, uchar y, uchar z) {
    return tex.permutations[2][(tex.permutations[1][(tex.permutations[0][x] + y) & 255] + z) & 255];
}

float smoothstep(float t) {
    return t * t * t * (t * (6.0f * t - 15.0f) + 10.0f);
}

float perlin_noise(constant PerlinNoiseTexture const & tex, float3 p) {
    enum { TABLE_SIZE_MASK = PerlinNoiseTexture::TABLE_SIZE - 1 };

    int xi0 = ((int)floor(p.x)) & TABLE_SIZE_MASK;
    int yi0 = ((int)floor(p.y)) & TABLE_SIZE_MASK;
    int zi0 = ((int)floor(p.z)) & TABLE_SIZE_MASK;

    int xi1 = (xi0 + 1) & TABLE_SIZE_MASK;
    int yi1 = (yi0 + 1) & TABLE_SIZE_MASK;
    int zi1 = (zi0 + 1) & TABLE_SIZE_MASK;

    float tx = p.x - floor(p.x);
    float ty = p.y - floor(p.y);
    float tz = p.z - floor(p.z);

    float u = smoothstep(tx);
    float v = smoothstep(ty);
    float w = smoothstep(tz);

    // gradients at the corner of the cell
    float3 c000 = tex.vectors[perlin_hash(tex, xi0, yi0, zi0)];
    float3 c100 = tex.vectors[perlin_hash(tex, xi1, yi0, zi0)];
    float3 c010 = tex.vectors[perlin_hash(tex, xi0, yi1, zi0)];
    float3 c110 = tex.vectors[perlin_hash(tex, xi1, yi1, zi0)];
    float3 c001 = tex.vectors[perlin_hash(tex, xi0, yi0, zi1)];
    float3 c101 = tex.vectors[perlin_hash(tex, xi1, yi0, zi1)];
    float3 c011 = tex.vectors[perlin_hash(tex, xi0, yi1, zi1)];
    float3 c111 = tex.vectors[perlin_hash(tex, xi1, yi1, zi1)];

    // generate vectors going from the grid points to p
    float x0 = tx, x1 = tx - 1;
    float y0 = ty, y1 = ty - 1;
    float z0 = tz, z1 = tz - 1;

    float3 p000 = float3(x0, y0, z0);
    float3 p100 = float3(x1, y0, z0);
    float3 p010 = float3(x0, y1, z0);
    float3 p110 = float3(x1, y1, z0);
    float3 p001 = float3(x0, y0, z1);
    float3 p101 = float3(x1, y0, z1);
    float3 p011 = float3(x0, y1, z1);
    float3 p111 = float3(x1, y1, z1);

    // linear interpolation
    float a = mix(dot(c000, p000), dot(c100, p100), u);
    float b = mix(dot(c010, p010), dot(c110, p110), u);
    float c = mix(dot(c001, p001), dot(c101, p101), u);
    float d = mix(dot(c011, p011), dot(c111, p111), u);

    float e = mix(a, b, v);
    float f = mix(c, d, v);

    return mix(e, f, w);
}

float3 get_color(constant PerlinNoiseTexture const & texture, vector_float2 coords, vector_float3 point) {
    auto t = 0.0;
    if (texture.turbulence == 0) {
        t = 1.0 + perlin_noise(texture, point * texture.frequency);
    } else {
        auto f = texture.frequency;
        auto weight = 1.0;
        for (unsigned i = 0; i < texture.turbulence; i++) {
            float ti = perlin_noise(texture, point * f);
            t += ti * weight;
            weight *= 0.5;
            f *= 2;
        }
        t = fabs(t);
    }
    return mix(texture.colors[0], texture.colors[1], t);
}

struct material_result {
    float3 emitted;
    float3 attenuation;
    Ray3D scattered;
};

template<class LambertianMaterial>
bool lambertian_scatter(constant LambertianMaterial const * material, Ray3D ray, HitInfo hit, thread RNG* rng, thread material_result & result) {
    result.emitted = 0;
    while (true) {
        float3 d = hit.normal + rng->random_unit_vector_3d();
        float lenSq = length_squared(d);
        if (lenSq > min_vector_length_squared) {
            float3 direction = d / sqrt(lenSq);
            result.scattered = Ray3D(hit.point, direction);
            break;
        }
    }
    result.attenuation = get_color(material->albedo, hit.texture_coordinates, hit.point);
    return true;
}

template<class MetalMaterial>
bool metal_scatter(constant MetalMaterial const * material, Ray3D ray, HitInfo hit, thread RNG* rng, thread material_result & result) {
    result.emitted = 0;
    float3 reflected = reflect(ray.direction, hit.normal) + material->fuzz * rng->random_unit_vector_3d();
    if (dot(reflected, hit.normal) < 0) { return false; }
    result.attenuation = get_color(material->albedo, hit.texture_coordinates, hit.point);
    result.scattered = Ray3D(hit.point, normalize(reflected));
    return true;
}

bool dielectric_scatter(constant DielectricMaterial const * material, Ray3D ray, HitInfo hit, thread RNG* rng, thread material_result & result) {
    result.emitted = 0;
    float ηRatio = hit.face == face::front ? 1.0 / material->refraction_index : material->refraction_index;
    float3 refracted = refract_or_reflect(ray.direction, hit.normal, ηRatio, rng->random_f());
    result.attenuation = 1;
    result.scattered = Ray3D(hit.point, refracted);
    return true;
}

bool emissive_scatter(constant ColoredEmissiveMaterial const * material, Ray3D ray, HitInfo hit, thread RNG* rng, thread material_result & result) {
    result.emitted = material->albedo;
    return false;
}

bool isotropic_scatter(constant ColoredIsotropicMaterial const * material, Ray3D ray, HitInfo hit, thread RNG* rng, thread material_result & result) {
    result.scattered = Ray3D(hit.point, rng->random_unit_vector_3d());
    result.attenuation = get_color(material->albedo, hit.texture_coordinates, hit.point);
    return true;
}

bool scatter(constant void const * material, Ray3D ray, HitInfo hit, thread RNG* rng, thread material_result & result) {
    MaterialKind kind = *reinterpret_cast<constant MaterialKind const*>(material);
    switch (kind) {
        case material_kind_lambertian_colored:
            return lambertian_scatter(reinterpret_cast<constant ColoredLambertianMaterial const *>(material), ray, hit, rng, result);
        case material_kind_lambertian_textured:
            return lambertian_scatter(reinterpret_cast<constant TexturedLambertianMaterial const *>(material), ray, hit, rng, result);
        case material_kind_lambertian_perlin_noise:
            return lambertian_scatter(reinterpret_cast<constant PerlinNoiseLambertianMaterial const *>(material), ray, hit, rng, result);
        case material_kind_metal_colored:
            return metal_scatter(reinterpret_cast<constant ColoredMetalMaterial const *>(material), ray, hit, rng, result);
        case material_kind_metal_textured:
            return metal_scatter(reinterpret_cast<constant TexturedMetalMaterial const *>(material), ray, hit, rng, result);
        case material_kind_metal_perlin_noise:
            return metal_scatter(reinterpret_cast<constant PerlinNoiseMetalMaterial const *>(material), ray, hit, rng, result);
        case material_kind_dielectric:
            return dielectric_scatter(reinterpret_cast<constant DielectricMaterial const *>(material), ray, hit, rng, result);
        case material_kind_emissive_colored:
            return emissive_scatter(reinterpret_cast<constant ColoredEmissiveMaterial const *>(material), ray, hit, rng, result);
        case material_kind_isotropic_colored:
            return isotropic_scatter(reinterpret_cast<constant ColoredIsotropicMaterial const *>(material), ray, hit, rng, result);
    }
}

#endif // MATERIALS_IMPL_H
