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
        uint32_t xorshifted = ((oldstate >> 18u) ^ oldstate) >> 27u;
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
            if (1e-24 < lenSq && lenSq <= 1.0) {
                return float2(x, y) / sqrt(lenSq);
            }
        }
    }

    float3 random_unit_vector_3d() {
        while (true) {
            float x = random_f() * 2 - 1;
            float y = random_f() * 2 - 1;
            float z = random_f() * 2 - 1;
            float lenSq = x * x + y * y;
            if (1e-24 < lenSq && lenSq <= 1.0) {
                return float3(x, y, z) / sqrt(lenSq);
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

enum class face {
    front,
    back
};

struct Payload {
    float3 point;
    float3 normal;
    face face;

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

class Camera {
    float2 image_size;
    float3 camera_center;
    float3 viewport_u;
    float3 viewport_v;
    float3 viewport_center;

    float3 defocus_u;
    float3 defocus_v;
public:
    Camera(uint image_width, uint image_height, CameraConfig config) {
        image_size = float2(image_width, image_height);
        float half_pov_radians = config.vertical_POV * M_PI_F / 360;
        float viewport_height = 2 * tan(half_pov_radians) * config.focus_distance;
        float viewport_width = viewport_height * float(image_width) / float(image_height);
        camera_center = config.look_from;

        float3 w = normalize(config.look_from - config.look_at);
        float3 u = normalize(cross(config.up, w));
        float3 v = cross(w, u);

        viewport_u = viewport_width * u;
        viewport_v = -viewport_height * v;
        viewport_center = config.look_from - config.focus_distance * w;

        float defocus_radius = config.focus_distance * tan(config.defocus_angle * M_PI_F / 360);
        defocus_u = u * defocus_radius;
        defocus_v = v * defocus_radius;
    }

    ray get_ray(uint2 grid_index, thread RNG* rng) const {
        float3 origin = get_ray_origin(rng);
        float3 pixel_sample = get_pixel_sample(grid_index, rng);
        return ray(origin, normalize(pixel_sample - origin));
    }

    float3 get_pixel_sample(uint2 grid_index, thread RNG* rng) const {
        float offset_x = rng->random_f();
        float offset_y = rng->random_f();
        float sx = ((float(grid_index[0]) + offset_x) / image_size.x - 0.5);
        float sy = ((float(grid_index[1]) + offset_y) / image_size.y - 0.5);
        return viewport_center + sx * viewport_u + sy * viewport_v;
    }

    float3 get_ray_origin(thread RNG* rng) const {
        float2 p = rng->random_unit_vector_2d();
        return camera_center + p.x * defocus_u + p.y * defocus_v;
    }
};

struct world {
    primitive_acceleration_structure acceleration_structure;
    intersection_function_table<triangle_data> function_table;
};

float3 background_color(float3 direction) {
    auto a = 0.5 * direction.y + 1.0;
    return (1.0-a) * float3(1.0, 1.0, 1.0) + a * float3(0.5, 0.7, 1.0);
}

float3 get_ray_color(ray r, world w, thread RNG *rng, uint max_depth) {
    float3 attenuation = 1;
    while (max_depth > 0) {
        intersector<triangle_data> intersector;
        Payload payload;
        intersection_result<triangle_data> intersection = intersector.intersect(r, w.acceleration_structure, w.function_table, payload);

        switch (intersection.type) {
            case intersection_type::none: {
                return attenuation * background_color(r.direction);
            }
            case intersection_type::bounding_box: {
                float3 direction = normalize(payload.normal + rng->random_unit_vector_3d());
                r = ray(payload.point, direction, 0.0001);
                attenuation *= 0.5;
                max_depth--;
                continue;
            }
            case intersection_type::triangle:
            case intersection_type::curve: {
                assert(false);
                return float3(1.0, 0.0, 1.0);
            }
        }
    }
    // If we've exceeded the ray bounce limit, no more light is gathered.
    return float3(0, 0, 0);
}

kernel void ray_tracing_kernel(texture2d<float, access::write> color_buffer [[texture(kernel_buffer_output_texture)]],
                               uint2 grid_index [[thread_position_in_grid]],
                               constant CameraConfig const &camera_config [[buffer(kernel_buffer_camera_config)]],
                               constant RenderConfig const &render_config [[buffer(kernel_buffer_render_config)]],
                               primitive_acceleration_structure accelerationStructure [[buffer(kernel_buffer_acceleration_structure)]],
                               intersection_function_table<triangle_data> functionTable [[buffer(kernel_buffer_function_table)]],
                               constant void const *materials [[buffer(kernel_buffer_materials)]])
{
    Camera camera(color_buffer.get_width(), color_buffer.get_height(), camera_config);
    RNG rng(grid_index[0], grid_index[1]);
    world w = { accelerationStructure, functionTable };

    float3 color = 0;
    for (uint i = 0; i < render_config.samples_per_pixel; i++) {
        auto ray = camera.get_ray(grid_index, &rng);
        color += get_ray_color(ray, w, &rng, render_config.max_depth);
    }
    color /= render_config.samples_per_pixel;
    color_buffer.write(float4(color, 1.0), grid_index);
}

template<typename T>
BoundingBoxResult intersection(float3 origin,
                               float3 direction,
                               float minDistance,
                               float maxDistance,
                               uint primitiveIndex,
                               device T *objects,
                               ray_data Payload & payload)
{
    Ray3D ray(origin, direction);
    typename T::HitEnumerator e(objects[primitiveIndex], ray);
    for (; e.hasNext(); e.move()) {
        // TODO: Should it be multiplied by vector length?
        float distance = e.t();
        if (distance >= minDistance && distance <= maxDistance) {
            payload.point = e.point();
            payload.set_normal(e.normal(), direction);
            return { true, distance };
        }
    }
    return { false, 0.0f };
}

[[intersection(bounding_box)]]
BoundingBoxResult sphereIntersectionFunction(float3 origin [[origin]],
                                               float3 direction [[direction]],
                                               float minDistance [[min_distance]],
                                               float maxDistance [[max_distance]],
                                               uint primitiveIndex [[primitive_id]],
                                               device Sphere *objects [[buffer(renderable_kind_sphere)]],
                                             ray_data Payload & payload [[payload]])
{
    return intersection(origin, direction, minDistance, maxDistance, primitiveIndex, objects, payload);
}
