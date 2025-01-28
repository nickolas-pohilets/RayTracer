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

inline float3 inverse_transform_point(float3 p, Transform t) {
    matrix_float3x3 rInv = transpose(t.rotation);
    return rInv * (p - t.translation);
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

    float2 texture_coordinates() const {
        float3 n = transpose(_sphere.transform.rotation) * normal();
        float2 result;
        result.x = (atan2(n.z, -n.x) + M_PI_F) / (2 * M_PI_F);
        result.y = acos(-n.y) / M_PI_F;
        return result;
    }
};

class Cylinder::HitEnumerator {
    struct Hit {
        float t;
        float3 normal;
        size_t material_offset;
        float2 texture_coordinates;
    };

    Cylinder _cylinder;
    Ray3D _ray;
    Hit _hit[2];
    int _index;

    static void hit_plane(Cylinder cylinder, Ray3D local_ray, thread Hit & planeIn, thread Hit & planeOut) {
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
            planeIn.texture_coordinates = plane_texture_coordinates(local_ray.at(tb), cylinder.radius, -1);

            planeOut.t = tt;
            planeOut.normal = +cylinder.transform.rotation.columns[1];
            planeOut.material_offset = cylinder.top_material_offset;
            planeOut.texture_coordinates = plane_texture_coordinates(local_ray.at(tt), cylinder.radius, +1);

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

    static float2 plane_texture_coordinates(float3 local_point, float radius, float flipX) {
        float2 result;
        result.x = 0.5 + local_point.z * flipX / (2 * radius);
        result.y = 0.5 + local_point.x / (2 * radius);
        return result;
    }

    static void hit_tube(Cylinder cylinder, Ray3D local_ray, thread Hit & tubeIn, thread Hit & tubeOut) {
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
            tubeIn.texture_coordinates = tube_texture_coordinates(lp1, cylinder.height);

            tubeOut.t = t2;
            tubeOut.normal = cylinder.transform.rotation * ((float3){lp2.x, 0, lp2.z} / cylinder.radius);
            tubeOut.material_offset = cylinder.side_material_offset;
            tubeOut.texture_coordinates = tube_texture_coordinates(lp2, cylinder.height);
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

    static float2 tube_texture_coordinates(float3 local_point, float height) {
        float2 result;
        result.x = (atan2(local_point.z, -local_point.x) + M_PI_F) / (2 * M_PI_F);
        result.y = local_point.y / height;
        return result;
    }
public:
    HitEnumerator(Cylinder cylinder, Ray3D ray)
        : _cylinder(cylinder), _ray(ray)
    {
        Ray3D local_ray = inverse_transform(ray, cylinder.transform);

        Hit planeIn, planeOut;
        hit_plane(cylinder, local_ray, planeIn, planeOut);

        // Hit testing side tube
        Hit tubeIn, tubeOut;
        hit_tube(cylinder, local_ray, tubeIn, tubeOut);

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
        assert(hasNext());
        return _hit[_index].normal;
    }

    size_t material_offset() const {
        assert(hasNext());
        return _hit[_index].material_offset;
    }

    float2 texture_coordinates() const {
        assert(hasNext());
        return _hit[_index].texture_coordinates;
    }
};

class Cuboid::HitEnumerator {
    struct Hit {
        float t;
        float3 normal;
        Face face;
    };

    Cuboid _cuboid;
    Ray3D _ray;
    Hit _hit[2];
    int _index;

    static void hit_plane(float size,
                          float origin, float direction,
                          float3 top_normal, int axis,
                          thread Hit & planeIn, thread Hit & planeOut)
    {
        float denom = direction; // dot((0,1,0),_local_ray.direction);
        float tb, tt;
        bool has_solutions;
        {
#pragma METAL fp math_mode(safe)
            tb = -origin / denom;
            tt = (size - origin) / denom;
            has_solutions = isfinite(tb) && isfinite(tt);
        }
        if (has_solutions) {
            planeIn.t = tb;
            planeIn.normal = -top_normal;
            planeIn.face = (Face)(2*axis);

            planeOut.t = tt;
            planeOut.normal = +top_normal;
            planeOut.face = (Face)(2*axis + 1);

            if (planeIn.t > planeOut.t) {
                Hit tmp = planeIn;
                planeIn = planeOut;
                planeOut = tmp;
            }
        } else {
            if (origin >= 0 && origin < size) {
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

    static float2 plane_texture_coordinates(float3 local_point, float radius, float flipX) {
        float2 result;
        result.x = 0.5 + local_point.z * flipX / (2 * radius);
        result.y = 0.5 + local_point.x / (2 * radius);
        return result;
    }
public:
    HitEnumerator(Cuboid cuboid, Ray3D ray)
        : _cuboid(cuboid), _ray(ray)
    {
        Ray3D local_ray = inverse_transform(ray, cuboid.transform);

        Hit xIn, xOut;
        hit_plane(cuboid.size.x, local_ray.origin.x, local_ray.direction.x, cuboid.transform.rotation.columns[0], 0, xIn, xOut);

        Hit yIn, yOut;
        hit_plane(cuboid.size.y, local_ray.origin.y, local_ray.direction.y, cuboid.transform.rotation.columns[1], 1, yIn, yOut);

        Hit zIn, zOut;
        hit_plane(cuboid.size.z, local_ray.origin.z, local_ray.direction.z, cuboid.transform.rotation.columns[2], 2, zIn, zOut);

        _hit[0] = xIn.t > yIn.t ? (xIn.t > zIn.t ? xIn : zIn) : (yIn.t > zIn.t ? yIn : zIn);
        _hit[1] = xOut.t < yOut.t ? (xOut.t < zOut.t ? xOut : zOut) : (yOut.t < zOut.t ? yOut : zOut);
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
        assert(hasNext());
        return _hit[_index].normal;
    }

    size_t material_offset() const {
        assert(hasNext());
        return _cuboid.material_offset[_hit[_index].face];
    }

    float2 texture_coordinates() const {
        float3 p = point();
        float3 local_p = inverse_transform_point(p, _cuboid.transform) / _cuboid.size;
        Face face = _hit[_index].face;
        float2 result;
        switch (face) {
        case left:
            result.x = 1 - local_p.z;
            result.y = local_p.y;
            break;
        case front:
            result.x = local_p.x;
            result.y = local_p.y;
            break;
        case right:
            result.x = local_p.z;
            result.y = local_p.y;
            break;
        case back:
            result.x = 1 - local_p.x;
            result.y = local_p.y;
            break;
        case top:
            result.x = local_p.x;
            result.y = local_p.z;
            break;
        case bottom:
            result.x = local_p.x;
            result.y = 1 - local_p.z;
            break;
        }
        return result;
    }
};

class Quad::HitEnumerator {
    int _index;
    float _hit[2];
    float3 _point;
    float3 _normal;
    float2 _texture_coordinates;
    size_t _material_offset;
public:
    HitEnumerator(Quad object, Ray3D ray)
    {
        float denom = dot(ray.direction, object.normal);
        float t;
        bool has_solutions;
        {
#pragma METAL fp math_mode(safe)
            t = (object.d - dot(ray.origin, object.normal)) / denom;
            has_solutions = isfinite(t);
        }
        if (has_solutions) {

            _hit[0] = denom < 0 ? t : -INFINITY;
            _hit[1] = denom < 0 ? +INFINITY : t;

            _point = ray.at(t);
            _normal = object.normal;
            float3 p = _point - object.origin;
            // p = α * u + β * v
            // w • (p ⨯ v) = w • (α * (u ⨯ v) + β * (v ⨯ v)) = α * (n / |n|²) • n = α
            // w • (u ⨯ p) = w • (α * (u ⨯ u) + β * (u ⨯ v)) = β * (n / |n|²) • n = β
            _texture_coordinates.x = dot(object.w, cross(p, object.v));
            _texture_coordinates.y = dot(object.w, cross(object.u, p));
            _material_offset = object.material_offset;

            if (_texture_coordinates.x < 0 || _texture_coordinates.x > 1 || _texture_coordinates.y < 0 || _texture_coordinates.y > 1) {
                _index = 2;
            } else {
                _index = 0;
            }
        } else {
            _index = 2;
        }
    }

    bool hasNext() const { return _index < 2; }
    void move() { _index++; }

    bool isExit() const { return _index == 1; }

    float t() const {
        assert(hasNext());
        return _hit[_index];
    }

    float3 point() const {
        assert(isfinite(t()));
        return _point;
    }

    float3 normal() const {
        assert(isfinite(t()));
        return _normal;
    }

    size_t material_offset() const {
        assert(isfinite(t()));
        return _material_offset;
    }

    float2 texture_coordinates() const {
        assert(isfinite(t()));
        return _texture_coordinates;
    }
};

template<class... T> struct tuple;
template<> struct tuple <> {
    enum { size = 0 };

    tuple() {};

    template<class F>
    tuple(F f, thread tuple<> const & other) {}
};

template<class H> struct tuple<H> {
    enum { size = 1 };

    H head;

    tuple<> get_tail() const { return tuple<>(); }

    tuple(H h): head(h) {}

    template<class F, class H2>
    tuple(F f, thread tuple<H2> const & other): head(f(other.head)) {}
};

template<class H, class M, class... T> struct tuple<H, M, T...> {
    enum { size = 1 + tuple<M, T...>::size };
    H head;
    tuple<M, T...> tail;

    tuple(H h, M m, T... t): head(h), tail(m, t...) {}

    thread tuple<M, T...> & get_tail() { return tail; }
    thread tuple<M, T...> const & get_tail() const { return tail; }

    template<class F, class H2, class...T2>
    tuple(F f, thread tuple<H2, T2...> const & other): head(f(other.head)), tail(f, other.tail) {}
};

template<int min_count, bool subtract, class... T>
struct Composition {
    tuple<T...> _items;

    Composition(T... items): _items(items...) {}

    class HitEnumerator;
};

template<class... T>
using Union = Composition<1, false, T...>;

template<class... T>
using Intersection = Composition<tuple<T...>::size, false, T...>;

template<class... T>
using Subtract = Composition<1, true, T...>;


namespace composition_impl {

struct NearestChild {
    size_t index;
    float best_t;
};

template<class H, class... T>
void getNearestChild(size_t index, thread NearestChild & ctx, thread tuple<H, T...> const & children) {
    getNearestChild(index + 1, ctx, children.get_tail());

    if (children.head.hasNext()) {
        float t = children.head.t();
        if (t < ctx.best_t) {
            ctx.index = index;
            ctx.best_t = t;
        }
    }
}

void getNearestChild(size_t index, thread NearestChild & ctx, thread tuple<> const &) {
    ctx.index = (size_t)(ptrdiff_t)-1;
    ctx.best_t = +INFINITY;
}

bool anyHasNext(thread tuple<> const & children) {
    return false;
}

template<class H, class... T>
bool anyHasNext(thread tuple<H, T...> const & children) {
    if (children.head.hasNext()) { return true; }
    return anyHasNext(children.get_tail());
}

template<class F, class H, class... T>
typename F::result withSelectedChild(F f, size_t selected_index, size_t current_index, thread tuple<H, T...> & children) {
    if (selected_index == current_index) {
        return f(children.head);
    }
    return withSelectedChild<F, T...>(f, selected_index, current_index + 1, children.get_tail());
}

template<class F, class H, class... T>
typename F::result withSelectedChild(F f, size_t selected_index, size_t current_index, thread tuple<H, T...> const & children) {
    if (selected_index == current_index) {
        return f(children.head);
    }
    return withSelectedChild<F, T...>(f, selected_index, current_index + 1, children.get_tail());
}

template<class F>
typename F::result withSelectedChild(F f, size_t selected_index, size_t current_index, thread tuple<> const & children) {
    assert(false);
    return typename F::result();
}

struct Move {
    typedef void result;

    template<class E>
    result operator()(thread E & e) const {
        e.move();
    }
};

struct IsExit {
    typedef bool result;

    template<class E>
    result operator()(thread E const & e) const {
        return e.isExit();
    }
};

struct GetT {
    typedef float result;

    template<class E>
    result operator()(thread E const & e) const {
        return e.t();
    }
};

struct GetPoint {
    typedef float3 result;

    template<class E>
    result operator()(thread E const & e) const {
        return e.point();
    }
};

struct GetNormal {
    typedef float3 result;

    template<class E>
    result operator()(thread E const & e) const {
        return e.normal();
    }
};

struct GetMaterial {
    typedef size_t result;

    template<class E>
    result operator()(thread E const & e) const {
        return e.material_offset();
    }
};

struct GetTextureCoordinates {
    typedef float2 result;

    template<class E>
    result operator()(thread E const & e) const {
        return e.texture_coordinates();
    }
};

struct GetHitEnumerator {
    Ray3D _ray;

    explicit GetHitEnumerator(Ray3D ray): _ray(ray) {}

    template<class T>
    typename T::HitEnumerator operator()(thread T const & object) {
        return typename T::HitEnumerator(object, _ray);
    }
};

} // namespace composition_impl

template<int min_count, bool subtract, class... T>
class Composition<min_count, subtract, T...>::HitEnumerator {
    tuple<typename T::HitEnumerator...> _children;
    int _depth;
    composition_impl::NearestChild _currentChild;

    void chooseChild() {
        composition_impl::getNearestChild(0, _currentChild, _children);
    }

    template<class F>
    typename F::result withSelectedChild(F f) {
        return composition_impl::withSelectedChild(f, _currentChild.index, 0, _children);
    }

    template<class F>
    typename F::result withSelectedChild(F f) const {
        return composition_impl::withSelectedChild(f, _currentChild.index, 0, _children);
    }

    void scanDepth() {
        bool wasInside = (_depth >= min_count);
        while (composition_impl::anyHasNext(_children)) {
            chooseChild();
            if (withSelectedChild(composition_impl::IsExit()) != (subtract && _currentChild.index > 0)) {
                _depth--;
            } else {
                _depth++;
            }
            bool isInside = (_depth >= min_count);
            if (isInside != wasInside) break;
            withSelectedChild(composition_impl::Move());
        }
    }

    bool shouldSwap() const {
        return subtract && _currentChild.index > 0;
    }
public:
    HitEnumerator(Composition<min_count, subtract, T...> object, Ray3D ray) : _children(composition_impl::GetHitEnumerator(ray), object._items)
    {
        _depth = 0;
        scanDepth();
    }

    bool hasNext() const { return composition_impl::anyHasNext(_children); }
    void move() {
        withSelectedChild(composition_impl::Move());
        scanDepth();
    }

    bool isExit() const { return withSelectedChild(composition_impl::IsExit()) != shouldSwap(); }
    float t() const { return withSelectedChild(composition_impl::GetT()); }
    float3 point() const { return withSelectedChild(composition_impl::GetPoint()); }
    float3 normal() const { return withSelectedChild(composition_impl::GetNormal()) * (shouldSwap() ? -1 : +1); }
    size_t material_offset() const { return withSelectedChild(composition_impl::GetMaterial()); }
    float2 texture_coordinates() const { return withSelectedChild(composition_impl::GetTextureCoordinates()); }
};

template<class R>
class ConstantDensityVolume {
    R _impl;
    float density;
public:
    ConstantDensityVolume(R impl): _impl(impl) {}

    class HitEnumerator;
};

template<class R>
class ConstantDensityVolume<R>::HitEnumerator {
    typename R::HitEnumerator _impl;
    Ray3D _ray;
    thread RNG *_rng;
    float _neg_inv_density;
    bool _exit;
    float _t;
    HitInfo _hit;

    void scan() {
        while (_impl.hasNext()) {
            assert(!_impl.isExit());
            float t1 = max(0.0f, _impl.t());
            size_t material = _impl.material_offset();
            float2 tex = _impl.texture_coordinates();

            _impl.move();
            float t2;
            if (_impl.hasNext()) {
                assert(_impl.isExit());
                t2 = _impl.t();
            } else {
                t2 = +INFINITY;
            }

            if (t1 < t2) {
                float t = t1 + log(1 - _rng->random_f()) * _neg_inv_density;
                if (t <= t2) {
                    _exit = false;
                    _t = t;
                    _hit.point = _ray.at(t);
                    _hit.normal = -_ray.direction;
                    _hit.face = face::front;
                    _hit.material_offset = material;
                    _hit.texture_coordinates = tex;
                    break;
                }
            }
            if (_impl.hasNext()) {
                _impl.move();
            }
        }
        _exit = true;
    }
public:
    HitEnumerator(ConstantDensityVolume<R> object, Ray3D ray, thread RNG* rng) : _impl(object._impl, ray), _ray(ray), _rng(rng), _neg_inv_density(-1/object.density)
    {
        scan();
    }

    bool hasNext() const { return !_exit || _impl.hasNext(); }
    void move() {
        if (_exit) {
            _impl.move();
            scan();
        } else {
            _exit = true;
        }
    }

    bool isExit() const { return _exit; }
    float t() const { return _exit ? _impl.t() : _t; }
    float3 point() const { return _exit ? _impl.point() : _hit.point; }
    float3 normal() const { return _exit ? _impl.normal() : _hit.normal; }
    size_t material_offset() const { return _exit ? _impl.material_offset() : _hit.material_offset; }
    float2 texture_coordinates() const { return _exit ? _impl.texture_coordinates() : _hit.texture_coordinates; }
};


#endif // RENDERABLE_IMPL_H
