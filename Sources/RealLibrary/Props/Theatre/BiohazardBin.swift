import simd
import Foundation

/// 23 gal (87 L) step-on medical waste can (Rubbermaid step-on medical container class), 42 x 53 x 83 cm:
/// tapered rectangular red resin body with a rolled top lip and molded base band, red LDPE liner bag
/// folded over the rim, hinged lid with a rear hinge housing, black foot pedal at the front base with a
/// ribbed tread. The pedal drives the lid through a rod in the rear channel (lid mimics pedal). A printed
/// black biohazard symbol and a warning placard sit on the front; the pedal tread is scuffed grey.
public struct BiohazardBin: RealArticulated {
    public static let id = "biohazard-bin"
    public static let summary = "23 gallon red step-on biohazard waste can: molded resin body, hinged lid lifted by a foot pedal, red liner rim and a biohazard label."
    public static let tags = ["prop", "medical", "hospital", "surgical", "articulated", "container", "plastic"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 16, distance: 1.25, studio: true)

    /// Body resin color (sRGB hex).
    public var color: UInt32 = 0xB01E1A
    /// Liner bag color (sRGB hex).
    public var liner: UInt32 = 0xC2241F
    /// Body width (x) and depth (z) at the lip, height to the lip (m).
    public var width: Float = 0.41
    public var depth: Float = 0.47
    public var height: Float = 0.762
    /// Lid opening at full pedal travel (degrees).
    public var lidOpen: Float = 72
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [6])
        let resin: MaterialKey = "plastic.resin-red:" + String(format: "%06X", color)
        let bag: MaterialKey = "plastic.gloss:" + String(format: "%06X", liner)
        let black: MaterialKey = "plastic.matte:1E1E20"
        let W = width, D = depth, H = height
        let segs = [6, 2]
        // Wall: base band 0.37 x 0.43 at 35 mm, flaring to 0.395 x 0.455 under the lip.
        let yb: Float = 0.035, yt = H - 0.022
        let wb = W - 0.04, db = D - 0.04, wt = W - 0.015, dt = D - 0.015
        func wallW(_ y: Float) -> Float { wb + (wt - wb) * (y - yb) / (yt - yb) }
        func wallD(_ y: Float) -> Float { db + (dt - db) * (y - yb) / (yt - yb) }
        let slope = atan((dt - db) / 2 / (yt - yb))      // front face lean (radians)
        func ring(_ w: Float, _ d: Float, _ y: Float, _ l: Int, r: Float = 0.05) -> [V3] {
            Prim.ring(Shape2D.roundedRect(w, d, radius: r, segments: segs[l]), y: y)
        }

        let phase = rng.float(0...6.28)
        for l in 0..<2 {
            var m = Model(name: Self.id)
            // Body shell: foot, base band step, tapered wall, rolled lip, inner wall going down under the liner.
            let rings: [[V3]] = [
                ring(wb - 0.012, db - 0.012, 0, l, r: 0.044), ring(wb - 0.002, db - 0.002, 0.006, l, r: 0.048),
                ring(wb + 0.004, db + 0.004, 0.03, l), ring(wb, db, yb + 0.004, l),
                ring(wallW(yt), wallD(yt), yt, l), ring(W - 0.004, D - 0.004, yt + 0.008, l, r: 0.052),
                ring(W, D, H - 0.008, l, r: 0.054), ring(W - 0.006, D - 0.006, H, l, r: 0.052),
                ring(W - 0.016, D - 0.016, H - 0.004, l, r: 0.048), ring(W - 0.022, D - 0.022, H - 0.02, l, r: 0.046),
                ring(wallW(H - 0.14) - 0.012, wallD(H - 0.14) - 0.012, H - 0.14, l, r: 0.044),
            ]
            m.add(Prim.loft(rings, capStart: true, material: resin))
            // Rear hinge bosses either side of the lid knuckle.
            for sx: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(0.05, 0.034, 0.03), radius: 0.008, bevelSegments: l == 0 ? 2 : 0, material: resin),
                      Xform(translation: V3(sx * 0.12, H - 0.006, -D / 2 - 0.006)))
            }
            // Rod channel down the back, leaning with the wall.
            let ch = yt - 0.09
            m.add(Prim.roundedBox(V3(0.05, ch, 0.016), radius: 0.006, bevelSegments: l == 0 ? 2 : 1, material: resin),
                  Xform(translation: V3(0, 0.06 + ch / 2, -(wallD(0.06 + ch / 2) / 2) - 0.004), rotation: simd_quatf(angle: slope, axis: V3(1, 0, 0))))
            // Pedal housing: black molded pocket at the front base.
            m.add(Prim.roundedBox(V3(0.27, 0.05, 0.03), radius: 0.01, bevelSegments: l == 0 ? 2 : 1, material: black),
                  Xform(translation: V3(0, 0.035, db / 2 - 0.008)))
            // Liner bag: inside the body, over the lip and hanging outside with soft folds.
            var lr: [[V3]] = [ring(W - 0.12, D - 0.12, 0.16, l, r: 0.04), ring(wallW(0.2) - 0.035, wallD(0.2) - 0.035, 0.2, l, r: 0.04),
                              ring(wallW(H - 0.2) - 0.035, wallD(H - 0.2) - 0.035, H - 0.2, l, r: 0.04), ring(W - 0.022, D - 0.022, H - 0.004, l, r: 0.046),
                              ring(W - 0.004, D - 0.004, H + 0.0035, l, r: 0.054), ring(W + 0.008, D + 0.008, H - 0.012, l, r: 0.058)]
            let hang: Float = 0.085
            lr.append(ring(W + 0.012, D + 0.012, H - 0.012 - hang, l, r: 0.06))
            var bagS = Prim.loft(lr, capStart: true, material: bag)
            bagS.displace { p, n in
                guard p.y < H - 0.015 && p.y > H - 0.13 else { return 0 }
                let a = atan2(p.z, p.x)
                let k = (H - 0.015 - p.y) / hang
                return 0.008 * k * sin(a * 17 + phase) + 0.004 * k * sin(a * 31 + phase * 2) + 0.002 * sin(a * 53)
            }
            m.add(bagS)
            m.add(bagS.flipped())
            rig.base[l] = m
        }

        // Printed biohazard symbol on the front, black, following the wall lean.
        let symY: Float = 0.6, symR: Float = 0.078
        let symZ = wallD(symY) / 2 + 0.0006
        let symX = Xform(translation: V3(0, symY, symZ), rotation: simd_quatf(angle: slope, axis: V3(1, 0, 0)))
        rig.base[0].add(biohazardSymbol(radius: symR, material: black), symX)
        rig.base[1].add(biohazardSymbol(radius: symR, material: black, segments: 8), symX)
        // Center hole of the trefoil shows the body color.
        let hole = Prim.cylinder(radius: symR * 6 / 27, height: 0.0004, bevel: 0.0001, segments: 20, bevelSegments: 1, material: resin)
        for l in 0..<2 { rig.base[l].add(hole, Xform(translation: symX.point(V3(0, 0, 0.0007)), rotation: symX.rotation * simd_quatf(degrees: 90, axis: V3(1, 0, 0)))) }
        // Warning placard (label.hazard: red band and text, UV v down the label).
        do {
            var s = Surface(material: "label.hazard")
            let lw: Float = 0.27, y0: Float = 0.3, y1: Float = 0.47
            let n = V3(0, sin(slope), cos(slope))
            func p(_ x: Float, _ y: Float) -> V3 { V3(x, y, wallD(y) / 2 + 0.0007) }
            let a = s.add(p(-lw / 2, y1), n, V2(0, 0)), b = s.add(p(lw / 2, y1), n, V2(1, 0))
            let c = s.add(p(lw / 2, y0), n, V2(1, 1)), d = s.add(p(-lw / 2, y0), n, V2(0, 1))
            s.quad(a, d, c, b)
            s.computeTangents()
            for l in 0..<2 { rig.base[l].add(s) }
        }
        // Molded hand grips under the lip on both sides.
        for sx: Float in [-1, 1] {
            let gy = H - 0.075
            for l in 0..<2 {
                rig.base[l].add(Prim.roundedBox(V3(0.014, 0.03, 0.17), radius: 0.006, bevelSegments: 1, material: resin),
                                Xform(translation: V3(sx * (wallW(gy) / 2 + 0.004), gy, 0), rotation: simd_quatf(angle: -sx * slope * 0.9, axis: V3(0, 0, 1))))
            }
        }
        // Shoe scuffs on the lower front around the pedal (rubber marks, a fraction of a millimeter proud).
        var scuffs = Surface(material: "rubber.tubing:4A4644")
        for k in 0..<7 {
            let y = rng.float(0.07...0.2), x = rng.float(-0.15...0.15), len = rng.float(0.015...0.05)
            let ang = rng.float(-25...25)
            scuffs.append(Prim.card(width: len, height: rng.float(0.0015...0.004), cell: (V2(0, 0), V2(len, 0.004)), material: "rubber.tubing:4A4644"),
                          Xform(translation: V3(x, y, wallD(y) / 2 + 0.0002 + Float(k) * 0.00004),
                                rotation: simd_quatf(angle: slope, axis: V3(1, 0, 0)) * simd_quatf(degrees: ang, axis: V3(0, 0, 1))))
        }
        rig.base[0].add(scuffs)
        // Molded "STEP" arrow bead above the pedal (LOD0).
        rig.base[0].add(Prim.extrude([V2(-0.02, 0), V2(0.02, 0), V2(0, -0.016)], depth: 0.002, bevel: 0.0006, bevelSegments: 1, material: black),
                        Xform(translation: V3(0, 0.1, wallD(0.1) / 2 + 0.0008), rotation: simd_quatf(angle: slope, axis: V3(1, 0, 0))))

        // Pedal: axis +X through the housing, positive presses the front down.
        let pz = db / 2 - 0.004, py: Float = 0.036
        rig.part("pedal", pivot: V3(0, py, pz), joint: .hinge(axis: V3(1, 0, 0), 0...14, duration: 0.3))
        let tongue = Shape2D.rounded([V2(-0.12, 0), V2(0.12, 0), V2(0.11, 0.07), V2(-0.11, 0.07)], radius: 0.014, segments: 3)
        for l in 0..<2 {
            rig.add(Prim.extrude(tongue, depth: 0.014, bevel: 0.004, bevelSegments: l == 0 ? 2 : 1, material: black),
                    Xform(translation: V3(0, py - 0.002, pz - 0.012), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "pedal", lods: l...l)
        }
        // Ribbed tread worn grey at the front edge.
        var ribs = Surface(material: "rubber")
        for k in 0..<5 {
            let z = pz + 0.008 + Float(k) * 0.011
            ribs.append(Prim.roundedBox(V3(0.19 - (k == 4 ? 0.01 : 0), 0.004, 0.005), radius: 0.0018, bevelSegments: 1, material: "rubber"),
                        Xform(translation: V3(0, py + 0.0065, z)))
        }
        rig.add(ribs, to: "pedal", lods: 0...0)
        rig.add(Prim.roundedBox(V3(0.17, 0.0012, 0.022), radius: 0.0005, bevelSegments: 1, material: "plastic.matte:6A6A6C"),
                Xform(translation: V3(0, py + 0.0052, pz + 0.05)), to: "pedal", lods: 0...0)

        // Lid: domed shell with a skirt over the lip; hinge knuckle at the back.
        let hy = H + 0.012, hz = -D / 2 - 0.01
        rig.part("lid", pivot: V3(0, hy, hz), joint: Joint(.revolute, axis: V3(1, 0, 0), range: -lidOpen...0, duration: 0.6,
                                                         mimic: .init("pedal", ratio: -lidOpen / 14)))
        let lw = W + 0.014, ld = D + 0.014
        for l in 0..<2 {
            let lr: [[V3]] = [
                ring(0.06, 0.06, H + 0.026, l, r: 0.02), ring(lw - 0.03, ld - 0.03, H + 0.026, l),
                ring(lw - 0.008, ld - 0.008, H + 0.018, l, r: 0.054), ring(lw - 0.008, ld - 0.008, H - 0.022, l, r: 0.054),
                ring(lw, ld, H - 0.024, l, r: 0.058), ring(lw + 0.002, ld + 0.002, H + 0.03, l, r: 0.06),
                ring(lw - 0.008, ld - 0.008, H + 0.05, l, r: 0.056), ring(lw - 0.06, ld - 0.06, H + 0.064, l, r: 0.04),
                ring(lw - 0.16, ld - 0.16, H + 0.069, l, r: 0.03), ring(0.06, 0.06, H + 0.07, l, r: 0.02),
            ]
            rig.add(Prim.loft(lr, capStart: true, capEnd: true, material: resin),
                    Xform.identity.jittered(&rng, deg: 0.08, offset: 0.0003), to: "lid", lods: l...l)
        }
        rig.add(Prim.roundedBox(V3(0.17, 0.026, 0.026), radius: 0.009, bevelSegments: 2, material: resin),
                Xform(translation: V3(0, hy, hz)), to: "lid")
        rig.add(Prim.cylinder(radius: 0.004, height: 0.29, bevel: 0.001, segments: 8, bevelSegments: 1, material: "metal.stainless"),
                Xform(translation: V3(-0.145, hy, hz), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "lid", lods: 0...0)
        // Front lid lip for a hand lift.
        rig.add(Prim.roundedBox(V3(0.12, 0.008, 0.018), radius: 0.003, bevelSegments: 1, material: resin),
                Xform(translation: V3(0, H - 0.02, ld / 2 + 0.006)), to: "lid")

        groundAO(&rig, height: 0.1, floor: 0.55)
        rig.states = [RigState("closed"), RigState("open", ["pedal": 14])]
        return rig
    }
}

