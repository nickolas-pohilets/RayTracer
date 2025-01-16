//
//  RenderableImpl.h
//  RayTracing
//
//  Created by Mykola Pokhylets on 14/01/2025.
//

#ifndef RENDERABLE_IMPL_H
#define RENDERABLE_IMPL_H

#include "../Renderable.h"
#include "RNG.h"
#include "HitTesting.h"
#include "Defines.h"

inline Ray3D inverse_transform(Ray3D r, Transform t) {
    matrix_float3x3 rInv = transpose(t.rotation);
    return Ray3D(rInv * (r.origin - t.translation), rInv * r.direction);
}

inline Ray3D transform(Ray3D r, Transform t) {
    return Ray3D(t.rotation * r.origin + t.translation, t.rotation * r.direction);
}

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
        float3 oc = _ray.origin - _sphere.transform.translation;
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

    bool isExit() const { return _index == 1; }

    float t() const {
        assert(hasNext());
        return _t[_index];
    }

    float3 point() const {
        return _ray.at(t());
    }

    float3 normal() const {
        return (point() - _sphere.transform.translation) / _sphere.radius;
    }

    size_t material_offset() const {
        return _sphere.material_offset;
    }

    //    var textureCoordinates: Point2D
};

class Cylinder::HitEnumerator {
    struct Hit {
        float t;
        float3 normal;
        size_t material_offset;
    };

    Cylinder _cylinder;
    Ray3D _ray;
    Hit _hit[2];
    int _index;

    static void hitPlane(Cylinder cylinder, Ray3D local_ray, thread Hit & planeIn, thread Hit & planeOut) {
        float denom = local_ray.direction.y; // dot((0,1,0),_local_ray.direction);
        float tb, tt;
        bool has_solutions;
        {
#pragma METAL fp math_mode(safe)
            tb = -local_ray.origin.y / denom;
            tt = (cylinder.height - local_ray.origin.y) / denom;
            has_solutions = isfinite(tb) && isfinite(tt);
        }
        if (has_solutions) {
            planeIn.t = tb;
            planeIn.normal = -cylinder.transform.rotation.columns[1];
            planeIn.material_offset = cylinder.bottom_material_offset;

            planeOut.t = tt;
            planeOut.normal = +cylinder.transform.rotation.columns[1];
            planeOut.material_offset = cylinder.top_material_offset;

            if (planeIn.t > planeOut.t) {
                Hit tmp = planeIn;
                planeIn = planeOut;
                planeOut = tmp;
            }
        } else {
            if (local_ray.origin.y >= 0 && local_ray.origin.y < cylinder.height) {
                // Not constrained by the planes
                planeIn.t = -INFINITY;
                planeOut.t = +INFINITY;
            } else {
                // Out of planes
                planeIn.t = +INFINITY;
                planeOut.t = -INFINITY;
            }
        }
    }

    static void hitTube(Cylinder cylinder, Ray3D local_ray, thread Hit & tubeIn, thread Hit & tubeOut) {
        // let ob = ray.origin - .zero
        // let ot = ray.origin - (0, height, 0)
        // let d = ray.direction
        // let a = -(axis • d).squared() + d • d
        // let b_2 = -axis • d * axis • ob + d • ob
        // let c = -(axis • ob).squared() + ob • ob - (radius).squared()

        float a = fmax(0, -local_ray.direction.y * local_ray.direction.y + 1);
        float b_2 = -local_ray.direction.y * local_ray.origin.y + dot(local_ray.direction, local_ray.origin);
        float c = -local_ray.origin.y * local_ray.origin.y + dot(local_ray.origin, local_ray.origin) - cylinder.radius * cylinder.radius;

        float D_4 = b_2 * b_2 - a * c;
        if (D_4 < 0) {
            tubeIn.t = +INFINITY;
            tubeOut.t = -INFINITY;
            return;
        }

        float D_4_root = sqrt(D_4);
        float t1, t2;
        bool has_solutions;
        {
#pragma METAL fp math_mode(safe)
            t1 = (-b_2 - D_4_root) / a;
            t2 = (-b_2 + D_4_root) / a;
            has_solutions = isfinite(t1) && isfinite(t2);
        }

        if (has_solutions) {
            float3 lp1 = local_ray.at(t1);
            float3 lp2 = local_ray.at(t2);

            tubeIn.t = t1;
            tubeIn.normal = cylinder.transform.rotation * ((float3){lp1.x, 0, lp1.z} / cylinder.radius);
            tubeIn.material_offset = cylinder.side_material_offset;

            tubeOut.t = t2;
            tubeOut.normal = cylinder.transform.rotation * ((float3){lp2.x, 0, lp2.z} / cylinder.radius);
            tubeOut.material_offset = cylinder.side_material_offset;
        } else {
            if (length_squared(local_ray.origin.xz) > cylinder.radius * cylinder.radius) {
                // Ray is outside of the side tube
                tubeIn.t = +INFINITY;
                tubeOut.t = -INFINITY;
            } else {
                // Not constrained by the sides
                tubeIn.t = -INFINITY;
                tubeOut.t = +INFINITY;
            }
        }
    }
public:
    HitEnumerator(Cylinder cylinder, Ray3D ray)
        : _cylinder(cylinder), _ray(ray)
    {
        Ray3D local_ray = inverse_transform(ray, cylinder.transform);

        Hit planeIn, planeOut;
        hitPlane(cylinder, local_ray, planeIn, planeOut);

        // Hit testing side tube
        Hit tubeIn, tubeOut;
        hitTube(cylinder, local_ray, tubeIn, tubeOut);

        _hit[0] = planeIn.t > tubeIn.t ? planeIn : tubeIn;
        _hit[1] = planeOut.t < tubeOut.t ? planeOut : tubeOut;
        _index = _hit[0].t <= _hit[1].t ? 0 : 2;
    }

    bool hasNext() const { return _index < 2; }
    void move() { _index++; }

    bool isExit() const { return _index == 1; }

    float t() const {
        assert(hasNext());
        return _hit[_index].t;
    }

    float3 point() const {
        return _ray.at(t());
    }

    float3 normal() const {
        return _hit[_index].normal;
    }

    size_t material_offset() const {
        return _hit[_index].material_offset;
    }
};


#endif // RENDERABLE_IMPL_H
