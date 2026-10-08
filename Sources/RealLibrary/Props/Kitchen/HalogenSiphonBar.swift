import simd
import Foundation

/// Two-station halogen beam siphon bar (Bonmac class) as found on cafe counters: brushed stainless
/// chassis 560 x 150 x 380 mm, top deck with two aluminum burner cups (square vents, recessed halogen
/// lens) on chrome horseshoe bases, chrome siphon stands with black turned handles and bent arms whose
/// screw clamps hold clear glass upper globes. Front: per station a finger-guarded cooling fan and a
/// keypad panel with a red four-digit LED display and nine keys (up, down, output set, time set, timer
/// start, heat, brew, keep warm, stop); a brand badge plate and a red magnetic kitchen timer on its cord.
/// Every key is a part that slides 1.8 mm in when tapped. Heat keys light their burner and display;
/// stop keys clear them.
public struct HalogenSiphonBar: RealArticulated {
    public static let id = "halogen-siphon-bar"
    public static let summary = "Two-station halogen beam siphon heater: stainless box with keypads, fans and badge, aluminum burner cups, chrome stands holding glass globes; tappable keys."
    public static let tags = ["prop", "kitchen", "appliance", "articulated", "electronics", "metal", "glass"]
    public static let budget = 14800
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 18, elevation: 14, studio: true)

    /// Chassis width, height, depth (m).
    public var body = V3(0.56, 0.15, 0.38)
    /// Chassis front and sides.
    public var shell: MaterialKey = "metal.stainless-smudged"
    /// Top deck plate.
    public var deck: MaterialKey = "metal.aluminum-brushed:D2C9B2"
    /// Burner cup metal.
    public var cup: MaterialKey = "metal.satin-aluminum"
    /// Stand chrome.
    public var chrome: MaterialKey = "metal.chrome"
    /// Handle plastic.
    public var handle: MaterialKey = "plastic.gloss:121212"
    /// Glass globes.
    public var glass: MaterialKey = "glass.clear"
    /// Key travel when pressed (m).
    public var keyTravel: Float = 0.0018
    /// Time shown on the displays when on.
    public var readout = "0130"
    public init() {}

    static let keyNames = ["up", "down", "out", "time", "timer", "heat", "brew", "warm", "stop"]

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3])
        let W = body.x, H = body.y, D = body.z, zf = D / 2
        let dark: MaterialKey = "plastic.matte:1E2022"
        let panelMat: MaterialKey = "plastic.matte:3A3D40"
        let fz = V3(0, 0, 1), ux = V3(1, 0, 0), uy = V3(0, 1, 0)
        let stations: [Float] = [-0.14, 0.14]
        let cupZ: Float = -0.03, standZ: Float = 0.085

        // MARK: chassis
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let bs = l == 0 ? 2 : 1
            m.add(Prim.roundedBox(V3(W, H - 0.004, D), radius: 0.006, bevelSegments: bs, material: shell), Xform(translation: V3(0, (H - 0.004) / 2 + 0.002, 0)))
            // Top deck plate with a folded front lip.
            m.add(Prim.roundedBox(V3(W + 0.004, 0.003, D + 0.004), radius: 0.0012, bevelSegments: 1, material: deck), Xform(translation: V3(0, H - 0.0005, 0.001)))
            // Rubber feet.
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                m.add(Prim.cylinder(radius: 0.012, height: 0.004, bevel: 0.001, segments: l == 0 ? 12 : 6, bevelSegments: 1, material: "rubber"),
                      Xform(translation: V3(sx * (W / 2 - 0.03), 0, sz * (zf - 0.03))))
            }}
            for (si, xs) in stations.enumerated() {
                // Fan: dark square recess, hub, blades, wire finger guard, four screws.
                let fc = V3(xs - 0.075, 0.105, zf)
                m.add(Prim.roundedBox(V3(0.062, 0.062, 0.002), radius: 0.004, bevelSegments: 1, material: dark), Xform(translation: fc + V3(0, 0, 0.0004)))
                m.add(Prim.cylinder(radius: 0.012, height: 0.003, bevel: 0.001, segments: l == 0 ? 16 : 8, bevelSegments: 1, material: "plastic.matte:2A2A2A"),
                      Xform(translation: fc + V3(0, 0, -0.001), rotation: simd_quatf(degrees: 90, axis: ux)))
                if l == 0 {
                    var blades = Surface(material: "plastic.matte:262626")
                    for k in 0..<7 {
                        let a = Float(k) / 7 * 2 * .pi
                        let d = V3(cos(a), sin(a), 0), t = V3(-sin(a), cos(a), 0)
                        BedsideKit.quad2(&blades, fc + V3(0, 0, 0.0002), d, t, V2(0.012, -0.004), V2(0.027, -0.009), V2(0.027, 0.004), V2(0.012, 0.004))
                    }
                    blades.computeTangents()
                    m.add(blades)
                    var guardS = Surface(material: chrome)
                    for r: Float in [0.012, 0.021, 0.029] {
                        let ring = (0...24).map { i -> V3 in let a = Float(i) / 24 * 2 * .pi; return fc + V3(cos(a) * r, sin(a) * r, 0.006) }
                        guardS.append(Prim.tube(ring, radii: ring.map { _ in 0.0009 }, sides: 3, seamTile: 0.01, material: chrome))
                    }
                    for s: Float in [-1, 1] {
                        let p = [fc + V3(-0.03, -0.03 * s, 0.003), fc + V3(-0.02, -0.02 * s, 0.006), fc + V3(0.02, 0.02 * s, 0.006), fc + V3(0.03, 0.03 * s, 0.003)]
                        guardS.append(Prim.tube(p, radii: p.map { _ in 0.0011 }, sides: 3, seamTile: 0.01, material: chrome))
                    }
                    m.add(guardS)
                    for sx: Float in [-1, 1] { for sy: Float in [-1, 1] {
                        m.add(Prim.cylinder(radius: 0.0032, height: 0.0018, bevel: 0.0008, segments: 6, bevelSegments: 1, material: chrome),
                              Xform(translation: fc + V3(sx * 0.031, sy * 0.031, 0.0004), rotation: simd_quatf(degrees: 90, axis: ux)))
                    }}
                }
                // Keypad panel.
                let pc = V3(xs - 0.05, 0.042, zf + 0.0012)
                m.add(Prim.roundedBox(V3(0.15, 0.064, 0.0026), radius: 0.003, bevelSegments: 1, material: panelMat), Xform(translation: pc))
                let face = pc.z + 0.0013
                m.add(Prim.roundedBox(V3(0.05, 0.019, 0.0012), radius: 0.001, bevelSegments: 1, material: "plastic.gloss:0C0C0C"), Xform(translation: V3(pc.x - 0.04, pc.y + 0.017, face)))
                if l == 0 {
                    // Printed captions above the lower key row and beside the column keys, small status LEDs.
                    var cap = Surface(material: "plastic.matte:D8D8D2")
                    for k in 0..<5 {
                        cap.append(BedsideKit.caption([2], origin: V3(pc.x - 0.064 + Float(k) * 0.026, pc.y - 0.012, face + 0.0001), u: ux, v: uy, height: 0.003, material: "plastic.matte:D8D8D2"))
                    }
                    m.add(cap)
                    var leds = Surface(material: "plastic.matte:4A2020")
                    for k in 0..<5 {
                        BedsideKit.bar(&leds, V3(pc.x - 0.054 + Float(k) * 0.026, pc.y - 0.006, face + 0.0001), ux, uy, -0.001, -0.001, 0.001, 0.001)
                    }
                    leds.computeTangents()
                    m.add(leds)
                }
                // Badge on the right station, magnetic timer on the left one.
                if si == 1 {
                    let bc = V3(xs + 0.065, 0.11, zf + 0.0012)
                    m.add(Prim.roundedBox(V3(0.09, 0.044, 0.0024), radius: 0.003, bevelSegments: 1, material: "metal.chrome"), Xform(translation: bc))
                    m.add(Prim.roundedBox(V3(0.084, 0.038, 0.0012), radius: 0.002, bevelSegments: 1, material: "plastic.gloss:101418"), Xform(translation: bc + V3(0, 0, 0.0012)))
                    if l == 0 {
                        m.add(BedsideKit.caption([7], origin: bc + V3(-0.031, -0.008, 0.0019), u: ux, v: uy, height: 0.012, material: "metal.chrome"))
                        m.add(BedsideKit.caption([6, 1, 5, 3, 3], origin: bc + V3(-0.036, 0.008, 0.0019), u: ux, v: uy, height: 0.0035, material: "metal.chrome"))
                    }
                } else {
                    let tc = V3(xs - 0.015, 0.098, zf + 0.0005)
                    let toZ = simd_quatf(degrees: 90, axis: ux)
                    m.add(Prim.cylinder(radius: 0.034, height: 0.014, bevel: 0.004, segments: l == 0 ? 24 : 12, bevelSegments: bs, material: "plastic.gloss:C8141C"), Xform(translation: tc, rotation: toZ))
                    m.add(Prim.roundedBox(V3(0.034, 0.016, 0.002), radius: 0.001, bevelSegments: 1, material: "plastic.gloss:1A1A1A"), Xform(translation: tc + V3(0, 0.01, 0.0145)))
                    m.add(Prim.roundedBox(V3(0.03, 0.012, 0.0008), radius: 0.0008, bevelSegments: 1, material: "plastic.matte:8C9488"), Xform(translation: tc + V3(0, 0.01, 0.0156)))
                    if l == 0 { m.add(BedsideKit.segments("12:30", origin: tc + V3(-0.012, 0.0055, 0.0161), u: ux, v: uy, height: 0.008, stroke: 0.14, material: "plastic.matte:1A1A1A")) }
                    for k in 0..<3 {
                        m.add(Prim.cylinder(radius: 0.0055, height: 0.004, bevel: 0.0015, segments: l == 0 ? 12 : 6, bevelSegments: 1, material: "plastic.gloss:181818"),
                              Xform(translation: tc + V3(Float(k - 1) * 0.015, -0.011 - (k == 1 ? 0.003 : 0), 0.013), rotation: toZ))
                    }
                    // Lanyard cord hanging from the timer to the counter.
                    let cord = catmull([tc + V3(-0.012, -0.03, 0.012), tc + V3(-0.02, -0.06, 0.02), V3(xs - 0.05, 0.012, zf + 0.045), V3(xs - 0.065, 0.003, zf + 0.09), V3(xs - 0.02, 0.003, zf + 0.12)], per: l == 0 ? 5 : 2)
                    m.add(Prim.tube(cord, radii: cord.map { _ in 0.0022 }, sides: l == 0 ? 6 : 4, seamTile: 0.014, material: "fabric.nylon:151515"))
                }
                // Deck hardware per station: horseshoe base, burner cup, stand.
                let cc = V3(xs, H, cupZ)
                var shoe: [V2] = []
                for i in 0...12 { let a = Float(i) / 12 * .pi * 1.6 - .pi * 1.3; shoe.append(V2(cos(a) * 0.082, sin(a) * 0.082)) }
                shoe.append(V2(0.024, standZ - cupZ + 0.022)); shoe.append(V2(-0.024, standZ - cupZ + 0.022))
                let shoeOut = Shape2D.rounded(shoe.map { V2($0.x, -$0.y) }, radius: 0.012)
                m.add(Prim.extrude(shoeOut, depth: 0.008, bevel: 0.0025, bevelSegments: 1, material: chrome),
                      Xform(translation: cc + V3(0, 0.004, 0), rotation: simd_quatf(degrees: -90, axis: ux)))
                let prof: [V2] = [V2(0.046, 0.006), V2(0.049, 0.03), V2(0.056, 0.04), V2(0.064, 0.047), V2(0.066, 0.052), V2(0.066, 0.086),
                                  V2(0.063, 0.09), V2(0.058, 0.089), V2(0.056, 0.084), V2(0.054, 0.072), V2(0.0, 0.072)]
                m.add(Prim.lathe(prof, segments: l == 0 ? 24 : 12, seamTile: 0.2, material: cup), Xform(translation: cc))
                m.add(Prim.lathe([V2(0.047, 0.0), V2(0.047, 0.008)], segments: l == 0 ? 32 : 12, seamTile: 0.2, material: "metal.anodized-black"), Xform(translation: cc))
                m.add(Prim.cylinder(radius: 0.052, height: 0.002, bevel: 0.0005, segments: l == 0 ? 32 : 12, bevelSegments: 1, material: "plastic.gloss:17140F"), Xform(translation: cc + V3(0, 0.0725, 0)))
                if l == 0 {
                    var vents = Surface(material: dark)
                    for k in 0..<10 {
                        let a = (Float(k) + 0.5) / 10 * 2 * .pi
                        let n = V3(sin(a), 0, cos(a)), t = V3(cos(a), 0, -sin(a))
                        BedsideKit.bar(&vents, cc + n * 0.0664 + V3(0, 0.072, 0), t, uy, -0.0035, -0.0035, 0.0035, 0.0035)
                    }
                    vents.computeTangents()
                    m.add(vents)
                }
                // Stand: chrome foot, black turned handle, chrome rod bent back over the cup.
                let sb = V3(xs, H + 0.012, standZ)
                m.add(Prim.lathe([V2(0.026, 0), V2(0.024, 0.006), V2(0.012, 0.012), V2(0.009, 0.02), V2(0.0, 0.02)], segments: l == 0 ? 24 : 10, seamTile: 0.1, material: chrome), Xform(translation: sb))
                m.add(Prim.lathe([V2(0.011, 0.02), V2(0.014, 0.05), V2(0.0155, 0.08), V2(0.0155, 0.084), V2(0.0138, 0.088), V2(0.0138, 0.092), V2(0.0155, 0.096),
                                  V2(0.0145, 0.14), V2(0.011, 0.17), V2(0.0, 0.17)], segments: l == 0 ? 16 : 8, seamTile: 0.1, material: handle), Xform(translation: sb))
                m.add(Prim.lathe([V2(0.0141, 0.087), V2(0.0141, 0.093)], segments: l == 0 ? 20 : 10, seamTile: 0.1, material: chrome), Xform(translation: sb))
                m.add(Prim.lathe([V2(0.0105, 0.168), V2(0.0098, 0.182), V2(0.0066, 0.19), V2(0.0, 0.19)], segments: l == 0 ? 16 : 8, seamTile: 0.1, material: chrome), Xform(translation: sb))
                let top: Float = 0.46
                let rod = catmull([sb + V3(0, 0.185, 0), V3(xs, top - 0.05, standZ), V3(xs, top - 0.01, standZ - 0.008), V3(xs, top, standZ - 0.035), V3(xs, top, cupZ + 0.04), V3(xs, top, cupZ + 0.017)], per: l == 0 ? 4 : 2)
                m.add(Prim.tube(rod, radii: rod.map { _ in 0.0052 }, sides: l == 0 ? 8 : 5, seamTile: 0.03, material: chrome))
                // Screw clamp ring with thumbscrew around the globe neck.
                let gc = V3(xs, top, cupZ)
                m.add(Prim.torus(major: 0.0145, minor: 0.0035, segments: l == 0 ? 14 : 8, sides: 5, material: chrome), Xform(translation: gc))
                m.add(Prim.cylinder(radius: 0.0025, height: 0.022, bevel: 0.0005, segments: 8, bevelSegments: 1, material: chrome),
                      Xform(translation: gc + V3(0.016, 0, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
                m.add(Prim.cylinder(radius: 0.0065, height: 0.006, bevel: 0.0015, segments: l == 0 ? 14 : 8, bevelSegments: 1, material: "metal.anodized-black"),
                      Xform(translation: gc + V3(0.036, 0, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
                // Glass upper globe: sphere, short neck, long stem down toward the burner.
                var gp: [V2] = [V2(0.0075, top - 0.11), V2(0.0078, top - 0.02), V2(0.0105, top + 0.004), V2(0.0115, top + 0.012)]
                let r: Float = 0.066, cy = top + 0.012 + r * 0.92
                for i in 1...10 { let a = -Float.pi / 2 + 0.4 + Float(i) / 10 * (.pi - 0.55); gp.append(V2(cos(a) * r, cy + sin(a) * r)) }
                gp.append(V2(0.026, cy + r * 0.985)); gp.append(V2(0.0265, cy + r + 0.006)); gp.append(V2(0.0285, cy + r + 0.008))
                m.add(Prim.lathe(gp, segments: l == 0 ? 20 : 10, seamTile: 0.3, material: glass), Xform(translation: V3(xs, 0, cupZ)))
                m.add(Prim.torus(major: 0.0098, minor: 0.0016, segments: l == 0 ? 16 : 8, sides: 5, material: "rubber"), Xform(translation: V3(xs, top - 0.01, cupZ)))
            }
            // Vent holes along the rear of the deck.
            if l == 0 {
                var holes = Surface(material: dark)
                for k in 0..<22 {
                    BedsideKit.bar(&holes, V3(-0.23 + Float(k) * 0.022, H + 0.0011, -zf + 0.02), ux, V3(0, 0, -1), -0.0025, -0.0025, 0.0025, 0.0025)
                }
                holes.computeTangents()
                m.add(holes)
                // Coffee drip stain on the deck (story).
                m.add(Prim.cylinder(radius: 0.011, height: 0.0004, bevel: 0.0001, segments: 14, bevelSegments: 1, material: "plastic.matte:4A3426"),
                      Xform(translation: V3(0.03 + rng.float(-0.01...0.01), H + 0.0011, 0.11)))
            }
            rig.base[l] = m
        }

        // MARK: keys (tappable) and displays
        let keyLayout: [(String, Float, Float, MaterialKey)] = [
            ("up", 0.012, 0.018, "plastic.gloss:E8962A"), ("down", 0.012, -0.002, "plastic.gloss:5FA36E"),
            ("out", 0.05, 0.018, "plastic.gloss:ECECE6"), ("time", 0.05, -0.002, "plastic.gloss:ECECE6"),
            ("timer", -0.064, -0.02, "plastic.gloss:ECECE6"), ("heat", -0.038, -0.02, "plastic.gloss:ECECE6"),
            ("brew", -0.012, -0.02, "plastic.gloss:ECECE6"), ("warm", 0.014, -0.02, "plastic.gloss:ECECE6"),
            ("stop", 0.04, -0.02, "plastic.gloss:ECECE6"),
        ]
        var states = [RigState("idle")]
        for (si, xs) in stations.enumerated() {
            let side = si == 0 ? "left" : "right"
            let pc = V3(xs - 0.05, 0.042, zf + 0.0025)
            for (name, kx, ky, mat) in keyLayout {
                let c = V3(pc.x + kx, pc.y + ky, pc.z + 0.002)
                let part = "\(side)-\(name)"
                rig.part(part, pivot: c, joint: .slide(axis: -fz, 0...keyTravel, duration: 0.12))
                rig.add(Prim.roundedBox(V3(0.016, 0.012, 0.004), radius: 0.0018, bevelSegments: 1, material: mat), Xform(translation: c), to: part, lods: 0...0)
                rig.add(Prim.roundedBox(V3(0.016, 0.012, 0.004), radius: 0.0018, bevelSegments: 1, material: mat), Xform(translation: c), to: part, lods: 1...1)
                var g = Surface(material: "plastic.matte:2A2A2A")
                let o = c + V3(0, 0, 0.0021)
                switch name {
                case "up": BedsideKit.quad2(&g, o, ux, uy, V2(-0.0035, -0.0025), V2(0.0035, -0.0025), V2(0.0003, 0.003), V2(-0.0003, 0.003))
                case "down": BedsideKit.quad2(&g, o, ux, uy, V2(-0.0003, -0.003), V2(0.0003, -0.003), V2(0.0035, 0.0025), V2(-0.0035, 0.0025))
                default:
                    g.append(BedsideKit.caption([2], origin: o + V3(-0.0045, 0.0005, 0), u: ux, v: uy, height: 0.0028, material: "plastic.matte:2A2A2A"))
                    if name == "out" || name == "time" || name == "timer" { g.append(BedsideKit.caption([3], origin: o + V3(-0.0055, -0.0035, 0), u: ux, v: uy, height: 0.0028, material: "plastic.matte:2A2A2A")) }
                }
                g.computeTangents()
                rig.add(g, to: part, lods: 0...0)
            }
            // Display digits and burner glow: off / on.
            let disp = "\(side)-display"
            let dc = V3(pc.x - 0.04, pc.y + 0.017, pc.z + 0.0006)
            rig.part(disp, pivot: dc, joint: .fixed, options: 2)
            rig.add(BedsideKit.segments("8888", origin: dc + V3(-0.019, -0.0055, 0), u: ux, v: uy, height: 0.011, stroke: 0.15, material: "plastic.matte:2A0A0A"), to: disp, option: 0, lods: 0...0)
            rig.add(BedsideKit.segments(readout, origin: dc + V3(-0.019, -0.0055, 0), u: ux, v: uy, height: 0.011, stroke: 0.15, material: "emissive.led-red"), to: disp, option: 1)
            let glow = "\(side)-burner"
            let gc = V3(xs, H + 0.0748, cupZ)
            rig.part(glow, pivot: gc, joint: .fixed, options: 2)
            rig.add(Prim.cylinder(radius: 0.028, height: 0.0008, bevel: 0.0002, segments: 20, bevelSegments: 1, material: "glass.lamp"), Xform(translation: gc + V3(0, -0.0016, 0)), to: glow, option: 1)
            rig.lights.append(RigLight(name: "\(side)-halogen", kind: .point, part: glow, option: 1, position: gc + V3(0, 0.03, 0),
                                       color: V3(1.0, 0.72, 0.42), intensity: 30, attenuationRadius: 0.6))
            states.append(RigState("\(side)-heating", ["\(side)-heat": keyTravel], options: [disp: 1, glow: 1]))
            states.append(RigState("\(side)-stopped", ["\(side)-stop": keyTravel], options: [disp: 0, glow: 0]))
            // Every other key gets a pressed state so a tap moves it.
            for (name, _, _, _) in keyLayout where name != "heat" && name != "stop" {
                states.append(RigState("\(side)-\(name)-pressed", ["\(side)-\(name)": keyTravel], options: [disp: 1]))
            }
        }
        states.append(RigState("both-heating", ["left-heat": keyTravel, "right-heat": keyTravel], options: ["left-display": 1, "right-display": 1, "left-burner": 1, "right-burner": 1]))
        rig.states = states

        groundAO(&rig, height: 0.05, floor: 0.6)
        return rig
    }
}
