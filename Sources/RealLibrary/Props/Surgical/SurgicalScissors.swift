import simd
import Foundation

/// Mayo dissecting scissors, 6.75 in (171 mm) curved, German pattern: two mirror-finish blades about
/// 66 mm from the screw, curving 6 mm to one side, hollow-ground shear faces with a bevelled cutting edge
/// and blunt rounded tips; round joint bosses on a slotted pivot screw; offset satin shanks stepping from
/// the blade layers down to two oval finger rings (20 x 17 mm inside, 3.4 mm wire). Lies flat on its
/// lower blade. The upper blade with its ring hinges about the screw axis (Y). Story detail: a blue
/// instrument ID tape band on the lower shank.
public struct SurgicalScissors: RealArticulated {
    public static let id = "surgical-scissors"
    public static let summary = "Mayo dissecting scissors, 6.75 in curved: mirror blades on a slotted pivot screw, satin shanks and oval finger rings."
    public static let tags = ["prop", "medical", "surgical", "handheld", "tool", "metal", "articulated"]
    public static let budget = 4_900
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 18, elevation: 58, distance: 0.32, studio: true)

    /// Blade length from the screw to the tip (m).
    public var bladeLength: Float = 0.066
    /// Lateral curve of the blades at the tip (m); 0 gives straight Mayo scissors.
    public var curve: Float = 0.006
    /// Blade thickness at the joint (m).
    public var bladeThick: Float = 0.0022
    /// Finger ring inner half-axes (m): 20 x 17 mm inside.
    public var ringInner = V2(0.0102, 0.0086)
    public var body: MaterialKey = "metal.surgical"
    public var blades: MaterialKey = "metal.surgical-mirror"
    /// ID tape color (sRGB hex); 0 removes the tape.
    public var tape: UInt32 = 0x1F5BC4
    /// Opening angle of the "open" state (degrees).
    public var openAngle: Float = 28
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [2.5])
        let L = bladeLength, hb = bladeThick, gap: Float = 0.00008
        let yMid = hb + gap / 2
        let wire: Float = 0.0039, ringH: Float = 0.0039
        let ringC = V2(-0.105 + ringInner.x + wire, 0.0158)
        rig.part("upper", pivot: .zero, joint: .hinge(axis: V3(0, 1, 0), 0...openAngle, duration: 0.5))

        // Blade width and thickness along x (joint to tip).
        func width(_ x: Float) -> Float {
            var w: Float = x < 0 ? 0.0085 + (x + 0.0045) / 0.0045 * 0.0013 : (x < 0.008 ? 0.0098 - x / 0.008 * 0.0013 : 0.0085 - (x - 0.008) / (L - 0.016) * 0.0043)
            if x > L - 0.008 { let u = min(1, (x - (L - 0.008)) / 0.008); w *= sqrt(max(0, 1 - u * u)) }
            return max(w, 0.0012)
        }
        func thick(_ x: Float) -> Float { hb - max(0, x) / L * 0.0006 }
        func centerZ(_ x: Float) -> Float { let u = max(0, x) / L; return -curve * u * u }

        for l in 0..<2 {
            let stations = l == 0 ? 24 : 10
            let xs: [Float] = (0...stations).map { k in
                let u = Float(k) / Float(stations)
                return -0.0045 + (L + 0.0045) * (1 - (1 - u) * (1 - u) * 0.35 - 0.65 * (1 - u))
            }
            let path = xs.map { V3($0, 0, centerZ($0)) }
            // Section: flat shear face, bevelled cutting edge, eased spine. Lower blade: edge toward -Z,
            // bevel underneath. Upper blade: mirrored (edge toward +Z, bevel on top).
            func bladeSection(_ x: Float, upper: Bool, edge: Bool) -> [V2] {
                let W = width(x), T = thick(x), r = min(0.0006, T * 0.3), eb = W * 0.34, te: Float = 0.00028
                var p: [V2] = edge
                    ? [V2(W / 2 - eb, 0), V2(W / 2, T - te), V2(W / 2 - 0.00015, T), V2(W / 2 - eb, T)]
                    : [V2(-W / 2 + r, 0), V2(W / 2 - eb, 0), V2(W / 2 - eb, T), V2(-W / 2 + r, T), V2(-W / 2 + r * 0.3, T - r * 0.3),
                       V2(-W / 2, T - r), V2(-W / 2, r), V2(-W / 2 + r * 0.3, r * 0.3)]
                if upper { p = p.map { V2(-$0.x, T - $0.y) } }
                return p
            }
            // Path frame x points to -Z for travel along +X, so section +x is the -Z side. Satin blade
            // body, mirror-polished cutting-edge bevel.
            let lower = SurgKit.loft(path, material: body) { _, i in bladeSection(xs[i], upper: false, edge: false) }
            let lowerEdge = SurgKit.loft(path, material: blades) { _, i in bladeSection(xs[i], upper: false, edge: true) }
            let lift = Xform(translation: V3(0, hb + gap, 0))
            let upperBlade = SurgKit.loft(path, material: body) { _, i in bladeSection(xs[i], upper: true, edge: false) }.transformed(lift)
            let upperEdge = SurgKit.loft(path, material: blades) { _, i in bladeSection(xs[i], upper: true, edge: true) }.transformed(lift)
            rig.base[l].add(lowerEdge)
            rig.add(upperEdge, to: "upper", lods: l...l)
            rig.base[l].add(lower)
            rig.add(upperBlade, to: "upper", lods: l...l)
            // Round joint bosses around the screw.
            let segs = l == 0 ? 24 : 12
            rig.base[l].add(Prim.cylinder(radius: 0.0051, height: hb, bevel: 0.0005, segments: segs, bevelSegments: 1, material: body))
            rig.add(Prim.cylinder(radius: 0.0051, height: hb, bevel: 0.0005, segments: segs, bevelSegments: 1, material: body),
                    Xform(translation: V3(0, hb + gap, 0)), to: "upper", lods: l...l)

            // Shanks: from the blade layer at the joint down to the ring plane, widening to the ring wire.
            for side: Float in [1, -1] {
                let yLayer = side > 0 ? hb + gap + hb / 2 : hb / 2
                let c = V2(ringC.x, side * ringC.y)
                let end = SurgKit.ringPoint(c, y: yMid, rx: ringInner.x, rz: ringInner.y, wire: wire, deg: side * -28)
                let ctrl = [V3(-0.001, yLayer, 0), V3(-0.02, yLayer, side * 0.0022), V3(-0.05, yMid, side * 0.0068), end]
                let sp = SurgKit.catmullPath(ctrl, per: l == 0 ? 6 : 3)
                let shank = SurgKit.bar(sp, w: { t in 0.0064 - 0.0018 * t }, h: { t in hb + (ringH - 0.0003 - hb) * smoothstep(0.25, 0.7, t) },
                                        sides: l == 0 ? 10 : 6, material: body)
                let ring = SurgKit.ring(c, y: yMid, rx: ringInner.x, rz: ringInner.y, wire: wire, thick: ringH,
                                        segments: l == 0 ? 30 : 16, sides: l == 0 ? 10 : 6, material: body)
                if side > 0 { rig.add(shank, to: "upper", lods: l...l); rig.add(ring, to: "upper", lods: l...l) }
                else {
                    rig.base[l].add(shank); rig.base[l].add(ring)
                    if l == 0 && tape != 0 {
                        // ID tape: a 6 mm band wrapped round the lower shank near the ring, seam slightly lifted.
                        let seg = SurgKit.span(sp, x0: -0.052, x1: -0.045, n: 4)
                        do {
                            let band = SurgKit.bar(seg, w: { _ in 0.0052 }, h: { _ in ringH + 0.00018 }, sides: 10,
                                                   material: "plastic.gloss:" + String(format: "%06X", tape))
                            rig.base[0].add(band, Xform(translation: V3(0, 0.00003, 0)).jittered(&rng, deg: 0.4, offset: 0.00005))
                        }
                    }
                }
            }
        }
        // Slotted pivot screw head on the upper blade, flat nut face under the lower one.
        let top = 2 * hb + gap
        rig.add(SurgKit.screwHead(at: V3(0, top - 0.0001, 0), r: 0.0033, h: 0.0007, segments: 18, material: blades), to: "upper")
        rig.add(Prim.roundedBox(V3(0.0052, 0.0005, 0.00045), radius: 0.0001, bevelSegments: 1, material: "metal.steel:2B2C2E"),
                Xform(translation: V3(0, top + 0.00045, 0), rotation: simd_quatf(angle: rng.float(0.2...1.2), axis: V3(0, 1, 0))), to: "upper", lods: 0...0)
        rig.base[0].add(SurgKit.screwHead(at: V3(0, 0.0001, 0), r: 0.003, h: 0.00025, down: true, segments: 16, material: body))

        rig.states = [RigState("closed"), RigState("open", ["upper": openAngle]), RigState("half-open", ["upper": openAngle / 2])]
        SurgKit.settle(&rig)
        return rig
    }
}
