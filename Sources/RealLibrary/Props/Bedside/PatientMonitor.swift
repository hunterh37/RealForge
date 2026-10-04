import simd
import Foundation

/// 15 in bedside patient monitor (Philips IntelliVue MX500 class) on a tilting wall-channel mount
/// (GCX class): 372 x 296 mm front, 110 mm deep tapered rear shell with vents and a molded handle,
/// 16:10 display behind a dark glass surround, hard keys and power LED below it, red alarm light bar
/// across the top, color-coded measurement sockets on the right side, a "BED" tape label. Mount:
/// 90 x 300 mm wall channel plate with four screws, short arm and a clevis tilt head with friction
/// knobs. The monitor tilts about the clevis axis; display and alarm bar are options with lights.
public struct PatientMonitor: RealArticulated {
    public static let id = "patient-monitor"
    public static let summary = "15 in bedside patient monitor on a tilting wall-channel mount: grey bezel, vitals display, alarm light bar, rear handle and tilt bracket."
    public static let tags = ["prop", "medical", "articulated", "electronics", "hospital", "plastic", "metal"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 12, studio: true)

    /// Housing plastic.
    public var housing: MaterialKey = "plastic.medical:E2E4E3"
    /// Mount finish.
    public var mount: MaterialKey = "metal.powder-white:C9CCCD"
    /// Downward tilt in the tilted state (degrees).
    public var tilt: Float = 15
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [7])
        let W: Float = 0.372, H: Float = 0.296, bezelD: Float = 0.034, shellD: Float = 0.072
        let cy: Float = 0.205, zFront: Float = 0.05
        let zBezelBack = zFront - bezelD
        let pivot = V3(0, cy - 0.01, zBezelBack - shellD - 0.012)
        let dark: MaterialKey = "plastic.matte:24272A"
        let qZ = simd_quatf(degrees: 90, axis: V3(1, 0, 0))   // loft +Y -> +Z

        // MARK: wall mount (static)
        let plateZ = pivot.z - 0.075
        for l in 0..<2 {
            var m = Model(name: Self.id)
            m.add(Prim.roundedBox(V3(0.09, 0.30, 0.012), radius: 0.004, bevelSegments: l == 0 ? 2 : 1, material: mount), Xform(translation: V3(0, 0.15, plateZ)))
            m.add(Prim.roundedBox(V3(0.03, 0.29, 0.004), radius: 0.0015, bevelSegments: 1, material: "metal.powder-white:A9ACAE"), Xform(translation: V3(0, 0.15, plateZ + 0.0065)))
            // Arm from the channel slide to the clevis.
            m.add(Prim.roundedBox(V3(0.05, 0.045, 0.06), radius: 0.008, bevelSegments: l == 0 ? 2 : 1, material: mount), Xform(translation: V3(0, pivot.y, plateZ + 0.035)))
            m.add(Prim.roundedBox(V3(0.07, 0.03, 0.02), radius: 0.006, bevelSegments: 1, material: mount), Xform(translation: V3(0, pivot.y, plateZ + 0.013)))
            // Clevis cheeks and friction knobs on the tilt axis.
            for sx: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(0.008, 0.05, 0.04), radius: 0.003, bevelSegments: 1, material: mount), Xform(translation: V3(sx * 0.03, pivot.y, pivot.z - 0.008)))
                m.add(Prim.cylinder(radius: 0.012, height: 0.014, bevel: 0.003, segments: l == 0 ? 16 : 8, bevelSegments: 1, material: dark),
                      Xform(translation: V3(sx * 0.034, pivot.y, pivot.z), rotation: simd_quatf(degrees: sx > 0 ? -90 : 90, axis: V3(0, 0, 1))))
            }
            if l == 0 {
                for sy: Float in [0.03, 0.27] {
                    for sx: Float in [-0.03, 0.03] {
                        m.add(Prim.cylinder(radius: 0.0045, height: 0.002, bevel: 0.0008, segments: 10, bevelSegments: 1, material: "metal.chrome"),
                              Xform(translation: V3(sx, sy, plateZ + 0.006), rotation: qZ))
                    }
                }
            }
            rig.base[l] = m
        }

        // MARK: monitor (tilts about the clevis axis)
        rig.part("monitor", pivot: pivot, joint: .hinge(axis: V3(1, 0, 0), -5...20, duration: 0.8))
        for l in 0..<2 {
            let bs = l == 0 ? 3 : 1
            // Front bezel.
            rig.add(Prim.roundedBox(V3(W, H, bezelD), radius: 0.014, bevelSegments: bs, material: housing), Xform(translation: V3(0, cy, zFront - bezelD / 2)), to: "monitor", lods: l...l)
            // Tapered rear shell lofted from the bezel back to the mount boss.
            let sh = l == 0 ? 3 : 1
            var rings: [[V3]] = []
            let steps: [(Float, Float, Float)] = [(1.0, 0.0, 0.0), (0.97, 0.35, -0.02), (0.88, 0.75, -0.035), (0.8, 1.0, -0.04)]
            for (k, st) in steps.reversed().enumerated() {
                _ = k
                let w = (W - 0.012) * st.0, h = (H - 0.012) * st.0
                rings.append(Prim.ring(Shape2D.roundedRect(w, h, radius: 0.03 * st.0, segments: sh), y: -shellD * st.1, offset: V3(0, 0, -st.2)))
            }
            rig.add(Prim.loft(rings, capStart: true, material: housing), Xform(translation: V3(0, cy, zBezelBack + 0.002), rotation: qZ), to: "monitor", lods: l...l)
            // Mount boss on the back.
            rig.add(Prim.roundedBox(V3(0.05, 0.06, 0.022), radius: 0.006, bevelSegments: 1, material: dark), Xform(translation: V3(0, pivot.y, pivot.z + 0.004)), to: "monitor", lods: l...l)
            // Carry handle molded into the top rear.
            let hz = zBezelBack + 0.006, ht = cy + H / 2
            let hp = catmull([V3(-0.1, ht - 0.006, hz), V3(-0.092, ht + 0.016, hz), V3(0, ht + 0.022, hz), V3(0.092, ht + 0.016, hz), V3(0.1, ht - 0.006, hz)], per: l == 0 ? 4 : 2)
            rig.add(Prim.sweep(Shape2D.roundedRect(0.02, 0.012, radius: 0.005, segments: l == 0 ? 2 : 1), along: hp, up: V3(0, 0, 1), material: housing), to: "monitor", lods: l...l)
        }
        // Dark glass surround, keys, power LED, sockets, vents, tape label.
        let sw: Float = 0.322, shH: Float = sw / 1.6
        let scrC = V3(0, cy + 0.016, zFront + 0.0006)
        rig.add(Prim.roundedBox(V3(sw + 0.02, shH + 0.02, 0.003), radius: 0.003, bevelSegments: 1, material: "screen.off"), Xform(translation: scrC + V3(0, 0, -0.0012)), to: "monitor")
        var keys = Surface(material: "plastic.medical:C9CCCC")
        for k in 0..<5 {
            keys.append(Prim.roundedBox(V3(0.026, 0.009, 0.004), radius: 0.002, bevelSegments: 1, material: "plastic.medical:C9CCCC"),
                        Xform(translation: V3(-0.1 + Float(k) * 0.034, cy - H / 2 + 0.024, zFront + 0.0012)))
        }
        rig.add(keys, to: "monitor", lods: 0...0)
        rig.add(Prim.cylinder(radius: 0.0065, height: 0.003, bevel: 0.001, segments: 12, bevelSegments: 1, material: dark),
                Xform(translation: V3(0.15, cy - H / 2 + 0.024, zFront - 0.0005), rotation: qZ), to: "monitor")
        rig.add(Prim.cylinder(radius: 0.0018, height: 0.001, bevel: 0.0003, segments: 8, bevelSegments: 1, material: "emissive.led-green"),
                Xform(translation: V3(0.15, cy - H / 2 + 0.024, zFront + 0.0024), rotation: qZ), to: "monitor", lods: 0...0)
        let socketColors: [UInt32] = [0x5C8A3A, 0x2F64B4, 0xB23A2E, 0xD0A020, 0x6A6E72]
        for (i, c) in socketColors.enumerated() {
            let p = V3(W / 2 + 0.0005, cy + 0.07 - Float(i) * 0.034, zFront - 0.022)
            rig.add(Prim.cylinder(radius: 0.0085, height: 0.003, bevel: 0.001, segments: 12, bevelSegments: 1, material: "plastic.medical:" + String(format: "%06X", c)),
                    Xform(translation: p, rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "monitor", lods: 0...0)
            rig.add(Prim.cylinder(radius: 0.0052, height: 0.0035, bevel: 0.0008, segments: 10, bevelSegments: 1, material: dark),
                    Xform(translation: p + V3(0.0005, 0, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "monitor", lods: 0...0)
        }
        // ECG trunk cable plugged into the first socket, hanging down the side (story: monitor in use).
        let sock = V3(W / 2 + 0.003, cy + 0.07, zFront - 0.022)
        let qx = simd_quatf(degrees: -90, axis: V3(0, 0, 1))
        rig.add(Prim.cylinder(radius: 0.0075, height: 0.026, bevel: 0.002, segments: 12, bevelSegments: 1, material: "plastic.medical:5C8A3A"), Xform(translation: sock, rotation: qx), to: "monitor")
        rig.add(Prim.lathe([V2(0.0072, 0), V2(0.0045, 0.014), V2(0.0034, 0.024)], segments: 10, material: "rubber.tubing:3A3D40"), Xform(translation: sock + V3(0.026, 0, 0), rotation: qx), to: "monitor")
        let cable = catmull([sock + V3(0.048, 0, 0), sock + V3(0.07, -0.012, 0.004), sock + V3(0.082, -0.06, 0.01), sock + V3(0.078, -0.16, 0.012), sock + V3(0.07, -0.22, 0.006)], per: 5)
        rig.add(Prim.tube(cable, radii: cable.map { _ in 0.0032 }, sides: 7, seamTile: 0.02, material: "rubber.tubing:3A3D40"), to: "monitor", lods: 0...0)
        rig.add(Prim.tube(cable, radii: cable.map { _ in 0.0032 }, sides: 4, seamTile: 0.02, material: "rubber.tubing:3A3D40"), to: "monitor", lods: 1...1)
        var vents = Surface(material: dark)
        for k in 0..<9 {
            vents.append(Prim.roundedBox(V3(0.004, 0.07, 0.002), radius: 0.0015, bevelSegments: 1, material: dark),
                         Xform(translation: V3(-0.06 + Float(k) * 0.015, cy - 0.03, zBezelBack + 0.002 - shellD - 0.0002), rotation: .identity))
        }
        rig.add(vents, to: "monitor", lods: 0...0)
        // Wear and story: cloth tape with the bed number in marker, a dated "cleaned" sticker on the side,
        // and a darker, glossier hand-worn patch on the handle grip.
        let tapeC = V3(-W / 2 + 0.06, cy + H / 2 - 0.014, zFront + 0.0003)
        rig.add(BedsideKit.panel(center: tapeC, u: V3(1, 0, 0), v: V3(0, 1, 0), w: 0.07, h: 0.018, material: "label.bedside-bedtape", vDown: true), to: "monitor", lods: 0...0)
        rig.add(BedsideKit.segments("12", origin: tapeC + V3(0.006, -0.006, 0.0003), u: V3(1, 0, 0), v: V3(0, 1, 0), height: 0.012, stroke: 0.2, shear: 0.18,
                                    material: "plastic.matte:1E2A5A"), to: "monitor", lods: 0...0)
        rig.add(BedsideKit.panel(center: V3(-W / 2 - 0.0004, cy - 0.06, zFront - 0.02), u: V3(0, 0, 1), v: V3(0, 1, 0), w: 0.04, h: 0.028, material: "label.bedside-cleaned", vDown: true),
                to: "monitor", lods: 0...0)
        let gz = zBezelBack + 0.006, gt = cy + H / 2 + 0.0225
        rig.add(Prim.roundedBox(V3(0.09, 0.0016, 0.016), radius: 0.0006, bevelSegments: 1, material: "plastic.medical:B9BCBC"), Xform(translation: V3(0, gt, gz)), to: "monitor", lods: 0...0)
        _ = rng.float()

        // MARK: display (off / vitals / alarm) and alarm light bar
        rig.part("screen", parent: "monitor", pivot: scrC, joint: .fixed, options: 3)
        for (opt, mat) in [(0, "screen.off"), (1, "screen.bedside-vitals"), (2, "screen.bedside-vitals-alarm")] as [(Int, MaterialKey)] {
            rig.add(BedsideKit.panel(center: scrC + V3(0, 0, 0.0004), u: V3(1, 0, 0), v: V3(0, 1, 0), w: sw, h: shH, material: mat), to: "screen", option: opt)
        }
        rig.part("alarm", parent: "monitor", pivot: V3(0, cy + H / 2, zFront), joint: .fixed, options: 2)
        for (opt, mat) in [(0, "plastic.matte:6E4A48"), (1, "emissive.led-red")] as [(Int, MaterialKey)] {
            rig.add(Prim.roundedBox(V3(0.16, 0.009, 0.016), radius: 0.004, bevelSegments: 1, material: mat), Xform(translation: V3(0, cy + H / 2 + 0.002, zFront - 0.012)), to: "alarm", option: opt)
        }
        let glow = V3(0.7, 0.85, 1.0)
        rig.lights = [
            RigLight(name: "screen-glow", kind: .point, part: "screen", option: 1, position: scrC + V3(0, 0, 0.3), color: glow, intensity: 30, attenuationRadius: 1.2),
            RigLight(name: "screen-glow-alarm", kind: .point, part: "screen", option: 2, position: scrC + V3(0, 0, 0.3), color: glow, intensity: 30, attenuationRadius: 1.2),
            RigLight(name: "alarm-lamp", kind: .point, part: "alarm", option: 1, position: V3(0, cy + H / 2 + 0.03, zFront), color: V3(1, 0.15, 0.1), intensity: 25, attenuationRadius: 1.0),
        ]

        groundAO(&rig, height: 0.05, floor: 0.6)
        rig.states = [
            RigState("off"),
            RigState("on", options: ["screen": 1]),
            RigState("alarm", options: ["screen": 2, "alarm": 1]),
            RigState("tilted-on", ["monitor": tilt], options: ["screen": 1]),
        ]
        rig.defaultState = "on"
        return rig
    }
}
