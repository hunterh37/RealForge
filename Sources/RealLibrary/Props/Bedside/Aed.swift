import simd
import Foundation

/// Public-access automated external defibrillator (ZOLL AED Plus / Philips HeartStart class) lying in
/// its use position: 241 x 133 x 292 mm green molded case on a dark rubber bumper band, carry handle
/// molded at the back, flip-up lid hinged at the back with the CPR pictogram on its underside. Under
/// the lid: dark grey control deck with a status LCD, a flashing shock button with its lightning
/// glyph, the on/off button, speaker grille, readiness indicator, pads socket and the sealed electrode
/// pad package in its tray. The lid swings up; pads are an option (stowed pack / both pads out on
/// the floor with their cables); the LCD and shock lamp are options with a small glow.
public struct Aed: RealArticulated {
    public static let id = "aed"
    public static let summary = "Automated external defibrillator: molded green case with carry handle, flip-up lid stowing electrode pads, status LCD, shock button and speaker."
    public static let tags = ["prop", "medical", "articulated", "handheld", "electronics", "hospital", "plastic"]
    public static let budget = 6700
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 26, elevation: 30, studio: true)

    /// Case color (sRGB hex).
    public var caseColor: UInt32 = 0x4F7D33
    /// Lid opening angle (degrees).
    public var lidOpen: Float = 105
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3.5])
        let shell: MaterialKey = "plastic.medical:" + String(format: "%06X", caseColor)
        let deck: MaterialKey = "plastic.medical-grey:4A4F52", bumper: MaterialKey = "rubber.tubing:2C2F31", dark: MaterialKey = "plastic.matte:1E2022"
        let W: Float = 0.241, bodyH: Float = 0.1, z0: Float = -0.11, z1: Float = 0.146
        let D = z1 - z0, zc = (z0 + z1) / 2
        let topY = bodyH + 0.0125

        for l in 0..<2 {
            var m = Model(name: Self.id)
            let bs = l == 0 ? 3 : 1
            m.add(Prim.roundedBox(V3(W, bodyH - 0.006, D), radius: 0.022, bevelSegments: bs, material: shell), Xform(translation: V3(0, 0.006 + (bodyH - 0.006) / 2, zc)))
            // Rubber bumper band around the base.
            m.add(Prim.roundedBox(V3(W + 0.006, 0.028, D + 0.006), radius: 0.012, bevelSegments: l == 0 ? 2 : 1, material: bumper), Xform(translation: V3(0, 0.014, zc)))
            // Rim walls around the recessed deck (the lid closes onto them).
            for (sz, w, d) in [(z0 + 0.012, W - 0.01, Float(0.01)), (z1 - 0.006, W - 0.01, Float(0.01))] as [(Float, Float, Float)] {
                m.add(Prim.roundedBox(V3(w, 0.016, d), radius: 0.004, bevelSegments: 1, material: shell), Xform(translation: V3(0, bodyH + 0.004, sz)))
            }
            for sx: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(0.01, 0.016, D - 0.012), radius: 0.004, bevelSegments: 1, material: shell), Xform(translation: V3(sx * (W / 2 - 0.006), bodyH + 0.004, zc + 0.003)))
            }
            // Rubber corner guards.
            for sx: Float in [-1, 1] { for zz in [z0 + 0.009, z1 - 0.009] where l == 0 {
                m.add(Prim.roundedBox(V3(0.034, 0.088, 0.034), radius: 0.013, bevelSegments: 1, material: bumper),
                      Xform(translation: V3(sx * (W / 2 - 0.009), 0.046, zz)))
            }}
            // Control deck.
            m.add(Prim.roundedBox(V3(W - 0.02, 0.006, 0.236), radius: 0.003, bevelSegments: 1, material: deck), Xform(translation: V3(0, bodyH - 0.001, 0.02)))
            // Carry handle at the back.
            let hp = catmull([V3(-0.085, 0.07, z0 + 0.008), V3(-0.08, 0.07, z0 - 0.026), V3(-0.055, 0.07, z0 - 0.034), V3(0.055, 0.07, z0 - 0.034),
                              V3(0.08, 0.07, z0 - 0.026), V3(0.085, 0.07, z0 + 0.008)], per: l == 0 ? 4 : 2)
            m.add(Prim.sweep(Shape2D.roundedRect(0.03, 0.016, radius: 0.007, segments: l == 0 ? 2 : 1), along: hp, up: .up, material: shell))
            // Lid hinge knuckles at the back of the deck.
            for sx: Float in [-0.075, 0.075] {
                m.add(Prim.cylinder(radius: 0.007, height: 0.03, bevel: 0.002, segments: l == 0 ? 12 : 6, bevelSegments: 1, material: shell),
                      Xform(translation: V3(sx - 0.015, topY + 0.006, z0 + 0.012), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
            }
            rig.base[l] = m
        }
        // Deck controls.
        let dy = bodyH + 0.002
        let qUp = simd_quatf(degrees: 0, axis: .up)
        _ = qUp
        // Shock button: raised orange dome in a dark ring, lightning glyph on the lamp option.
        let shockC = V3(0.055, dy, 0.07)
        rig.base[0].add(Prim.cylinder(radius: 0.022, height: 0.003, bevel: 0.001, segments: 20, bevelSegments: 1, material: dark), Xform(translation: shockC))
        rig.base[1].add(Prim.cylinder(radius: 0.022, height: 0.003, bevel: 0.001, segments: 10, bevelSegments: 1, material: dark), Xform(translation: shockC))
        // On/off button, readiness window, speaker grille, pads socket, pictogram label.
        for l in 0..<2 {
            rig.base[l].add(Prim.cylinder(radius: 0.011, height: 0.006, bevel: 0.002, segments: l == 0 ? 16 : 8, bevelSegments: 1, material: "plastic.medical:3E8E4A"),
                            Xform(translation: V3(-0.085, dy, 0.11)))
            rig.base[l].add(Prim.roundedBox(V3(0.07, 0.003, 0.046), radius: 0.003, bevelSegments: 1, material: dark), Xform(translation: V3(-0.055, dy + 0.0015, 0.04)))
        }
        var grille = Surface(material: dark)
        for i in 0..<5 { for j in 0..<5 {
            grille.append(Prim.cylinder(radius: 0.0018, height: 0.0012, bevel: 0, segments: 6, bevelSegments: 1, material: dark),
                          Xform(translation: V3(-0.095 + Float(i) * 0.008, dy + 0.0003, -0.085 + Float(j) * 0.008)))
        }}
        rig.base[0].add(grille)
        rig.base[0].add(Prim.roundedBox(V3(0.012, 0.004, 0.008), radius: 0.0015, bevelSegments: 1, material: "emissive.led-green"), Xform(translation: V3(-0.06, dy + 0.001, 0.08)))
        rig.base[0].add(Prim.roundedBox(V3(0.03, 0.01, 0.016), radius: 0.003, bevelSegments: 1, material: dark), Xform(translation: V3(0.098, dy + 0.004, -0.085)))
        rig.base[0].add(BedsideKit.panel(center: V3(0.0, dy + 0.0016, 0.122), u: V3(1, 0, 0), v: V3(0, 0, -1), w: 0.13, h: 0.026, material: "label.bedside-aed", vDown: true))
        // Pads tray recess.
        rig.base[0].add(Prim.roundedBox(V3(0.13, 0.002, 0.094), radius: 0.004, bevelSegments: 1, material: dark), Xform(translation: V3(0.035, dy + 0.0005, -0.04)))

        // MARK: lid (hinged at the back, swings up)
        let pivot = V3(0, topY + 0.006, z0 + 0.012)
        rig.part("lid", pivot: pivot, joint: .hinge(axis: V3(1, 0, 0), -lidOpen...0, duration: 0.8))
        for l in 0..<2 {
            let lid = Prim.roundedBox(V3(W - 0.004, 0.022, D - 0.004), radius: 0.01, bevelSegments: l == 0 ? 3 : 1, material: shell)
            rig.add(lid, Xform(translation: V3(0, topY + 0.011, zc)), to: "lid", lods: l...l)
        }
        rig.add(Prim.roundedBox(V3(0.03, 0.006, 0.03), radius: 0.003, bevelSegments: 1, material: shell), Xform(translation: V3(0, topY + 0.004, z1 + 0.002)), to: "lid")
        // CPR pictogram on the lid underside, and the "AED" mark on top.
        rig.add(BedsideKit.panel(center: V3(0, topY - 0.0004, 0.03), u: V3(1, 0, 0), v: V3(0, 0, 1), w: 0.17, h: 0.15, material: "label.bedside-aed-cpr", vDown: true), to: "lid", lods: 0...0)
        // Lid logo: red heart with a white lightning bolt (molded inlay), white "AED" lettering below.
        let lidTop = topY + 0.0222
        var heart: [V2] = []
        for k in 0..<28 {
            let t = Float(k) / 28 * 2 * .pi
            let x = 16 * pow(sin(t), 3), y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
            heart.append(V2(x, y) * 0.0021)
        }
        let flatUp = simd_quatf(degrees: -90, axis: V3(1, 0, 0))   // extrude +Z -> +Y, outline y -> -Z
        let logo = V3(0, lidTop + 0.0006, zc - 0.01)
        rig.add(Prim.extrude(Shape2D.deduped(heart), depth: 0.0012, bevel: 0.0004, bevelSegments: 1, material: "plastic.medical:C4261C"), Xform(translation: logo, rotation: flatUp), to: "lid")
        let bolt2: [V2] = [V2(-0.004, 0.022), V2(0.009, 0.022), V2(0.002, 0.004), V2(0.01, 0.004), V2(-0.007, -0.024), V2(-0.002, -0.004), V2(-0.01, -0.004)]
        rig.add(Prim.extrude(bolt2, depth: 0.0006, bevel: 0, material: "plastic.medical:F4F2EA"), Xform(translation: logo + V3(0, 0.0008, 0), rotation: flatUp), to: "lid", lods: 0...0)
        rig.add(BedsideKit.segments("AE", origin: V3(-0.022, lidTop + 0.0002, zc + 0.075), u: V3(1, 0, 0), v: V3(0, 0, -1), height: 0.018, stroke: 0.18, shear: 0,
                                    material: "plastic.medical:F2F2EE"), to: "lid", lods: 0...0)
        var dGlyph = Surface(material: "plastic.medical:F2F2EE")
        let dO = V3(0.009, lidTop + 0.0002, zc + 0.075), u = V3(1, 0, 0), v = V3(0, 0, -1), st: Float = 0.0032
        BedsideKit.bar(&dGlyph, dO, u, v, 0, 0, st, 0.018)
        BedsideKit.bar(&dGlyph, dO, u, v, st, 0, 0.007, st); BedsideKit.bar(&dGlyph, dO, u, v, st, 0.018 - st, 0.007, 0.018)
        BedsideKit.quad2(&dGlyph, dO, u, v, V2(0.007, 0), V2(0.0105, 0.004), V2(0.0105 - st, 0.004 + st * 0.3), V2(0.007, st))
        BedsideKit.bar(&dGlyph, dO, u, v, 0.0105 - st, 0.004, 0.0105, 0.014)
        BedsideKit.quad2(&dGlyph, dO, u, v, V2(0.0105 - st, 0.014 - st * 0.3), V2(0.0105, 0.014), V2(0.007, 0.018), V2(0.007, 0.018 - st))
        dGlyph.computeTangents()
        rig.add(dGlyph, to: "lid", lods: 0...0)

        // Story detail: monthly inspection tag tied to the handle, lying on the floor behind the unit.
        let tagC = V3(0.05, 0.0012, z0 - 0.075)
        let tq = simd_quatf(degrees: rng.float(18...30), axis: .up)
        rig.base[0].add(Prim.roundedBox(V3(0.05, 0.0008, 0.085), radius: 0.0003, bevelSegments: 1, material: "plastic.medical:F1EEDC"), Xform(translation: tagC, rotation: tq))
        rig.base[0].add(BedsideKit.panel(center: tagC + V3(0, 0.0005, 0), u: tq.act(V3(1, 0, 0)), v: tq.act(V3(0, 0, -1)), w: 0.044, h: 0.07, material: "label.bedside-tag", vDown: true))
        let tagTop = tagC + tq.act(V3(0, 0, -0.04))
        let string = catmull([V3(0.055, 0.07, z0 - 0.034), V3(0.056, 0.03, z0 - 0.045), V3(0.054, 0.002, tagTop.z + 0.008), tagTop + V3(0, 0.0012, 0)], per: 4)
        rig.base[0].add(Prim.tube(string, radii: string.map { _ in 0.0008 }, sides: 4, seamTile: 0.01, material: "plastic.matte:B8352A", capEnd: false))
        rig.base[1].add(Prim.roundedBox(V3(0.05, 0.0008, 0.085), radius: 0.0003, bevelSegments: 1, material: "plastic.medical:F1EEDC"), Xform(translation: tagC, rotation: tq))

        // MARK: pads (stowed pack / out on the floor)
        rig.part("pads", pivot: V3(0.035, dy, -0.04), joint: .fixed, options: 2)
        rig.add(Prim.superellipsoid(V3(0.12, 0.012, 0.085), exponent: 5, subdivisions: 4, material: "plastic.medical:D9DDE2"), Xform(translation: V3(0.035, dy + 0.006, -0.04)), to: "pads", option: 0)
        rig.add(BedsideKit.panel(center: V3(0.035, dy + 0.0122, -0.04), u: V3(1, 0, 0), v: V3(0, 0, -1), w: 0.09, h: 0.06, material: "label.bedside-pads", vDown: true), to: "pads", option: 0, lods: 0...0)
        let stub = catmull([V3(0.098, dy + 0.005, -0.085), V3(0.098, dy + 0.012, -0.07), V3(0.09, dy + 0.012, -0.045)], per: 3)
        rig.add(Prim.tube(stub, radii: stub.map { _ in 0.0025 }, sides: 6, seamTile: 0.02, material: "rubber.tubing:5A5E62", capEnd: true), to: "pads", option: 0)
        // Out: both pads face down on the floor in front with cables over the front edge.
        let padCenters: [(V3, Float)] = [(V3(-0.075, 0.0016, z1 + 0.11), rng.float(-14 ... -6)), (V3(0.085, 0.0016, z1 + 0.13), rng.float(8...16))]
        for (c, yaw) in padCenters {
            let q = simd_quatf(degrees: yaw, axis: .up)
            rig.add(Prim.extrude(Shape2D.roundedRect(0.125, 0.155, radius: 0.025, segments: 3), depth: 0.003, bevel: 0.001, bevelSegments: 1, material: "plastic.medical:EDEDEA"),
                    Xform(translation: c, rotation: q * simd_quatf(degrees: -90, axis: V3(1, 0, 0))), to: "pads", option: 1)
            rig.add(BedsideKit.panel(center: c + V3(0, 0.0016, 0), u: q.act(V3(1, 0, 0)), v: q.act(V3(0, 0, -1)), w: 0.1, h: 0.13, material: "label.bedside-pads", vDown: true), to: "pads", option: 1, lods: 0...0)
        }
        let socket = V3(0.098, dy + 0.009, -0.085)
        for (i, (c, _)) in padCenters.enumerated() {
            let side: Float = i == 0 ? -1 : 1
            let path = catmull([socket, socket + V3(0, 0.01, 0.02), V3(0.05 + side * 0.02, dy + 0.012, 0.06), V3(0.03 + side * 0.03, dy + 0.008, z1 + 0.008),
                                V3(0.025 + side * 0.035, 0.05, z1 + 0.025), V3(c.x * 0.5, 0.0026, z1 + 0.05), c + V3(0, 0.0045, -0.07)], per: l0Per)
            rig.add(Prim.tube(path, radii: path.map { _ in 0.0025 }, sides: 6, seamTile: 0.02, material: "rubber.tubing:5A5E62", capEnd: true), to: "pads", option: 1)
        }

        // MARK: LCD and shock lamp
        let lcdC = V3(-0.055, dy + 0.0032, 0.04)
        rig.part("lcd", pivot: lcdC, joint: .fixed, options: 2)
        rig.add(BedsideKit.panel(center: lcdC, u: V3(1, 0, 0), v: V3(0, 0, -1), w: 0.062, h: 0.038, material: "screen.off"), to: "lcd")
        rig.add(BedsideKit.panel(center: lcdC, u: V3(1, 0, 0), v: V3(0, 0, -1), w: 0.062, h: 0.038, material: "screen.lcd"), to: "lcd", option: 1)
        var lcdText = BedsideKit.caption([4, 3], origin: lcdC + V3(-0.026, 0.0002, -0.006), u: V3(1, 0, 0), v: V3(0, 0, -1), height: 0.006, material: "plastic.matte:1A1C1A")
        lcdText.append(BedsideKit.segments("0:12", origin: lcdC + V3(-0.026, 0.0002, 0.013), u: V3(1, 0, 0), v: V3(0, 0, -1), height: 0.008, material: "plastic.matte:1A1C1A"))
        lcdText.append(BedsideKit.caption([2, 5], origin: lcdC + V3(0.004, 0.0002, 0.013), u: V3(1, 0, 0), v: V3(0, 0, -1), height: 0.004, material: "plastic.matte:1A1C1A"))
        rig.add(lcdText, to: "lcd", option: 1)
        rig.part("shock", pivot: shockC, joint: .fixed, options: 2)
        for (opt, mat) in [(0, "plastic.medical:C2541C"), (1, "emissive.bedside-shock")] as [(Int, MaterialKey)] {
            rig.add(Prim.lathe([V2(0.0175, 0.002), V2(0.0175, 0.006), V2(0.014, 0.0085), V2(0.007, 0.0098), V2(0, 0.01)], segments: 18, material: mat),
                    Xform(translation: shockC), to: "shock", option: opt)
        }
        var bolt = Surface(material: "plastic.medical:F4F2EA")
        let bo = shockC + V3(0, 0.0102, 0)
        BedsideKit.quad2(&bolt, bo, V3(1, 0, 0), V3(0, 0, -1), V2(-0.002, 0.009), V2(0.005, 0.009), V2(0.001, 0.001), V2(-0.004, 0.001))
        BedsideKit.quad2(&bolt, bo, V3(1, 0, 0), V3(0, 0, -1), V2(-0.001, 0.002), V2(0.004, 0.002), V2(0.002, -0.009), V2(0.002, -0.009))
        bolt.computeTangents()
        rig.add(bolt, to: "shock", option: 0, lods: 0...0)
        rig.add(bolt, to: "shock", option: 1, lods: 0...0)
        rig.lights = [
            RigLight(name: "shock-lamp", kind: .point, part: "shock", option: 1, position: shockC + V3(0, 0.04, 0), color: V3(1, 0.55, 0.2), intensity: 4, attenuationRadius: 0.3),
            RigLight(name: "lcd-glow", kind: .point, part: "lcd", option: 1, position: lcdC + V3(0, 0.05, 0), color: V3(0.6, 0.85, 0.7), intensity: 2, attenuationRadius: 0.25),
        ]

        groundAO(&rig, height: 0.03, floor: 0.55)
        rig.states = [
            RigState("closed"),
            RigState("open", ["lid": -lidOpen]),
            RigState("pads-out", ["lid": -lidOpen], options: ["pads": 1]),
            RigState("analyzing", ["lid": -lidOpen], options: ["pads": 1, "lcd": 1, "shock": 1]),
        ]
        rig.defaultState = "open"
        return rig
    }

    private var l0Per: Int { 4 }
}
