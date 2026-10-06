import simd
import Foundation

/// Generic 18V class cordless 1/2 in drill/driver standing on its 2 Ah slide-on pack (about 200 mm long,
/// 232 mm tall, 77 mm wide): teal clamshell motor housing with rear vents and Torx screws, black rear cap,
/// pistol grip with a pebbled rubber overmold, variable speed trigger, forward/reverse rocker, 2-speed
/// slider on top, 20-position clutch ring with tick marks, 13 mm keyless chuck (ribbed sleeve, steel nose,
/// three jaws), LED work light in the foot under the trigger, steel belt clip, slide-on pack with release
/// button and fuel gauge. Chuck axis +X.
///
/// Rig: `chuck` (hinge about X through the chuck axis, 0...360, the game spins it), `trigger` (slide
/// into the grip, 0...8 mm), `clutch` (hinge about X, 0...342), `bit` on `chuck` (options 0 none,
/// 1 3/16 in TiN twist drill, 2 #2 Phillips power bit), `led` (option 1 lit).
public struct CordlessDrill: RealArticulated {
    public static let id = "cordless-drill"
    public static let summary = "18V class cordless 1/2 in drill/driver standing on its slide-on battery: teal and black housing, rubber overmold grip, trigger, keyless chuck, clutch ring."
    public static let tags = ["prop", "workshop", "tool", "handheld", "articulated", "plastic", "rubber", "metal"]
    public static let budget = 11_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 150, elevation: 16, distance: 0.7, studio: true)

    /// Housing color (sRGB hex, `plastic.tool`).
    public var bodyColor: UInt32 = CordlessKit.bodyColor
    /// Chuck axis height above the floor (m).
    public var axisHeight: Float = 0.188
    /// Trigger travel in the running state (m).
    public var triggerTravel: Float = 0.008
    /// Exposed length of the 3/16 in twist drill bit from the chuck nose (m).
    public var drillBitReach: Float = 0.0495
    /// Exposed length of the #2 Phillips power bit from the chuck nose (m).
    public var driverBitReach: Float = 0.034
    public init() {}

    /// X of the chuck nose face.
    static let noseX: Float = 0.1135
    /// Asset-space shift applied after building (centers the bounds on X).
    static let shiftX: Float = -0.017

    /// Tip of the bit for `option` (0 none: the chuck nose center, 1 twist drill, 2 Phillips), asset space at rest.
    public func bitTip(option: Int) -> V3 {
        let reach: Float = option == 1 ? drillBitReach : (option == 2 ? driverBitReach : 0)
        return V3(Self.noseX + reach + Self.shiftX, axisHeight, 0)
    }
    /// Center of the pistol grip (palm contact), asset space.
    public var gripCenter: V3 { V3(-0.028 + Self.shiftX, 0.118, 0) }
    /// Chuck spin axis: a point on it (chuck rear face) and the unit direction (+X).
    public var chuckAxis: (origin: V3, direction: V3) { (V3(0.066 + Self.shiftX, axisHeight, 0), V3(1, 0, 0)) }

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3])
        let body = CordlessKit.housing(bodyColor), trim = CordlessKit.tool(CordlessKit.trimColor)
        let grip = CordlessKit.grip, slotK = CordlessKit.slot
        let yc = axisHeight
        let X = V3(1, 0, 0), Y = V3(0, 1, 0), Z = V3(0, 0, 1)
        func smooth(_ a: Float, _ b: Float, _ x: Float) -> Float { let t = min(max((x - a) / (b - a), 0), 1); return t * t * (3 - 2 * t) }

        // Grip axis: bottom (foot) slightly forward of the top.
        let gy0: Float = 0.074, gy1: Float = 0.172
        func gripX(_ y: Float) -> Float { -0.019 - 0.017 * (y - gy0) / (gy1 - gy0) }
        // (y, depth along X, width along Z)
        let gripSt: [(Float, Float, Float)] = [(0.072, 0.064, 0.052), (0.080, 0.053, 0.041), (0.094, 0.0475, 0.0365), (0.115, 0.0455, 0.0352),
                                               (0.135, 0.0465, 0.036), (0.150, 0.050, 0.039), (0.162, 0.057, 0.045), (0.174, 0.068, 0.054)]
        // Housing sections along X: (x, height, width).
        let houseSt: [(Float, Float, Float)] = [(-0.068, 0.054, 0.052), (-0.064, 0.0605, 0.0585), (-0.052, 0.0645, 0.0605), (-0.026, 0.0645, 0.0605),
                                                (-0.004, 0.0625, 0.0585), (0.014, 0.058, 0.0555), (0.032, 0.0535, 0.0525), (0.046, 0.0505, 0.050)]

        for l in 0..<2 {
            let lite = l == 1
            let n = lite ? 16 : 32
            var m = Model(name: Self.id)

            // MARK: battery pack, latch end forward (+X), under the foot.
            m.add(CordlessKit.battery(lite: lite, bodyColor: bodyColor), Xform(translation: V3(-0.016, 0, 0)))

            // MARK: foot (battery receiver): teal top, black skirt.
            m.add(Prim.roundedBox(V3(0.101, 0.012, 0.070), radius: 0.004, bevelSegments: lite ? 1 : 2, material: trim), Xform(translation: V3(-0.0145, 0.0565, 0)))
            m.add(Prim.superellipsoid(V3(0.103, 0.030, 0.068), exponent: 5, subdivisions: lite ? 4 : 6, material: CordlessKit.worn(bodyColor)), Xform(translation: V3(-0.0135, 0.0705, 0)))

            // MARK: pistol grip: teal core, rubber overmold over the back and sides.
            let gOut = Shape2D.superellipse(1, 1, exponent: 2.6, segments: n)
            let core = gripSt.map { (y, d, w) in Prim.ring(gOut.map { V2($0.x * d, $0.y * w) }, y: y, offset: V3(gripX(y), 0, 0)) }
            m.add(Prim.loft(core, capStart: true, capEnd: true, material: body))
            let rub = gripSt.dropFirst().dropLast().map { (y, d, w) -> [V3] in
                Prim.ring(gOut.map { p -> V2 in
                    let k = p.x / sqrt(p.x * p.x + p.y * p.y)          // +1 at the front (trigger side)
                    let s = 1 + 0.085 * (1 - smooth(-0.15, 0.4, k)) - 0.06 * smooth(0.4, 0.7, k)
                    return V2(p.x * d * s, p.y * w * s)
                }, y: y, offset: V3(gripX(y) - 0.0008, 0, 0))
            }
            m.add(Prim.loft([rub[0].map { V3($0.x * 0.985 + gripX(0.084) * 0.015, 0.0835, $0.z * 0.97) }] + rub +
                            [rub[rub.count - 1].map { V3($0.x * 0.985 + gripX(0.152) * 0.015, 0.1525, $0.z * 0.97) }], material: grip))

            // MARK: motor housing (teal clamshell) and black rear cap.
            let hOut = Shape2D.superellipse(1, 1, exponent: 2.7, segments: n)
            let house = houseSt.map { (x, h, w) in CordlessKit.section(hOut.map { V2($0.x * h, $0.y * w) }, V3(x, yc, 0), Y, Z) }
            m.add(Prim.loft(house, capStart: false, capEnd: true, material: body))
            let capSt: [(Float, Float, Float)] = [(-0.0845, 0.030, 0.029), (-0.0825, 0.044, 0.042), (-0.078, 0.053, 0.051), (-0.071, 0.0585, 0.0565), (-0.0655, 0.0605, 0.0585)]
            m.add(Prim.loft(capSt.map { (x, h, w) in CordlessKit.section(hOut.map { V2($0.x * h, $0.y * w) }, V3(x, yc, 0), Y, Z) },
                            capStart: true, capEnd: true, material: trim))
            // Rubber bumper ring at the back of the housing.
            m.add(Prim.loft([(-0.0662, 0.0612, 0.0592), (-0.0640, 0.0632, 0.0612), (-0.0600, 0.0640, 0.0620), (-0.0578, 0.0635, 0.0615)].map { (x, h, w) in
                CordlessKit.section(hOut.map { V2($0.x * h, $0.y * w) }, V3(x, yc, 0), Y, Z) }, material: grip))
            // Gear case collar.
            m.add(CordlessKit.spinX([V2(0.044, 0.0236), V2(0.046, 0.0245), V2(0.0495, 0.0245)], center: V3(0, yc, 0), segments: n, material: trim))

            // MARK: forward/reverse rocker through the top of the grip.
            m.add(Prim.roundedBox(V3(0.011, 0.0085, 0.056), radius: 0.0032, bevelSegments: 1, material: trim), Xform(translation: V3(-0.0125, 0.1615, 0.0015)))

            // MARK: 2-speed slider on top.
            m.add(Prim.roundedBox(V3(0.030, 0.003, 0.0135), radius: 0.0012, bevelSegments: 1, material: slotK), Xform(translation: V3(-0.010, yc + 0.0318, 0)))
            m.add(Prim.roundedBox(V3(0.0115, 0.0068, 0.0118), radius: 0.0026, bevelSegments: 1, material: trim), Xform(translation: V3(-0.0185, yc + 0.0345, 0)))

            // MARK: LED lens in the foot front, aimed up the chuck axis (part `led`).
            // MARK: belt clip on the -Z side of the foot, up along the grip.
            let clipPath = catmull([V3(-0.030, 0.064, -0.0358), V3(-0.032, 0.080, -0.0330), V3(-0.036, 0.100, -0.0255), V3(-0.040, 0.124, -0.0228), V3(-0.0415, 0.134, -0.0236)], per: lite ? 2 : 3)
            m.add(Prim.sweep(Shape2D.roundedRect(0.014, 0.0019, radius: 0.0008, segments: 2), along: clipPath, up: X, material: "metal.powdercoat:1C1D1F"))
            m.add(Prim.roundedBox(V3(0.020, 0.012, 0.004), radius: 0.0015, bevelSegments: 1, material: trim), Xform(translation: V3(-0.030, 0.064, -0.0343)))

            if !lite {
                // Rear vents: slanted slots on both housing sides, and on the rear cap.
                for sz: Float in [-1, 1] {
                    CordlessKit.vents(&m, start: V3(-0.058, yc, sz * 0.0300), step: V3(0.0058, 0, 0), count: 5,
                                      along: simd_normalize(V3(0.25, 1, 0)), normal: V3(0, 0, sz), len: 0.024, width: 0.0022)
                    CordlessKit.vents(&m, start: V3(-0.0772, yc - 0.012, sz * 0.0262), step: V3(0, 0.006, 0), count: 5,
                                      along: X, normal: simd_normalize(V3(-0.35, 0, sz)), len: 0.008, width: 0.0018)
                }
                // Clamshell screws on the -Z half and the clip screw.
                for p in [V3(-0.044, yc - 0.002, -0.0301), V3(0.012, yc - 0.004, -0.0279), V3(-0.022, yc + 0.020, -0.0262)] {
                    CordlessKit.screw(&m, at: p, normal: V3(0, (p.y - yc) * 12, -1))
                }
                CordlessKit.screw(&m, at: V3(-0.030, 0.064, -0.0365), normal: V3(0, 0, -1), radius: 0.0031)
                CordlessKit.screw(&m, at: V3(-0.050, 0.070, -0.0338), normal: V3(0, 0, -1))
                // Clamshell parting line along the housing top and bottom, and down the grip front.
                let seamTop = houseSt.map { V3($0.0, yc + $0.1 / 2 + 0.0001, 0) }
                let seamBot = houseSt.filter { $0.0 > -0.004 }.map { V3($0.0, yc - $0.1 / 2 - 0.0001, 0) }
                let seamGrip = [0.080, 0.094, 0.106].map { (y: Float) -> V3 in
                    let d = gripSt.first { $0.0 >= y }!.1
                    return V3(gripX(y) + d / 2 + 0.0001, y, 0)
                }
                for path in [seamTop, seamBot, seamGrip] {
                    m.add(Prim.tube(path, radii: path.map { _ in 0.00045 }, sides: 4, seamTile: 0.02, material: slotK))
                }
                // Side badge on +Z.
                m.add(Prim.roundedBox(V3(0.034, 0.013, 0.0014), radius: 0.0013, bevelSegments: 1, material: trim), Xform(translation: V3(-0.016, yc + 0.003, 0.0299)))
                m.add(cuboid(V3(0.010, 0.0035, 0.0008), material: "paint.field-white"), Xform(translation: V3(-0.024, yc + 0.003, 0.0306)))
                m.add(cuboid(V3(0.012, 0.0035, 0.0008), material: body), Xform(translation: V3(-0.009, yc + 0.003, 0.0306)))
                // Slider ridges and gear marks (1 bar, 2 bars).
                for k in 0..<3 { m.add(cuboid(V3(0.0012, 0.0012, 0.010), material: trim),
                                       Xform(translation: V3(-0.0215 + Float(k) * 0.003, yc + 0.0381, 0))) }
                m.add(cuboid(V3(0.0012, 0.0004, 0.004), material: "paint.field-white"), Xform(translation: V3(-0.0215, yc + 0.0316, 0.010)))
                for dx: Float in [-0.0012, 0.0012] { m.add(cuboid(V3(0.0012, 0.0004, 0.004), material: "paint.field-white"), Xform(translation: V3(0.0015 + dx, yc + 0.0314, 0.010))) }
                // Clutch index arrow on the housing top.
                m.add(cuboid(V3(0.004, 0.0006, 0.0022), material: "paint.field-white"), Xform(translation: V3(0.0435, yc + 0.0254, 0)))
            }
            rig.base[l] = m
        }

        // MARK: trigger (slides into the grip along -X)
        rig.part("trigger", pivot: V3(-0.010, 0.135, 0), joint: .slide(axis: V3(-1, 0, 0), 0...0.010, duration: 0.25))
        let trigOutline = Shape2D.rounded([V2(-0.016, 0.1505), V2(0.0015, 0.1525), V2(0.0072, 0.1475), V2(0.0045, 0.1350),
                                           V2(0.0068, 0.1215), V2(0.0015, 0.1170), V2(-0.016, 0.1185)], radius: 0.0022, segments: 3)
        rig.add(Prim.extrude(trigOutline, depth: 0.0170, bevel: 0.0048, bevelSegments: 3, material: trim), to: "trigger", lods: 0...0)
        rig.add(Prim.extrude(trigOutline, depth: 0.0170, bevel: 0.0040, bevelSegments: 1, material: trim), to: "trigger", lods: 1...1)
        for k in 0..<5 {   // finger ridges
            rig.add(cuboid(V3(0.0012, 0.0011, 0.013), material: trim),
                    Xform(translation: V3(0.0052 - abs(Float(k) - 2) * 0.0003, 0.1295 + Float(k) * 0.0028, 0)), to: "trigger", lods: 0...0)
        }

        // MARK: clutch ring (hinge about X)
        rig.part("clutch", pivot: V3(0.048, yc, 0), joint: .hinge(axis: X, 0...342, duration: 0.8))
        for l in 0..<2 {
            let n = l == 0 ? 36 : 18
            rig.add(CordlessKit.spinX([V2(0.0485, 0.0254), V2(0.0495, 0.0263), V2(0.0545, 0.0265), V2(0.0555, 0.0270), V2(0.0632, 0.0270), V2(0.0645, 0.0255)],
                                      center: V3(0, yc, 0), segments: n, ribs: l == 0 ? 24 : 0, ribDepth: 0.0011, ribRange: 0.0555...0.0632,
                                      material: trim), to: "clutch", lods: l...l)
        }
        for k in 0..<20 {   // clutch numbers as ticks, long tick every 5
            let a = Float(k) / 20 * 2 * .pi, long = k % 5 == 0
            rig.add(cuboid(V3(long ? 0.0046 : 0.0028, 0.0004, 0.0009), material: "paint.field-white"),
                    Xform(translation: V3(0.0518, yc + 0.0266 * cos(a), 0.0266 * sin(a)), rotation: simd_quatf(angle: a, axis: X)), to: "clutch", lods: 0...0)
        }

        // MARK: keyless chuck (hinge about X, spun by the game)
        let c0: Float = 0.066, nose = Self.noseX
        rig.part("chuck", pivot: V3(c0, yc, 0), joint: .hinge(axis: X, 0...360, duration: 0.6))
        for l in 0..<2 {
            let n = l == 0 ? 32 : 16
            let C = V3(0, yc, 0)
            // Rear collar and front sleeve: black, ribbed.
            rig.add(CordlessKit.spinX([V2(c0 - 0.0005, 0.0185), V2(c0 + 0.001, 0.0212), V2(0.0775, 0.0214), V2(0.0785, 0.0195)], center: C, segments: n,
                                      ribs: l == 0 ? 20 : 0, ribDepth: 0.0009, ribRange: (c0 + 0.002)...0.077, material: trim), to: "chuck", lods: l...l)
            rig.add(CordlessKit.spinX([V2(0.0785, 0.0192), V2(0.0800, 0.0207), V2(0.0960, 0.0206), V2(0.1010, 0.0192), V2(0.1055, 0.0165), V2(0.1068, 0.0148)],
                                      center: C, segments: n, ribs: l == 0 ? 36 : 0, ribDepth: 0.0010, ribRange: 0.0805...0.0985, material: trim), to: "chuck", lods: l...l)
            // Steel nose with the jaw bore.
            rig.add(CordlessKit.spinX([V2(0.1062, 0.0150), V2(0.1095, 0.0136), V2(0.1125, 0.0108), V2(nose, 0.0092)], center: C, segments: n,
                                      capEnd: false, material: "metal.chrome"), to: "chuck", lods: l...l)
            rig.add(CordlessKit.spinX([V2(nose, 0.0092), V2(nose - 0.0003, 0.0060), V2(nose - 0.004, 0.0058)], center: C, segments: n, capStart: false,
                                      material: "metal.stainless"), to: "chuck", lods: l...l)
        }
        // Jaws: three hardened steel jaws converging in the bore.
        for k in 0..<3 {
            let a = Float(k) / 3 * 2 * .pi + 0.5
            let q = simd_quatf(angle: a, axis: X) * simd_quatf(degrees: 15, axis: V3(0, 0, -1))
            rig.add(cuboid(V3(0.012, 0.0030, 0.0034), material: "metal.stainless"),
                    Xform(translation: V3(nose - 0.0045, yc, 0) + simd_quatf(angle: a, axis: X).act(V3(0, 0.0047, 0)), rotation: q), to: "chuck")
        }

        // MARK: bit on the chuck (option 0 none, 1 twist drill, 2 Phillips power bit)
        rig.part("bit", parent: "chuck", pivot: V3(c0, yc, 0), joint: .fixed, options: 3)
        for l in 0..<2 {
            let n = l == 0 ? 20 : 10, steps = l == 0 ? 28 : 10
            // 3/16 in (4.76 mm) TiN twist drill: shank, two helical flutes, 118 degree point.
            let R: Float = 0.00238, f0 = nose + 0.002, f1 = nose + drillBitReach - 0.0014
            var drill = CordlessKit.spinX([V2(0.090, R), V2(f0, R)], center: V3(0, yc, 0), segments: n, capEnd: false, material: "metal.surgical-gold")
            var rings: [[V3]] = []
            for s in 0...steps {
                let x = f0 + (f1 - f0) * Float(s) / Float(steps), tw = (x - f0) / 0.024 * 2 * .pi
                rings.append((0..<n).map { k in
                    let a = Float(k) / Float(n) * 2 * .pi
                    let r = R * (1 - 0.36 * pow(abs(sin(a)), 3))
                    return V3(x, yc + r * cos(a + tw), r * sin(a + tw))
                })
            }
            let tipX = nose + drillBitReach
            rings.append(rings[rings.count - 1].map { V3(tipX - 0.0004, yc + ($0.y - yc) * 0.25, $0.z * 0.25) })
            drill.append(Prim.loft(rings, capStart: false, capEnd: true, material: "metal.surgical-gold"))
            rig.add(drill, to: "bit", option: 1, lods: l...l)

            // #2 Phillips 2 in power bit: 1/4 in hex, retention groove, torsion neck, four-wing tip.
            let hexR: Float = 0.00635 / 2 / cos(.pi / 6), dr = driverBitReach
            func hex(_ a: Float) -> Float { let s = Float.pi / 3; let t = (a.truncatingRemainder(dividingBy: s) + s).truncatingRemainder(dividingBy: s) - s / 2; return hexR * cos(Float.pi / 6) / cos(t) }
            func phil(_ a: Float, _ wing: Float, _ core: Float) -> Float { core + (wing - core) * pow(abs(cos(2 * a)), 8) }
            let prof: [(Float, (Float) -> Float)] = [
                (0.086, { hex($0) * 0.97 }), (0.0875, hex), (nose + 0.010, hex), (nose + 0.0108, { hex($0) * 0.80 }), (nose + 0.0122, { hex($0) * 0.80 }),
                (nose + 0.013, hex), (nose + dr - 0.016, hex), (nose + dr - 0.012, { _ in 0.0026 }), (nose + dr - 0.0075, { _ in 0.0023 }),
                (nose + dr - 0.0055, { phil($0, 0.0030, 0.0012) }), (nose + dr - 0.002, { phil($0, 0.0020, 0.0008) }), (nose + dr - 0.0002, { phil($0, 0.0007, 0.0004) })]
            let pr = prof.map { (x, f) in (0..<(n * 2)).map { k -> V3 in
                let a = Float(k) / Float(n * 2) * 2 * .pi
                return V3(x, yc + f(a) * cos(a), f(a) * sin(a))
            }}
            rig.add(Prim.loft(pr, capStart: true, capEnd: true, material: "metal.stainless"), to: "bit", option: 2, lods: l...l)
        }

        // MARK: LED work light in the foot front (option 1 lit)
        let ledP = V3(0.0372, 0.0745, 0), ledD = simd_normalize(V3(1, 0.95, 0))
        rig.part("led", pivot: ledP, joint: .fixed, options: 2)
        let (bez, bx) = CordlessKit.rod(ledP - ledD * 0.002, ledD, radius: 0.0052, length: 0.0024, bevel: 0.0007, segments: 16, material: trim)
        for o in 0..<2 {
            rig.add(bez, bx, to: "led", option: o)
            let (lens, lx) = CordlessKit.rod(ledP - ledD * 0.001, ledD, radius: 0.0034, length: 0.0019, bevel: 0.0006, segments: 16,
                                             material: o == 0 ? "glass.led-lens" : "emissive.bulb")
            rig.add(lens, lx, to: "led", option: o)
        }
        rig.lights = [RigLight(name: "work-light", kind: .spot(inner: 14, outer: 32), part: "led", option: 1, position: ledP + ledD * 0.004,
                               direction: ledD, color: V3(0.92, 0.95, 1), intensity: 60, attenuationRadius: 1.2)]

        groundAO(&rig, height: 0.03, floor: 0.55)
        _ = rng.float(0...1)
        CordlessKit.shift(&rig, by: V3(Self.shiftX, 0, 0))
        rig.states = [RigState("idle"),
                      RigState("running", ["trigger": triggerTravel, "chuck": 120], options: ["led": 1, "bit": 1]),
                      RigState("driver", ["clutch": 162], options: ["bit": 2]),
                      RigState("drill", ["clutch": 342], options: ["bit": 1])]
        return rig
    }
}
