import simd
import Foundation

/// Builder's sawhorse, 1.0 m beam at 0.75 m: 2 x 4 (38 x 89 mm) top rail on edge, four splayed 2 x 4 legs
/// held in stamped galvanized brackets, 1 x 4 spreaders at each end.
public struct Sawhorse: RealAsset {
    public static let id = "sawhorse"
    public static let summary = "Builder's sawhorse: 2x4 pine beam on four splayed 2x4 legs, galvanized brackets, end spreaders."
    public static let tags = ["prop", "construction", "wood", "tool"]
    public static let budget = 4_800
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 14)

    /// Beam length in meters.
    public var length: Float = 1.0
    /// Height to the top of the beam.
    public var height: Float = 0.75
    /// Leg spread at the floor, front to back.
    public var spread: Float = 0.5
    public var wood: MaterialKey = "wood.pine"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let w: Float = 0.089, t: Float = 0.038
        let len = rng.vary(length, 0.04)
        // Top rail on edge.
        m.add(plank(len, w, t, bevel: 0.003, material: wood),
              Xform(translation: V3(0, height - w / 2, 0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))).jittered(&rng, deg: 0.3))
        let legTopY = height - 0.03
        for sx: Float in [-1, 1] {
            let xTop = sx * (len / 2 - 0.12), xFoot = sx * (len / 2 - 0.06)
            func legPoint(_ sz: Float, _ y: Float) -> V3 {
                let k = 1 - y / legTopY
                return V3(lerp(xTop, xFoot, k), y, sz * lerp(t / 2 + t / 2, spread / 2, k))
            }
            for sz: Float in [-1, 1] {
                let a = legPoint(sz, legTopY), b = legPoint(sz, 0.0)
                let (s, x) = board(from: a, to: b, width: w, thick: t, up: V3(0, 0, sz), bevel: 0.003, material: wood, extend: 0.0)
                // Square cut at the floor: extend a little and let the bottom sit at y ~ 0.
                m.add(s, x.jittered(&rng, deg: 0.8))
            }
            // Spreader across the legs on the outside face.
            let ys: Float = 0.26
            let pa = legPoint(-1, ys), pb = legPoint(1, ys)
            let (sp, spx) = board(from: pa - V3(0, 0, 0.025), to: pb + V3(0, 0, 0.025), width: w, thick: 0.019,
                                  up: V3(sx, 0, 0), bevel: 0.002, material: wood)
            var spt = spx; spt.translation += V3(sx * (0.019 / 2 + 0.03), 0, 0)
            m.add(sp, spt.jittered(&rng, deg: 0.5))
            // Stamped steel bracket: saddle over the rail plus a sleeve down each leg.
            let bx = sx * (len / 2 - 0.12)
            let saddle = Prim.roundedBox(V3(0.11, 0.004, t + 0.008), radius: 0.0015, bevelSegments: 1, material: "metal.galvanized")
            m.add(saddle, Xform(translation: V3(bx, height + 0.002, 0)))
            for sz: Float in [-1, 1] {
                let cheek = Prim.roundedBox(V3(0.11, 0.075, 0.003), radius: 0.001, bevelSegments: 1, material: "metal.galvanized")
                m.add(cheek, Xform(translation: V3(bx, height - 0.035, sz * (t / 2 + 0.0035))))
                let a = legPoint(sz, legTopY), b = legPoint(sz, legTopY - 0.13)
                let (sl, slx) = board(from: a, to: b, width: w + 0.008, thick: t + 0.008, up: V3(0, 0, sz), bevel: 0.002,
                                      material: "metal.galvanized")
                m.add(sl, slx)
            }
        }
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
