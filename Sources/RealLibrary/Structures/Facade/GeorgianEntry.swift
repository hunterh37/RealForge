import simd
import Foundation

/// Georgian entrance: 0.91 x 2.13 m six-panel door between two sidelights (three lites over a
/// raised panel), transom bar, half-elliptical fanlight with radiating muntins over the full width,
/// fluted pilasters with plinths and capitals, frieze and stepped cornice, stone step, brass knob and
/// knocker. Exterior faces +Z; base y = 0 is the bottom of the step. The door swings inward on its
/// left hinges.
public struct GeorgianEntry: RealArticulated {
    public static let id = "georgian-entry"
    public static let summary = "Georgian entrance: six-panel door between leaded sidelights under a semicircular fanlight, fluted pilasters, entablature and stone step."
    public static let tags = ["structure", "architecture", "facade", "door", "wood", "glass", "articulated"]
    public static let budget = 26_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 22, elevation: 6, distance: 1.0, studio: true)

    public var doorWidth: Float = 0.91
    public var doorHeight: Float = 2.13
    /// Sidelight glass width (m); 0 removes the sidelights.
    public var sidelightWidth: Float = 0.34
    /// Rise of the half-elliptical fanlight (m).
    public var fanlightRise: Float = 0.46
    /// Radiating fanlight muntins.
    public var fanSpokes: Int = 9
    /// Step height (m).
    public var stepHeight: Float = 0.16
    public var doorMaterial: MaterialKey = "wood.painted-exterior:16243A"
    public var trimMaterial: MaterialKey = "wood.painted-exterior:F1EEE4"
    public var stoneMaterial: MaterialKey = "stone.cast-grey"
    public var glass: MaterialKey = "glass.pane"
    public var hardware: MaterialKey = "metal.brass-aged"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [10])
        let W = doorWidth, H = doorHeight, T: Float = 0.045
        let sy = stepHeight, sw = sidelightWidth
        let jamb: Float = 0.05, mul: Float = 0.07, D: Float = 0.16
        let xo = W / 2 + 0.003
        let sideOuter = sw > 0 ? xo + mul + sw : xo     // outer glass edge
        let frameOuter = sideOuter + jamb
        let transomY = sy + H + 0.006, barH: Float = 0.08
        let fanY = transomY + barH                       // springing line
        let a = frameOuter - jamb, b = fanlightRise      // fanlight semi axes (glass)
        let zf: Float = D / 2 - 0.03, zb = zf - T
        let tm = trimMaterial

        var st: [Surface] = []
        // Outer jambs to the springing line, mullions, transom bar.
        for sx: Float in [-1, 1] {
            st.append(FK.vbox(V3(jamb, fanY - sy, D), V3(sx * (frameOuter - jamb / 2), sy + (fanY - sy) / 2, 0), tm))
            if sw > 0 {
                st.append(FK.vbox(V3(mul, H + 0.006, D), V3(sx * (xo + mul / 2), sy + (H + 0.006) / 2, 0), tm))
                // Sidelight: raised panel below, three lites above.
                let cx = sx * (xo + mul + sw / 2)
                let panelH: Float = 0.62
                st.append(HK.box(V3(sw + 0.004, 0.08, T), V3(cx, sy + 0.04, zf - T / 2), tm, r: 0.003))
                st += FK.raisedPanel(w: sw + 0.004, h: panelH - 0.08, t: T, at: V3(cx, sy + 0.08 + (panelH - 0.08) / 2, zf - T / 2), mat: tm, raise: 0.03)
                st.append(HK.box(V3(sw + 0.004, 0.05, T), V3(cx, sy + panelH + 0.025, zf - T / 2), tm, r: 0.003))
                let gh = H - panelH - 0.05
                st += FK.lite(w: sw, h: gh, t: T, at: V3(cx, sy + panelH + 0.05 + gh / 2, zf - T / 2), mat: tm, glass: glass, muntins: (1, 3), bead: 0.01, muntinW: 0.016)
            }
            // Door stop.
            st.append(FK.vbox(V3(0.014, H, 0.03), V3(sx * (xo - 0.007), sy + H / 2, zb - 0.017), tm, r: 0.002))
        }
        st.append(HK.box(V3(2 * a, barH, D), V3(0, transomY + barH / 2, 0), tm, r: 0.004))
        st.append(HK.box(V3(2 * a + 0.03, 0.03, D + 0.03), V3(0, transomY + barH - 0.012, 0.01), tm, r: 0.008))

        // Fanlight: elliptical frame swept along the arc, glass fan, radiating muntins, hub.
        let arcN = 32
        let arc = (0...arcN).map { i -> V3 in
            let t = Float(i) / Float(arcN) * .pi
            return V3(cos(t) * (a + jamb / 2), fanY + sin(t) * (b + jamb / 2), 0)
        }
        st.append(Prim.sweep(Shape2D.roundedRect(jamb, D, radius: 0.004), along: arc, up: V3(0, 0, 1), material: tm))
        var fan: [V2] = []
        for i in 0...arcN { let t = Float(i) / Float(arcN) * .pi; fan.append(V2(cos(t) * a, sin(t) * b)) }
        st.append(Prim.extrude(fan, depth: 0.006, bevel: 0.001, bevelSegments: 1, material: glass).transformed(Xform(translation: V3(0, fanY, zf - T / 2))))
        let hubR: Float = 0.12
        for k in 1..<fanSpokes {
            let t = Float(k) / Float(fanSpokes) * .pi
            let p0 = V3(cos(t) * hubR, fanY + sin(t) * hubR * (b / a) * 1.6, zf - T / 2)
            let p1 = V3(cos(t) * a, fanY + sin(t) * b, zf - T / 2)
            st.append(HK.pipe([p0, p1], r: 0.009, sides: 6, mat: tm))
        }
        // Inner arc ring and hub (half disc) at the springing line.
        let ring = (0...20).map { i -> V3 in let t = Float(i) / 20 * .pi; return V3(cos(t) * a * 0.62, fanY + sin(t) * b * 0.62, zf - T / 2) }
        st.append(HK.pipe(ring, r: 0.008, sides: 6, mat: tm))
        var hub: [V2] = []
        for i in 0...16 { let t = Float(i) / 16 * .pi; hub.append(V2(cos(t) * hubR, sin(t) * hubR * 0.9)) }
        st.append(Prim.extrude(hub, depth: 0.05, bevel: 0.008, bevelSegments: 2, material: tm).transformed(Xform(translation: V3(0, fanY, zf - T / 2 + 0.005))))

        // Fluted pilasters, plinths, capitals.
        let pw: Float = 0.2, pd: Float = 0.06
        let px = frameOuter + pw / 2 + 0.01
        let topY = fanY + b + jamb + 0.06
        for sx: Float in [-1, 1] {
            let x = sx * px, z = D / 2 + pd / 2
            st.append(FK.vbox(V3(pw, topY - sy, pd), V3(x, sy + (topY - sy) / 2, z), tm, r: 0.004))
            for f in 0..<4 {
                let fx = x - pw / 2 + 0.045 + Float(f) * (pw - 0.09) / 3
                st.append(HK.box(V3(0.018, topY - sy - 0.5, 0.012), V3(fx, sy + 0.3 + (topY - sy - 0.5) / 2, D / 2 + pd + 0.002), tm, r: 0.0085, seg: 2))
            }
            st.append(HK.box(V3(pw + 0.05, 0.24, pd + 0.03), V3(x, sy + 0.12, D / 2 + (pd + 0.03) / 2), tm, r: 0.006))
            st.append(HK.box(V3(pw + 0.035, 0.03, pd + 0.02), V3(x, sy + 0.255, D / 2 + (pd + 0.02) / 2), tm, r: 0.01))
            st.append(HK.box(V3(pw + 0.04, 0.05, pd + 0.025), V3(x, topY - 0.06, D / 2 + (pd + 0.025) / 2), tm, r: 0.012))
            st.append(HK.box(V3(pw + 0.06, 0.035, pd + 0.035), V3(x, topY - 0.018, D / 2 + (pd + 0.035) / 2), tm, r: 0.006))
        }
        // Spandrel board filling between the fanlight arc and the frieze.
        var sp: [V2] = []
        for i in 0...arcN { let t = Float(i) / Float(arcN) * .pi; sp.append(V2(cos(t) * (a + jamb), sin(t) * (b + jamb))) }
        sp += [V2(-px, 0), V2(-px, topY - fanY), V2(px, topY - fanY), V2(px, 0)]
        st.append(Prim.extrude(sp.reversed(), depth: 0.03, bevel: 0.003, bevelSegments: 1, material: tm).transformed(Xform(translation: V3(0, fanY, D / 2 - 0.012))))
        // Frieze and stepped cornice.
        let ew = 2 * (px + pw / 2) + 0.08
        st.append(HK.box(V3(ew, 0.2, pd + 0.02), V3(0, topY + 0.1, D / 2 + (pd + 0.02) / 2), tm, r: 0.005))
        var cy = topY + 0.2, cz = D / 2 + pd + 0.02, cw = ew
        for (h, out) in [(Float(0.03), Float(0.025)), (0.05, 0.05), (0.035, 0.08), (0.03, 0.095)] {
            cw += 2 * (out - 0.0) * 0.6
            st.append(HK.box(V3(cw, h, cz + out - D / 2 + 0.06), V3(0, cy + h / 2, D / 2 - 0.06 + (cz + out - D / 2 + 0.06) / 2), tm, r: min(0.012, h * 0.4)))
            cy += h
        }
        _ = cz
        // Stone step with a rounded nosing.
        let stepW = ew + 0.2
        st.append(HK.box(V3(stepW, sy, 0.5), V3(0, sy / 2, D / 2 + 0.25 - 0.1), stoneMaterial, r: 0.012))
        rig.addBase(st)

        // MARK: door leaf
        let hx = -xo + 0.001, hz = zb - 0.002
        rig.part("leaf", pivot: V3(hx, 0, hz), joint: .hinge(axis: .up, 0...100, duration: 1.6))
        for s in FK.panelLeaf(w: W, h: H, t: T, rows: [1.0, 1.0, 0.42], cols: 2, stile: 0.115, bottomRail: 0.24, topRail: 0.115, midRail: 0.105, mat: doorMaterial) {
            rig.add(s, Xform(translation: V3(0, sy + 0.002, zb + T / 2)).jittered(&rng, deg: 0, offset: 0.00015), to: "leaf")
        }
        for hy in [sy + 0.25, sy + H / 2 + 0.1, sy + H - 0.2] {
            let k = FK.hingeKnuckles(at: V3(hx, hy, hz), length: 0.1, r: 0.0065, mat: hardware)
            rig.addBase(k.frame); rig.add(k.leaf, to: "leaf", lods: 0...0)
        }
        let kx = W / 2 - 0.07
        rig.add(FK.knob(at: V3(kx, sy + 0.97, zf), n: V3(0, 0, 1), mat: hardware), .identity, to: "leaf")
        rig.add(FK.knob(at: V3(kx, sy + 0.97, zb), n: V3(0, 0, -1), mat: hardware), .identity, to: "leaf")
        rig.add(FK.escutcheon(at: V3(kx, sy + 0.9, zf), n: V3(0, 0, 1), mat: hardware), to: "leaf", lods: 0...0)
        // Knocker: ring on a backplate at eye level, centered on the lock stile line.
        rig.add(HK.box(V3(0.06, 0.1, 0.008), V3(0, sy + 1.5, zf + 0.004), hardware, r: 0.004), .identity, to: "leaf")
        rig.add(Prim.torus(major: 0.045, minor: 0.008, segments: 24, sides: 8, material: hardware)
            .transformed(Xform(translation: V3(0, sy + 1.47, zf + 0.018), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)))), .identity, to: "leaf")

        FK.shift(&rig, by: V3(0, 0, -0.197))
        groundAO(&rig, height: 0.12, floor: 0.6)
        rig.states = [RigState("closed"), RigState("ajar", ["leaf": 20]), RigState("open", ["leaf": 90])]
        return rig
    }
}
