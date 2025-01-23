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

#ifndef __METAL__

static inline matrix_float3x3 quaternion_to_matrix(simd_quatf quat) {
    vector_float4 q = quat.vector;
    float xx = q.x * q.x;
    float yy = q.y * q.y;
    float zz = q.z * q.z;
    float xy = q.x * q.y;
    float xz = q.x * q.z;
    float yz = q.y * q.z;
    float wx = q.w * q.x;
    float wy = q.w * q.y;
    float wz = q.w * q.z;

    
    return (matrix_float3x3){ .columns = {
        (vector_float3){1 - 2 * (yy + zz), 2 * (xy - wz), 2 * (xz + wy)},
        (vector_float3){2 * (xy + wz), 1 - 2 * (xx + zz), 2 * (yz - wx)},
        (vector_float3){2 * (xz - wy), 2 * (yz + wx), 1 - 2 * (xx + yy)}
    }};
}

#endif


#endif // RENDERABLE_H
