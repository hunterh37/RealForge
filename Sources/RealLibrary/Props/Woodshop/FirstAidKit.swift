import simd
import Foundation

/// Wall-mount first aid cabinet, 340 W x 420 H x 130 D mm: red ABS case with a molded front rim, carry
/// handle and keyhole wall tabs; a tray door with a raised white cross on a full-height piano hinge (left
/// edge) and a snap latch on the right; a shelf divider; stocked with gauze pad packs, adhesive bandage
/// boxes, a roller bandage, a tape roll, nitrile gloves and a contents sticker inside the door.
///
/// Rig: part `door` hinges about +Y through the left front edge, range -115...0 deg (negative swings the
/// door out toward +Z). States `closed` (default) and `open` (-110). Base at y = 0, centered, back at
/// z = -depth/2 (the wall), door facing +Z.
public struct FirstAidKit: RealArticulated {
    public static let id = "first-aid-kit"
    public static let summary = "Wall-mount ABS first aid cabinet with a white cross on a hinged front door, stocked with gauze, bandage boxes, tape and gloves."
    public static let tags = ["prop", "workshop", "plastic", "medical", "articulated"]
    public static let budget = 9_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 28, elevation: 10, distance: 0.8, studio: true)

    /// Case width, height, depth (m).
    public var width: Float = 0.34
    public var height: Float = 0.42
    public var depth: Float = 0.13
    /// Case color (sRGB hex) and cross color.
    public var color: UInt32 = 0xC21F1A
    public var crossColor: UInt32 = 0xF4F4F2
    /// Door opening angle for the `open` state (deg, negative opens).
    public var openAngle: Float = -110
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 1)
        let W = width, H = height, D = depth
        let abs: MaterialKey = "plastic.tool:" + String(format: "%06X", color)
        let white: MaterialKey = "plastic.tool:" + String(format: "%06X", crossColor)
        let doorT: Float = 0.018, wall: Float = 0.004
        let zb = -D / 2, zf = D / 2 - doorT                     // case back, case front rim plane
        let caseD = zf - zb

        func base(_ s: Surface, _ x: Xform = .identity) { rig.base[0].add(s, x) }
        // MARK: case shell: molded walls with 22 mm corner radii (swept), flat back, rim around the opening
        let cr: Float = 0.022
        let wallPath = Shape2D.roundedRect(W - wall, H - wall, radius: cr - wall / 2, segments: 5).map { V3($0.x, H / 2 + $0.y, zb + caseD / 2) }
        base(Prim.sweep(Shape2D.roundedRect(caseD, wall, radius: 0.0015, segments: 1), along: wallPath, up: V3(0, 0, 1), closedPath: true, caps: false, material: abs))
        base(Prim.extrude(Shape2D.roundedRect(W - 0.003, H - 0.003, radius: cr, segments: 5), depth: wall, bevel: 0.001, bevelSegments: 1, material: abs),
             Xform(translation: V3(0, H / 2, zb + wall / 2)))
        let rimPath = Shape2D.roundedRect(W - 0.004, H - 0.004, radius: cr - 0.002, segments: 5).map { V3($0.x, H / 2 + $0.y, zf - 0.003) }
        base(Prim.sweep(Shape2D.roundedRect(0.006, 0.008, radius: 0.0025, segments: 1), along: rimPath, up: V3(0, 0, 1), closedPath: true, caps: false, material: abs))
        // Shelf divider.
        let shelfY: Float = H * 0.52
        base(Prim.roundedBox(V3(W - 2 * wall - 0.001, 0.004, caseD - 0.012), radius: 0.0015, bevelSegments: 1, material: abs),
             Xform(translation: V3(0, shelfY, zb + (caseD - 0.012) / 2 + wall)))
        // Carry handle on top: molded arch.
        let hp = catmull([V3(-0.06, H - 0.002, zb + caseD * 0.5), V3(-0.052, H + 0.024, zb + caseD * 0.5), V3(0.052, H + 0.024, zb + caseD * 0.5), V3(0.06, H - 0.002, zb + caseD * 0.5)], per: 4)
        base(Prim.sweep(Shape2D.roundedRect(0.014, 0.018, radius: 0.006, segments: 2), along: hp, up: V3(0, 0, 1), material: abs))
        // Keyhole wall tabs on top, flush with the back.
        for sx: Float in [-1, 1] {
            let ty = H + 0.01
            base(Prim.roundedBox(V3(0.04, 0.026, 0.004), radius: 0.0018, bevelSegments: 1, material: abs), Xform(translation: V3(sx * 0.11, ty - 0.008, zb + 0.002)))
            base(cuboid(V3(0.006, 0.011, 0.0006), material: "plastic.matte:2A1210"), Xform(translation: V3(sx * 0.11, ty - 0.006, zb + 0.0043)))
        }
        // Screws in the back (visible inside).
        for (sx, sy) in [(Float(-1), Float(1)), (1, 1), (-1, -1), (1, -1)] {
            var mm = Model(name: "s")
            rivet(&mm, at: V3(sx * (W / 2 - 0.03), H / 2 + sy * (H / 2 - 0.03), zb + wall), normal: V3(0, 0, 1), radius: 0.004, segments: 8, material: "metal.chrome")
            for s in mm.surfaces { base(s) }
        }
        // Hinge knuckles on the case side (alternating with the door's).
        let hingeX = -W / 2 - 0.0035, hingeZ = zf + 0.002
        for k in 0..<5 where k % 2 == 0 {
            let y0 = 0.02 + Float(k) * (H - 0.04) / 5
            base(Prim.cylinder(radius: 0.0035, height: (H - 0.04) / 5 - 0.001, bevel: 0.0008, segments: 10, bevelSegments: 1, material: abs),
                 Xform(translation: V3(hingeX, y0, hingeZ)))
        }

        // MARK: contents
        let floorY = wall, sy2 = shelfY + 0.002
        let backZ = zb + wall
        func box(_ size: V3, _ c: V3, _ tint: UInt32, label: MaterialKey?, yaw: Float = 0) {
            let x = Xform(translation: c + V3(0, size.y / 2, 0), rotation: simd_quatf(degrees: yaw, axis: .up))
            base(Prim.roundedBox(size, radius: 0.0012, bevelSegments: 1, material: "paper.sheet:" + String(format: "%06X", tint)), x)
            if let label {
                var q = Surface(material: label)
                let n = V3(0, 0, 1), w = size.x * 0.84, h = size.y * 0.78
                let a = q.add(V3(-w / 2, h / 2, size.z / 2 + 0.0004), n, V2(0, 0)), b = q.add(V3(w / 2, h / 2, size.z / 2 + 0.0004), n, V2(0.08, 0))
                let c2 = q.add(V3(w / 2, -h / 2, size.z / 2 + 0.0004), n, V2(0.08, 0.08)), d = q.add(V3(-w / 2, -h / 2, size.z / 2 + 0.0004), n, V2(0, 0.08))
                q.quad(a, d, c2, b); q.computeTangents()
                base(q, x)
            }
        }
        // Lower compartment: bandage boxes standing, roller bandage, tape roll.
        box(V3(0.095, 0.065, 0.045), V3(-0.1, floorY, backZ + 0.03), 0xF1EEE6, label: "label.supply-small", yaw: rng.float(-3...3))
        box(V3(0.095, 0.065, 0.045), V3(-0.1, floorY + 0.065, backZ + 0.03), 0xE6EEF4, label: "label.rx-small", yaw: rng.float(-4...4))
        box(V3(0.075, 0.1, 0.04), V3(0.015, floorY, backZ + 0.026), 0xF4F1EA, label: "label.supply-small", yaw: rng.float(-2...2))
        base(Prim.lathe([V2(0, 0), V2(0.028, 0), V2(0.03, 0.003), V2(0.03, 0.072), V2(0.028, 0.075), V2(0, 0.075)], segments: 18, seamTile: 0.05, material: "fabric.linen"),
             Xform(translation: V3(0.11, floorY + 0.03, backZ + 0.035), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        // Tape roll lying flat: white cloth tape on a core.
        base(Prim.lathe([V2(0.0125, 0), V2(0.024, 0), V2(0.025, 0.002), V2(0.025, 0.023), V2(0.024, 0.025), V2(0.0125, 0.025), V2(0.0125, 0)], segments: 18, seamTile: 0.05, material: "fabric.linen"),
             Xform(translation: V3(0.035, floorY + 0.1, backZ + 0.07)))
        base(Prim.lathe([V2(0.0115, 0.0), V2(0.0128, 0.0), V2(0.0128, 0.026), V2(0.0115, 0.026)], segments: 14, seamTile: 0.05, material: "paper.sheet:B8A58A"),
             Xform(translation: V3(0.035, floorY + 0.0995, backZ + 0.07)))
        // Nitrile gloves: a folded pair, flattened.
        for k in 0..<2 {
            var g = Prim.superellipsoid(V3(0.1, 0.012, 0.05), exponent: 2.6, subdivisions: 4, material: "rubber.silicone:5A7EC8")
            g.deform { p in V3(p.x, p.y + 0.004 * sin(p.x * 60), p.z * (1 - 0.25 * max(0, p.x) / 0.05)) }
            base(g, Xform(translation: V3(-0.085, floorY + 0.137 + Float(k) * 0.01, backZ + 0.045 + Float(k) * 0.006), rotation: simd_quatf(degrees: 8 - Float(k) * 14, axis: .up)))
        }
        // Upper compartment: stacked gauze pad packets, more boxes.
        for k in 0..<7 {
            let x = Xform(translation: V3(-0.085 + rng.float(-0.003...0.003), sy2 + 0.004 + Float(k) * 0.0075, backZ + 0.05), rotation: simd_quatf(degrees: rng.float(-5...5), axis: .up))
            base(Prim.roundedBox(V3(0.09, 0.007, 0.085), radius: 0.0025, bevelSegments: 1, material: k % 3 == 1 ? "paper.exam" : "paper.sheet:F5F3EE"), x)
        }
        box(V3(0.11, 0.08, 0.05), V3(0.06, sy2, backZ + 0.034), 0xF2EFE8, label: "label.supply-small", yaw: rng.float(-2...2))
        box(V3(0.06, 0.12, 0.035), V3(0.06, sy2 + 0.08, backZ + 0.024), 0xE9F0E6, label: "label.rx-small", yaw: rng.float(-3...3))
        box(V3(0.05, 0.09, 0.03), V3(-0.08, sy2 + 0.056, backZ + 0.02), 0xF6E8E4, label: "label.supply-small")

        // MARK: door (tray lid hinged on the left front edge)
        rig.part("door", pivot: V3(hingeX, H / 2, hingeZ), joint: .hinge(axis: .up, -115...0, duration: 0.7))
        let dz0 = zf + 0.0005
        rig.add(Prim.extrude(Shape2D.roundedRect(W, H, radius: cr, segments: 5), depth: 0.005, bevel: 0.002, bevelSegments: 2, material: abs),
                Xform(translation: V3(0, H / 2, dz0 + doorT - 0.0025)), to: "door")
        // Tray skirt (the door's rim walls) that closes over the case rim.
        let skirt = Shape2D.roundedRect(W - 0.004, H - 0.004, radius: cr - 0.002, segments: 5).map { V3($0.x, H / 2 + $0.y, dz0 + (doorT - 0.004) / 2) }
        rig.add(Prim.sweep(Shape2D.roundedRect(doorT - 0.004, 0.004, radius: 0.0015, segments: 1), along: skirt, up: V3(0, 0, 1), closedPath: true, caps: false, material: abs), to: "door")
        // Raised molded panel and the white cross.
        rig.add(Prim.extrude(Shape2D.roundedRect(W - 0.05, H - 0.06, radius: 0.014, segments: 4), depth: 0.003, bevel: 0.0012, bevelSegments: 2, material: abs),
                Xform(translation: V3(0, H / 2, dz0 + doorT + 0.001)), to: "door")
        // Finger recess beside the latch.
        rig.add(Prim.superellipsoid(V3(0.012, 0.06, 0.006), exponent: 3, subdivisions: 3, material: "plastic.matte:5A0E0B"),
                Xform(translation: V3(W / 2 - 0.012, H / 2, dz0 + doorT + 0.0002)), to: "door")
        let cw: Float = 0.12, ct: Float = 0.038
        let crossY = H * 0.55
        let crossOutline = Shape2D.rounded([V2(-ct / 2, -cw / 2), V2(ct / 2, -cw / 2), V2(ct / 2, -ct / 2), V2(cw / 2, -ct / 2), V2(cw / 2, ct / 2), V2(ct / 2, ct / 2),
                                            V2(ct / 2, cw / 2), V2(-ct / 2, cw / 2), V2(-ct / 2, ct / 2), V2(-cw / 2, ct / 2), V2(-cw / 2, -ct / 2), V2(-ct / 2, -ct / 2)], radius: 0.002, segments: 2)
        rig.add(Prim.extrude(crossOutline, depth: 0.002, bevel: 0.0006, bevelSegments: 1, material: white), Xform(translation: V3(0, crossY, dz0 + doorT + 0.0025)), to: "door")
        // Printed label below the cross (generic, greeked text) on a slightly raised white plate.
        rig.add(Prim.roundedBox(V3(0.17, 0.05, 0.0012), radius: 0.0005, bevelSegments: 1, material: white), Xform(translation: V3(0, H * 0.22, dz0 + doorT + 0.0026)), to: "door")
        var lab = Surface(material: "label.first-aid")
        let lw: Float = 0.16, lh: Float = 0.042, lz = dz0 + doorT + 0.0033, ly = H * 0.22
        let la = lab.add(V3(-lw / 2, ly + lh / 2, lz), V3(0, 0, 1), V2(0, 0)), lb = lab.add(V3(lw / 2, ly + lh / 2, lz), V3(0, 0, 1), V2(1, 0))
        let lc = lab.add(V3(lw / 2, ly - lh / 2, lz), V3(0, 0, 1), V2(1, 1)), ld = lab.add(V3(-lw / 2, ly - lh / 2, lz), V3(0, 0, 1), V2(0, 1))
        lab.quad(la, ld, lc, lb); lab.computeTangents()
        rig.add(lab, to: "door")
        // Hinge knuckles on the door.
        for k in 0..<5 where k % 2 == 1 {
            let y0 = 0.02 + Float(k) * (H - 0.04) / 5
            rig.add(Prim.cylinder(radius: 0.0035, height: (H - 0.04) / 5 - 0.001, bevel: 0.0008, segments: 10, bevelSegments: 1, material: abs),
                    Xform(translation: V3(hingeX, y0, hingeZ)), to: "door")
        }
        rig.add(Prim.cylinder(radius: 0.0012, height: H - 0.036, bevel: 0.0004, segments: 6, bevelSegments: 1, material: "metal.chrome"),
                Xform(translation: V3(hingeX, 0.018, hingeZ)), to: "door")
        // Snap latch on the right edge: thumb tab with grip ridges.
        let lx = W / 2 + 0.002
        rig.add(Prim.roundedBox(V3(0.012, 0.05, 0.022), radius: 0.004, bevelSegments: 2, material: white), Xform(translation: V3(lx, H / 2, dz0 + doorT * 0.5)), to: "door")
        for k in -2...2 {
            rig.add(cuboid(V3(0.0015, 0.0025, 0.016), material: white), Xform(translation: V3(lx + 0.006, H / 2 + Float(k) * 0.007, dz0 + doorT * 0.5)), to: "door")
        }
        // Contents sticker inside the door.
        var sticker = Surface(material: "label.supply-small")
        let sw: Float = 0.16, sh: Float = 0.22, sz = dz0 - 0.0003
        let n = V3(0, 0, -1)
        let a = sticker.add(V3(-sw / 2, H / 2 + sh / 2, sz), n, V2(0, 0)), b = sticker.add(V3(sw / 2, H / 2 + sh / 2, sz), n, V2(0.08, 0))
        let c = sticker.add(V3(sw / 2, H / 2 - sh / 2, sz), n, V2(0.08, 0.08)), d = sticker.add(V3(-sw / 2, H / 2 - sh / 2, sz), n, V2(0, 0.08))
        sticker.quad(a, b, c, d); sticker.computeTangents()
        rig.add(sticker, to: "door")
        // Door inner face plate (white-ish matte so the sticker reads), slightly behind the outer plate.
        rig.add(Prim.extrude(Shape2D.roundedRect(W - 0.008, H - 0.008, radius: cr - 0.004, segments: 4), depth: 0.001, bevel: 0.0003, bevelSegments: 1, material: abs),
                Xform(translation: V3(0, H / 2, dz0 + 0.0005)), to: "door")
        // Monthly check tag on a loop through the latch (story detail).
        let tagTop = V3(lx + 0.006, H / 2 - 0.022, dz0 + doorT * 0.5 + 0.004)
        rig.add(Prim.tube([tagTop + V3(0, 0.004, 0), tagTop + V3(0.004, -0.016, 0.004)], radii: [0.0006, 0.0006], sides: 4, seamTile: 0.01, material: "plastic.matte:EDEAE0", capEnd: false), to: "door")
        var tag = Surface(material: "label.inspection")
        let tw: Float = 0.03, th: Float = 0.055
        let tq = simd_quatf(degrees: 8, axis: V3(0, 0, 1)) * simd_quatf(degrees: -30, axis: .up)
        let tc = tagTop + V3(0.005, -0.016 - th / 2, 0.008)
        for (side, nn) in [(Float(1), V3(0, 0, 1)), (-1, V3(0, 0, -1))] {
            let o = V3(0, 0, side * 0.0002)
            let ta = tag.add(tq.act(V3(-tw / 2, th / 2, 0) + o) + tc, tq.act(nn), V2(0, 0)), tb = tag.add(tq.act(V3(tw / 2, th / 2, 0) + o) + tc, tq.act(nn), V2(1, 0))
            let tcc = tag.add(tq.act(V3(tw / 2, -th / 2, 0) + o) + tc, tq.act(nn), V2(1, 1)), td = tag.add(tq.act(V3(-tw / 2, -th / 2, 0) + o) + tc, tq.act(nn), V2(0, 1))
            if side > 0 { tag.quad(ta, td, tcc, tb) } else { tag.quad(ta, tb, tcc, td) }
        }
        tag.computeTangents()
        rig.add(tag, to: "door")

        rig.states = [RigState("closed"), RigState("open", ["door": openAngle])]
        groundAO(&rig, height: 0.05, floor: 0.7)
        return rig
    }
}
