import simd
import Foundation

/// Exterior six-panel entry door set: 0.91 x 2.13 m x 45 mm painted stile-and-rail leaf (six fielded
/// panels: two short over four tall), 35 mm jambs and head with an integral stop, flat casing with back
/// band and drip cap, oak threshold, three butt hinges, brass knob on a rose and a deadbolt escutcheon.
/// Exterior faces +Z; base y = 0 is the top of the floor; the leaf swings inward (-Z) on its left
/// hinges, so the opening is walkable in the "open" state.
public struct SixPanelDoor: RealArticulated {
    public static let id = "six-panel-door"
    public static let summary = "Exterior six-panel entry door, 0.91 x 2.13 m: painted stile-and-rail leaf with raised panels, cased frame, brass knob, deadbolt, hinges and oak sill."
    public static let tags = ["structure", "architecture", "facade", "door", "wood", "articulated"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 6, distance: 1.05, studio: true)

    /// Leaf width (m); the rough opening grows with it.
    public var leafWidth: Float = 0.91
    /// Leaf height (m).
    public var leafHeight: Float = 2.13
    /// Leaf thickness (m).
    public var leafThickness: Float = 0.045
    /// Jamb depth through the wall (m).
    public var jambDepth: Float = 0.14
    /// Casing face width (m).
    public var casingWidth: Float = 0.09
    /// Panel rows bottom up, as relative heights (classic six-panel: tall, tall, short).
    public var panelRows: [Float] = [1.0, 1.0, 0.42]
    /// Panels per row.
    public var panelColumns: Int = 2
    /// Leaf paint (painted wood, `:RRGGBB` tints).
    public var leafMaterial: MaterialKey = "wood.painted-shaker-worn:1E3A2C"
    /// Frame and casing paint.
    public var trimMaterial: MaterialKey = "wood.painted-shaker:EEEBE2"
    public var sillMaterial: MaterialKey = "wood.oak"
    public var hardware: MaterialKey = "metal.brass-aged"
    /// Brass kick plate on the bottom rail.
    public var kickPlate = true
    public var kickMaterial: MaterialKey = "metal.brass"
    /// Knob height above the floor (m).
    public var knobHeight: Float = 0.97
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [9])
        let W = leafWidth, H = leafHeight, T = leafThickness, D = jambDepth
        let gap: Float = 0.003, sillH: Float = 0.022, jamb: Float = 0.022
        let xo = W / 2 + gap, headY = sillH + H + gap
        let zFront = D / 2                       // exterior wall face
        let zf = zFront - 0.025                  // leaf exterior face, set back in the jamb
        let zb = zf - T

        // MARK: frame, casing, sill (static)
        var frame: [Surface] = []
        for sx: Float in [-1, 1] {
            frame.append(FK.vbox(V3(jamb, headY + jamb, D), V3(sx * (xo + jamb / 2), (headY + jamb) / 2, 0), trimMaterial, r: 0.002))
            // Stop behind the leaf.
            frame.append(FK.vbox(V3(0.014, headY - sillH, 0.035), V3(sx * (xo - 0.007), sillH + (headY - sillH) / 2, zb - 0.0175 - 0.002), trimMaterial, r: 0.002))
        }
        frame.append(HK.box(V3(2 * xo + 0.002, jamb, D), V3(0, headY + jamb / 2, 0), trimMaterial, r: 0.002))
        frame.append(HK.box(V3(2 * xo, 0.014, 0.035), V3(0, headY - 0.007, zb - 0.0195), trimMaterial, r: 0.002))
        frame += FK.casing(openW: 2 * (xo + jamb), openH: headY + jamb, width: casingWidth, thick: 0.02, z: zFront, mat: trimMaterial, headHeight: casingWidth * 1.25)
        // Oak threshold with a sloped exterior nose.
        let sillShape: [V2] = [V2(-D / 2, 0), V2(D / 2 + 0.03, 0), V2(D / 2 + 0.03, 0.012), V2(zb + 0.01, sillH), V2(-D / 2, sillH)]
        var sill = Prim.extrude(Shape2D.rounded(sillShape, radius: 0.003), depth: 2 * (xo + jamb), bevel: 0.002, bevelSegments: 1, material: sillMaterial)
        sill = sill.transformed(Xform(rotation: simd_quatf(degrees: -90, axis: V3(0, 1, 0))))
        frame.append(sill)
        rig.addBase(frame)

        // MARK: leaf
        let hx = -xo + 0.001, hz = zb - 0.002
        rig.part("leaf", pivot: V3(hx, 0, hz), joint: .hinge(axis: .up, 0...100, duration: 1.5))
        let leaf = FK.panelLeaf(w: W, h: H, t: T, rows: panelRows, cols: panelColumns, stile: 0.115,
                                bottomRail: 0.24, topRail: 0.115, midRail: 0.105, mat: leafMaterial)
        let place = Xform(translation: V3(0, sillH + 0.002, zb + T / 2))
        for s in leaf { rig.add(s, place.jittered(&rng, deg: 0, offset: 0.00015), to: "leaf") }

        // Brass mail slot in the lock rail and a kick plate scuffed by boots.
        let slot = Prim.extrude(Shape2D.roundedRect(0.27, 0.07, radius: 0.006), depth: 0.004, bevel: 0.0015, bevelSegments: 1, material: hardware)
        rig.add(slot, Xform(translation: V3(0, sillH + 0.002 + 0.24 + (H - 0.24 - 0.115 - 0.21) * 1 / 2.42 + 0.0525, zf + 0.002)), to: "leaf")
        rig.add(HK.box(V3(0.22, 0.022, 0.006), V3(0, sillH + 0.002 + 0.24 + (H - 0.24 - 0.115 - 0.21) * 1 / 2.42 + 0.0525, zf + 0.005), hardware, r: 0.002), .identity, to: "leaf")
        if kickPlate {
            rig.add(HK.box(V3(W - 0.04, 0.2, 0.0015), V3(0, sillH + 0.012 + 0.1, zf + 0.00075), kickMaterial, r: 0.0007, seg: 1), .identity, to: "leaf")
        }

        // Hinges: knuckles on the interior hinge edge, frame segments static.
        for hy in [sillH + 0.25, sillH + H / 2 + 0.1, sillH + H - 0.2] {
            let k = FK.hingeKnuckles(at: V3(hx, hy, hz), length: 0.1, r: 0.0065, mat: hardware)
            rig.addBase(k.frame)
            rig.add(k.leaf, to: "leaf", lods: 0...0)
        }

        // Knob both faces, deadbolt above on the exterior, thumbturn inside.
        let kx = W / 2 - 0.06
        rig.add(FK.knob(at: V3(kx, knobHeight, zf), n: V3(0, 0, 1), mat: hardware), .identity, to: "leaf")
        rig.add(FK.knob(at: V3(kx, knobHeight, zb), n: V3(0, 0, -1), mat: hardware), .identity, to: "leaf")
        let bolt = Prim.lathe([V2(0, 0), V2(0.03, 0), V2(0.03, 0.004), V2(0.026, 0.008), V2(0.012, 0.01), V2(0, 0.01)], segments: 24, seamTile: 0.05, material: hardware)
        rig.add(bolt, Xform(translation: V3(kx, knobHeight + 0.14, zf), rotation: facing(V3(0, 0, 1))), to: "leaf")
        rig.add(Prim.roundedBox(V3(0.003, 0.012, 0.002), radius: 0.0008, bevelSegments: 1, material: "plastic.black"),
                Xform(translation: V3(kx, knobHeight + 0.14, zf + 0.0105)), to: "leaf", lods: 0...0)
        rig.add(bolt, Xform(translation: V3(kx, knobHeight + 0.14, zb), rotation: facing(V3(0, 0, -1))), to: "leaf")
        rig.add(HK.box(V3(0.008, 0.03, 0.012), V3(kx, knobHeight + 0.14, zb - 0.015), hardware, r: 0.003), .identity, to: "leaf", lods: 0...0)
        // Strike plates on the lock jamb.
        for y in [knobHeight, knobHeight + 0.14] {
            rig.addBase([HK.box(V3(0.002, 0.07, 0.025), V3(xo + 0.0005, y, zb + T / 2), hardware, r: 0.0008, seg: 1)], lods: 0...0)
        }

        groundAO(&rig, height: 0.15, floor: 0.6)
        rig.states = [RigState("closed"), RigState("ajar", ["leaf": 20]), RigState("open", ["leaf": 90])]
        return rig
    }
}
