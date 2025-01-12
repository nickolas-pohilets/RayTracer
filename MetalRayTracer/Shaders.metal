//
//  Shaders.metal
//  MetalRayTracer
//
//  Created by Mykola Pokhylets on 10/01/2025.
//

#include <metal_stdlib>
#include <metal_raytracing>
#include "Types.h"
using namespace metal;
using namespace metal::raytracing;

#if defined(assert)
#undef assert
#endif

void assert(bool ok) {
    if (!ok) {
        device float* f = nullptr;
        *f = 12;
    }
}

class HitRecord {
    float t;
    float3 point;
    float3 normal;
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

class Sphere::HitEnumerator {
    Sphere _sphere;
    Ray3D _ray;
    float _t[2];
    int _index;
public:
    HitEnumerator(Sphere sphere, Ray3D ray): _sphere(sphere), _ray(ray) {
        // P = ray[t]
        // (ray.origin + ray.direction * t - C) • (ray.origin + ray.direction * t - C) = radius²
        // (ray.direction * t + (ray.origin - C)) • (ray.direction * t + (ray.origin - C)) = radius²
        // (ray.direction * t + (ray.origin - C)) • (ray.direction * t + (ray.origin - C)) = radius²
        // t² * ray.direction • ray.direction + t * (2 * ray.direction • (ray.origin - C)) + (ray.origin - C) • (ray.origin - C) - radius² = 0
        float3 oc = _ray.origin - _sphere.center;
        float a = dot(ray.direction, ray.direction);
        float b_2 = dot(ray.direction, oc);
        float c = dot(oc, oc) - _sphere.radius * _sphere.radius;
        float D_4 = b_2 * b_2 - a * c;
        if (D_4 < 0) {
            _index = 2;
            _t[0] = NAN;
            _t[1] = NAN;
        } else {
            _t[0] = (-b_2 - sqrt(D_4)) / a;
            _t[1] = (-b_2 + sqrt(D_4)) / a;
            _index = 0;
        }
    }

    bool hasNext() const { return _index < 2; }
    void move() { _index++; }

    float t() const {
        assert(hasNext());
        return _t[_index];
    }

    float3 point() const {
        return _ray.at(t());
    }

    float3 normal() const {
        return (point() - _sphere.center) / _sphere.radius;
    }

    //    float3 point;
    //    float3 normal;
    //    var face: Face
    //    var material: any Material
    //    var textureCoordinates: Point2D
};

struct BoundingBoxResult {
    bool accept [[accept_intersection]];
    float distance [[distance]];
};

struct Payload {
    float3 normal;
};

kernel void ray_tracing_kernel(texture2d<float, access::write> color_buffer [[texture(0)]],
                               uint2 grid_index [[thread_position_in_grid]],
                               primitive_acceleration_structure accelerationStructure [[buffer(1)]],
                               intersection_function_table<triangle_data> functionTable [[buffer(2)]])
{
    int w = color_buffer.get_width();
    int h = color_buffer.get_height();
    float3 direction = float3(
                              (float(grid_index[0]) - w * 0.5) / w,
                              -(float(grid_index[1]) - h * 0.5) / w,
                              -1.0);
    float3 origin = float3(0, 0, 0);
    ray ray(origin, direction);

    intersector<triangle_data> intersector;
    Payload payload;
    intersection_result<triangle_data> intersection = intersector.intersect(ray, accelerationStructure, functionTable, payload);

    float4 color;
    switch (intersection.type) {
        case intersection_type::none:
            color = float4(0.0, 0.0, 0.0, 1.0);
            break;
        case intersection_type::bounding_box:
            color = float4(1.0, 0.5, 0.0, 1.0);
            break;
        case intersection_type::triangle:
        case intersection_type::curve:
            assert(false);
            color = float4(1.0, 0.0, 1.0, 1.0);
    }
    color_buffer.write(color, grid_index);
}

template<typename T>
[[intersection(bounding_box)]]
BoundingBoxResult intersectionFunction(float3 origin [[origin]],
                                       float3 direction [[direction]],
                                       float minDistance [[min_distance]],
                                       float maxDistance [[max_distance]],
                                       uint primitiveIndex [[primitive_id]],
                                       device T *objects [[buffer (0)]],
                                       ray_data Payload & payload [[payload]])
{
    Ray3D ray(origin, direction);
    typename T::HitEnumerator e(objects[primitiveIndex], ray);
    for (; e.hasNext(); e.move()) {
        // TODO: Should it be multiplied by vector length?
        float distance = e.t();
        if (distance >= minDistance && distance <= maxDistance) {
            payload.normal = e.normal();
            return { true, distance };
        }
    }
    return { false, 0.0f };
}

template [[host_name("sphereIntersectionFunction")]]
[[intersection(bounding_box)]]
BoundingBoxResult intersectionFunction<Sphere>(float3 origin [[origin]],
                                               float3 direction [[direction]],
                                               float minDistance [[min_distance]],
                                               float maxDistance [[max_distance]],
                                               uint primitiveIndex [[primitive_id]],
                                               device Sphere *objects [[buffer (0)]],
                                               ray_data Payload & payload [[payload]]);
