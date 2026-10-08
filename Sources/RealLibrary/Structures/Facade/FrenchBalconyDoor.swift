import simd
import Foundation

/// French balcony door pair (porte-fenêtre) with a Juliet railing: 1.2 x 2.25 m opening, two 45 mm
/// inswing leaves each with a raised bottom panel under four divided lites, rebated meeting stiles,
/// espagnolette rod and handle, hinges, painted frame and casing, stone sill, and a wrought-iron
/// railing across the outside of the opening (top and bottom rails, balusters, C-scrolls).
/// Exterior faces +Z, base y = 0 is the floor line.
public struct FrenchBalconyDoor: RealArticulated {
    public static let id = "french-balcony-door"
    public static let summary = "French balcony door pair with Juliet railing: two glazed leaves with divided lites and panels, casing, wrought-iron railing across the opening."
    public static let tags = ["structure", "architecture", "facade", "door", "window", "wood", "glass", "metal", "articulated"]
    public static let budget = 26_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 6, distance: 1.0, studio: true)

    /// Clear opening width (m), split between two leaves.
    public var width: Float = 1.2
    /// Leaf height (m).
    public var height: Float = 2.25
    /// Glass rows per leaf above the bottom panel.
    public var liteRows: Int = 4
    /// Railing height above the floor (m).
    public var railHeight: Float = 0.95
    /// Baluster spacing (m).
    public var balusterSpacing: Float = 0.11
    public var leafMaterial: MaterialKey = "wood.painted-exterior:A9B0AC"
    public var frameMaterial: MaterialKey = "wood.painted-exterior:B4BAB6"
    public var ironMaterial: MaterialKey = "metal.wrought-iron"
    public var sillMaterial: MaterialKey = "stone.cast-grey"
    public var glass: MaterialKey = "glass.pane"
    public var hardware: MaterialKey = "metal.brass-aged"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [10])
        let H = height, T: Float = 0.045, D: Float = 0.16
        let xo = width / 2, W = width / 2 - 0.004
        let sy: Float = 0.04, fj: Float = 0.06
        let zf = D / 2 - 0.02, zb = zf - T
        let fm = frameMaterial

        var st: [Surface] = []
        for sx: Float in [-1, 1] {
            st.append(FK.vbox(V3(fj, H + sy + fj, D), V3(sx * (xo + fj / 2), (H + sy + fj) / 2, 0), fm))
            st.append(FK.vbox(V3(0.014, H, 0.03), V3(sx * (xo - 0.007), sy + H / 2, zf + 0.015), fm, r: 0.002))
        }
        st.append(HK.box(V3(2 * xo + 2 * fj, fj, D), V3(0, sy + H + 0.004 + fj / 2, 0), fm, r: 0.003))
        st += FK.casing(openW: 2 * (xo + fj), openH: sy + H + 0.004 + fj, width: 0.1, thick: 0.022, z: D / 2, mat: fm, headHeight: 0.13)
        // Stone sill under the leaves, projecting past the wall.
        st.append(HK.box(V3(2 * (xo + fj) + 0.2, sy, D + 0.1), V3(0, sy / 2, 0.05), sillMaterial, r: 0.006))
        rig.addBase(st)

        // MARK: leaves (inswing)
        for (name, sx, range) in [("left", Float(-1), Float(0)...100), ("right", Float(1), Float(-100)...0)] {
            let px = sx * (xo - 0.001), pz = zb - 0.002
            rig.part(name, pivot: V3(px, 0, pz), joint: .hinge(axis: .up, range, duration: 1.4))
            let cx = sx * (xo - W / 2 - 0.002)
            let leaf = FK.panelLeaf(w: W, h: H, t: T, rows: [0.5, 2.6], cols: 1, stile: 0.08, bottomRail: 0.16, topRail: 0.08, midRail: 0.08,
                                    mat: leafMaterial, glazed: [1], glass: glass, muntins: (1, liteRows))
            for s in leaf { rig.add(s, Xform(translation: V3(cx, sy + 0.003, zb + T / 2)).jittered(&rng, deg: 0, offset: 0.0002), to: name) }
            for hy in [sy + 0.25, sy + H / 2, sy + H - 0.22] {
                let k = FK.hingeKnuckles(at: V3(px, hy, pz), length: 0.1, r: 0.007, mat: hardware)
                rig.addBase(k.frame); rig.add(k.leaf, to: name, lods: 0...0)
            }
        }
        // Espagnolette on the right leaf: rod, guides, oval handle.
        let ex: Float = 0.035, ez = zb - 0.012
        rig.add(HK.cyl(r: 0.007, len: H - 0.1, at: V3(ex, sy + H / 2, ez), axis: .up, mat: hardware, seg: 10), .identity, to: "right")
        for gy in [sy + 0.3, sy + H - 0.3] { rig.add(HK.box(V3(0.03, 0.02, 0.016), V3(ex, gy, ez + 0.004), hardware, r: 0.004), .identity, to: "right", lods: 0...0) }
        rig.add(HK.box(V3(0.034, 0.1, 0.01), V3(ex, sy + 1.05, ez + 0.006), hardware, r: 0.004), .identity, to: "right")
        rig.add(HK.pipe(catmull([V3(ex, sy + 1.05, ez - 0.004), V3(ex, sy + 1.03, ez - 0.03), V3(ex, sy + 0.92, ez - 0.035)], per: 3), r: 0.007, sides: 10, mat: hardware), .identity, to: "right")
        // Meeting-stile astragal outside on the right leaf.
        rig.add(FK.vbox(V3(0.03, H - 0.01, 0.012), V3(0.002, sy + H / 2, zf + 0.006), leafMaterial, r: 0.005), .identity, to: "right")

        // MARK: Juliet railing (static, outside the opening)
        var rail: [Surface] = []
        let rz = D / 2 + 0.06, rw = 2 * (xo + fj) + 0.06
        let ry0 = sy + 0.09, ry1 = railHeight
        rail.append(HK.box(V3(rw, 0.04, 0.05), V3(0, ry1, rz), ironMaterial, r: 0.012))
        rail.append(HK.box(V3(rw - 0.02, 0.016, 0.03), V3(0, ry0, rz), ironMaterial, r: 0.004))
        rail.append(HK.box(V3(rw - 0.02, 0.012, 0.024), V3(0, ry0 + 0.12, rz), ironMaterial, r: 0.004))
        let nb = Int(((rw - 0.06) / balusterSpacing).rounded())
        for i in 0...nb {
            let x = -rw / 2 + 0.03 + (rw - 0.06) * Float(i) / Float(nb)
            rail.append(HK.cyl(r: 0.008, len: ry1 - ry0, at: V3(x, (ry0 + ry1) / 2, rz), axis: .up, mat: ironMaterial, seg: 8))
            // C-scroll pairs in the band between bottom rails.
            if i < nb {
                let mx = x + (rw - 0.06) / Float(nb) / 2
                for (cyy, flip) in [(ry0 + 0.06, Float(1))] {
                    let r: Float = 0.026
                    let arcA = (0...8).map { k -> V3 in let t = Float(k) / 8 * .pi; return V3(mx + flip * cos(t) * r, cyy + sin(t) * r - 0.005, rz) }
                    let arcB = (0...8).map { k -> V3 in let t = Float(k) / 8 * .pi; return V3(mx - cos(t) * r, cyy - sin(t) * r + 0.005, rz) }
                    rail.append(HK.pipe(arcA, r: 0.005, sides: 6, mat: ironMaterial))
                    rail.append(HK.pipe(arcB, r: 0.005, sides: 6, mat: ironMaterial))
                }
            }
        }
        // Wall anchors at both ends: square posts into the reveal with rosette plates.
        for sx: Float in [-1, 1] {
            let x = sx * (rw / 2 - 0.012)
            rail.append(HK.box(V3(0.025, ry1 - sy, 0.025), V3(x, sy + (ry1 - sy) / 2, rz), ironMaterial, r: 0.004))
            rail.append(HK.box(V3(0.025, 0.025, 0.07), V3(x, ry1 - 0.06, rz - 0.04), ironMaterial, r: 0.004))
            rail.append(Prim.lathe([V2(0, 0), V2(0.02, 0), V2(0.02, 0.006), V2(0.012, 0.016), V2(0, 0.02)], segments: 12, seamTile: 0.05, material: ironMaterial)
                .transformed(Xform(translation: V3(x, ry1 + 0.02, rz))))
        }
        rig.addBase(rail)

        groundAO(&rig, height: 0.12, floor: 0.6)
        rig.states = [RigState("closed"), RigState("ajar", ["right": -25]), RigState("open", ["left": 85, "right": -85])]
        return rig
    }
}
