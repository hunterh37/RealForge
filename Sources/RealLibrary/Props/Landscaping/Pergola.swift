import simd
import Foundation

/// Freestanding cedar pergola, 3.0 x 3.0 m footprint, 2.75 m tall: four 6x6 posts on steel post bases
/// and concrete footings, doubled 2x10 beams through-bolted to the posts, 2x8 rafters with
/// cut-and-curved tails, 2x2 purlins on top, 45-degree knee braces.
public struct Pergola: RealAsset {
    public static let id = "pergola"
    public static let summary = "Freestanding cedar pergola, 3 x 3 m, 2.75 m tall: 6x6 posts on steel bases, doubled 2x10 beams, 2x8 rafters with curved tails, 2x2 purlins, knee braces."
    public static let tags = ["prop", "garden", "outdoor", "landscaping", "wood", "furniture"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 14, distance: 1.1, studio: true)

    /// Post-to-post span along X (m).
    public var spanX: Float = 2.7
    /// Post-to-post span along Z (m).
    public var spanZ: Float = 2.7
    /// Post height to the beam tops (m).
    public var postHeight: Float = 2.45
    /// Rafter count.
    public var rafters: Int = 9
    /// Purlin count.
    public var purlins: Int = 11
    /// Lumber material.
    public var wood: MaterialKey = "wood.cedar"
    /// Sun-bleached lumber for the exposed purlins.
    public var weathered: MaterialKey = "wood.cedar-weathered"
    /// Hardware material.
    public var hardware: MaterialKey = "metal.galvanized"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id), lite = Model(name: Self.id + "-lite")
        let px = spanX / 2, pz = spanZ / 2, ph = postHeight
        let post: Float = 0.14
        func lumber(from a: V3, to b: V3, w: Float, t: Float, up: V3) -> (Surface, Xform) {
            let x = board(from: a, to: b, width: w, thick: t, up: up, bevel: 0.005, material: wood).1
            return (Prim.roundedBox(V3(simd_distance(a, b), t, w), radius: 0.005, bevelSegments: 1, material: wood), x)
        }
        func both(_ s: Surface, _ x: Xform, liteToo: Bool = true) { m.add(s, x); if liteToo { lite.add(s, x) } }
        // Footings, post bases, posts.
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
            let c = V3(sx * px, 0, sz * pz)
            both(Prim.roundedBox(V3(0.3, 0.04, 0.3), radius: 0.008, bevelSegments: 1, material: "concrete.rough"), Xform(translation: c + V3(0, 0.02, 0)))
            m.add(Prim.roundedBox(V3(0.15, 0.006, 0.15), radius: 0.002, bevelSegments: 1, material: hardware), Xform(translation: c + V3(0, 0.043, 0)))
            for side: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(0.003, 0.16, 0.12), radius: 0.001, bevelSegments: 1, material: hardware), Xform(translation: c + V3(side * (post / 2 + 0.0025), 0.126, 0)))
                for dy: Float in [0.13] { hexBolt(&m, at: c + V3(side * (post / 2 + 0.004), dy, 0), normal: V3(side, 0, 0), size: 0.016, material: hardware) }
            }
            var r = rng.fork(Int(sx * 2 + sz + 3))
            let pb = lumber(from: c + V3(0, 0.046, 0), to: c + V3(0, ph - 0.01, 0), w: post, t: post, up: V3(1, 0, 0))
            both(pb.0, pb.1.jittered(&r, deg: 0.25, offset: 0.002))
        }}
        // Doubled beams along X on both sides of the posts at each Z line, with tails cut at an angle.
        let beamH: Float = 0.235, beamT: Float = 0.038, over: Float = 0.38
        func tailBoard(length: Float, height: Float, thick: Float, cut: Float, material: MaterialKey) -> Surface {
            // Side profile in XY with ogee-ish curved tails at both ends; extruded along Z (thickness).
            let L = length / 2, h2 = height / 2
            var pts: [V2] = []
            for k in 0...4 { let t = Float(k) / 4; pts.append(V2(L - cut + cut * sin(t * .pi / 2), -h2 + height * 0.6 * (1 - cos(t * .pi / 2)))) }
            pts.append(V2(L, h2)); pts.append(V2(-L, h2))
            for k in 0...4 { let t = 1 - Float(k) / 4; pts.append(V2(-(L - cut + cut * sin(t * .pi / 2)), -h2 + height * 0.6 * (1 - cos(t * .pi / 2)))) }
            let clean = Shape2D.deduped(pts)
            return Prim.extrude(Shape2D.rounded(clean, radius: 0.004, segments: 1), depth: thick, bevel: 0.003, bevelSegments: 1, material: material)
        }
        for sz: Float in [-1, 1] { for side: Float in [-1, 1] {
            let z = sz * pz + side * (post / 2 + beamT / 2 + 0.002)
            let b = tailBoard(length: spanX + post + over * 2, height: beamH, thick: beamT, cut: 0.26, material: wood)
            both(b, Xform(translation: V3(0, ph - beamH / 2, z)))
            for sx: Float in [-1, 1] { for dy: Float in [side > 0 ? -0.055 : 0.055] {
                hexBolt(&m, at: V3(sx * px, ph - beamH / 2 + dy, sz * pz + side * (post / 2 + beamT + 0.004)), normal: V3(0, 0, side), size: 0.02, material: hardware)
            }}
        }}
        // Rafters along Z on top of the beams, notched (sitting 0.03 lower), curved tails.
        let rafH: Float = 0.184, rafT: Float = 0.038
        let nr = max(3, rafters)
        for i in 0..<nr {
            var r = rng.fork(100 + i)
            let x = -spanX / 2 - post / 2 + (spanX + post) * Float(i) / Float(nr - 1)
            let s = tailBoard(length: spanZ + post + over * 2 + 0.12, height: rafH, thick: rafT, cut: 0.22, material: wood)
            let xf = Xform(translation: V3(x, ph + rafH / 2 - 0.03, 0), rotation: simd_quatf(degrees: 90, axis: .up)).jittered(&r, deg: 0.2, offset: 0.002)
            both(s, xf)
        }
        // Purlins along X on top of the rafters.
        let pu: Float = 0.038, np = max(2, purlins)
        for i in 0..<np {
            var r = rng.fork(300 + i)
            let z = -spanZ / 2 - 0.2 + (spanZ + 0.4) * Float(i) / Float(np - 1)
            let s = Prim.roundedBox(V3(spanX + post + 0.5, pu, pu), radius: 0.003, bevelSegments: 1, material: weathered)
            both(s, Xform(translation: V3(0, ph + rafH - 0.03 + pu / 2 + 0.001, z)).jittered(&r, deg: 0.2, offset: 0.0015), liteToo: i % 2 == 0)
        }
        // Knee braces from posts to beams, both directions.
        let br: Float = 0.5
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
            let c = V3(sx * px, 0, sz * pz)
            let inX = V3(-sx, 0, 0), inZ = V3(0, 0, -sz)
            for (dir, up) in [(inX, V3(0, 0, 1)), (inZ, V3(1, 0, 0))] {
                let a = c + dir * (post / 2) + V3(0, ph - beamH - br * 0.7, 0)
                let b = c + dir * (post / 2 + br * 0.7) + V3(0, ph - beamH - 0.005, 0)
                let bd = lumber(from: a, to: b, w: 0.089, t: 0.089, up: up)
                m.add(bd.0, bd.1)
            }
        }}
        let bb = m.bounds
        let shift = V3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2)
        m = m.transformed(Xform(translation: shift)); lite = lite.transformed(Xform(translation: shift))
        groundAO(&m, height: 0.4, floor: 0.6); groundAO(&lite, height: 0.4, floor: 0.6)
        return LODModel(levels: [m, lite], switchDistances: [14])
    }
}
