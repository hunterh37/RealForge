import simd
import Foundation

/// Generic 18V class cordless 5 in random orbit sander standing on its pad (about 270 mm long with the
/// pack and canister, 152 mm tall): 127 mm 8-hole hook-and-loop pad with a red-brown 120 grit disc, rubber
/// dust skirt, teal motor housing with a rubber finger band, vents and Torx screws, rubber-topped palm grip,
/// rocker on/off switch in a black bezel, dust port with a smoked translucent canister holding sawdust,
/// rear battery mount carrying the family 2 Ah slide-on pack.
///
/// Rig: `pad` (hinge about Y through the pad center, 0...360, the game spins it), `switch` (rocker about X,
/// 0...14 degrees, 14 = on).
public struct RandomOrbitSander: RealArticulated {
    public static let id = "random-orbit-sander"
    public static let summary = "Cordless 5 in random orbit sander on its pad: rubber palm grip, rocker switch, smoked dust canister, 8-hole hook-and-loop pad with a 120 grit disc."
    public static let tags = ["prop", "workshop", "tool", "handheld", "articulated", "plastic", "rubber", "metal"]
    public static let budget = 10_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 145, elevation: 20, distance: 0.75, studio: true)

    /// Housing color (sRGB hex, `plastic.tool`).
    public var bodyColor: UInt32 = CordlessKit.bodyColor
    /// Pad radius (m): 5 in pad.
    public var padRadius: Float = 0.0635
    /// Sanding disc material (grit as a material key).
    public var discMaterial: MaterialKey = "abrasive.cordless-disc-120"
    /// Switch rocker angle in the running state (degrees).
    public var switchOn: Float = 14
    public init() {}

    /// Asset-space shift applied after building (centers the bounds on X).
    static let shiftX: Float = -0.024
    /// Center of the sanding face (bottom of the disc, y = 0), asset space.
    public var padCenter: V3 { V3(Self.shiftX, 0, 0) }
    /// Palm grip contact point on top of the rubber dome, asset space.
    public var grip: V3 { V3(Self.shiftX, 0.1515, 0) }

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3])
        let body = CordlessKit.housing(bodyColor), trim = CordlessKit.tool(CordlessKit.trimColor)
        let gripK = CordlessKit.grip, slotK = CordlessKit.slot
        let X = V3(1, 0, 0), Y = V3(0, 1, 0), Z = V3(0, 0, 1)
        let R = padRadius
        let portY: Float = 0.033
        let oval = { (s: Surface) -> Surface in var t = s; t.deform { V3($0.x * 1.06, $0.y, $0.z) }; return t }

        for l in 0..<2 {
            let lite = l == 1
            let n = lite ? 18 : 36
            var m = Model(name: Self.id)

            // MARK: rubber dust skirt over the pad rim.
            m.add(Prim.lathe([V2(R - 0.012, 0.0172), V2(R - 0.0035, 0.0158), V2(R - 0.0016, 0.0146), V2(R - 0.0022, 0.0137), V2(R - 0.012, 0.0141)],
                             segments: n, seamTile: 0.05, material: "rubber"))
            // MARK: housing: teal shroud, rubber finger band, teal motor case, rubber palm dome.
            m.add(oval(Prim.lathe([V2(0.020, 0.0150), V2(0.0575, 0.0150), V2(0.0588, 0.0175), V2(0.0585, 0.0300), V2(0.0560, 0.0400),
                                   V2(0.0500, 0.0480), V2(0.0455, 0.0530)], segments: n, seamTile: 0.08, material: body)))
            m.add(oval(Prim.lathe([V2(0.0440, 0.0505), V2(0.0466, 0.0540), V2(0.0450, 0.0620), V2(0.0432, 0.0700), V2(0.0438, 0.0790), V2(0.0466, 0.0870), V2(0.0440, 0.0910)],
                                  segments: n, seamTile: 0.06, material: gripK)))
            m.add(oval(Prim.lathe([V2(0.0445, 0.0880), V2(0.0468, 0.0910), V2(0.0478, 0.1050), V2(0.0482, 0.1150), V2(0.0470, 0.1185)],
                                  segments: n, seamTile: 0.08, material: body)))
            var dome: [V2] = [V2(0.0466, 0.1170)]
            for k in 0...(lite ? 4 : 7) {
                let t = Float(k) / Float(lite ? 4 : 7) * .pi / 2
                dome.append(V2(0.0488 * cos(t), 0.1185 + 0.0335 * sin(t)))
            }
            m.add(oval(Prim.lathe(dome, segments: n, seamTile: 0.06, material: gripK)))

            // MARK: rear battery mount and pack (rails toward +X, latch end up).
            m.add(Prim.roundedBox(V3(0.036, 0.104, 0.074), radius: 0.009, bevelSegments: lite ? 1 : 2, material: body), Xform(translation: V3(-0.050, 0.076, 0)))
            m.add(Prim.roundedBox(V3(0.006, 0.112, 0.076), radius: 0.0025, bevelSegments: 1, material: trim), Xform(translation: V3(-0.0665, 0.076, 0)))
            let packQ = simd_quatf(degrees: 180, axis: X) * simd_quatf(degrees: -90, axis: Z)
            m.add(CordlessKit.battery(lite: lite, bodyColor: bodyColor), Xform(translation: V3(-0.1195, 0.077, 0), rotation: packQ))

            // MARK: dust port and smoked canister along +X.
            m.add(CordlessKit.spinX([V2(0.040, 0.0125), V2(0.083, 0.0125), V2(0.0845, 0.0118)], center: V3(0, portY, 0), segments: lite ? 12 : 24, material: body))
            m.add(CordlessKit.spinX([V2(0.081, 0.0150), V2(0.0825, 0.0168), V2(0.0915, 0.0168), V2(0.0925, 0.0150)], center: V3(0, portY, 0),
                                    segments: lite ? 12 : 28, ribs: lite ? 0 : 12, ribDepth: 0.0008, ribRange: 0.083...0.091, material: trim))
            m.add(CordlessKit.spinX([V2(0.0915, 0.0170), V2(0.0935, 0.0262), V2(0.0960, 0.0282), V2(0.1520, 0.0282), V2(0.1545, 0.0270)],
                                    center: V3(0, portY, 0), segments: lite ? 14 : 36, capStart: false, capEnd: false, material: "plastic.cordless-smoke"))
            m.add(CordlessKit.spinX([V2(0.1525, 0.0278), V2(0.1540, 0.0290), V2(0.1610, 0.0290), V2(0.1640, 0.0270), V2(0.1650, 0.0240)],
                                    center: V3(0, portY, 0), segments: lite ? 14 : 36, ribs: lite ? 0 : 18, ribDepth: 0.0009, ribRange: 0.155...0.160, material: trim))
            // Sawdust settled in the lower third of the canister.
            let fill: Float = -0.0105, rIn: Float = 0.0272
            let a0 = acos(fill / rIn)
            var seg: [V2] = []
            for k in 0...(lite ? 6 : 14) { let a = a0 + (2 * .pi - 2 * a0) * Float(k) / Float(lite ? 6 : 14); seg.append(V2(rIn * cos(a), rIn * sin(a))) }
            let dustRings = [V3(0.0965, portY, 0), V3(0.1515, portY, 0)].map { CordlessKit.section(seg, $0, Y, Z) }
            m.add(Prim.loft(dustRings, capStart: true, capEnd: true, material: "wood.sawdust"))

            if !lite {
                // Vents around the motor case, back half (battery side) and flanks.
                for k in 0..<12 {
                    let a = Float.pi * (0.62 + Float(k) * 0.065)
                    let d = V3(cos(a) * 1.06, 0, sin(a)), nrm = simd_normalize(V3(cos(a) / 1.06, 0, sin(a)))
                    CordlessKit.vents(&m, start: V3(d.x * 0.0477, 0.1025, d.z * 0.0477), step: .zero, count: 1, along: Y, normal: nrm, len: 0.014, width: 0.0021)
                    let a2 = -a
                    CordlessKit.vents(&m, start: V3(cos(a2) * 1.06 * 0.0477, 0.1025, sin(a2) * 0.0477), step: .zero, count: 1, along: Y,
                                      normal: simd_normalize(V3(cos(a2) / 1.06, 0, sin(a2))), len: 0.014, width: 0.0021)
                }
                // Shroud screws.
                for a in [Float(0.35), 2.2, 4.1] {
                    let nrm = simd_normalize(V3(cos(a) / 1.06, 0.25, sin(a)))
                    CordlessKit.screw(&m, at: V3(cos(a) * 1.06 * 0.0583, 0.026, sin(a) * 0.0583), normal: nrm)
                }
                // Side badge on -Z.
                m.add(Prim.roundedBox(V3(0.030, 0.0125, 0.0024), radius: 0.0012, bevelSegments: 1, material: trim),
                      Xform(translation: V3(0.0, 0.1025, -0.0478)))
                m.add(Prim.roundedBox(V3(0.012, 0.0035, 0.0008), radius: 0.0005, bevelSegments: 1, material: body), Xform(translation: V3(0.006, 0.1025, -0.0492)))
                m.add(Prim.roundedBox(V3(0.008, 0.0035, 0.0008), radius: 0.0005, bevelSegments: 1, material: "paint.field-white"), Xform(translation: V3(-0.007, 0.1025, -0.0492)))
                // Canister latch tabs and port clamp screw.
                for sz: Float in [-1, 1] {
                    m.add(Prim.roundedBox(V3(0.008, 0.010, 0.004), radius: 0.0012, bevelSegments: 1, material: trim), Xform(translation: V3(0.087, portY, sz * 0.0175)))
                }
            }
            rig.base[l] = m
        }

        // MARK: pad (hinge about Y, spun by the game)
        rig.part("pad", pivot: .zero, joint: .hinge(axis: Y, 0...360, duration: 0.6))
        for l in 0..<2 {
            let n = l == 0 ? 48 : 20
            rig.add(Prim.cylinder(radius: R + 0.0003, height: 0.0016, bevel: 0.0004, segments: n, bevelSegments: 1, seamTile: 0.03, material: discMaterial),
                    Xform(translation: V3(0, 0.0001, 0)), to: "pad", lods: l...l)
            rig.add(Prim.lathe([V2(0, 0.0015), V2(R - 0.0006, 0.0015), V2(R - 0.0001, 0.0022), V2(R - 0.0002, 0.0085), V2(R - 0.0016, 0.0105),
                                V2(R - 0.0040, 0.0112), V2(0, 0.0112)], segments: n, seamTile: 0.05, material: "rubber"), to: "pad", lods: l...l)
            rig.add(Prim.cylinder(radius: R - 0.0055, height: 0.0030, bevel: 0.0009, segments: n, bevelSegments: 1, seamTile: 0.05, material: trim),
                    Xform(translation: V3(0, 0.0108, 0)), to: "pad", lods: l...l)
        }
        // Eight dust holes through the disc (dark openings on the face) and the hook-and-loop edge band.
        var holes = Model(name: "holes")
        for k in 0..<8 {
            let a = Float(k) / 8 * 2 * .pi
            CordlessKit.disc(&holes, at: V3(0.040 * cos(a), 0.00005, 0.040 * sin(a)), normal: V3(0, -1, 0), radius: 0.0047, sides: 12, material: slotK)
        }
        CordlessKit.disc(&holes, at: V3(0, 0.00005, 0), normal: V3(0, -1, 0), radius: 0.0040, sides: 12, material: slotK)
        for s in holes.surfaces { rig.add(s, to: "pad") }
        rig.add(Prim.lathe([V2(R + 0.00005, 0.0018), V2(R + 0.00005, 0.0026)], segments: 48, seamTile: 0.03, material: "fabric.nylon:3A3B3E"), to: "pad", lods: 0...0)
        // Index mark on the pad edge (shows the spin).
        rig.add(Prim.roundedBox(V3(0.0012, 0.0045, 0.009), radius: 0.0004, bevelSegments: 1, material: "paint.field-white"),
                Xform(translation: V3(R - 0.0003, 0.0055, 0)), to: "pad")

        // MARK: switch: rocker in a bezel on the +Z flank (hinge about X).
        let sw = V3(0.004, 0.1035, 0.0478)
        rig.base[0].add(Prim.roundedBox(V3(0.024, 0.019, 0.006), radius: 0.0022, bevelSegments: 2, material: trim), Xform(translation: sw + V3(0, 0, -0.0005)))
        rig.base[1].add(Prim.roundedBox(V3(0.024, 0.019, 0.006), radius: 0.0022, bevelSegments: 1, material: trim), Xform(translation: sw + V3(0, 0, -0.0005)))
        rig.part("switch", pivot: sw + V3(0, 0, 0.002), joint: .hinge(axis: X, 0...14, duration: 0.2))
        rig.add(Prim.superellipsoid(V3(0.017, 0.014, 0.0056), exponent: 3.2, subdivisions: 4, material: "rubber"),
                Xform(translation: sw + V3(0, 0, 0.0028), rotation: simd_quatf(degrees: -7, axis: X)), to: "switch")
        rig.add(Prim.roundedBox(V3(0.006, 0.0012, 0.0006), radius: 0.0003, bevelSegments: 1, material: "paint.field-white"),
                Xform(translation: sw + V3(0, 0.0036, 0.0058), rotation: simd_quatf(degrees: -7, axis: X)), to: "switch", lods: 0...0)

        groundAO(&rig, height: 0.025, floor: 0.55)
        CordlessKit.shift(&rig, by: V3(Self.shiftX, 0, 0))
        rig.states = [RigState("idle"), RigState("running", ["pad": 180, "switch": switchOn])]
        return rig
    }
}
