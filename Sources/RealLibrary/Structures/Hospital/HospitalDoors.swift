import simd
import Foundation

/// Pair of double-acting hospital corridor doors in a 72 x 84 in (1.83 x 2.13 m) opening, the usual
/// patient-transport traffic pair: 16 ga hollow-metal cased frame (51 mm faces, 146 mm soffit, no stops
/// so the leaves swing both ways), two 44 mm solid-core leaves faced in maple woodgrain plastic laminate
/// with full-round pivot and meeting edges, narrow 4 x 25 in vision kits with polished wired glass,
/// 254 mm stainless kick plates and 4 x 16 in push plates on both faces, center-hung top pivots in the
/// head and floor-closer pivots under stainless cover plates. Bed-bumper rubber scuffs mark the kick
/// plates. Base y = 0, centered, frame in the wall plane (depth along Z), doorway along X. Each leaf
/// pivots about a vertical axis at its pivot-edge radius center; positive angles swing it toward -Z.
public struct HospitalDoors: RealArticulated {
    public static let id = "hospital-doors"
    public static let summary = "Double-acting hospital door pair: hollow-metal frame, laminate leaves with wired-glass lites, stainless kick and push plates, center-hung pivots."
    public static let tags = ["structure", "medical", "hospital", "interior", "door", "wood", "metal", "glass", "articulated"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 6, distance: 1.05, studio: true)

