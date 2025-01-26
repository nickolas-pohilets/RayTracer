//
//  Renderable.h
//  RayTracing
//
//  Created by Mykola Pokhylets on 13/01/2025.
//

#ifndef RENDERABLE_H
#define RENDERABLE_H

#include <simd/simd.h>

struct Transform {
    matrix_float3x3 rotation;
    vector_float3 translation;
} __attribute__((swift_private));

struct Sphere {
    struct Transform transform;
    float radius;
    size_t material_offset;
#ifdef __cplusplus
    class HitEnumerator;
#endif
} __attribute__((swift_private));

struct Cylinder {
    struct Transform transform;
    float radius;
    float height;
    size_t bottom_material_offset;
    size_t top_material_offset;
    size_t side_material_offset;
#ifdef __cplusplus
    class HitEnumerator; 
#endif
} __attribute__((swift_private));

struct Cuboid {
    enum Face {
        left, right,
        bottom, top,
        back, front
    };

    struct Transform transform;
    vector_float3 size;
    size_t material_offset[6];
#ifdef __cplusplus
    class HitEnumerator;
#endif
} __attribute__((swift_private));

struct Quad {
    vector_float3 origin;
    vector_float3 u, v, w;
    vector_float3 normal;
    float d;
    size_t material_offset;
#ifdef __cplusplus
    class HitEnumerator;
#endif
} __attribute__((swift_private));

#endif // RENDERABLE_H
