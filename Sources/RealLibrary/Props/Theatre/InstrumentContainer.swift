import simd
import Foundation

/// Full-size rigid sterilization container (Aesculap SterilContainer JK class), 580 x 280 mm footprint,
/// 152 mm closed: deep-drawn anodized aluminium tub with two embossed stiffening beads and a rolled flange,
/// stacking rails underneath; blue anodized lid with a silicone gasket and two round filter retention
/// plates; two lever latches on the ends with yellow tamper seals; folding stainless bail handles; a card
/// holder with the load card and a riveted ID tag on the front. Inside, a wire-mesh basket holds a ring-handle
/// instrument set. Lid lifts (slide) and tips back (hinge); latches swing out; handles fold up to carry.
public struct InstrumentContainer: RealArticulated {
    public static let id = "instrument-container"
    public static let summary = "Rigid sterilization container: anodized aluminium tub, blue lid with filter plates, side latches with seals and a perforated instrument basket."
    public static let tags = ["prop", "medical", "surgical", "articulated", "container", "metal", "handheld"]
    public static let budget = 9500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 28, distance: 0.95, studio: true)

    /// Tub footprint (x length, z depth) and closed height (m).
    public var length: Float = 0.58
    public var depth: Float = 0.28
    /// Lid anodizing color (sRGB hex): blue 2E5C9E, red A8322C, green 3A7A4A, gold B89A4A, grey 7A7E84.
    public var lidColor: UInt32 = 0x2E5C9E
    /// Tamper seal color (sRGB hex).
    public var sealColor: UInt32 = 0xE8C21E
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3])
        let alu: MaterialKey = "metal.anodized-worn", lidMat: MaterialKey = "metal.anodized-lid:" + String(format: "%06X", lidColor)
        let steel: MaterialKey = "metal.surgical", seal: MaterialKey = "plastic.gloss:" + String(format: "%06X", sealColor)
        let W = length, D = depth
        let yb: Float = 0.005, yr: Float = 0.119          // tub bottom, tub rim top
        let rc: Float = 0.03
        func ring(_ dw: Float, _ y: Float, _ l: Int, r: Float = 0.03, z: Float = 0) -> [V3] {
            Prim.ring(Shape2D.roundedRect(W + dw, D + dw, radius: r, segments: l == 0 ? 4 : 2), y: y, offset: V3(0, 0, z))
        }

        func cring(_ y: Float, _ l: Int) -> [V3] {
            Prim.ring(Shape2D.roundedRect(W * 0.08, D * 0.08, radius: 0.004, segments: l == 0 ? 4 : 2), y: y)
        }

        // MARK: tub
        for l in 0..<2 {
            var m = Model(name: Self.id)
            var rings: [[V3]] = [ring(-0.034, yb, l, r: 0.016), ring(-0.012, yb + 0.002, l, r: 0.024), ring(-0.004, yb + 0.008, l, r: rc)]
            // Embossed stiffening beads (LOD0) at 40 and 80 mm.
            for by: Float in [0.04, 0.08] where l == 0 {
                rings += [ring(-0.002, by - 0.004, l), ring(0.0012, by - 0.0015, l), ring(0.0012, by + 0.0015, l), ring(-0.002, by + 0.004, l)]
            }
            rings += [ring(0, yr - 0.012, l, r: rc + 0.001), ring(0.006, yr - 0.008, l, r: rc + 0.004), ring(0.008, yr - 0.003, l, r: rc + 0.005),
                      ring(0.004, yr, l, r: rc + 0.003), ring(-0.004, yr - 0.002, l, r: rc - 0.001), ring(-0.008, yr - 0.02, l, r: rc - 0.003),
                      ring(-0.012, yb + 0.012, l, r: rc - 0.006), ring(-0.04, yb + 0.006, l, r: 0.014)]
            m.add(Prim.loft(rings, capStart: true, capEnd: true, material: alu))
            // Stacking rails under the floor.
            for sz: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(W - 0.08, yb + 0.002, 0.016), radius: 0.002, bevelSegments: 1, material: alu),
                      Xform(translation: V3(0, (yb + 0.002) / 2, sz * D * 0.3)))
            }
            rig.base[l] = m
        }
        // End hardware: latch pivot blocks, handle brackets, seal eyelets.
        let latchY: Float = 0.072, hY: Float = 0.096, hz: Float = 0.085
        for sx: Float in [-1, 1] {
            let xw = sx * (W / 2 + 0.001)
            for l in 0..<2 {
                rig.base[l].add(Prim.roundedBox(V3(0.012, 0.016, 0.06), radius: 0.004, bevelSegments: 1, material: alu),
                                Xform(translation: V3(xw + sx * 0.005, latchY, 0)))
                for s2: Float in [-1, 1] {
                    rig.base[l].add(Prim.roundedBox(V3(0.012, 0.022, 0.014), radius: 0.004, bevelSegments: 1, material: alu),
                                    Xform(translation: V3(xw + sx * 0.005, hY, s2 * hz)))
                }
            }
            rig.base[0].add(Prim.torus(major: 0.004, minor: 0.0013, segments: 8, sides: 4, material: steel),
                            Xform(translation: V3(xw + sx * 0.005, latchY - 0.016, 0.022), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        }
        // Front: card holder frame with the load card, riveted ID tag.
        let fz = D / 2 + 0.0012
        for l in 0..<2 {
            rig.base[l].add(Prim.roundedBox(V3(0.11, 0.058, 0.004), radius: 0.0015, bevelSegments: 1, material: alu),
                            Xform(translation: V3(-0.13, 0.062, fz + 0.002)))
        }
        do {
            var card = Surface(material: "label.rx")
            let cw: Float = 0.096, ch: Float = 0.046, cx: Float = -0.13, cy: Float = 0.062, z = fz + 0.0042
            let n = V3(0, 0, 1)
            let a = card.add(V3(cx - cw / 2, cy + ch / 2, z), n, V2(0, 0)), b = card.add(V3(cx + cw / 2, cy + ch / 2, z), n, V2(1, 0))
            let c = card.add(V3(cx + cw / 2, cy - ch / 2, z), n, V2(1, 1)), d = card.add(V3(cx - cw / 2, cy - ch / 2, z), n, V2(0, 1))
            card.quad(d, c, b, a)
            card.computeTangents()
            for l in 0..<2 { rig.base[l].add(card) }
        }
        rig.base[0].add(Prim.roundedBox(V3(0.062, 0.022, 0.0016), radius: 0.0007, bevelSegments: 1, material: "metal.aluminum-brushed"),
                        Xform(translation: V3(0.15, 0.062, fz + 0.0008)))
        for sx: Float in [-1, 1] {
            rivet(&rig.base[0], at: V3(0.15 + sx * 0.026, 0.062, fz + 0.0016), normal: V3(0, 0, 1), radius: 0.0018, material: "metal.chrome")
        }

        // MARK: lid (lift, then tip back about the rear rim)
        let pz = -D / 2 - 0.006, py = yr + 0.004
        rig.part("lid-lift", pivot: V3(0, py, pz), joint: .slide(axis: V3(0, 1, 0), 0...0.08, duration: 0.5))
        rig.part("lid", parent: "lid-lift", pivot: V3(0, py, pz), joint: .hinge(axis: V3(1, 0, 0), -110...0, duration: 0.8))
        let ly0 = yr - 0.007, lyt: Float = 0.149
        for l in 0..<2 {
            let lr: [[V3]] = [
                cring(lyt - 0.02, l), ring(0.001, lyt - 0.02, l), ring(0.003, ly0 + 0.001, l, r: rc + 0.002),
                ring(0.012, ly0, l, r: rc + 0.006), ring(0.014, ly0 + 0.003, l, r: rc + 0.007), ring(0.014, lyt - 0.006, l, r: rc + 0.007),
                ring(0.008, lyt - 0.0005, l, r: rc + 0.004), ring(-0.01, lyt, l, r: rc - 0.004), cring(lyt, l),
            ]
            rig.add(Prim.loft(lr, capStart: true, capEnd: true, material: lidMat), to: "lid", lods: l...l)
        }
        // Silicone gasket seated in the lid channel.
        rig.add(Prim.sweep(Shape2D.roundedRect(0.005, 0.004, radius: 0.0015, segments: 1),
                           along: Shape2D.roundedRect(W + 0.004, D + 0.004, radius: rc + 0.002, segments: 4).map { V3($0.x, yr + 0.0005, -$0.y) },
                           up: V3(0, 1, 0), closedPath: true, caps: false, material: "rubber.silicone:6E7276"), to: "lid", lods: 0...0)
        // Filter retention plates: raised discs with concentric ribs, radial slots and a twist knob.
        let plateR: Float = 0.062
        for px: Float in [-0.14, 0.14] {
            for l in 0..<2 {
                let prof: [V2] = l == 0
                    ? [V2(plateR + 0.002, 0), V2(plateR, 0.0025), V2(plateR - 0.006, 0.003), V2(plateR - 0.008, 0.0045), V2(plateR - 0.012, 0.0045),
                       V2(plateR - 0.014, 0.003), V2(0.03, 0.003), V2(0.028, 0.0042), V2(0.024, 0.0042), V2(0.022, 0.003), V2(0.012, 0.003),
                       V2(0.011, 0.012), V2(0.0, 0.0125)]
                    : [V2(plateR + 0.002, 0), V2(plateR, 0.003), V2(0.012, 0.003), V2(0.011, 0.012), V2(0, 0.0125)]
                rig.add(Prim.lathe(prof, segments: l == 0 ? 20 : 10, material: lidMat), Xform(translation: V3(px, lyt - 0.0005, 0)), to: "lid", lods: l...l)
            }
            // Knob wings.
            rig.add(Prim.roundedBox(V3(0.034, 0.008, 0.006), radius: 0.0025, bevelSegments: 1, material: lidMat),
                    Xform(translation: V3(px, lyt + 0.009, 0), rotation: simd_quatf(degrees: rng.float(0...180), axis: .up)), to: "lid")
            var slots = Surface(material: "plastic.matte:16181A")
            for k in 0..<12 {
                let a = Float(k) / 12 * 2 * .pi
                slots.append(cuboid(V3(0.012, 0.0006, 0.0028), material: "plastic.matte:16181A"),
                             Xform(translation: V3(px + cos(a) * 0.041, lyt + 0.0027, -sin(a) * 0.041), rotation: simd_quatf(angle: a, axis: .up)))
            }
            rig.add(slots, to: "lid", lods: 0...0)
        }

        // Autoclave indicator tape across the lid front edge: cream tape with stripes turned dark by the cycle.
        do {
            let tx: Float = 0.2, tz = D / 2 - 0.03, tw: Float = 0.019, tl: Float = 0.075
            rig.add(cuboid(V3(tw, 0.0004, tl), material: "paper.sheet:E4DCC0"), Xform(translation: V3(tx, lyt + 0.0003, tz), rotation: simd_quatf(degrees: 6, axis: .up)), to: "lid")
            var stripes = Surface(material: "plastic.matte:16181A")
            for k in 0..<6 {
                stripes.append(cuboid(V3(0.0035, 0.0002, tw * 1.3), material: "plastic.matte:16181A"),
                               Xform(translation: V3(tx + 0.0, lyt + 0.0006, tz - tl / 2 + 0.008 + Float(k) * 0.012), rotation: simd_quatf(degrees: 6 + 50, axis: .up)))
            }
            rig.add(stripes, to: "lid", lods: 0...0)
        }

        // MARK: latches (swing outward about Z at the pivot blocks)
        for (sx, name) in [(Float(1), "latch-r"), (Float(-1), "latch-l")] {
            let xw = sx * (W / 2 + 0.012)
            rig.part(name, pivot: V3(xw, latchY, 0), joint: .hinge(axis: V3(0, 0, sx), -80...0, duration: 0.4))
            // Lever plate up the end wall, hook over the lid skirt, slot for the seal.
            let lever = Shape2D.rounded([V2(-0.022, 0), V2(0.022, 0), V2(0.02, lyt + 0.008 - latchY), V2(-0.02, lyt + 0.008 - latchY)], radius: 0.006, segments: 2)
            for l in 0..<2 {
                rig.add(Prim.extrude(lever, depth: 0.004, bevel: 0.0012, bevelSegments: 1, material: steel),
                        Xform(translation: V3(xw + sx * 0.001, latchY - 0.006, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 1, 0))), to: name, lods: l...l)
            }
            rig.add(Prim.roundedBox(V3(0.02, 0.0045, 0.04), radius: 0.002, bevelSegments: 1, material: steel),
                    Xform(translation: V3(xw - sx * 0.007, lyt + 0.0018, 0)), to: name)
            rig.add(Prim.cylinder(radius: 0.005, height: 0.064, bevel: 0.001, segments: 10, bevelSegments: 1, material: steel),
                    Xform(translation: V3(xw, latchY, -0.032), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: name, lods: 0...0)
            rig.add(cuboid(V3(0.0012, 0.008, 0.012), material: "plastic.matte:16181A"),
                    Xform(translation: V3(xw + sx * 0.0032, latchY + 0.03, 0.012)), to: name, lods: 0...0)
        }
        // MARK: tamper seals (option 0 intact through the latch, option 1 cut and hanging from the eyelet)
        for (sx, name) in [(Float(1), "seal-r"), (Float(-1), "seal-l")] {
            let xw = sx * (W / 2 + 0.006)
            let eye = V3(xw + sx * 0.002, latchY - 0.016, 0.022)
            rig.part(name, pivot: eye, joint: .fixed, options: 2)
            let strap = [eye, V3(xw + sx * 0.008, latchY + 0.0, 0.02), V3(xw + sx * 0.008, latchY + 0.028, 0.013), V3(xw + sx * 0.004, latchY + 0.03, 0.012)]
            rig.add(Prim.tube(catmull(strap, per: 3), radii: Array(repeating: 0.0011, count: catmull(strap, per: 3).count), sides: 5, seamTile: 0.02, material: seal),
                    to: name, lods: 0...0)
            let tag = Prim.roundedBox(V3(0.0018, 0.03, 0.012), radius: 0.0008, bevelSegments: 1, material: seal)
            rig.add(tag, Xform(translation: eye + V3(sx * 0.004, -0.018, 0.004), rotation: simd_quatf(degrees: sx * 8, axis: V3(0, 0, 1))), to: name)
            // Cut seal: short strap stub and the tag hanging lower.
            let cut = [eye, eye + V3(sx * 0.005, -0.006, 0.002), eye + V3(sx * 0.006, -0.014, 0.003)]
            rig.add(Prim.tube(cut, radii: [0.0011, 0.0011, 0.0011], sides: 5, seamTile: 0.02, material: seal), to: name, option: 1, lods: 0...0)
            rig.add(tag, Xform(translation: eye + V3(sx * 0.007, -0.03, 0.004), rotation: simd_quatf(degrees: sx * 18, axis: V3(0, 0, 1))), to: name, option: 1)
        }

        // MARK: handles (bails hang folded; swing out and up to carry)
        for (sx, name) in [(Float(1), "handle-r"), (Float(-1), "handle-l")] {
            let xw = sx * (W / 2 + 0.013)
            rig.part(name, pivot: V3(xw, hY, 0), joint: .hinge(axis: V3(0, 0, sx), 0...95, duration: 0.4))
            let drop: Float = 0.055
            var path: [V3] = [V3(xw, hY, -hz - 0.004), V3(xw, hY, -hz + 0.004)]
            path += [V3(xw + sx * 0.004, hY - drop * 0.4, -hz + 0.01), V3(xw + sx * 0.006, hY - drop + 0.012, -hz + 0.018)]
            path += [V3(xw + sx * 0.006, hY - drop, -hz + 0.034), V3(xw + sx * 0.006, hY - drop, hz - 0.034)]
            path += [V3(xw + sx * 0.006, hY - drop + 0.012, hz - 0.018), V3(xw + sx * 0.004, hY - drop * 0.4, hz - 0.01), V3(xw, hY, hz - 0.004), V3(xw, hY, hz + 0.004)]
            for l in 0..<2 {
                let pts = catmull(path, per: l == 0 ? 3 : 1)
                rig.add(Prim.tube(pts, radii: pts.map { _ in 0.003 }, sides: l == 0 ? 6 : 4, seamTile: 0.03, material: steel), to: name, lods: l...l)
            }
            // Grip sleeve on the bar.
            rig.add(Prim.cylinder(radius: 0.0062, height: 0.1, bevel: 0.002, segments: 10, bevelSegments: 1, material: "plastic.matte:16181A"),
                    Xform(translation: V3(xw + sx * 0.008, hY - drop, -0.05), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: name)
        }

        // MARK: basket and instruments (static, inside the tub)
        let bw = W - 0.05, bd = D - 0.045, bh: Float = 0.068, by0 = yb + 0.012
        do {
            var mesh = Surface(material: "metal.basket-mesh")
            func panel(_ o: V3, _ u: V3, _ v: V3, _ lu: Float, _ lv: Float) {
                let n = simd_normalize(simd_cross(u, v))
                let a = mesh.add(o, n, V2(0, 0)), b = mesh.add(o + u * lu, n, V2(lu, 0))
                let c = mesh.add(o + u * lu + v * lv, n, V2(lu, lv)), d = mesh.add(o + v * lv, n, V2(0, lv))
                mesh.quad(a, b, c, d)
            }
            panel(V3(-bw / 2, by0, bd / 2), V3(1, 0, 0), V3(0, 0, -1), bw, bd)                 // floor (up)
            panel(V3(-bw / 2, by0, bd / 2), V3(1, 0, 0), V3(0, 1, 0), bw, bh)                  // front
            panel(V3(bw / 2, by0, -bd / 2), V3(-1, 0, 0), V3(0, 1, 0), bw, bh)                 // back
            panel(V3(-bw / 2, by0, -bd / 2), V3(0, 0, 1), V3(0, 1, 0), bd, bh)                 // left
            panel(V3(bw / 2, by0, bd / 2), V3(0, 0, -1), V3(0, 1, 0), bd, bh)                  // right
            mesh.computeTangents()
            for l in 0..<2 { rig.base[l].add(mesh); rig.base[l].add(mesh.flipped()) }
            // Wire frame: top and bottom rims, corner posts.
            for (y, rr) in [(by0 + bh, Float(0.0022)), (by0, Float(0.0018))] {
                let rim = Shape2D.roundedRect(bw, bd, radius: 0.006, segments: 2).map { V3($0.x, y, -$0.y) }
                rig.base[0].add(Prim.sweep(Shape2D.circle(rr, segments: 6), along: rim, closedPath: true, caps: false, material: steel))
            }
            // Fold-down basket handles lying on the rim at the ends.
            for sx: Float in [-1, 1] {
                let hp = [V3(sx * (bw / 2 - 0.004), by0 + bh + 0.003, -0.05), V3(sx * (bw / 2 - 0.03), by0 + bh + 0.003, -0.04),
                          V3(sx * (bw / 2 - 0.03), by0 + bh + 0.003, 0.04), V3(sx * (bw / 2 - 0.004), by0 + bh + 0.003, 0.05)]
                rig.base[0].add(Prim.tube(hp, radii: [0.002, 0.002, 0.002, 0.002], sides: 6, seamTile: 0.03, material: steel))
            }
        }
        // Instrument set on the basket floor, lengths along X, alternating directions; a silicone stringer mat.
        rig.base[0].add(Prim.roundedBox(V3(bw - 0.03, 0.003, bd - 0.03), radius: 0.001, bevelSegments: 1, material: "rubber.silicone:5A6E78"),
                        Xform(translation: V3(0, by0 + 0.0025, 0)))
        let kit: [(TheatreInstrument, Float)] = [(.hemostat, 0.14), (.hemostat, 0.14), (.curvedHemostat, 0.16), (.curvedHemostat, 0.16),
                                                 (.scissors, 0.17), (.needleHolder, 0.18), (.forceps, 0.15), (.scalpel, 0.135),
                                                 (.towelClip, 0.11)]
        var irng = rng.fork(3)
        for (i, (kind, len)) in kit.enumerated() {
            // Two instruments per row, ring handles toward the basket ends.
            let row = i / 2, left = i % 2 == 0
            let x = (left ? -0.13 : 0.13) + irng.float(-0.01...0.01)
            let z = -bd / 2 + 0.03 + Float(row) * 0.044 + irng.float(-0.004...0.004)
            rig.base[0].add(theatreInstrument(kind, length: len),
                            Xform(translation: V3(x + (left ? len / 2 : -len / 2), by0 + 0.004 + Float(i % 3) * 0.0004, z),
                                  rotation: simd_quatf(degrees: (left ? -90 : 90) + irng.float(-3...3), axis: .up)))
        }

        groundAO(&rig, height: 0.03, floor: 0.6)
        rig.states = [
            RigState("sealed"),
            RigState("unlatched", ["latch-r": -75, "latch-l": -75], options: ["seal-r": 1, "seal-l": 1]),
            RigState("open", ["latch-r": -75, "latch-l": -75, "lid-lift": 0.006, "lid": -105], options: ["seal-r": 1, "seal-l": 1]),
            RigState("carry", ["handle-r": 90, "handle-l": 90]),
        ]
        return rig
    }
}
