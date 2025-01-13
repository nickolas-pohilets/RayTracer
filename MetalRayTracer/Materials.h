//
//  Materials.h
//  RayTracing
//
//  Created by Mykola Pokhylets on 13/01/2025.
//
#ifndef MATERIALS_H
#define MATERIALS_H

#include <simd/simd.h>

enum MaterialKind {
    material_kind_lambertian = 1,
    material_kind_metal,
    material_kind_dielectric
} __attribute__((enum_extensibility(closed)));

struct LambertianMaterial {
    enum MaterialKind kind;
    vector_float3 albedo;
} __attribute__((swift_private));

struct MetalMaterial {
    enum MaterialKind kind;
    vector_float3 albedo;
    float fuzz;
} __attribute__((swift_private));

struct DielectricMaterial {
    enum MaterialKind kind;
    float refraction_index;
} __attribute__((swift_private));

#endif // MATERIALS_H
