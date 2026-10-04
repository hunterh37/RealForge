import simd
import Foundation

/// Blood glucose meter kit (OneTouch Verio Flex / Accu-Chek Guide class) lying on a table: 88 x 47 x
/// 11.4 mm meter with a white top shell over a grey soft-touch base, segment LCD in a black window,
/// OK button between up/down keys, strip port in the top end; a 34 x 5.6 mm test strip that slides into
/// the port (contacts end grey, sample end with a blue capillary mark, a blood drop in the reading
/// state); a 95 mm pen lancing device beside it with a depth dial, release button and a cap that
/// slides off. LCD options: off / apply-blood prompt / reading 104 mg/dL.
public struct Glucometer: RealArticulated {
    public static let id = "glucometer"
    public static let summary = "Blood glucose meter with sliding test strip, segment LCD showing a reading, three buttons, and a pen lancing device with a removable cap."
    public static let tags = ["prop", "medical", "articulated", "handheld", "electronics", "plastic"]
    public static let budget = 3600
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 18, elevation: 38, distance: 0.32, studio: true)

    /// Reading shown on the LCD (mg/dL).
    public var reading: Int = 104
    /// Base shell color (sRGB hex).
    public var baseColor: UInt32 = 0x5E6B78
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [2])
        let L: Float = 0.088, Wd: Float = 0.047, T: Float = 0.0114
        let ox: Float = -0.02, oz: Float = 0.014              // meter center on the table
        let flat = simd_quatf(degrees: -90, axis: V3(1, 0, 0))  // extrude +Z -> +Y, outline y -> -Z
        let top: MaterialKey = "plastic.medical:F2F2EF", base: MaterialKey = "plastic.medical:" + String(format: "%06X", baseColor)
        let dark: MaterialKey = "plastic.matte:1A1C1E"
        let ink: MaterialKey = "plastic.matte:1B201C"
        let topY: Float = 0.0116          // top shell surface

        for l in 0..<2 {
            var m = Model(name: Self.id)
            let cs = l == 0 ? 5 : 1
            let outline = Shape2D.roundedRect(L, Wd, radius: 0.016, segments: cs)
            m.add(Prim.extrude(outline, depth: 0.0062, bevel: l == 0 ? 0.0022 : 0.0015, bevelSegments: l == 0 ? 2 : 1, material: base),
                  Xform(translation: V3(ox, 0.0031, oz), rotation: flat))
            m.add(Prim.extrude(Shape2D.roundedRect(L - 0.0012, Wd - 0.0012, radius: 0.0155, segments: cs), depth: 0.0056, bevel: l == 0 ? 0.0022 : 0.0015, bevelSegments: l == 0 ? 2 : 1, material: top),
                  Xform(translation: V3(ox, 0.0062 + 0.0026, oz), rotation: flat))
            // LCD window (black bezel) toward the port end.
            m.add(Prim.extrude(Shape2D.roundedRect(0.044, 0.036, radius: 0.004, segments: 2), depth: 0.0006, bevel: 0.0002, bevelSegments: 1, material: dark),
                  Xform(translation: V3(ox + 0.013, topY - 0.0001, oz), rotation: flat))
            // Buttons: round OK between two arrow keys.
            m.add(Prim.cylinder(radius: 0.0068, height: 0.0012, bevel: 0.0005, segments: l == 0 ? 18 : 8, bevelSegments: 1, material: "plastic.medical:3A6EA5"),
                  Xform(translation: V3(ox - 0.026, topY - 0.0003, oz)))
            for sz: Float in [-1, 1] where l == 0 {
                m.add(Prim.extrude(Shape2D.roundedRect(0.008, 0.0095, radius: 0.0025, segments: 1), depth: 0.001, bevel: 0.0004, bevelSegments: 1, material: "plastic.medical:D4D7DA"),
                      Xform(translation: V3(ox - 0.026, topY + 0.0002, oz + sz * 0.0135), rotation: flat))
            }
            // Strip port: dark slot in the top end.
            m.add(Prim.roundedBox(V3(0.003, 0.0026, 0.0085), radius: 0.0008, bevelSegments: 1, material: dark), Xform(translation: V3(ox + L / 2 - 0.0012, 0.0062, oz)))

            // Lancing device: pen body along X beside the meter (cap is a part).
            let lz: Float = -0.033, lr: Float = 0.0085
            let qx = simd_quatf(degrees: -90, axis: V3(0, 0, 1))   // lathe +Y -> +X
            let body: [V2] = [V2(0, -0.05), V2(0.006, -0.0498), V2(0.0072, -0.048), V2(0.0072, -0.036), V2(0.0080, -0.035), V2(lr, -0.033),
                              V2(lr, 0.012), V2(0.0078, 0.014), V2(0.0072, 0.016)]
            m.add(Prim.lathe(body, segments: l == 0 ? 20 : 8, material: "plastic.medical:E9EAEC"), Xform(translation: V3(0.0, lr, lz), rotation: qx))
            // Depth dial ring and the plunger end.
            m.add(Prim.lathe([V2(0.0086, -0.03), V2(0.009, -0.029), V2(0.009, -0.022), V2(0.0086, -0.021)], segments: l == 0 ? 20 : 8, material: base),
                  Xform(translation: V3(0.0, lr, lz), rotation: qx))
            m.add(Prim.lathe([V2(0.0055, -0.06), V2(0.0058, -0.058), V2(0.0058, -0.049)], segments: l == 0 ? 14 : 6, material: base), Xform(translation: V3(0.0, lr, lz), rotation: qx))
            m.add(Prim.lathe([V2(0, -0.0602), V2(0.0055, -0.0601), V2(0.0055, -0.06)], segments: l == 0 ? 14 : 6, material: base), Xform(translation: V3(0.0, lr, lz), rotation: qx))
            // Release button on top.
            m.add(Prim.roundedBox(V3(0.012, 0.004, 0.0055), radius: 0.0018, bevelSegments: 1, material: "plastic.medical:3A6EA5"), Xform(translation: V3(-0.004, 2 * lr - 0.0003, lz)))
            rig.base[l] = m
        }
        // Story detail: the strip vial lying behind the meter, flip lid open, strips showing at the mouth.
        let vr: Float = 0.0135, vq = simd_quatf(degrees: 8, axis: .up) * simd_quatf(degrees: 90, axis: V3(0, 0, 1))   // lathe +Y -> -X
        let vc = V3(0.03, vr, -0.03 - 0.032)
        for l in 0..<2 {
            rig.base[l].add(Prim.lathe([V2(0, 0), V2(vr - 0.001, 0), V2(vr, 0.001), V2(vr, 0.044), V2(vr - 0.0012, 0.045), V2(vr - 0.0012, 0.04)], segments: l == 0 ? 20 : 8,
                                       material: "plastic.medical:E4E6E8"), Xform(translation: vc, rotation: vq))
        }
        let vAxis = vq.act(V3(0, 1, 0))
        rig.base[0].add(BedsideKit.panel(center: vc + vAxis * 0.022 + V3(0, vr + 0.0002, 0), u: vAxis, v: simd_cross(V3(0, 1, 0), vAxis), w: 0.034, h: 0.016,
                                         material: "label.bedside-strips", vDown: true))
        for k in 0..<4 {
            rig.base[0].add(Prim.roundedBox(V3(0.014, 0.0005, 0.0056), radius: 0.0002, bevelSegments: 1, material: "plastic.medical:EDEFF0"),
                            Xform(translation: vc + vAxis * 0.049 + V3(0, -0.0055 + Float(k) * 0.0034, 0), rotation: simd_quatf(degrees: 8 + Float(k) * 5 - 7, axis: .up)))
        }
        // Lid unscrewed and lying upside down beside the mouth.
        let lidP = vc + vAxis * 0.06 + V3(0, -vr, 0.014)
        rig.base[0].add(Prim.cylinder(radius: vr + 0.0008, height: 0.009, bevel: 0.0015, segments: 20, bevelSegments: 1, material: "plastic.medical:5E6B78"), Xform(translation: lidP))
        rig.base[1].add(Prim.cylinder(radius: vr + 0.0008, height: 0.009, bevel: 0.001, segments: 8, bevelSegments: 1, material: "plastic.medical:5E6B78"), Xform(translation: lidP))
        // Depth marks on the dial and a printed maker caption on the meter.
        var marks = Surface(material: ink)
        for k in 0..<5 {
            let a = Float(k - 2) * 0.35
            let n = V3(0, cos(a), sin(a))
            let c = V3(-0.0255, 0.0085, -0.033) + n * 0.00905
            BedsideKit.quad2(&marks, c, V3(1, 0, 0), simd_cross(n, V3(1, 0, 0)), V2(-0.002, -0.0003), V2(0.002, -0.0003), V2(0.002, 0.0003), V2(-0.002, 0.0003))
        }
        marks.computeTangents()
        rig.base[0].add(marks)
        rig.base[0].add(BedsideKit.caption([3, 5], origin: V3(ox - 0.036, topY + 0.0001, oz - 0.012), u: V3(0, 0, 1), v: V3(1, 0, 0), height: 0.0028, material: "plastic.medical:8A9096"))

        // MARK: test strip (slides into the port; option 1 carries the blood drop)
        let portX = ox + L / 2, sy: Float = 0.0062, sL: Float = 0.034, inside: Float = 0.012
        rig.part("strip", pivot: V3(portX, sy, oz), joint: .slide(axis: V3(1, 0, 0), 0...0.012, duration: 0.5), options: 2)
        for opt in 0..<2 {
            let sx0 = portX - inside
            rig.add(Prim.roundedBox(V3(sL, 0.0005, 0.0056), radius: 0.0002, bevelSegments: 1, material: "plastic.medical:EDEFF0"), Xform(translation: V3(sx0 + sL / 2, sy, oz)), to: "strip", option: opt)
            rig.add(Prim.roundedBox(V3(0.009, 0.0002, 0.0044), radius: 0.0001, bevelSegments: 1, material: "metal.surgical"), Xform(translation: V3(sx0 + 0.005, sy + 0.0003, oz)), to: "strip", option: opt, lods: 0...0)
            rig.add(Prim.roundedBox(V3(0.003, 0.0002, 0.0056), radius: 0.0001, bevelSegments: 1, material: "plastic.medical:2F64B4"), Xform(translation: V3(sx0 + sL - 0.0022, sy + 0.0003, oz)), to: "strip", option: opt, lods: 0...0)
        }
        for l in 0..<2 {
            rig.add(Prim.superellipsoid(V3(0.0042, 0.0022, 0.0042), exponent: 2, subdivisions: l == 0 ? 4 : 1, material: "fluid.bedside-blood"),
                    Xform(translation: V3(portX - inside + sL - 0.0006, sy + 0.0008, oz)), to: "strip", option: 1, lods: l...l)
        }

        // MARK: LCD (off / apply blood / reading)
        let lcdC = V3(ox + 0.013, topY + 0.0006, oz)
        rig.part("lcd", pivot: lcdC, joint: .fixed, options: 3)
        let uL = V3(0, 0, 1), vL = V3(1, 0, 0)   // read with the port end up
        rig.add(BedsideKit.panel(center: lcdC, u: uL, v: vL, w: 0.032, h: 0.038, material: "screen.bedside-lcd-off"), to: "lcd")
        for opt in 1...2 { rig.add(BedsideKit.panel(center: lcdC, u: uL, v: vL, w: 0.032, h: 0.038, material: "screen.bedside-lcd-on"), to: "lcd", option: opt) }
        let txt0 = lcdC + V3(0, 0.0002, 0)
        var prompt = BedsideKit.segments("- -", origin: txt0 + uL * -0.012 + vL * -0.004, u: uL, v: vL, height: 0.011, stroke: 0.14, material: ink)
        // Blood-drop prompt icon.
        BedsideKit.quad2(&prompt, txt0 + vL * 0.011, uL, vL, V2(0, 0.004), V2(0.0025, -0.001), V2(0, -0.0035), V2(-0.0025, -0.001))
        prompt.computeTangents()
        rig.add(prompt, to: "lcd", option: 1, lods: 0...0)
        var value = BedsideKit.segments(String(reading), origin: txt0 + uL * -0.013 + vL * -0.008, u: uL, v: vL, height: 0.013, stroke: 0.14, material: ink)
        value.append(BedsideKit.caption([5], origin: txt0 + uL * 0.002 + vL * -0.0135, u: uL, v: vL, height: 0.003, material: ink))
        value.append(BedsideKit.segments("10:42", origin: txt0 + uL * -0.013 + vL * 0.011, u: uL, v: vL, height: 0.004, stroke: 0.16, material: ink))
        rig.add(value, to: "lcd", option: 2, lods: 0...0)
        rig.lights = [RigLight(name: "lcd-glow", kind: .point, part: "lcd", option: 2, position: lcdC + V3(0, 0.03, 0), color: V3(0.6, 0.85, 0.7), intensity: 1, attenuationRadius: 0.15)]

        // MARK: lancing device cap (slides off the front end)
        let capR: Float = 0.0083
        rig.part("cap", pivot: V3(0.012, 0.0085, -0.033), joint: .slide(axis: V3(1, 0, 0), 0...0.022, duration: 0.4))
        let qx = simd_quatf(degrees: -90, axis: V3(0, 0, 1))
        for l in 0..<2 {
            rig.add(Prim.lathe([V2(0.0066, 0.034), V2(0.0066, 0.0124), V2(0.0072, 0.0118), V2(capR, 0.012), V2(capR, 0.034), V2(0.0072, 0.0365), V2(0.0035, 0.0375), V2(0, 0.0376)], segments: l == 0 ? 20 : 8,
                               material: "plastic.medical:B8C4CF"), Xform(translation: V3(0, 0.0085, -0.033), rotation: qx), to: "cap", lods: l...l)
        }
        _ = rng.float()

        groundAO(&rig, height: 0.006, floor: 0.6)
        rig.states = [
            RigState("off", ["strip": 0.012]),
            RigState("strip-in", options: ["lcd": 1]),
            RigState("reading", ["cap": 0.022], options: ["lcd": 2, "strip": 1]),
        ]
        rig.defaultState = "reading"
        return rig
    }
}
