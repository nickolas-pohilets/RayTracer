//
//  Hittable.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//

public enum Face {
    case front
    case back

    var inverted: Face {
        switch self {
        case .front: return .back
        case .back: return .front
        }
    }
}

public struct HitRecord {
    var t: Double
    var point: Point3D
    var normal: Vector3D
    var face: Face
    var material: any Material

    public init(t: Double, point: Point3D, normal: Vector3D, face: Face, material: any Material) {
        self.t = t
        self.point = point
        self.normal = normal
        self.face = face
        self.material = material
    }

    public init(t: Double, point: Point3D, normal: Vector3D, rayDirection: Vector3D, material: any Material) {
        self.t = t
        self.point = point
        if normal • rayDirection > 0 {
            self.normal = -normal
            self.face = .back
        } else {
            self.normal = normal
            self.face = .front
        }
        self.material = material
    }

    var inverted: HitRecord {
        .init(t: t, point: point, normal: normal, face: face.inverted, material: material)
    }
}

public struct HitRange {
    public var entry: HitRecord
    public var exit: HitRecord

    public init(_ a: HitRecord, _ b: HitRecord) {
        if a.t <= b.t {
            self.entry = a
            self.exit = b
        } else {
            self.entry = b
            self.exit = a
        }
    }
}

public protocol Hittable {
    func hit(ray: Ray3D, range: Range<Double>) -> HitRecord?
}

public protocol HittableVolume: Hittable {
    func hits(ray: Ray3D) -> [HitRange]
}

public protocol HittableConvexVolume: HittableVolume {
    func hit(ray: Ray3D) -> HitRange?
}

extension HittableVolume {
    public func hit(ray: Ray3D, range: Range<Double>) -> HitRecord? {
        let ranges = self.hits(ray: ray)
        for r in ranges {
            if range.contains(r.entry.t) {
                return r.entry
            }
            if range.contains(r.exit.t) {
                return r.exit
            }
        }
        return nil
    }
}

extension HittableConvexVolume {
    public func hits(ray: Ray3D) -> [HitRange] {
        if let range = self.hit(ray: ray) {
            return [range]
        }
        return []
    }

    public func hit(ray: Ray3D, range: Range<Double>) -> HitRecord? {
        if let r = self.hit(ray: ray) {
            if range.contains(r.entry.t) {
                return r.entry
            }
            if range.contains(r.exit.t) {
                return r.exit
            }
        }
        return nil
    }
}

public struct Sphere: HittableVolume {
    var center: Point3D
    var radius: Double
    var material: any Material

    public init(center: Point3D, radius: Double, material: any Material) {
        self.center = center
        self.radius = radius
        self.material = material
    }

    public func hits(ray: Ray3D) -> [HitRange] {
        // P = ray[t]
        // (ray.origin + ray.direction * t - C) • (ray.origin + ray.direction * t - C) = radius²
        // (ray.direction * t + (ray.origin - C)) • (ray.direction * t + (ray.origin - C)) = radius²
        // (ray.direction * t + (ray.origin - C)) • (ray.direction * t + (ray.origin - C)) = radius²
        // t² * ray.direction • ray.direction + t * (2 * ray.direction • (ray.origin - C)) + (ray.origin - C) • (ray.origin - C) - radius² = 0
        let oc = ray.origin - center
        let a = ray.direction • ray.direction
        let b_2 = ray.direction • oc
        let c = oc • oc - radius * radius
        let D_4 = b_2 * b_2 - a * c
        if D_4 < 0 { return [] }
        let hit1 = hitRecord(for: (-b_2 - D_4.squareRoot()) / a, in: ray)
        let hit2 = hitRecord(for: (-b_2 + D_4.squareRoot()) / a, in: ray)
        return [HitRange(hit1, hit2)]
    }

    private func hitRecord(for t: Double, in ray: Ray3D) -> HitRecord {
        let point = ray[t]
        let normal = (point - center) / radius
        return HitRecord(t: t, point: point, normal: normal, rayDirection: ray.direction, material: material)
    }
}

public struct Cylinder: HittableConvexVolume {
    public var bottomCenter: Point3D
    public var topCenter: Point3D
    public var radius: Double
    var material: any Material

    public init(bottomCenter: Point3D, topCenter: Point3D, radius: Double, material: any Material) {
        self.bottomCenter = bottomCenter
        self.topCenter = topCenter
        self.radius = radius
        self.material = material
    }

