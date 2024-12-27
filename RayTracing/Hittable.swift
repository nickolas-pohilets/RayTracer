//
//  Hittable.swift
//  RayTracing
//
//  Created by Mykola Pokhylets on 24/12/2024.
//

public enum Face {
    case front
    case back
}

public struct HitRecord {
    var point: Point3D
    var normal: Vector3D
    var t: Double
    var face: Face
    var material: any Material
}

public protocol Hittable {
    func hit(ray: Ray3D, range: Range<Double>) -> HitRecord?
}

public struct Sphere: Hittable {
    var center: Point3D
    var radius: Double
    var material: any Material

    public init(center: Point3D, radius: Double, material: any Material) {
        self.center = center
        self.radius = radius
        self.material = material
    }

    public func hit(ray: Ray3D, range: Range<Double>) -> HitRecord? {
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
        if D_4 < 0 { return nil }
        var t = (-b_2 - D_4.squareRoot()) / a
        if !range.contains(t) {
            t = (-b_2 + D_4.squareRoot()) / a
            if !range.contains(t) {
                return nil
            }
        }
        let point = ray[t]
        var normal = (point - center) / radius
        var face: Face = .front
        if normal • ray.direction > 0 {
            normal = -normal
            face = .back
        }
        return HitRecord(point: point, normal: normal, t: t, face: face, material: material)
    }
}

public struct Cylinder: Hittable {
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

    public func hit(ray: Ray3D, range: Range<Double>) -> HitRecord? {
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

        struct Hit {
            var t: Double
            var point: Point3D
            var normal: Vector3D
        }

        struct HitRange {
            var entry: Hit
            var exit: Hit

            init(_ a: Hit, _ b: Hit) {
                if a.t <= b.t {
                    self.entry = a
                    self.exit = b
                } else {
                    self.entry = b
                    self.exit = a
                }
            }
        }

        var hitRanges: [HitRange] = []
        do {
            // Coefficients for plane equations
            let bottomD = -(axis • bottomCenter)
            let topD = -(axis • topCenter)

            let denom = axis • ray.direction

            let db = ob • axis
            let dt = ot • axis
            let tb = db / denom
            let tt = dt / denom

            if tb.isFinite && tt.isFinite {
                let hitB = Hit(t: tb, point: ray[tb], normal: -axis)
                let hitT = Hit(t: tt, point: ray[tt], normal: axis)
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
                let hit1 = Hit(t: t1, point: p1, normal: n1)
                let hit2 = Hit(t: t2, point: p2, normal: n2)
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

        let hit: Hit
        if range.contains(intersection.entry.t) {
            hit = intersection.entry
        } else if range.contains(intersection.exit.t) {
            hit = intersection.exit
        } else {
            return nil
        }

        var normal = hit.normal
        var face: Face = .front
        if normal • ray.direction > 0 {
            normal = -normal
            face = .back
        }

        return HitRecord(point: hit.point, normal: normal, t: hit.t, face: face, material: material)
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
