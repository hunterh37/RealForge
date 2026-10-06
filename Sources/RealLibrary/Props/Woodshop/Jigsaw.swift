import simd
import Foundation

/// Generic 18V class cordless top-handle jigsaw on its shoe at y = 0, cutting toward +X (about 250 mm long,
/// 205 mm tall above the shoe, 77 mm wide): stamped steel shoe with a blade notch, stamped ribs and a
/// die-cast bevel quadrant with a hex lock bolt, die-cast gear housing, teal motor housing with vents and
/// Torx screws, closed D handle with a pebbled rubber overmold, trigger with a lock-on button, speed dial,
/// four-position orbital selector, blade roller guide, wire finger guard, clear chip shield, T-shank
/// 10 TPI blade on the plunger with a tool-free clamp, family 2 Ah slide-on pack under the handle's rear.
/// The blade hangs below the shoe (`bladeTipDepth`).
///
/// Rig: `blade` (slide along Y, -0.01...0.01 m; plunger, clamp and blade; the game reciprocates it),
/// `trigger` (slide up into the handle, 0...7 mm).
public struct Jigsaw: RealArticulated {
    public static let id = "jigsaw"
    public static let summary = "Cordless top-handle jigsaw on its steel shoe: rubber D handle, locking trigger, speed dial, orbital selector, roller guide, chip shield, T-shank blade."
    public static let tags = ["prop", "workshop", "tool", "handheld", "articulated", "plastic", "rubber", "metal"]
    public static let budget = 11_000
    public static let author = "hunter"
    /// No floor in previews: the blade hangs below the shoe and would vanish into it.
    public static let preview = PreviewHint(azimuth: 150, elevation: 12, distance: 0.8, ground: false, studio: true)

    /// Housing color (sRGB hex, `plastic.tool`).
    public var bodyColor: UInt32 = CordlessKit.bodyColor
    /// Blade length below the shoe at rest (m).
    public var bladeTipDepth: Float = 0.062
    /// Trigger travel in the running state (m).
    public var triggerTravel: Float = 0.007
    public init() {}

