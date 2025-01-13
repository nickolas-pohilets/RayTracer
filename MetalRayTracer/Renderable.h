//
//  Renderable.h
//  RayTracing
//
//  Created by Mykola Pokhylets on 13/01/2025.
//

#ifndef RENDERABLE_H
#define RENDERABLE_H

#include <simd/simd.h>

enum RenderableKind {
    renderable_kind_sphere = 0,
} __attribute__((enum_extensibility(closed)));

struct Sphere {
    vector_float3 center;
    float radius;
    size_t material_offset;
#ifdef __METAL__
    class HitEnumerator;
#endif
} __attribute__((swift_private));

#endif // RENDERABLE_H
