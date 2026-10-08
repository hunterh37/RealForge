import simd
import Foundation

/// Packaged rooftop HVAC unit (10-ton class RTU): sheet-metal cabinet on a galvanized roof curb,
/// louvered condenser-coil guards on the back and one end, two condenser fans on top behind wire
/// guards, hinged access panels with quarter-turn latches on the front, an outside-air rain hood,
/// a yellow gas line and a conduit whip to a disconnect box. Base y = 0 is the roof deck.
public struct RooftopHvac: RealAsset {
    public static let id = "rooftop-hvac"
    public static let summary = "Packaged rooftop HVAC unit: sheet-metal cabinet on a curb, condenser coil grilles, two fan guards on top, access panels and ductwork."
    public static let tags = ["structure", "architecture", "roof", "metal", "industrial"]
    public static let budget = 20_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 34, elevation: 18, distance: 1.0, studio: true)

    /// Cabinet size (m).
    public var size = V3(2.3, 1.1, 1.3)
    /// Roof curb height (m).
    public var curbHeight: Float = 0.3
    /// Condenser fans on top.
    public var fans: Int = 2
    public var cabinetMaterial: MaterialKey = "metal.powder-white:CFC8B6"
    public var curbMaterial: MaterialKey = "metal.galvanized-aged"
    public var guardMaterial: MaterialKey = "metal.wrought-iron"
    public var gasMaterial: MaterialKey = "metal.painted:D8B020"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id), lite = Model(name: Self.id + "-lite")
        let W = size.x, Hc = size.y, D = size.z, cH = curbHeight
        let y0 = cH, y1 = cH + Hc
        let cab = cabinetMaterial
        func both(_ s: Surface) { m.add(s); lite.add(s) }

        // Curb with wood nailer and counterflashing.
        both(HK.box(V3(W - 0.1, cH, D - 0.1), V3(0, cH / 2, 0), curbMaterial, r: 0.006))
        both(HK.box(V3(W - 0.06, 0.03, D - 0.06), V3(0, cH - 0.015, 0), curbMaterial, r: 0.004))
        // Cabinet: base rail, body, top pan.
        both(HK.box(V3(W, 0.08, D), V3(0, y0 + 0.04, 0), cab, r: 0.006))
        both(HK.box(V3(W - 0.004, Hc - 0.12, D - 0.004), V3(0, y0 + 0.08 + (Hc - 0.12) / 2, 0), cab, r: 0.008))
        both(HK.box(V3(W + 0.01, 0.04, D + 0.01), V3(0, y1 - 0.02, 0), cab, r: 0.01))

        // Front (+Z) access panels with latches and a nameplate.
        let np = 4
        let pw = (W - 0.1) / Float(np)
        for i in 0..<np {
            let x = -W / 2 + 0.05 + pw * (Float(i) + 0.5)
            m.add(HK.box(V3(pw - 0.02, Hc - 0.22, 0.012), V3(x, y0 + 0.11 + (Hc - 0.22) / 2, D / 2 + 0.004), cab, r: 0.004))
            for sy: Float in [0.3, 0.75] {
                m.add(HK.cyl(r: 0.016, len: 0.012, at: V3(x + pw * 0.38, y0 + Hc * sy, D / 2 + 0.014), axis: V3(0, 0, 1), mat: "plastic.black", seg: 12))
            }
            for (sx, sy) in [(Float(-0.45), Float(0.15)), (0.45, 0.15), (-0.45, 0.85), (0.45, 0.85)] {
                m.add(HK.cyl(r: 0.005, len: 0.004, at: V3(x + pw * sx, y0 + 0.11 + (Hc - 0.22) * sy, D / 2 + 0.011), axis: V3(0, 0, 1), mat: "metal.steel", seg: 6))
            }
        }
        m.add(HK.box(V3(0.18, 0.1, 0.002), V3(-W / 2 + 0.25, y1 - 0.15, D / 2 + 0.011), "metal.satin-aluminum", r: 0.001, seg: 1))
        // Back (-Z) and right end: louvered coil guards, coil fins seen behind.
        do {
            let c = V3(0.1, y0 + Hc / 2, -D / 2 - 0.006), w = W - 0.5, h = Hc - 0.3
            m.add(HK.box(V3(w, h, 0.004), c + V3(0, 0, 0.02), "plastic.matte:3A3C38", r: 0.001, seg: 1))
            lite.add(HK.box(V3(w, h, 0.004), c, "plastic.matte:3A3C38", r: 0.001, seg: 1))
            let k = Int(h / 0.035)
            for j in 0..<k {
                let y = c.y - h / 2 + 0.02 + Float(j) * h / Float(k)
                m.add(HK.box(V3(w, 0.03, 0.003), V3(0, 0, 0), cab, r: 0.001, seg: 1), Xform(translation: V3(c.x, y, c.z), rotation: simd_quatf(degrees: 35, axis: V3(1, 0, 0))))
            }
        }
        // End louvers built with a rotated frame.
        do {
            let c = V3(W / 2 + 0.006, y0 + Hc / 2, 0)
            let k = Int((Hc - 0.3) / 0.035)
            m.add(HK.box(V3(0.004, Hc - 0.3, D - 0.3), c - V3(0.02, 0, 0), "plastic.matte:3A3C38", r: 0.001, seg: 1))
            for j in 0..<k {
                let y = c.y - (Hc - 0.3) / 2 + 0.02 + Float(j) * (Hc - 0.3) / Float(k)
                m.add(HK.box(V3(0.003, 0.03, D - 0.3), .zero, cab, r: 0.001, seg: 1), Xform(translation: V3(c.x, y, 0), rotation: simd_quatf(degrees: 35, axis: V3(0, 0, 1))))
            }
        }
        // Top: fan openings with guards, dark blades below.
        for f in 0..<fans {
            let fx = W / 2 - 0.45 - Float(f) * 0.75
            let r: Float = 0.3
            m.add(Prim.cylinder(radius: r + 0.02, height: 0.04, bevel: 0.006, segments: 32, bevelSegments: 1, material: cab).transformed(Xform(translation: V3(fx, y1, 0))))
            m.add(Prim.cylinder(radius: r, height: 0.002, bevel: 0.0005, segments: 32, bevelSegments: 1, material: "plastic.matte:1A1A1A").transformed(Xform(translation: V3(fx, y1 + 0.02, 0))))
            for b in 0..<3 {
                let a = Float(b) * 2 * .pi / 3 + rng.float(0...0.5)
                m.add(HK.box(V3(r * 0.85, 0.006, 0.12), V3(0, 0, 0), "plastic.matte:2C2C2C", r: 0.002, seg: 1),
                      Xform(translation: V3(fx + cos(a) * r * 0.45, y1 + 0.03, sin(a) * r * 0.45), rotation: simd_quatf(angle: -a, axis: .up) * simd_quatf(degrees: 18, axis: V3(1, 0, 0))))
            }
            // Wire guard: concentric rings and radial wires.
            for k in 1...5 {
                let rr = r * Float(k) / 5
                m.add(Prim.torus(major: rr, minor: 0.003, segments: 28, sides: 4, material: guardMaterial).transformed(Xform(translation: V3(fx, y1 + 0.06, 0))))
            }
            for k in 0..<8 {
                let a = Float(k) / 8 * 2 * .pi
                m.add(HK.pipe([V3(fx, y1 + 0.065, 0), V3(fx + cos(a) * r, y1 + 0.05, sin(a) * r)], r: 0.003, sides: 4, mat: guardMaterial))
            }
            lite.add(Prim.cylinder(radius: r + 0.02, height: 0.06, bevel: 0.006, segments: 16, bevelSegments: 1, material: "plastic.matte:1A1A1A").transformed(Xform(translation: V3(fx, y1, 0))))
        }
        // Outside-air rain hood on the left end.
        // Outside-air hood: wedge with its open mouth facing down (bird screen dark).
        let wedge = Prim.extrude([V2(0, 0.45), V2(0, 0), V2(-0.22, 0)], depth: 0.5, bevel: 0.004, bevelSegments: 1, material: cab)
        both(wedge.transformed(Xform(translation: V3(-W / 2 - 0.002, y1 - 0.6, 0.1))))
        m.add(HK.box(V3(0.2, 0.003, 0.46), V3(-W / 2 - 0.11, y1 - 0.602, 0.1), "plastic.matte:1A1A1A", r: 0.001, seg: 1))
        // Gas line from the curb up to the unit, disconnect box with conduit.
        m.add(HK.pipe([V3(-W / 2 + 0.2, 0.04, D / 2 + 0.25), V3(-W / 2 + 0.2, 0.04, D / 2 + 0.08), V3(-W / 2 + 0.2, y0 + 0.25, D / 2 + 0.08), V3(-W / 2 + 0.2, y0 + 0.25, D / 2 + 0.01)], r: 0.016, sides: 10, mat: gasMaterial))
        for py in [Float(0.15), 0.45] {
            m.add(HK.box(V3(0.12, 0.08, 0.12), V3(-W / 2 + 0.2, 0.04, D / 2 + 0.1 + py * 0.3), "rubber", r: 0.01))
        }
        both(HK.box(V3(0.2, 0.3, 0.12), V3(W / 2 - 0.3, y0 + 0.35, D / 2 + 0.07), "metal.galvanized", r: 0.008))
        m.add(HK.pipe([V3(W / 2 - 0.3, y0 + 0.2, D / 2 + 0.07), V3(W / 2 - 0.3, 0.12, D / 2 + 0.12), V3(W / 2 - 0.3, 0.05, D / 2 + 0.4)], r: 0.012, sides: 8, mat: "metal.galvanized"))

        groundAO(&m, height: 0.2, floor: 0.7)
        groundAO(&lite, height: 0.2, floor: 0.7)
        let b = m.bounds
        let c = Xform(translation: V3(-(b.min.x + b.max.x) / 2, 0, -(b.min.z + b.max.z) / 2))
        return LODModel(levels: [m.transformed(c), lite.transformed(c)], switchDistances: [14])
    }
}
