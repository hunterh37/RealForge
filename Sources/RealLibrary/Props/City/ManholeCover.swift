import simd
import Foundation

/// Cast-iron sewer manhole cover, 76 cm, flush in its frame ring and set in a square collar of
/// patch asphalt. The lid carries a raised diamond tread clipped to a ring, a cast SEWER legend and
/// two pick holes; tyres have polished the tread tops.
public struct ManholeCover: RealAsset {
    public static let id = "manhole-cover"
    public static let summary = "Cast-iron manhole cover, 76 cm, with a diamond-tread pattern, pick holes and frame ring set in an asphalt patch."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "metal", "road"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 45, distance: 1.0)

    /// Lid diameter (m).
    public var diameter: Float = 0.76
    /// Collar patch size (m).
    public var collar: Float = 1.0
    /// Cast legend.
    public var legend = "SEWER"
    /// Tread diamond pitch (m).
    public var pitch: Float = 0.045
    /// Materials.
    public var iron: MaterialKey = "metal.cast-iron-street"
    public var polished: MaterialKey = "metal.cast-iron-worn"
    public var patch: MaterialKey = "asphalt.patch"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = diameter / 2, top: Float = 0.022
        // Asphalt collar with rough edge, slightly below the ring.
        var pts: [V2] = []
        for k in 0..<24 { let a = Float(k) / 24 * 2 * .pi, d = V2(cos(a), sin(a))
            let sq = collar / 2 / max(abs(d.x), abs(d.y))
            pts.append(d * (sq + rng.float(-0.012...0))) }
        cityLayer(&m, outline: pts, y: 0, lift: (top - 0.002) / 2, thick: top - 0.002, bevel: 0.006, material: patch)
        // Frame ring.
        m.add(Prim.lathe([V2(R + 0.004, top - 0.004), V2(R + 0.07, top - 0.004), V2(R + 0.075, top - 0.001), V2(R + 0.075, top + 0.002),
                          V2(R + 0.07, top + 0.004), V2(R + 0.006, top + 0.004), V2(R + 0.004, top - 0.004)], segments: 64, seamTile: 0.2, material: iron))
        // Lid disc.
        m.add(Prim.cylinder(radius: R, height: 0.012, bevel: 0.004, segments: 64, material: iron), Xform(translation: V3(0, top - 0.008, 0)))
        let ly = top + 0.004
        // Diamond tread between the legend band and the rim band.
        let n = Int(R / pitch) + 1
        var tread = Surface(material: polished)
        let dia = cuboid(V3(pitch * 0.42, 0.004, pitch * 0.42), material: polished)
        for i in -n...n { for j in -n...n {
            let p = V2(Float(i), Float(j)) * pitch + (abs(i + j) % 2 == 0 ? .zero : V2(0, 0))
            let r = simd_length(p)
            guard r < R - 0.04, abs(p.y) > 0.06 || r > R * 0.62 else { continue }
            tread.append(dia, Xform(translation: V3(p.x, ly, p.y), rotation: simd_quatf(degrees: 45, axis: .up)))
        }}
        m.add(tread)
        // Rim bead and legend band border.
        m.add(Prim.torus(major: R - 0.022, minor: 0.004, segments: 64, sides: 6, minorY: 0.0024, material: polished), Xform(translation: V3(0, top + 0.003, 0)))
        for s: Float in [-1, 1] {
            m.add(cuboid(V3(R * 1.25, 0.004, 0.008), material: polished), Xform(translation: V3(0, ly, s * 0.055)))
        }
        // Cast legend, flat on the lid.
        var t = strokeText(legend, height: 0.06, stroke: 0.011, depth: 0.004, material: polished)
        t = t.transformed(Xform(rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0)), scale: V3(0.8, 1, 1)))
        m.add(t, Xform(translation: V3(0, ly - 0.002, 0)))
        // Pick holes.
        for s: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.04, 0.003, 0.014), radius: 0.004, bevelSegments: 1, material: "metal.steel:0A0A0A"), Xform(translation: V3(s * (R - 0.06), top + 0.003, 0)))
        }
        groundAO(&m, height: 0.03, floor: 0.75)
        return LODModel(m)
    }
}
