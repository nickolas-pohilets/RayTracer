//
//  Config.h
//  RayTracing
//
//  Created by Mykola Pokhylets on 13/01/2025.
//

#ifndef CONFIG_H
#define CONFIG_H

#include <simd/simd.h>

struct CameraConfig {
    float vertical_POV;
    vector_float3 look_from;
    vector_float3 look_at;
    vector_float3 up;
    float defocus_angle;
    float focus_distance;
} __attribute__((swift_private));

struct RenderConfig {
    unsigned int samples_per_pixel;
    unsigned int max_depth;
} __attribute__((swift_private));

enum kernel_buffers {
    kernel_buffer_output_texture,
    kernel_buffer_camera_config,
    kernel_buffer_render_config,
    kernel_buffer_acceleration_structure,
    kernel_buffer_function_table,
    kernel_buffer_materials
} __attribute__((enum_extensibility(closed)));

#endif // CONFIG_H
