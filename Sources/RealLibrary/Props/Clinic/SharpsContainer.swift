import simd
import Foundation

/// Wall-mount 5 qt sharps container (BD / Covidien 5 quart wall class), 10.75 x 10.75 x 4.75 in:
/// tapered red polypropylene body with a moulded lip, translucent red lid with a horizontal rotating
/// "mailbox" drum (turn it to open the slot, turn back to drop), a final lock tab that folds over the
/// drum, a white wall bracket with keyhole screw slots, side arms and a bottom ledge, and a biohazard
/// label. Used syringes show dimly through the lid. Wall-mounted: the scene hangs it; base at y = 0.
public struct SharpsContainer: RealArticulated {
    public static let id = "sharps-container"
    public static let summary = "Wall-mount 5 qt red sharps container with a translucent rotating mail-drop lid, final lock tab and a white wall bracket."
    public static let tags = ["prop", "medical", "articulated", "hospital", "plastic", "container", "interior"]
    public static let budget = 5_200
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 18, distance: 0.85, studio: true)

    public var width: Float = 0.272
    public var depth: Float = 0.117
    public var body: MaterialKey = "plastic.sharps-red"
    public var lid: MaterialKey = "plastic.sharps-lid"
    public var bracket: MaterialKey = "plastic.medical"
    /// Drum turn to open the slot (degrees about X).
    public var drumOpen: Float = 173
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [4])
        let W = width, D = depth
        let backZ: Float = -0.0675, plateT: Float = 0.006
        let bz = backZ + plateT + 0.0006 + D / 2            // body center z
        let y0: Float = 0.008, lipY: Float = 0.192, lidY: Float = 0.199
        let flat = simd_quatf(degrees: -90, axis: V3(1, 0, 0))
        func outline(_ s: Float, _ seg: Int) -> [V2] { Shape2D.roundedRect(W * s, D * s + (1 - s) * 0.02, radius: 0.022 * s, segments: seg) }

        // MARK: body, lid shell, bracket
        for l in 0..<2 {
            let seg = l == 0 ? 5 : 2
            var m = Model(name: Self.id)
            // Body: tapered loft with a rounded foot and a proud moulded lip under the lid.
            let rings: [(Float, Float)] = [(0.935, 0), (0.955, 0.003), (0.965, 0.009), (1.0, lipY - 0.006), (1.012, lipY - 0.004), (1.012, lipY + 0.004), (0.985, lipY + 0.007)]
            m.add(Prim.loft(rings.map { Prim.ring(outline($0.0, seg), y: y0 + $0.1, offset: V3(0, 0, bz)) }, capStart: true, capEnd: true, material: body))
            // Lid: translucent dome from the lip up to the drum seat.
            let lr: [(Float, Float)] = [(1.016, lidY), (1.01, lidY + 0.016), (0.975, lidY + 0.036), (0.9, lidY + 0.05), (0.84, lidY + 0.053)]
            m.add(Prim.loft(lr.map { Prim.ring(outline($0.0, seg), y: $0.1, offset: V3(0, 0, bz)) }, capStart: true, capEnd: true, material: lid))
            // Wall bracket: back plate, side arms, bottom ledge.
            m.add(Prim.extrude(Shape2D.roundedRect(0.232, 0.27, radius: 0.016, segments: seg), depth: plateT, bevel: 0.0015, bevelSegments: l == 0 ? 2 : 1, material: bracket),
                  Xform(translation: V3(0, 0.017 + 0.135, backZ + plateT / 2)))
            for sx: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(0.006, 0.12, 0.05), radius: 0.0025, bevelSegments: 1, material: bracket),
                      Xform(translation: V3(sx * (W / 2 + 0.0035), 0.1, backZ + 0.026)))
            }
            m.add(Prim.roundedBox(V3(0.2, y0, 0.05), radius: 0.003, bevelSegments: 1, material: bracket),
                  Xform(translation: V3(0, y0 / 2, backZ + 0.026)))
            rig.base[l] = m
        }
        // Keyhole screw slots and screws at the top of the bracket.
        for sx: Float in [-0.075, 0.075] {
            rig.base[0].add(Prim.extrude(Shape2D.roundedRect(0.008, 0.022, radius: 0.0039, segments: 3), depth: 0.0012, bevel: 0, material: "plastic.matte:1A1A1C"),
                            Xform(translation: V3(sx, 0.262, backZ + plateT + 0.0001)))
            rig.base[0].add(Prim.cylinder(radius: 0.0048, height: 0.0025, bevel: 0.0012, segments: 12, bevelSegments: 1, material: "metal.chrome"),
                            Xform(translation: V3(sx, 0.266, backZ + plateT), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }
        // Moulded vertical grip channels on the body sides (LOD0).
        for sx: Float in [-1, 1] { for k in 0..<3 {
            rig.base[0].add(Prim.roundedBox(V3(0.003, 0.11, 0.008), radius: 0.0012, bevelSegments: 1, material: body),
                            Xform(translation: V3(sx * (W / 2 - 0.0005), 0.09, bz + 0.012 + Float(k) * 0.014)))
        }}
        // Biohazard label on the front face (UVs 0...0.08 across it).
        func quad(_ c: V3, _ w: Float, _ h: Float, _ mat: MaterialKey, _ T: Float) -> Surface {
            var s = Surface(material: mat)
            let n = V3(0, 0, 1)
            let a = s.add(c + V3(-w / 2, h / 2, 0), n, V2(0, 0)), b = s.add(c + V3(w / 2, h / 2, 0), n, V2(T, 0))
            let cc = s.add(c + V3(w / 2, -h / 2, 0), n, V2(T, T)), d = s.add(c + V3(-w / 2, -h / 2, 0), n, V2(0, T))
            s.quad(a, d, cc, b)
            s.computeTangents()
            return s
        }
        // Body front at mid height (taper: outline scale ~0.985 there).
        let frontZ = bz + (D * 0.985 + 0.015 * 0.02) / 2 + 0.0004
        rig.base[0].add(quad(V3(0, 0.11, frontZ), 0.13, 0.085, "label.hazard-small", 0.08))
        rig.base[1].add(quad(V3(0, 0.11, frontZ), 0.13, 0.085, "label.hazard-small", 0.08))

        // Printed fill line with arrow heads, and a "date opened" tape label (written on at the bedside).
        let fillY: Float = 0.168
        for l in 0..<2 {
            rig.base[l].add(Prim.roundedBox(V3(0.21, 0.0022, 0.0006), radius: 0.0002, bevelSegments: 1, material: "plastic.matte:151515"),
                            Xform(translation: V3(0, fillY, frontZ - 0.0001)))
        }
        for sx: Float in [-1, 1] {
            rig.base[0].add(Prim.extrude([V2(-0.006, 0.006), V2(0.006, 0.006), V2(0, -0.001)], depth: 0.0006, bevel: 0, material: "plastic.matte:151515"),
                            Xform(translation: V3(sx * 0.112, fillY, frontZ - 0.0001)))
        }
        rig.base[0].add(quad(V3(0.075, 0.18, frontZ + 0.0002), 0.06, 0.018, "label.supply-small", 0.04))

        // Used syringes lying under the lid (show through the translucent red).
        for i in 0..<3 {
            var r = rng.fork(i + 3)
            let c = V3(r.float(-0.04...0.04), lidY + 0.005 + Float(i) * 0.005, bz + r.float(-0.018...0.01))
            let q = simd_quatf(angle: r.float(-0.35...0.35), axis: .up) * simd_quatf(degrees: 90, axis: V3(0, 0, 1)) * simd_quatf(degrees: r.float(-6...6), axis: V3(1, 0, 0))
            rig.base[0].add(Prim.cylinder(radius: 0.0048, height: 0.058, bevel: 0.0006, segments: 8, bevelSegments: 1, material: "plastic.frosted"),
                            Xform(translation: c + q.act(V3(0, -0.03, 0)), rotation: q))
            rig.base[0].add(Prim.cylinder(radius: 0.0021, height: 0.016, bevel: 0.0004, segments: 6, bevelSegments: 1, material: "plastic.white"),
                            Xform(translation: c + q.act(V3(0, -0.045, 0)), rotation: q))
            rig.base[0].add(Prim.cylinder(radius: 0.0035, height: 0.022, bevel: 0.0008, segments: 8, bevelSegments: 1, material: "plastic.orange"),
                            Xform(translation: c + q.act(V3(0, 0.028, 0)), rotation: q))
            rig.base[0].add(Prim.cylinder(radius: 0.0062, height: 0.0016, bevel: 0.0004, segments: 8, bevelSegments: 1, material: "plastic.white"),
                            Xform(translation: c + q.act(V3(0, -0.047, 0)), rotation: q))
        }

        // MARK: rotating mail-drop drum
        let dR: Float = 0.028, dL: Float = 0.17, dY = lidY + 0.053, dZ = bz + 0.012
        rig.part("drum", pivot: V3(0, dY, dZ), joint: .hinge(axis: V3(1, 0, 0), 0...175, duration: 0.7))
        // Annular sector in (px = -z, py = y); the 80 degree slot faces down-back (inside) at rest.
        let gap: Float = -30 * .pi / 180
        func sector(_ n: Int) -> [V2] {
            var o: [V2] = []
            for k in 0...n { let a = gap + 0.7 + (2 * .pi - 1.4) * Float(k) / Float(n); o.append(V2(cos(a), sin(a)) * dR) }
            for k in 0...n { let a = gap + 0.7 + (2 * .pi - 1.4) * Float(n - k) / Float(n); o.append(V2(cos(a), sin(a)) * (dR - 0.0026)) }
            return o
        }
        let toX = simd_quatf(degrees: 90, axis: .up)
        for l in 0..<2 {
            rig.add(Prim.extrude(sector(l == 0 ? 22 : 9), depth: dL, bevel: 0.0008, bevelSegments: 1, material: lid),
                    Xform(translation: V3(0, dY, dZ), rotation: toX), to: "drum", lods: l...l)
        }
        // Drum end discs.
        for sx: Float in [-1, 1] {
            rig.add(Prim.cylinder(radius: dR - 0.001, height: 0.003, bevel: 0.0008, segments: 20, bevelSegments: 1, material: lid),
                    Xform(translation: V3(sx * (dL / 2 - 0.0015) - 0.0015, dY, dZ), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "drum")
        }
        // Cheeks holding the drum (static, translucent) and the dark throat under it.
        for sx: Float in [-1, 1] {
            rig.base[0].add(Prim.roundedBox(V3(0.014, 0.05, 0.068), radius: 0.006, bevelSegments: 2, material: lid), Xform(translation: V3(sx * (dL / 2 + 0.007), dY - 0.006, dZ)))
            rig.base[1].add(Prim.roundedBox(V3(0.014, 0.05, 0.068), radius: 0.006, bevelSegments: 1, material: lid), Xform(translation: V3(sx * (dL / 2 + 0.007), dY - 0.006, dZ)))
        }
        rig.base[0].add(Prim.roundedBox(V3(dL - 0.004, 0.003, 0.046), radius: 0.0012, bevelSegments: 1, material: "plastic.matte:1E0605"),
                        Xform(translation: V3(0, dY - 0.012, dZ)))

        // MARK: final lock tab (folds forward over the drum)
        let tp = V3(0, dY + 0.004, dZ - dR - 0.004)
        rig.part("lock", pivot: tp, joint: .hinge(axis: V3(1, 0, 0), 0...100, duration: 0.4))
        let rest = simd_quatf(degrees: -50, axis: V3(1, 0, 0))   // leaning back 40 degrees above the lid
        let tab = Prim.extrude(Shape2D.rounded([V2(-0.026, 0), V2(0.026, 0), V2(0.02, 0.046), V2(-0.02, 0.046)], radius: 0.006, segments: 3),
                               depth: 0.003, bevel: 0.0009, bevelSegments: 1, material: body)
        rig.add(tab, Xform(translation: tp, rotation: rest), to: "lock")
        // Snap hook at the tab tip.
        rig.add(Prim.roundedBox(V3(0.03, 0.006, 0.004), radius: 0.0015, bevelSegments: 1, material: body),
                Xform(translation: tp + rest.act(V3(0, 0.046, 0.002))), to: "lock", lods: 0...0)
        // Hinge barrel for the tab.
        rig.add(Prim.cylinder(radius: 0.003, height: 0.06, bevel: 0.0008, segments: 10, bevelSegments: 1, material: body),
                Xform(translation: tp + V3(-0.03, 0, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "lock")

        groundAO(&rig, height: 0.03, floor: 0.65)
        rig.states = [
            RigState("closed"),
            RigState("open", ["drum": drumOpen]),
            RigState("locked", ["lock": 100]),
        ]
        return rig
    }
}
