import simd
import Foundation

/// Wooden cable reel standing on its flanges: 0.9 m plywood flanges 30 mm thick, 0.45 m drum, 0.5 m between
/// flanges, four steel tie rods with nuts, part-wound black cable with a loose end trailing to the ground.
public struct CableSpool: RealAsset {
    public static let id = "cable-spool"
    public static let summary = "Wooden cable reel, 0.9 m: plywood flanges, tie rods, wound black cable with a loose end to the ground."
    public static let tags = ["prop", "construction", "wood", "industrial"]
    public static let budget = 7_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 40, elevation: 14)

    public var flangeDiameter: Float = 0.9
    public var drumDiameter: Float = 0.45
    public var width: Float = 0.5
    /// Wound cable outer diameter (drum diameter = empty).
    public var cableDiameter: Float = 0.72
    public var cableMaterial: MaterialKey = "rubber"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = flangeDiameter / 2, t: Float = 0.03, hw = width / 2
        let wound = max(drumDiameter / 2, min(R - 0.04, rng.vary(cableDiameter / 2, 0.06)))
        // Built with the axis on Y, then laid onto X.
        var parts = Model(name: "spool")
        for sy: Float in [-1, 1] {
            let y0 = sy * hw, y1 = sy * (hw + t)
            // Faces: flat discs with planar UVs so the veneer grain runs straight.
            for (y, up) in [(y0, -sy), (y1, sy)] {
                var d = Surface(material: "wood.plywood")
                let seg = 48
                let rot = rng.float(0...(2 * .pi))
                let c = d.add(V3(0, y, 0), V3(0, up, 0), V2(0, 0))
                for k in 0...seg {
                    let a = Float(k) / Float(seg) * 2 * .pi
                    let p = V2(cos(a), sin(a)) * R
                    let uv = V2(p.x * cos(rot) - p.y * sin(rot), p.x * sin(rot) + p.y * cos(rot)) + V2(0.3, 0.7)
                    d.add(V3(p.x, y, p.y), V3(0, up, 0), uv)
                }
                for k in 0..<UInt32(seg) { d.tri(c, 1 + k, 2 + k) }
                CFKit.orient(&d) { _ in V3(0, up, 0) }
                parts.add(d)
            }
            // Edge band: plies across the 30 mm thickness.
            var edge = Prim.lathe([V2(R, min(y0, y1)), V2(R, max(y0, y1))], segments: 48, seamTile: 0.1, material: "wood.plywood-edge")
            CFKit.orient(&edge) { p in V3(p.x, 0, p.z) }
            parts.add(edge)
            // Tie rod nuts and square washers on the outside face.
            for k in 0..<4 {
                let a = Float(k) / 4 * 2 * .pi + .pi / 4
                let p = V3(cos(a), 0, sin(a)) * (drumDiameter / 2 - 0.05)
                parts.add(Prim.roundedBox(V3(0.07, 0.006, 0.07), radius: 0.002, bevelSegments: 1, material: "metal.rust"), Xform(translation: p + V3(0, y1 + sy * 0.003, 0)))
                parts.add(turned([(0, 0), (0.016, 0), (0.016, 0.014), (0.0, 0.016)], segments: 6, material: "metal.rust"),
                          Xform(translation: p + V3(0, y1 + sy * 0.006, 0), rotation: simd_quatf(degrees: sy > 0 ? 0 : 180, axis: V3(1, 0, 0))))
                parts.add(turned([(0, 0), (0.008, 0), (0.008, 0.03), (0, 0.032)], segments: 6, material: "metal.rust"),
                          Xform(translation: p + V3(0, y1 + sy * 0.02, 0), rotation: simd_quatf(degrees: sy > 0 ? 0 : 180, axis: V3(1, 0, 0))))
            }
            // Arbor hole plate.
            parts.add(turned([(0.04, 0), (0.09, 0), (0.09, 0.004), (0.04, 0.004)], segments: 24, material: "metal.galvanized"),
                      Xform(translation: V3(0, y1 - (sy < 0 ? 0.004 : 0), 0)))
        }
        // Drum staves under the cable (visible only when nearly empty).
        parts.add(Prim.lathe([V2(drumDiameter / 2, -hw), V2(drumDiameter / 2, hw)], segments: 40, seamTile: 0.2, material: "wood.weathered"))
        // Wound cable: one ridge per turn across the width.
        let turns = Int(width / 0.024)
        var prof: [V2] = [V2(drumDiameter / 2, -hw + 0.001)]
        for k in 0...turns {
            let y = -hw + 0.012 + Float(k) * (width - 0.024) / Float(turns)
            prof.append(V2(wound - 0.004, y - 0.008)); prof.append(V2(wound + 0.002, y))
        }
        prof.append(V2(wound - 0.004, hw - 0.004)); prof.append(V2(drumDiameter / 2, hw - 0.001))
        let windSeg = 40
        var cable = Prim.lathe(prof, segments: windSeg, seamTile: 0.3, material: cableMaterial)
        cable.positions = cable.positions.map { p in
            let r = simd_length(V2(p.x, p.z))
            guard r > drumDiameter / 2 + 0.01 else { return p }
            let a = atan2(p.z, p.x)
            return p + V3(cos(a), 0, sin(a)) * Noise.perlin(V3(a * 2, p.y * 6, 0), seed: UInt32(truncatingIfNeeded: seed)) * 0.006
        }
        cable.recomputeNormals(); cable.computeTangents()
        parts.add(cable)
        // Lay the reel on its flanges: axis Y -> X, flange rim on the ground.
        let lay = Xform(translation: V3(0, R, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1)) * simd_quatf(degrees: rng.float(0...360), axis: .up))
        m.add(parts, lay)
        // Loose end: leaves the top of the winding, arcs forward and lies on the ground.
        let x0 = rng.float(-hw + 0.05...hw - 0.05)
        let end: [V3] = [V3(x0, R + wound - 0.004, -0.05), V3(x0, R + wound + 0.01, 0.12), V3(x0 + 0.03, R + 0.15, wound + 0.08),
                         V3(x0 + 0.05, 0.25, R + 0.2), V3(x0 + 0.1, 0.012, R + 0.45), V3(x0 + 0.25, 0.012, R + 0.75)]
        m.add(CFKit.pipe(end, radius: 0.011, sides: 8, per: 5, material: cableMaterial))
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
