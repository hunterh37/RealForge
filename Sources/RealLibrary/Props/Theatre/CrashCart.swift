import simd
import Foundation

/// Emergency crash cart (Harloff Classic 6400 class), cabinet 780 x 560 mm on 125 mm casters: red powder-
/// coated steel shell with front stiles, grey perimeter bumper, five drawers (three 3 in, one 6 in, one 9 in)
/// on full-extension slides with full-width aluminium pulls and label cards, a breakaway lock hasp with a
/// numbered plastic seal, grey ABS top with a raised rim on three sides, a defibrillator on a shelf post, an
/// O2 D-cylinder in a side holder, a CPR board on the back, a side push handle and a clipped daily check log.
/// Each drawer slides; the seal is an option (intact or cut).
public struct CrashCart: RealArticulated {
    public static let id = "crash-cart"
    public static let summary = "Emergency crash cart: red powder-coated cabinet with five drawers, breakaway seal, rimmed top, O2 tank holder, CPR board and defib shelf."
    public static let tags = ["prop", "medical", "hospital", "articulated", "furniture", "container", "metal"]
    public static let budget = 14000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 14, distance: 1.9, studio: true)

    /// Powder coat color (sRGB hex).
    public var color: UInt32 = 0xB3201C
    public var width: Float = 0.78
    public var depth: Float = 0.56
    /// Drawer front heights, top to bottom (m).
    public var drawers: [Float] = [0.11, 0.11, 0.11, 0.2, 0.28]
    /// Drawer travel (m).
    public var travel: Float = 0.42
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [8])
        let paint: MaterialKey = "metal.powdercoat:" + String(format: "%06X", color)
        let grey: MaterialKey = "plastic.medical-grey", dark: MaterialKey = "plastic.matte:2A2B2D"
        let alu: MaterialKey = "metal.aluminum-brushed", liner: MaterialKey = "metal.powdercoat:3A3A3C"
        let W = width, D = depth
        let y0: Float = 0.165, yTop: Float = 1.045           // cabinet underside, cabinet top
        let sheet: Float = 0.018, stile: Float = 0.026, front: Float = 0.02
        let zFace = D / 2 - front
        let stackLo = y0 + 0.012, reveal: Float = 0.006

        func box(_ size: V3, _ c: V3, _ mat: MaterialKey, r: Float = 0.004, seg: Int = 1) -> (Surface, Xform) {
            (Prim.roundedBox(size, radius: r, bevelSegments: seg, material: mat), Xform(translation: c))
        }

        // MARK: cabinet, base, top
        for l in 0..<2 {
            var m = Model(name: Self.id)
            func add(_ b: (Surface, Xform)) { m.add(b.0, b.1) }
            let sg = l == 0 ? 2 : 1
            for sx: Float in [-1, 1] {
                add(box(V3(sheet, yTop - y0, D - front), V3(sx * (W / 2 - sheet / 2), (y0 + yTop) / 2, -front / 2), paint, r: 0.006, seg: sg))
                add(box(V3(stile, yTop - y0 - 0.01, front), V3(sx * (W / 2 - stile / 2), (y0 + yTop) / 2, zFace + front / 2 - 0.002), paint, r: 0.004, seg: sg))
            }
            add(box(V3(W - 2 * sheet, yTop - y0, sheet), V3(0, (y0 + yTop) / 2, -D / 2 + sheet / 2), paint, r: 0.003))
            // Chassis pan and bumper.
            add(box(V3(W, 0.02, D), V3(0, y0 + 0.002, 0), paint, r: 0.005, seg: sg))
            let bump = Shape2D.roundedRect(W + 0.03, D + 0.03, radius: 0.05, segments: l == 0 ? 5 : 2).map { V3($0.x, y0 + 0.004, -$0.y) }
            m.add(Prim.sweep(Shape2D.roundedRect(0.03, 0.034, radius: 0.01, segments: l == 0 ? 2 : 1), along: bump, up: V3(0, 1, 0),
                             closedPath: true, caps: false, material: "rubber"))
            // Dark cavity behind the drawers.
            var cav = cuboid(V3(W - 2 * sheet - 0.004, yTop - y0 - 0.03, D - front - sheet - 0.01), material: liner).flipped()
            cav = cav.transformed(Xform(translation: V3(0, (y0 + yTop) / 2, -front / 2 + 0.002)))
            m.add(cav)
            // Top: grey ABS worksurface with raised rim on back and sides.
            let tw = W + 0.02, td = D + 0.02
            add(box(V3(tw, 0.03, td), V3(0, yTop + 0.015, 0.005), grey, r: 0.008, seg: sg))
            add(box(V3(tw, 0.035, 0.022), V3(0, yTop + 0.045, -td / 2 + 0.016), grey, r: 0.009, seg: 1))
            for sx: Float in [-1, 1] {
                add(box(V3(0.022, 0.035, td - 0.01), V3(sx * (tw / 2 - 0.011), yTop + 0.045, 0.0), grey, r: 0.009, seg: 1))
            }
            // Casters, brakes on the front pair.
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                theatreCaster(&m, at: V3(sx * (W / 2 - 0.06), 0, sz * (D / 2 - 0.07)), height: y0 - 0.008, wheelRadius: 0.0625, width: 0.032,
                              yaw: sz > 0 ? 0 : 180, brake: sz > 0, detail: l, frame: "metal.chrome", wheel: "rubber.tubing:3A3B3D", hub: grey)
            }}
            rig.base[l] = m
        }
        // Breakaway lock hasp on the right stile, top.
        let hx = W / 2 - stile / 2, hy = yTop - 0.04, hzf = D / 2 + 0.006
        for l in 0..<2 {
            rig.base[l].add(Prim.roundedBox(V3(0.022, 0.05, 0.016), radius: 0.003, bevelSegments: 1, material: alu), Xform(translation: V3(hx, hy, hzf - 0.004)))
        }
        rig.base[0].add(Prim.torus(major: 0.006, minor: 0.0018, segments: 10, sides: 4, material: "metal.chrome"),
                        Xform(translation: V3(hx, hy - 0.03, hzf + 0.002), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))

        // MARK: O2 cylinder holder (-X side)
        let tx = -W / 2 - 0.075, tz: Float = 0.06, tr: Float = 0.052
        for l in 0..<2 {
            let sg = l == 0 ? 16 : 8
            for (y, h) in [(Float(0.3), Float(0.03)), (Float(0.72), Float(0.03))] {
                rig.base[l].add(Prim.lathe([V2(tr + 0.004, 0), V2(tr + 0.008, 0.002), V2(tr + 0.008, h - 0.002), V2(tr + 0.004, h)], segments: sg, material: "metal.chrome"),
                                Xform(translation: V3(tx, y, tz)))
                rig.base[l].add(l == 0 ? Prim.roundedBox(V3(0.07, 0.024, 0.03), radius: 0.004, bevelSegments: 1, material: "metal.chrome") : cuboid(V3(0.07, 0.024, 0.03), material: "metal.chrome"),
                                Xform(translation: V3(-W / 2 - 0.03, y + h / 2, tz)))
            }
            // Bottom cup.
            rig.base[l].add(Prim.lathe([V2(0, 0.2), V2(tr + 0.006, 0.2), V2(tr + 0.006, 0.24), V2(tr + 0.002, 0.24), V2(tr + 0.002, 0.206), V2(0, 0.206)],
                                       segments: sg, material: "metal.chrome"), Xform(translation: V3(tx, 0, tz)))
            rig.base[l].add(l == 0 ? Prim.roundedBox(V3(0.07, 0.02, 0.04), radius: 0.004, bevelSegments: 1, material: "metal.chrome") : cuboid(V3(0.07, 0.02, 0.04), material: "metal.chrome"),
                            Xform(translation: V3(-W / 2 - 0.03, 0.21, tz)))
            // Green D cylinder with shoulder, valve and regulator.
            var prof: [V2] = [V2(0, 0.206), V2(tr - 0.006, 0.206), V2(tr, 0.215), V2(tr, 0.68)]
            for k in 1...(l == 0 ? 6 : 3) {
                let a = Float(k) / Float(l == 0 ? 6 : 3) * .pi / 2
                prof.append(V2(0.012 + (tr - 0.012) * cos(a), 0.68 + 0.05 * sin(a)))
            }
            prof += [V2(0.012, 0.745), V2(0, 0.745)]
            rig.base[l].add(Prim.lathe(prof, segments: sg, material: "metal.powdercoat:2E7D4F"), Xform(translation: V3(tx, 0, tz)))
            rig.base[l].add(Prim.lathe([V2(0.011, 0.744), V2(0.013, 0.75), V2(0.013, 0.79), V2(0.009, 0.8), V2(0, 0.8)], segments: l == 0 ? 12 : 8, material: "metal.brass"),
                            Xform(translation: V3(tx, 0, tz)))
            rig.base[l].add(l == 0 ? Prim.roundedBox(V3(0.045, 0.05, 0.04), radius: 0.008, bevelSegments: 1, material: "metal.chrome") : cuboid(V3(0.045, 0.05, 0.04), material: "metal.chrome"), Xform(translation: V3(tx, 0.82, tz)))
        }
        // Regulator gauge and flow knob.
        rig.base[0].add(Prim.cylinder(radius: 0.022, height: 0.014, bevel: 0.003, segments: 16, bevelSegments: 1, material: "metal.chrome"),
                        Xform(translation: V3(tx, 0.84, tz + 0.02), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        rig.base[0].add(Prim.cylinder(radius: 0.019, height: 0.001, bevel: 0, segments: 16, bevelSegments: 1, material: "paper.sheet"),
                        Xform(translation: V3(tx, 0.84, tz + 0.0345), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        rig.base[0].add(Prim.cylinder(radius: 0.012, height: 0.02, bevel: 0.003, segments: 12, bevelSegments: 1, material: "metal.powdercoat:2E7D4F"),
                        Xform(translation: V3(tx - 0.022, 0.82, tz), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))

        // MARK: CPR board on the back, push handle and check log (+X)
        for l in 0..<2 {
            rig.base[l].add(Prim.roundedBox(V3(0.5, 0.6, 0.014), radius: 0.006, bevelSegments: l == 0 ? 2 : 1, material: dark),
                            Xform(translation: V3(0, 0.62, -D / 2 - 0.022)))
            for sx: Float in [-1, 1] {
                rig.base[l].add(l == 0 ? Prim.roundedBox(V3(0.04, 0.03, 0.035), radius: 0.004, bevelSegments: 1, material: "metal.chrome") : cuboid(V3(0.04, 0.03, 0.035), material: "metal.chrome"),
                                Xform(translation: V3(sx * 0.2, 0.33, -D / 2 - 0.016)))
            }
        }
        rig.base[0].add(Prim.roundedBox(V3(0.16, 0.035, 0.002), radius: 0.001, bevelSegments: 1, material: "paper.sheet"),
                        Xform(translation: V3(0, 0.86, -D / 2 - 0.0298)))
        for l in 0..<2 {
            // Side push handle: chrome bar on two posts.
            let hpth = [V3(W / 2, 0.9, -0.21), V3(W / 2 + 0.05, 0.9, -0.2), V3(W / 2 + 0.05, 0.9, 0.2), V3(W / 2, 0.9, 0.21)]
            let pts = catmull(hpth, per: l == 0 ? 3 : 1)
            rig.base[l].add(Prim.tube(pts, radii: pts.map { _ in 0.012 }, sides: l == 0 ? 12 : 6, seamTile: 0.1, material: "metal.chrome"))
        }
        do {
            let cx = W / 2 + 0.003, cy: Float = 0.62, cz: Float = 0.08
            rig.base[0].add(Prim.roundedBox(V3(0.004, 0.32, 0.23), radius: 0.003, bevelSegments: 1, material: dark),
                            Xform(translation: V3(cx, cy, cz)))
            rig.base[0].add(Prim.roundedBox(V3(0.001, 0.28, 0.215), radius: 0.0005, bevelSegments: 1, material: "paper.sheet"),
                            Xform(translation: V3(cx + 0.0025, cy - 0.015, cz), rotation: simd_quatf(degrees: rng.float(-2...2), axis: V3(1, 0, 0))))
            rig.base[0].add(Prim.roundedBox(V3(0.012, 0.03, 0.09), radius: 0.004, bevelSegments: 1, material: "metal.chrome"),
                            Xform(translation: V3(cx + 0.006, cy + 0.14, cz)))
            // Log lines: a few pen ticks.
            var ticks = Surface(material: "plastic.matte:1A2A6A")
            for k in 0..<9 {
                ticks.append(cuboid(V3(0.0004, 0.002, rng.float(0.03...0.09)), material: "plastic.matte:1A2A6A"),
                             Xform(translation: V3(cx + 0.0032, cy + 0.09 - Float(k) * 0.024, cz - 0.04 + rng.float(0...0.03))))
            }
            rig.base[0].add(ticks)
            rig.base[1].add(Prim.roundedBox(V3(0.004, 0.32, 0.23), radius: 0.002, bevelSegments: 1, material: "paper.sheet"), Xform(translation: V3(cx, cy, cz)))
        }

        // MARK: defibrillator shelf on a post (back right of the top)
        let px = W / 2 - 0.12, pzz = -D / 2 + 0.1
        let shelfY = yTop + 0.085
        for l in 0..<2 {
            let sg = l == 0 ? 16 : 8
            rig.base[l].add(Prim.cylinder(radius: 0.018, height: shelfY - yTop - 0.03, bevel: 0.002, segments: sg, bevelSegments: 1, material: "metal.chrome"),
                            Xform(translation: V3(px, yTop + 0.03, pzz)))
            rig.base[l].add(Prim.roundedBox(V3(0.42, 0.012, 0.34), radius: 0.005, bevelSegments: 1, material: paint), Xform(translation: V3(px - 0.1, shelfY, pzz + 0.1)))
            rig.base[l].add(Prim.roundedBox(V3(0.42, 0.03, 0.01), radius: 0.004, bevelSegments: 1, material: paint), Xform(translation: V3(px - 0.1, shelfY + 0.015, pzz + 0.1 - 0.165)))
            // Defibrillator: grey housing with a dark face, screen and handle.
            rig.base[l].add(Prim.roundedBox(V3(0.33, 0.21, 0.24), radius: 0.025, bevelSegments: l == 0 ? 2 : 1, material: "plastic.medical-grey:5C6166"),
                            Xform(translation: V3(px - 0.1, shelfY + 0.006 + 0.105, pzz + 0.1)))
            rig.base[l].add(Prim.roundedBox(V3(0.3, 0.17, 0.01), radius: 0.012, bevelSegments: 1, material: dark),
                            Xform(translation: V3(px - 0.1, shelfY + 0.11, pzz + 0.1 + 0.118)))
        }
        do {
            var scr = Surface(material: "screen.off")
            let sx0 = px - 0.1 - 0.13, sx1 = px - 0.1 + 0.02, sy0 = shelfY + 0.06, sy1 = shelfY + 0.155, sz = pzz + 0.1 + 0.1235
            let n = V3(0, 0, 1)
            let a = scr.add(V3(sx0, sy1, sz), n, V2(0, 0)), b = scr.add(V3(sx1, sy1, sz), n, V2(1, 0))
            let c = scr.add(V3(sx1, sy0, sz), n, V2(1, 1)), d = scr.add(V3(sx0, sy0, sz), n, V2(0, 1))
            scr.quad(d, c, b, a)
            for l in 0..<2 { rig.base[l].add(scr) }
            // Energy dial and buttons.
            rig.base[0].add(Prim.cylinder(radius: 0.022, height: 0.012, bevel: 0.003, segments: 16, bevelSegments: 1, material: "plastic.matte:D8B020"),
                            Xform(translation: V3(px - 0.1 + 0.08, shelfY + 0.12, sz - 0.002), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            for k in 0..<3 {
                rig.base[0].add(Prim.roundedBox(V3(0.022, 0.012, 0.006), radius: 0.003, bevelSegments: 1, material: k == 0 ? "plastic.matte:B3261E" : "plastic.medical"),
                                Xform(translation: V3(px - 0.1 + 0.12, shelfY + 0.072 - Float(k) * 0.02, sz - 0.002)))
            }
            let hp = [V3(px - 0.2, shelfY + 0.2, pzz + 0.1), V3(px - 0.19, shelfY + 0.235, pzz + 0.1), V3(px - 0.01, shelfY + 0.235, pzz + 0.1), V3(px, shelfY + 0.2, pzz + 0.1)]
            rig.base[0].add(Prim.tube(catmull(hp, per: 2), radii: Array(repeating: 0.009, count: catmull(hp, per: 2).count), sides: 8, seamTile: 0.05, material: dark))
        }
        // Strap across the defibrillator.
        rig.base[0].add(Prim.roundedBox(V3(0.025, 0.002, 0.26), radius: 0.0008, bevelSegments: 1, material: dark),
                        Xform(translation: V3(px - 0.2, shelfY + 0.217, pzz + 0.1)))

        // MARK: drawers
        let lip = Shape2D.rounded([V2(0, 0), V2(0.004, 0), V2(0.004, -0.018), V2(0.026, -0.022), V2(0.028, -0.027), V2(0, -0.029)], radius: 0.0012, segments: 2)
        let fw = W - 2 * stile - 2 * reveal, depthIn = D - front - 0.05
        var yCursor = yTop - 0.012
        let labelMats: [MaterialKey] = ["label.rx", "label.hazard", "label.iv", "label.rx", "label.iv"]
        for (k, fh) in drawers.enumerated() {
            let name = "drawer\(k + 1)"
            let top = yCursor, cy = top - fh / 2
            yCursor -= fh + reveal
            let zc = D / 2 - front / 2
            rig.part(name, pivot: V3(0, cy, zc), joint: .slide(axis: V3(0, 0, 1), 0...travel, duration: 0.6))
            for l in 0..<2 {
                rig.add(Prim.roundedBox(V3(fw, fh, front), radius: 0.004, bevelSegments: 1, material: paint),
                        Xform(translation: V3(0, cy, zc + 0.002)).jittered(&rng, deg: 0.03, offset: 0.0002), to: name, lods: l...l)
            }
            // Full-width aluminium pull under the top edge.
            rig.add(Prim.extrude(lip, depth: fw - 0.04, bevel: 0.001, bevelSegments: 1, material: alu),
                    Xform(translation: V3(0, top - 0.008, D / 2 + 0.003), rotation: simd_quatf(degrees: -90, axis: .up)), to: name)
            // Label card in a clear sleeve.
            do {
                var card = Surface(material: labelMats[k])
                let lw: Float = 0.1, lh: Float = min(0.04, fh * 0.3), lx: Float = -fw / 2 + 0.09, ly = cy - (fh > 0.12 ? fh * 0.15 : 0.012), lz = D / 2 + 0.0035
                let n = V3(0, 0, 1)
                let a = card.add(V3(lx - lw / 2, ly + lh / 2, lz), n, V2(0, 0)), b = card.add(V3(lx + lw / 2, ly + lh / 2, lz), n, V2(1, 0))
                let c = card.add(V3(lx + lw / 2, ly - lh / 2, lz), n, V2(1, 1)), d = card.add(V3(lx - lw / 2, ly - lh / 2, lz), n, V2(0, 1))
                card.quad(d, c, b, a)
                card.computeTangents()
                rig.add(card, to: name)
                rig.add(cuboid(V3(lw + 0.008, lh + 0.008, 0.0015), material: "plastic.clear"), Xform(translation: V3(lx, ly, lz + 0.0012)), to: name, lods: 0...0)
            }
            // Drawer box: sides, back, bottom (dark grey), slide members.
            let bw = fw - 0.03, bh = fh - 0.025, zb = zc - front / 2 - depthIn / 2
            for sx: Float in [-1, 1] {
                rig.add(cuboid(V3(0.008, bh, depthIn), material: liner), Xform(translation: V3(sx * bw / 2, cy - 0.005, zb)), to: name)
                rig.add(cuboid(V3(0.004, 0.02, depthIn * 0.95), material: alu), Xform(translation: V3(sx * (bw / 2 + 0.008), cy, zb)), to: name, lods: 0...0)
            }
            rig.add(cuboid(V3(bw, 0.006, depthIn), material: liner), Xform(translation: V3(0, cy - fh / 2 + 0.012, zb)), to: name)
            rig.add(cuboid(V3(bw, bh, 0.008), material: liner), Xform(translation: V3(0, cy - 0.005, zc - front / 2 - depthIn)), to: name)
            // Contents: dividers and boxed supplies (LOD0).
            var drng = rng.fork(100 + k)
            let fillMats: [MaterialKey] = ["plastic.medical", "paper.sheet", "plastic.matte:3A72B8"]
            var x = -bw / 2 + 0.02
            while x < bw / 2 - 0.06 {
                let w = drng.float(0.04...0.12), h = min(bh - 0.02, drng.float(0.03...0.09)), dz = drng.float(0.1...0.3)
                rig.add(cuboid(V3(w - 0.006, h, dz), material: fillMats[drng.int(0...2)]),
                        Xform(translation: V3(x + w / 2, cy - fh / 2 + 0.015 + h / 2, zc - front / 2 - 0.02 - dz / 2 - drng.float(0...0.08))), to: name, lods: 0...0)
                x += w
            }
        }

        // MARK: breakaway seal (option 0 intact through the hasp, option 1 cut)
        rig.part("seal", pivot: V3(hx, hy - 0.03, hzf), joint: .fixed, options: 2)
        let sealMat: MaterialKey = "plastic.gloss:E8C21E"
        let loop = (0...10).map { k -> V3 in
            let a = Float(k) / 10 * 2 * .pi
            return V3(hx + 0.0, hy - 0.03 - 0.012 + 0.012 * cos(a), hzf + 0.004 + 0.008 * sin(a))
        }
        rig.add(Prim.tube(loop, radii: loop.map { _ in 0.0012 }, sides: 5, seamTile: 0.02, material: sealMat), to: "seal", lods: 0...0)
        let tag = Prim.roundedBox(V3(0.014, 0.034, 0.002), radius: 0.001, bevelSegments: 1, material: sealMat)
        rig.add(tag, Xform(translation: V3(hx + 0.002, hy - 0.072, hzf + 0.008), rotation: simd_quatf(degrees: 6, axis: V3(0, 0, 1))), to: "seal")
        rig.add(Prim.roundedBox(V3(0.009, 0.004, 0.0006), radius: 0.0002, bevelSegments: 1, material: dark),
                Xform(translation: V3(hx + 0.002, hy - 0.068, hzf + 0.0092)), to: "seal", lods: 0...0)
        // Cut: the strap is snipped, the tag hangs from the ring on a short stub.
        rig.add(Prim.tube([V3(hx, hy - 0.042, hzf + 0.004), V3(hx + 0.003, hy - 0.05, hzf + 0.006), V3(hx + 0.004, hy - 0.056, hzf + 0.007)],
                          radii: [0.0012, 0.0012, 0.0012], sides: 5, seamTile: 0.02, material: sealMat), to: "seal", option: 1, lods: 0...0)
        rig.add(tag, Xform(translation: V3(hx + 0.006, hy - 0.073, hzf + 0.008), rotation: simd_quatf(degrees: 14, axis: V3(0, 0, 1))), to: "seal", option: 1)

        groundAO(&rig, height: 0.15, floor: 0.55)
        let open = travel * 0.95
        rig.states = [RigState("sealed")]
            + (1...drawers.count).map { RigState("drawer\($0)-open", ["drawer\($0)": open], options: ["seal": 1]) }
            + [RigState("all-open", Dictionary(uniqueKeysWithValues: (1...drawers.count).map { ("drawer\($0)", open * (0.5 + 0.1 * Float($0))) }), options: ["seal": 1])]
        return rig
    }
}