    public func hit(ray: Ray3D) -> HitRange? {
        // P = ray[t]
        // Q = (P - baseCenter) = ray.direction * t + (ray.origin - baseCenter)
        // Qp = axis * (Q • axis)
        // Qr = Q - Qp
        // Qr • Qr = radius²

        let sizedAxis = (topCenter - bottomCenter)
        let height = sizedAxis.length
        let axis = sizedAxis / height

        let ob = ray.origin - bottomCenter
        let ot = ray.origin - topCenter

        var hitRanges: [HitRange] = []
        do {
            let denom = axis • ray.direction

            let db = -(ob • axis)
            let dt = -(ot • axis)
            let tb = db / denom
            let tt = dt / denom

            if tb.isFinite && tt.isFinite {
                let hitB = HitRecord(t: tb, point: ray[tb], normal: -axis, rayDirection: ray.direction, material: material)
                let hitT = HitRecord(t: tt, point: ray[tt], normal: axis, rayDirection: ray.direction, material: material)
                hitRanges.append(HitRange(hitB, hitT))
            } else {
                // Ray is parallel to the bottom planes
                if db < 0 && dt < 0 || db > 0 && dt > 0 {
                    // No intersection
                    return nil
                }
                // Not constrained by the top/bottom planes
            }
        }

        do {
            let d = ray.direction

            let a = -(axis • d).squared() + d • d
            let b_2 = -axis • d * axis • ob + d • ob
            let c = -(axis • ob).squared() + ob • ob - (radius).squared()

            let D_4 = b_2 * b_2 - a * c
            if D_4 < 0 { return nil }
            let D_4_root = D_4.squareRoot()
            let t1 = (-b_2 - D_4_root) / a
            let t2 = (-b_2 + D_4_root) / a

            let axisRay = Ray3D(origin: bottomCenter, direction: axis)

            if t1.isFinite && t2.isFinite {
                let p1 = ray[t1]
                let p2 = ray[t2]
                let n1 = (p1 - axisRay.projection(of: p1)).normalized()
                let n2 = (p2 - axisRay.projection(of: p2)).normalized()
                let hit1 = HitRecord(t: t1, point: p1, normal: n1, rayDirection: ray.direction,  material: material)
                let hit2 = HitRecord(t: t2, point: p2, normal: n2, rayDirection: ray.direction,  material: material)
                hitRanges.append(HitRange(hit1, hit2))
            } else {
                // Ray is parallel to the axis
                if axisRay.distanceSquared(to: ray.origin) > radius.squared() {
                    // Ray is outside of the side tube
                    return nil
                }
                // Not constrained by the sides
            }
        }

        var intersection: HitRange = hitRanges[0]
        for hr in hitRanges.dropFirst() {
            if hr.entry.t > intersection.entry.t {
                intersection.entry = hr.entry
            }
            if hr.exit.t < intersection.exit.t {
                intersection.exit = hr.exit
            }
        }
        if intersection.exit.t < intersection.entry.t {
            return nil
        }

        return intersection
    }
}

public struct Plane {
    var normal: Vector3D
    var d: Double

    init(normal: Vector3D, d: Double) {
        self.normal = normal
        self.d = d
    }

    init(normal: Vector3D, point: Point3D) {
        self.normal = normal
        self.d = -(normal • point)
    }

    func distance(to point: Point3D) -> Double {
        return normal • point + d
    }
}

extension [HitRange] {
    public func hit(at index: Int) -> HitRecord {
        let r = self[index / 2]
        if (index % 2 == 0) {
            return r.entry
        } else {
            return r.exit
        }
    }
}

struct Composition: HittableVolume {
    enum Operation {
        case union
        case intersection
        case subtract
    }

    var operation: Operation
    var items: [any HittableVolume]

    func hits(ray: Ray3D) -> [HitRange] {
        var ranges = items[0].hits(ray: ray)
        for item in items.dropFirst() {
            let next = item.hits(ray: ray)
            switch operation {
            case .union:
                ranges = Self.makeUnion(lhs: ranges, rhs: next)
            case .intersection:
                ranges = Self.makeUnion(lhs: ranges, rhs: next)
            case .subtract:
                ranges = Self.makeDifference(lhs: ranges, rhs: next)
            }
        }
        return ranges
    }

    static func enumerateHits(lhs: [HitRange], rhs: [HitRange], _ block: (HitRecord, Bool) -> Void) {
        var i = 0, j = 0
        while true {
            if i < 2 * lhs.count {
                let lhsHit = lhs.hit(at: i)
                if j < 2 * rhs.count {
                    let rhsHit = rhs.hit(at: j)
                    if lhsHit.t < rhsHit.t {
                        block(lhsHit, false)
                        i += 1
                    } else {
                        block(rhsHit, true)
                        j += 1
                    }
                } else {
                    block(lhsHit, false)
                    i += 1
                }
            } else {
                if j < 2 * rhs.count {
                    let rhsHit = rhs.hit(at: j)
                    block(rhsHit, true)
                    j += 1
                } else {
                    break
                }
            }
        }
    }

    static func makeUnion(lhs: [HitRange], rhs: [HitRange]) -> [HitRange] {
        var result: [HitRange] = []
        var entry: HitRecord?
        var depth: Int = 0
        enumerateHits(lhs: lhs, rhs: rhs) { hit, _ in
            if hit.face == .front {
                if entry == nil {
                    entry = hit
                }
                depth += 1
            } else {
                depth -= 1
                if depth == 0 {
                    result.append(HitRange(entry!, hit))
                    entry = nil
                }
            }
        }
        return result
    }

    static func makeIntersection(lhs: [HitRange], rhs: [HitRange]) -> [HitRange] {
        var result: [HitRange] = []
        var entry: HitRecord?
        var depth: Int = 0
        enumerateHits(lhs: lhs, rhs: rhs) { hit, _ in
            if hit.face == .front {
                depth += 1
                if depth == 2 {
                    entry = hit
                }
            } else {
                if depth == 2  {
                    result.append(HitRange(entry!, hit))
                    entry = nil
                }
                depth -= 1
            }
        }
        return result
    }

    static func makeDifference(lhs: [HitRange], rhs: [HitRange]) -> [HitRange] {
        var result: [HitRange] = []
        var entry: HitRecord?
        var depth: Int = 0
        enumerateHits(lhs: lhs, rhs: rhs) { hit, isRight in
            if (hit.face == .front) != isRight {
                depth += 1
            } else {
                depth -= 1
            }
            if depth == 1 {
                entry = isRight ? hit.inverted : hit
            } else {
                if let e = entry {
                    let exit = isRight ? hit.inverted : hit
                    result.append(HitRange(e, exit))
                    entry = nil
                }
            }
        }
        return result
    }
}

extension Array: Hittable where Element == any Hittable {
    public func hit(ray: Ray3D, range: Range<Double>) -> HitRecord? {
        var result: HitRecord?
        for item in self {
            let itemRange = range.lowerBound..<(result?.t ?? range.upperBound)
            if let hit = item.hit(ray: ray, range: itemRange) {
                result = hit
            }
        }
        return result
    }
}
