import simd
import Foundation

/// Mobile IV pole (Pryor / Midmark / Blickman class): 5-leg chrome base 63 cm across on 65 mm swivel
/// casters, chrome hub, 25.4 mm white powder-coated outer tube, 19 mm stainless inner pole that
/// telescopes 0.9 m (hook height 1.40-2.30 m), twist-lock collet knob, stainless 2-hook ram's-horn top.
/// A 1 L saline bag (13.5 x 21 cm) hangs on the right hook with a printed label, ports, spike and drip
/// chamber; the line loops down and its end is draped over the left hook. The inner pole slides up,
/// the lock knob turns, the bag (with its set) is an option on the pole.
public struct IvPole: RealArticulated {
    public static let id = "iv-pole"
    public static let summary = "Telescoping IV pole: 5-leg chrome base on casters, powder-coated outer tube, twist lock, stainless 2-hook top and a 1 L IV bag with drip chamber and line."
    public static let tags = ["prop", "medical", "articulated", "hospital", "metal", "plastic"]
    public static let budget = 10200
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 14)

    /// Base radius to the caster centers (m).
    public var baseRadius: Float = 0.27
    /// Outer tube finish.
    public var tubeMaterial: MaterialKey = "metal.powder-white"
    /// Inner pole extension in the high states (m), up to 0.9.
    public var highExtension: Float = 0.9
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [8])
        let chrome: MaterialKey = "metal.chrome", grey: MaterialKey = "plastic.medical-grey"
        let casterH: Float = 0.085, wheelR: Float = 0.0325
        let outerR: Float = 0.0127, innerR: Float = 0.0095
        let outerTop: Float = 1.22, innerBottom: Float = 0.25, hubTop: Float = 1.345
        let yaw0 = rng.float(0...72)

        // MARK: base
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let sg = l == 0 ? 28 : 12
            m.add(Prim.lathe([V2(0.046, 0.083), V2(0.05, 0.092), V2(0.05, 0.104), V2(0.042, 0.124), V2(0.024, 0.15), V2(0.016, 0.162), V2(0.0145, 0.172), V2(0, 0.172)],
                             segments: sg, material: chrome))
            let legProf = Shape2D.roundedRect(0.024, 0.032, radius: l == 0 ? 0.008 : 0.006, segments: l == 0 ? 2 : 1)
            for i in 0..<5 {
                let a = (yaw0 + Float(i) * 72) * .pi / 180
                let d = V3(cos(a), 0, -sin(a))
                let path = [d * 0.035 + V3(0, 0.112, 0), d * 0.15 + V3(0, 0.104, 0), d * (baseRadius + 0.012) + V3(0, casterH + 0.012, 0)]
                m.add(Prim.sweep(legProf, along: path, up: .up, caps: true, material: chrome))
                // Toe cap over the caster stem.
                m.add(Prim.cylinder(radius: 0.017, height: 0.026, bevel: 0.005, segments: l == 0 ? 10 : 6, bevelSegments: 1, material: chrome),
                      Xform(translation: d * baseRadius + V3(0, casterH - 0.002, 0)))
                let cp = d * baseRadius
                // Twin-wheel swivel caster: stem housing, swivel plate, hood, two wheels on a shared axle.
                let cy = rng.float(0...360)
                let cq = simd_quatf(degrees: cy, axis: .up)
                let off = cq.act(V3(0.012, 0, 0))
                let ws = l == 0 ? 10 : 6
                m.add(Prim.cylinder(radius: 0.013, height: 0.012, bevel: 0.002, segments: ws, bevelSegments: 1, material: chrome), Xform(translation: cp + V3(0, casterH - 0.014, 0)))
                m.add(Prim.roundedBox(V3(0.05, 0.026, 0.03), radius: 0.008, bevelSegments: 1, material: grey),
                      Xform(translation: cp + off + V3(0, wheelR + 0.009, 0), rotation: cq))
                let tire: [V2] = [V2(0.008, -0.0095), V2(wheelR - 0.004, -0.0095), V2(wheelR, -0.006), V2(wheelR, 0.006), V2(wheelR - 0.004, 0.0095), V2(0.008, 0.0095)]
                for sz: Float in (l == 0 ? [-1, 1] : [0]) {
                    let wc = cp + off + cq.act(V3(0, 0, sz * 0.0115)) + V3(0, wheelR, 0)
                    let wq = cq * simd_quatf(degrees: 90, axis: V3(1, 0, 0))
                    m.add(Prim.lathe(tire, segments: ws + 2, material: "rubber"), Xform(translation: wc, rotation: wq))
                    if l == 0 {
                        m.add(Prim.lathe([V2(0, -0.0099), V2(0.0082, -0.0099), V2(0.0082, 0.0099), V2(0, 0.0099)], segments: 10, material: grey), Xform(translation: wc, rotation: wq))
                    }
                }
            }
            // Outer tube with a rolled top lip and a chrome base collar.
            m.add(Prim.lathe([V2(outerR, 0.16), V2(outerR, outerTop - 0.004), V2(outerR - 0.0015, outerTop), V2(innerR + 0.0006, outerTop)], segments: l == 0 ? 20 : 10, material: tubeMaterial))
            m.add(Prim.cylinder(radius: outerR + 0.003, height: 0.04, bevel: 0.002, segments: l == 0 ? 20 : 10, bevelSegments: 1, material: chrome),
                  Xform(translation: V3(0, 0.15, 0)))
            // Scuffed kick zone: a slightly darker sleeve where feet hit the tube.
            if l == 0 {
                m.add(Prim.lathe([V2(outerR + 0.0002, 0.2), V2(outerR + 0.0002, 0.32)], segments: 20, material: "metal.powder-white:D6D4CC"))
            }
            rig.base[l] = m
        }

        // MARK: twist-lock collet (part)
        rig.part("lock", pivot: V3(0, outerTop, 0), joint: .hinge(axis: .up, 0...240, duration: 0.6))
        var knob: [V2] = []
        for k in 0..<24 { let a = Float(k) / 24 * 2 * .pi; knob.append(V2(cos(a), sin(a)) * (k % 2 == 0 ? 0.023 : 0.0205)) }
        rig.add(Prim.extrude(Shape2D.rounded(knob, radius: 0.0015, segments: 1), depth: 0.03, bevel: 0.003, bevelSegments: 1, material: grey),
                Xform(translation: V3(0, outerTop - 0.012, 0), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))), to: "lock", lods: 0...0)
        rig.add(Prim.cylinder(radius: 0.022, height: 0.03, bevel: 0.003, segments: 12, bevelSegments: 1, material: grey),
                Xform(translation: V3(0, outerTop - 0.027, 0)), to: "lock", lods: 1...1)
        rig.add(Prim.lathe([V2(0.016, outerTop + 0.003), V2(0.018, outerTop + 0.012), V2(0.012, outerTop + 0.016), V2(innerR + 0.0008, outerTop + 0.016)],
                           segments: 20, material: grey), to: "lock", lods: 0...0)

        // MARK: inner pole with hook top (part)
        rig.part("pole", pivot: V3(0, outerTop, 0), joint: .slide(axis: .up, 0...0.9, duration: 1.4))
        for l in 0..<2 {
            let sg = l == 0 ? 16 : 8
            rig.add(Prim.lathe([V2(innerR, innerBottom), V2(innerR, hubTop - 0.01)], segments: sg, material: "metal.surgical"), to: "pole", lods: l...l)
            // Hook hub, finial and two ram's-horn hooks.
            rig.add(Prim.lathe([V2(0.0125, hubTop - 0.03), V2(0.014, hubTop - 0.026), V2(0.014, hubTop + 0.006), V2(0.011, hubTop + 0.012), V2(0.0075, hubTop + 0.03),
                                V2(0.0105, hubTop + 0.04), V2(0.008, hubTop + 0.052), V2(0, hubTop + 0.055)], segments: sg, material: chrome), to: "pole", lods: l...l)
            for sx: Float in [-1, 1] {
                let path = catmull([V3(0, hubTop - 0.006, 0), V3(sx * 0.03, hubTop - 0.008, 0), V3(sx * 0.07, hubTop - 0.006, 0), V3(sx * 0.092, hubTop + 0.008, 0),
                                    V3(sx * 0.098, hubTop + 0.032, 0), V3(sx * 0.088, hubTop + 0.046, 0), V3(sx * 0.078, hubTop + 0.04, 0)], per: l == 0 ? 4 : 2)
                rig.add(Prim.tube(path, radii: path.map { _ in 0.0042 }, sides: l == 0 ? 8 : 5, seamTile: 0.03, material: chrome), to: "pole", lods: l...l)
                rig.add(Prim.cubeSphere(subdivisions: 2, material: chrome) { $0 * 0.0055 }, Xform(translation: V3(sx * 0.078, hubTop + 0.04, 0)), to: "pole", lods: 0...0)
            }
        }

        // MARK: IV bag and set (option on a fixed part riding the pole)
        rig.part("bag", parent: "pole", pivot: V3(0, outerTop, 0), joint: .fixed, options: 2)
        let hx: Float = 0.072, hy = hubTop - 0.006 - 0.004
        let bw: Float = 0.135, bh: Float = 0.205, bt: Float = 0.036
        let bagTop = hy - 0.03, bagCy = bagTop - bh / 2
        // Hanger tab with the punched hole around the hook.
        var tabOutline: [V2] = Shape2D.roundedRect(0.034, 0.03, radius: 0.006, segments: 2)
        tabOutline = Shape2D.deduped(tabOutline)
        rig.add(Prim.extrude(tabOutline, depth: 0.0012, bevel: 0.0004, bevelSegments: 1, material: "plastic.frosted"),
                Xform(translation: V3(hx, hy - 0.011, 0)), to: "bag", option: 1, lods: 0...0)
        // Filled bag: flattened pillow, thickest low where the fluid sits.
        let pillow = Prim.superellipsoid(V3(bw, bh, bt), exponent: 3.2, subdivisions: 8, material: "plastic.frosted") { d in
            1 - 0.35 * max(0, d.y) * (abs(d.z) > 0.5 ? 1 : 0.3)
        }
        rig.add(pillow, Xform(translation: V3(hx, bagCy, 0)), to: "bag", option: 1, lods: 0...0)
        rig.add(Prim.superellipsoid(V3(bw, bh, bt), exponent: 3.2, subdivisions: 4, material: "plastic.frosted"), Xform(translation: V3(hx, bagCy, 0)), to: "bag", option: 1, lods: 1...1)
        // Fluid body inside the film.
        rig.add(Prim.superellipsoid(V3(bw - 0.012, bh - 0.03, bt - 0.008), exponent: 3, subdivisions: 5, material: "fluid.saline"),
                Xform(translation: V3(hx, bagCy - 0.008, 0)), to: "bag", option: 1, lods: 0...0)
        // Welded seam border around the bag edge.
        rig.add(Prim.extrude(Shape2D.roundedRect(bw + 0.008, bh + 0.008, radius: 0.012, segments: 3), depth: 0.0015, bevel: 0.0005, bevelSegments: 1, material: "plastic.frosted"),
                Xform(translation: V3(hx, bagCy, 0)), to: "bag", option: 1, lods: 0...0)
        // Printed label on the front (bag hangs upside down: text is printed so it reads when hung).
        rig.add(BedsideKit.panel(center: V3(hx, bagCy + 0.005, bt * 0.5 - 0.0035), u: V3(1, 0, 0), v: V3(0, 1, 0), w: 0.092, h: 0.125, material: "label.bedside-iv", vDown: true),
                to: "bag", option: 1)
        // Ports: administration port with spike, injection port with a blue cap.
        let py = bagTop - bh - 0.002
        rig.add(Prim.cylinder(radius: 0.0055, height: 0.03, bevel: 0.001, segments: 10, bevelSegments: 1, material: "plastic.frosted"),
                Xform(translation: V3(hx - 0.022, py - 0.03, 0)), to: "bag", option: 1, lods: 0...0)
        rig.add(Prim.cylinder(radius: 0.0055, height: 0.026, bevel: 0.001, segments: 10, bevelSegments: 1, material: "plastic.frosted"),
                Xform(translation: V3(hx + 0.022, py - 0.026, 0)), to: "bag", option: 1, lods: 0...0)
        rig.add(Prim.cylinder(radius: 0.0068, height: 0.012, bevel: 0.0015, segments: 10, bevelSegments: 1, material: "plastic.medical:2F64B4"),
                Xform(translation: V3(hx + 0.022, py - 0.036, 0)), to: "bag", option: 1, lods: 0...0)
        // Spike, drip chamber (fluid in its lower third), then the line.
        let cx = hx - 0.022, cTop = py - 0.03
        rig.add(Prim.lathe([V2(0.0075, cTop - 0.004), V2(0.0078, cTop + 0.002), V2(0.0058, cTop + 0.004), V2(0.0058, cTop + 0.012)], segments: 12, material: "plastic.medical"),
                Xform(translation: V3(cx, 0, 0)), to: "bag", option: 1, lods: 0...0)
        let chamber: [V2] = [V2(0.0025, cTop - 0.068), V2(0.0065, cTop - 0.062), V2(0.0092, cTop - 0.056), V2(0.0092, cTop - 0.012), V2(0.0078, cTop - 0.004)]
        rig.add(Prim.lathe(chamber, segments: 14, material: "plastic.clear"), Xform(translation: V3(cx, 0, 0)), to: "bag", option: 1, lods: 0...0)
        rig.add(Prim.lathe([V2(0.0025, cTop - 0.0665), V2(0.0063, cTop - 0.061), V2(0.0087, cTop - 0.055), V2(0.0087, cTop - 0.042), V2(0, cTop - 0.042)], segments: 12,
                           material: "fluid.saline"), Xform(translation: V3(cx, 0, 0)), to: "bag", option: 1, lods: 0...0)
        // LOD1: chamber and ports as one frosted stick.
        rig.add(Prim.cylinder(radius: 0.008, height: 0.1, bevel: 0.002, segments: 6, bevelSegments: 1, material: "plastic.frosted"),
                Xform(translation: V3(cx, cTop - 0.068, 0)), to: "bag", option: 1, lods: 1...1)
        // Line: down in a long loop, up and draped over the left hook, end cap hanging.
        let lineStart = V3(cx, cTop - 0.068, 0)
        let loopBottom = hy - 0.78
        var ctrl: [V3] = [lineStart, lineStart + V3(0, -0.06, 0.004), V3(cx - 0.01, lineStart.y - 0.3, 0.03), V3(0.03, loopBottom + 0.04, 0.05), V3(-0.02, loopBottom, 0.052),
                          V3(-0.07, loopBottom + 0.06, 0.04), V3(-0.088, hy - 0.4, 0.02), V3(-0.084, hy - 0.08, 0.01), V3(-0.078, hy - 0.002, 0.0055), V3(-0.07, hy + 0.003, 0.0)]
        ctrl += [V3(-0.06, hy - 0.004, -0.0055), V3(-0.056, hy - 0.05, -0.008), V3(-0.054, hy - 0.11, -0.008)]
        let line = catmull(ctrl, per: 4)
        rig.add(Prim.tube(line, radii: line.map { _ in 0.0021 }, sides: 6, seamTile: 0.013, material: "plastic.frosted", capEnd: false), to: "bag", option: 1, lods: 0...0)
        let lineLite = catmull(ctrl, per: 2)
        rig.add(Prim.tube(lineLite, radii: lineLite.map { _ in 0.0021 }, sides: 4, seamTile: 0.013, material: "plastic.frosted", capEnd: false), to: "bag", option: 1, lods: 1...1)
        // Roller clamp on the descending run and the luer end cap on the draped end.
        let rc = line[min(line.count - 1, 10)]
        rig.add(Prim.roundedBox(V3(0.016, 0.05, 0.014), radius: 0.003, bevelSegments: 1, material: "plastic.medical"), Xform(translation: rc), to: "bag", option: 1, lods: 0...0)
        rig.add(Prim.cylinder(radius: 0.0055, height: 0.006, bevel: 0.001, segments: 10, bevelSegments: 1, material: "plastic.medical:2F64B4"),
                Xform(translation: rc + V3(0.0085, -0.003, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "bag", option: 1, lods: 0...0)
        rig.add(Prim.lathe([V2(0.0024, 0.0), V2(0.0042, 0.002), V2(0.0042, 0.016), V2(0.0032, 0.02), V2(0, 0.02)], segments: 10, material: "plastic.medical"),
                Xform(translation: line.last! + V3(0, -0.018, 0)), to: "bag", option: 1, lods: 0...0)

        groundAO(&rig, height: 0.12, floor: 0.5)
        let hi = min(highExtension, 0.9)
        rig.states = [
            RigState("low", options: ["bag": 1]),
            RigState("high", ["pole": hi]),
            RigState("high-with-bag", ["pole": hi], options: ["bag": 1]),
            RigState("bag-removed", ["lock": 120]),
        ]
        return rig
    }
}
