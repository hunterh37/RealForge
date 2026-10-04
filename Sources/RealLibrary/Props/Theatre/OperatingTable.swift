import simd
import Foundation

/// General surgical operating table (Maquet Alphamaxx / Steris 5085 class), top 2.06 x 0.50 m: brushed
/// stainless base plate with a rubber skirt and floor locks, rectangular column shroud with a telescoping
/// upper shroud, a column head carrying the top, four sections (head 280, back 560, seat 480, legs 700 mm)
/// each with an 80 mm black vinyl pad on a dark radiolucent board, a stainless under-frame and 10 x 30 mm side
/// rails on standoffs with accessory clamps, an arm board stowed along the back section, and a wired hand
/// pendant hanging on the seat rail on a coiled cord. Joints: column lift, Trendelenburg tilt of the whole
/// top, back section, leg section and arm board.
public struct OperatingTable: RealArticulated {
    public static let id = "operating-table"
    public static let summary = "General surgical table: stainless base and column lift, four-section radiolucent top with black pads, side rails, arm board and hand pendant."
    public static let tags = ["prop", "medical", "surgical", "articulated", "furniture", "metal", "hospital"]
    public static let budget = 14000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 40, elevation: 20, distance: 1.0, studio: true)

    /// Pad width and thickness (m).
    public var padWidth: Float = 0.5
    public var padThickness: Float = 0.08
    /// Section lengths head to foot (m).
    public var sections: [Float] = [0.28, 0.56, 0.48, 0.7]
    /// Column lift travel (m).
    public var lift: Float = 0.3
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        let L = 3
        var rig = Rig(name: Self.id, lods: L, switchDistances: [5, 12])
        let steel: MaterialKey = "metal.casework", pad: MaterialKey = "vinyl.medical-black", boardMat: MaterialKey = "plastic.medical-grey:3C4044"
        let dark: MaterialKey = "plastic.matte:2A2B2D"
        func pick<T>(_ l: Int, _ a: T, _ b: T, _ c: T) -> T { l == 0 ? a : (l == 1 ? b : c) }
        func rbox(_ size: V3, _ r: Float, _ l: Int, _ mat: MaterialKey, seg0: Int = 2) -> Surface {
            l == 2 ? cuboid(size, material: mat) : Prim.roundedBox(size, radius: r, bevelSegments: l == 0 ? seg0 : 1, material: mat)
        }
        let gap: Float = 0.012
        let total = sections.reduce(0, +) + gap * Float(sections.count - 1)
        var z0s: [Float] = []
        var z = -total / 2
        for s in sections { z0s.append(z); z += s + gap }
        let zc: Float = z0s[2] + sections[2] / 2 - 0.05     // column under the seat
        let headY: Float = 0.62                             // column head (tilt axis)
        let boardY0: Float = 0.655, boardT: Float = 0.02, padT = padThickness
        let padY0 = boardY0 + boardT, padTop = padY0 + padT
        let railX = padWidth / 2 + 0.035

        // MARK: base and lower shroud
        for l in 0..<L {
            var m = Model(name: Self.id)
            let plate = Shape2D.roundedRect(0.6, 1.02, radius: 0.08, segments: pick(l, 6, 3, 2))
            m.add(Prim.extrude(plate, depth: 0.05, bevel: pick(l, 0.008, 0.006, 0.0), bevelSegments: pick(l, 2, 1, 1), material: steel),
                  Xform(translation: V3(0, 0.03, zc + 0.02), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
            m.add(Prim.extrude(Shape2D.offset(plate, 0.004), depth: 0.008, bevel: pick(l, 0.002, 0.0, 0.0), bevelSegments: 1, material: "rubber"),
                  Xform(translation: V3(0, 0.004, zc + 0.02), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
            // Lower column shroud.
            m.add(rbox(V3(0.36, 0.5, 0.28), 0.035, l, steel), Xform(translation: V3(0, 0.05 + 0.25, zc)))
            rig.base[l] = m
        }
        // Floor locks and foot-pedal pads (LOD0/1), tape on the base.
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
            for l in 0..<2 {
                rig.base[l].add(Prim.cylinder(radius: 0.03, height: 0.012, bevel: 0.003, segments: pick(l, 16, 8, 6), bevelSegments: 1, material: dark),
                                Xform(translation: V3(sx * 0.22, 0.054, zc + 0.02 + sz * 0.42)))
            }
        }}
        rig.base[0].add(Prim.roundedBox(V3(0.12, 0.012, 0.06), radius: 0.004, bevelSegments: 1, material: dark), Xform(translation: V3(0, 0.06, zc + 0.47)))
        // Kick-zone scuffs on the base plate at the foot end.
        var scuffs = Surface(material: "rubber.tubing:3A3836")
        for _ in 0..<6 {
            let x = rng.float(-0.25...0.25), zz = zc + 0.02 + rng.float(0.3...0.5), len = rng.float(0.02...0.07)
            scuffs.append(cuboid(V3(len, 0.0004, rng.float(0.002...0.005)), material: "rubber.tubing:3A3836"),
                          Xform(translation: V3(x, 0.0552, zz), rotation: simd_quatf(degrees: rng.float(-40...40), axis: .up)))
        }
        rig.base[0].add(scuffs)

        // MARK: lift (upper shroud) and tilt (column head with every section)
        rig.part("lift", pivot: V3(0, 0.55, zc), joint: .slide(axis: V3(0, 1, 0), 0...lift, duration: 2.5))
        for l in 0..<L {
            rig.add(rbox(V3(0.33, 0.36, 0.25), 0.03, l, steel), Xform(translation: V3(0, 0.25 + 0.18, zc)), to: "lift", lods: l...l)
            rig.add(rbox(V3(0.3, 0.05, 0.22), 0.012, l, steel), Xform(translation: V3(0, headY - 0.015, zc)), to: "lift", lods: l...l)
        }
        // Ownership tape label on the shroud.
        rig.add(cuboid(V3(0.08, 0.025, 0.0006), material: "paper.sheet:ECE9DC"), Xform(translation: V3(0, 0.52, zc + 0.1255)), to: "lift", lods: 0...0)
        rig.part("tilt", parent: "lift", pivot: V3(0, headY, zc), joint: .hinge(axis: V3(1, 0, 0), -20...20, duration: 2.0))
        for l in 0..<L {
            // Column head yoke and the longitudinal under-frame of seat.
            rig.add(rbox(V3(0.36, 0.035, 0.42), 0.01, l, steel), Xform(translation: V3(0, headY + 0.012, zc + 0.05)), to: "tilt", lods: l...l)
        }

        // Section builder: board, pad, under-frame, side rails on standoffs.
        func section(_ part: String, _ k: Int, headEnd: Bool = false) {
            let z0 = z0s[k], len = sections[k], cz = z0 + len / 2
            for l in 0..<L {
                rig.add(rbox(V3(padWidth - 0.01, boardT, len - 0.004), 0.004, l, boardMat, seg0: 1), Xform(translation: V3(0, boardY0 + boardT / 2, cz)), to: part, lods: l...l)
                let pr: Float = headEnd ? 0.035 : 0.025
                rig.add(l == 2 ? cuboid(V3(padWidth, padT, len), material: pad)
                               : Prim.roundedBox(V3(padWidth, padT, len), radius: pr, bevelSegments: pick(l, 3, 1, 1), material: pad),
                        Xform(translation: V3(0, padY0 + padT / 2, cz)), to: part, lods: l...l)
                for sx: Float in [-1, 1] {
                    rig.add(rbox(V3(0.03, 0.025, len - 0.02), 0.004, l, steel, seg0: 1), Xform(translation: V3(sx * 0.2, boardY0 - 0.0125, cz)), to: part, lods: l...l)
                    if l < 2 || k != 0 {
                        rig.add(rbox(V3(0.01, 0.03, len - 0.05), 0.003, l, "metal.surgical", seg0: 1), Xform(translation: V3(sx * railX, boardY0 + 0.01, cz)), to: part, lods: l...l)
                    }
                    for e: Float in [-1, 1] where l == 0 {
                        rig.add(cuboid(V3(railX - padWidth / 2 + 0.01, 0.018, 0.02), material: steel),
                                Xform(translation: V3(sx * (padWidth / 2 + (railX - padWidth / 2) / 2 - 0.005), boardY0 + 0.01, cz + e * (len / 2 - 0.06))), to: part, lods: l...l)
                    }
                }
            }
            // Pad seam welt around the top edge (LOD0).
            let welt = Shape2D.roundedRect(padWidth - 0.004, len - 0.004, radius: (headEnd ? 0.035 : 0.025), segments: 3).map { V3($0.x, padTop - 0.012, cz - $0.y) }
            rig.add(Prim.sweep(Shape2D.circle(0.0022, segments: 4), along: welt, closedPath: true, caps: false, material: pad), to: part, lods: 0...0)
        }
        // Seat on the tilt part.
        section("tilt", 2)
        // Back (with head section fixed to it) hinged at the top of the seat/back gap.
        let backPivot = V3(0, padTop, z0s[2] - gap / 2)
        rig.part("back", parent: "tilt", pivot: backPivot, joint: .hinge(axis: V3(1, 0, 0), 0...75, duration: 2.0))
        section("back", 1)
        section("back", 0, headEnd: true)
        // Legs hinged at the board underside of the seat/legs gap.
        rig.part("legs", parent: "tilt", pivot: V3(0, boardY0 - 0.025, z0s[3] - gap / 2), joint: .hinge(axis: V3(1, 0, 0), 0...90, duration: 2.0))
        section("legs", 3)
        // Head/back joint plate and seat/back hinge knuckles (stainless, under the boards).
        for sx: Float in [-1, 1] {
            rig.add(rbox(V3(0.03, 0.04, 0.05), 0.006, 0, steel), Xform(translation: V3(sx * 0.2, boardY0 - 0.01, z0s[1] - gap / 2)), to: "back", lods: 0...1)
            rig.add(Prim.cylinder(radius: 0.012, height: 0.04, bevel: 0.002, segments: 12, bevelSegments: 1, material: steel),
                    Xform(translation: V3(sx * 0.2 - 0.02, boardY0 - 0.025, z0s[3] - gap / 2), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "legs", lods: 0...1)
        }

        // Gel head ring on the head pad and a folded linen draw sheet across the seat.
        rig.add(Prim.torus(major: 0.06, minor: 0.024, segments: 20, sides: 8, minorY: 0.018, material: "rubber.silicone:4E7FA8"),
                Xform(translation: V3(0, padTop + 0.017, z0s[0] + sections[0] / 2 + 0.01)), to: "back", lods: 0...0)
        for l in 0..<2 {
            rig.add(Prim.superellipsoid(V3(padWidth - 0.04, 0.018, 0.36), exponent: 7, subdivisions: pick(l, 6, 3, 2), material: "fabric.linen"),
                    Xform(translation: V3(0.01, padTop + 0.007, z0s[2] + sections[2] / 2 - 0.02), rotation: simd_quatf(degrees: 1.5, axis: .up)), to: "tilt", lods: l...l)
        }
        // Accessory clamps on the rails (seat and legs).
        func clamp(_ part: String, _ x: Float, _ zz: Float) {
            let s: Float = x > 0 ? 1 : -1
            rig.add(Prim.roundedBox(V3(0.03, 0.05, 0.04), radius: 0.005, bevelSegments: 1, material: "metal.surgical"),
                    Xform(translation: V3(x + s * 0.012, boardY0 + 0.005, zz)), to: part, lods: 0...1)
            rig.add(Prim.cylinder(radius: 0.012, height: 0.025, bevel: 0.003, segments: 10, bevelSegments: 1, material: dark),
                    Xform(translation: V3(x + s * 0.027, boardY0 + 0.005, zz), rotation: simd_quatf(degrees: s * -90, axis: V3(0, 0, 1))), to: part, lods: 0...0)
        }
        clamp("tilt", railX, z0s[2] + 0.12)
        clamp("legs", -railX, z0s[3] + 0.3)

        // MARK: arm board, stowed along the back section on +X, swings out 90 degrees about Y
        let abPivot = V3(railX + 0.03, boardY0 + 0.01, z0s[1] + 0.06)
        rig.part("armboard", parent: "back", pivot: abPivot, joint: .hinge(axis: V3(0, 1, 0), 0...90, duration: 1.0))
        let abLen: Float = 0.48, abW: Float = 0.15
        let abC = V3(abPivot.x + abW / 2 + 0.01, boardY0 + 0.03, abPivot.z + 0.03 + abLen / 2)
        for l in 0..<L {
            rig.add(rbox(V3(abW, 0.015, abLen), 0.004, l, boardMat, seg0: 1), Xform(translation: abC + V3(0, -0.012, 0)), to: "armboard", lods: l...l)
            rig.add(l == 2 ? cuboid(V3(abW, 0.05, abLen), material: pad)
                           : Prim.roundedBox(V3(abW, 0.05, abLen), radius: 0.02, bevelSegments: pick(l, 2, 1, 1), material: pad),
                    Xform(translation: abC + V3(0, 0.02, 0)), to: "armboard", lods: l...l)
        }
        rig.add(Prim.roundedBox(V3(0.05, 0.05, 0.06), radius: 0.006, bevelSegments: 1, material: "metal.surgical"),
                Xform(translation: abPivot + V3(0.0, -0.005, 0.02)), to: "armboard", lods: 0...1)
        rig.add(Prim.cylinder(radius: 0.014, height: 0.03, bevel: 0.003, segments: 10, bevelSegments: 1, material: dark),
                Xform(translation: abPivot + V3(0.0, -0.045, 0.02)), to: "armboard", lods: 0...0)
        // Velcro arm strap across the board.
        rig.add(cuboid(V3(abW + 0.006, 0.054, 0.05), material: "fabric.nylon:1E1E20"), Xform(translation: abC + V3(0, 0.02, 0.1)), to: "armboard", lods: 0...1)

        // MARK: hand pendant on the -X seat rail with a coiled cord to the column head
        let pz = z0s[2] + 0.3, px = -railX - 0.03
        let pTop = boardY0 + 0.0
        rig.add(Prim.roundedBox(V3(0.012, 0.035, 0.02), radius: 0.004, bevelSegments: 1, material: "metal.surgical"), Xform(translation: V3(-railX - 0.012, pTop + 0.005, pz)), to: "tilt", lods: 0...1)
        for l in 0..<L {
            rig.add(rbox(V3(0.032, 0.2, 0.075), 0.012, l, "plastic.medical"), Xform(translation: V3(px, pTop - 0.1, pz)), to: "tilt", lods: l...l)
        }
        var keys = Surface(material: dark)
        for r in 0..<5 { for c in 0..<2 {
            keys.append(cuboid(V3(0.004, 0.018, 0.022), material: dark), Xform(translation: V3(px - 0.0165, pTop - 0.04 - Float(r) * 0.026, pz - 0.015 + Float(c) * 0.03)))
        }}
        rig.add(keys, to: "tilt", lods: 0...0)
        // Coiled cord below the pendant, then a smooth lead up to the column head.
        let coilTop = V3(px, pTop - 0.2, pz)
        var coil = Prim.helix(radius: 0.011, pitch: 0.009, turns: 14, wire: 0.0022, perTurn: 10, sides: 5, material: "rubber.tubing:E8E6E0")
        coil = coil.transformed(Xform(translation: coilTop, rotation: simd_quatf(degrees: 180, axis: V3(1, 0, 0))))
        rig.add(coil, to: "tilt", lods: 0...0)
        let lead = catmull([coilTop + V3(0, -0.126, 0), coilTop + V3(0.03, -0.16, -0.03), V3(-0.12, headY - 0.05, zc + 0.15), V3(-0.15, headY, zc + 0.15)], per: 4)
        for l in 0..<2 {
            rig.add(Prim.tube(lead, radii: lead.map { _ in 0.003 }, sides: pick(l, 6, 4, 4), seamTile: 0.05, material: "rubber.tubing:E8E6E0"), to: "tilt", lods: l...l)
        }
        rig.add(Prim.tube([coilTop, coilTop + V3(0, -0.126, 0)], radii: [0.012, 0.012], sides: 6, seamTile: 0.05, material: "rubber.tubing:E8E6E0"), to: "tilt", lods: 1...2)

        groundAO(&rig, height: 0.12, floor: 0.55)
        rig.states = [
            RigState("flat"),
            RigState("high", ["lift": lift * 0.93]),
            RigState("beach-chair", ["lift": 0.08, "tilt": 8, "back": 62, "legs": 38]),
            RigState("trendelenburg", ["lift": 0.2, "tilt": -16]),
            RigState("arm-out", ["armboard": 90]),
        ]
        return rig
    }
}
