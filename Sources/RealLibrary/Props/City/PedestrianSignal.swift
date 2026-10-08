import simd
import Foundation

/// Pedestrian signal post: a galvanized pole on a cast base, a countdown pedestrian head (lit
/// orange hand and digits inside a hood visor) on a clamshell bracket, and an accessible push
/// button station with its instruction sign at 1 m.
public struct PedestrianSignal: RealAsset {
    public static let id = "pedestrian-signal"
    public static let summary = "Pedestrian signal post: galvanized pole with a countdown walk/don't-walk head and an accessible push button with sign."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "metal", "light", "sign"]
    public static let budget = 5400
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 10, distance: 1.1)

    /// Pole height (m).
    public var height: Float = 3.2
    /// Countdown digits shown.
    public var countdown = "12"
    /// Materials.
    public var steel: MaterialKey = "metal.galvanized"
    public var housing: MaterialKey = "metal.signal-yellow"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        m.add(turned([(0, 0), (0.17, 0), (0.17, 0.03), (0.13, 0.08), (0.1, 0.25), (0.07, 0.3), (0, 0.3)], segments: 24, material: "metal.galvanized-aged"))
        m.add(turned([(0, 0.3), (0.06, 0.3), (0.055, height - 0.03), (0.06, height - 0.02), (0.03, height), (0, height)], segments: 20, material: steel, seamTile: 0.2))
        // Head on a clamshell bracket facing +Z.
        let hy = height - 0.45, hz: Float = 0.2
        m.add(Prim.roundedBox(V3(0.12, 0.16, hz - 0.04), radius: 0.012, bevelSegments: 1, material: housing), Xform(translation: V3(0, hy, (hz + 0.02) / 2)))
        m.add(Prim.torus(major: 0.064, minor: 0.012, segments: 18, sides: 6, minorY: 0.03, material: housing), Xform(translation: V3(0, hy, 0)))
        let hx = Xform(translation: V3(0, hy, hz + 0.1))
        m.add(Prim.roundedBox(V3(0.46, 0.46, 0.2), radius: 0.02, bevelSegments: 2, material: housing), hx)
        let face = hx.child(Xform(translation: V3(0, 0, 0.1)))
        m.add(Prim.roundedBox(V3(0.4, 0.4, 0.008), radius: 0.01, bevelSegments: 1, material: "glass.signal-off"), face)
        // Lit upraised hand on the left half (palm, four fingers, thumb), countdown digits on the right.
        let orange: MaterialKey = "emissive.signal-orange", h0 = face.child(Xform(translation: V3(-0.09, -0.03, 0.006), scale: V3(1.25, 1.25, 1)))
        m.add(Prim.roundedBox(V3(0.075, 0.08, 0.003), radius: 0.015, bevelSegments: 1, material: orange), h0)
        for k in 0..<4 {
            m.add(Prim.roundedBox(V3(0.015, 0.06 + (k == 1 || k == 2 ? 0.01 : 0), 0.003), radius: 0.007, bevelSegments: 1, material: orange),
                  h0.child(Xform(translation: V3(-0.028 + Float(k) * 0.0187, 0.07, 0))))
        }
        m.add(Prim.roundedBox(V3(0.014, 0.05, 0.003), radius: 0.007, bevelSegments: 1, material: orange),
              h0.child(Xform(translation: V3(-0.05, 0.015, 0), rotation: simd_quatf(degrees: 35, axis: V3(0, 0, 1)))))
        m.add(strokeText(countdown, height: 0.11, stroke: 0.014, depth: 0.003, material: orange).transformed(Xform(scale: V3(0.8, 1, 1))), face.child(Xform(translation: V3(0.09, 0, 0.005))))
        // Egg-crate visor: a lip around the face and a few horizontal louvers.
        for (dx, dy, sx, sy) in [(Float(0), Float(0.215), Float(0.46), Float(0.02)), (0, -0.215, 0.46, 0.02), (-0.215, 0, 0.02, 0.43), (0.215, 0, 0.02, 0.43)] {
            m.add(Prim.roundedBox(V3(sx, sy, 0.08), radius: 0.004, bevelSegments: 1, material: housing), face.child(Xform(translation: V3(dx, dy, 0.04))))
        }
        // Push button station at 1 m facing +Z: housing, sign, button with arrow.
        let py: Float = 1.05
        m.add(Prim.roundedBox(V3(0.13, 0.2, 0.08), radius: 0.015, bevelSegments: 2, material: housing), Xform(translation: V3(0, py, 0.095)))
        m.add(Prim.cylinder(radius: 0.025, height: 0.012, bevel: 0.004, segments: 18, material: "metal.stainless"), Xform(translation: V3(0, py + 0.03, 0.135), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        m.add(Prim.cylinder(radius: 0.018, height: 0.018, bevel: 0.005, segments: 18, material: "metal.chrome"), Xform(translation: V3(0, py + 0.03, 0.137), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        let signX = Xform(translation: V3(0, py + 0.27, 0.07))
        citySignPlate(&m, outline: Shape2D.roundedRect(0.23, 0.3, radius: 0.012, segments: 2), x: signX, thickness: 0.003, border: 0.008, borderMaterial: "plastic.black",
                      face: "sign.white", text: [("PUSH", V2(0, 0.09), 0.035, 0.7), ("BUTTON", V2(0, 0.04), 0.03, 0.7), ("FOR", V2(0, -0.005), 0.03, 0.7)], textMaterial: "plastic.black")
        m.add(Prim.roundedBox(V3(0.06, 0.07, 0.002), radius: 0.008, bevelSegments: 1, material: "emissive.signal-white"), signX.child(Xform(translation: V3(0, -0.08, 0.003))))
        // A strip of old sticker residue on the pole at hand height.
        m.add(cuboid(V3(0.04, 0.07, 0.0008), material: "paper.sheet"), Xform(translation: V3(0.0, 1.45, 0.0558), rotation: simd_quatf(angle: rng.float(-0.2...0.2), axis: V3(0, 0, 1))))
        groundAO(&m, height: 0.3, floor: 0.6)
        let b = m.bounds, c = (b.min + b.max) / 2
        var out = Model(name: Self.id); out.add(m, Xform(translation: V3(-c.x, 0, -c.z)))
        return LODModel(out)
    }
}
