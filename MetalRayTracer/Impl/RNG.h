//
//  RNG.h
//  RayTracing
//
//  Created by Mykola Pokhylets on 14/01/2025.
//

#ifndef RNG_H
#define RNG_H

#include "Defines.h"

constant float const min_vector_length_squared = 1e-24;

// See https://www.pcg-random.org/
class pcg32 {
    // RNG state.  All values are possible.
    uint64_t state;
    // Controls which RNG sequence (stream) is selected. Must *always* be odd.
    uint64_t inc;
public:
    pcg32(uint64_t initstate, uint64_t initseq)
    {
        state = 0U;
        inc = (initseq << 1u) | 1u;
        random_u32();
        state += initstate;
        random_u32();
    }

    uint32_t random_u32() {
        uint64_t oldstate = state;
        state = oldstate * 6364136223846793005ULL + inc;
        uint32_t xorshifted = (uint32_t)(((oldstate >> 18u) ^ oldstate) >> 27u);
        uint32_t rot = oldstate >> 59u;
        return (xorshifted >> rot) | (xorshifted << ((-rot) & 31));
    }

    float random_f() {
        return ldexp(float(random_u32()), -32);
    }

    float2 random_unit_vector_2d() {
        while (true) {
            float x = random_f() * 2 - 1;
            float y = random_f() * 2 - 1;
            float lenSq = x * x + y * y;
            if (min_vector_length_squared < lenSq && lenSq <= 1.0) {
                return (float2){x, y} / sqrt(lenSq);
            }
        }
    }

    float3 random_unit_vector_3d() {
        while (true) {
            float x = random_f() * 2 - 1;
            float y = random_f() * 2 - 1;
            float z = random_f() * 2 - 1;
            float lenSq = x * x + y * y;
            if (min_vector_length_squared < lenSq && lenSq <= 1.0) {
                return (float3){x, y, z} / sqrt(lenSq);
            }
        }
    }

    float3 random_unit_vector_on_hemisphere(float3 normal) {
        float3 v = random_unit_vector_3d();
        if (dot(v, normal) > 0.0) {
            return v; // In the same hemisphere as the normal
        } else {
            return -v; // In the opposite hemisphere as the normal
        }
    }
};

typedef pcg32 RNG;

#endif // RNG_H
