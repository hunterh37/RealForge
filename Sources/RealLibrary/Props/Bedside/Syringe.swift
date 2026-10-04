import simd
import Foundation

/// 10 ml luer-lock syringe (BD Luer-Lok 10 ml class) lying on its side: clear polypropylene barrel,
/// 15.9 mm OD / 14.5 mm ID, graduated 0-10 ml in 0.2 ml steps over 60.6 mm with numerals every 1 ml;
/// 34 x 22 mm finger flange; luer-lock collar with an internal thread around a 6 percent luer cone;
/// black rubber stopper with two sealing ribs and a conical face; white cross-ribbed plunger rod with
/// a seal disc and a 21 mm thumb press. The plunger slides out along the barrel axis (60.6 mm = 10 ml);
/// the saline column is a fixed part with empty / 5 ml / 10 ml options, the tip cap a second option part.
public struct Syringe: RealArticulated {
    public static let id = "syringe"
    public static let summary = "10 ml luer-lock syringe: clear graduated barrel, finger flange, black rubber stopper, white ribbed plunger rod with thumb press, luer collar and cap."
    public static let tags = ["prop", "medical", "articulated", "handheld", "hospital", "plastic", "rubber"]
    public static let budget = 4500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 32, distance: 0.22, studio: true)

    /// Barrel inside radius (m); 10 ml spans 60.6 mm at 14.5 mm bore.
    public var bore: Float = 0.00725
    /// Barrel wall (m).
    public var wall: Float = 0.0007
    /// Plunger rod and cap plastic.
    public var rodMaterial: MaterialKey = "plastic.medical:DCDFDD"
    /// Graduation print.
    public var print: MaterialKey = "plastic.matte:121212"
    public init() {}

    /// Barrel length per ml (m).
    var mlLength: Float { 1e-6 / (.pi * bore * bore) }

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [2.5])
        let ri = bore, ro = bore + wall
        let clear: MaterialKey = "plastic.syringe-barrel", stopperMat: MaterialKey = "rubber.tubing:0C0C0D"
        let zeroS: Float = 0.0775                     // stopper face at 0 ml
        let full = 10 * mlLength                       // 60.6 mm
        // Local frame: syringe axis +X (tip), flange at s = 0. Lathe +Y -> +X.
        let qAx = simd_quatf(degrees: -90, axis: V3(0, 0, 1))
        // Lie it down: rests on the bottom of the flange and the front of the barrel.
        let flangeHalf: Float = 0.011
        let tilt = atan((flangeHalf - ro) / 0.079)
        let qS = simd_quatf(angle: -tilt, axis: V3(0, 0, 1))
        let lift = flangeHalf * cos(tilt)
        let S = Xform(translation: V3(-0.042, lift, 0), rotation: qS)
        func at(_ x: Xform) -> Xform { x.then(S) }
        func ax(_ s: Float) -> Xform { at(Xform(translation: V3(s, 0, 0), rotation: qAx)) }

        for l in 0..<2 {
            let sg = l == 0 ? 28 : 14
            var m = Model(name: Self.id)
            // Barrel: one closed wall profile (outer up, tip, bore back down).
            let barrel: [V2] = [V2(ri, 0.0006), V2(ro - 0.0002, 0.0002), V2(ro, 0.0012), V2(ro, 0.0785), V2(ro - 0.0012, 0.0812), V2(0.0042, 0.0826),
                                V2(0.0026, 0.0832), V2(0.0021, 0.0925), V2(0.0011, 0.0925), V2(0.0011, 0.0834), V2(0.0036, 0.0822), V2(ri - 0.0004, 0.0798), V2(ri, 0.0788), V2(ri, 0.0007)]
            m.add(Prim.lathe(barrel, segments: sg, seamTile: 0.05, material: clear), ax(0))
            // Luer-lock collar: ring with a rounded lip, thread inside.
            m.add(Prim.lathe([V2(0.0047, 0.0918), V2(0.0050, 0.0921), V2(0.0055, 0.0918), V2(0.0055, 0.0826), V2(0.0050, 0.0818)], segments: sg, seamTile: 0.05, material: clear), ax(0))
            if l == 0 {
                m.add(Prim.lathe([V2(0.0055, 0.0918), V2(0.0047, 0.0918), V2(0.0047, 0.0825)], segments: sg, seamTile: 0.05, material: clear), ax(0))
                m.add(Prim.helix(radius: 0.00475, pitch: 0.0024, turns: 2.4, wire: 0.00028, perTurn: 12, sides: 3, material: clear), ax(0.0838))
            }
            // Finger flange: 34 x 22 mm rounded plate with flats top and bottom.
            let fl = Shape2D.rounded([V2(-0.017, -0.0072), V2(-0.0125, -flangeHalf), V2(0.0125, -flangeHalf), V2(0.017, -0.0072),
                                      V2(0.017, 0.0072), V2(0.0125, flangeHalf), V2(-0.0125, flangeHalf), V2(-0.017, 0.0072)], radius: 0.0045, segments: l == 0 ? 3 : 1)
            m.add(Prim.extrude(fl, depth: 0.0022, bevel: 0.0005, bevelSegments: 1, material: clear),
                  at(Xform(translation: V3(-0.0011 + 0.0002, 0, 0), rotation: simd_quatf(degrees: 90, axis: .up))))
            // Graduations: printed on the upper front of the barrel, reading tip-up.
            var g = Surface(material: print)
            let phiC: Float = 1.0                      // radians from +Y toward +Z: print faces up and toward the viewer
            let rp = ro + 0.00004
            func onBarrel(_ s: Float, _ phi: Float, _ dr: Float = 0) -> V3 { V3(s, (rp + dr) * cos(phi), (rp + dr) * sin(phi)) }
            let step = l == 0 ? 1 : 5
            for k in stride(from: 0, through: 50, by: step) {
                let s = zeroS - Float(k) * 0.2 * mlLength
                let major = k % 5 == 0, half = k % 5 != 0 && k % 5 == 0
                _ = half
                let span: Float = major ? 0.55 : 0.28, w: Float = major ? 0.00022 : 0.00016
                let segs = major ? 4 : 2
                let p0 = phiC - span / 2
                let base = UInt32(g.positions.count)
                for j in 0...segs {
                    let phi = p0 + span * Float(j) / Float(segs)
                    let n = V3(0, cos(phi), sin(phi))
                    _ = g.add(onBarrel(s - w, phi), n, V2(0, 0)); _ = g.add(onBarrel(s + w, phi), n, V2(1, 0))
                }
                for j in 0..<UInt32(segs) { let a = base + j * 2; g.quad(a, a + 2, a + 3, a + 1) }
            }
            if l == 0 {
                // Numerals every 1 ml beside the major lines (glyph up toward the tip).
                for ml in 1...10 {
                    let s = zeroS - Float(ml) * mlLength
                    let phi = phiC + 0.38
                    let n = V3(0, cos(phi), sin(phi)), tang = V3(0, -sin(phi), cos(phi))
                    let o = onBarrel(s, phi, 0.00016)
                    g.append(BedsideKit.segments(String(ml), origin: o - V3(0.0011, 0, 0), u: tang, v: V3(1, 0, 0), height: 0.0022, stroke: 0.16, shear: 0,
                                                 centered: true, material: print))
                    _ = n
                }
                // "ml" and maker caption along the barrel.
                let phiT = phiC - 0.55
                let nT = V3(0, cos(phiT), sin(phiT)), tT = V3(0, -sin(phiT), cos(phiT))
                g.append(BedsideKit.caption([2], origin: onBarrel(zeroS - 0.004, phiC + 0.42, 0.00016), u: V3(0, -sin(phiC + 0.42), cos(phiC + 0.42)), v: V3(1, 0, 0), height: 0.0016, material: print))
                g.append(BedsideKit.caption([2, 6], origin: onBarrel(0.012, phiT, 0.0001) + tT * 0.0008, u: V3(1, 0, 0), v: -tT, height: 0.0018, material: print))
                _ = nT
            }
            g.computeTangents()
            m.add(g, S)
            // Story detail: a hand-applied drug label wrapped on the back of the barrel, slightly skewed.
            var lab = Surface(material: "label.bedside-drug")
            let ls = l == 0 ? 6 : 3
            for j in 0...ls {
                let f = Float(j) / Float(ls), phi: Float = -0.3 - 1.7 * f
                let n = V3(0, cos(phi), sin(phi))
                let r = ro + 0.0001, skew = 0.0012 * f
                _ = lab.add(V3(0.031 + skew, r * cos(phi), r * sin(phi)), n, V2(f, 0))
                _ = lab.add(V3(0.055 + skew, r * cos(phi), r * sin(phi)), n, V2(f, 1))
            }
            for j in 0..<UInt32(ls) { let a = j * 2; lab.quad(a, a + 1, a + 3, a + 2) }
            lab.computeTangents()
            m.add(lab, S)
            rig.base[l] = m
        }

        // MARK: plunger (stopper + rod + thumb press) slides out along the axis.
        rig.part("plunger", pivot: S.point(V3(0.03, 0, 0)), joint: .slide(axis: qS.act(V3(-1, 0, 0)), 0...full, duration: 0.9))
        for l in 0..<2 {
            let sg = l == 0 ? 24 : 12
            // Stopper: conical face, two sealing ribs, a relief groove, back skirt.
            let st: [V2] = [V2(0, zeroS), V2(0.0028, zeroS - 0.0006), V2(ri - 0.0012, zeroS - 0.0022), V2(ri - 0.0002, zeroS - 0.0028), V2(ri + 0.00005, zeroS - 0.0036),
                            V2(ri - 0.0003, zeroS - 0.0043), V2(ri - 0.0006, zeroS - 0.0048), V2(ri - 0.0003, zeroS - 0.0053), V2(ri + 0.00005, zeroS - 0.0061),
                            V2(ri - 0.0002, zeroS - 0.0069), V2(ri - 0.0012, zeroS - 0.0078), V2(0, zeroS - 0.0078)].reversed()
            rig.add(Prim.lathe(st, segments: sg, seamTile: 0.03, material: stopperMat), ax(0), to: "plunger", lods: l...l)
            // Seal disc behind the stopper and thumb press.
            rig.add(Prim.cylinder(radius: ri - 0.0007, height: 0.0011, bevel: 0.0003, segments: sg, bevelSegments: 1, material: rodMaterial), ax(zeroS - 0.0098), to: "plunger", lods: l...l)
            rig.add(Prim.cylinder(radius: 0.0105, height: 0.0016, bevel: 0.0006, segments: sg, bevelSegments: l == 0 ? 2 : 1, material: rodMaterial), ax(-0.0083), to: "plunger", lods: l...l)
        }
        // Cross-ribbed rod from the thumb press to the seal disc.
        let vane: Float = 0.0006, span: Float = ri - 0.0009
        let cross = Shape2D.rounded([V2(vane, vane), V2(span, vane), V2(span, -vane), V2(vane, -vane), V2(vane, -span), V2(-vane, -span), V2(-vane, -vane),
                                     V2(-span, -vane), V2(-span, vane), V2(-vane, vane), V2(-vane, span), V2(vane, span)], radius: 0.0003, segments: 1)
        let rodLen = zeroS - 0.0098 - (-0.0083 + 0.0016) + 0.0004
        rig.add(Prim.extrude(cross, depth: rodLen, bevel: 0.0002, bevelSegments: 1, material: rodMaterial),
                at(Xform(translation: V3(-0.0067 + rodLen / 2 - 0.0002, 0, 0), rotation: simd_quatf(degrees: 90, axis: .up) * simd_quatf(degrees: 45, axis: V3(0, 0, 1)))), to: "plunger")

        // MARK: saline column (fixed part, options: empty / 5 ml / 10 ml)
        rig.part("fluid", pivot: S.point(.zero), joint: .fixed, options: 3)
        for (opt, ml) in [(1, Float(5)), (2, Float(10))] {
            let back = zeroS - ml * mlLength
            let prof: [V2] = [V2(0, back - 0.0004), V2(ri - 0.00008, back), V2(ri - 0.00008, 0.0787), V2(0.0036, 0.0821), V2(0.0010, 0.0833), V2(0.0010, 0.0922), V2(0, 0.0922)]
            rig.add(Prim.lathe(prof, segments: 20, seamTile: 0.05, material: "fluid.drawn"), ax(0), to: "fluid", option: opt)
            // Story detail: a small air bubble caught under the upper wall near the tip.
            rig.add(Prim.superellipsoid(V3(0.0026, 0.0016, 0.0022), exponent: 2, subdivisions: 3, material: "plastic.syringe-barrel"),
                    at(Xform(translation: V3(zeroS - 0.006 - Float(opt) * 0.004, ri - 0.0010, 0.0012))), to: "fluid", option: opt)
        }

        // MARK: luer tip cap (option)
        rig.part("cap", pivot: S.point(V3(0.095, 0, 0)), joint: .fixed, options: 2)
        var capProf: [V2] = [V2(0.0049, 0.0905), V2(0.0058, 0.0903), V2(0.0061, 0.0912), V2(0.0058, 0.1005), V2(0.0050, 0.1035), V2(0.0042, 0.1043)]
        capProf.append(V2(0, 0.1043))
        rig.add(Prim.lathe(capProf, segments: 18, seamTile: 0.05, material: rodMaterial), ax(0), to: "cap", option: 1)
        var ribs = Surface(material: rodMaterial)
        for k in 0..<6 {
            let a = Float(k) / 6 * 2 * .pi
            ribs.append(Prim.roundedBox(V3(0.0085, 0.0009, 0.0012), radius: 0.0003, bevelSegments: 1, material: rodMaterial),
                        Xform(translation: V3(0.0958, cos(a) * 0.0062, sin(a) * 0.0062), rotation: simd_quatf(angle: a, axis: V3(1, 0, 0))))
        }
        rig.add(ribs, S, to: "cap", option: 1)

        groundAO(&rig, height: 0.006, floor: 0.7)
        rig.states = [
            RigState("empty"),
            RigState("drawn-5ml", ["plunger": 5 * mlLength], options: ["fluid": 1]),
            RigState("full", ["plunger": full], options: ["fluid": 2]),
            RigState("capped", ["plunger": full], options: ["fluid": 2, "cap": 1]),
        ]
        return rig
    }
}
