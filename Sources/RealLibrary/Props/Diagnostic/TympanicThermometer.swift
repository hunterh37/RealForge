import simd
import Foundation

/// Infrared ear thermometer (Braun ThermoScan 7 class), about 150 x 42 x 36 mm, lying on its back:
/// gloss white body lofted from rounded sections with the head curving up 25 degrees into the probe,
/// grey soft-grip side insets, an LCD window with bezel, a large measure button, a small power button,
/// the cover eject button by the probe, and the probe with a lens tip. Options: probe bare or under a
/// disposable lens filter; LCD off, lit, or showing a reading (37.2). Buttons slide in.
public struct TympanicThermometer: RealArticulated {
    public static let id = "tympanic-thermometer"
    public static let summary = "Braun ThermoScan class ear thermometer lying on its back: curved white body, probe with cover, LCD, power, measure and eject buttons."
    public static let tags = ["prop", "medical", "handheld", "articulated", "electronics", "plastic"]
    public static let budget = 4_500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 34, distance: 0.42, studio: true)

    /// Body colour (sRGB hex).
    public var bodyColor: UInt32 = 0xF1F0EC
    /// Grip inset colour (sRGB hex).
    public var gripColor: UInt32 = 0xBFC5CB
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [2.5])
        let body: MaterialKey = "plastic.gloss:" + String(format: "%06X", bodyColor)
        let grip: MaterialKey = "rubber.silicone:" + String(format: "%06X", gripColor)
        let dark: MaterialKey = "plastic.matte:1E2124"
        // Centre line: straight from the tail (+Z) to z = -0.03, then an arc rising 25 degrees to the head.
        let zTail: Float = 0.072, zBend: Float = -0.03, Rarc: Float = 0.085, arc: Float = 25 * .pi / 180
        let straightLen = zTail - zBend, arcLen = Rarc * arc, total = straightLen + arcLen
        func sec(_ s: Float) -> (w: Float, h: Float) {   // s: 0 head ... 1 tail
            let w = s < 0.2 ? 0.029 + 0.06 * s : (s < 0.7 ? 0.041 + 0.002 * sin((s - 0.2) / 0.5 * .pi) : 0.041 - (s - 0.7) * 0.03)
            let h = s < 0.2 ? 0.027 + 0.04 * s : (s < 0.75 ? 0.035 : 0.035 - (s - 0.75) * 0.03)
            // Domed tail: the last 7 % rounds over.
            let e = max(0, (s - 0.9) / 0.1), k = sqrt(max(0, 1 - e * e))
            return (w * (0.12 + 0.88 * k), h * (0.1 + 0.9 * k))
        }
        // Frame at distance d from the head end along the centre line (head end = d 0).
        func frame(_ d: Float) -> (c: V3, t: V3, up: V3) {
            let fromBend = arcLen - d
            if fromBend <= 0 {
                let z = zBend - fromBend
                return (V3(0, 0, z), V3(0, 0, 1), V3(0, 1, 0))
            }
            let a = fromBend / Rarc   // angle along the arc from the bend
            let c = V3(0, Rarc * (1 - cos(a)), zBend - Rarc * sin(a))
            return (c, V3(0, -sin(a), cos(a)), V3(0, cos(a), sin(a)))
        }
        func center(_ d: Float) -> (c: V3, t: V3, up: V3, w: Float, h: Float) {
            let f = frame(d), s = d / total, wh = sec(s)
            let base = sec(0.5).h / 2
            return (f.c + V3(0, base, 0) + f.up * (wh.h / 2 - base) * (d > arcLen ? 1 : 0.6), f.t, f.up, wh.w, wh.h)
        }
        let stations = [26, 11]
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let n = l == 0 ? 28 : 14
            var rings: [[V3]] = []
            for k in 0...stations[l] {
                let u = Float(k) / Float(stations[l]); let d = total * (u < 0.85 ? u : 0.85 + 0.15 * sin((u - 0.85) / 0.15 * .pi / 2))
                let f = center(d)
                let side = V3(1, 0, 0)
                rings.append(Shape2D.superellipse(f.w, f.h, exponent: 3.4, segments: n).map { f.c + side * $0.x + f.up * $0.y })
            }
            m.add(Prim.loft(rings, capStart: true, capEnd: true, material: body))
            // Grey soft-grip insets on both flanks of the handle.
            for sx: Float in [-1, 1] {
                let f = center(arcLen + 0.05)
                var g = Prim.superellipsoid(V3(0.004, 0.015, 0.07), exponent: 2.6, subdivisions: l == 0 ? 6 : 3, material: grip)
                g.deform { q in V3(q.x, q.y, q.z) }
                m.add(g, Xform(translation: f.c + V3(sx * (f.w / 2 - 0.0012), -0.0012, 0)))
            }
            // Probe: cone along the head tangent, with a seam ring at its base.
            let hf = center(0)
            let toT = simd_quatf(from: V3(0, 1, 0), to: -hf.t)
            let pb = hf.c + hf.up * 0.001
            m.add(Prim.lathe([V2(0.0128, -0.002), V2(0.0122, 0.002), V2(0.0108, 0.004), V2(0.0098, 0.009), V2(0.0072, 0.019), V2(0.0058, 0.0235),
                              V2(0.0052, 0.024)], segments: l == 0 ? 28 : 10, seamTile: 0.03, material: body),
                  Xform(translation: pb, rotation: toT))
            m.add(Prim.lathe([V2(0.0131, -0.0004), V2(0.0133, 0.0004), V2(0.0124, 0.0012)], segments: l == 0 ? 28 : 10, seamTile: 0.03, material: "plastic.matte:B9BCBF"),
                  Xform(translation: pb, rotation: toT))
            rig.base[l] = m
        }
        // Battery door seam on the underside tail and a serial sticker (detail, hidden side).
        let tailF = center(total * 0.82)
        rig.base[0].add(Prim.roundedBox(V3(0.026, 0.0003, 0.03), radius: 0.0001, bevelSegments: 1, material: "plastic.matte:C8C8C4"),
                        Xform(translation: V3(0, 0.0002, tailF.c.z)))

        // MARK: display bezel and screen (top face, middle).
        let dz: Float = 0.012, dW: Float = 0.024, dH: Float = 0.017
        let yTop = center(arcLen + (dz - zBend)).h
        rig.base.indices.forEach { l in
            rig.base[l].add(Prim.extrude(Shape2D.roundedRect(dW + 0.005, dH + 0.005, radius: 0.003, segments: 3), depth: 0.0016, bevel: 0.0005, bevelSegments: 1,
                                         material: "plastic.gloss:2A2D31"),
                            Xform(translation: V3(0, yTop - 0.0004, dz), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
        }
        let sy = yTop + 0.00045
        rig.part("screen", pivot: V3(0, sy, dz), joint: .fixed, options: 3)
        func lcd(_ mat: MaterialKey) -> Surface {
            var s = Surface(material: mat)
            let n = V3(0, 1, 0)
            // Reads from the tail end: text up = -Z, right = +X.
            let tl = s.add(V3(dW / 2, sy, dz - dH / 2), n, V2(0, 0)), tr = s.add(V3(-dW / 2, sy, dz - dH / 2), n, V2(dW, 0))
            let br = s.add(V3(-dW / 2, sy, dz + dH / 2), n, V2(dW, dH)), bl = s.add(V3(dW / 2, sy, dz + dH / 2), n, V2(0, dH))
            s.quad(tl, tr, br, bl)
            s.computeTangents()
            return s
        }
        rig.add(lcd("screen.off"), to: "screen")
        rig.add(lcd("screen.lcd"), to: "screen", option: 1)
        rig.add(lcd("screen.lcd"), to: "screen", option: 2)
        // Seven-segment "37.2" and a degree mark in dark LCD ink (option 2).
        var ink = Surface(material: "plastic.matte:1B2420")
        let segs: [Int: [Int]] = [3: [0, 1, 2, 3, 6], 7: [0, 1, 2], 2: [0, 1, 6, 4, 3]]
        let dh: Float = 0.0085, dw: Float = 0.0046, tk: Float = 0.0009
        func digit(_ v: Int, _ cxp: Float) {
            // cxp: digit centre along +X (reading right); segments a b c d e f g.
            for sgi in segs[v] ?? [] {
                let horiz = sgi == 0 || sgi == 3 || sgi == 6
                let ry: Float = sgi == 0 ? dh / 2 : (sgi == 3 ? -dh / 2 : (sgi == 6 ? 0 : (sgi == 1 || sgi == 5 ? dh / 4 : -dh / 4)))
                let rx: Float = horiz ? 0 : ((sgi == 1 || sgi == 2) ? dw / 2 : -dw / 2)
                let size = horiz ? V3(dw - tk, 0.00012, tk) : V3(tk, 0.00012, dh / 2 - tk)
                // Read from the tail end: screen-right is +X, screen-up is -Z.
                ink.append(cuboid(V3(size.x, size.y, size.z), material: ink.material), Xform(translation: V3(cxp + rx, sy + 0.0001, dz - ry - 0.001)))
            }
        }
        digit(3, -0.0072); digit(7, -0.0012); digit(2, 0.0062)
        ink.append(cuboid(V3(tk, 0.00012, tk), material: ink.material), Xform(translation: V3(0.0025, sy + 0.0001, dz + dh / 2 - 0.001)))
        ink.append(cuboid(V3(0.0012, 0.00012, 0.0012), material: ink.material), Xform(translation: V3(0.0098, sy + 0.0001, dz - dh / 2 - 0.0002)))
        rig.add(ink, to: "screen", option: 2)

        // MARK: buttons (slide into the body).
        func button(_ name: String, z: Float, size: V3, mat: MaterialKey) {
            let f = center(arcLen + (z - zBend))
            let y = f.h - 0.0003
            rig.part(name, pivot: V3(0, y, z), joint: .slide(axis: V3(0, -1, 0), 0...0.0009, duration: 0.12))
            for l in 0..<2 {
                rig.add(Prim.superellipsoid(size, exponent: 3, subdivisions: l == 0 ? 4 : 2, material: mat), Xform(translation: V3(0, y + size.y * 0.3, z)), to: name, lods: l...l)
            }
        }
        button("power", z: 0.04, size: V3(0.009, 0.0026, 0.0062), mat: "plastic.gloss:5C6670")
        button("measure", z: -0.014, size: V3(0.016, 0.0034, 0.012), mat: "plastic.gloss:3E73B8")
        // Eject button: on the head just behind the probe.
        let ef = center(arcLen * 0.35)
        let ep = ef.c + ef.up * (ef.h / 2 - 0.0004)
        rig.part("eject", pivot: ep, joint: .slide(axis: -ef.up, 0...0.0008, duration: 0.12))
        for l in 0..<2 {
            rig.add(Prim.superellipsoid(V3(0.008, 0.0024, 0.0055), exponent: 3, subdivisions: l == 0 ? 4 : 2, material: "plastic.gloss:5C6670"),
                    Xform(translation: ep + ef.up * 0.0007, rotation: simd_quatf(from: V3(0, 1, 0), to: ef.up)), to: "eject", lods: l...l)
        }

        // MARK: probe tip: bare lens (0) or disposable lens filter (1).
        let hf = center(0)
        let toT = simd_quatf(from: V3(0, 1, 0), to: -hf.t)
        let pb = hf.c + hf.up * 0.001
        rig.part("cover", pivot: pb, joint: .fixed, options: 2)
        rig.add(Prim.lathe([V2(0.0053, 0.0232), V2(0.0048, 0.0237), V2(0.0028, 0.0243), V2(0, 0.0246)], segments: 20, seamTile: 0.02, material: dark),
                Xform(translation: pb, rotation: toT), to: "cover")
        var filt = Prim.lathe([V2(0.0136, 0.0015), V2(0.0138, 0.003), V2(0.0112, 0.0042), V2(0.0102, 0.009), V2(0.0076, 0.019), V2(0.0062, 0.0238),
                               V2(0.0046, 0.0252), V2(0, 0.0255)], segments: 24, seamTile: 0.03, material: "plastic.frosted")
        filt = filt.transformed(Xform(translation: pb, rotation: toT))
        rig.add(filt, to: "cover", option: 1)
        rig.add(Prim.lathe([V2(0.0053, 0.0232), V2(0.0048, 0.0237), V2(0.0028, 0.0243), V2(0, 0.0246)], segments: 20, seamTile: 0.02, material: dark),
                Xform(translation: pb, rotation: toT), to: "cover", option: 1)

        groundAO(&rig, height: 0.008, floor: 0.6)
        // Ward asset sticker on the top behind the power button (story detail): one label tile.
        let stz: Float = 0.054 + rng.float(-0.002...0.002)
        let stY = center(arcLen + (stz - zBend)).h + 0.0001
        var st = Surface(material: "label.biomed")
        let up = V3(0, 1, 0)
        let a = st.add(V3(-0.0065, stY, stz - 0.0048), up, V2(0, 0)), b = st.add(V3(0.0065, stY, stz - 0.0048), up, V2(0.012, 0))
        let c = st.add(V3(0.0065, stY, stz + 0.0048), up, V2(0.012, 0.012)), d = st.add(V3(-0.0065, stY, stz + 0.0048), up, V2(0, 0.012))
        st.quad(a, d, c, b)
        st.computeTangents()
        rig.base[0].add(st)
        rig.states = [RigState("off"), RigState("on", options: ["screen": 1]), RigState("covered-on", options: ["screen": 1, "cover": 1]),
                      RigState("reading", ["measure": 0.0009], options: ["screen": 2, "cover": 1])]
        return rig
    }
}
