import simd
import Foundation

/// Weathering-steel landscape edging, 2.4 m strip by default: 3 mm x 10 cm Corten strip with a rolled
/// top bead, following a gentle S-curve, with triangular ground stakes riveted every 0.6 m on the lawn face, a slotted
/// joiner tab at one end, and the mulch bed it retains banked against the stake side and soil on the lawn side. Base at the stake tips' ground line (strip bottom at y = 0).
public struct SteelEdging: RealAsset {
    public static let id = "steel-edging"
    public static let summary = "Corten steel landscape edging, 2.4 m: 3 mm x 10 cm curved strip, rolled top, riveted stakes, joiner tab, mulch and lawn soil."
    public static let tags = ["prop", "garden", "outdoor", "landscaping", "metal", "barrier"]
    public static let budget = 7_500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 28, distance: 0.9, studio: true)

    /// Strip length along X (m).
    public var length: Float = 2.4
    /// Strip height (m).
    public var height: Float = 0.1
    /// Steel thickness (m).
    public var thickness: Float = 0.003
    /// Sideways bow of the S-curve (m); 0 = straight.
    public var bow: Float = 0.12
    /// Stake spacing (m).
    public var stakeSpacing: Float = 0.6
    /// Mulch berm behind the edging (the bed side).
    public var berm = true
    /// Berm material.
    public var bermMaterial: MaterialKey = "mulch.bark"
    /// Stake material (darker, older steel).
    public var stakeMaterial: MaterialKey = "metal.corten:4A2814"
    /// Lawn-side soil material.
    public var lawnSoil: MaterialKey = "ground.dirt"
    /// Steel material.
    public var steel: MaterialKey = "metal.corten"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let n = max(8, Int(length / 0.05))
        let phase = rng.float(-0.3...0.3)
        func at(_ t: Float) -> V3 { V3((t - 0.5) * length, 0, bow * sin((t * 2 + phase) * .pi) * 0.5) }
        let path = (0...n).map { at(Float($0) / Float(n)) }
        // Section in the sweep frame: x follows `up` (vertical), y across the thickness.
        let h = height, th = thickness
        let profile: [V2] = Shape2D.rounded([V2(0, -th / 2), V2(h - 0.004, -th / 2), V2(h - 0.004, -th / 2 - 0.0015), V2(h, -th / 2 - 0.0015),
                                             V2(h, th / 2 + 0.0015), V2(h - 0.004, th / 2 + 0.0015), V2(h - 0.004, th / 2), V2(0, th / 2)], radius: 0.0008, segments: 2)
        var m = Model(name: Self.id), lite = Model(name: Self.id + "-lite")
        let strip = Prim.sweep(profile, along: path, up: .up, material: steel)
        m.add(strip); lite.add(Prim.sweep([V2(0, -th / 2), V2(h, -th / 2), V2(h, th / 2), V2(0, th / 2)], along: path, up: .up, material: steel))
        // Stakes: triangular plates riveted to the back face, tips at ground.
        let count = max(1, Int(length / stakeSpacing))
        for k in 0..<count {
            let t = (Float(k) + 0.5) / Float(count)
            let p = at(t), dir = simd_normalize(at(min(1, t + 0.01)) - at(max(0, t - 0.01)))
            let nrm = simd_normalize(simd_cross(dir, .up))
            let plate = Prim.extrude(Shape2D.rounded([V2(-0.035, h * 0.75), V2(0.035, h * 0.75), V2(0.006, 0.004), V2(-0.006, 0.004)], radius: 0.003, segments: 2),
                                     depth: 0.003, bevel: 0.0008, bevelSegments: 1, material: stakeMaterial)
            let rot = simd_quatf(from: V3(0, 0, 1), to: nrm)
            let xf = Xform(translation: p + nrm * (th / 2 + 0.0035), rotation: rot)
            m.add(plate, xf); lite.add(plate, xf)
            for dy: Float in [h * 0.45, h * 0.65] {
                m.add(Prim.cylinder(radius: 0.0045, height: 0.002, bevel: 0.0012, segments: 10, bevelSegments: 1, material: steel),
                      Xform(translation: p + nrm * (th / 2 + 0.005) + V3(0, dy, 0), rotation: simd_quatf(from: .up, to: nrm)))
                m.add(Prim.cylinder(radius: 0.0045, height: 0.002, bevel: 0.0012, segments: 10, bevelSegments: 1, material: steel),
                      Xform(translation: p - nrm * (th / 2) + V3(0, dy, 0), rotation: simd_quatf(from: .up, to: -nrm)))
            }
        }
        // Mulch berm on the stake side: the edging holds a planting bed above the lawn line.
        if berm {
            let sd = UInt32(truncatingIfNeeded: rng.int(0...100_000))
            var b = Surface(material: bermMaterial)
            let cols = 8
            for i in 0...n {
                let t = Float(i) / Float(n), p = at(t)
                let dir = simd_normalize(at(min(1, t + 0.01)) - at(max(0, t - 0.01)))
                let nrm = simd_normalize(simd_cross(dir, .up)) * -1
                for j in 0...cols {
                    let f = Float(j) / Float(cols)
                    let out = th / 2 + 0.02 + f * 0.22
                    let hgt = (h * 0.12) * (1 - f * f) + 0.01 * Noise.fbm(p * 12 + nrm * f * 3, octaves: 3, seed: sd)
                    let q = p + nrm * out
                    b.add(V3(q.x, max(0.001, hgt), q.z), .up, V2(q.x, q.z))
                }
            }
            let row = UInt32(cols + 1)
            for i in 0..<UInt32(n) { for j in 0..<UInt32(cols) { let a = i * row + j; b.quad(a, a + row, a + row + 1, a + 1) } }
            b.recomputeNormals(weldSeams: true); b.computeTangents()
            m.add(b); lite.add(b)
            // Lawn-side soil strip, a little lower than the bed.
            var g = Surface(material: lawnSoil)
            for i in 0...n {
                let t = Float(i) / Float(n), p = at(t)
                let dir = simd_normalize(at(min(1, t + 0.01)) - at(max(0, t - 0.01)))
                let nrm = simd_normalize(simd_cross(dir, .up))
                for j in 0...4 {
                    let f = Float(j) / 4, q = p + nrm * (th / 2 + 0.002 + f * 0.12)
                    g.add(V3(q.x, max(0.001, 0.02 * (1 - f) + 0.004 * Noise.fbm(q * 15, octaves: 2, seed: sd + 5)), q.z), .up, V2(q.x, q.z))
                }
            }
            for i in 0..<UInt32(n) { for j in 0..<UInt32(4) { let a = i * 5 + j; g.quad(a, a + 1, a + 6, a + 5) } }
            g.recomputeNormals(weldSeams: true); g.computeTangents()
            m.add(g); lite.add(g)
        }
        // A spare stake left lying on the lawn side near the start of the run.
        do {
            let p = at(0.12), dir = simd_normalize(at(0.13) - at(0.11))
            let nrm = simd_normalize(simd_cross(dir, .up))
            let spare = Prim.extrude(Shape2D.rounded([V2(-0.035, h * 0.75), V2(0.035, h * 0.75), V2(0.006, 0.004), V2(-0.006, 0.004)], radius: 0.003, segments: 2),
                                     depth: 0.003, bevel: 0.0008, bevelSegments: 1, material: stakeMaterial)
            m.add(spare, Xform(translation: p + nrm * 0.07 + V3(0, 0.024, 0), rotation: simd_quatf(degrees: 25, axis: .up) * simd_quatf(degrees: -88, axis: V3(1, 0, 0))))
        }
        // Joiner tab with slots at the +X end.
        let e = at(1), e0 = at(0.98), ed = simd_normalize(e - e0)
        let en = simd_normalize(simd_cross(ed, .up)) * -1
        let tab = Prim.extrude(Shape2D.roundedRect(0.08, h * 0.7, radius: 0.004), depth: 0.003, bevel: 0.0008, bevelSegments: 1, material: steel)
        let rotTab = simd_quatf(from: V3(1, 0, 0), to: ed)
        m.add(tab, Xform(translation: e - ed * 0.02 + en * (th / 2 + 0.0016) + V3(0, h * 0.4, 0), rotation: rotTab))
        let bb = m.bounds
        let shift = V3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2)
        m = m.transformed(Xform(translation: shift)); lite = lite.transformed(Xform(translation: shift))
        groundAO(&m, height: 0.05, floor: 0.6)
        return LODModel(levels: [m, lite], switchDistances: [8])
    }
}
