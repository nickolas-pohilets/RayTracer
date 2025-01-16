//
//  HitTesting.h
//  RayTracing
//
//  Created by Mykola Pokhylets on 14/01/2025.
//
#ifndef HIT_TESTING_H
#define HIT_TESTING_H

#include "Defines.h"

enum class face {
    front,
    back
};

struct Payload {
    float3 point;
    float3 normal;
    face face;
    size_t material_offset;

    void set_normal(float3 front_normal, float3 ray_direction) ray_data {
        if (dot(front_normal, ray_direction) > 0) {
            normal = -front_normal;
            face = face::back;
        } else {
            normal = front_normal;
            face = face::front;
        }
    }
};

class Ray3D {
public:
    float3 origin;
    float3 direction;

    Ray3D(float3 _origin, float3 _direction): origin(_origin), direction(_direction) {}

    float3 at(float t) const {
        return origin + t * direction;
    }
};

#endif // HIT_TESTING_H
