import simd
import Foundation

/// Wrought-iron balcony, 1.9 x 0.7 m: 120 mm brownstone slab with a molded edge on two scrolled iron
/// brackets, railing on three sides (flat top rail, bottom rail, square balusters, a band of C-scrolls,
/// corner posts with ball finials, wall returns). Wall plane at z = -depth/2, balcony projects +Z;
/// base y = 0 is the underside of the brackets, the slab top sits at `bracketDrop + slab`.
public struct WroughtIronBalcony: RealAsset {
    public static let id = "wrought-iron-balcony"
    public static let summary = "Wrought-iron balcony, 1.9 m: stone slab on brackets, iron railing with scroll balusters, top rail and corner posts."
    public static let tags = ["structure", "architecture", "facade", "metal", "stone"]
    public static let budget = 22_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 14, distance: 1.0, studio: true)

    /// Slab length along the wall (m).
    public var width: Float = 1.9
    /// Projection from the wall (m).
    public var depth: Float = 0.7
    /// Railing height above the slab (m).
    public var railHeight: Float = 0.95
    /// Bracket height below the slab (m).
    public var bracketDrop: Float = 0.32
    public var balusterSpacing: Float = 0.12
    public var slabMaterial: MaterialKey = "stone.brownstone"
    public var ironMaterial: MaterialKey = "metal.wrought-iron"
    public var rustMaterial: MaterialKey = "metal.rust"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id), lite = Model(name: Self.id + "-lite")
        let W = width, P = depth, zw = -P / 2
        let slabT: Float = 0.12, y0 = bracketDrop, yTop = y0 + slabT
        let iron = ironMaterial

        func both(_ s: Surface) { m.add(s); lite.add(s) }
        // Slab with molded edge: main slab, projecting nosing, cove below.
        both(HK.box(V3(W, slabT * 0.6, P), V3(0, y0 + slabT * 0.7, 0), slabMaterial, r: 0.015))
        both(HK.box(V3(W - 0.04, slabT * 0.45, P - 0.02), V3(0, y0 + slabT * 0.225, -0.01), slabMaterial, r: 0.02))
        both(HK.box(V3(W + 0.02, 0.025, P + 0.01), V3(0, yTop - 0.03, 0.005), slabMaterial, r: 0.011))

        // Brackets: plate on the wall, curved strap from wall foot to slab front, inner scroll.
        for bx in [-W / 2 + 0.25, W / 2 - 0.25] {
            both(HK.box(V3(0.06, y0 + 0.02, 0.012), V3(bx, (y0 + 0.02) / 2, zw + 0.006), iron, r: 0.004))
            let curve = (0...14).map { i -> V3 in
                let t = Float(i) / 14
                return V3(bx, t * t * y0 * 0.95 + 0.01 + (1 - t) * 0.0, zw + 0.01 + t * (P * 0.7))
            }
            both(Prim.sweep(Shape2D.roundedRect(0.016, 0.03, radius: 0.004), along: curve, up: V3(1, 0, 0), material: iron))
            both(HK.box(V3(0.03, 0.016, P * 0.72), V3(bx, y0 - 0.008, zw + P * 0.36), iron, r: 0.004))
            let scroll = (0...20).map { i -> V3 in
                let t = Float(i) / 20 * 1.6 * .pi
                let r = 0.09 * (1 - Float(i) / 26)
                return V3(bx, y0 * 0.62 + sin(t) * r, zw + 0.16 + cos(t) * r)
            }
            m.add(HK.pipe(scroll, r: 0.006, sides: 6, mat: iron))
        }

        // Railing around three sides.
        let inset: Float = 0.05, rx = W / 2 - inset, rzF = P / 2 - inset
        let ryB = yTop + 0.06, ryT = yTop + railHeight
        // Edges: (start, end) front and both sides.
        let edges: [(V3, V3)] = [(V3(-rx, 0, rzF), V3(rx, 0, rzF)), (V3(-rx, 0, zw + 0.01), V3(-rx, 0, rzF)), (V3(rx, 0, zw + 0.01), V3(rx, 0, rzF))]
        for (a, b) in edges {
            let dir = simd_normalize(b - a), len = simd_length(b - a)
            let c = (a + b) / 2
            let rot = simd_quatf(from: V3(1, 0, 0), to: dir)
            // Flat top rail with a rounded handrail cap, bottom rail, second rail for the scroll band.
            both(HK.box(V3(len + 0.03, 0.035, 0.05), V3(c.x, ryT, c.z), iron, r: 0.012, rot: rot))
            both(HK.box(V3(len, 0.014, 0.025), V3(c.x, ryB, c.z), iron, r: 0.004, rot: rot))
            both(HK.box(V3(len, 0.012, 0.022), V3(c.x, ryB + 0.14, c.z), iron, r: 0.004, rot: rot))
            let n = max(2, Int((len / balusterSpacing).rounded()))
            for i in 1..<n {
                let p = a + dir * (len * Float(i) / Float(n))
                let s = HK.box(V3(0.014, ryT - ryB, 0.014), V3(p.x, (ryB + ryT) / 2, p.z), iron, r: 0.003, seg: 1, rot: rot)
                m.add(s); lite.add(s)
                // Collar on each baluster under the top rail.
                m.add(HK.box(V3(0.024, 0.02, 0.024), V3(p.x, ryT - 0.06, p.z), iron, r: 0.004, seg: 1, rot: rot))
                // C-scroll pair between balusters in the bottom band.
                let mid = a + dir * (len * (Float(i) - 0.5) / Float(n))
                let r: Float = 0.032
                for side: Float in [1, -1] {
                    let arc = (0...8).map { k -> V3 in
                        let t = Float(k) / 8 * .pi
                        let local = dir * (side * cos(t) * r) + V3(0, side * sin(t) * r, 0)
                        return V3(mid.x, ryB + 0.07 + side * 0.006, mid.z) + local
                    }
                    m.add(HK.pipe(arc, r: 0.005, sides: 6, mat: iron))
                }
            }
        }
        // Corner posts with ball finials; rust bleeding at the front corners where water sits.
        for sx: Float in [-1, 1] {
            for z in [rzF, zw + 0.02] {
                let front = z == rzF
                both(HK.box(V3(0.03, ryT - yTop + 0.02, 0.03), V3(sx * rx, yTop + (ryT - yTop) / 2, z), iron, r: 0.005))
                m.add(Prim.lathe([V2(0, 0), V2(0.02, 0), V2(0.024, 0.01), V2(0.012, 0.02), V2(0.01, 0.03), V2(0.026, 0.05), V2(0.02, 0.07), V2(0, 0.078)],
                                 segments: 16, seamTile: 0.05, material: iron).transformed(Xform(translation: V3(sx * rx, ryT + 0.015, z))))
                if front {
                    m.add(HK.box(V3(0.034, 0.06, 0.034), V3(sx * rx, yTop + 0.03, z), rustMaterial, r: 0.006).transformed(Xform.identity.jittered(&rng, deg: 0, offset: 0.0003)))
                }
            }
        }
        // Rust streak on the slab nosing under the front rail.
        m.add(HK.box(V3(0.08, 0.06, 0.004), V3(0.42, y0 + 0.05, P / 2 + 0.006), "metal.rust", r: 0.0015, seg: 1))

        groundAO(&m, height: 0.2, floor: 0.7)
        groundAO(&lite, height: 0.2, floor: 0.7)
        return LODModel(levels: [m, lite], switchDistances: [8])
    }
}
