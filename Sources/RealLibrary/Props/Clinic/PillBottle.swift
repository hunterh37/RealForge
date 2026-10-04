import simd
import Foundation

/// 40 dram pharmacy vial (US amber polypropylene Rx vial class): 46 mm body, 98 mm tall with its
/// white push-and-turn child-resistant cap (50 mm, 48 grip ribs). Amber body with a rolled bead under
/// the cap, two locking lugs on the neck, a wrap-around Rx label applied slightly crooked, and
/// two-tone size 1 capsules (19.4 x 6.9 mm) inside. The cap twists (push and turn), lifts, then sets
/// down beside the vial; a spill option lays a few capsules on the table.
public struct PillBottle: RealArticulated {
    public static let id = "pill-bottle"
    public static let summary = "40 dram amber pharmacy vial with a white child-resistant push-and-turn cap, wrap-around Rx label and capsules inside."
    public static let tags = ["prop", "medical", "articulated", "handheld", "plastic", "container"]
    public static let budget = 4_900
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 22, distance: 0.32, studio: true)

    /// Vial outer radius (m).
    public var radius: Float = 0.0229
    /// Vial height without the cap (m).
    public var vialHeight: Float = 0.0905
    /// Cap outer radius (m).
    public var capRadius: Float = 0.0252
    /// Capsule body color (sRGB hex) and cap-half color.
    public var capsuleA: UInt32 = 0x2F5FA8
    public var capsuleB: UInt32 = 0xF2EFE6
    /// Capsules inside the vial.
    public var count: Int = 20
    public var vial: MaterialKey = "plastic.amber:B5651E"
    public var cap: MaterialKey = "plastic.medical"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [2.5])
        let R = radius, H = vialHeight, wall: Float = 0.0011
        let neckR = R - 0.0016, capY0 = H - 0.0105, capH: Float = 0.0175
        let matA: MaterialKey = "plastic.gloss:" + String(format: "%06X", capsuleA)
        let matB: MaterialKey = "plastic.gloss:" + String(format: "%06X", capsuleB)

        // MARK: vial (two-sided translucent shell: outer wall, rolled bead, neck, lip, inner wall)
        for l in 0..<2 {
            let sg = l == 0 ? 40 : 16
            let prof: [V2] = [
                V2(0, 0.0006), V2(R - 0.003, 0.0006), V2(R - 0.0008, 0.0012), V2(R, 0.003),
                V2(R, capY0 - 0.0022), V2(R + 0.0009, capY0 - 0.0012), V2(R + 0.0009, capY0 - 0.0002), V2(neckR, capY0 + 0.0008),
                V2(neckR, H - 0.0012), V2(neckR - 0.0004, H), V2(neckR - wall - 0.0002, H), V2(neckR - wall - 0.0004, H - 0.002),
                V2(R - wall, capY0 - 0.004), V2(R - wall, 0.0035), V2(R - wall - 0.002, 0.0022), V2(0, 0.0022),
            ]
            var m = Model(name: Self.id)
            m.add(Prim.lathe(prof, segments: sg, seamTile: 0.144, material: vial))
            // Locking lugs on the neck (hidden under the cap; they show when it is off).
            if l == 0 {
                for k in 0..<2 {
                    let a = Float(k) * .pi + 0.4
                    m.add(Prim.roundedBox(V3(0.0018, 0.0022, 0.007), radius: 0.0006, bevelSegments: 1, material: vial),
                          Xform(translation: V3(cos(a) * (neckR + 0.0006), H - 0.0045, sin(a) * (neckR + 0.0006)), rotation: simd_quatf(angle: -a, axis: .up)))
                }
            }
            rig.base[l] = m
        }

        // Wrap label: 50 mm tall, 300 degrees round, applied 1.5 degrees off level.
        let labelTilt = rng.float(-1.8...(-1.0)) * .pi / 180
        func label(_ segs: Int, _ mat: MaterialKey = "label.rx-small", y0: Float = 0.016, y1: Float = 0.068, a0: Float = 0.35, span: Float = 5.24, lift: Float = 0.0003, uv T: Float = 0.08) -> Surface {
            var s = Surface(material: mat)
            let r = R + lift
            var idx: [UInt32] = []
            for i in 0...segs {
                let u = Float(i) / Float(segs), a = a0 + span * u
                let n = V3(cos(a), 0, sin(a)), dy = sin(a) * r * labelTilt
                idx.append(s.add(V3(n.x * r, y1 + dy, n.z * r), n, V2((1 - u) * T, 0)))
                idx.append(s.add(V3(n.x * r, y0 + dy, n.z * r), n, V2((1 - u) * T, T)))
            }
            for i in 0..<segs { s.quad(idx[i * 2], idx[i * 2 + 2], idx[i * 2 + 3], idx[i * 2 + 1]) }
            s.computeTangents()
            return s
        }
        rig.base[0].add(label(40))
        rig.base[1].add(label(14))
        // Yellow auxiliary sticker ("may cause drowsiness") in the gap, overlapping the Rx label edge.
        rig.base[0].add(label(6, "label.hazard-small:F3C731", y0: 0.03, y1: 0.052, a0: -0.42, span: 0.86, lift: 0.0005, uv: 0.05))

        // MARK: capsules
        func capsule(_ segs: Int, _ lenTotal: Float, _ r: Float) -> (Surface, Surface) {
            // Axis +Y, centered. Body half (A) is longer and sits over the cap half (B).
            let h = lenTotal / 2 - r
            var pb: [V2] = [V2(0, -h - r)]
            for k in 1...3 { let t = Float(k) / 3 * .pi / 2; pb.append(V2(r * sin(t), -h - r * cos(t))) }
            pb += [V2(r, 0.0012), V2(0, 0.0012)]
            var pa: [V2] = [V2(0, -0.0004), V2(r * 0.985, -0.0004), V2(r * 0.985, h)]
            for k in 1...2 { let t = Float(k) / 3 * .pi / 2; pa.append(V2(r * 0.985 * cos(t), h + r * sin(t))) }
            pa.append(V2(0, h + r))
            return (Prim.lathe(pa, segments: segs, seamTile: 0.02, material: matA), Prim.lathe(pb, segments: segs, seamTile: 0.02, material: matB))
        }
        let cl: Float = 0.0194, cr: Float = 0.00345
        let (hiA, hiB) = capsule(6, cl, cr), (loA, loB) = capsule(4, cl, cr)
        // Pack capsules inside with rejection sampling (segment-segment clearance), layer by layer.
        struct Cap { var a: V3; var b: V3 }
        var placed: [Cap] = []
        func segDist(_ p1: V3, _ q1: V3, _ p2: V3, _ q2: V3) -> Float {
            var best = Float.greatestFiniteMagnitude
            for i in 0...6 { for j in 0...6 {
                let a = p1 + (q1 - p1) * Float(i) / 6, b = p2 + (q2 - p2) * Float(j) / 6
                best = min(best, simd_distance(a, b))
            }}
            return best
        }
        let inR = R - wall - cr - 0.0004, half = cl / 2 - cr
        var xforms: [Xform] = []
        var tries = 0
        while placed.count < count && tries < 4000 {
            tries += 1
            let layer = Float(placed.count / 6)
            let y = 0.0022 + cr + 0.0002 + layer * (cr * 1.75) + rng.float(0...0.0012)
            let yaw = rng.float(0...(2 * .pi)), tilt = rng.float(-0.35...0.35)
            let dir = simd_normalize(V3(cos(yaw), tilt, sin(yaw)))
            let c2 = V2(rng.float(-inR...inR), rng.float(-inR...inR))
            let c = V3(c2.x, y + abs(dir.y) * half, c2.y)
            let a = c - dir * half, b = c + dir * half
            if simd_length(V2(a.x, a.z)) > inR || simd_length(V2(b.x, b.z)) > inR || min(a.y, b.y) < 0.0022 + cr { continue }
            if placed.contains(where: { segDist($0.a, $0.b, a, b) < cr * 2.02 }) { continue }
            placed.append(Cap(a: a, b: b))
            xforms.append(Xform(translation: c, rotation: simd_quatf(from: .up, to: dir)))
        }
        for (i, x) in xforms.enumerated() {
            rig.base[0].add(hiA, x); rig.base[0].add(hiB, x)
            if i % 2 == 0 { rig.base[1].add(loA, x); rig.base[1].add(loB, x) }
        }

        // MARK: cap: twist (push and turn) -> lift off the neck -> set down beside the vial
        let axisPivot = V3(0, capY0, 0)
        rig.part("twist", pivot: axisPivot, joint: .hinge(axis: .up, -40...0, duration: 0.4))
        rig.part("lift", parent: "twist", pivot: axisPivot, joint: .slide(axis: .up, 0...0.03, duration: 0.35))
        let setDown = V3(0.06, -(capY0 + 0.03), -0.034)
        rig.part("cap", parent: "lift", pivot: axisPivot, joint: .slide(axis: setDown, 0...simd_length(setDown), duration: 0.6))
        let cR = capRadius, cin = cR - 0.0016, top = capY0 + capH
        for l in 0..<2 {
            let sg = l == 0 ? 48 : 20
            var c = Prim.lathe([V2(0, top - 0.0016), V2(cin - 0.0004, top - 0.0016), V2(cin, top - 0.003), V2(cin, capY0 + 0.0003),
                                V2(cin + 0.0005, capY0), V2(cR - 0.0004, capY0), V2(cR, capY0 + 0.0006), V2(cR, top - 0.0016),
                                V2(cR - 0.0007, top - 0.0003), V2(cR - 0.0016, top), V2(cR - 0.0045, top), V2(cR - 0.0052, top - 0.0004),
                                V2(0, top - 0.0004)], segments: sg, seamTile: 0.16, material: cap)
            if l == 0 {
                // 48 vertical grip ribs on the skirt.
                c.deform { p in
                    let r = simd_length(V2(p.x, p.z))
                    guard r > cR - 0.0002, p.y > capY0 + 0.001, p.y < top - 0.0012 else { return p }
                    let a = atan2(p.z, p.x), k = 1 + 0.045 * max(0, cos(a * 24)) - 0.016
                    return V3(p.x * k, p.y, p.z * k)
                }
            }
            rig.add(c, to: "cap", lods: l...l)
        }
        // Arrow and "PUSH DOWN & TURN" ring read as a slightly greyer recessed disc on top.
        rig.add(Prim.cylinder(radius: cR - 0.0058, height: 0.0003, bevel: 0.0001, segments: 32, bevelSegments: 1, material: "plastic.medical-grey"),
                Xform(translation: V3(0, top - 0.0006, 0)), to: "cap", lods: 0...0)

        // MARK: spilled capsules beside the vial (option 1)
        rig.part("spill", pivot: V3(-0.05, 0, 0), joint: .fixed, options: 2)
        var spillRng = rng.fork(9)
        for i in 0..<5 {
            let x = V3(-0.04 - spillRng.float(0...0.03), cr, spillRng.float(-0.03...0.035) + Float(i) * 0.002)
            let rot = simd_quatf(angle: spillRng.float(0...(2 * .pi)), axis: .up) * simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1))
            let xf = Xform(translation: x, rotation: rot)
            rig.add(hiA, xf, to: "spill", option: 1, lods: 0...0); rig.add(hiB, xf, to: "spill", option: 1, lods: 0...0)
            rig.add(loA, xf, to: "spill", option: 1, lods: 1...1); rig.add(loB, xf, to: "spill", option: 1, lods: 1...1)
        }

        groundAO(&rig, height: 0.02, floor: 0.6)
        rig.states = [
            RigState("closed"),
            RigState("unlocked", ["twist": -40, "lift": 0.012]),
            RigState("open", ["twist": -40, "lift": 0.03, "cap": simd_length(setDown)]),
            RigState("spilled", ["twist": -40, "lift": 0.03, "cap": simd_length(setDown)], options: ["spill": 1]),
        ]
        return rig
    }
}
