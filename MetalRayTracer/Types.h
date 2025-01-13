//
//  Types.h
//  RayTracing
//
//  Created by Mykola Pokhylets on 11/01/2025.
//

#include <simd/simd.h>

struct CameraConfig {
    float vertical_POV;
    vector_float3 look_from;
    vector_float3 look_at;
    vector_float3 up;
    float defocus_angle;
    float focus_distance;
} __attribute__((swift_name("__CameraConfig")));

struct RenderConfig {
    unsigned int samples_per_pixel;
    unsigned int max_depth;
} __attribute__((swift_name("__RenderConfig")));

struct Sphere {
    vector_float3 center;
    float radius;
#ifdef __METAL__
    Sphere(float3 c, float r): center(c), radius(r) {}

    class HitEnumerator;
#endif
};

enum RenderableTypeBufferIndex {
    renderable_sphere0,
    renderable_sphere1,
    renderable_sphere2,
};
