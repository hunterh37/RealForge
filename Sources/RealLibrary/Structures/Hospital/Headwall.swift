import simd
import Foundation

/// Horizontal patient-room headwall (Modular Services / Amico horizontal bed-locator class), 2.4 m long:
/// clear anodized aluminium extrusion, 260 mm service section with three white modular faceplates and an
/// integrated overbed luminaire on top (up-light lens over a 1.4 m run, a centre reading lens and two exam
/// lenses underneath). Left plate: DISS medical gas outlets (2 x O2 green, air yellow, vacuum white) with
/// an O2-in-use tag. Centre: nurse call station with call and cancel buttons, pillow speaker jack and
/// hook, dome light and two light rockers. Right: hospital-grade duplex receptacles on white (normal) and
/// red (emergency) plates. Stainless equipment rail along the bottom carrying a 1200 cc suction canister
/// fed from a wall vacuum regulator in the vacuum outlet. Back on the wall (-Z); lowest point (canister
/// base) at y = 0 with the extrusion bottom at y = 0.30: place it at y = 1.15 for a 1.45 m service line.
public struct Headwall: RealArticulated {
    public static let id = "headwall"
    public static let summary = "Patient-room headwall: 2.4 m aluminium extrusion with O2, air and vacuum outlets, outlets, nurse call, overbed up/down light and suction canister."
    public static let tags = ["structure", "medical", "hospital", "interior", "metal", "electronics", "light", "articulated"]
    public static let budget = 13_500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 22, elevation: 10, distance: 1.0, studio: true)

    public var length: Float = 2.4
    public var frame: MaterialKey = "metal.anodized"
    public var plates: MaterialKey = "metal.powder-white"
    /// Suction canister on the rail under the vacuum outlet.
    public var canister = true
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [8])
        let W = length, yb: Float = 0.3, sh: Float = 0.26, lh: Float = 0.14
        let zb: Float = -0.08, zs: Float = 0.01           // back plane, service front
        let zf = zs + 0.004                                 // faceplate front
        let ylight = yb + sh
        let grey: MaterialKey = "plastic.medical-grey", black: MaterialKey = "plastic.black"
        // Luminaire profile (z, y) above the service section, extruded along X.
        let lp: [V2] = [V2(-0.08, 0), V2(0.055, 0), V2(0.07, 0.02), V2(0.07, 0.1), V2(0.03, lh), V2(-0.08, lh)]
        let lightOutline = Shape2D.rounded(lp.map { V2(-$0.x, $0.y) }, radius: 0.006, segments: 2)
        let alongX = simd_quatf(degrees: 90, axis: V3(0, 1, 0))

        for l in 0..<2 {
            var m = Model(name: Self.id)
            let seg = l == 0 ? 2 : 1
            m.add(Prim.roundedBox(V3(W, sh, zs - zb), radius: 0.006, bevelSegments: seg, material: frame), Xform(translation: V3(0, yb + sh / 2, (zb + zs) / 2)))
            m.add(Prim.extrude(l == 0 ? lightOutline : lp.map { V2(-$0.x, $0.y) }, depth: W, bevel: 0.002, bevelSegments: 1, material: frame),
                  Xform(translation: V3(0, ylight, 0), rotation: alongX))
            // End caps.
            for s: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(0.012, sh, zs - zb + 0.004), radius: 0.004, bevelSegments: seg, material: grey),
                      Xform(translation: V3(s * (W / 2 + 0.006), yb + sh / 2, (zb + zs) / 2)))
                m.add(Prim.extrude(Shape2D.offset(lightOutline, 0.002), depth: 0.012, bevel: 0.003, bevelSegments: seg, material: grey),
                      Xform(translation: V3(s * (W / 2 + 0.006), ylight, 0), rotation: alongX))
            }
            // Modular faceplates: gas (left), nurse call (centre), power (right), blanks between.
            let spans: [(Float, Float)] = [(-W / 2 + 0.02, -0.3), (-0.296, 0.296), (0.3, W / 2 - 0.02)]
            for (a, b) in spans {
                m.add(Prim.roundedBox(V3(b - a, 0.2, 0.006), radius: 0.002, bevelSegments: 1, material: plates),
                      Xform(translation: V3((a + b) / 2, yb + sh / 2, zs + 0.002)).jittered(&rng, deg: 0.03, offset: 0.0002))
            }
            // Stainless equipment rail on standoffs.
            m.add(Prim.roundedBox(V3(W - 0.1, 0.025, 0.008), radius: 0.002, bevelSegments: seg, material: "metal.stainless"), Xform(translation: V3(0, yb + 0.016, zs + 0.03)))
            for k in 0..<5 {
                let x = -W / 2 + 0.1 + Float(k) * (W - 0.2) / 4
                m.add(Prim.cylinder(radius: 0.007, height: 0.03, bevel: 0.001, segments: 8, bevelSegments: 1, material: "metal.stainless"),
                      Xform(translation: V3(x, yb + 0.016, zs), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            }
            rig.base[l] = m
        }

        // MARK: medical gas outlets
        let yo = yb + sh / 2 + 0.01
        let gases: [(Float, UInt32, String)] = [(-1.0, 0x2E8B3E, "O2"), (-0.85, 0x2E8B3E, "O2"), (-0.7, 0xE3BE20, "AIR"), (-0.52, 0xEDEDED, "VAC")]
        var chrome = Surface(material: "metal.chrome"), sockets = Surface(material: black)
        for (x, color, _) in gases {
            let plate: MaterialKey = "plastic.gloss:" + String(format: "%06X", color)
            for l in 0..<2 {
                rig.base[l].add(Prim.roundedBox(V3(0.075, 0.1, 0.004), radius: 0.004, bevelSegments: 1, material: plate), Xform(translation: V3(x, yo, zf + 0.002)))
            }
            chrome.append(Prim.lathe([V2(0, 0.03), V2(0.016, 0.03), V2(0.019, 0.027), V2(0.021, 0.012), V2(0.024, 0.006), V2(0.024, 0)], segments: 16, seamTile: 0.05, material: "metal.chrome"),
                          Xform(translation: V3(x, yo + 0.005, zf + 0.004), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            sockets.append(Prim.cylinder(radius: 0.008, height: 0.002, bevel: 0.0005, segments: 10, bevelSegments: 1, material: black),
                           Xform(translation: V3(x, yo + 0.005, zf + 0.0335), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }
        // Story detail: an "OXYGEN IN USE" tag hung on the first O2 outlet.
        rig.base[0].add(quad(V3(-1.0, yo - 0.075, zf + 0.012), right: V3(1, 0, 0), up: V3(0, 1, 0), w: 0.07, h: 0.045, mat: "label.o2-tag"))

        // MARK: electrical receptacles (normal white, emergency red)
        var slots = Surface(material: black)
        for (i, x) in [Float(0.45), 0.6, 0.85, 1.0].enumerated() {
            let red = i >= 2
            let plate: MaterialKey = red ? "plastic.gloss:B52A26" : "plastic.gloss:F0EFEA"
            for l in 0..<2 {
                rig.base[l].add(Prim.roundedBox(V3(0.07, 0.115, 0.005), radius: 0.003, bevelSegments: 1, material: plate), Xform(translation: V3(x, yo, zf + 0.0025)))
            }
            for dy: Float in [-0.024, 0.024] {
                rig.base[0].add(Prim.roundedBox(V3(0.034, 0.038, 0.006), radius: 0.004, bevelSegments: 1, material: red ? "plastic.gloss:C23430" : "plastic.gloss:F4F3EE"),
                                Xform(translation: V3(x, yo + dy, zf + 0.006)))
                for sx: Float in [-1, 1] { slots.append(cuboid(V3(0.0025, 0.009, 0.002), material: black), Xform(translation: V3(x + sx * 0.0065, yo + dy + 0.004, zf + 0.009))) }
                slots.append(cuboid(V3(0.005, 0.005, 0.002), material: black), Xform(translation: V3(x, yo + dy - 0.009, zf + 0.009)))
            }
        }
        rig.base[0].add(slots)

        // MARK: nurse call station
        for l in 0..<2 {
            rig.base[l].add(Prim.roundedBox(V3(0.13, 0.15, 0.012), radius: 0.006, bevelSegments: l == 0 ? 2 : 1, material: grey), Xform(translation: V3(0, yo, zf + 0.006)))
        }
        rig.base[0].add(Prim.cylinder(radius: 0.014, height: 0.006, bevel: 0.002, segments: 16, bevelSegments: 1, material: "plastic.gloss:C8302A"),
                        Xform(translation: V3(-0.03, yo + 0.04, zf + 0.012), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        rig.base[0].add(Prim.roundedBox(V3(0.026, 0.016, 0.006), radius: 0.003, bevelSegments: 1, material: "plastic.gloss:EDEDE8"), Xform(translation: V3(0.03, yo + 0.04, zf + 0.014)))
        rig.base[0].add(Prim.lathe([V2(0, 0.012), V2(0.008, 0.011), V2(0.012, 0.006), V2(0.013, 0)], segments: 12, seamTile: 0.05, material: "emissive.led-green"),
                        Xform(translation: V3(0, yo + 0.06, zf + 0.012), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        rig.base[0].add(Prim.cylinder(radius: 0.011, height: 0.004, bevel: 0.001, segments: 12, bevelSegments: 1, material: "metal.chrome"),
                        Xform(translation: V3(0, yo - 0.005, zf + 0.012), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        rig.base[0].add(Prim.cylinder(radius: 0.007, height: 0.002, bevel: 0.0005, segments: 10, bevelSegments: 1, material: black),
                        Xform(translation: V3(0, yo - 0.005, zf + 0.0155), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Pillow speaker hook (J hook) beside the station.
        rig.base[0].add(Prim.tube(catmull([V3(0.08, yo + 0.02, zf), V3(0.08, yo + 0.02, zf + 0.035), V3(0.08, yo - 0.01, zf + 0.04), V3(0.08, yo - 0.02, zf + 0.025), V3(0.08, yo - 0.005, zf + 0.02)], per: 3),
                                  radii: Array(repeating: 0.004, count: 13), sides: 8, seamTile: 0.05, material: "metal.chrome"))
        rig.base[0].add(chrome); rig.base[0].add(sockets)
        // O2 flowmeter in the second oxygen outlet: chrome body, clear flow tube with a float, green knob.
        let fx: Float = -0.85, fz = zf + 0.045
        for l in 0..<2 {
            let sg = l == 0 ? 16 : 8
            var fm = Model(name: "flow")
            fm.add(Prim.roundedBox(V3(0.034, 0.05, 0.03), radius: 0.006, bevelSegments: l == 0 ? 2 : 1, material: "metal.chrome"), Xform(translation: V3(fx, yo, fz)))
            fm.add(Prim.cylinder(radius: 0.017, height: 0.13, bevel: 0.002, segments: sg, bevelSegments: 1, material: "plastic.clear"), Xform(translation: V3(fx, yo + 0.025, fz + 0.003)))
            fm.add(Prim.cylinder(radius: 0.019, height: 0.014, bevel: 0.003, segments: sg, bevelSegments: 1, material: "plastic.gloss:2E8B3E"), Xform(translation: V3(fx, yo + 0.155, fz + 0.003)))
            fm.add(Prim.cylinder(radius: 0.014, height: 0.02, bevel: 0.003, segments: sg, bevelSegments: 1, material: "plastic.gloss:2E8B3E"),
                   Xform(translation: V3(fx + 0.017, yo - 0.005, fz), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
            fm.add(Prim.cylinder(radius: 0.005, height: 0.03, bevel: 0.001, segments: 8, bevelSegments: 1, material: "metal.chrome"), Xform(translation: V3(fx, yo - 0.055, fz)))
            rig.base[l].add(fm)
        }
        rig.base[0].add(Prim.superellipsoid(V3(0.012, 0.012, 0.012), exponent: 2, subdivisions: 3, material: "metal.stainless"), Xform(translation: V3(fx, yo + 0.07, fz + 0.003)))
        // Pillow speaker handset hanging on its hook, cord running to the station jack.
        let hs = V3(0.08, yo - 0.085, zf + 0.04)
        for l in 0..<2 {
            rig.base[l].add(Prim.superellipsoid(V3(0.062, 0.15, 0.026), exponent: 3.5, subdivisions: l == 0 ? 6 : 3, material: grey),
                            Xform(translation: hs, rotation: simd_quatf(degrees: 4, axis: V3(0, 0, 1))))
        }
        var keys2 = Surface(material: "plastic.gloss:EDEDE8")
        for k in 0..<4 { keys2.append(Prim.roundedBox(V3(0.022, 0.014, 0.004), radius: 0.002, bevelSegments: 1, material: "plastic.gloss:EDEDE8"),
                                      Xform(translation: hs + V3(Float(k % 2) * 0.026 - 0.013, 0.035 - Float(k / 2) * 0.022, 0.013))) }
        rig.base[0].add(keys2)
        rig.base[0].add(Prim.cylinder(radius: 0.009, height: 0.003, bevel: 0.001, segments: 12, bevelSegments: 1, material: "plastic.gloss:C8302A"),
                        Xform(translation: hs + V3(0, -0.035, 0.012), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        let cord = catmull([V3(0, yo - 0.005, zf + 0.016), V3(0.01, yo - 0.06, zf + 0.06), V3(0.05, yb - 0.04, zf + 0.07), V3(0.085, yb - 0.09, zf + 0.05), V3(0.08, hs.y - 0.075, hs.z)], per: 5)
        rig.base[0].add(Prim.tube(cord, radii: cord.map { _ in 0.0025 }, sides: 6, seamTile: 0.05, material: "rubber"))
        for l in 1..<2 {
            var lite = Surface(material: "metal.chrome")
            for (x, _, _) in gases { lite.append(Prim.cylinder(radius: 0.021, height: 0.025, bevel: 0.002, segments: 8, bevelSegments: 1, material: "metal.chrome"),
                                                 Xform(translation: V3(x, yo + 0.005, zf + 0.004), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)))) }
            rig.base[l].add(lite)
        }

        // MARK: luminaire lenses (options) and lights
        let lensY = ylight - 0.0006, lz0: Float = zs + 0.006, lz1: Float = 0.052
        func lens(_ x0: Float, _ x1: Float, down: Bool, mat: MaterialKey) -> Surface {
            if down { return quad(V3((x0 + x1) / 2, lensY, (lz0 + lz1) / 2), right: V3(1, 0, 0), up: V3(0, 0, 1), w: x1 - x0, h: lz1 - lz0, mat: mat) }
            return quad(V3((x0 + x1) / 2, ylight + lh + 0.0006, -0.035), right: V3(1, 0, 0), up: V3(0, 0, -1), w: x1 - x0, h: 0.06, mat: mat)
        }
        rig.part("uplight", pivot: V3(0, ylight + lh, -0.035), joint: .fixed, options: 2)
        rig.part("reading", pivot: V3(0, ylight, 0.03), joint: .fixed, options: 2)
        rig.part("exam", pivot: V3(0, ylight, 0.03), joint: .fixed, options: 2)
        for (o, mat) in [(0, "plastic.diffuser"), (1, "emissive.panel")] {
            rig.add(lens(-0.7, 0.7, down: false, mat: mat), to: "uplight", option: o)
            rig.add(lens(-0.15, 0.15, down: true, mat: mat == "emissive.panel" ? "emissive.warm" : mat), to: "reading", option: o)
            var ex = lens(-0.65, -0.2, down: true, mat: mat)
            ex.append(lens(0.2, 0.65, down: true, mat: mat))
            rig.add(ex, to: "exam", option: o)
        }
        rig.lights = [
            RigLight(name: "uplight", kind: .point, part: "uplight", option: 1, position: V3(0, ylight + lh + 0.35, 0.05), color: V3(1, 0.9, 0.78), intensity: 700, attenuationRadius: 3),
            RigLight(name: "reading", kind: .spot(inner: 22, outer: 38), part: "reading", option: 1, position: V3(0, lensY - 0.02, 0.03),
                     direction: V3(0, -1, 0.35), color: V3(1, 0.84, 0.64), intensity: 900, attenuationRadius: 3, castsShadow: true),
            RigLight(name: "exam", kind: .spot(inner: 35, outer: 60), part: "exam", option: 1, position: V3(0, lensY - 0.02, 0.03),
                     direction: V3(0, -1, 0.45), color: V3(0.95, 0.97, 1), intensity: 2400, attenuationRadius: 4, castsShadow: true),
        ]

        // MARK: light rockers on the call station
        for (i, name) in ["reading-switch", "exam-switch"].enumerated() {
            let p = V3(Float(i) * 0.036 - 0.018, yo - 0.05, zf + 0.014)
            rig.part(name, pivot: p, joint: .hinge(axis: V3(1, 0, 0), 0...16, duration: 0.15))
            rig.add(Prim.roundedBox(V3(0.026, 0.02, 0.006), radius: 0.002, bevelSegments: 1, material: "plastic.gloss:EDEDE8"),
                    Xform(translation: p, rotation: simd_quatf(degrees: 8, axis: V3(1, 0, 0))), to: name)
        }

        // MARK: suction regulator and canister
        if canister {
            let vx: Float = -0.52, rz = zf + 0.03
            var reg = Model(name: "reg")
            reg.add(Prim.roundedBox(V3(0.06, 0.1, 0.05), radius: 0.01, bevelSegments: 2, material: "plastic.medical"), Xform(translation: V3(vx, yo - 0.02, rz + 0.025)))
            reg.add(Prim.cylinder(radius: 0.034, height: 0.03, bevel: 0.004, segments: 20, bevelSegments: 2, material: "plastic.matte:2C2D30"),
                    Xform(translation: V3(vx, yo + 0.055, rz), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            reg.add(Prim.cylinder(radius: 0.012, height: 0.02, bevel: 0.002, segments: 12, bevelSegments: 1, material: "plastic.matte:2C2D30"),
                    Xform(translation: V3(vx, yo - 0.085, rz + 0.025)))
            reg.add(Prim.cylinder(radius: 0.0045, height: 0.022, bevel: 0.001, segments: 8, bevelSegments: 1, material: "plastic.medical"),
                    Xform(translation: V3(vx + 0.03, yo - 0.04, rz + 0.025), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
            for l in 0..<2 { rig.base[l].add(reg) }
            // Gauge face and needle.
            rig.base[0].add(Prim.cylinder(radius: 0.028, height: 0.002, bevel: 0.0005, segments: 20, bevelSegments: 1, material: "plastic.white"),
                            Xform(translation: V3(vx, yo + 0.055, rz + 0.03), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            rig.base[0].add(cuboid(V3(0.0015, 0.022, 0.001), material: "plastic.gloss:B52A26"),
                            Xform(translation: V3(vx + 0.004, yo + 0.062, rz + 0.0325), rotation: simd_quatf(degrees: -35, axis: V3(0, 0, 1))))
            rig.base[0].add(quad(V3(vx, yo + 0.055, rz + 0.0323), right: V3(1, 0, 0), up: V3(0, 1, 0), w: 0.036, h: 0.036, mat: "plastic.clear"))
            // Canister: clear 1200 cc jar in a rail bracket, blue lid with ports.
            let cx = vx + 0.0, cz: Float = 0.105, cr: Float = 0.06, ch: Float = 0.18
            for l in 0..<2 {
            let sg = l == 0 ? 28 : 10
            var jar = Model(name: "jar")
            jar.add(Prim.lathe(Profile.shell([V2(cr - 0.008, 0), V2(cr, 0.008), V2(cr, ch)], wall: 0.003, floor: 0.004), segments: sg, seamTile: 0.2, material: "plastic.clear"),
                    Xform(translation: V3(cx, 0, cz)))
            jar.add(Prim.lathe([V2(0, ch + 0.028), V2(cr - 0.01, ch + 0.028), V2(cr + 0.004, ch + 0.022), V2(cr + 0.004, ch - 0.004), V2(cr - 0.002, ch - 0.006)],
                               segments: sg, seamTile: 0.2, material: "plastic.gloss:2A5FA8"), Xform(translation: V3(cx, 0, cz)))
            for (dx, label) in [(Float(-0.025), 0), (0.025, 1)] {
                _ = label
                jar.add(Prim.cylinder(radius: 0.007, height: 0.02, bevel: 0.0015, segments: 10, bevelSegments: 1, material: "plastic.gloss:2A5FA8"), Xform(translation: V3(cx + dx, ch + 0.026, cz)))
            }
            // Bracket: rail hook, strap, holder ring.
            jar.add(Prim.roundedBox(V3(0.05, 0.04, 0.012), radius: 0.003, bevelSegments: 1, material: "metal.stainless"), Xform(translation: V3(cx, yb + 0.012, zs + 0.04)))
            jar.add(Prim.roundedBox(V3(0.03, yb - 0.11, 0.006), radius: 0.002, bevelSegments: 1, material: "metal.stainless"), Xform(translation: V3(cx, 0.11 + (yb - 0.11) / 2, zs + 0.043)))
            jar.add(Prim.torus(major: cr + 0.006, minor: 0.004, segments: sg, sides: l == 0 ? 6 : 4, material: "metal.stainless"), Xform(translation: V3(cx, ch - 0.03, cz)))
            rig.base[l].add(jar)
            }
            // Graduation label and a little aspirate in the jar.
            rig.base[0].add(quad(V3(cx, 0.09, cz + cr + 0.0008), right: V3(1, 0, 0), up: V3(0, 1, 0), w: 0.04, h: 0.12, mat: "label.canister"))
            rig.base[0].add(Prim.lathe([V2(0, 0.034), V2(cr - 0.005, 0.034), V2(cr - 0.005, 0.006), V2(cr - 0.012, 0.005)], segments: 24, seamTile: 0.2, material: "fluid.saline:D9C9A0"),
                            Xform(translation: V3(cx, 0, cz)))
            // Tubing: regulator outlet to the canister vacuum port, patient line looping out of the other.
            let t1 = catmull([V3(vx + 0.052, yo - 0.04, rz + 0.025), V3(vx + 0.09, yo - 0.08, rz + 0.04), V3(cx + 0.06, ch + 0.08, cz + 0.02), V3(cx + 0.025, ch + 0.05, cz)], per: 5)
            let t2 = catmull([V3(cx - 0.025, ch + 0.05, cz), V3(cx - 0.07, ch + 0.08, cz + 0.05), V3(cx - 0.16, ch - 0.02, cz + 0.07), V3(cx - 0.2, 0.06, cz + 0.04), V3(cx - 0.26, 0.012, cz + 0.02)], per: 5)
            for (t, lods) in [(t1, 0...0), (t2, 0...0)] {
                let tube = Prim.tube(t, radii: t.map { _ in 0.0042 }, sides: 8, seamTile: 0.05, material: "rubber.tubing")
                for l in lods { rig.base[l].add(tube) }
            }
        }

        groundAO(&rig, height: 0.04, floor: 0.8)
        rig.states = [
            RigState("off"),
            RigState("reading-light", ["reading-switch": 16], options: ["uplight": 1, "reading": 1]),
            RigState("exam-light", ["reading-switch": 16, "exam-switch": 16], options: ["uplight": 1, "reading": 1, "exam": 1]),
        ]
        return rig
    }
}

/// Quad with UVs 0...1 across it (labels, lenses).
private func quad(_ c: V3, right: V3, up: V3, w: Float, h: Float, mat: MaterialKey) -> Surface {
    var s = Surface(material: mat)
    let n = simd_normalize(simd_cross(right, up)), r = right * (w / 2), u = up * (h / 2)
    let t = artSpan(mat)
    let a = s.add(c - r - u, n, V2(0, 0)), b = s.add(c + r - u, n, V2(t, 0))
    let cc = s.add(c + r + u, n, V2(t, t)), d = s.add(c - r + u, n, V2(0, t))
    s.quad(a, b, cc, d)
    s.computeTangents()
    return s
}

/// UV span for one artwork across a label or screen: the material's tileSize (so texel density lints at ~1), else 1.
private func artSpan(_ mat: MaterialKey) -> Float {
    let s = MaterialLibrary.spec(for: String(mat.split(separator: ":")[0]))
    return s.program != nil && s.tileSize > 0 ? s.tileSize : 1
}
