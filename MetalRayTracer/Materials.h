//
//  Materials.h
//  RayTracing
//
//  Created by Mykola Pokhylets on 13/01/2025.
//
#ifndef MATERIALS_H
#define MATERIALS_H

#include <simd/simd.h>

#ifndef __METAL__
#include <Metal/Metal.h>
#endif

enum MaterialKind {
    material_kind_lambertian_colored = 1,
    material_kind_lambertian_textured,
    material_kind_lambertian_perlin_noise,
    material_kind_metal_colored,
    material_kind_metal_textured,
    material_kind_metal_perlin_noise,
    material_kind_dielectric,
    material_kind_emissive_colored,
    material_kind_isotropic_colored,
} __attribute__((enum_extensibility(closed)));

typedef vector_float3 SolidColor;

struct ImageTexture {
#ifdef __METAL__
    metal::texture2d<float> texture;
#else
    MTLResourceID texture_ptr;
#endif
} __attribute__((swift_private));

struct PerlinNoiseTexture {
    enum { TABLE_SIZE = 256 };
    SolidColor colors[2];
    float frequency;
    unsigned int turbulence;
    vector_float3 vectors[TABLE_SIZE];
    uint8_t permutations[3][TABLE_SIZE];
};

struct ColoredLambertianMaterial {
    enum MaterialKind kind;
    SolidColor albedo;
} __attribute__((swift_private));

struct TexturedLambertianMaterial {
    enum MaterialKind kind;
    struct ImageTexture albedo;
} __attribute__((swift_private));

struct PerlinNoiseLambertianMaterial {
    enum MaterialKind kind;
    struct PerlinNoiseTexture albedo;
} __attribute__((swift_private));

struct ColoredMetalMaterial {
    enum MaterialKind kind;
    SolidColor albedo;
    float fuzz;
} __attribute__((swift_private));

struct TexturedMetalMaterial {
    enum MaterialKind kind;
    struct ImageTexture albedo;
    float fuzz;
} __attribute__((swift_private));

struct PerlinNoiseMetalMaterial {
    enum MaterialKind kind;
    struct PerlinNoiseTexture albedo;
    float fuzz;
} __attribute__((swift_private));

struct DielectricMaterial {
    enum MaterialKind kind;
    float refraction_index;
} __attribute__((swift_private));

struct ColoredEmissiveMaterial {
    enum MaterialKind kind;
    SolidColor albedo;
} __attribute__((swift_private));

struct ColoredIsotropicMaterial {
    enum MaterialKind kind;
    SolidColor albedo;
} __attribute__((swift_private));

#endif // MATERIALS_H
