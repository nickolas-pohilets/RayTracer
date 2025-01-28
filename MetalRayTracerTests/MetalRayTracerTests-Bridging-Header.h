//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#include <vector>
#define USE_TEST_RNG 1
#import "../MetalRayTracer/Impl/RenderableImpl.h"

class CylinderDiff {
    Subtract<Cylinder, Cylinder> _impl;
public:
    CylinderDiff(Cylinder lhs, Cylinder rhs): _impl(lhs, rhs) {}

    class HitEnumerator;
};

class CylinderDiff::HitEnumerator {
    Subtract<Cylinder, Cylinder>::HitEnumerator _impl;
public:
    HitEnumerator(CylinderDiff object, Ray3D ray): _impl(object._impl, ray) {}

    bool hasNext() const { return _impl.hasNext(); }
    void move() {
        _impl.move();
    }

    bool isExit() const { return _impl.isExit(); }
    float t() const { return _impl.t(); }
    float3 point() const { return _impl.point(); }
    float3 normal() const { return _impl.normal(); }
    size_t material_offset() const { return _impl.material_offset(); }
    float2 texture_coordinates() const { return _impl.texture_coordinates(); }
};

class Combo {
    Subtract<Intersection<Cuboid, Sphere>, Cylinder> _impl;
public:
    Combo(Cuboid cuboid, Sphere sphere, Cylinder cylinder): _impl(Intersection<Cuboid, Sphere>(cuboid, sphere), cylinder) {}

    class HitEnumerator;
};

class Combo::HitEnumerator {
    Subtract<Intersection<Cuboid, Sphere>, Cylinder>::HitEnumerator _impl;
public:
    HitEnumerator(Combo object, Ray3D ray): _impl(object._impl, ray) {}

    bool hasNext() const { return _impl.hasNext(); }
    void move() {
        _impl.move();
    }

    bool isExit() const { return _impl.isExit(); }
    float t() const { return _impl.t(); }
    float3 point() const { return _impl.point(); }
    float3 normal() const { return _impl.normal(); }
    size_t material_offset() const { return _impl.material_offset(); }
    float2 texture_coordinates() const { return _impl.texture_coordinates(); }
};


class CuboidFog {
    ConstantDensityVolume<Cuboid> _impl;
public:
    CuboidFog(Cuboid impl, float density): _impl(impl, density) {}

    class HitEnumerator;
};

class CuboidFog::HitEnumerator {
    ConstantDensityVolume<Cuboid>::HitEnumerator _impl;
public:
    HitEnumerator(CuboidFog object, Ray3D ray, thread RNG* rng): _impl(object._impl, ray, rng) {};

    bool hasNext() const { return _impl.hasNext(); }
    void move() {
        _impl.move();
    }

    bool isExit() const { return _impl.isExit(); }
    float t() const { return _impl.t(); }
    float3 point() const { return _impl.point(); }
    float3 normal() const { return _impl.normal(); }
    size_t material_offset() const { return _impl.material_offset(); }
    float2 texture_coordinates() const { return _impl.texture_coordinates(); }
};