/// Flat biohazard trefoil in the local XY plane (facing +Z, 1 mm thick): three crescents (outer circle minus an
/// offset inner circle), the center hole ring and the broken circle through the arms.
func biohazardSymbol(radius R: Float, material: MaterialKey, segments n: Int = 24) -> Surface {
    var s = Surface(material: material)
    let u = R / 27                                          // symbol unit (outer tip at 27 u)
    let t: Float = 0.001
    func circle(_ c: V2, _ r: Float, _ a0: Float, _ a1: Float, _ k: Int) -> [V2] {
        (0...k).map { i in let a = a0 + (a1 - a0) * Float(i) / Float(k); return c + V2(cos(a), sin(a)) * r }
    }
    for arm in 0..<3 {
        let dir = Float(arm) * 2 * .pi / 3 + .pi / 2
        let ax = V2(cos(dir), sin(dir))
        let c1 = ax * 11 * u, r1 = 15 * u, c2 = ax * 17 * u, r2 = 10 * u
        // Intersections of the two circles (symmetric about the arm axis).
        let d: Float = 6 * u
        let a = (r1 * r1 - r2 * r2 + d * d) / (2 * d)
        let h = sqrt(max(0, r1 * r1 - a * a))
        let pm = c1 + ax * a
        let perp = V2(-ax.y, ax.x)
        let p = pm + perp * h, q = pm - perp * h
        let ap1 = atan2(p.y - c1.y, p.x - c1.x), aq1 = atan2(q.y - c1.y, q.x - c1.x)
        let ap2 = atan2(p.y - c2.y, p.x - c2.x), aq2 = atan2(q.y - c2.y, q.x - c2.x)
        // Outer arc on circle 1 from p round the inner side to q, then back along circle 2 from q to p.
        var e1 = aq1; while e1 <= ap1 { e1 += 2 * .pi }
        var e2 = ap2; while e2 >= aq2 { e2 -= 2 * .pi }
        var outline = circle(c1, r1, ap1, e1, n)
        outline += circle(c2, r2, aq2, e2, n / 2).dropFirst().dropLast()
        let shape = Shape2D.deduped(outline)
        s.append(Prim.extrude(shape, depth: t, bevel: 0.0002, bevelSegments: 1, material: material),
                 Xform(translation: V3(0, 0, Float(arm) * 0.00005)))
    }
    // Center hole: body-colored disk is not used; a ring of the symbol color frames a dark hole instead.
    let ring = Prim.torus(major: 11.5 * u, minor: 1.6 * u, segments: n * 2, sides: 4, minorY: 0.0004, material: material)
    s.append(ring, Xform(translation: V3(0, 0, 0.0002), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
    return s
}
