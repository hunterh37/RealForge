import simd
import Foundation

/// Large-volume infusion pump (Alaris GP / B. Braun Infusomat class) standing on its feet: white
/// molded housing 145 x 231 x 150 mm with a grey front bezel, molded carry handle, 3.5 in display,
/// soft keys and a key column (start, stop, arrows, power) with run and alarm LEDs; lower front door
/// hinged on the left over the peristaltic pumping segment (fingers, pressure sensor) with a blue latch
/// lever; clear administration set threaded through the channel with a blue free-flow clip; rear cast
/// pole clamp with a T-handle clamp screw. The door swings open, the clamp screw slides, the display
/// and LEDs are options with a faint screen light.
public struct InfusionPump: RealArticulated {
    public static let id = "infusion-pump"
    public static let summary = "Large-volume infusion pump channel: grey housing, LCD with keypad, hinged door over the pumping segment, tubing set, rear pole clamp with screw."
    public static let tags = ["prop", "medical", "articulated", "electronics", "hospital", "plastic"]
    public static let budget = 8200
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 16, studio: true)

    /// Housing plastic.
    public var housing: MaterialKey = "plastic.medical"
    /// Front bezel and door plastic.
    public var bezel: MaterialKey = "plastic.medical-grey"
    /// Rate shown on the display (mL/h).
    public var rate: Int = 125
    /// Door opening angle (degrees).
    public var doorOpen: Float = 100
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3.5])
        let W: Float = 0.145, H: Float = 0.225, D: Float = 0.15, foot: Float = 0.006
        let y0 = foot, zf = D / 2, cy = y0 + H / 2
        let dark: MaterialKey = "plastic.matte:2A2C2E", keyMat: MaterialKey = "plastic.medical:D9DBDA", door: MaterialKey = "plastic.medical-grey:8C9399"
        let flat = simd_quatf(degrees: 0, axis: .up)
        _ = flat

        for l in 0..<2 {
            var m = Model(name: Self.id)
            let bs = l == 0 ? 3 : 1
            m.add(Prim.roundedBox(V3(W, H, D), radius: 0.012, bevelSegments: bs, material: housing), Xform(translation: V3(0, cy, 0)))
            // Grey front bezel over the upper third (display and keys).
            m.add(Prim.roundedBox(V3(W - 0.008, 0.078, 0.006), radius: 0.0025, bevelSegments: l == 0 ? 2 : 1, material: bezel),
                  Xform(translation: V3(0, y0 + H - 0.046, zf - 0.0015)))
            // Pumping-mechanism recess plate behind the door.
            m.add(Prim.roundedBox(V3(0.118, 0.106, 0.004), radius: 0.004, bevelSegments: 1, material: dark), Xform(translation: V3(0, y0 + 0.078, zf - 0.0005)))
            // Carry handle: molded bar arching over the top.
            let hp = catmull([V3(-0.052, y0 + H - 0.004, -0.01), V3(-0.046, y0 + H + 0.024, -0.01), V3(0, y0 + H + 0.03, -0.01), V3(0.046, y0 + H + 0.024, -0.01),
                              V3(0.052, y0 + H - 0.004, -0.01)], per: l == 0 ? 4 : 2)
            m.add(Prim.sweep(Shape2D.roundedRect(0.026, 0.012, radius: 0.005, segments: l == 0 ? 2 : 1), along: hp, up: V3(0, 0, 1), caps: true, material: housing))
            // Rubber feet.
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                m.add(Prim.cylinder(radius: 0.009, height: foot + 0.001, bevel: 0.0015, segments: l == 0 ? 12 : 6, bevelSegments: 1, material: "rubber"),
                      Xform(translation: V3(sx * (W / 2 - 0.018), 0, sz * (D / 2 - 0.02))))
            }}
            // Rear pole clamp: cast block with a vertical V-jaw.
            let clampMat: MaterialKey = "metal.powder-white:B9BCBE"
            m.add(Prim.roundedBox(V3(0.07, 0.07, 0.03), radius: 0.006, bevelSegments: l == 0 ? 2 : 1, material: clampMat), Xform(translation: V3(-0.005, y0 + 0.15, -zf - 0.013)))
            m.add(Prim.roundedBox(V3(0.018, 0.07, 0.04), radius: 0.005, bevelSegments: 1, material: clampMat), Xform(translation: V3(-0.034, y0 + 0.15, -zf - 0.046)))
            m.add(Prim.roundedBox(V3(0.018, 0.07, 0.016), radius: 0.004, bevelSegments: 1, material: clampMat), Xform(translation: V3(0.024, y0 + 0.15, -zf - 0.034)))
            if l == 0 {
                // Vent slots on the left side, rating and asset labels on the right.
                for k in 0..<7 {
                    m.add(Prim.roundedBox(V3(0.002, 0.004, 0.05), radius: 0.0015, bevelSegments: 1, material: dark),
                          Xform(translation: V3(-W / 2 + 0.0004, y0 + 0.13 + Float(k) * 0.009, -0.02)))
                }
                m.add(BedsideKit.panel(center: V3(W / 2 + 0.0003, y0 + 0.07, -0.02), u: V3(0, 0, -1), v: V3(0, 1, 0), w: 0.06, h: 0.04, material: "label.bedside-asset", vDown: true))
                m.add(BedsideKit.panel(center: V3(W / 2 + 0.0003, y0 + 0.16, 0.03), u: V3(0, 0, -1), v: V3(0, 1, 0), w: 0.034, h: 0.016, material: "label.bedside-cuff", vDown: true))
                // Scuffed lower front edge where the door is kicked and the set rubs.
                m.add(Prim.roundedBox(V3(W - 0.03, 0.004, 0.003), radius: 0.001, bevelSegments: 1, material: "plastic.medical:C9C6BC"),
                      Xform(translation: V3(0, y0 + 0.012, zf + 0.0004)))
            }
            // Keys: three soft keys under the display, a column of five on the right.
            let kz = zf + 0.0015
            var keys = Surface(material: keyMat)
            for k in 0..<3 {
                keys.append(Prim.roundedBox(V3(0.018, 0.007, 0.004), radius: 0.0018, bevelSegments: 1, material: keyMat),
                            Xform(translation: V3(-0.052 + Float(k) * 0.024, y0 + H - 0.077, kz)))
            }
            let colKeys: [(Float, MaterialKey)] = [(0.0, "plastic.medical:3E8E4A"), (1, "plastic.medical:B23A2E"), (2, keyMat), (3, keyMat)]
            for (i, mat) in colKeys {
                let s = Prim.roundedBox(V3(0.02, 0.011, 0.005), radius: 0.0025, bevelSegments: 1, material: mat)
                let x = Xform(translation: V3(0.05, y0 + H - 0.022 - i * 0.0145, kz))
                if mat == keyMat { keys.append(s, x) } else { m.add(s, x) }
            }
            m.add(keys)
            // Arrow glyphs on the up/down keys and the power key ring.
            if l == 0 {
                var glyph = Surface(material: dark)
                for (i, up) in [(2, true), (3, false)] as [(Float, Bool)] {
                    let c = V3(0.05, y0 + H - 0.022 - i * 0.0145, kz + 0.0026)
                    let s: Float = up ? 1 : -1
                    BedsideKit.quad2(&glyph, c, V3(1, 0, 0), V3(0, 1, 0), V2(-0.003, -0.0018 * s), V2(0.003, -0.0018 * s), V2(0.0002, 0.0022 * s), V2(-0.0002, 0.0022 * s))
                }
                glyph.computeTangents()
                m.add(glyph)
            }
            // Display bezel window.
            m.add(Prim.roundedBox(V3(0.084, 0.052, 0.002), radius: 0.002, bevelSegments: 1, material: dark), Xform(translation: V3(-0.016, y0 + H - 0.04, zf + 0.0012)))
            rig.base[l] = m
        }

        // MARK: tubing set through the pumping channel (fixed)
        let tubeX: Float = -0.004, tz = zf + 0.0036
        let tr: Float = 0.0021
        let setPath = catmull([V3(-0.1, tr, 0.07), V3(-0.086, tr, 0.06), V3(-0.084, 0.03, 0.055), V3(-0.08, y0 + 0.125, 0.06), V3(-0.05, y0 + 0.139, tz + 0.005),
                               V3(tubeX, y0 + 0.136, tz), V3(tubeX, y0 + 0.08, tz), V3(tubeX, y0 + 0.02, tz), V3(tubeX + 0.002, 0.004, tz + 0.016), V3(0.02, tr, 0.104), V3(0.065, tr, 0.11)], per: 4)
        for l in 0..<2 {
            let p = l == 0 ? setPath : stride(from: 0, to: setPath.count, by: 2).map { setPath[$0] } + [setPath.last!]
            rig.base[l].add(Prim.tube(p, radii: p.map { _ in tr }, sides: l == 0 ? 6 : 4, seamTile: 0.013, material: "plastic.frosted", capEnd: false))
        }
        // Anti-free-flow clip on the set below the door and pumping fingers behind it.
        rig.base[0].add(Prim.roundedBox(V3(0.016, 0.01, 0.008), radius: 0.002, bevelSegments: 1, material: "plastic.medical:2F64B4"), Xform(translation: V3(tubeX, y0 + 0.024, tz)))
        rig.base[1].add(Prim.roundedBox(V3(0.016, 0.01, 0.008), radius: 0.002, bevelSegments: 1, material: "plastic.medical:2F64B4"), Xform(translation: V3(tubeX, y0 + 0.024, tz)))
        var fingers = Surface(material: "metal.surgical")
        for k in 0..<12 {
            fingers.append(Prim.roundedBox(V3(0.012, 0.004, 0.003), radius: 0.0008, bevelSegments: 1, material: "metal.surgical"),
                           Xform(translation: V3(tubeX, y0 + 0.05 + Float(k) * 0.0052, zf + 0.0012 + 0.0008 * sin(Float(k) * 0.9))))
        }
        rig.base[0].add(fingers)
        rig.base[0].add(Prim.cylinder(radius: 0.006, height: 0.002, bevel: 0.0006, segments: 12, bevelSegments: 1, material: "metal.surgical"),
                        Xform(translation: V3(tubeX, y0 + 0.125, zf), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))

        // MARK: door (hinged on the left edge, swings out)
        let dw: Float = 0.126, dh: Float = 0.112, dt: Float = 0.012
        let hingeX = -dw / 2 + 0.002, doorZ = zf + dt / 2 + 0.0062
        rig.part("door", pivot: V3(hingeX, y0 + 0.078, zf + 0.006), joint: .hinge(axis: .up, -doorOpen...0, duration: 0.7))
        _ = doorZ
        for l in 0..<2 {
            rig.add(Prim.roundedBox(V3(dw, dh, dt), radius: 0.005, bevelSegments: l == 0 ? 2 : 1, material: door), Xform(translation: V3(0, y0 + 0.078, doorZ)), to: "door", lods: l...l)
        }
        // Latch lever on the right edge, hinge knuckles on the left, flow arrow embossed.
        rig.add(Prim.roundedBox(V3(0.012, 0.05, 0.008), radius: 0.003, bevelSegments: 1, material: "plastic.medical:2F64B4"),
                Xform(translation: V3(dw / 2 - 0.01, y0 + 0.078, doorZ + dt / 2 + 0.002)), to: "door")
        for k in 0..<2 {
            rig.add(Prim.cylinder(radius: 0.0035, height: 0.022, bevel: 0.001, segments: 10, bevelSegments: 1, material: door),
                    Xform(translation: V3(hingeX - 0.001, y0 + 0.032 + Float(k) * 0.07, zf + 0.006)), to: "door", lods: 0...0)
        }
        var arrow = Surface(material: "plastic.medical-grey:7A8187")
        let ao = V3(-0.03, y0 + 0.078, doorZ + dt / 2 + 0.0002)
        BedsideKit.bar(&arrow, ao, V3(1, 0, 0), V3(0, 1, 0), -0.002, -0.004, 0.002, 0.03)
        BedsideKit.quad2(&arrow, ao, V3(1, 0, 0), V3(0, 1, 0), V2(-0.007, -0.004), V2(0, -0.016), V2(0, -0.016), V2(0.007, -0.004))
        arrow.computeTangents()
        rig.add(arrow, to: "door", lods: 0...0)
        // Door edge scuff (story): worn paint line along the latch side.
        rig.add(Prim.roundedBox(V3(0.0025, dh - 0.02, 0.0012), radius: 0.0005, bevelSegments: 1, material: "plastic.medical-grey:B7BCBF"),
                Xform(translation: V3(dw / 2 - 0.0012, y0 + 0.078, doorZ + dt / 2 - 0.0008)), to: "door", lods: 0...0)

        // MARK: clamp screw (slides along X through the right jaw)
        rig.part("clamp", pivot: V3(0.04, y0 + 0.15, -zf - 0.034), joint: .slide(axis: V3(-1, 0, 0), 0...0.014, duration: 0.6))
        let qx = simd_quatf(degrees: -90, axis: V3(0, 0, 1))
        rig.add(Prim.cylinder(radius: 0.004, height: 0.05, bevel: 0.0008, segments: 10, bevelSegments: 1, material: "metal.chrome"),
                Xform(translation: V3(0.008, y0 + 0.15, -zf - 0.034), rotation: qx), to: "clamp")
        rig.add(Prim.cylinder(radius: 0.0055, height: 0.012, bevel: 0.002, segments: 10, bevelSegments: 1, material: "plastic.matte:2A2C2E"),
                Xform(translation: V3(0.058, y0 + 0.15, -zf - 0.034), rotation: qx), to: "clamp")
        rig.add(Prim.roundedBox(V3(0.012, 0.05, 0.01), radius: 0.004, bevelSegments: 1, material: "plastic.matte:2A2C2E"),
                Xform(translation: V3(0.066, y0 + 0.15, -zf - 0.034)), to: "clamp")
        rig.add(Prim.cylinder(radius: 0.006, height: 0.003, bevel: 0.001, segments: 10, bevelSegments: 1, material: "metal.chrome"),
                Xform(translation: V3(0.006, y0 + 0.15, -zf - 0.034), rotation: qx), to: "clamp", lods: 0...0)

        // MARK: display (off / running) and LEDs
        let scrC = V3(-0.016, y0 + H - 0.04, zf + 0.0024)
        rig.part("screen", pivot: scrC, joint: .fixed, options: 2)
        rig.add(BedsideKit.panel(center: scrC, u: V3(1, 0, 0), v: V3(0, 1, 0), w: 0.078, h: 0.047, material: "screen.off"), to: "screen")
        rig.add(BedsideKit.panel(center: scrC, u: V3(1, 0, 0), v: V3(0, 1, 0), w: 0.078, h: 0.047, material: "screen.bedside-pump"), to: "screen", option: 1)
        var txt = BedsideKit.segments(String(rate), origin: scrC + V3(-0.033, -0.009, 0.0002), u: V3(1, 0, 0), v: V3(0, 1, 0), height: 0.019, stroke: 0.14, material: "emissive.bedside-white")
        txt.append(BedsideKit.caption([4], origin: scrC + V3(0.012, -0.009, 0.0002), u: V3(1, 0, 0), v: V3(0, 1, 0), height: 0.004, material: "emissive.bedside-white"))
        txt.append(BedsideKit.caption([4, 6], origin: scrC + V3(-0.035, 0.016, 0.0002), u: V3(1, 0, 0), v: V3(0, 1, 0), height: 0.0035, material: "emissive.bedside-white"))
        txt.append(BedsideKit.segments("875", origin: scrC + V3(0.016, 0.013, 0.0002), u: V3(1, 0, 0), v: V3(0, 1, 0), height: 0.006, stroke: 0.16, material: "emissive.bedside-white"))
        txt.append(BedsideKit.caption([3, 2, 3], origin: scrC + V3(-0.035, -0.0205, 0.0002), u: V3(1, 0, 0), v: V3(0, 1, 0), height: 0.0032, material: "emissive.bedside-white"))
        rig.add(txt, to: "screen", option: 1)
        rig.part("leds", pivot: V3(0.05, y0 + H - 0.08, zf), joint: .fixed, options: 2)
        for (opt, run) in [(0, "plastic.matte:3A4A3C"), (1, "emissive.led-green")] {
            rig.add(Prim.roundedBox(V3(0.006, 0.003, 0.002), radius: 0.0008, bevelSegments: 1, material: run), Xform(translation: V3(0.044, y0 + H - 0.0815, zf + 0.0012)), to: "leds", option: opt)
            rig.add(Prim.roundedBox(V3(0.006, 0.003, 0.002), radius: 0.0008, bevelSegments: 1, material: "plastic.matte:4A3E2A"), Xform(translation: V3(0.056, y0 + H - 0.0815, zf + 0.0012)), to: "leds", option: opt)
        }
        rig.lights = [RigLight(name: "screen-glow", kind: .point, part: "screen", option: 1, position: scrC + V3(0, 0, 0.12),
                               color: V3(0.75, 0.85, 1.0), intensity: 6, attenuationRadius: 0.5)]
        _ = rng.float()

        groundAO(&rig, height: 0.03, floor: 0.55)
        rig.states = [
            RigState("closed-off"),
            RigState("on", options: ["screen": 1, "leds": 1]),
            RigState("door-open", ["door": -doorOpen], options: ["screen": 1]),
        ]
        return rig
    }
}
