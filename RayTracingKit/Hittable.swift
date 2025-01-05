//
//  Hittable.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//
import Foundation

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

public struct Point2D {
    public var u: Double
    public var v: Double

    public init(u: Double, v: Double) {
        self.u = u
        self.v = v
    }
}

public struct HitRecord {
    var t: Double
    var point: Point3D
    var normal: Vector3D
    var face: Face
    var material: any Material
    var textureCoordinates: Point2D

    public init(t: Double, point: Point3D, normal: Vector3D, face: Face, material: any Material, textureCoordinates: Point2D) {
        self.t = t
        self.point = point
        self.normal = normal
        self.face = face
        self.material = material
        self.textureCoordinates = textureCoordinates
    }

    public init(t: Double, point: Point3D, normal: Vector3D, rayDirection: Vector3D, material: any Material, textureCoordinates: Point2D) {
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
        self.textureCoordinates = textureCoordinates
    }

    var inverted: HitRecord {
        var result = self
        result.face = face.inverted
        return result
    }

    mutating func apply(transform: Transform3D) {
        point = transform.transform(point)
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

    mutating func apply(transform: Transform3D) {
        entry.apply(transform: transform)
        exit.apply(transform: transform)
    }
}

public protocol Hittable {
    var center: Point3D { get }
    var boundingBox: AABB { get }
    func hit(ray: Ray3D, time: Double, range: Range<Double>) -> HitRecord?
}

public protocol HittableVolume: Hittable {
    func hits(ray: Ray3D, time: Double) -> [HitRange]
}

public protocol HittableConvexVolume: HittableVolume {
    func hit(ray: Ray3D, time: Double) -> HitRange?
}

extension HittableVolume {
    public func hit(ray: Ray3D, time: Double, range: Range<Double>) -> HitRecord? {
        let ranges = self.hits(ray: ray, time: time)
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
    public func hits(ray: Ray3D, time: Double) -> [HitRange] {
        if let range = self.hit(ray: ray, time: time) {
            return [range]
        }
        return []
    }

    public func hit(ray: Ray3D, time: Double, range: Range<Double>) -> HitRecord? {
        if let r = self.hit(ray: ray, time: time) {
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
    public var center: Point3D
    public var radius: Double
    public var material: any Material

    public init(center: Point3D, radius: Double, material: any Material) {
        self.center = center
        self.radius = radius
        self.material = material
    }

    public var boundingBox: AABB {
        let r = Vector3D(x: radius, y: radius, z: radius)
        return AABB(center - r, center + r)
    }

    public func hits(ray: Ray3D, time: Double) -> [HitRange] {
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
        let textureCoordinates = Self.textureCoordinates(normal: normal)
        return HitRecord(t: t, point: point, normal: normal, rayDirection: ray.direction, material: material, textureCoordinates: textureCoordinates)
    }

    private static func textureCoordinates(normal: Vector3D) -> Point2D {
        return Point2D(
            u: (atan2(-normal.z, normal.x) + .pi) / (2 * .pi),
            v: acos(-normal.y) / .pi
        )
    }
}

public struct Cylinder: HittableConvexVolume {
    public var radius: Double
    public var height: Double
    var bottom: any Material
    var top: any Material
    var side: any Material

    public init(radius: Double, height: Double, bottom: any Material, top: any Material, side: any Material) {
        assert(radius >= 0)
        assert(height >= 0)
        self.radius = radius
        self.height = height
        self.bottom = bottom
        self.top = top
        self.side = side
    }

    public var center: Point3D {
        return Vector3D(x: 0, y: height * 0.5, z: 0)
    }

    public var boundingBox: AABB {
        AABB(
            Vector3D(x: -radius, y: 0, z: -radius),
            Vector3D(x: +radius, y: height, z: +radius)
        )
    }

    public func hit(ray: Ray3D, time: Double) -> HitRange? {
        // P = ray[t]
        // Q = (P - baseCenter) = ray.direction * t + (ray.origin - baseCenter)
        // Qp = axis * (Q • axis)
        // Qr = Q - Qp
        // Qr • Qr = radius²

        let axis = Vector3D(x: 0, y: 1, z: 0)

        let ob = ray.origin - .zero
        let ot = ray.origin - Vector3D(x: 0, y: height, z: 0)

        let textureWidth = radius * 2 * .pi
        let textureHeight = height + 2 * radius

        var hitRanges: [HitRange] = []
        do {
            let denom = axis • ray.direction

            let db = -(ob • axis)
            let dt = -(ot • axis)
            let tb = db / denom
            let tt = dt / denom

            if tb.isFinite && tt.isFinite {
                let pb = ray[tb]
                let textureCoordinatesB = Point2D(u: 0.5 + pb.x / (2 * radius), v: 0.5 + pb.z / (2 * radius))
                let hitB = HitRecord(t: tb, point: pb, normal: -axis, rayDirection: ray.direction, material: bottom, textureCoordinates: textureCoordinatesB)
                let pt = ray[tt]
                let textureCoordinatesT = Point2D(u: 0.5 + pt.x / (2 * radius), v: 0.5 + pt.z / (2 * radius))
                let hitT = HitRecord(t: tt, point: pt, normal: axis, rayDirection: ray.direction, material: top, textureCoordinates: textureCoordinatesT)
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

            let axisRay = Ray3D(origin: .zero, direction: axis)

            if t1.isFinite && t2.isFinite {
                let p1 = ray[t1]
                let p2 = ray[t2]
                let n1 = (p1 - axisRay.projection(of: p1)).normalized()
                let n2 = (p2 - axisRay.projection(of: p2)).normalized()
                let tc1 = Point2D(u: atan2(p1.z, p1.x) / (2 * .pi), v: p1.y / height)
                let tc2 = Point2D(u: atan2(p2.z, p2.x) / (2 * .pi), v: p2.y / height)
                let hit1 = HitRecord(t: t1, point: p1, normal: n1, rayDirection: ray.direction,  material: side, textureCoordinates: tc1)
                let hit2 = HitRecord(t: t2, point: p2, normal: n2, rayDirection: ray.direction,  material: side, textureCoordinates: tc2)
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

public struct Composition: HittableVolume {
    public enum Operation {
        case union
        case intersection
        case subtract
    }

    public init(operation: Operation, items: [any HittableVolume]) {
        self.operation = operation
        self.items = items
        self.boundingBox = AABB()
        for item in items {
            boundingBox.add(item.boundingBox)
        }
    }

    public var operation: Operation
    public var items: [any HittableVolume]
    public private(set) var boundingBox: AABB

    public var center: Point3D { boundingBox.center }

    public func hits(ray: Ray3D, time: Double) -> [HitRange] {
        var ranges = items[0].hits(ray: ray, time: time)
        for item in items.dropFirst() {
            let next = item.hits(ray: ray, time: time)
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

public struct MotionBlur<Base: HittableVolume>: HittableVolume {
    var transform: Transform3D
    var base: Base

    public init(transform: Transform3D, base: Base) {
        self.transform = transform
        self.base = base
    }

    public var center: Point3D {
        return boundingBox.center
    }

    public var boundingBox: AABB {
        var result = AABB()
        let box = base.boundingBox
        if transform.rotation.isIdentity {
            result.add(box)
            result.add(box.translate(by: transform.translation))
        } else {
            box.enumerateCorners { p in
                let box = transform.boundingBox(for: p)
                result.add(box)
            }
        }
        return result
    }

    public func hits(ray: Ray3D, time: Double) -> [HitRange] {
        return transformed(time: time).hits(ray: ray, time: time)
    }

    public func hit(ray: Ray3D, time: Double, range: Range<Double>) -> HitRecord? {
        return transformed(time: time).hit(ray: ray, time: time, range: range)
    }

    public func transformed(time: Double) -> Transformed<Base> {
        let tr = transform.pow(time)
        return Transformed(transform: tr, base: base)
    }
}

extension MotionBlur: HittableConvexVolume where Base: HittableConvexVolume {
    public func hit(ray: Ray3D, time: Double) -> HitRange? {
        return transformed(time: time).hit(ray: ray, time: time)
    }
}

public struct Transformed<Base: HittableVolume>: HittableVolume {
    var transform: Transform3D
    var base: Base

    public init(transform: Transform3D, base: Base) {
        self.transform = transform
        self.base = base
    }

    public var center: Point3D {
        return boundingBox.center
    }

    public var boundingBox: AABB {
        let box = base.boundingBox
        if transform.rotation.isIdentity {
            return box.translate(by: transform.translation)
        } else {
            var result = AABB()
            box.enumerateCorners { p in
                let box = transform.transform(p)
                result.add(box)
            }
            return result
        }
    }

    public func hits(ray: Ray3D, time: Double) -> [HitRange] {
        let offsetRay = transform.inverse.transform(ray)
        var hits = base.hits(ray: offsetRay, time: time)
        for i in hits.indices {
            hits[i].apply(transform: transform)
        }
        return hits
    }

    public func hit(ray: Ray3D, time: Double, range: Range<Double>) -> HitRecord? {
        let offsetRay = transform.inverse.transform(ray)
        guard var h = base.hit(ray: offsetRay, time: time, range: range) else { return nil }
        h.apply(transform: transform)
        return h
    }
}

extension Transformed: HittableConvexVolume where Base: HittableConvexVolume {
    public func hit(ray: Ray3D, time: Double) -> HitRange? {
        let offsetRay = transform.inverse.transform(ray)
        guard var h = base.hit(ray: offsetRay, time: time) else { return nil }
        h.apply(transform: transform)
        return h
    }
}

public class BoundingVolumeNode: Hittable {
    public private(set) var boundingBox: AABB
    private var leftChild: any Hittable
    private var rightChild: any Hittable

    public init(items: [any Hittable]) {
        assert(items.count >= 2)
        boundingBox = AABB()
        for item in items {
            boundingBox.add(item.boundingBox)
        }
        let longestAxis = boundingBox.longestAxis
        var itemsCopy = consume items
        itemsCopy.sort { a, b in
            a.center[longestAxis] < b.center[longestAxis]
        }
        let mid = (itemsCopy.count + 1) / 2
        if mid == 1 {
            leftChild = itemsCopy[0]
        } else {
            leftChild = BoundingVolumeNode(items: Array(itemsCopy[0..<mid]))
        }
        if mid + 1 == itemsCopy.count {
            rightChild = itemsCopy[mid]
        } else {
            rightChild = BoundingVolumeNode(items: Array(itemsCopy[mid...]))
        }
    }

    public var center: Point3D {
        boundingBox.center
    }

    public func hit(ray: Ray3D, time: Double, range: Range<Double>) -> HitRecord? {
        if boundingBox.hit(ray: ray) == nil {
            return nil
        }

        let leftHit = leftChild.hit(ray: ray, time: time, range: range)
        let rightHit = rightChild.hit(ray: ray, time: time, range: range.lowerBound..<(leftHit?.t ?? range.upperBound))
        return rightHit ?? leftHit
    }
}


extension Array: Hittable where Element == any Hittable {
    public var center: Point3D {
        return boundingBox.center
    }
    
    public var boundingBox: AABB {
        var result = AABB()
        for item in self {
            result.add(item.boundingBox)
        }
        return result
    }
    
    public func hit(ray: Ray3D, time: Double, range: Range<Double>) -> HitRecord? {
        var result: HitRecord?
        for item in self {
            let itemRange = range.lowerBound..<(result?.t ?? range.upperBound)
            if let hit = item.hit(ray: ray, time: time, range: itemRange) {
                result = hit
            }
        }
        return result
    }
}
