//
//  Shaders.metal
//  MetalRayTracer
//
//  Created by Mykola Pokhylets on 10/01/2025.
//

#include <metal_stdlib>
#include <metal_raytracing>
#include "../Types.h"
#include "RNG.h"
#include "MaterialsImpl.h"
#include "RenderableImpl.h"

struct BoundingBoxResult {
    bool accept [[accept_intersection]];
    float distance [[distance]];
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
        float half_pov_radians = config.vertical_FOV * M_PI_F / 360;
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

    Ray3D get_ray(uint2 grid_index, thread RNG* rng) const {
        float3 origin = get_ray_origin(rng);
        float3 pixel_sample = get_pixel_sample(grid_index, rng);
        return Ray3D(origin, normalize(pixel_sample - origin));
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
    BackgroundLighting background_lighting;
};

float3 background_color(BackgroundLighting mode, float3 direction) {
    switch (mode) {
        case background_lighting_none: {
            return float3(0, 0, 0);
        }
        case background_lighting_sky: {
            auto a = 0.5 * direction.y + 1.0;
            return (1.0-a) * float3(1.0, 1.0, 1.0) + a * float3(0.5, 0.7, 1.0);
        }
    }
}

struct Payload {
    RNG rng;
    HitInfo hit;
};

float3 get_ray_color(ray r, world w, constant uchar const * meterials, thread RNG *rng, uint max_depth) {
    float3 attenuation = 1;
    float3 color = 0;
    while (max_depth > 0) {
        intersector<triangle_data> intersector;
        Payload payload = { *rng };
        intersection_result<triangle_data> intersection = intersector.intersect(r, w.acceleration_structure, w.function_table, payload);
        *rng = payload.rng;

        switch (intersection.type) {
            case intersection_type::none: {
                return color + attenuation * background_color(w.background_lighting, r.direction);
            }
            case intersection_type::bounding_box: {
                constant uchar const * material = meterials + payload.hit.material_offset;
                Ray3D old_ray(r.origin, r.direction);
                material_result result = { 0, 0, Ray3D(0, 0) };
                bool did_scatter = scatter(material, old_ray, payload.hit, rng, result);
                color += attenuation * result.emitted;
                if (!did_scatter) {
                    return color;
                }
                attenuation *= result.attenuation;
                r = ray(result.scattered.origin, result.scattered.direction, 0.0001);
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
                               texture2d<ushort, access::read_write> acc_buffer [[texture(kernel_buffer_accumulator_texture)]],
                               uint2 grid_index [[thread_position_in_grid]],
                               constant CameraConfig const &camera_config [[buffer(kernel_buffer_camera_config)]],
                               constant RenderConfig const &render_config [[buffer(kernel_buffer_render_config)]],
                               primitive_acceleration_structure accelerationStructure [[buffer(kernel_buffer_acceleration_structure)]],
                               intersection_function_table<triangle_data> functionTable [[buffer(kernel_buffer_function_table)]],
                               constant uchar const *materials [[buffer(kernel_buffer_materials)]])
{
    Camera camera(color_buffer.get_width(), color_buffer.get_height(), camera_config);
    uint32_t rng_seed_hi = (uint32_t)(render_config.rng_seed >> 32);
    uint32_t rng_seed_lo = (uint32_t)render_config.rng_seed;
    RNG rng(grid_index[0] * 5569 + rng_seed_lo, grid_index[1] * 2707 + rng_seed_hi);
    world w = { accelerationStructure, functionTable, camera_config.background };

    float3 color = 0;
    for (uint i = 0; i < render_config.samples_per_pixel; i++) {
        auto r = camera.get_ray(grid_index, &rng);
        color += get_ray_color(ray(r.origin, r.direction), w, materials, &rng, render_config.max_depth);
    }
    color /= render_config.samples_per_pixel;
    color = min(color, 1);
    float3 old_color = (float3(acc_buffer.read(grid_index).rgb) + nextafter(0.5, 0)) / 1024.f;
    float t = 1.f / render_config.pass_counter;
    float3 total_color = old_color * (1 - t) + color * t;
    ushort3 uint_color = min(ushort3(total_color * 1024), 1023);
    acc_buffer.write(ushort4(uint_color, 0), grid_index);
    color_buffer.write(float4(sqrt(total_color), 1.0), grid_index);
}

template<class T>
auto get_hit_enumerator(device T const & object, Ray3D ray, thread RNG * rng) -> decltype(typename T::HitEnumerator(object, ray)) {
    return typename T::HitEnumerator(object, ray);
}

template<class T>
auto get_hit_enumerator(device T const & object, Ray3D ray, thread RNG * rng) -> decltype(typename T::HitEnumerator(object, ray, rng)) {
    return typename T::HitEnumerator(object, ray, rng);
}

template<typename T>
BoundingBoxResult intersection(float3 origin,
                               float3 direction,
                               float minDistance,
                               float maxDistance,
                               device T const &object,
                               ray_data Payload & payload)
{
    Ray3D ray(origin, direction);
    RNG rng = payload.rng;
    auto e = get_hit_enumerator(object, ray, &rng);
    for (; e.hasNext(); e.move()) {
        // TODO: Should it be multiplied by vector length?
        float distance = e.t();
        bool matches_distance;
        {
#pragma METAL fp math_mode(safe)
            matches_distance = distance >= minDistance && distance <= maxDistance;
        }
        if (matches_distance) {
            payload.hit.point = e.point();
            payload.hit.set_normal(e.normal(), direction);
            payload.hit.material_offset = e.material_offset();
            payload.hit.texture_coordinates = e.texture_coordinates();

            payload.rng = rng;
            return { true, distance };
        }
    }

    payload.rng = rng;
    return { false, 0.0f };
}

// MARK: - Primitives

[[intersection(bounding_box)]]
BoundingBoxResult sphereIntersectionFunction(float3 origin [[origin]],
                                             float3 direction [[direction]],
                                             float minDistance [[min_distance]],
                                             float maxDistance [[max_distance]],
                                             device Sphere const *object [[primitive_data]],
                                             ray_data Payload & payload [[payload]])
{
    return intersection(origin, direction, minDistance, maxDistance, *object, payload);
}

[[intersection(bounding_box)]]
BoundingBoxResult cylinderIntersectionFunction(float3 origin [[origin]],
                                               float3 direction [[direction]],
                                               float minDistance [[min_distance]],
                                               float maxDistance [[max_distance]],
                                               uint primitiveIndex [[primitive_id]],
                                               device Cylinder const *object [[primitive_data]],
                                               ray_data Payload & payload [[payload]])
{
    return intersection(origin, direction, minDistance, maxDistance, *object, payload);
}

[[intersection(bounding_box)]]
BoundingBoxResult cuboidIntersectionFunction(float3 origin [[origin]],
                                             float3 direction [[direction]],
                                             float minDistance [[min_distance]],
                                             float maxDistance [[max_distance]],
                                             uint primitiveIndex [[primitive_id]],
                                             device Cuboid const *object [[primitive_data]],
                                             ray_data Payload & payload [[payload]])
{
    return intersection(origin, direction, minDistance, maxDistance, *object, payload);
}

[[intersection(bounding_box)]]
BoundingBoxResult quadIntersectionFunction(float3 origin [[origin]],
                                             float3 direction [[direction]],
                                             float minDistance [[min_distance]],
                                             float maxDistance [[max_distance]],
                                             uint primitiveIndex [[primitive_id]],
                                             device Quad const *object [[primitive_data]],
                                             ray_data Payload & payload [[payload]])
{
    return intersection(origin, direction, minDistance, maxDistance, *object, payload);
}

// MARK: - CSG Operations

[[intersection(bounding_box)]]
BoundingBoxResult subtract_cylinder_cylinder_IntersectionFunction(float3 origin [[origin]],
                                                                  float3 direction [[direction]],
                                                                  float minDistance [[min_distance]],
                                                                  float maxDistance [[max_distance]],
                                                                  uint primitiveIndex [[primitive_id]],
                                                                  device Subtract<Cylinder, Cylinder> const *object [[primitive_data]],
                                                                  ray_data Payload & payload [[payload]])
{
    return intersection(origin, direction, minDistance, maxDistance, *object, payload);
}

[[intersection(bounding_box)]]
BoundingBoxResult subtract_cuboid_cylinder_IntersectionFunction(float3 origin [[origin]],
                                                                float3 direction [[direction]],
                                                                float minDistance [[min_distance]],
                                                                float maxDistance [[max_distance]],
                                                                uint primitiveIndex [[primitive_id]],
                                                                device Subtract<Cuboid, Cylinder> const *object [[primitive_data]],
                                                                ray_data Payload & payload [[payload]])
{
    return intersection(origin, direction, minDistance, maxDistance, *object, payload);
}

[[intersection(bounding_box)]]
BoundingBoxResult intersection2_cuboid_sphere_IntersectionFunction(float3 origin [[origin]],
                                                                   float3 direction [[direction]],
                                                                   float minDistance [[min_distance]],
                                                                   float maxDistance [[max_distance]],
                                                                   uint primitiveIndex [[primitive_id]],
                                                                   device Intersection<Cuboid, Sphere> const *object [[primitive_data]],
                                                                   ray_data Payload & payload [[payload]])
{
    return intersection(origin, direction, minDistance, maxDistance, *object, payload);
}

[[intersection(bounding_box)]]
BoundingBoxResult union3_cylinder_cylinder_cylinder_IntersectionFunction(float3 origin [[origin]],
                                                                  float3 direction [[direction]],
                                                                  float minDistance [[min_distance]],
                                                                  float maxDistance [[max_distance]],
                                                                  uint primitiveIndex [[primitive_id]],
                                                                  device Union<Cylinder, Cylinder, Cylinder> const *object [[primitive_data]],
                                                                  ray_data Payload & payload [[payload]])
{
    return intersection(origin, direction, minDistance, maxDistance, *object, payload);
}

[[intersection(bounding_box)]]
BoundingBoxResult subtract_cuboid_union3_cylinder_cylinder_cylinder__IntersectionFunction(
    float3 origin [[origin]],
    float3 direction [[direction]],
    float minDistance [[min_distance]],
    float maxDistance [[max_distance]],
    uint primitiveIndex [[primitive_id]],
    device Subtract<Cuboid, Union<Cylinder, Cylinder, Cylinder>> const *object [[primitive_data]],
    ray_data Payload & payload [[payload]])
{
    return intersection(origin, direction, minDistance, maxDistance, *object, payload);
}

[[intersection(bounding_box)]]
BoundingBoxResult subtract_intersection2_cuboid_sphere__cylinder_IntersectionFunction(
    float3 origin [[origin]],
    float3 direction [[direction]],
    float minDistance [[min_distance]],
    float maxDistance [[max_distance]],
    uint primitiveIndex [[primitive_id]],
    device Subtract<Intersection<Cuboid, Sphere>, Cylinder> const *object [[primitive_data]],
    ray_data Payload & payload [[payload]])
{
    return intersection(origin, direction, minDistance, maxDistance, *object, payload);
}

[[intersection(bounding_box)]]
BoundingBoxResult subtract_intersection2_cuboid_sphere__union3_cylinder_cylinder_cylinder__IntersectionFunction(
    float3 origin [[origin]],
    float3 direction [[direction]],
    float minDistance [[min_distance]],
    float maxDistance [[max_distance]],
    uint primitiveIndex [[primitive_id]],
    device Subtract<Intersection<Cuboid, Sphere>, Union<Cylinder, Cylinder, Cylinder>> const *object [[primitive_data]],
    ray_data Payload & payload [[payload]])
{
    return intersection(origin, direction, minDistance, maxDistance, *object, payload);
}

// MARK: - Constant Density Volumes

[[intersection(bounding_box)]]
BoundingBoxResult cdv_cuboid_IntersectionFunction(
    float3 origin [[origin]],
    float3 direction [[direction]],
    float minDistance [[min_distance]],
    float maxDistance [[max_distance]],
    uint primitiveIndex [[primitive_id]],
    device ConstantDensityVolume<Cuboid> const *object [[primitive_data]],
    ray_data Payload & payload [[payload]])
{
    return intersection(origin, direction, minDistance, maxDistance, *object, payload);
}
