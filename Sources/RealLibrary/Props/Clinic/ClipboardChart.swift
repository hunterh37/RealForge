import simd
import Foundation

/// Aluminium patient chart holder (top-hinged metal chart binder class, letter size), 250 x 325 mm:
/// back tray with an upturned spine, piano hinge along the top, ribbed front cover with folded side
/// and bottom flanges, black corner guards, a name-card window, and a low-profile spring clip holding
/// a stack of chart pages (top sheet a printed form with a dog-eared corner). The cover swings over the
/// top (hinge about X) and the clip jaw lifts (hinge about X).
public struct ClipboardChart: RealArticulated {
    public static let id = "clipboard-chart"
    public static let summary = "Aluminium patient chart holder: hinged ribbed cover, spring clip on the inner board and a stack of chart pages."
    public static let tags = ["prop", "medical", "articulated", "handheld", "metal", "paper", "hospital"]
    public static let budget = 4_200
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 40, distance: 1.25, studio: true)

    public var width: Float = 0.25
    public var depth: Float = 0.325
    public var metal: MaterialKey = "metal.satin-aluminum"
    /// Cover angle in the open states (degrees over the top).
    public var openAngle: Float = 176
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [2.5])
        let W = width, D = depth, t: Float = 0.0012
        let black: MaterialKey = "plastic.matte:1C1D1F"
        let flat = simd_quatf(degrees: -90, axis: V3(1, 0, 0))       // extrude Z -> +Y, outline y -> -Z
        let hz = -D / 2 + 0.006, hy: Float = 0.0185, kr: Float = 0.0036  // hinge axis
        let backY: Float = 0.0022                                      // back tray underside (on its feet)

        /// Light strip: rounded cross-section (x, y) extruded along Z (or X when `alongX`), flat ends.
        func strip(_ size: V3, alongX: Bool = false, mat: MaterialKey? = nil) -> (Surface, simd_quatf) {
            let cs = alongX ? V2(size.z, size.y) : V2(size.x, size.y), len = alongX ? size.x : size.z
            let r = min(cs.x, cs.y) * 0.45
            let s = Prim.extrude(Shape2D.roundedRect(cs.x, cs.y, radius: r, segments: 1), depth: len, bevel: 0, material: mat ?? metal)
            return (s, alongX ? simd_quatf(degrees: 90, axis: .up) : simd_quatf(angle: 0, axis: .up))
        }
        func addStrip(_ m: inout Model, _ size: V3, at p: V3, alongX: Bool = false, mat: MaterialKey? = nil) {
            let (s, q) = strip(size, alongX: alongX, mat: mat); m.add(s, Xform(translation: p, rotation: q))
        }
        func addStrip(_ size: V3, at p: V3, alongX: Bool = false, to part: String, lods: ClosedRange<Int>? = nil) {
            let (s, q) = strip(size, alongX: alongX); rig.add(s, Xform(translation: p, rotation: q), to: part, lods: lods)
        }

        // MARK: back tray, spine, feet, pages
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let bev: Float = l == 0 ? 0.0005 : 0.0003
            m.add(Prim.extrude(Shape2D.roundedRect(W - 0.006, D - 0.012, radius: 0.008, segments: l == 0 ? 4 : 2), depth: t, bevel: bev, bevelSegments: 1, material: metal),
                  Xform(translation: V3(0, backY + t / 2, 0.003), rotation: flat))
            // Upturned spine from the tray to the hinge.
            addStrip(&m, V3(W - 0.006, hy - backY, t), at: V3(0, (hy + backY) / 2, hz + 0.0015), alongX: true)
            // Side rails folded up from the tray edges (keep pages in register).
            for sx: Float in [-1, 1] {
                addStrip(&m, V3(t, 0.006, D - 0.03), at: V3(sx * (W / 2 - 0.0035), backY + 0.003, 0.008))
            }
            // Rubber feet (LOD0 only; the tray hides them at distance).
            if l == 0 { for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                m.add(Prim.cylinder(radius: 0.0065, height: backY + 0.0002, bevel: 0.0006, segments: l == 0 ? 12 : 8, bevelSegments: 1, material: "rubber"),
                      Xform(translation: V3(sx * (W / 2 - 0.02), 0, sz * (D / 2 - 0.03) + 0.004)))
            }}}
            rig.base[l] = m
        }
        // Page stack: letter sheets, 5 mm, nudged out of square.
        let pw: Float = 0.216, pd: Float = 0.279, pt: Float = 0.005, py = backY + t
        let pz: Float = 0.012
        var sides = Surface(material: "paper.pages")
        let corners = [V3(-pw / 2, 0, pd / 2), V3(pw / 2, 0, pd / 2), V3(pw / 2, 0, -pd / 2), V3(-pw / 2, 0, -pd / 2)]
        for k in 0..<4 {
            let a = corners[k], b = corners[(k + 1) % 4]
            let n = simd_normalize(simd_cross(b - a, V3(0, 1, 0))), len = simd_distance(a, b)
            let i0 = sides.add(a, n, V2(0, 0)), i1 = sides.add(b, n, V2(len, 0))
            let i2 = sides.add(b + V3(0, pt, 0), n, V2(len, pt)), i3 = sides.add(a + V3(0, pt, 0), n, V2(0, pt))
            sides.quad(i0, i1, i2, i3)
        }
        sides.computeTangents()
        let stackX = Xform(translation: V3(0.002, py, pz), rotation: simd_quatf(degrees: rng.float(-0.8...0.8), axis: .up))
        // Top sheet with a dog-eared lower right corner.
        func topSheet(_ seg: Int) -> Surface {
            var s = Prim.terrain(size: V2(pw, pd), segments: seg, material: "paper.sheet") { p in
                let u = max(0, (p.x / pw + 0.5 - 0.8) / 0.2), v = max(0, (p.y / pd + 0.5 - 0.84) / 0.16)
                return 0.0002 + 0.012 * pow(u * v, 1.6)
            }
            s.computeTangents()
            return s
        }
        // Printed form on the top sheet (header band, ruled text, barcode), UVs 0...0.08 across it.
        var form = Surface(material: "label.rx-small")
        let fw: Float = 0.18, fd: Float = 0.2, fy = pt + 0.0004, fz: Float = -0.025
        let f0 = form.add(V3(-fw / 2, fy, fz - fd / 2), .up, V2(0, 0)), f1 = form.add(V3(fw / 2, fy, fz - fd / 2), .up, V2(0.08, 0))
        let f2 = form.add(V3(fw / 2, fy, fz + fd / 2), .up, V2(0.08, 0.08)), f3 = form.add(V3(-fw / 2, fy, fz + fd / 2), .up, V2(0, 0.08))
        form.quad(f0, f3, f2, f1)
        form.computeTangents()
        for l in 0..<2 {
            rig.base[l].add(sides, stackX)
            rig.base[l].add(topSheet(l == 0 ? 10 : 5), stackX.then(Xform(translation: V3(0, pt, 0))))
            rig.base[l].add(form, stackX)
        }

        // Hinge knuckles on the spine (fixed half): alternate segments, cover takes the others.
        let kn = 7, kl = (W - 0.012) / Float(kn)
        func knuckle(_ i: Int, _ segs: Int) -> (Surface, Xform) {
            (Prim.cylinder(radius: kr, height: kl - 0.0008, bevel: 0.0006, segments: segs, bevelSegments: 1, material: metal),
             Xform(translation: V3(-W / 2 + 0.006 + Float(i) * kl + 0.0004, hy, hz), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        }
        for i in stride(from: 0, to: kn, by: 2) {
            let (a, x) = knuckle(i, 12); rig.base[0].add(a, x)
        }
        // LOD1: one plain barrel for the whole hinge.
        rig.base[1].add(Prim.cylinder(radius: kr, height: W - 0.012, bevel: 0, segments: 6, bevelSegments: 1, material: metal),
                        Xform(translation: V3(-W / 2 + 0.006, hy, hz), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        // Hinge pin ends.
        for sx: Float in [-1, 1] {
            rig.base[0].add(Prim.cylinder(radius: 0.0016, height: 0.001, bevel: 0.0003, segments: 8, bevelSegments: 1, material: "metal.chrome"),
                            Xform(translation: V3(sx * (W / 2 - 0.006) + (sx > 0 ? 0 : 0), hy, hz), rotation: simd_quatf(degrees: sx > 0 ? -90 : 90, axis: V3(0, 0, 1))))
        }

        // MARK: spring clip (jaw lifts about X)
        let cz = -D / 2 + 0.032, cy = py + pt
        // Base plate riveted to the tray behind the pages.
        rig.base[0].add(Prim.roundedBox(V3(0.11, 0.0012, 0.016), radius: 0.0004, bevelSegments: 1, material: "metal.chrome"),
                        Xform(translation: V3(0, py + 0.0006, cz - 0.018)))
        addStrip(&rig.base[1], V3(0.11, 0.0012, 0.016), at: V3(0, py + 0.0006, cz - 0.018), alongX: true, mat: "metal.chrome")
        for sx: Float in [-0.04, 0.04] {
            rivet(&rig.base[0], at: V3(sx, py + 0.0012, cz - 0.018), normal: .up, radius: 0.0022, material: "metal.chrome")
        }
        let clipPivot = V3(0, cy + 0.0045, cz - 0.012)
        rig.part("clip", pivot: clipPivot, joint: .hinge(axis: V3(1, 0, 0), -65...0, duration: 0.3))
        // Spring roll, jaw plate with a rolled lip, two pads.
        rig.add(Prim.cylinder(radius: 0.0035, height: 0.1, bevel: 0.0008, segments: 14, bevelSegments: 1, material: "metal.chrome"),
                Xform(translation: clipPivot + V3(-0.05, 0, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "clip", lods: 0...0)
        let jawProf = [V2(0, 0), V2(0.0036, -0.0005), V2(0.016, -0.0035), V2(0.026, -0.0042), V2(0.029, -0.0036)]
        let jawPath = jawProf.map { V3(0, clipPivot.y + $0.y, clipPivot.z + $0.x) }
        rig.add(Prim.sweep(Shape2D.roundedRect(0.1, 0.0012, radius: 0.0005, segments: 1), along: catmull(jawPath, per: 3), up: V3(1, 0, 0), material: "metal.chrome"),
                to: "clip", lods: 0...0)
        rig.add(Prim.sweep(Shape2D.rect(0.1, 0.0012), along: jawPath, up: V3(1, 0, 0), material: "metal.chrome"), to: "clip", lods: 1...1)
        for sx: Float in [-0.035, 0.035] {
            rig.add(Prim.roundedBox(V3(0.012, 0.0012, 0.006), radius: 0.0005, bevelSegments: 1, material: "rubber"),
                    Xform(translation: V3(sx, cy + 0.0006, clipPivot.z + 0.024)), to: "clip", lods: 0...0)
        }

        // MARK: front cover (top hinge)
        rig.part("cover", pivot: V3(0, hy, hz), joint: .hinge(axis: V3(1, 0, 0), -openAngle...0, duration: 0.9))
        let cyTop: Float = 0.0225, cD = D - 0.004, czC = hz + cD / 2 - 0.002
        for l in 0..<2 {
            let bev: Float = l == 0 ? 0.0005 : 0.0003
            rig.add(Prim.extrude(Shape2D.roundedRect(W, cD, radius: 0.01, segments: l == 0 ? 4 : 2), depth: t, bevel: bev, bevelSegments: 1, material: metal),
                    Xform(translation: V3(0, cyTop - t / 2, czC), rotation: flat), to: "cover", lods: l...l)
            // Folded flanges: sides and bottom edge.
            for sx: Float in [-1, 1] {
                addStrip(V3(t, 0.0165, cD - 0.03), at: V3(sx * (W / 2 - 0.0006), cyTop - 0.0085, czC + 0.008), to: "cover", lods: l...l)
            }
            addStrip(V3(W - 0.03, 0.0165, t), at: V3(0, cyTop - 0.0085, czC + cD / 2 - 0.0006), alongX: true, to: "cover", lods: l...l)
            // Embossed lengthwise ribs.
            for k in 0..<6 {
                let x = -0.095 + Float(k) * 0.038
                rig.add(Prim.extrude(Shape2D.superellipse(0.011, 0.005, exponent: 2.6, segments: l == 0 ? 14 : 8), depth: cD - 0.12, bevel: 0, material: metal),
                        Xform(translation: V3(x, cyTop - 0.0009, czC + 0.04)), to: "cover", lods: l...l)
            }
        }
        // Cover knuckles.
        for i in stride(from: 1, to: kn, by: 2) {
            let (a, x) = knuckle(i, 12); rig.add(a, x, to: "cover", lods: 0...0)
        }
        // Leaf from the knuckles to the cover top.
        let (leaf, lq) = strip(V3(W - 0.012, t, 0.008), alongX: true)
        rig.add(leaf, Xform(translation: V3(0, cyTop - t / 2 - 0.0003, hz + 0.005), rotation: simd_quatf(degrees: -20, axis: V3(1, 0, 0)) * lq), to: "cover")
        // Black corner guards on the two free corners.
        for sx: Float in [-1, 1] {
            rig.add(Prim.roundedBox(V3(0.022, 0.0185, 0.022), radius: 0.004, bevelSegments: 1, material: black),
                    Xform(translation: V3(sx * (W / 2 - 0.009), cyTop - 0.0085, czC + cD / 2 - 0.009)), to: "cover")
        }
        // Name-card window: clear frame over a printed card, top centre of the cover.
        rig.add(Prim.roundedBox(V3(0.096, 0.0016, 0.036), radius: 0.0007, bevelSegments: 1, material: black),
                Xform(translation: V3(0, cyTop + 0.0006, hz + 0.045)), to: "cover", lods: 0...0)
        rig.add(strip(V3(0.096, 0.0016, 0.036), mat: black).0, Xform(translation: V3(0, cyTop + 0.0006, hz + 0.045)), to: "cover", lods: 1...1)
        var card = Surface(material: "label.supply-small")
        let wy = cyTop + 0.0015, wz = hz + 0.045
        let c0 = card.add(V3(-0.044, wy, wz - 0.015), .up, V2(0, 0)), c1 = card.add(V3(0.044, wy, wz - 0.015), .up, V2(0.08, 0))
        let c2 = card.add(V3(0.044, wy, wz + 0.015), .up, V2(0.08, 0.08 * 0.34)), c3 = card.add(V3(-0.044, wy, wz + 0.015), .up, V2(0, 0.08 * 0.34))
        card.quad(c0, c3, c2, c1)
        card.computeTangents()
        rig.add(card, to: "cover")
        rig.add(Prim.roundedBox(V3(0.09, 0.0004, 0.031), radius: 0.0002, bevelSegments: 1, material: "plastic.clear"),
                Xform(translation: V3(0, wy + 0.0004, wz)), to: "cover", lods: 0...0)

        // Red allergy-alert sticker on the cover's lower corner (the story detail), slightly askew.
        var alert = Surface(material: "label.hazard-small")
        let ay = cyTop + 0.00015, ac = V3(-0.066, ay, czC + cD / 2 - 0.0112), ar = simd_quatf(degrees: 4, axis: .up)
        let ac0 = alert.add(ac + ar.act(V3(-0.015, 0, -0.0078)), .up, V2(0, 0)), ac1 = alert.add(ac + ar.act(V3(0.015, 0, -0.0078)), .up, V2(0.05, 0))
        let ac2 = alert.add(ac + ar.act(V3(0.015, 0, 0.0078)), .up, V2(0.05, 0.026)), ac3 = alert.add(ac + ar.act(V3(-0.015, 0, 0.0078)), .up, V2(0, 0.026))
        alert.quad(ac0, ac3, ac2, ac1)
        alert.computeTangents()
        rig.add(alert, to: "cover")

        groundAO(&rig, height: 0.012, floor: 0.6)
        rig.states = [
            RigState("closed"),
            RigState("open", ["cover": -openAngle]),
            RigState("clip-open", ["cover": -openAngle, "clip": -65]),
        ]
        return rig
    }
}