    /// Clear opening between jamb soffits (m).
    public var openingWidth: Float = 1.83
    /// Floor to head soffit (m).
    public var openingHeight: Float = 2.13
    /// Frame depth (wall thickness plus face returns) (m).
    public var frameDepth: Float = 0.146
    public var leafThickness: Float = 0.0445
    /// Floor clearance under the leaves (m).
    public var undercut: Float = 0.016
    public var leafMaterial: MaterialKey = "laminate.door-maple"
    public var frameMaterial: MaterialKey = "metal.powder-white:8A959C"
    public var kitMaterial: MaterialKey = "metal.powder-white:3E4246"
    public var plateMaterial: MaterialKey = "metal.kickplate"
    public var hardware: MaterialKey = "metal.stainless"
    /// Kick plate height (m).
    public var kickHeight: Float = 0.254
    /// Push plate center height (m).
    public var pushHeight: Float = 1.12
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        let rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [10])
        let xo = openingWidth / 2, headY = openingHeight, D = frameDepth
        let fw: Float = 0.051, ft: Float = 0.0127
        let T = leafThickness, r = T / 2 - 0.0002
        let gapJ: Float = 0.003, meet: Float = 0.005, topGap: Float = 0.003
        let W = (2 * xo - 2 * gapJ - meet) / 2
        let y0 = undercut, y1 = headY - topGap
        let H = y1 - y0
        let pivotX = -xo + gapJ + T / 2
        let flat = simd_quatf(degrees: -90, axis: V3(1, 0, 0))   // extrude depth (z) -> +Y
        let ss = hardware

        // MARK: frame (static)
        var outline = [V2(-xo - fw, 0), V2(-xo, 0), V2(-xo, headY), V2(xo, headY), V2(xo, 0), V2(xo + fw, 0),
                       V2(xo + fw, headY + fw), V2(-xo - fw, headY + fw)]
        if Shape2D.area(outline) < 0 { outline.reverse() }
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let face = Prim.extrude(l == 0 ? Shape2D.rounded(outline, radius: 0.0025, segments: 2) : outline, depth: ft,
                                    bevel: l == 0 ? 0.0018 : 0.001, bevelSegments: l == 0 ? 2 : 1, material: frameMaterial)
            for sz: Float in [-1, 1] { m.add(face, Xform(translation: V3(0, 0, sz * (D / 2 - ft / 2)))) }
            let sd = D - 2 * ft + 0.002
            for sx: Float in [-1, 1] {
                m.add(HK.box(V3(0.012, headY + 0.012, sd), V3(sx * (xo + 0.006), (headY + 0.012) / 2, 0), frameMaterial, r: 0.0015, seg: 1))
            }
            m.add(HK.box(V3(2 * xo + 0.001, 0.012, sd), V3(0, headY + 0.006, 0), frameMaterial, r: 0.0015, seg: 1))
            for sx: Float in [-1, 1] {
                let px = sx * -pivotX
                // Floor-closer cover plate along the closed leaf line, top-pivot plate in the head soffit.
                m.add(HK.box(V3(0.33, 0.004, 0.1), V3(px - sx * 0.12, 0.002, 0), ss, r: 0.0015, seg: 1))
                m.add(HK.box(V3(0.075, 0.003, 0.034), V3(px - sx * 0.022, headY - 0.0012, 0), ss, r: 0.001, seg: 1))
                if l == 0 {
                    for dx: Float in [-0.14, 0.14] {
                        m.add(HK.cyl(r: 0.0032, len: 0.0012, at: V3(px - sx * 0.12 + dx, 0.0042, 0), axis: .up, mat: ss, seg: 8, bevel: 0.0002))
                    }
                    for dx: Float in [-0.026, 0.026] {
                        m.add(HK.cyl(r: 0.0026, len: 0.001, at: V3(px - sx * 0.022 + dx, headY - 0.0031, 0), axis: V3(0, -1, 0), mat: ss, seg: 8, bevel: 0.0002))
                    }
                }
            }
            rig.base[l] = m
        }

        // MARK: leaves (authored as the left leaf, the right one is the same leaf turned 180 degrees)
        let kitW: Float = 0.022, kitT: Float = 0.005
        let gw: Float = 0.115, gh: Float = 0.635
        let ext: Float = 0.012
        func leaf(_ l: Int, _ rng: inout SeededRNG) -> Model {
            var m = Model(name: "leaf")
            let ux = { (u: Float) -> Float in -xo + gapJ + u }
            // Full-round hardwood edges, laminate-banded, on the pivot and meeting stiles.
            let segs = l == 0 ? 12 : 6
            var edge: [V2] = [V2(-ext, -r)]
            for k in 0...segs {
                let a = -Float.pi / 2 + Float.pi * Float(k) / Float(segs)
                edge.append(V2(cos(a) * r, sin(a) * r))
            }
            edge.append(V2(-ext, r))
            let edgeS = Prim.extrude(edge, depth: H, bevel: 0.001, bevelSegments: 1, material: leafMaterial)
            m.add(edgeS, Xform(translation: V3(ux(T / 2), y0 + H / 2, 0), rotation: simd_quatf(degrees: 180, axis: .up) * flat))
            m.add(edgeS, Xform(translation: V3(ux(W - T / 2), y0 + H / 2, 0), rotation: flat))
            // Laminate faces with the vision-lite cutout; grain runs up the leaf (U along Y).
            let x0 = ux(T / 2 + ext - 0.0005), x1 = ux(W - T / 2 - ext + 0.0005)
            let hc = ux(W - 0.3), hx0 = hc - gw / 2, hx1 = hc + gw / 2
            let hy0: Float = 1.45 - gh / 2, hy1 = hy0 + gh
            var lam = Surface(material: leafMaterial)
            let grain = { (p: V3) -> V2 in V2(p.y, p.x) }
            for side: Float in [1, -1] {
                let z = side * T / 2
                let rects: [(Float, Float, Float, Float)] = [(x0, hx0, y0, y1), (hx1, x1, y0, y1), (hx0, hx1, y0, hy0), (hx0, hx1, hy1, y1)]
                for (a, b, c, d) in rects {
                    if side > 0 {
                        HK.quad(&lam, V3(a, c, z), V3(b, c, z), V3(b, d, z), V3(a, d, z), uv: grain)
                    } else {
                        HK.quad(&lam, V3(b, c, z), V3(a, c, z), V3(a, d, z), V3(b, d, z), uv: grain)
                    }
                }
            }
            // Top and bottom edges of the core.
            HK.quad(&lam, V3(x0, y1, T / 2), V3(x1, y1, T / 2), V3(x1, y1, -T / 2), V3(x0, y1, -T / 2), uv: grain)
            HK.quad(&lam, V3(x0, y0, -T / 2), V3(x1, y0, -T / 2), V3(x1, y0, T / 2), V3(x0, y0, T / 2), uv: grain)
            m.add(lam)
            // Vision kit: steel sleeve lining the cutout, beveled frames on both faces, wired glass.
            var kit = Surface(material: kitMaterial)
            let t2 = T / 2
            HK.quad(&kit, V3(hx0, hy0, t2), V3(hx0, hy0, -t2), V3(hx0, hy1, -t2), V3(hx0, hy1, t2)) { V2($0.z, $0.y) }
            HK.quad(&kit, V3(hx1, hy0, -t2), V3(hx1, hy0, t2), V3(hx1, hy1, t2), V3(hx1, hy1, -t2)) { V2($0.z, $0.y) }
            HK.quad(&kit, V3(hx0, hy0, -t2), V3(hx0, hy0, t2), V3(hx1, hy0, t2), V3(hx1, hy0, -t2)) { V2($0.x, $0.z) }
            HK.quad(&kit, V3(hx0, hy1, t2), V3(hx0, hy1, -t2), V3(hx1, hy1, -t2), V3(hx1, hy1, t2)) { V2($0.x, $0.z) }
            for side: Float in [1, -1] {
                let z = side * (t2 + kitT / 2 - 0.0005)
                let br: Float = l == 0 ? 0.0022 : 0.001
                kit.append(HK.box(V3(kitW, gh + 2 * kitW, kitT), V3(hx0 - kitW / 2 + 0.001, (hy0 + hy1) / 2, z), kitMaterial, r: br, seg: 1))
                kit.append(HK.box(V3(kitW, gh + 2 * kitW, kitT), V3(hx1 + kitW / 2 - 0.001, (hy0 + hy1) / 2, z), kitMaterial, r: br, seg: 1))
                kit.append(HK.box(V3(gw - 0.002, kitW, kitT), V3(hc, hy0 - kitW / 2 + 0.001, z), kitMaterial, r: br, seg: 1))
                kit.append(HK.box(V3(gw - 0.002, kitW, kitT), V3(hc, hy1 + kitW / 2 - 0.001, z), kitMaterial, r: br, seg: 1))
                if l == 0 {
                    // Tamper-proof screws, four per frame.
                    for (sx, sy) in [(hx0 - kitW / 2, hy0 + 0.06), (hx1 + kitW / 2, hy0 + 0.06), (hx0 - kitW / 2, hy1 - 0.06), (hx1 + kitW / 2, hy1 - 0.06)] {
                        kit.append(HK.cyl(r: 0.0034, len: 0.0012, at: V3(sx + 0.001 * (sx < hc ? 1 : -1), sy, side * (t2 + kitT + 0.0001)), axis: V3(0, 0, side), mat: kitMaterial, seg: 8, bevel: 0.0002))
                    }
                }
            }
            m.add(kit)
            m.add(HK.box(V3(gw + 0.012, gh + 0.012, 0.0064), V3(hc, (hy0 + hy1) / 2, 0), "glass.clear", r: 0.0008, seg: 1))
            if l == 0 {
                m.add(HK.rect("glass.wire-mesh", center: V3(hc, (hy0 + hy1) / 2, 0), right: V3(1, 0, 0), up: .up, w: gw + 0.004, h: gh + 0.004))
            }
            // Stainless kick plates (both faces) and push plates near the meeting stile.
            let kx0 = ux(T / 2 + 0.004), kx1 = ux(W - T / 2 - 0.004)
            let ky0 = y0 + 0.006, kpT: Float = 0.0013
            let push = Prim.extrude(Shape2D.roundedRect(0.102, 0.406, radius: 0.008, segments: l == 0 ? 3 : 1), depth: 0.0015,
                                    bevel: l == 0 ? 0.0006 : 0, bevelSegments: 1, material: "metal.surgical")
            let px = ux(W - 0.105)
            for side: Float in [1, -1] {
                m.add(HK.box(V3(kx1 - kx0, kickHeight, kpT), V3((kx0 + kx1) / 2, ky0 + kickHeight / 2, side * (t2 + kpT / 2)), plateMaterial, r: 0.0006, seg: 1))
                m.add(push, Xform(translation: V3(px, pushHeight, side * (t2 + 0.00075))))
                if l == 0 {
                    for (dx, dy) in [(-0.038, -0.19), (0.038, -0.19), (-0.038, 0.19), (0.038, 0.19)] as [(Float, Float)] {
                        m.add(HK.cyl(r: 0.0032, len: 0.0007, at: V3(px + dx, pushHeight + dy, side * (t2 + 0.0017)), axis: V3(0, 0, side), mat: ss, seg: 8, bevel: 0.0002))
                    }
                    // Kick plate countersunk screws along the top edge.
                    for k in 0..<5 {
                        let sx = kx0 + 0.025 + Float(k) * (kx1 - kx0 - 0.05) / 4
                        m.add(HK.cyl(r: 0.003, len: 0.0006, at: V3(sx, ky0 + kickHeight - 0.014, side * (t2 + kpT + 0.0002)), axis: V3(0, 0, side), mat: plateMaterial, seg: 8, bevel: 0.0002))
                    }
                }
            }
            // Pivot hardware: top arm mortised in the leaf top, bottom arm and spindle into the floor closer.
            m.add(HK.box(V3(0.09, 0.0016, T - 0.01), V3(ux(0.045), y1 + 0.0008, 0), ss, r: 0.0006, seg: 1))
            m.add(HK.cyl(r: 0.0055, len: topGap - 0.0006, at: V3(pivotX, y1 + topGap / 2 - 0.0003, 0), axis: .up, mat: ss, seg: 12, bevel: 0.0005))
            m.add(HK.box(V3(0.16, 0.004, T - 0.006), V3(ux(0.08), y0 - 0.002, 0), ss, r: 0.001, seg: 1))
            m.add(HK.cyl(r: 0.009, len: y0 - 0.0045, at: V3(pivotX, 0.004 + (y0 - 0.0045) / 2, 0), axis: .up, mat: ss, seg: 14, bevel: 0.001))
            // Story: black rubber transfer from bed bumpers and cart wheels on the plates and low laminate.
            if l == 0 {
                var scuff = Surface(material: "decal.rubber-scuff")
                for side: Float in [1, -1] {
                    let n = rng.int(3...6)
                    for _ in 0..<n {
                        let len = rng.float(0.04...0.16), h = rng.float(0.003...0.011)
                        let cx = rng.float((kx0 + 0.06)...(kx1 - 0.06)), cy = rng.float((ky0 + 0.03)...(ky0 + kickHeight - 0.03))
                        let a = rng.float(-0.12...0.12)
                        HK.rect(&scuff, center: V3(cx, cy, side * (t2 + kpT + 0.0004)), right: V3(cos(a) * side, sin(a), 0), up: V3(-sin(a) * side, cos(a), 0), w: len, h: h)
                    }
                    for _ in 0..<2 {
                        let len = rng.float(0.05...0.2), h = rng.float(0.003...0.008)
                        let cx = rng.float((kx0 + 0.1)...(kx1 - 0.1)), cy = rng.float(0.36...0.48)
                        HK.rect(&scuff, center: V3(cx, cy, side * (t2 + 0.0004)), right: V3(side, 0, 0), up: .up, w: len, h: h)
                    }
                }
                m.add(scuff)
            }
            return m
        }

        rig.part("left", pivot: V3(pivotX, 0, 0), joint: .hinge(axis: .up, -100...100, duration: 1.6))
        rig.part("right", pivot: V3(-pivotX, 0, 0), joint: .hinge(axis: .up, -100...100, duration: 1.6))
        let turn = Xform(rotation: simd_quatf(degrees: 180, axis: .up))
        for l in 0..<2 {
            var lr = rng.fork(1), rr = rng.fork(2)
            rig.add(leaf(l, &lr), to: "left", lod: l)
            rig.add(leaf(l, &rr).transformed(turn), to: "right", lod: l)
        }

        groundAO(&rig, height: 0.15, floor: 0.6)
        rig.states = [RigState("closed"),
                      RigState("open-in", ["left": 90, "right": -90]),
                      RigState("open-out", ["left": -90, "right": 90]),
                      RigState("left-open", ["left": -85])]
        return rig
    }
}
