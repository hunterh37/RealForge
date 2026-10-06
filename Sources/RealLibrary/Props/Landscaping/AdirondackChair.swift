import simd
import Foundation

/// Classic Adirondack chair, 0.97 m tall, 0.76 m wide, 0.88 m deep: two sloped side stringers on short
/// back legs, upright front legs, seven seat slats falling toward the back, a fan of five back slats with
/// rounded tops on two curved cross supports, wide flat armrests on angled brackets, stainless screws.
/// Painted cedar, paint worn through on the arm fronts.
public struct AdirondackChair: RealAsset {
    public static let id = "adirondack-chair"
    public static let summary = "Cedar Adirondack chair, 0.97 m: slanted slat seat, fan back of five rounded slats, wide flat armrests on front legs."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "furniture", "wood"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)

    /// Paint color (sRGB hex).
    public var paint: UInt32 = 0xE8E2D2
    /// Back slat count.
    public var backSlats: Int = 5
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let wood = String(format: "wood.barn-white:%06X", paint)
        let W: Float = 0.76, t: Float = 0.019
        // Chair faces +Z. Stringers: from front (z 0.42, y 0.36) down to back (z -0.44, y 0.02).
        let front = V3(0, 0.37, 0.43), back = V3(0, 0.03, -0.44)
        let sx = W / 2 - 0.12
        for s: Float in [-1, 1] {
            let (b, x) = board(from: V3(s * sx, front.y, front.z), to: V3(s * sx, back.y, back.z), width: t, thick: 0.09, up: V3(0, 1, 0.4), material: wood)
            m.add(b, x.jittered(&rng, deg: 0.2))
            // Front leg: upright 2x4.
            let (l, lx) = board(from: V3(s * (sx + 0.03), 0, 0.35), to: V3(s * (sx + 0.03), 0.6, 0.35), width: 0.019, thick: 0.085, up: V3(0, 0, 1), material: wood)
            m.add(l, lx.jittered(&rng, deg: 0.2))
        }
        // Seat slats across X following the stringer slope.
        let seatN = 7
        for i in 0..<seatN {
            let f = (Float(i) + 0.5) / Float(seatN) * 0.62
            let z = front.z - 0.02 - f * (front.z - back.z) * 0.95
            let y = front.y + 0.045 + (z - front.z) * (front.y - back.y) / (front.z - back.z) * 1.0 + 0.0
            let slat = plank(2 * sx + 0.06, 0.06, t, bevel: 0.004, material: wood)
            m.add(slat, Xform(translation: V3(0, y + 0.0, z), rotation: simd_quatf(degrees: -21, axis: V3(1, 0, 0))).jittered(&rng, deg: 0.3))
        }
        // Back: fan of slats from a low back rail (y 0.3, z -0.2) leaning back to y 0.97.
        let lean: Float = 24
        let bottom = V3(0, 0.22, -0.24)
        let up = simd_quatf(degrees: -lean, axis: V3(1, 0, 0)).act(V3(0, 1, 0))
        let n = backSlats
        for i in 0..<n {
            let u = (Float(i) - Float(n - 1) / 2) / Float(n - 1)
            let splay = u * 0.12
            let len: Float = 0.82 - abs(u) * 0.14
            let w: Float = 0.085
            let dir = simd_normalize(up + V3(splay, 0, 0))
            let base = bottom + V3(u * 0.32, 0, 0)
            var slat = Prim.extrude(Shape2D.rounded([V2(-w / 2, 0), V2(w / 2, 0), V2(w / 2, len - w / 2), V2(0, len), V2(-w / 2, len - w / 2)], radius: 0.03),
                                    depth: t, bevel: 0.003, material: wood)
            slat.deform { $0 }
            let rot = simd_quatf(from: V3(0, 1, 0), to: dir)
            m.add(slat, Xform(translation: base, rotation: rot).jittered(&rng, deg: 0.3))
        }
        // Cross supports behind the back slats (curved, lower and upper).
        for (h, r) in [(Float(0.2), Float(0.17)), (Float(0.52), Float(0.22))] {
            let c = bottom + up * h - simd_normalize(simd_cross(V3(1, 0, 0), up)) * 0.022
            var pts: [V3] = []
            for k in 0...8 { let a = (Float(k) / 8 - 0.5) * 2; pts.append(c + V3(a * r, 0, -0.03 * a * a)) }
            m.add(Prim.sweep(Shape2D.roundedRect(0.05, t, radius: 0.004), along: pts, up: up, grainAlongPath: true, material: wood))
        }
        // Back legs tie the stringers to the lower back support.
        for s: Float in [-1, 1] {
            let (b, x) = board(from: V3(s * (sx - 0.02), 0, -0.24), to: V3(s * (sx - 0.02), 0.26, -0.26), width: 0.04, thick: 0.065, up: V3(0, 0, 1), material: wood)
            m.add(b, x.jittered(&rng, deg: 0.2))
        }
        // Armrests: wide flat boards from front leg back to the upper support, with angled brackets.
        let armY: Float = 0.6 + t / 2
        for s: Float in [-1, 1] {
            let outline = [V2(-0.36, -0.075), V2(0.16, -0.075), V2(0.16, 0.06), V2(-0.36, 0.035)]
            let arm = Prim.extrude(Shape2D.rounded(outline, radius: 0.04), depth: t, bevel: 0.005, material: wood)
            let x = Xform(translation: V3(s * (sx + 0.05), armY, 0.25), rotation: simd_quatf(degrees: -90, axis: .up) * simd_quatf(degrees: -90, axis: V3(1, 0, 0)))
            m.add(arm, x)
            let br = Prim.extrude(Shape2D.rounded([V2(0, 0), V2(0.1, 0), V2(0, -0.12)], radius: 0.01), depth: 0.019, bevel: 0.003, material: wood)
            m.add(br, Xform(translation: V3(s * (sx + 0.03), armY - t / 2, 0.39), rotation: simd_quatf(degrees: -90, axis: .up)))
            // Screw heads on arm top.
            for z: Float in [0.35, 0.3] {
                m.add(Prim.cylinder(radius: 0.005, height: 0.0015, bevel: 0.0005, segments: 8, material: "metal.stainless"),
                      Xform(translation: V3(s * (sx + 0.03), armY + t / 2, z)))
            }
        }
        // Recenter on X/Z, base at 0.
        let b = m.bounds
        let shift = V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)
        for i in m.surfaces.indices { m.surfaces[i].positions = m.surfaces[i].positions.map { $0 + shift } }
        groundAO(&m, height: 0.2)
        return LODModel(m)
    }
}
