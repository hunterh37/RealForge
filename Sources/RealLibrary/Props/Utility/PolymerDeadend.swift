import simd
import Foundation

/// 15 kV distribution polymer deadend (suspension) insulator, DS-15 class, standing on its tongue:
/// a fiberglass rod in a one-piece gray silicone housing with five sheds, hot-dip galvanized forged end
/// fittings crimped on (crimp flats show as bands), a clevis at the top with a bolt, nut and stainless
/// cotter, and a flat tongue with an eye at the bottom. A thin mold parting line runs up the housing.
public struct PolymerDeadend: RealAsset {
    public static let id = "polymer-deadend"
    public static let summary = "15 kV silicone polymer deadend insulator: fiberglass rod in a gray silicone housing with five sheds, forged steel clevis and tongue ends."
    public static let tags = ["prop", "utility", "electrical", "handheld", "metal"]
    public static let budget = 11000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 10, distance: 1.4, studio: true)

    /// Overall length, tongue eye to clevis top (m).
    public var length: Float = 0.39
    /// Number of sheds.
    public var sheds = 5
    /// Shed radius (m).
    public var shedRadius: Float = 0.037
    /// Housing core radius over the rod (m).
    public var coreRadius: Float = 0.0135
    /// Silicone housing.
    public var housing: MaterialKey = "rubber.silicone-gray"
    /// Galvanized end fittings.
    public var fitting: MaterialKey = "metal.galvanized"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length, s = L / 0.39
        let rc = coreRadius, fr: Float = 0.0165
        // Tongue: flat forged bar with a round eye at the bottom.
        let eyeY: Float = 0.016
        m.add(Prim.torus(major: 0.0105, minor: 0.0058, segments: 24, sides: 8, material: fitting),
              Xform(translation: V3(0, eyeY, 0), rotation: simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))))
        let tongue = Shape2D.rounded([V2(-0.011, 0.024), V2(0.011, 0.024), V2(0.013, 0.05), V2(-0.013, 0.05)], radius: 0.003, segments: 2)
        m.add(Prim.extrude(tongue, depth: 0.0115, bevel: 0.0018, bevelSegments: 2, material: fitting))
        // Bottom end fitting: forged socket, crimped onto the rod.
        let b0: Float = 0.048, b1: Float = 0.1 * s
        m.add(Prim.lathe([V2(0, b0), V2(0.012, b0), V2(fr, b0 + 0.012), V2(fr, b1 - 0.004), V2(fr - 0.002, b1), V2(rc - 0.001, b1)],
                         segments: 28, seamTile: 0.2, material: fitting))
        for k in 0..<1 {
            m.add(Prim.torus(major: fr - 0.0005, minor: 0.0012, segments: 28, sides: 5, material: "metal.galvanized-aged"),
                  Xform(translation: V3(0, b1 - 0.012 + Float(k) * 0.009, 0)))
        }
        // Housing: core with sheds, sealed collars over each fitting lip.
        let h0 = b1 - 0.006, h1 = L - 0.112 * s + 0.006
        var prof: [V2] = [V2(rc - 0.001, h0 - 0.0005), V2(fr + 0.0008, h0), V2(fr + 0.001, h0 + 0.005), V2(rc + 0.0008, h0 + 0.01)]
        let n = max(1, sheds)
        let span = (h1 - h0 - 0.024)
        for i in 0..<n {
            let y = h0 + 0.012 + span * (Float(i) + 0.5) / Float(n)
            let R = shedRadius
            prof += [V2(rc, y - 0.008), V2(rc + 0.003, y - 0.0042), V2(R - 0.004, y - 0.0012), V2(R - 0.0004, y - 0.0008),
                     V2(R, y), V2(R - 0.0006, y + 0.0007), V2(R - 0.006, y + 0.0014), V2(rc + 0.004, y + 0.0036), V2(rc, y + 0.006)]
        }
        prof += [V2(rc + 0.0008, h1 - 0.01), V2(fr + 0.001, h1 - 0.005), V2(fr + 0.0008, h1), V2(rc - 0.001, h1 + 0.0005)]
        m.add(Prim.lathe(prof, segments: 40, seamTile: 0.2, material: housing))
        // Mold parting line: thin flash on both sides of the core.
        for side: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.0005, h1 - h0 - 0.03, 0.0005), radius: 0.0002, bevelSegments: 1, material: housing),
                  Xform(translation: V3(side * (rc + 0.0001), (h0 + h1) / 2, 0)))
        }
        // Top end fitting and clevis.
        let t0 = h1 - 0.004, t1 = L - 0.05 * s
        m.add(Prim.lathe([V2(rc - 0.001, t0), V2(fr - 0.002, t0), V2(fr, t0 + 0.004), V2(fr, t1 - 0.01), V2(0.013, t1), V2(0, t1)],
                         segments: 28, seamTile: 0.2, material: fitting))
        for k in 0..<1 {
            m.add(Prim.torus(major: fr - 0.0005, minor: 0.0012, segments: 28, sides: 5, material: "metal.galvanized-aged"),
                  Xform(translation: V3(0, t0 + 0.012 + Float(k) * 0.009, 0)))
        }
        // Clevis: forged U, two cheeks with the bolt across them.
        let gap: Float = 0.0185, cheek: Float = 0.009
        let cy = L - 0.016
        let cheekOutline = Shape2D.rounded([V2(-0.0135, 0), V2(0.0135, 0), V2(0.0135, 0.034), V2(0, 0.047), V2(-0.0135, 0.034)], radius: 0.008, segments: 4)
        for side: Float in [-1, 1] {
            m.add(Prim.extrude(cheekOutline, depth: cheek, bevel: 0.0018, bevelSegments: 2, material: fitting),
                  Xform(translation: V3(side * (gap / 2 + cheek / 2), t1 - 0.004, 0), rotation: simd_quatf(angle: .pi / 2, axis: .up)))
        }
        m.add(Prim.roundedBox(V3(gap + 2 * cheek, 0.012, 0.027), radius: 0.004, bevelSegments: 2, material: fitting), Xform(translation: V3(0, t1, 0)))
        // Bolt along X with head, nut and cotter.
        let bl = gap + 2 * cheek + 0.016
        m.add(Prim.cylinder(radius: 0.0064, height: bl, bevel: 0.001, segments: 16, material: fitting),
              Xform(translation: V3(-bl / 2, cy, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))))
        m.add(Prim.cylinder(radius: 0.0105, height: 0.006, bevel: 0.0015, segments: 16, material: fitting),
              Xform(translation: V3(-(gap / 2 + cheek) - 0.006, cy, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))))
        m.add(Prim.cylinder(radius: 0.0098, height: 0.0065, bevel: 0.0012, segments: 6, material: fitting),
              Xform(translation: V3(gap / 2 + cheek, cy, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))))
        let cx = gap / 2 + cheek + 0.0095
        m.add(Prim.torus(major: 0.0042, minor: 0.0011, segments: 14, sides: 4, material: "metal.stainless"),
              Xform(translation: V3(cx, cy + 0.0042, 0), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1))))
        m.add(Prim.tube([V3(cx, cy, 0), V3(cx, cy - 0.016, 0.001)], radii: [0.0011, 0.0011], sides: 4, seamTile: 0.02, material: "metal.stainless"))
        // Light handling marks on the galvanizing.
        for _ in 0..<3 {
            let a = rng.float(0...6.28), y = rng.float(b0 + 0.01...b1 - 0.01)
            m.add(Prim.roundedBox(V3(0.006, 0.003, 0.0006), radius: 0.0002, bevelSegments: 1, material: "metal.galvanized-aged"),
                  Xform(translation: V3(sin(a) * (fr + 0.0002), y, cos(a) * (fr + 0.0002)), rotation: simd_quatf(angle: a, axis: .up)))
        }
        groundAO(&m, height: 0.03, floor: 0.6)
        return LODModel(m)
    }
}
