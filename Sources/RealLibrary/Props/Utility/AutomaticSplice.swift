import simd
import Foundation

/// Full-tension automatic splice for 1/0 ACSR (Fargo GLS class), lying on its side: a seamless
/// aluminum tube swaged into long tapers at both ends, with the two center-stop dimples, stamped size
/// marking and the color-coded plastic funnel guides pushed into each mouth. Conductor pushed into a
/// funnel lifts the jaws off their spring and the tension sets them.
public struct AutomaticSplice: RealAsset {
    public static let id = "automatic-splice"
    public static let summary = "Full-tension automatic splice for 1/0 ACSR: tapered aluminum tube, internal jaw cones, color-coded funnel guides at both ends."
    public static let tags = ["prop", "utility", "electrical", "handheld", "metal"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 22, distance: 1.0, studio: true)

    /// Overall length including guides (m).
    public var length: Float = 0.4
    /// Body radius at the center (m).
    public var bodyRadius: Float = 0.0142
    /// Funnel guide color (sRGB hex); red marks the 1/0 ACSR size.
    public var guideColor: UInt32 = 0xE8432E
    /// Tube material.
    public var tube: MaterialKey = "metal.aluminum-cast"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length, rB = bodyRadius, half = L / 2
        let guide: MaterialKey = "plastic.resin-red:" + String(format: "%06X", guideColor)
        // Body profile along +Y from one end to the center, mirrored.
        let g: Float = 0.016    // funnel guide length
        let side: [V2] = [V2(0.0088, g - 0.004), V2(0.0098, g), V2(0.0102, g + 0.004), V2(0.0108, g + 0.03),
                          V2(0.0122, g + 0.07), V2(rB - 0.0005, g + 0.115), V2(rB, g + 0.13), V2(rB, half)]
        var prof = side
        prof += side.reversed().dropFirst().map { V2($0.x, L - $0.y) }
        var body = Prim.lathe([V2(0.0075, g - 0.004)] + prof + [V2(0.0075, L - g + 0.004)], segments: 32, seamTile: 0.2, material: tube)
        // Center-stop dimples: two shallow pressed dents.
        body.deform { q in
            for dy: Float in [-0.012, 0.012] {
                let d = simd_length(V2(q.z - 0, q.y - (half + dy))) , ang = atan2(q.z, q.x)
                if abs(ang - .pi / 2) < 0.45 && d < 0.008 { let k = 1 - d / 0.008; return q - simd_normalize(V3(q.x, 0, q.z)) * 0.0022 * k * k }
            }
            return q
        }
        body.recomputeNormals()
        // Funnel guides: flared red cups at both mouths.
        let funnel: [V2] = [V2(0.0045, g + 0.004), V2(0.0098, g - 0.002), V2(0.0112, g - 0.004), V2(0.0118, 0.005), V2(0.0132, 0.0015), V2(0.0134, 0),
                            V2(0.0118, 0), V2(0.0062, g - 0.006)]
        var cups = Prim.lathe(funnel, segments: 28, seamTile: 0.1, material: guide)
        cups.append(Prim.lathe(funnel.map { V2($0.x, L - $0.y) }.reversed(), segments: 28, seamTile: 0.1, material: guide))
        // Mould flash ring on each guide lip.
        var ink = Surface(material: guide)
        for y in [Float(0.0035), L - 0.0035] {
            ink.append(Prim.torus(major: 0.0128, minor: 0.0009, segments: 28, sides: 4, material: guide), Xform(translation: V3(0, y, 0)))
        }
        _ = rng.float()
        // Lay along X, resting on the tube.
        let lay = Xform(translation: V3(-half, rB, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1)))
        m.add(body, lay); m.add(cups, lay); m.add(ink, lay)
        groundAO(&m, height: 0.02, floor: 0.55)
        return LODModel(m)
    }
}
