import simd
import Foundation

/// New York rooftop water tank: 3.2 m cedar stave tank (staves taper slightly toward the top),
/// flat steel hoops with tightening lugs, conical cedar roof with a finial and a hinged hatch, on a
/// steel dunnage frame (six legs, ring beams, cross bracing, timber floor beams), a caged-free
/// steel ladder to the roof and the rising main and overflow pipes. Base y = 0 is the roof deck.
public struct WaterTower: RealAsset {
    public static let id = "water-tower"
    public static let summary = "NYC rooftop water tower: cedar stave tank with steel hoops, conical shingled roof and hatch, on a steel frame with ladder."
    public static let tags = ["structure", "architecture", "roof", "wood", "metal", "urban"]
    public static let budget = 28_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 8, distance: 1.0, studio: true)

    /// Tank diameter at the base (m).
    public var diameter: Float = 3.2
    /// Stave height (m).
    public var tankHeight: Float = 3.2
    /// Steel frame height under the tank (m).
    public var frameHeight: Float = 2.8
    /// Number of hoops.
    public var hoops: Int = 9
    /// Number of staves.
    public var staves: Int = 56
    public var woodMaterial: MaterialKey = "wood.cedar-weathered:8C7B66"
    public var steelMaterial: MaterialKey = "metal.wrought-iron"
    public var hoopMaterial: MaterialKey = "metal.rust"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id), lite = Model(name: Self.id + "-lite")
        let R0 = diameter / 2, R1 = R0 * 0.93, Ht = tankHeight, yF = frameHeight
        let fe = steelMaterial
        func both(_ s: Surface, _ x: Xform = .identity) { m.add(s, x); lite.add(s, x) }

        // Staves: boards around the tank, leaning in for the taper.
        let lean = atan((R0 - R1) / Ht)
        for i in 0..<staves {
            let a = Float(i) / Float(staves) * 2 * .pi
            let w = 2 * .pi * R0 / Float(staves) - 0.003
            let rmid = (R0 + R1) / 2
            let q = simd_quatf(angle: -a + .pi / 2, axis: .up) * simd_quatf(angle: -lean, axis: V3(1, 0, 0)) * simd_quatf(degrees: 90, axis: V3(0, 0, 1))
            let s = Prim.roundedBox(V3(Ht, w, 0.06), radius: 0.006, bevelSegments: 1, material: woodMaterial)
            let p = V3(cos(a) * rmid, yF + 0.3 + Ht / 2, sin(a) * rmid)
            m.add(s, Xform(translation: p + V3(0, 0, 0), rotation: q).jittered(&rng, deg: 0.15, offset: 0.002))
        }
        lite.add(Prim.lathe([V2(0, yF + 0.3), V2(R0 + 0.03, yF + 0.3), V2(R1 + 0.03, yF + 0.3 + Ht), V2(0, yF + 0.3 + Ht)], segments: 24, seamTile: 1, material: woodMaterial))
        // Tank bottom (chime) disc.
        both(Prim.cylinder(radius: R0 - 0.02, height: 0.08, bevel: 0.01, segments: 32, bevelSegments: 1, material: woodMaterial).transformed(Xform(translation: V3(0, yF + 0.3, 0))))
        // Hoops: denser toward the bottom where pressure is highest, with lugs.
        for k in 0..<hoops {
            let t = pow(Float(k) / Float(hoops), 1.35)
            let y = yF + 0.45 + t * (Ht - 0.4)
            let r = R0 + (R1 - R0) * (y - yF - 0.3) / Ht + 0.035
            m.add(Prim.torus(major: r, minor: 0.025, segments: 48, sides: 6, minorY: 0.006, material: hoopMaterial).transformed(Xform(translation: V3(0, y, 0))))
            let la = Float(k % 3) * 2.1 + 0.4
            m.add(HK.box(V3(0.05, 0.05, 0.12), V3(0, 0, 0), hoopMaterial, r: 0.008), Xform(translation: V3(cos(la) * (r + 0.02), y, sin(la) * (r + 0.02)), rotation: simd_quatf(angle: -la, axis: .up)))
        }
        // Conical roof (boards radiating) with finial and hatch.
        let yR = yF + 0.3 + Ht
        let cone = Prim.lathe([V2(R1 + 0.12, yR - 0.02), V2(R1 + 0.12, yR + 0.03), V2(0.08, yR + 1.0), V2(0, yR + 1.02)], segments: 40, seamTile: 0.6, material: woodMaterial, swapUV: true)
        both(cone)
        both(Prim.lathe([V2(0, 0), V2(0.06, 0), V2(0.07, 0.08), V2(0.03, 0.14), V2(0.05, 0.2), V2(0, 0.32)], segments: 12, seamTile: 0.2, material: fe).transformed(Xform(translation: V3(0, yR + 0.98, 0))))
        // Hatch on the roof slope facing the ladder.
        let slope = atan(1.0 / (R1 + 0.04))
        m.add(HK.box(V3(0.55, 0.04, 0.6), V3(0, 0, 0), woodMaterial, r: 0.008),
              Xform(translation: V3(R1 * 0.55, yR + 0.47, 0), rotation: simd_quatf(angle: -.pi / 2, axis: .up) * simd_quatf(angle: slope, axis: V3(1, 0, 0))))

        // Steel frame: six legs, top ring of beams, mid bracing, timber dunnage.
        let legs = 6, rl = R0 * 0.82
        var tops: [V3] = []
        for i in 0..<legs {
            let a = Float(i) / Float(legs) * 2 * .pi + .pi / 6
            let base = V3(cos(a) * (rl + 0.25), 0, sin(a) * (rl + 0.25)), top = V3(cos(a) * rl, yF, sin(a) * rl)
            let (s, x) = board(from: base, to: top, width: 0.16, thick: 0.16, up: V3(-sin(a), 0, cos(a)), bevel: 0.006, material: fe)
            both(s, x)
            both(HK.box(V3(0.4, 0.02, 0.4), base + V3(0, 0.01, 0), fe, r: 0.004))
            tops.append(top)
        }
        for i in 0..<legs {
            let a = tops[i], b = tops[(i + 1) % legs]
            let (s, x) = board(from: a, to: b, width: 0.2, thick: 0.12, up: .up, bevel: 0.006, material: fe, extend: 0.05)
            both(s, x)
            // X bracing with rods between the legs.
            let a0 = V3(a.x * 1.1, 0.25, a.z * 1.1), b0 = V3(b.x * 1.1, 0.25, b.z * 1.1)
            m.add(HK.pipe([a0, b - V3(0, 0.15, 0)], r: 0.014, sides: 6, mat: fe))
            m.add(HK.pipe([b0, a - V3(0, 0.15, 0)], r: 0.014, sides: 6, mat: fe))
        }
        // Timber dunnage beams under the tank bottom.
        for k in -2...2 {
            both(HK.box(V3(0.15, 0.2, 2 * R0 - 0.2), V3(Float(k) * 0.6, yF + 0.1, 0), woodMaterial, r: 0.01))
        }
        // Ladder from the deck to the roof edge on +X.
        let lx = R0 + 0.28
        for sz: Float in [-0.22, 0.22] {
            both(HK.box(V3(0.06, yR + 0.1, 0.015), V3(lx, (yR + 0.1) / 2, sz), fe, r: 0.004))
            // Standoff brackets to the hoops.
            for y in [yF + 0.6, yF + 2.0, yR - 0.2] {
                m.add(HK.box(V3(lx - R0 + 0.02, 0.04, 0.012), V3((lx + R0) / 2, y, sz), fe, r: 0.003))
            }
        }
        var y: Float = 0.3
        while y < yR {
            m.add(HK.cyl(r: 0.012, len: 0.44, at: V3(lx, y, 0), axis: V3(0, 0, 1), mat: fe, seg: 8))
            y += 0.3
        }
        // Rising main and overflow from the tank bottom down through the roof.
        m.add(HK.pipe([V3(-0.4, 0.0, 0.4), V3(-0.4, yF + 0.3, 0.4)], r: 0.08, sides: 14, mat: "metal.rust"))
        m.add(HK.pipe([V3(0.5, 0.0, -0.6), V3(0.5, yF + 0.3, -0.6)], r: 0.05, sides: 12, mat: "metal.galvanized-aged"))

        groundAO(&m, height: 0.3, floor: 0.7)
        groundAO(&lite, height: 0.3, floor: 0.7)
        let b = m.bounds
        let c = Xform(translation: V3(-(b.min.x + b.max.x) / 2, 0, -(b.min.z + b.max.z) / 2))
        return LODModel(levels: [m.transformed(c), lite.transformed(c)], switchDistances: [25])
    }
}
