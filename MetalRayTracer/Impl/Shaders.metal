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
};

float3 background_color(float3 direction) {
    auto a = 0.5 * direction.y + 1.0;
    return (1.0-a) * float3(1.0, 1.0, 1.0) + a * float3(0.5, 0.7, 1.0);
}

float3 get_ray_color(ray r, world w, constant uchar const * meterials, thread RNG *rng, uint max_depth) {
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
                constant uchar const * material = meterials + payload.material_offset;
                Ray3D old_ray(r.origin, r.direction);
                float3 material_attenuation;
                Ray3D new_ray(0, 0);
                if (!scatter(material, old_ray, payload, rng, material_attenuation, new_ray)) {
                    return 0;
                }
                attenuation *= material_attenuation;
                r = ray(new_ray.origin, new_ray.direction, 0.0001);
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
                               constant uchar const *materials [[buffer(kernel_buffer_materials)]])
{
    Camera camera(color_buffer.get_width(), color_buffer.get_height(), camera_config);
    RNG rng(grid_index[0], grid_index[1]);
    world w = { accelerationStructure, functionTable };

    float3 color = 0;
    for (uint i = 0; i < render_config.samples_per_pixel; i++) {
        auto r = camera.get_ray(grid_index, &rng);
        color += get_ray_color(ray(r.origin, r.direction), w, materials, &rng, render_config.max_depth);
    }
    color /= render_config.samples_per_pixel;
    color = min(sqrt(color), 1);
    color_buffer.write(float4(color, 1.0), grid_index);
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
    typename T::HitEnumerator e(object, ray);
    for (; e.hasNext(); e.move()) {
        // TODO: Should it be multiplied by vector length?
        float distance = e.t();
        if (distance >= minDistance && distance <= maxDistance) {
            payload.point = e.point();
            payload.set_normal(e.normal(), direction);
            payload.material_offset = e.material_offset();
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