    /// Asset-space shift applied after building (centers the bounds on X).
    static let shiftX: Float = 0.0655
    /// Tooth line X in the design frame.
    static let toothX: Float = 0.041
    /// X of the blade's tooth line (the kerf's leading edge) in asset space; the blade plane is z = 0.
    public var bladeX: Float { Self.toothX + Self.shiftX }
    /// Center of the rubber-gripped top handle bar (where the palm wraps), asset space.
    public var grip: V3 { V3(-0.095 + Self.shiftX, 0.192, 0) }

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3])
        let body = CordlessKit.housing(bodyColor), trim = CordlessKit.tool(CordlessKit.trimColor)
        let gripK = CordlessKit.grip, slotK = CordlessKit.slot
        let steel: MaterialKey = "metal.stainless", cast: MaterialKey = "metal.diecast"
        let X = V3(1, 0, 0), Y = V3(0, 1, 0), Z = V3(0, 0, 1)
        let bx = Self.toothX
        let toY = simd_quatf(degrees: -90, axis: X)     // extrude depth (Z) -> +Y, outline y -> -Z

        // Handle path (XY plane): front post, top bar, rear post into the battery receiver.
        let handlePts = catmull([V3(0.012, 0.105, 0), V3(0.010, 0.140, 0), V3(0.001, 0.170, 0), V3(-0.022, 0.1885, 0), V3(-0.060, 0.1925, 0),
                                 V3(-0.105, 0.1920, 0), V3(-0.135, 0.1830, 0), V3(-0.149, 0.1620, 0), V3(-0.152, 0.1250, 0), V3(-0.150, 0.086, 0)], per: 3)

        for l in 0..<2 {
            let lite = l == 1
            let n = lite ? 16 : 30
            var m = Model(name: Self.id)

            // MARK: shoe: stamped steel plate with a front blade notch and two stamped ribs.
            let notch: Float = 0.0045
            let shoe = Shape2D.rounded([V2(-0.065, -0.034), V2(0.050, -0.034), V2(0.050, -notch), V2(0.027, -notch), V2(0.027, notch),
                                        V2(0.050, notch), V2(0.050, 0.034), V2(-0.065, 0.034)], radius: 0.0035, segments: lite ? 1 : 3)
            m.add(Prim.extrude(shoe, depth: 0.003, bevel: 0.0009, bevelSegments: lite ? 1 : 2, material: steel), Xform(translation: V3(0, 0.0015, 0), rotation: toY))
            for z: Float in [-0.023, 0.023] {
                m.add(Prim.roundedBox(V3(0.090, 0.0016, 0.006), radius: 0.0007, bevelSegments: 1, material: steel), Xform(translation: V3(-0.012, 0.0033, z)))
            }
            // Base casting and bevel quadrant.
            m.add(Prim.roundedBox(V3(0.096, 0.018, 0.050), radius: 0.005, bevelSegments: lite ? 1 : 2, material: cast), Xform(translation: V3(-0.020, 0.0135, 0)))
            var quad: [V2] = []
            for k in 0...(lite ? 6 : 14) { let a = Float.pi * Float(k) / Float(lite ? 6 : 14); quad.append(V2(-0.030 + 0.026 * cos(a), 0.003 + 0.026 * sin(a))) }
            m.add(Prim.extrude(quad, depth: 0.052, bevel: 0.0015, bevelSegments: 1, material: cast))
            // Gear housing (die-cast aluminum), lofted up from the blade exit.
            let gOut = Shape2D.superellipse(1, 1, exponent: 3.4, segments: n)
            let gSt: [(Float, Float, Float, Float)] = [(0.0285, 0.048, 0.034, 0.030), (0.034, 0.058, 0.048, 0.028), (0.050, 0.064, 0.058, 0.026),
                                                       (0.080, 0.066, 0.061, 0.024), (0.106, 0.064, 0.059, 0.023), (0.114, 0.058, 0.054, 0.022)]
            m.add(Prim.loft(gSt.map { (y, L, W, cx) in Prim.ring(gOut.map { V2($0.x * L, $0.y * W * (1 - 0.55 * max(0, $0.x) * max(0, $0.x) * 4 * 0.5)) }, y: y, offset: V3(cx, 0, 0)) },
                            capStart: true, capEnd: true, material: cast))
            // Motor housing (teal), along X.
            let hOut = Shape2D.superellipse(1, 1, exponent: 2.8, segments: n)
            let hSt: [(Float, Float, Float)] = [(-0.090, 0.064, 0.050), (-0.086, 0.086, 0.062), (-0.074, 0.094, 0.066), (-0.030, 0.095, 0.067), (0.000, 0.092, 0.064), (0.008, 0.088, 0.060)]
            m.add(Prim.loft(hSt.map { (x, h, w) in CordlessKit.section(hOut.map { V2($0.x * h, $0.y * w) }, V3(x, 0.071, 0), Y, Z) }, capStart: true, capEnd: true, material: body))
            // Black nose band between motor and gear housing.
            m.add(Prim.loft([(0.004, 0.0925, 0.0655), (0.010, 0.0930, 0.0660), (0.016, 0.0915, 0.0645)].map { (x, h, w) in
                CordlessKit.section(hOut.map { V2($0.x * h, $0.y * w) }, V3(x, 0.071, 0), Y, Z) }, material: trim))

            // MARK: battery receiver and pack (latch end toward -X, rails up).
            m.add(Prim.superellipsoid(V3(0.112, 0.032, 0.074), exponent: 9, subdivisions: 4, material: body), Xform(translation: V3(-0.133, 0.0735, 0)))
            m.add(Prim.roundedBox(V3(0.108, 0.010, 0.076), radius: 0.003, bevelSegments: 1, material: trim), Xform(translation: V3(-0.133, 0.0630, 0)))
            m.add(CordlessKit.battery(lite: lite, bodyColor: bodyColor), Xform(translation: V3(-0.133, 0.0085, 0), rotation: simd_quatf(degrees: 180, axis: Y)))

            // MARK: D handle with rubber overmold on the top bar.
            let hp = Shape2D.superellipse(0.031, 0.027, exponent: 2.6, segments: lite ? 10 : 12)
            m.add(Prim.sweep(hp, along: handlePts, up: Z, material: body))
            // Rubber overmold: top bar and rear post in one piece.
            let bar = handlePts.filter { $0.x < -0.058 && $0.y > 0.104 }
            if bar.count >= 2 { m.add(Prim.sweep(hp.map { $0 * 1.08 }, along: bar, up: Z, material: gripK)) }

            // MARK: lock-on button on the +Z side of the handle above the trigger.
            let (lb, lx) = CordlessKit.rod(V3(-0.041, 0.1905, 0.0140), Z, radius: 0.0037, length: 0.0032, bevel: 0.0009, segments: 10, material: trim)
            m.add(lb, lx)
            // MARK: speed dial: ribbed wheel in the top front of the handle (axis Z).
            m.add(CordlessKit.spinX([V2(-0.0055, 0.0098), V2(0.0055, 0.0098)], center: .zero, segments: lite ? 12 : 20, ribs: lite ? 0 : 10, ribDepth: 0.0007, material: trim),
                  Xform(translation: V3(-0.016, 0.1955, 0), rotation: simd_quatf(degrees: -90, axis: Y)))
            // MARK: orbital selector on the +Z flank: boss and lever.
            let (ob, obx) = CordlessKit.rod(V3(0.012, 0.050, 0.0300), Z, radius: 0.0085, length: 0.0042, bevel: 0.001, segments: 12, material: trim)
            m.add(ob, obx)
            m.add(Prim.roundedBox(V3(0.0065, 0.024, 0.0042), radius: 0.0018, bevelSegments: 1, material: trim),
                  Xform(translation: V3(0.016, 0.040, 0.0352), rotation: simd_quatf(degrees: 20, axis: Z)))

            // MARK: LED work light in the gear housing nose, aimed at the cut line.
            let ledD = simd_normalize(V3(0.8, -1, 0))
            let (lb2, lb2x) = CordlessKit.rod(V3(0.0525, 0.0335, 0) - ledD * 0.002, ledD, radius: 0.0045, length: 0.0024, bevel: 0.0006, segments: 10, material: trim)
            m.add(lb2, lb2x)
            let (ll, llx) = CordlessKit.rod(V3(0.0525, 0.0335, 0) - ledD * 0.001, ledD, radius: 0.0029, length: 0.0018, bevel: 0.0005, segments: 10, material: "glass.led-lens")
            m.add(ll, llx)
            // MARK: roller guide behind the blade, wire finger guard in front, clear chip shield.
            let rx = bx - 0.0075 - 0.0042
            for z: Float in [-0.0048, 0.0048] {
                m.add(Prim.roundedBox(V3(0.020, 0.012, 0.0018), radius: 0.0007, bevelSegments: 1, material: steel), Xform(translation: V3(rx - 0.006, 0.0130, z)))
            }
            let (rl, rlx) = CordlessKit.rod(V3(rx, 0.0115, -0.0039), Z, radius: 0.0040, length: 0.0078, bevel: 0.0008, segments: lite ? 8 : 12, material: "metal.chrome")
            m.add(rl, rlx)
            let guardPath = catmull([V3(0.047, 0.030, -0.011), V3(0.053, 0.019, -0.010), V3(0.058, 0.011, -0.004), V3(0.059, 0.010, 0),
                                     V3(0.058, 0.011, 0.004), V3(0.053, 0.019, 0.010), V3(0.047, 0.030, 0.011)], per: lite ? 2 : 3)
            m.add(Prim.tube(guardPath, radii: guardPath.map { _ in 0.0011 }, sides: lite ? 5 : 6, seamTile: 0.02, material: steel))
            var arc: [V3] = []
            for k in 0...(lite ? 6 : 10) { let a = -1.35 + 2.7 * Float(k) / Float(lite ? 6 : 10); arc.append(V3(bx - 0.003 + 0.0155 * cos(a), 0.0205, 0.0155 * sin(a))) }
            m.add(Prim.sweep(Shape2D.roundedRect(0.016, 0.0012, radius: 0.0005, segments: 1), along: arc, up: Y, material: "plastic.clear"))
            for sz: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(0.007, 0.007, 0.0024), radius: 0.0009, bevelSegments: 1, material: trim), Xform(translation: V3(bx + 0.0005, 0.0285, sz * 0.0160)))
            }

            if !lite {
                // Motor vents both sides, rear vents.
                for sz: Float in [-1, 1] {
                    CordlessKit.vents(&m, start: V3(-0.074, 0.071, sz * 0.0334), step: V3(0.0062, 0, 0), count: 6, along: Y, normal: V3(0, 0, sz), len: 0.026, width: 0.0024)
                }
                CordlessKit.vents(&m, start: V3(-0.0905, 0.060, 0), step: V3(0, 0.0055, 0), count: 4, along: Z, normal: V3(-1, 0, 0), len: 0.030, width: 0.0019)
                // Clamshell screws on -Z.
                for p in [V3(-0.058, 0.0560, -0.0328), V3(-0.012, 0.0600, -0.0315), V3(-0.135, 0.0800, -0.0372), V3(-0.147, 0.150, -0.0150)] {
                    CordlessKit.screw(&m, at: p, normal: V3(0, 0, -1))
                }
                // Clamshell parting line over the motor housing top and down the handle's outer face.
                let seamTop = hSt.map { V3($0.0, 0.071 + $0.1 / 2 + 0.0001, 0) }
                let mid = V3(-0.07, 0.13, 0)
                let seamHandle = handlePts.indices.compactMap { i -> V3? in
                    let p = handlePts[i], a = handlePts[max(0, i - 1)], b = handlePts[min(handlePts.count - 1, i + 1)]
                    var nn = simd_normalize(V3(-(b - a).y, (b - a).x, 0))
                    if simd_dot(nn, p - mid) < 0 { nn = -nn }
                    let r: Float = (p.x < -0.058 && p.y > 0.104) ? 0.0135 * 1.08 : 0.0135
                    return p.y > 0.112 ? p + nn * (r + 0.0001) : nil
                }
                for path in [seamTop, seamHandle] where path.count >= 2 {
                    m.add(Prim.tube(path, radii: path.map { _ in 0.00045 }, sides: 4, seamTile: 0.02, material: slotK))
                }
                // Hex bevel lock bolt at the rear of the base casting.
                let (hb, hbx) = CordlessKit.rod(V3(-0.068, 0.0120, 0), V3(-1, 0, 0), radius: 0.0045, length: 0.0038, bevel: 0.0006, segments: 6, material: steel)
                m.add(hb, hbx)
                let (hs, hsx) = CordlessKit.rod(V3(-0.0716, 0.0120, 0), V3(-1, 0, 0), radius: 0.0018, length: 0.0003, bevel: 0.0001, segments: 6, material: slotK)
                m.add(hs, hsx)
                // Bevel scale ticks on the quadrant's +Z face (0, 15, 30, 45 each way).
                for k in 0..<7 {
                    let a = Float.pi * (0.5 + (Float(k) - 3) * 0.13)
                    m.add(cuboid(V3(0.0045, 0.0007, 0.0003), material: "paint.field-white"),
                          Xform(translation: V3(-0.030 + 0.0215 * cos(a), 0.003 + 0.0215 * sin(a), 0.0262), rotation: simd_quatf(angle: a, axis: Z)))
                }
                // Orbital selector marks (0, I, II, III).
                for k in 0..<4 {
                    let a = Float.pi * (1.25 + Float(k) * 0.17)
                    CordlessKit.disc(&m, at: V3(0.012 + 0.0115 * cos(a), 0.050 + 0.0115 * sin(a), 0.0328), normal: Z, radius: 0.0008, sides: 6, material: "paint.field-white")
                }
                // Speed dial numbers as ticks on the handle beside the wheel.
                for k in 0..<5 {
                    m.add(cuboid(V3(0.0008, 0.0006, 0.0018), material: "paint.field-white"), Xform(translation: V3(-0.027 + Float(k) * 0.0025, 0.1925 + Float(k) * 0.0007, 0.0118)))
                }
                // Side badge on +Z.
                m.add(Prim.roundedBox(V3(0.036, 0.013, 0.0016), radius: 0.0012, bevelSegments: 1, material: trim), Xform(translation: V3(-0.045, 0.0880, 0.0330)))
                m.add(cuboid(V3(0.012, 0.0035, 0.0008), material: "paint.field-white"), Xform(translation: V3(-0.054, 0.0880, 0.0340)))
                m.add(cuboid(V3(0.012, 0.0035, 0.0008), material: body), Xform(translation: V3(-0.038, 0.0880, 0.0340)))
                // Sawdust caught on the shoe around the notch (story detail).
                for k in 0..<3 {
                    let f = rng.float(0...1)
                    m.add(Prim.superellipsoid(V3(0.012 + 0.006 * f, 0.0016, 0.007 + 0.003 * f), exponent: 2.4, subdivisions: 3, material: "wood.sawdust"),
                          Xform(translation: V3(0.030 + Float(k) * 0.007, 0.0033, (k % 2 == 0 ? 1 : -1) * (0.012 + 0.004 * f))))
                }
            }
            rig.base[l] = m
        }

        // MARK: trigger: under the top bar, slides up.
        rig.part("trigger", pivot: V3(-0.043, 0.178, 0), joint: .slide(axis: Y, 0...0.009, duration: 0.25))
        let trig = Shape2D.rounded([V2(-0.0275, 0.1830), V2(-0.0290, 0.1640), V2(-0.0360, 0.1580), V2(-0.0480, 0.1595), V2(-0.0560, 0.1700), V2(-0.0570, 0.1830)],
                                   radius: 0.0022, segments: 3)
        rig.add(Prim.extrude(trig, depth: 0.0135, bevel: 0.0014, bevelSegments: 2, material: trim), to: "trigger", lods: 0...0)
        rig.add(Prim.extrude(trig, depth: 0.0135, bevel: 0.0010, bevelSegments: 1, material: trim), to: "trigger", lods: 1...1)

        // MARK: blade: plunger, clamp and T-shank blade (slides along Y).
        rig.part("blade", pivot: V3(bx - 0.004, 0, 0), joint: .slide(axis: Y, -0.01...0.01, duration: 0.15))
        let tip = -bladeTipDepth, back = bx - 0.0075
        for l in 0..<2 {
            var o: [V2] = [V2(bx - 0.0016, tip)]
            let pitch: Float = 0.0025
            var y = tip + 0.003
            while y < 0.010 {
                if l == 0 { o.append(V2(bx - 0.0011, y)); o.append(V2(bx, y + pitch * 0.72)) } else { o.append(V2(bx, y)) }
                y += l == 0 ? pitch : 0.02
            }
            o += [V2(bx, 0.019), V2(bx + 0.0016, 0.0205), V2(bx + 0.0016, 0.0240), V2(bx - 0.0008, 0.0240), V2(bx - 0.0008, 0.0300),
                  V2(back + 0.0008, 0.0300), V2(back + 0.0008, 0.0240), V2(back - 0.0016, 0.0240), V2(back - 0.0016, 0.0205), V2(back, 0.019),
                  V2(back, tip + 0.022)]
            rig.add(Prim.extrude(o, depth: 0.00125, bevel: 0.0002, bevelSegments: 1, material: "metal.sawblade"), to: "blade", lods: l...l)
        }
        // Printed shank band on both faces.
        for sz: Float in [-1, 1] {
            rig.add(cuboid(V3(0.0062, 0.014, 0.0002), material: "metal.powdercoat:2B4E8C"), Xform(translation: V3(bx - 0.0038, 0.004, sz * 0.00068)), to: "blade", lods: 0...0)
        }
        // Pitch and heat discoloration on the cutting zone (story detail).
        for sz: Float in [-1, 1] {
            rig.add(cuboid(V3(0.0042, 0.034, 0.0001), material: "metal.powdercoat:3B2A1F"), Xform(translation: V3(bx - 0.0029, -0.022, sz * 0.00066)), to: "blade", lods: 0...0)
        }
        // Clamp and plunger.
        rig.add(Prim.roundedBox(V3(0.013, 0.011, 0.011), radius: 0.0018, bevelSegments: 1, material: cast), Xform(translation: V3(bx - 0.004, 0.0255, 0)), to: "blade")
        let (pl, plx) = CordlessKit.rod(V3(bx - 0.004, 0.030, 0), Y, radius: 0.0034, length: 0.014, bevel: 0.0005, segments: 14, material: "metal.chrome")
        rig.add(pl, plx, to: "blade")
        rig.add(Prim.roundedBox(V3(0.006, 0.018, 0.0028), radius: 0.0011, bevelSegments: 1, material: trim),
                Xform(translation: V3(bx - 0.006, 0.0225, 0.0068), rotation: simd_quatf(degrees: -12, axis: Z)), to: "blade", lods: 0...0)

        groundAO(&rig, height: 0.02, floor: 0.55)
        CordlessKit.shift(&rig, by: V3(Self.shiftX, 0, 0))
        rig.states = [RigState("idle"), RigState("running", ["blade": 0.008, "trigger": triggerTravel])]
        return rig
    }
}
