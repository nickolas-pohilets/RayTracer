//
//  Types.h
//  RayTracing
//
//  Created by Mykola Pokhylets on 11/01/2025.
//

#include <simd/simd.h>

struct Sphere {
    vector_float3 center;
    float radius;
#ifdef __METAL__
    Sphere(float3 c, float r): center(c), radius(r) {}

    class HitEnumerator;
#endif
};
