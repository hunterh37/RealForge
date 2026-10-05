import simd
import Foundation

/// Shaker base cabinet (frameless, full-overlay): painted five-piece drawer front over one or two
/// five-piece doors on concealed cup hinges, brushed-nickel bar pulls, plywood box with an adjustable
/// shelf and a drawer box, recessed toe kick, and an optional 3 cm quartz top with eased edges and a
/// 2.5 cm front overhang. `sinkCutout` cuts the top for an undermount sink and turns the drawer into a
/// tilt-out false front. Back of the box against the wall at `backZ`; doors face +Z.
public struct BaseCabinet: RealArticulated {
    public static let id = "base-cabinet"
    public static let summary = "Shaker base cabinet, 90 cm: painted drawer over two doors, nickel bar pulls, plywood box and shelf, 3 cm quartz top."
    public static let tags = ["prop", "kitchen", "wood", "furniture", "container", "articulated"]
    public static let budget = 11_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 16, distance: 1.7, studio: true)

    /// Cabinet width in meters (0.3...1.2). Under 0.6 m it gets one door.
    public var width: Float = 0.9
    /// Box height to the counter underside (standard 0.876-0.88 m).
    public var boxHeight: Float = 0.88
    /// Carcass depth behind the doors.
    public var carcassDepth: Float = 0.585
    /// Adds the stone top.
    public var countertop = true
    /// Top thickness (3 cm quartz).
    public var counterThickness: Float = 0.03
    /// Top overhang past the door faces.
    public var overhang: Float = 0.025
    /// Top overhang past each side (0 in a run; 0.02 for an end cabinet).
    public var sideOverhang: Float = 0
    /// Cuts the top for an undermount sink and makes the drawer a tilt-out false front.
    public var sinkCutout = false
    /// Sink cutout size (x, z) and corner radius.
    public var sinkSize = V2(0.74, 0.42)
    public var sinkRadius: Float = 0.015
    /// Single door hinged on the left (false: right). Ignored with two doors.
    public var hingeLeft = true
    /// Paint tint (sRGB hex), nil = factory white. Sage 0x9AA58E, navy 0x34404F.
    public var color: UInt32? = nil
    public var paint: MaterialKey = "wood.painted-shaker"
    public var top: MaterialKey = "stone.quartz"
    public var hardware: MaterialKey = "metal.brushed-nickel"
    public init() {}

    static let doorT: Float = 0.019, kickH: Float = 0.1, kickRecess: Float = 0.075, drawerH: Float = 0.15

    /// Total depth (box, doors and top overhang).
    public var depth: Float { carcassDepth + Self.doorT + (countertop ? overhang : 0) }
    /// Back face (wall side), asset space.
    public var backZ: Float { -depth / 2 }
    /// Door and drawer front faces.
    public var doorFrontZ: Float { backZ + carcassDepth + Self.doorT }
    /// Counter front edge (door faces without a top).
    public var frontZ: Float { depth / 2 }
    /// Work surface height (top of the stone, or of the box).
    public var topY: Float { boxHeight + (countertop ? counterThickness : 0) }
    /// Sink cutout center on the counter top surface, asset space.
    public var sinkCenter: V3 { V3(0, topY, frontZ - 0.075 - sinkSize.y / 2) }
    public var hasTwoDoors: Bool { width >= 0.6 }

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [6])
        let W = min(max(width, 0.3), 1.2), H = boxHeight
        let paintKey: MaterialKey = color.map { paint + ":" + String(format: "%06X", $0) } ?? paint
        // Drawer front and toe kick take the handled variant (grime where hands and shoes reach).
        let wornKey: MaterialKey = color.map { paint + "-worn:" + String(format: "%06X", $0) } ?? paint + "-worn"
        let ply: MaterialKey = "wood.plywood", plyEdge: MaterialKey = "wood.plywood-edge"
        let side: Float = 0.018, back: Float = 0.006
        let bz = backZ, cf = bz + carcassDepth, df = cf + Self.doorT
        let kick = Self.kickH
        let gapTop: Float = 0.004, reveal: Float = 0.0015, mid: Float = 0.0015

        func rbox(_ size: V3, _ c: V3, _ mat: MaterialKey, r: Float = 0.0015, seg: Int = 1) -> (Surface, Xform) {
            (Prim.roundedBox(size, radius: r, bevelSegments: seg, material: mat), Xform(translation: c))
        }

        for l in 0..<2 {
            var m = Model(name: Self.id)
            func add(_ b: (Surface, Xform)) { m.add(b.0, b.1) }
            // Finished sides with the toe-kick notch.
            for sx: Float in [-1, 1] {
                let x = sx * (W / 2 - side / 2)
                add(rbox(V3(side, H - kick, carcassDepth), V3(x, kick + (H - kick) / 2, bz + carcassDepth / 2), paintKey, r: 0.0025, seg: 2))
                add(rbox(V3(side, kick, carcassDepth - Self.kickRecess), V3(x, kick / 2, bz + (carcassDepth - Self.kickRecess) / 2), paintKey, r: 0.001))
            }
            let inW = W - 2 * side
            // Bottom deck, back, top rails (plywood, edge-banded fronts).
            add(rbox(V3(inW - 0.001, side, carcassDepth - back), V3(0, kick + side / 2, bz + back + (carcassDepth - back) / 2), ply, r: 0.001))
            add(rbox(V3(inW - 0.001, 0.0012, side), V3(0, kick + side / 2, cf + 0.0006), plyEdge, r: 0.0004))
            add(rbox(V3(inW - 0.001, H - kick - side, back), V3(0, kick + side + (H - kick - side) / 2, bz + back / 2), "laminate.white:A58C6C", r: 0.0005))
            for (z, d) in [(cf - 0.05, Float(0.1)), (bz + back + 0.05, Float(0.1))] {
                add(rbox(V3(inW - 0.001, side, d), V3(0, H - side / 2, z), ply, r: 0.001))
            }
            // Plywood liner on the inside faces of the sides (the outside is painted).
            for sx: Float in [-1, 1] {
                add(rbox(V3(0.002, H - kick - side, carcassDepth - back - 0.002), V3(sx * (inW / 2 - 0.001), kick + side + (H - kick - side) / 2, bz + back + (carcassDepth - back) / 2), ply, r: 0.0005))
            }
            // Toe kick board, recessed.
            add(rbox(V3(W - 0.004, kick - 0.006, 0.012), V3(0, (kick - 0.006) / 2 + 0.003, cf - Self.kickRecess + 0.006), wornKey, r: 0.001))
            // Adjustable shelf (not in sink bases) on four pins.
            let doorTop = H - gapTop - Self.drawerH - 0.003
            if !sinkCutout {
                let sy = kick + side + (doorTop - kick - side) * 0.5
                add(rbox(V3(inW - 0.004, side, carcassDepth - back - 0.04), V3(0, sy, bz + back + (carcassDepth - back - 0.04) / 2 + 0.002), ply, r: 0.0015, seg: 2))
                if l == 0 {
                    for sx: Float in [-1, 1] { for z in [cf - 0.06, bz + back + 0.06] {
                        m.add(Prim.cylinder(radius: 0.0025, height: 0.012, bevel: 0.0006, segments: 8, bevelSegments: 1, material: "metal.galvanized"),
                              Xform(translation: V3(sx * (inW / 2 - 0.012), sy - side / 2 - 0.003, z), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
                    }}
                    // System holes: 5 mm on 32 mm centres up the front of each side.
                    var hy = kick + side + 0.06
                    while hy < doorTop - 0.05 {
                        for sx: Float in [-1, 1] {
                            m.add(Prim.lathe([V2(0, 0), V2(0.0026, 0)], segments: 8, material: "metal.powdercoat:1C1C1C"),
                                  Xform(translation: V3(sx * (inW / 2 - 0.0021), hy, cf - 0.037), rotation: simd_quatf(degrees: sx * 90, axis: V3(0, 0, 1))))
                        }
                        hy += 0.064
                    }
                }
            } else if l == 0 {
                // Supply stops and a trap under the sink.
                for sx: Float in [-1, 1] {
                    m.add(Prim.cylinder(radius: 0.006, height: 0.08, bevel: 0.002, segments: 10, material: "metal.chrome"),
                          Xform(translation: V3(sx * 0.09, kick + 0.18, bz + back + 0.04), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
                    m.add(Prim.cylinder(radius: 0.004, height: H - kick - 0.32, bevel: 0.001, segments: 8, material: "metal.chrome"),
                          Xform(translation: V3(sx * 0.09, kick + 0.18, bz + back + 0.1)))
                }
                let trap = [V3(0, H - 0.02, sinkCenter.z), V3(0, H - 0.2, sinkCenter.z), V3(0, H - 0.3, sinkCenter.z + 0.03), V3(0, H - 0.33, sinkCenter.z - 0.05),
                            V3(0, H - 0.28, bz + back + 0.12), V3(0, H - 0.28, bz + back)]
                m.add(Prim.tube(catmull(trap, per: 4), radii: [0.02], sides: 12, seamTile: 0.1, material: "plastic.white"))
            }
            // Counter.
            if countertop {
                let hole: (center: V2, size: V2, radius: Float)? = sinkCutout ? (V2(0, sinkCenter.z), sinkSize, sinkRadius) : nil
                let slabD = carcassDepth + Self.doorT + overhang
                var slab = KitchenFit.counterSlab(width: W + 2 * sideOverhang, depth: slabD, thickness: counterThickness, ease: 0.003,
                                                  corner: 0.003, hole: hole.map { (V2($0.center.x, $0.center.y - (bz + slabD / 2)), $0.size, $0.radius) }, material: top)
                slab.bakeCavityAO(strength: 0.3)
                m.add(slab, Xform(translation: V3(0, H, bz + slabD / 2)))
            }
            rig.base[l] = m
        }

        // Drawer (or tilt-out false front over a sink).
        let drTop = H - gapTop, drBot = drTop - Self.drawerH
        let fw = W - 2 * reveal
        if sinkCutout {
            rig.part("drawer", pivot: V3(0, drBot, cf), joint: .hinge(axis: V3(1, 0, 0), 0...24, duration: 0.5))
        } else {
            rig.part("drawer", pivot: V3(0, drBot, cf), joint: .slide(axis: V3(0, 0, 1), 0...0.45, duration: 0.7))
        }
        for l in 0..<2 {
            var m = Model(name: "drawer")
            KitchenFit.shakerFront(&m, width: fw, height: Self.drawerH, frame: 0.055, at: V3(0, (drTop + drBot) / 2, df), material: wornKey, lite: l > 0)
            let pullLen: Float = W >= 0.6 ? 0.16 : 0.128
            m.add(barHandle(length: pullLen, standoff: 0.03, radius: 0.0055, overhang: 0.022, material: hardware), Xform(translation: V3(0, (drTop + drBot) / 2, df)))
            if !sinkCutout {
                // Drawer box: 12 mm plywood, dovetailed corners read as edge-banded ends.
                let bw = W - 2 * side - 0.026, bd = carcassDepth - 0.06, bh: Float = 0.1, by = drBot + 0.012
                let bzF = cf - 0.008, bzB = bzF - bd
                for sx: Float in [-1, 1] {
                    m.add(Prim.roundedBox(V3(bd, bh, 0.012), radius: 0.002, bevelSegments: 1, material: ply),
                          Xform(translation: V3(sx * (bw / 2 - 0.006), by + bh / 2, (bzF + bzB) / 2), rotation: simd_quatf(degrees: 90, axis: .up)))
                }
                for z in [bzF - 0.006, bzB + 0.006] {
                    m.add(Prim.roundedBox(V3(bw - 0.024, bh, 0.012), radius: 0.002, bevelSegments: 1, material: ply), Xform(translation: V3(0, by + bh / 2, z)))
                }
                m.add(cuboid(V3(bw - 0.02, 0.006, bd - 0.02), material: ply), Xform(translation: V3(0, by + 0.009, (bzF + bzB) / 2)))
                if l == 0 {
                    // Undermount slide rails.
                    for sx: Float in [-1, 1] {
                        m.add(cuboid(V3(0.012, 0.014, bd - 0.02), material: "metal.galvanized"), Xform(translation: V3(sx * (bw / 2 + 0.006), by - 0.002, (bzF + bzB) / 2)))
                    }
                }
            }
            rig.set(m, part: "drawer", lod: l)
        }

        // Doors.
        let dTop = drBot - 2 * reveal, dBot = kick + 0.002
        let dh = dTop - dBot, dcy = (dTop + dBot) / 2
        var doors: [(String, Float, Float, Float)] = []   // name, x0, x1, hinge side (-1 left)
        if hasTwoDoors {
            doors = [("left", -W / 2 + reveal, -mid, -1), ("right", mid, W / 2 - reveal, 1)]
        } else {
            doors = [(hingeLeft ? "left" : "right", -W / 2 + reveal, W / 2 - reveal, hingeLeft ? -1 : 1)]
        }
        for (name, x0, x1, hs) in doors {
            let hx = hs < 0 ? x0 : x1
            rig.part(name, pivot: V3(hx, dcy, cf), joint: .hinge(axis: .up, hs < 0 ? -110...0 : 0...110, duration: 0.8))
            for l in 0..<2 {
                var m = Model(name: name)
                let dw = x1 - x0, cx = (x0 + x1) / 2
                KitchenFit.shakerFront(&m, width: dw, height: dh, frame: 0.07, at: V3(cx, dcy, df), material: paintKey, bottomRail: wornKey, lite: l > 0)
                // Vertical pull at the opening edge, top.
                let px = hs < 0 ? x1 - 0.045 : x0 + 0.045
                let pl: Float = 0.128
                m.add(barHandle(length: pl, standoff: 0.03, radius: 0.0055, overhang: 0.02, material: hardware),
                      Xform(translation: V3(px, dTop - 0.07 - pl / 2, df), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
                if l == 0 {
                    for y in [dBot + 0.1, dTop - 0.1] {
                        KitchenFit.cupHinge(&m, at: V3(hx - hs * 0.0, y, cf - 0.0015), side: hs, material: "metal.galvanized")
                    }
                }
                rig.set(m, part: name, lod: l)
            }
        }
        _ = rng.float(0...1)

        groundAO(&rig, height: 0.1, floor: 0.55)
        let doorOpen: [String: Float] = hasTwoDoors ? ["left": -100, "right": 100] : [hingeLeft ? "left" : "right": hingeLeft ? -100 : 100]
        let drawerOpen: [String: Float] = ["drawer": sinkCutout ? 22 : 0.4]
        rig.states = [RigState("closed"), RigState("drawer-open", drawerOpen), RigState("doors-open", doorOpen),
                      RigState("all-open", drawerOpen.merging(doorOpen) { $1 })]
        return rig
    }
}
