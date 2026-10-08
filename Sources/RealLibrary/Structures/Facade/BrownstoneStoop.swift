import simd
import Foundation

/// Brooklyn brownstone stoop: seven 180 mm risers with bullnosed brownstone treads (worn hollow at
/// the centre), a 1.2 m landing at the parlour door, solid cheek walls with sloped coping, and
/// cast-iron railings on the cheeks (sloped top rail, balusters with collars, newel posts with urn
/// finials at the foot and turned posts at the landing). Wall plane at z = -depth/2, the stair runs
/// down toward +Z; base y = 0 is the sidewalk.
public struct BrownstoneStoop: RealAsset {
    public static let id = "brownstone-stoop"
    public static let summary = "Brownstone stoop: seven-riser stone stair to a landing, side cheek walls, cast-iron railings with newel posts and scrolls."
    public static let tags = ["structure", "architecture", "facade", "stone", "metal"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 34, elevation: 12, distance: 1.0, studio: true)

    /// Clear stair width between the cheek walls (m).
    public var width: Float = 1.5
    /// Number of risers.
    public var risers: Int = 7
    /// Riser height (m).
    public var rise: Float = 0.18
    /// Tread going (m).
    public var going: Float = 0.29
    /// Landing depth at the top (m).
    public var landing: Float = 1.2
    /// Railing height above the nosing line (m).
    public var railHeight: Float = 0.9
    public var stoneMaterial: MaterialKey = "stone.brownstone"
    public var ironMaterial: MaterialKey = "metal.wrought-iron"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id), lite = Model(name: Self.id + "-lite")
        let n = risers, R = rise, G = going
        let H = Float(n) * R, run = Float(n - 1) * G
        let cw: Float = 0.3, Wd = width
        let depth = landing + run
        let zw = -depth / 2 - 0.15
        let st = stoneMaterial, fe = ironMaterial
        func both(_ s: Surface, _ x: Xform = .identity) { m.add(s, x); lite.add(s, x) }

        // Landing slab and steps (each a block to the ground so the stair reads solid).
        both(HK.box(V3(Wd + 0.002, H, landing), V3(0, H / 2, zw + landing / 2), st, r: 0.01))
        both(HK.box(V3(Wd + 0.02, 0.05, 0.04), V3(0, H - 0.025, zw + landing + 0.015), st, r: 0.02))
        for i in 0..<(n - 1) {
            let top = Float(n - 1 - i) * R
            let z0 = zw + landing + Float(i) * G
            both(HK.box(V3(Wd, top, G + 0.004), V3(0, top / 2, z0 + G / 2), st, r: 0.008))
            // Bullnose nosing with a worn hollow in the middle third.
            let nose = Prim.cylinder(radius: 0.022, height: Wd - 0.01, bevel: 0.006, segments: 12, bevelSegments: 1, material: st)
            both(nose, Xform(translation: V3(-(Wd - 0.01) / 2, top - 0.022, z0 + G + 0.0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
            m.add(HK.box(V3(Wd * 0.33, 0.004, G * 0.6), V3(rng.float(-0.04...0.04), top + 0.0005, z0 + G * 0.55), "stone.brownstone:4A3024", r: 0.002, seg: 1))
        }
        // Cheek walls: side profile (z, y) stepped down with a sloped top, extruded across x.
        for sx: Float in [-1, 1] {
            let zEnd = zw + landing + run + 0.1
            let prof: [V2] = [V2(zw, 0), V2(zEnd, 0), V2(zEnd, 0.45), V2(zw + landing + 0.05, H + 0.15), V2(zw, H + 0.15)]
            let wall = Prim.extrude(prof, depth: cw, bevel: 0.01, bevelSegments: 1, material: st)
            both(wall, Xform(translation: V3(sx * (Wd / 2 + cw / 2), 0, 0), rotation: simd_quatf(degrees: -90, axis: .up)).jittered(&rng, deg: 0, offset: 0))
            // Coping ledge along the slope and plinth at the foot.
            let a = V3(sx * (Wd / 2 + cw / 2), H + 0.18, zw + landing + 0.05), b = V3(sx * (Wd / 2 + cw / 2), 0.48, zEnd)
            let (cs, cx) = board(from: a, to: b, width: cw + 0.05, thick: 0.06, up: V3(0, 1, 0), bevel: 0.015, material: st, extend: 0.03)
            both(cs, cx)
            both(HK.box(V3(cw + 0.05, 0.06, landing + 0.05), V3(sx * (Wd / 2 + cw / 2), H + 0.18, zw + landing / 2 + 0.03), st, r: 0.015))
            both(HK.box(V3(cw + 0.06, 0.5, 0.36), V3(sx * (Wd / 2 + cw / 2), 0.25, zEnd - 0.17), st, r: 0.015))

            // Railing on the cheek: sloped top rail, bottom rail, balusters, newel and landing posts.
            let rx = sx * (Wd / 2 + cw / 2)
            let foot = V3(rx, 0.5, zEnd - 0.17), head = V3(rx, H + 0.21, zw + landing + 0.05)
            let topA = foot + V3(0, railHeight + 0.15, 0), topB = head + V3(0, railHeight, 0)
            both(HK.pipe([topA, topB, V3(rx, topB.y, zw + 0.05)], r: 0.022, sides: 10, mat: fe))
            m.add(HK.pipe([foot + V3(0, 0.12, 0), head + V3(0, 0.08, 0), V3(rx, head.y + 0.08, zw + 0.05)], r: 0.01, sides: 8, mat: fe))
            let nb = 16
            for k in 1..<nb {
                let t = Float(k) / Float(nb)
                let p0 = foot + (head - foot) * t
                let p1 = topA + (topB - topA) * t
                m.add(HK.pipe([p0 + V3(0, 0.12, 0), p1], r: 0.009, sides: 8, mat: fe))
                m.add(HK.cyl(r: 0.016, len: 0.04, at: p0 + (p1 - p0) * 0.5, axis: .up, mat: fe, seg: 10))
                lite.add(HK.pipe([p0 + V3(0, 0.12, 0), p1], r: 0.009, sides: 4, mat: fe))
            }
            for k in 1...4 {
                let z = head.z - landing * Float(k) / 5
                m.add(HK.pipe([V3(rx, head.y + 0.08, z), V3(rx, topB.y, z)], r: 0.009, sides: 8, mat: fe))
            }
            // Newel post with urn finial at the foot.
            let newel = Prim.lathe([V2(0, 0), V2(0.06, 0), V2(0.06, 0.06), V2(0.035, 0.1), V2(0.03, 0.75), V2(0.05, 0.8), V2(0.05, 0.85),
                                    V2(0.03, 0.9), V2(0.065, 1.0), V2(0.06, 1.08), V2(0.02, 1.12), V2(0.025, 1.17), V2(0, 1.2)],
                                   segments: 16, seamTile: 0.1, material: fe)
            both(newel, Xform(translation: foot))
            both(Prim.lathe([V2(0, 0), V2(0.035, 0), V2(0.025, 0.05), V2(0.022, railHeight), V2(0.04, railHeight + 0.04), V2(0, railHeight + 0.08)],
                            segments: 12, seamTile: 0.1, material: fe), Xform(translation: head))
            // Scroll at the newel.
            let scroll = (0...16).map { i -> V3 in let t = Float(i) / 16 * 1.7 * .pi; let r = 0.1 * (1 - Float(i) / 22); return foot + V3(0, 0.45 + sin(t) * r, -0.15 + cos(t) * r) }
            m.add(HK.pipe(scroll, r: 0.008, sides: 6, mat: fe))
        }
        groundAO(&m, height: 0.2, floor: 0.7)
        groundAO(&lite, height: 0.2, floor: 0.7)
        let b = m.bounds
        let c = Xform(translation: V3(0, 0, -(b.min.z + b.max.z) / 2))
        return LODModel(levels: [m.transformed(c), lite.transformed(c)], switchDistances: [12])
    }
}
