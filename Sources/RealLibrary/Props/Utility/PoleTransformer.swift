import simd
import Foundation

/// 25 kVA single-phase conventional pole-mount distribution transformer, 7200 V to 120/240 V (12.47 kV
/// wye feeder), standing free: an ANSI 70 gray welded round tank on a dished bottom, domed cover held by
/// a bolted clamp band, one porcelain primary bushing on the cover with an eyebolt connector, three
/// secondary bushings (X1, X2, X3) with spade terminals on the front wall, upper and lower hanger lugs
/// on the back, two lifting lugs, a kVA stencil, nameplate, ground pad and rain streaks from the band.
public struct PoleTransformer: RealAsset {
    public static let id = "pole-transformer"
    public static let summary = "25 kVA single-phase pole-mount transformer: ANSI 70 gray tank, clamped cover, primary bushing, three secondary bushings, hangers."
    public static let tags = ["prop", "utility", "electrical", "metal"]
    public static let budget = 12000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 12, distance: 1.0)

    /// Tank radius (m).
    public var tankRadius: Float = 0.225
    /// Tank wall height (m).
    public var tankHeight: Float = 0.7
    public var paint: MaterialKey = "metal.transformer-gray"
    public var porcelain: MaterialKey = "ceramic.porcelain-gray"
    public var hardware: MaterialKey = "metal.galvanized"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = tankRadius, H = tankHeight, b: Float = 0.03
        // Tank: dished bottom on a short skirt, straight wall, flanged top.
        m.add(Prim.lathe([V2(0, b + 0.02), V2(R - 0.03, b + 0.004), V2(R - 0.004, b), V2(R, b + 0.006), V2(R, b + H - 0.01), V2(R + 0.012, b + H - 0.006),
                          V2(R + 0.012, b + H), V2(0, b + H)], segments: 48, seamTile: 0.6, material: paint))
        m.add(Prim.lathe([V2(R - 0.02, 0), V2(R - 0.008, 0), V2(R - 0.006, b + 0.006), V2(R - 0.02, b + 0.01)], segments: 48, material: paint))
        // Weld seam up the back.
        m.add(Prim.roundedBox(V3(0.006, H - 0.03, 0.003), radius: 0.0015, bevelSegments: 1, material: paint), Xform(translation: V3(0, b + H / 2, -R - 0.001)))
        // Cover: shallow dome with a lip over the flange, clamp band with its bolt lug.
        let ct = b + H
        m.add(Prim.lathe([V2(R + 0.018, ct - 0.004), V2(R + 0.02, ct + 0.008), V2(R + 0.006, ct + 0.016), V2(R * 0.7, ct + 0.05), V2(R * 0.3, ct + 0.068), V2(0, ct + 0.072)],
                         segments: 48, seamTile: 0.6, material: paint))
        m.add(Prim.lathe([V2(R + 0.019, ct - 0.016), V2(R + 0.024, ct - 0.014), V2(R + 0.024, ct + 0.004), V2(R + 0.019, ct + 0.006)], segments: 48, material: "metal.galvanized-aged"))
        m.add(Prim.roundedBox(V3(0.03, 0.026, 0.03), radius: 0.003, bevelSegments: 1, material: "metal.galvanized-aged"), Xform(translation: V3(R + 0.03, ct - 0.005, 0)))
        hexBolt(&m, at: V3(R + 0.03, ct - 0.005, 0.016), normal: V3(0, 0, 1), size: 0.016, material: hardware)
        // Primary bushing on the cover, slightly off center, with sheds and an eyebolt connector.
        let pb = V3(0.06, ct + 0.06, 0.05)
        var sheds: [V2] = [V2(0, 0), V2(0.04, 0), V2(0.04, 0.012), V2(0.028, 0.02)]
        for k in 0..<3 { let y = 0.03 + Float(k) * 0.034; sheds += [V2(0.024, y), V2(0.048, y + 0.01), V2(0.046, y + 0.016), V2(0.024, y + 0.026)] }
        sheds += [V2(0.022, 0.14), V2(0.016, 0.15), V2(0, 0.152)]
        m.add(Prim.lathe(sheds, segments: 28, seamTile: 0.2, material: porcelain), Xform(translation: pb))
        m.add(Prim.cylinder(radius: 0.008, height: 0.03, bevel: 0.002, segments: 12, material: "metal.bronze-cast"), Xform(translation: pb + V3(0, 0.15, 0)))
        m.add(Prim.torus(major: 0.011, minor: 0.0035, segments: 16, sides: 6, material: "metal.bronze-cast"),
              Xform(translation: pb + V3(0, 0.188, 0), rotation: simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))))
        // Secondary bushings X1 X2 X3 on the front wall, with spade terminals.
        for (i, ang) in [Float(-0.5), 0, 0.5].enumerated() {
            let d = V3(sin(ang), 0, cos(ang)), y = b + H - 0.13
            let base = V3(d.x * (R - 0.004), y, d.z * (R - 0.004))
            let q = simd_quatf(from: .up, to: d)
            var prof: [V2] = [V2(0, 0), V2(0.03, 0), V2(0.03, 0.01), V2(0.022, 0.016)]
            prof += [V2(0.027, 0.03), V2(0.022, 0.042), V2(0.026, 0.054), V2(0.018, 0.068), V2(0, 0.07)]
            m.add(Prim.lathe(prof, segments: 20, material: i == 1 ? "ceramic.porcelain-black" : porcelain), Xform(translation: base, rotation: q))
            let tip = base + d * 0.07
            m.add(Prim.cylinder(radius: 0.007, height: 0.03, bevel: 0.0015, segments: 10, material: "metal.bronze-cast"), Xform(translation: tip, rotation: q))
            m.add(Prim.roundedBox(V3(0.03, 0.04, 0.006), radius: 0.003, bevelSegments: 1, material: "metal.bronze-cast"),
                  Xform(translation: tip + d * 0.045 + V3(0, -0.01, 0), rotation: simd_quatf(angle: ang, axis: .up)))
        }
        // Hanger lugs on the back (pole side), welded vertical brackets with slots.
        for y in [b + H - 0.12, b + 0.18] {
            m.add(Prim.roundedBox(V3(0.16, 0.08, 0.05), radius: 0.006, bevelSegments: 1, material: hardware), Xform(translation: V3(0, y, -R - 0.02)))
            for s: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(0.012, 0.1, 0.07), radius: 0.003, bevelSegments: 1, material: hardware), Xform(translation: V3(s * 0.08, y, -R - 0.03)))
            }
        }
        // Lifting lugs at the top sides.
        for s: Float in [-1, 1] {
            let p = V3(s * (R + 0.018), b + H - 0.06, 0)
            m.add(Prim.roundedBox(V3(0.04, 0.07, 0.012), radius: 0.004, bevelSegments: 1, material: paint), Xform(translation: p, rotation: simd_quatf(angle: .pi / 2, axis: .up)))
            m.add(Prim.torus(major: 0.012, minor: 0.004, segments: 12, sides: 5, material: paint), Xform(translation: p + V3(0, 0.035, 0), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1))))
        }
        // Nameplate, kVA stencil and ground pad.
        let fz = R + 0.0015
        m.add(Prim.roundedBox(V3(0.09, 0.06, 0.003), radius: 0.002, bevelSegments: 1, material: "metal.aluminum-brushed"),
              Xform(translation: V3(sin(-0.9) * fz, b + 0.42, cos(-0.9) * fz), rotation: simd_quatf(angle: -0.9, axis: .up)))
        for (k, w) in [Float(0.022), 0.022, 0.012].enumerated() {
            m.add(Prim.roundedBox(V3(w, 0.05, 0.001), radius: 0.0005, bevelSegments: 1, material: "plastic.matte:1C1C1C"),
                  Xform(translation: V3(-0.03 + Float(k) * 0.03, b + 0.3, fz + 0.0003)))
        }
        m.add(Prim.roundedBox(V3(0.05, 0.04, 0.008), radius: 0.003, bevelSegments: 1, material: "metal.bronze-cast"), Xform(translation: V3(0.12, b + 0.08, R * 0.9)))
        _ = rng.float()
        groundAO(&m, height: 0.12, floor: 0.55)
        let bb = m.bounds, c = (bb.min + bb.max) / 2
        var out = Model(name: Self.id); out.add(m, Xform(translation: V3(-c.x, -bb.min.y, -c.z)))
        return LODModel(out)
    }
}
