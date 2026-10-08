import simd
import Foundation

/// NYC fire-escape floor module, 3 m bay: slatted iron platform (flat bars on edge in an angle
/// frame) with a stair hatch, railing on three sides (top rail, mid rail, square pickets, posts),
/// diagonal wall brackets, and a steep stair (channel stringers, bar-grate treads, pipe handrail) that
/// rises one storey to the next module's hatch. Stack modules every `storey` meters: the stair top
/// lands in the hatch of the module above. Wall plane at z = -depth/2, the platform projects +Z; base
/// y = 0 is the foot of the brackets, the platform deck sits at `bracketDrop`.
public struct FireEscapeBay: RealAsset {
    public static let id = "fire-escape-bay"
    public static let summary = "NYC fire escape floor module, 3 m storey: slatted iron platform, railing, cantilever brackets and a stair to the next level, stackable."
    public static let tags = ["structure", "architecture", "facade", "metal", "urban"]
    public static let budget = 28_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 10, distance: 1.0, studio: true)

    /// Platform length along the wall (m).
    public var width: Float = 3.0
    /// Platform projection from the wall (m).
    public var depth: Float = 0.9
    /// Floor-to-floor height; the stair rises this much (m).
    public var storey: Float = 3.0
    /// Bracket height below the deck (m).
    public var bracketDrop: Float = 0.6
    /// Railing height above the deck (m).
    public var railHeight: Float = 0.95
    /// Include the stair up to the next module.
    public var stair = true
    public var ironMaterial: MaterialKey = "metal.wrought-iron"
    public var rustMaterial: MaterialKey = "metal.rust"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id), lite = Model(name: Self.id + "-lite")
        let W = width, P = depth, zw = -P / 2, y0 = bracketDrop
        let fe = ironMaterial
        func both(_ s: Surface) { m.add(s); lite.add(s) }

        // Platform frame: angles along the front and the wall, ends.
        both(HK.box(V3(W, 0.06, 0.008), V3(0, y0 - 0.03, P / 2 - 0.004), fe, r: 0.002))
        both(HK.box(V3(W, 0.008, 0.06), V3(0, y0 - 0.004, P / 2 - 0.03), fe, r: 0.002))
        both(HK.box(V3(W, 0.06, 0.06), V3(0, y0 - 0.03, zw + 0.03), fe, r: 0.003))
        for sx: Float in [-1, 1] { both(HK.box(V3(0.06, 0.06, P), V3(sx * (W / 2 - 0.03), y0 - 0.03, 0), fe, r: 0.003)) }
        // Deck: flat bars on edge along X, 38 mm pitch, gap over the hatch.
        let hatchX0: Float = 0.25, hatchX1 = W / 2 - 0.12, hatchZ1 = zw + 0.66
        var z = zw + 0.08
        while z < P / 2 - 0.05 {
            if stair && z < hatchZ1 {
                for (a, b) in [(-W / 2 + 0.06, hatchX0), (hatchX1, W / 2 - 0.06)] where b - a > 0.02 {
                    let s = HK.box(V3(b - a, 0.035, 0.008), V3((a + b) / 2, y0 - 0.0175, z), fe, r: 0.002, seg: 1)
                    m.add(s)
                }
            } else {
                m.add(HK.box(V3(W - 0.12, 0.035, 0.008), V3(0, y0 - 0.0175, z), fe, r: 0.002, seg: 1))
            }
            z += 0.038
        }
        lite.add(HK.box(V3(W - 0.12, 0.02, P - 0.12), V3(0, y0 - 0.02, 0), fe, r: 0.002, seg: 1))
        if stair {
            // Hatch trim angle.
            both(HK.box(V3(0.04, 0.05, hatchZ1 - zw - 0.06), V3(hatchX0 - 0.02, y0 - 0.025, (zw + 0.06 + hatchZ1) / 2), fe, r: 0.003))
            both(HK.box(V3(hatchX1 - hatchX0, 0.05, 0.04), V3((hatchX0 + hatchX1) / 2, y0 - 0.025, hatchZ1), fe, r: 0.003))
        }

        // Brackets: horizontal arm under the deck plus a diagonal strut to a wall plate at y = 0.
        let nb = max(2, Int((W / 1.4).rounded()) + 1)
        for i in 0..<nb {
            let x = -W / 2 + 0.15 + (W - 0.3) * Float(i) / Float(nb - 1)
            both(HK.box(V3(0.05, 0.05, P - 0.04), V3(x, y0 - 0.085, 0), fe, r: 0.004))
            let (s, xf) = board(from: V3(x, 0.04, zw + 0.03), to: V3(x, y0 - 0.1, P / 2 - 0.1), width: 0.05, thick: 0.03, up: V3(1, 0, 0), bevel: 0.004, material: fe)
            both(s.transformed(xf))
            both(HK.box(V3(0.12, 0.2, 0.014), V3(x, 0.1, zw + 0.007), fe, r: 0.004))
            both(HK.box(V3(0.12, 0.14, 0.014), V3(x, y0 - 0.1, zw + 0.007), fe, r: 0.004))
            for by: Float in [0.05, 0.15] { m.add(HK.cyl(r: 0.012, len: 0.012, at: V3(x, by, zw + 0.02), axis: V3(0, 0, 1), mat: fe, seg: 8)) }
            // Rust weeping from the strut foot.
            m.add(HK.box(V3(0.06, 0.12, 0.003), V3(x + 0.01, 0.0 + 0.07, zw + 0.016), rustMaterial, r: 0.001, seg: 1).transformed(Xform.identity.jittered(&rng, deg: 0, offset: 0.0003)))
        }

        // Railing: front and both ends.
        let ry = y0 + railHeight
        let edges: [(V3, V3)] = [(V3(-W / 2 + 0.02, 0, P / 2 - 0.02), V3(W / 2 - 0.02, 0, P / 2 - 0.02)),
                                 (V3(-W / 2 + 0.02, 0, zw + 0.02), V3(-W / 2 + 0.02, 0, P / 2 - 0.02)),
                                 (V3(W / 2 - 0.02, 0, zw + 0.02), V3(W / 2 - 0.02, 0, P / 2 - 0.02))]
        for (a, b) in edges {
            let dir = simd_normalize(b - a), len = simd_length(b - a), c = (a + b) / 2
            let rot = simd_quatf(from: V3(1, 0, 0), to: dir)
            both(HK.box(V3(len + 0.03, 0.04, 0.04), V3(c.x, ry, c.z), fe, r: 0.006, rot: rot))
            both(HK.box(V3(len, 0.012, 0.03), V3(c.x, y0 + 0.45, c.z), fe, r: 0.003, rot: rot))
            both(HK.box(V3(len, 0.012, 0.03), V3(c.x, y0 + 0.08, c.z), fe, r: 0.003, rot: rot))
            let n = max(2, Int((len / 0.11).rounded()))
            for i in 1..<n {
                let p = a + dir * (len * Float(i) / Float(n))
                m.add(HK.box(V3(0.016, railHeight - 0.08, 0.016), V3(p.x, y0 + 0.04 + (railHeight - 0.08) / 2, p.z), fe, r: 0.003, seg: 1, rot: rot))
            }
            lite.add(HK.box(V3(len, railHeight - 0.1, 0.006), V3(c.x, y0 + railHeight / 2, c.z), "fence.chainlink", r: 0.002, seg: 1, rot: rot))
        }
        for p in [V3(-W / 2 + 0.02, 0, P / 2 - 0.02), V3(W / 2 - 0.02, 0, P / 2 - 0.02), V3(-W / 2 + 0.02, 0, zw + 0.02), V3(W / 2 - 0.02, 0, zw + 0.02)] {
            both(HK.box(V3(0.045, railHeight + 0.02, 0.045), V3(p.x, y0 + railHeight / 2, p.z), fe, r: 0.006))
        }

        // Stair: from the deck at the left end up to the next module's hatch.
        if stair {
            let sx0 = -W / 2 + 0.25, sx1 = hatchX1 - 0.05
            let za = zw + 0.08, zb = zw + 0.6
            let run = sx1 - sx0, rise = storey
            for zz in [za, zb] {
                let (s, xf) = board(from: V3(sx0, y0, zz), to: V3(sx1, y0 + rise, zz), width: 0.16, thick: 0.012, up: V3(0, 0, 1), bevel: 0.003, material: fe)
                both(s.transformed(xf))
                let (f, fx) = board(from: V3(sx0, y0 + 0.07, zz + (zz == za ? 0.03 : -0.03)), to: V3(sx1, y0 + rise + 0.07, zz + (zz == za ? 0.03 : -0.03)),
                                    width: 0.012, thick: 0.06, up: V3(0, 0, 1), bevel: 0.002, material: fe)
                m.add(f.transformed(fx))
            }
            let steps = Int((rise / 0.21).rounded())
            for i in 1..<steps {
                let t = Float(i) / Float(steps)
                let x = sx0 + run * t, y = y0 + rise * t
                // Bar-grate tread: frame plus three bars.
                m.add(HK.box(V3(0.16, 0.025, zb - za - 0.02), V3(x - 0.02, y - 0.05, (za + zb) / 2), fe, r: 0.003, seg: 1))
                for k in 0..<3 { m.add(HK.box(V3(0.008, 0.02, zb - za - 0.03), V3(x - 0.08 + Float(k) * 0.06, y - 0.04, (za + zb) / 2), fe, r: 0.002, seg: 1)) }
                lite.add(HK.box(V3(0.16, 0.025, zb - za - 0.02), V3(x - 0.02, y - 0.05, (za + zb) / 2), fe, r: 0.003, seg: 1))
            }
            // Pipe handrail on the open side with two posts.
            let hz = zb + 0.02
            both(HK.pipe([V3(sx0 + 0.05, y0 + 0.9, hz), V3(sx1 - 0.05, y0 + rise + 0.9, hz)], r: 0.018, sides: 10, mat: fe))
            for t: Float in [0.08, 0.92] {
                let x = sx0 + run * t, y = y0 + rise * t
                m.add(HK.pipe([V3(x, y, hz), V3(x, y + 0.9 + 0.02, hz)], r: 0.014, sides: 8, mat: fe))
            }
        }

        groundAO(&m, height: 0.2, floor: 0.75)
        groundAO(&lite, height: 0.2, floor: 0.75)
        return LODModel(levels: [m, lite], switchDistances: [14])
    }
}
