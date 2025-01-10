//
//  Shaders.metal
//  MetalRayTracer
//
//  Created by Mykola Pokhylets on 10/01/2025.
//

#include <metal_stdlib>
using namespace metal;

class Ray3D {
public:
    float3 origin;
    float3 direction;

    Ray3D(float3 _origin, float3 _direction): origin(_origin), direction(_direction) {}

    float3 at(float t) const {
        return origin + t * direction;
    }
};

class Sphere {
public:
    float3 center;
    float radius;

    Sphere(float3 c, float r): center(c), radius(r) {}

    bool hit(Ray3D ray) const {
        // P = ray[t]
        // (ray.origin + ray.direction * t - C) • (ray.origin + ray.direction * t - C) = radius²
        // (ray.direction * t + (ray.origin - C)) • (ray.direction * t + (ray.origin - C)) = radius²
        // (ray.direction * t + (ray.origin - C)) • (ray.direction * t + (ray.origin - C)) = radius²
        // t² * ray.direction • ray.direction + t * (2 * ray.direction • (ray.origin - C)) + (ray.origin - C) • (ray.origin - C) - radius² = 0
        float3 oc = ray.origin - center;
        float a = dot(ray.direction, ray.direction);
        float b_2 = dot(ray.direction, oc);
        float c = dot(oc, oc) - radius * radius;
        float D_4 = b_2 * b_2 - a * c;
        if (D_4 < 0) { return false; }
        float t1 = (-b_2 - sqrt(D_4)) / a;
        float t2 = (-b_2 + sqrt(D_4)) / a;
        return t1 > 0 || t2 > 0;
    }
};

kernel void ray_tracing_kernel(
    texture2d<float, access::write> color_buffer [[texture(0)]],
    uint2 grid_index [[thread_position_in_grid]]
) {
    int w = color_buffer.get_width();
    int h = color_buffer.get_height();
    float3 direction = float3(
                              (float(grid_index[0]) - w * 0.5) / w,
                              -(float(grid_index[1]) - h * 0.5) / w,
                              -1.0);
    float3 origin = float3(0, 0, 0);
    Ray3D ray(origin, direction);
    Sphere s1(float3(-0.2, -0.2, -1), 0.2);
    Sphere s2(float3(+0.2, +0.2, -1), 0.2);
    float4 color = s1.hit(ray) ? float4(1.0, 0.5, 0.0, 1.0) :
                   s2.hit(ray) ? float4(0.0, 0.5, 1.0, 1.0) :
                                 float4(0.0, 0.0, 0.0, 1.0);
    color_buffer.write(color, grid_index);
}


