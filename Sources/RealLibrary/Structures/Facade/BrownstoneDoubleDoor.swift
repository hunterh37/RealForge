import simd
import Foundation

/// Brownstone double entry, 1.22 x 2.6 m pair: two 57 mm walnut leaves with glazed upper panels
/// (beveled lites behind a bolection bead) over raised lower panels, transom bar and transom light,
/// carved brownstone surround (eared jambs, lintel, frieze, cornice on two scrolled consoles), brass
/// knobs, push plates and hinges, stone threshold. Exterior faces +Z, base y = 0 is the threshold
/// bottom; the leaves swing inward from their outer hinges.
public struct BrownstoneDoubleDoor: RealArticulated {
    public static let id = "brownstone-double-door"
    public static let summary = "Brownstone double entry: pair of tall walnut doors with glazed upper panels, transom light, carved brownstone surround and brass hardware."
    public static let tags = ["structure", "architecture", "facade", "door", "wood", "stone", "glass", "articulated"]
    public static let budget = 26_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 22, elevation: 6, distance: 1.0, studio: true)

    /// Clear width of the pair (m).
    public var pairWidth: Float = 1.22
    /// Leaf height (m).
    public var leafHeight: Float = 2.6
    /// Transom light height (m); 0 removes it.
    public var transomHeight: Float = 0.42
    /// Panel rows bottom up (relative heights); the last row is glazed.
    public var panelRows: [Float] = [0.55, 1.0]
    public var leafMaterial: MaterialKey = "wood.walnut"
    public var stoneMaterial: MaterialKey = "stone.brownstone"
    public var glass: MaterialKey = "glass.pane"
    public var hardware: MaterialKey = "metal.brass-aged"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [10])
        let W = pairWidth / 2 - 0.003, H = leafHeight, T: Float = 0.057
        let sy: Float = 0.03, D: Float = 0.3
        let xo = pairWidth / 2 + 0.003
        let zf = D / 2 - 0.06, zb = zf - T
        let topLeaf = sy + H + 0.004
        let barH: Float = 0.1, trH = transomHeight
        let openTop = topLeaf + (trH > 0 ? barH + trH : 0)
        let wood = leafMaterial, stone = stoneMaterial

        var st: [Surface] = []
        // Wood frame: jambs, head, transom bar, transom sash.
        let fj: Float = 0.06
        for sx: Float in [-1, 1] {
            st.append(FK.vbox(V3(fj, openTop - sy + fj, 0.14), V3(sx * (xo + fj / 2), sy + (openTop - sy + fj) / 2, zf - 0.07 + 0.02), wood, r: 0.003))
            st.append(FK.vbox(V3(0.016, H, 0.03), V3(sx * (xo - 0.008), sy + H / 2, zb - 0.016), wood, r: 0.002))
        }
        st.append(HK.box(V3(2 * xo + 2 * fj, fj, 0.14), V3(0, openTop + fj / 2, zf - 0.05), wood, r: 0.003))
        if trH > 0 {
            st.append(HK.box(V3(2 * xo, barH, 0.14), V3(0, topLeaf + barH / 2, zf - 0.05), wood, r: 0.004))
            st.append(HK.box(V3(2 * xo + 0.02, 0.03, 0.17), V3(0, topLeaf + barH - 0.015, zf - 0.035), wood, r: 0.01))
            st += FK.lite(w: 2 * xo - 0.01, h: trH - 0.01, t: 0.04, at: V3(0, topLeaf + barH + trH / 2, zf - 0.03), mat: wood, glass: glass, muntins: (1, 1), bead: 0.02)
            // House number in gilt on the transom glass.
            for (i, dx) in [Float(-0.06), 0, 0.06].enumerated() {
                st.append(HK.box(V3(0.035, 0.09, 0.0015), V3(dx, topLeaf + barH + trH / 2, zf - 0.03 + 0.0045 + Float(i) * 0.00001), "metal.brass", r: 0.0006, seg: 1))
            }
        }
        // Brownstone surround: eared jambs, lintel, frieze, cornice on consoles.
        let sjw: Float = 0.26, sz0 = zf - 0.04, sd = D / 2 - sz0
        let sxo = xo + fj
        for sx: Float in [-1, 1] {
            st.append(HK.box(V3(sjw, openTop + fj - sy, sd + 0.04), V3(sx * (sxo + sjw / 2), sy + (openTop + fj - sy) / 2, sz0 + (sd + 0.04) / 2), stone, r: 0.012))
            // Projecting architrave band on the jamb face.
            st.append(HK.box(V3(0.09, openTop + fj - sy - 0.25, 0.03), V3(sx * (sxo + 0.045), sy + 0.25 + (openTop + fj - sy - 0.25) / 2, sz0 + sd + 0.04 + 0.015), stone, r: 0.01))
            st.append(HK.box(V3(sjw + 0.04, 0.25, sd + 0.08), V3(sx * (sxo + sjw / 2), sy + 0.125, sz0 + (sd + 0.08) / 2), stone, r: 0.012))
            // Console under the cornice: scrolled block.
            let cx = sx * (sxo + sjw - 0.07)
            let cy = openTop + fj + 0.02
            st.append(HK.box(V3(0.11, 0.42, 0.13), V3(cx, cy - 0.21 + 0.42, sz0 + sd + 0.04 + 0.065), stone, r: 0.03))
            st.append(HK.cyl(r: 0.055, len: 0.11, at: V3(cx, cy + 0.15, sz0 + sd + 0.04 + 0.13), axis: V3(1, 0, 0), mat: stone, seg: 18, bevel: 0.01))
        }
        let ow = 2 * (sxo + sjw)
        st.append(HK.box(V3(ow, 0.34, sd + 0.07), V3(0, openTop + fj + 0.17, sz0 + (sd + 0.07) / 2), stone, r: 0.012))
        var cy = openTop + fj + 0.34
        for (h, out, grow) in [(Float(0.06), Float(0.2), Float(0.1)), (0.08, 0.26, 0.16), (0.07, 0.3, 0.22)] {
            st.append(HK.box(V3(ow + 2 * grow, h, sd + out), V3(0, cy + h / 2, sz0 + (sd + out) / 2), stone, r: 0.015))
            cy += h
        }
        // Stone threshold.
        st.append(HK.box(V3(2 * sxo + 0.02, sy, D + 0.08), V3(0, sy / 2, 0.04), stone, r: 0.006))
        rig.addBase(st)

        // MARK: leaves
        for (name, sx, range) in [("left", Float(-1), Float(0)...100), ("right", Float(1), Float(-100)...0)] {
            let px = sx * (xo - 0.001), pz = zb - 0.002
            rig.part(name, pivot: V3(px, 0, pz), joint: .hinge(axis: .up, range, duration: 1.7))
            let cx = sx * (xo - W / 2 - 0.0015)
            let leaf = FK.panelLeaf(w: W, h: H, t: T, rows: panelRows, cols: 1, stile: 0.13, bottomRail: 0.28, topRail: 0.14, midRail: 0.16,
                                    mat: wood, glazed: [panelRows.count - 1], glass: glass, muntins: (1, 1))
            for s in leaf { rig.add(s, Xform(translation: V3(cx, sy + 0.002, zb + T / 2)).jittered(&rng, deg: 0, offset: 0.0002), to: name) }
            // Bolection bead around the glazed panel (exterior).
            let free = H - 0.28 - 0.14 - 0.16
            let gy0 = sy + 0.002 + 0.28 + free * panelRows[0] / panelRows.reduce(0, +) + 0.16
            let gh = H - 0.14 - (gy0 - sy - 0.002), gw = W - 0.26
            for s in [HK.box(V3(gw + 0.05, 0.025, 0.018), V3(cx, gy0 + 0.0125 - 0.012, zf + 0.009), wood, r: 0.008),
                      HK.box(V3(gw + 0.05, 0.025, 0.018), V3(cx, gy0 + gh - 0.0125 + 0.012, zf + 0.009), wood, r: 0.008),
                      FK.vbox(V3(0.025, gh + 0.024, 0.018), V3(cx - gw / 2 - 0.0125 + 0.012, gy0 + gh / 2, zf + 0.009), wood, r: 0.008),
                      FK.vbox(V3(0.025, gh + 0.024, 0.018), V3(cx + gw / 2 + 0.0125 - 0.012, gy0 + gh / 2, zf + 0.009), wood, r: 0.008)] {
                rig.add(s, .identity, to: name)
            }
            for hy in [sy + 0.3, sy + H / 2, sy + H - 0.25] {
                let k = FK.hingeKnuckles(at: V3(px, hy, pz), length: 0.12, r: 0.008, mat: hardware)
                rig.addBase(k.frame); rig.add(k.leaf, to: name, lods: 0...0)
            }
            // Knob and push plate at the meeting stiles.
            let kx = sx * 0.07
            rig.add(FK.knob(at: V3(kx, sy + 1.0, zf), n: V3(0, 0, 1), mat: hardware, r: 0.031), .identity, to: name)
            rig.add(FK.knob(at: V3(kx, sy + 1.0, zb), n: V3(0, 0, -1), mat: hardware, r: 0.031), .identity, to: name)
            rig.add(Prim.extrude(Shape2D.roundedRect(0.08, 0.3, radius: 0.01), depth: 0.003, bevel: 0.001, bevelSegments: 1, material: hardware)
                .transformed(Xform(translation: V3(kx, sy + 1.3, zf + 0.0015))), .identity, to: name)
        }
        // Astragal on the right leaf's meeting edge.
        rig.add(FK.vbox(V3(0.03, H - 0.01, 0.012), V3(0.002, sy + H / 2, zf + 0.006), wood, r: 0.005), .identity, to: "right")

        FK.shift(&rig, by: V3(0, 0, -0.15))
        groundAO(&rig, height: 0.12, floor: 0.6)
        rig.states = [RigState("closed"), RigState("one-open", ["right": -85]), RigState("open", ["left": 88, "right": -88])]
        return rig
    }
}
