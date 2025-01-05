//
//  AABB.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 30/12/2024.
//

public struct AABB {
    private var _min: Point3D
    private var _max: Point3D

    private init(_min: Point3D, _max: Point3D) {
        self._min = _min
        self._max = _max
    }

    public init() {
        _min = Point3D(x: .infinity, y: .infinity, z: .infinity)
        _max = -_min
    }

    public init(_ points: Point3D...) {
        self.init()
        for p in points {
            add(p)
        }
    }

    public init(_ children: AABB...) {
        self.init()
        for box in children {
            add(box._min)
            add(box._max)
        }
    }

    mutating func add(_ point: Point3D) {
        _min.x = min(_min.x, point.x)
        _min.y = min(_min.y, point.y)
        _min.z = min(_min.z, point.z)
        _max.x = max(_max.x, point.x)
        _max.y = max(_max.y, point.y)
        _max.z = max(_max.z, point.z)
    }

    mutating func add(_ box: AABB) {
        add(box._min)
        add(box._max)
    }

    public var center: Point3D {
        return (_min + _max) / 2
    }

    public var size: Vector3D {
        return _max - _min
    }

    public var longestAxis: Axis3D {
        let size = _max - _min
        if size.x > size.y {
            return size.x > size.z ? .x : .z
        } else {
            return size.y > size.z ? .y : .z
        }
    }

    public func translate(by offset: Vector3D) -> Self {
        return AABB(_min: _min + offset, _max: _max + offset)
    }

    public func contains(_ point: Point3D, threshold: Double = 0.0) -> Bool {
        _min.x - threshold <= point.x && point.x <= _max.x + threshold
        && _min.y - threshold <= point.y && point.y <= _max.y + threshold
        && _min.z - threshold <= point.z && point.z <= _max.z + threshold
    }

    func hit(ray: Ray3D) -> ClosedRange<Double>? {
        var tEntry: Double = -Double.infinity
        var tExit: Double = +Double.infinity
        for axis in Axis3D.allCases {
            let t1 = (_min[axis] - ray.origin[axis]) / ray.direction[axis]
            let t2 = (_max[axis] - ray.origin[axis]) / ray.direction[axis]
            if t1.isFinite && t2.isFinite {
                let tMin = min(t1, t2)
                let tMax = max(t1, t2)
                tEntry = max(tEntry, tMin)
                tExit = min(tExit, tMax)
            }
        }
        if tEntry >= tExit { return nil }
        return tEntry...tExit
    }

    public func enumerateCorners(_ block: (Vector3D) -> Void) {
        for i in 0..<8 {
            let x = (i & 1) != 0 ? _max.x : _min.x
            let y = (i & 2) != 0 ? _max.y : _min.z
            let z = (i & 4) != 0 ? _max.z : _min.z
            block(Vector3D(x: x, y: y, z: z))
        }
    }
}
