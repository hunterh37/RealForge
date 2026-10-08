import simd
import Foundation

/// 45 ft class 3 southern pine distribution pole on a 12.47 kV wye three-phase line, 11.9 m above
/// grade: a tapered, checked, sun-greyed pole with a creosote-dark butt, a burned brand and an aluminum
/// tag at eye height, an 8 ft fir crossarm on galvanized braces with three porcelain pin insulators and
/// phase conductors A, B and C (ACSR stubs tied in), a neutral on a secondary spool rack, a 25 kVA
/// transformer hung on the field side, three fused cutouts and an arrester on a cutout arm, a ground
/// wire in its molding and a down guy with a yellow guard.
///
/// States: `normal`, and `damaged` (insulator B cracked, conductor B dropped off its tie and hanging,
/// cutout A dropped open with a blown fuse tube). Parts: `cutoutA/B/C` (door hinge 0...-120),
/// `insulatorB` and `conductorB` (options 0 normal, 1 failed). Repair-site attachment points are the
/// static `V3` constants below, in asset space (meters, base of the pole at the origin).
public struct DistributionPole: RealArticulated {
    public static let id = "distribution-pole"
    public static let summary = "45 ft class 3 wood distribution pole with a three-phase crossarm, pin insulators, neutral, 25 kVA transformer, three cutouts, an arrester and a guy wire."
    public static let tags = ["prop", "utility", "electrical", "articulated", "wood", "metal"]
    public static let budget = 15000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 8, distance: 1.0)

    // MARK: layout (asset space, meters)

    /// Pole height above grade.
    public static let height: Float = 11.9
    /// Top of the crossarm.
    public static let armY: Float = 11.55
    /// Phase positions along the arm (x).
    public static let phaseX: [Float] = [-1.07, 0.42, 1.07]
    /// Cutout arm height and cutout x positions (cutouts hang on the -Z, field side).
    public static let cutoutY: Float = 10.5
    public static let cutoutX: [Float] = [-0.42, 0, 0.42]
    /// Transformer center height.
    public static let transformerY: Float = 8.6

    // MARK: repair-site attachment points

    /// Conductor seat in the top groove of each pin insulator (A, B, C).
    public static let insulatorTopA = V3(-1.07, armY + 0.14, 0.2)
    public static let insulatorTopB = V3(0.42, armY + 0.14, 0.2)
    public static let insulatorTopC = V3(1.07, armY + 0.14, 0.2)
    /// Where the dropped conductor B end hangs in the damaged state.
    public static let conductorBDroppedEnd = V3(0.42, 7.2, 0.95)
    /// Pull ring of each cutout door (closed position), for the shotgun stick.
    public static let cutoutRingA = V3(-0.42, cutoutY + 0.29, -0.52)
    public static let cutoutRingB = V3(0, cutoutY + 0.29, -0.52)
    public static let cutoutRingC = V3(0.42, cutoutY + 0.29, -0.52)
    /// Fuse tube center of cutout A (link replacement).
    public static let cutoutTubeA = V3(-0.42, cutoutY + 0.06, -0.47)
    /// Transformer primary bushing terminal (jumper from cutout A, hot-line clamp site).
    public static let transformerPrimary = V3(0.06, transformerY + 0.62, -0.55)
    /// Neutral conductor on the spool rack (grounding-set clamp site).
    public static let neutralClamp = V3(0, armY - 1.6, 0.27)
    /// Pole ground wire at the bottom of its molding (ground end of the grounding set).
    public static let groundLead = V3(0.0, 0.3, 0.17)

    /// Lean of the pole (m at the top), from the seed if nil.
    public var leanX: Float = 0.04
    public var wood: MaterialKey = "wood.pole-pine"
    public var butt: MaterialKey = "wood.pole-creosote"
    public var arm: MaterialKey = "wood.crossarm-fir"
    public var steel: MaterialKey = "metal.galvanized"
    public var porcelain: MaterialKey = "ceramic.porcelain-gray"
    public var conductor: MaterialKey = "metal.acsr-strand"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 1)
        var m = Model(name: Self.id)
        let H = Self.height, rb: Float = 0.165, rt: Float = 0.11
        func r(_ y: Float) -> Float { rb + (rt - rb) * y / H }
        // Pole: tapered shaft, creosote butt sleeve, roof-cut top.
        m.add(turned([(0, 0), (rb, 0), (r(H * 0.5), H * 0.5), (rt, H - 0.05), (rt - 0.03, H), (0, H)], segments: 18, material: wood, grainVertical: true))
        m.add(Prim.lathe([V2(rb + 0.003, 0), V2(r(1.2) + 0.002, 1.2), V2(r(1.35) - 0.002, 1.35)], segments: 18, seamTile: 0.4, material: butt))
        // Drying checks.
        for _ in 0..<12 {
            let a = rng.float(0...6.28), y0 = rng.float(0.4...9), len = rng.float(0.8...2.8), d = V3(sin(a), 0, cos(a))
            m.add(cuboid(V3(0.007, len, 0.004), material: "wood.pole-creosote"), Xform(translation: V3(0, y0 + len / 2, 0) + d * (r(y0 + len / 2) - 0.0006), rotation: simd_quatf(angle: a, axis: .up)))
        }
        // Burned brand (10 ft from the butt): plant code, year, species and class rows.
        let by: Float = 1.25
        for row in 0..<3 {
            for k in 0..<5 {
                let a = -0.22 + Float(k) * 0.11, d = V3(sin(a), 0, cos(a))
                m.add(cuboid(V3(0.012, 0.022, 0.002), material: "plastic.matte:2A1E16"),
                      Xform(translation: V3(0, by + Float(row) * 0.035, 0) + d * (r(by) + 0.0004), rotation: simd_quatf(angle: a, axis: .up)))
            }
        }
        m.add(Prim.roundedBox(V3(0.1, 0.06, 0.003), radius: 0.004, bevelSegments: 1, material: "metal.aluminum-brushed"), Xform(translation: V3(0, 1.7, r(1.7) + 0.002)))
        // Ground wire molding on the +Z face down to grade.
        m.add(Prim.roundedBox(V3(0.03, 2.6, 0.012), radius: 0.004, bevelSegments: 1, material: "plastic.matte:2C2C2C"), Xform(translation: V3(0, 1.4, r(1.4) + 0.004)))
        m.add(Prim.tube([V3(0, 2.7, r(2.7) + 0.004), V3(0, 7.9, r(7.9) + 0.004)], radii: [0.003, 0.003], sides: 4, seamTile: 0.05, material: "metal.copper"))

        // Crossarm on the +Z face, two flat braces, through bolt.
        let aY = Self.armY, az = r(aY) + 0.045
        m.add(Prim.roundedBox(V3(2.44, 0.095, 0.095), radius: 0.008, bevelSegments: 1, material: arm), Xform(translation: V3(0, aY - 0.0475, az)))
        for s: Float in [-1, 1] {
            m.add(Prim.tube([V3(s * 0.7, aY - 0.1, az - 0.02), V3(0, aY - 0.72, r(aY - 0.72) + 0.01)], radii: [0.012, 0.012], sides: 4, seamTile: 0.1, material: steel))
        }
        hexBolt(&m, at: V3(0, aY - 0.05, az + 0.05), normal: V3(0, 0, 1), size: 0.03, material: steel)

        // Pin insulators A and C (static) and conductors A and C.
        func pinInsulator(broken: Bool) -> [Surface] {
            var sk = Prim.lathe([V2(0.018, 0.0), V2(0.076, 0.002), V2(0.077, 0.024), V2(0.068, 0.05), V2(0.048, 0.06)], segments: 16, material: porcelain)
            if broken {
                sk.deform { q in
                    let a = atan2(q.z, q.x), rr = simd_length(V2(q.x, q.z))
                    guard a > 0.3, a < 1.3, q.y < 0.04 else { return q }
                    let k = min(rr, 0.054); return V3(cos(a) * k, q.y, sin(a) * k)
                }
            }
            var out = [sk]
            out.append(Prim.lathe([V2(0.048, 0.06), V2(0.038, 0.075), V2(0.036, 0.09), V2(0.046, 0.108), V2(0.044, 0.122), V2(0.02, 0.128), V2(0, 0.126)],
                                  segments: 16, material: "ceramic.porcelain-black"))
            if broken {
                out.append(Prim.roundedBox(V3(0.03, 0.03, 0.02), radius: 0.006, bevelSegments: 1, material: "ceramic.porcelain-fracture").transformed(Xform(translation: V3(0.032, 0.018, 0.045))))
                out.append(Prim.tube([V3(0.04, 0.0, 0.065), V3(0.03, 0.05, 0.05), V3(0.025, 0.1, 0.035)], radii: [0.0012, 0.0012, 0.0012], sides: 3, seamTile: 0.05, material: "plastic.matte:111111"))
            }
            return out
        }
        func pin(_ x: Float) -> V3 { V3(x, aY, az) }
        for (i, x) in Self.phaseX.enumerated() where i != 1 {
            m.add(Prim.cylinder(radius: 0.013, height: 0.06, bevel: 0.002, segments: 8, material: steel), Xform(translation: pin(x)))
            for s in pinInsulator(broken: false) { m.add(s, Xform(translation: pin(x) + V3(0, 0.03, 0))) }
            m.add(Prim.tube([V3(x, aY + 0.142, az - 0.7), V3(x, aY + 0.145, az), V3(x, aY + 0.142, az + 0.7)], radii: [0.0051, 0.0051, 0.0051], sides: 6, seamTile: 0.03, material: conductor))
            // Tie wire wraps.
            m.add(Prim.torus(major: 0.02, minor: 0.002, segments: 10, sides: 3, material: "metal.aluminum-brushed"), Xform(translation: V3(x, aY + 0.145, az), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1))))
        }
        // Insulator B: part with options (0 intact, 1 cracked).
        let pB = pin(Self.phaseX[1])
        m.add(Prim.cylinder(radius: 0.013, height: 0.06, bevel: 0.002, segments: 8, material: steel), Xform(translation: pB))
        rig.part("insulatorB", pivot: pB, joint: Joint(.fixed), options: 2)
        for s in pinInsulator(broken: false) { rig.add(s, Xform(translation: pB + V3(0, 0.03, 0)), to: "insulatorB", option: 0) }
        for s in pinInsulator(broken: true) { rig.add(s, Xform(translation: pB + V3(0, 0.03, 0)), to: "insulatorB", option: 1) }
        // Conductor B: tied on top (0) or dropped and hanging off the arm toward the street (1).
        rig.part("conductorB", pivot: pB, joint: Joint(.fixed), options: 2)
        let xB = Self.phaseX[1]
        rig.add(Prim.tube([V3(xB, aY + 0.142, az - 0.7), V3(xB, aY + 0.145, az), V3(xB, aY + 0.142, az + 0.7)], radii: [0.0051, 0.0051, 0.0051], sides: 6, seamTile: 0.03, material: conductor), to: "conductorB", option: 0)
        rig.add(Prim.torus(major: 0.02, minor: 0.002, segments: 10, sides: 3, material: "metal.aluminum-brushed"), Xform(translation: V3(xB, aY + 0.145, az), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1))), to: "conductorB", option: 0)
        let drop = catmull([V3(xB, aY + 0.1, az - 0.7), V3(xB + 0.02, aY - 0.05, az - 0.05), V3(xB + 0.05, aY - 0.3, az + 0.15), V3(xB + 0.06, aY - 2.0, az + 0.6), Self.conductorBDroppedEnd], per: 6)
        rig.add(Prim.tube(drop, radii: drop.map { _ in 0.0051 }, sides: 6, seamTile: 0.03, material: conductor), to: "conductorB", option: 1)
        // Broken tie wire stub left on the insulator.
        rig.add(Prim.tube([V3(xB - 0.02, aY + 0.14, az), V3(xB - 0.05, aY + 0.17, az + 0.02)], radii: [0.002, 0.002], sides: 3, seamTile: 0.05, material: "metal.aluminum-brushed"), to: "conductorB", option: 1)

        // Neutral: secondary spool rack on the +Z face.
        let nY = aY - 1.6
        m.add(Prim.roundedBox(V3(0.05, 0.22, 0.012), radius: 0.003, bevelSegments: 1, material: steel), Xform(translation: V3(0, nY, r(nY) + 0.006)))
        m.add(Prim.roundedBox(V3(0.05, 0.012, 0.12), radius: 0.003, bevelSegments: 1, material: steel), Xform(translation: V3(0, nY + 0.1, r(nY) + 0.06)))
        m.add(Prim.roundedBox(V3(0.05, 0.012, 0.12), radius: 0.003, bevelSegments: 1, material: steel), Xform(translation: V3(0, nY - 0.1, r(nY) + 0.06)))
        m.add(Prim.lathe([V2(0.02, -0.075), V2(0.04, -0.075), V2(0.03, -0.04), V2(0.03, 0.04), V2(0.04, 0.075), V2(0.02, 0.075)], segments: 12, material: porcelain), Xform(translation: V3(0, nY, r(nY) + 0.1)))
        m.add(Prim.tube([V3(-0.8, nY + 0.03, r(nY) + 0.13), V3(0, nY + 0.03, r(nY) + 0.13), V3(0.8, nY + 0.03, r(nY) + 0.13)], radii: [0.0051, 0.0051, 0.0051], sides: 6, seamTile: 0.03, material: conductor))

        // Cutout arm on the -Z (field) side with three cutouts; arrester at the end.
        let cY = Self.cutoutY, cz = -(r(cY) + 0.045)
        m.add(Prim.roundedBox(V3(1.2, 0.09, 0.09), radius: 0.008, bevelSegments: 1, material: arm), Xform(translation: V3(0, cY - 0.045, cz)))
        let tilt = simd_quatf(angle: -20 * .pi / 180, axis: V3(1, 0, 0))
        for (i, x) in Self.cutoutX.enumerated() {
            let name = ["cutoutA", "cutoutB", "cutoutC"][i]
            let base = V3(x, cY - 0.25, cz - 0.27)
            func at(_ p: V3) -> V3 { base + tilt.act(p) }
            // Bracket from the arm to the body band.
            m.add(Prim.tube([V3(x, cY - 0.07, cz - 0.04), at(V3(0, 0.27, 0.035))], radii: [0.009, 0.009], sides: 5, seamTile: 0.1, material: steel))
            var prof: [V2] = [V2(0, 0.1), V2(0.03, 0.1)]
            for k in 0..<5 { let y = 0.13 + Float(k) * 0.065; prof += [V2(0.03, y), V2(0.05, y + 0.015), V2(0.046, y + 0.025), V2(0.03, y + 0.035)] }
            prof += [V2(0.03, 0.47), V2(0, 0.47)]
            m.add(Prim.lathe(prof, segments: 12, material: porcelain), Xform(translation: base, rotation: tilt))
            m.add(Prim.roundedBox(V3(0.03, 0.022, 0.11), radius: 0.005, bevelSegments: 1, material: "metal.bronze-cast"), Xform(translation: at(V3(0, 0.49, -0.05)), rotation: tilt))
            m.add(Prim.roundedBox(V3(0.03, 0.022, 0.1), radius: 0.005, bevelSegments: 1, material: "metal.bronze-cast"), Xform(translation: at(V3(0, 0.1, -0.05)), rotation: tilt))
            // Door: fuse tube, cap, pull ring. Hinge at the trunnion; opens away from the pole.
            let pv = at(V3(0, 0.09, -0.09))
            rig.part(name, pivot: pv, joint: .hinge(axis: V3(1, 0, 0), -120...0, duration: 0.9), options: 2)
            for o in 0..<2 {
                rig.add(Prim.lathe([V2(0.012, 0.1), V2(0.016, 0.1), V2(0.016, 0.46), V2(0.012, 0.46)], segments: 10, material: o == 1 ? "plastic.matte:2A2622" : "plastic.fuse-tube"), Xform(translation: at(V3(0, 0, -0.09)), rotation: tilt), to: name, option: o)
                rig.add(Prim.cylinder(radius: 0.019, height: 0.03, bevel: 0.003, segments: 10, material: "metal.bronze-cast"), Xform(translation: at(V3(0, 0.455, -0.09)), rotation: tilt), to: name, option: o)
                rig.add(Prim.torus(major: 0.017, minor: 0.0035, segments: 12, sides: 4, material: "metal.bronze-cast"), Xform(translation: at(V3(0, 0.465, -0.125)), rotation: tilt * simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))), to: name, option: o)
                rig.add(Prim.tube([at(V3(0, 0.1, -0.09)), at(V3(0.003, o == 1 ? 0.07 : 0.03, -0.092))], radii: [0.0018, 0.0018], sides: 4, seamTile: 0.02, material: o == 1 ? "metal.copper-patina" : "metal.tinned-copper"), to: name, option: o)
            }
            // Line jumpers from the cutout tops up to the phase conductors.
            let top = at(V3(0, 0.5, -0.05)), ph = V3(Self.phaseX[i], aY + 0.13, az - 0.5)
            let mid = (top + ph) / 2 + V3(0, -0.25, 0)
            m.add(Prim.tube(catmull([top, mid, ph], per: 5), radii: Array(repeating: 0.004, count: 11), sides: 5, seamTile: 0.05, material: "rubber"))
        }
        // Arrester on the arm end.
        let arP = V3(0.56, cY, cz - 0.03)
        var ap: [V2] = [V2(0, 0), V2(0.03, 0)]
        for k in 0..<6 { let y = 0.02 + Float(k) * 0.035; ap += [V2(0.03, y), V2(0.06, y + 0.008), V2(0.058, y + 0.014), V2(0.03, y + 0.024)] }
        ap += [V2(0.03, 0.24), V2(0, 0.24)]
        m.add(Prim.lathe(ap, segments: 12, material: "rubber.silicone-gray:5E646A"), Xform(translation: arP))
        // Transformer on the field side with hanger and drop leads.
        let tY = Self.transformerY, tz = -(r(tY) + 0.3)
        m.add(Prim.roundedBox(V3(0.18, 0.7, 0.05), radius: 0.008, bevelSegments: 1, material: steel), Xform(translation: V3(0, tY + 0.3, -(r(tY) + 0.03))))
        m.add(Prim.lathe([V2(0, 0), V2(0.215, 0), V2(0.225, 0.02), V2(0.225, 0.7), V2(0.24, 0.71), V2(0.24, 0.72), V2(0.15, 0.77), V2(0, 0.78)], segments: 24, seamTile: 0.6, material: "metal.transformer-gray"),
              Xform(translation: V3(0, tY, tz)))
        let pb = V3(0.06, tY + 0.74, tz + 0.05)
        m.add(Prim.lathe([V2(0, 0), V2(0.035, 0), V2(0.04, 0.03), V2(0.025, 0.05), V2(0.04, 0.07), V2(0.022, 0.1), V2(0.035, 0.11), V2(0.015, 0.15), V2(0, 0.15)], segments: 12, material: porcelain), Xform(translation: pb))
        let ca = V3(Self.cutoutX[0], cY - 0.25, cz - 0.27) + tilt.act(V3(0, 0.09, -0.05))
        m.add(Prim.tube(catmull([ca, (ca + pb) / 2 + V3(0, -0.4, -0.2), pb + V3(0, 0.15, 0)], per: 6), radii: Array(repeating: 0.004, count: 13), sides: 5, seamTile: 0.05, material: "rubber"))
        for (k, a) in [Float(-0.5), 0, 0.5].enumerated() {
            let d = V3(sin(a + .pi), 0, cos(a + .pi)), b = V3(0, tY + 0.55, tz) + d * 0.23
            m.add(Prim.cylinder(radius: 0.022, height: 0.06, bevel: 0.004, segments: 10, material: k == 1 ? "ceramic.porcelain-black" : porcelain), Xform(translation: b, rotation: simd_quatf(from: .up, to: d)))
            let e = b + d * 0.06
            let n = V3(Float(k - 1) * 0.15, nY - 0.05, r(nY) + 0.13)
            m.add(Prim.tube(catmull([e, e + d * 0.1 + V3(0, 0.2, 0), (e + n) / 2 + V3(0.4, 0.1, 0), n], per: 5), radii: Array(repeating: 0.006, count: 16), sides: 5, seamTile: 0.05, material: "plastic.matte:1A1A1A"))
        }
        // Down guy: attachment under the arm, strand to an anchor rod, yellow guard at the bottom.
        let gTop = V3(-r(aY - 0.4) - 0.01, aY - 0.4, 0), gBot = V3(-2.6, 0.15, 0)
        m.add(Prim.tube([gTop, gBot], radii: [0.0048, 0.0048], sides: 5, seamTile: 0.05, material: "metal.galvanized-aged"))
        m.add(Prim.cylinder(radius: 0.012, height: 0.2, bevel: 0.003, segments: 8, material: "metal.galvanized-aged"), Xform(translation: V3(-2.62, 0.0, 0), rotation: simd_quatf(from: .up, to: simd_normalize(gTop - gBot))))
        let gd = simd_normalize(gTop - gBot)
        m.add(Prim.cylinder(radius: 0.022, height: 2.4, bevel: 0.004, segments: 10, material: "plastic.yellow"), Xform(translation: gBot + gd * 0.25, rotation: simd_quatf(from: .up, to: gd)))
        m.add(Prim.roundedBox(V3(0.05, 0.08, 0.03), radius: 0.006, bevelSegments: 1, material: steel), Xform(translation: gTop + V3(-0.01, 0, 0)))
        _ = leanX
        rig.base[0] = m
        rig.states = [RigState("normal"),
                      RigState("damaged", ["cutoutA": -120], options: ["insulatorB": 1, "conductorB": 1, "cutoutA": 1])]
        groundAO(&rig, height: 0.4, floor: 0.6)
        return rig
    }
}
