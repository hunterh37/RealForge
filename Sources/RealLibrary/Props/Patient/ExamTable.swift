import simd
import Foundation

/// Clinic examination table (Midmark Ritter 204 / 625 class): 1.2 m powder-coated casework on a recessed
/// toe kick with a brushed stainless kick plate, two front drawers with bar pulls over a pair of storage
/// doors, a pull-out step at the foot end, a 686 mm wide top 80 cm off the floor upholstered in 78 mm
/// foam under medical vinyl with stitched side seams, a back section on a hinge at the seat line
/// (0-80 degrees) on a steel underframe, a chrome paper roll holder at the head feeding a 53 cm sheet of
/// exam paper over both sections (torn off at the foot end), and two stirrups stowed under the foot end.
/// Head at -X, foot (step) at +X, drawers face +Z.
public struct ExamTable: RealArticulated {
    public static let id = "exam-table"
    public static let summary = "Medical exam table: powder-coated casework with two drawers and a pull-out step, vinyl top with a raising back, paper roll and stowed stirrups."
    public static let tags = ["prop", "medical", "hospital", "furniture", "metal", "articulated"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 16, distance: 2.4, studio: true)

    /// Upholstery vinyl (tint for color).
    public var upholstery: MaterialKey = "vinyl.medical"
    /// Casework powder coat.
    public var casework: MaterialKey = "metal.powder-white:DEDCD6"
    public var topWidth: Float = 0.686
    /// Top surface height (m).
    public var topHeight: Float = 0.802
    /// Back raise in the sitting state (degrees).
    public var sittingAngle: Float = 60
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [8])
        let dark: MaterialKey = "plastic.matte:2E2F31", chrome: MaterialKey = "metal.chrome", grey: MaterialKey = "plastic.medical-grey"
        let C = topWidth / 2
        let cx0: Float = -0.6, cx1: Float = 0.6, cz: Float = 0.27, kick: Float = 0.06, caseTop: Float = 0.7
        let boardY0: Float = 0.71, cushY0: Float = 0.724, top = topHeight
        let b = (top - cushY0) / 2, cy = cushY0 + b
        let hingeX: Float = -0.15
        let seatX0 = hingeX + 0.004, seatX1: Float = 0.62
        let backX0: Float = -0.86, backX1 = hingeX - 0.004
        let n: Float = 8

        // MARK: casework (static)
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let seg = l == 0 ? 2 : 1
            m.add(PatientKit.box(V3(cx1 - cx0, caseTop - kick, 2 * cz), V3(0, (kick + caseTop) / 2, 0), r: 0.008, seg: seg, material: casework))
            m.add(PatientKit.box(V3(cx1 - cx0 - 0.08, kick, 2 * cz - 0.08), V3(0, kick / 2, 0), r: 0.003, seg: 1, material: dark))
            // Top plate under the seat and the seat board.
            m.add(PatientKit.box(V3(seatX1 - hingeX + 0.02, boardY0 - caseTop, 2 * C - 0.08), V3((seatX1 + hingeX) / 2, (caseTop + boardY0) / 2, 0), r: 0.002, seg: 1, material: casework))
            m.add(PatientKit.box(V3(seatX1 - seatX0 - 0.01, cushY0 - boardY0 + 0.002, 2 * C - 0.012), V3((seatX0 + seatX1) / 2, (boardY0 + cushY0) / 2, 0), r: 0.003, seg: 1, material: dark))
            // Front: dark reveals behind the drawers, two storage doors with pulls.
            for (x0, x1) in [(cx0 + 0.04, -0.01), (Float(0.01), cx1 - 0.04)] {
                m.add(PatientKit.box(V3(x1 - x0, 0.15, 0.002), V3((x0 + x1) / 2, 0.585, cz + 0.0005), r: 0.0005, seg: 1, material: dark))
                m.add(PatientKit.box(V3(x1 - x0 - 0.004, 0.4, 0.016), V3((x0 + x1) / 2, 0.29, cz + 0.006), r: 0.004, seg: seg, material: casework))
                let px = x0 > 0 ? x0 + 0.05 : x1 - 0.05
                m.add(PatientKit.pull(length: 0.096, standoff: 0.024, r: 0.005, sides: l == 0 ? 8 : 4, material: chrome),
                      Xform(translation: V3(px, 0.4, cz + 0.014), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
            }
            // Foot end: dark step opening behind the step riser, stainless kick plate (scuffed), leveling feet.
            m.add(PatientKit.box(V3(0.002, 0.2, 0.46), V3(cx1 + 0.0005, 0.17, 0), r: 0.0005, seg: 1, material: dark))
            m.add(PatientKit.box(V3(0.003, 0.055, 2 * cz - 0.1), V3(cx1 - 0.038, 0.032, 0), r: 0.001, seg: 1, material: "metal.casework"))
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                m.add(Prim.cylinder(radius: 0.022, height: 0.012, bevel: 0.003, segments: l == 0 ? 14 : 8, bevelSegments: 1, material: "rubber"),
                      Xform(translation: V3(sx * (cx1 - 0.08), 0, sz * (cz - 0.07))))
            }}
            if l == 0 {
                // Duplex receptacle on the head end.
                m.add(PatientKit.box(V3(0.006, 0.115, 0.07), V3(cx0 - 0.002, 0.42, 0.14), r: 0.002, seg: 1, material: "plastic.medical"))
                for dy: Float in [-0.022, 0.022] {
                    m.add(PatientKit.box(V3(0.004, 0.034, 0.038), V3(cx0 - 0.005, 0.42 + dy, 0.14), r: 0.006, seg: 1, material: "plastic.medical:D9D5CB"))
                    for dz: Float in [-0.007, 0.007] {
                        m.add(cuboid(V3(0.002, 0.012, 0.0025), material: dark), Xform(translation: V3(cx0 - 0.0065, 0.42 + dy + 0.003, 0.14 + dz)))
                    }
                }
            }
            rig.base[l] = m
        }

        // MARK: upholstery and paper helpers
        func topY(_ x: Float, _ x0: Float, _ x1: Float) -> Float {
            let a = (x1 - x0) / 2, d = abs(x - (x0 + x1) / 2) / a
            return cy + b * pow(max(0, 1 - pow(d, n)), 1 / n)
        }
        func cushion(_ x0: Float, _ x1: Float, sub: Int) -> Surface {
            Prim.superellipsoid(V3(x1 - x0, 2 * b, 2 * C), exponent: n, subdivisions: sub, material: upholstery)
                .transformed(Xform(translation: V3((x0 + x1) / 2, cy, 0)))
        }
        func seams(_ x0: Float, _ x1: Float) -> Surface {
            var s = Surface(material: "thread.white:1E3E44")
            let ys = cy + b * 0.62
            let zs = C * pow(1 - pow(0.62, n), 1 / n) + 0.0004
            for sz: Float in [-1, 1] {
                s.append(stitches(along: [V3(x0 + 0.06, ys, sz * zs), V3(x1 - 0.06, ys, sz * zs)], normal: { _ in V3(0, 0, sz) }, pitch: 0.01, material: s.material))
            }
            return s
        }
        let paperW: Float = 0.53
        func paper(_ pts: [V3], torn: Bool) -> Surface {
            var r = SeededRNG(seed: seed &+ (torn ? 11 : 5))
            let jag = (0...10).map { _ in r.float(-0.006...0.006) }
            return PatientKit.ribbon(pts, across: V3(0, 0, 1), width: paperW, steps: 10, material: "paper.exam") { i, j in
                var o = V3(0, 0.0004 * sin(Float(i) * 0.9 + Float(j) * 1.7), 0)
                if torn && i == pts.count - 1 { o.x += jag[j] + (j % 2 == 0 ? 0.004 : -0.002) }
                return o
            }
        }

        // Seat cushion, seams and paper (static).
        rig.base[0].add(cushion(seatX0, seatX1, sub: 10))
        rig.base[1].add(cushion(seatX0, seatX1, sub: 6))
        rig.base[0].add(seams(seatX0, seatX1))
        let seatPaper = stride(from: seatX0 + 0.012, through: 0.5, by: 0.02).map { V3($0, topY($0, seatX0, seatX1) + 0.0012, 0) }
        rig.base[0].add(paper(seatPaper, torn: true))
        rig.base[1].add(PatientKit.ribbon([seatPaper[0], seatPaper[seatPaper.count / 2], seatPaper[seatPaper.count - 1]], across: V3(0, 0, 1), width: paperW, steps: 1, material: "paper.exam"))

        // MARK: back section: hinge at the seat line, top surface level.
        rig.part("back", pivot: V3(hingeX, top - 0.012, 0), joint: .hinge(axis: V3(0, 0, -1), 0...80, duration: 1.4))
        rig.add(cushion(backX0, backX1, sub: 10), to: "back", lods: 0...0)
        rig.add(cushion(backX0, backX1, sub: 6), to: "back", lods: 1...1)
        rig.add(seams(backX0, backX1), to: "back", lods: 0...0)
        rig.add(PatientKit.box(V3(backX1 - backX0 - 0.01, cushY0 - boardY0 + 0.002, 2 * C - 0.012), V3((backX0 + backX1) / 2, (boardY0 + cushY0) / 2, 0), r: 0.003, seg: 1, material: dark), to: "back")
        // Steel underframe: two rails and a cross tube.
        for sz: Float in [-1, 1] {
            rig.add(PatientKit.bar(V3(backX0 + 0.04, boardY0 - 0.0045, sz * 0.22), V3(backX1 - 0.01, boardY0 - 0.0045, sz * 0.22), w: 0.03, h: 0.008, r: 0.002, material: casework), to: "back")
        }
        rig.add(PatientKit.bar(V3(backX0 + 0.12, boardY0 - 0.0045, -0.22), V3(backX0 + 0.12, boardY0 - 0.0045, 0.22), w: 0.03, h: 0.008, r: 0.002, material: casework), to: "back")
        // Paper roll holder: two bent chrome arms from the head end, rod, roll on a core.
        let rollC = V3(backX0 - 0.03, cushY0 - 0.035, 0), rollR: Float = 0.04
        for sz: Float in [-1, 1] {
            let arm = PatientKit.bend([V3(backX0 + 0.05, boardY0 - 0.004, sz * 0.29), V3(backX0 - 0.01, boardY0 - 0.004, sz * 0.29), V3(rollC.x, rollC.y, sz * 0.29)], radius: 0.015, seg: 3)
            rig.add(PatientKit.tube(arm, r: 0.0045, sides: 8, material: chrome), to: "back")
        }
        rig.add(Prim.cylinder(radius: 0.005, height: 0.6, bevel: 0.001, segments: 8, bevelSegments: 1, material: chrome),
                Xform(translation: rollC + V3(0, 0, -0.3), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "back")
        rig.add(Prim.cylinder(radius: rollR, height: paperW, bevel: 0.002, segments: 24, bevelSegments: 1, material: "paper.exam"),
                Xform(translation: rollC + V3(0, 0, -paperW / 2), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "back")
        for sz: Float in [-1, 1] {
            rig.add(Prim.cylinder(radius: 0.019, height: 0.002, bevel: 0.0005, segments: 10, bevelSegments: 1, material: "plastic.matte:8A6A48"),
                    Xform(translation: rollC + V3(0, 0, sz * (paperW / 2 + 0.001)), rotation: simd_quatf(degrees: sz * 90, axis: V3(1, 0, 0))), to: "back", lods: 0...0)
        }
        // Back paper: off the roll top, over the head end, along the back to the hinge.
        var backPaper: [V3] = [rollC + V3(0.004, rollR + 0.0008, 0), V3(backX0 - 0.012, top - 0.012, 0)]
        for x in stride(from: backX0 + 0.004, through: backX1 - 0.012, by: 0.02) where topY(x, backX0, backX1) > top - 0.012 {
            backPaper.append(V3(x, topY(x, backX0, backX1) + 0.0012, 0))
        }
        rig.add(paper(backPaper, torn: false), to: "back", lods: 0...0)
        rig.add(PatientKit.ribbon([backPaper[0], backPaper[1], backPaper[3], backPaper[backPaper.count - 1]], across: V3(0, 0, 1), width: paperW, steps: 1,
                                  material: "paper.exam"), to: "back", lods: 1...1)

        // MARK: drawers: fronts proud of the casework, boxes behind, chrome bar pulls.
        for (name, x0, x1) in [("drawer-left", cx0 + 0.04, Float(-0.01)), ("drawer-right", Float(0.01), cx1 - 0.04)] {
            let cxm = (x0 + x1) / 2, w = x1 - x0
            rig.part(name, pivot: V3(cxm, 0.585, cz), joint: .slide(axis: V3(0, 0, 1), 0...0.32, duration: 0.6))
            rig.add(PatientKit.box(V3(w - 0.004, 0.15, 0.018), V3(cxm, 0.585, cz + 0.009), r: 0.004, seg: 2, material: casework).transformed(.identity),
                    Xform.identity.jittered(&rng, deg: 0.03, offset: 0.0002), to: name)
            rig.add(PatientKit.pull(length: 0.128, standoff: 0.026, r: 0.0055, material: chrome), Xform(translation: V3(cxm, 0.6, cz + 0.018)), to: name, lods: 0...0)
            rig.add(PatientKit.pull(length: 0.128, standoff: 0.026, r: 0.0055, sides: 4, material: chrome), Xform(translation: V3(cxm, 0.6, cz + 0.018)), to: name, lods: 1...1)
            let bw = w - 0.05, bd: Float = 0.42, by0: Float = 0.52
            for sx: Float in [-1, 1] {
                rig.add(PatientKit.box(V3(0.01, 0.11, bd), V3(cxm + sx * bw / 2, by0 + 0.055, cz - bd / 2), r: 0.002, seg: 1, material: grey), to: name, lods: 0...0)
            }
            rig.add(PatientKit.box(V3(bw, 0.01, bd), V3(cxm, by0 + 0.005, cz - bd / 2), r: 0.002, seg: 1, material: grey), to: name, lods: 0...0)
            rig.add(PatientKit.box(V3(bw, 0.11, 0.01), V3(cxm, by0 + 0.055, cz - bd + 0.005), r: 0.002, seg: 1, material: grey), to: name, lods: 0...0)
            rig.add(cuboid(V3(bw, 0.11, bd), material: grey), Xform(translation: V3(cxm, by0 + 0.055, cz - bd / 2)), to: name, lods: 1...1)
            // Contents: a glove box in the left drawer, tongue depressor packs in the right.
            if name == "drawer-left" {
                rig.add(Prim.roundedBox(V3(0.24, 0.065, 0.125), radius: 0.003, bevelSegments: 1, material: "plastic.medical:5C7FB8"),
                        Xform(translation: V3(cxm - 0.06, by0 + 0.0425, cz - 0.15), rotation: simd_quatf(degrees: 4, axis: .up)), to: name, lods: 0...0)
            } else {
                rig.add(Prim.roundedBox(V3(0.16, 0.04, 0.09), radius: 0.003, bevelSegments: 1, material: "paper.sheet:E8E0CC"),
                        Xform(translation: V3(cxm + 0.04, by0 + 0.03, cz - 0.12), rotation: simd_quatf(degrees: -7, axis: .up)), to: name, lods: 0...0)
            }
        }

        // MARK: pull-out step at the foot end: riser fascia, tread with rubber mat, side rails.
        rig.part("step", pivot: V3(cx1, 0.2, 0), joint: .slide(axis: V3(1, 0, 0), 0...0.26, duration: 0.6))
        rig.add(PatientKit.box(V3(0.018, 0.19, 0.48), V3(cx1 + 0.009, 0.17, 0), r: 0.004, seg: 2, material: casework), to: "step")
        rig.add(PatientKit.box(V3(0.25, 0.022, 0.44), V3(cx1 - 0.125, 0.249, 0), r: 0.003, seg: 1, material: casework), to: "step")
        var mat = Surface(material: "rubber")
        for k in 0..<9 {
            mat.append(cuboid(V3(0.006, 0.004, 0.4), material: "rubber"), Xform(translation: V3(cx1 - 0.02 - Float(k) * 0.025, 0.262, 0)))
        }
        rig.add(mat, to: "step", lods: 0...0)
        rig.add(PatientKit.box(V3(0.006, 0.08, 0.06), V3(cx1 + 0.02, 0.23, 0), r: 0.002, seg: 1, material: dark), to: "step", lods: 0...0)
        for sz: Float in [-1, 1] {
            rig.add(PatientKit.box(V3(0.24, 0.05, 0.012), V3(cx1 - 0.12, 0.214, sz * 0.214), r: 0.002, seg: 1, material: "metal.casework"), to: "step", lods: 0...0)
        }

        // MARK: stirrups: chrome rods in channels under the top overhang, cast foot cups at the ends.
        rig.part("stirrup-right", pivot: V3(0.58, 0.68, C - 0.04), joint: .slide(axis: V3(1, 0, 0), 0...0.32, duration: 0.7))
        rig.part("stirrup-left", pivot: V3(0.58, 0.68, -C + 0.04), joint: Joint(.prismatic, axis: V3(1, 0, 0), range: 0...0.32, mimic: .init("stirrup-right")))
        for (name, sz) in [("stirrup-right", Float(1)), ("stirrup-left", Float(-1))] {
            let z = sz * (C - 0.04)
            rig.add(PatientKit.rod(V3(0.22, 0.688, z), V3(0.585, 0.688, z), r: 0.008, sides: 10, material: chrome), to: name)
            let post = PatientKit.bend([V3(0.585, 0.688, z), V3(0.612, 0.688, z), V3(0.612, 0.64, z)], radius: 0.012, seg: 3)
            rig.add(PatientKit.tube(post, r: 0.008, sides: 10, material: chrome), to: name)
            for l in 0..<2 {
                rig.add(Prim.superellipsoid(V3(0.075, 0.07, 0.058), exponent: 3, subdivisions: l == 0 ? 5 : 2, material: grey),
                        Xform(translation: V3(0.612, 0.615, z)), to: name, lods: l...l)
            }
            rig.add(Prim.roundedBox(V3(0.07, 0.008, 0.05), radius: 0.003, bevelSegments: 1, material: "rubber"), Xform(translation: V3(0.612, 0.583, z)), to: name, lods: 0...0)
        }

        groundAO(&rig, height: 0.1, floor: 0.6)
        rig.states = [RigState("flat"), RigState("sitting", ["back": sittingAngle]), RigState("step-out", ["step": 0.26]),
                      RigState("drawers-open", ["drawer-left": 0.28, "drawer-right": 0.28]), RigState("stirrups-out", ["stirrup-right": 0.3])]
        return rig
    }
}
