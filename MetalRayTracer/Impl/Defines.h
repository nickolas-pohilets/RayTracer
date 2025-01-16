//
//  Defines.h
//  RayTracing
//
//  Created by Mykola Pokhylets on 14/01/2025.
//
#ifndef DEFINES_H
#define DEFINES_H

#ifndef __METAL__

#include <simd/simd.h>
#include <cassert>

#define device
#define constant
#define thread
#define threadgroup
#define threadgroup_imageblock
#define ray_data
#define object_data

typedef vector_float3 float3;
typedef vector_float2 float2;

using namespace simd;

inline bool isfinite(float x) {
    return std::isfinite(x);
}

#else

#include <metal_stdlib>
#include <metal_raytracing>

using namespace metal;
using namespace metal::raytracing;

#endif

#endif // DEFINES_H
