import simd
import Foundation

/// E-size medical oxygen cylinder (aluminium E, 4.38 in x 25.6 in, 680 L) with a CGA 870 post valve
/// and a yoke-mount click-style regulator: satin aluminium body standing in a black rubber boot,
/// US-green painted shoulder with chipped edges, white USP oxygen label, chromed brass post valve with
/// a square stem, yoke with a black T-screw, regulator with a contents gauge (needle rises with the
/// valve), a top flow selector dial and a barbed outlet, and a T-handle valve key on the stem.
public struct OxygenCylinder: RealArticulated {
    public static let id = "oxygen-cylinder"
    public static let summary = "E-size medical oxygen cylinder: aluminium body, green shoulder, post-valve regulator with flowmeter dial and contents gauge, T-handle key, base ring."
    public static let tags = ["prop", "medical", "articulated", "handheld", "metal", "hospital"]
    public static let budget = 6_400
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 14, distance: 1.5, studio: true)

    public var radius: Float = 0.0556
    /// Body height to the top of the neck (m).
    public var bodyHeight: Float = 0.672
    public var body: MaterialKey = "metal.satin-aluminum"
    public var shoulder: MaterialKey = "paint.cylinder-green"
    /// Valve key turn when open (degrees) and the flow dial setting for 2 L/min (degrees).
    public var keyOpen: Float = 300
    public var flowOpen: Float = 72
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3])
        let R = radius, H = bodyHeight
        let neckR: Float = 0.0165, shY0: Float = 0.545
        let chrome: MaterialKey = "metal.chrome", black: MaterialKey = "plastic.matte:1D1E20"
        let regMat: MaterialKey = "metal.anodized"

        // MARK: cylinder, shoulder paint, boot, label
        for l in 0..<2 {
            let sg = l == 0 ? 40 : 16
            var m = Model(name: Self.id)
            // Aluminium body: domed base, straight wall, shoulder to the neck.
            var prof: [V2] = [V2(0, 0.012), V2(R * 0.55, 0.008), V2(R - 0.012, 0.006), V2(R - 0.003, 0.012), V2(R, 0.024), V2(R, shY0)]
            let shoulderPts = (1...(l == 0 ? 9 : 4)).map { k -> V2 in
                let t = Float(k) / Float(l == 0 ? 9 : 4)
                let a = t * .pi / 2
                return V2(neckR + (R - neckR) * cos(a), shY0 + (H - 0.03 - shY0) * sin(a))
            }
            prof += shoulderPts
            prof += [V2(neckR, H - 0.004), V2(neckR - 0.001, H), V2(0, H)]
            m.add(Prim.lathe(prof, segments: sg, seamTile: 0.35, material: body))
            // Green shoulder paint: a skin over the shoulder, ending at a chipped line on the wall.
            var paint: [V2] = [V2(R + 0.0003, shY0 - 0.022), V2(R + 0.0004, shY0)]
            paint += shoulderPts.map { V2($0.x + 0.0004, $0.y + 0.0002) }
            paint += [V2(neckR + 0.0004, H - 0.006)]
            m.add(Prim.lathe(paint, segments: sg, seamTile: 0.35, material: shoulder))
            // Black rubber boot.
            m.add(Prim.lathe([V2(0, 0.0005), V2(R + 0.001, 0), V2(R + 0.0035, 0.004), V2(R + 0.0035, 0.032), V2(R + 0.0015, 0.036), V2(R - 0.0002, 0.036)],
                             segments: sg, seamTile: 0.2, material: "rubber"))
            rig.base[l] = m
        }
        // USP oxygen label wrapped on the front (UVs 0...0.08 across it).
        func wrap(_ segs: Int) -> Surface {
            var s = Surface(material: "label.oxygen-small")
            let r = R + 0.0003, y0: Float = 0.36, y1: Float = 0.47, a0: Float = .pi / 2 - 1.05, span: Float = 2.1
            var idx: [UInt32] = []
            for i in 0...segs {
                let u = Float(i) / Float(segs), a = a0 + span * u, n = V3(cos(a), 0, sin(a))
                idx.append(s.add(V3(n.x * r, y1, n.z * r), n, V2((1 - u) * 0.08, 0)))
                idx.append(s.add(V3(n.x * r, y0, n.z * r), n, V2((1 - u) * 0.08, 0.08)))
            }
            for i in 0..<segs { s.quad(idx[i * 2], idx[i * 2 + 2], idx[i * 2 + 3], idx[i * 2 + 1]) }
            s.computeTangents()
            return s
        }
        rig.base[0].add(wrap(16)); rig.base[1].add(wrap(6))
        // Paint chips on the shoulder edge (aluminium showing through): a few small patches.
        for _ in 0..<4 {
            let a = rng.float(0...(2 * .pi)), y = shY0 + rng.float(0.01...0.07)
            let rr = R - (y - shY0) * 0.08 + 0.0008
            let n = V3(cos(a), 0.15, sin(a))
            rig.base[0].add(Prim.superellipsoid(V3(rng.float(0.005...0.011), 0.0006, rng.float(0.004...0.008)), exponent: 3.5, subdivisions: 2, material: "metal.satin-aluminum:9A9C9E"),
                            Xform(translation: V3(cos(a) * rr, y, sin(a) * rr), rotation: facing(n)))
        }

        // MARK: post valve, yoke, regulator body
        let vy = H + 0.03                              // valve body center
        for l in 0..<2 {
            let bev: Float = l == 0 ? 0.003 : 0.002, bs = 1
            rig.base[l].add(Prim.cylinder(radius: 0.0175, height: 0.012, bevel: 0.002, segments: l == 0 ? 20 : 10, bevelSegments: 1, material: chrome),
                            Xform(translation: V3(0, H - 0.002, 0)))
            rig.base[l].add(Prim.roundedBox(V3(0.03, 0.05, 0.032), radius: bev, bevelSegments: bs, material: chrome), Xform(translation: V3(0, vy, 0)))
            // Yoke frame around the valve (anodized), regulator body on +X, T-screw on -X.
            rig.base[l].add(Prim.roundedBox(V3(0.01, 0.058, 0.03), radius: bev, bevelSegments: bs, material: regMat), Xform(translation: V3(-0.022, vy, 0)))
            for sz: Float in [-1, 1] {
                rig.base[l].add(Prim.roundedBox(V3(0.058, 0.036, 0.004), radius: 0.0015, bevelSegments: 1, material: regMat), Xform(translation: V3(0.006, vy + 0.004, sz * 0.0185)))
            }
            rig.base[l].add(Prim.roundedBox(V3(0.048, 0.068, 0.046), radius: 0.008, bevelSegments: bs, material: regMat), Xform(translation: V3(0.042, vy + 0.002, 0)))
            // T-screw.
            rig.base[l].add(Prim.cylinder(radius: 0.004, height: 0.02, bevel: 0.0008, segments: 10, bevelSegments: 1, material: chrome),
                            Xform(translation: V3(-0.027, vy, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
            rig.base[l].add(Prim.roundedBox(V3(0.012, 0.012, 0.05), radius: 0.004, bevelSegments: bs, material: black), Xform(translation: V3(-0.052, vy, 0)))
            // Barbed outlet at the bottom of the regulator, angled forward.
            rig.base[l].add(Prim.lathe([V2(0, 0), V2(0.0045, 0), V2(0.0045, 0.008), V2(0.0032, 0.01), V2(0.0042, 0.014), V2(0.003, 0.016), V2(0.004, 0.02), V2(0.0025, 0.024), V2(0, 0.024)],
                                       segments: l == 0 ? 10 : 6, seamTile: 0.03, material: "metal.brass"),
                            Xform(translation: V3(0.05, vy - 0.03, 0.006), rotation: simd_quatf(degrees: 150, axis: V3(1, 0, 0))))
        }
        // Pin-index gasket visible as a white ring where the yoke meets the valve (LOD0).
        rig.base[0].add(Prim.torus(major: 0.006, minor: 0.0012, segments: 12, sides: 5, material: "plastic.white"),
                        Xform(translation: V3(0.0155, vy - 0.006, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))

        // MARK: contents gauge on the regulator front (needle follows the valve key)
        let gC = V3(0.042, vy + 0.002, 0.023 + 0.006), gR: Float = 0.019
        for l in 0..<2 {
            rig.base[l].add(Prim.cylinder(radius: gR + 0.0025, height: 0.012, bevel: 0.0018, segments: l == 0 ? 24 : 12, bevelSegments: 1, material: chrome),
                            Xform(translation: gC - V3(0, 0, 0.008), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }
        // Dial face: white with a red "refill" arc and a green "full" arc, ticks.
        rig.base[0].add(Prim.cylinder(radius: gR, height: 0.0006, bevel: 0, segments: 24, bevelSegments: 1, material: "plastic.white"),
                        Xform(translation: gC + V3(0, 0, 0.0036), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        rig.base[1].add(Prim.cylinder(radius: gR, height: 0.0006, bevel: 0, segments: 12, bevelSegments: 1, material: "plastic.white"),
                        Xform(translation: gC + V3(0, 0, 0.0036), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Arcs: in the gauge plane, angle measured from +X counter-clockwise (seen from the front).
        func arc(_ a0: Float, _ a1: Float, _ mat: MaterialKey) -> Surface {
            var s = Prim.torus(major: gR * 0.78, minor: 0.0026, segments: 8, sides: 3, arc: (a1 - a0) * .pi / 180, minorY: 0.0003, material: mat)
            s.deform { p in V3(p.x, -p.z, p.y) }                       // XZ ring -> XY plane facing +Z
            return s.transformed(Xform(rotation: simd_quatf(degrees: a0, axis: V3(0, 0, 1))))
        }
        rig.base[0].add(arc(200, 245, "plastic.matte:C8261E"), Xform(translation: gC + V3(0, 0, 0.0042)))
        rig.base[0].add(arc(-40, 40, "plastic.matte:2E8B3A"), Xform(translation: gC + V3(0, 0, 0.0042)))
        for k in 0..<9 {
            let a = (225 - Float(k) * 30) * .pi / 180
            rig.base[0].add(cuboid(V3(0.0045, 0.0008, 0.0004), material: black),
                            Xform(translation: gC + V3(cos(a) * gR * 0.86, sin(a) * gR * 0.86, 0.0042), rotation: simd_quatf(angle: a, axis: V3(0, 0, 1))))
        }
        // Needle part: at rest pointing at empty (225 deg); rotates clockwise (negative about +Z).
        rig.part("key", pivot: V3(0, H + 0.062, 0), joint: .hinge(axis: .up, 0...330, duration: 1.4))
        rig.part("needle", pivot: gC, joint: Joint(.revolute, axis: V3(0, 0, 1), range: -230...0, duration: 1.0, mimic: .init("key", ratio: -0.68)))
        let na: Float = 225 * .pi / 180
        rig.add(Prim.roundedBox(V3(gR * 0.92, 0.0012, 0.0006), radius: 0.0002, bevelSegments: 1, material: "plastic.matte:111111"),
                Xform(translation: gC + V3(cos(na), sin(na), 0) * gR * 0.38 + V3(0, 0, 0.0052), rotation: simd_quatf(angle: na, axis: V3(0, 0, 1))), to: "needle")
        rig.add(Prim.cylinder(radius: 0.0018, height: 0.0012, bevel: 0.0003, segments: 8, bevelSegments: 1, material: "plastic.matte:111111"),
                Xform(translation: gC + V3(0, 0, 0.0046), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "needle")
        // Glass lens (static, after the needle so it sits in front).
        rig.base[0].add(Prim.cylinder(radius: gR + 0.0005, height: 0.0012, bevel: 0.0005, segments: 24, bevelSegments: 1, material: "plastic.clear"),
                        Xform(translation: gC + V3(0, 0, 0.0068), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))

        // MARK: flow selector dial on top of the regulator
        let fC = V3(0.042, vy + 0.036, 0)
        rig.part("flow", pivot: fC, joint: .hinge(axis: .up, 0...300, duration: 0.8))
        for l in 0..<2 {
            var knob = Prim.cylinder(radius: 0.021, height: 0.016, bevel: 0.003, segments: l == 0 ? 36 : 12, bevelSegments: 1, material: black)
            if l == 0 {
                knob.deform { p in
                    let r = simd_length(V2(p.x, p.z))
                    guard r > 0.0205, p.y > 0.002, p.y < 0.014 else { return p }
                    let a = atan2(p.z, p.x), k: Float = 1 + 0.06 * max(0, cos(a * 18))
                    return V3(p.x * k, p.y, p.z * k)
                }
            }
            rig.add(knob, Xform(translation: fC), to: "flow", lods: l...l)
        }
        // Flow numerals as white tick marks around the dial top, with a pointer ridge.
        for k in 0..<10 {
            let a = Float(k) * 30 * .pi / 180
            rig.add(cuboid(V3(0.0045, 0.0005, 0.0012), material: "plastic.white"),
                    Xform(translation: fC + V3(cos(a) * 0.016, 0.0162, sin(a) * 0.016), rotation: simd_quatf(angle: -a, axis: .up)), to: "flow", lods: 0...0)
        }
        rig.add(Prim.roundedBox(V3(0.03, 0.005, 0.006), radius: 0.002, bevelSegments: 1, material: black),
                Xform(translation: fC + V3(0, 0.018, 0)), to: "flow")
        // Fixed index window on the regulator body (shows the selected flow).
        rig.base[0].add(Prim.roundedBox(V3(0.008, 0.004, 0.003), radius: 0.001, bevelSegments: 1, material: "plastic.matte:F0F0F0"),
                        Xform(translation: V3(0.042, vy + 0.035, 0.0235)))

        // MARK: T-handle valve key on the square stem
        let sy = H + 0.055
        rig.base[0].add(Prim.roundedBox(V3(0.009, 0.012, 0.009), radius: 0.001, bevelSegments: 1, material: "metal.brass"), Xform(translation: V3(0, sy + 0.006, 0)))
        rig.base[1].add(Prim.roundedBox(V3(0.009, 0.012, 0.009), radius: 0.001, bevelSegments: 1, material: "metal.brass"), Xform(translation: V3(0, sy + 0.006, 0)))
        rig.add(Prim.roundedBox(V3(0.016, 0.03, 0.016), radius: 0.004, bevelSegments: 1, material: "plastic.matte:2D6F3E"),
                Xform(translation: V3(0, sy + 0.022, 0)), to: "key")
        rig.add(Prim.tube([V3(-0.045, sy + 0.04, 0), V3(-0.035, sy + 0.04, 0), V3(0.035, sy + 0.04, 0), V3(0.045, sy + 0.04, 0)], radii: [0.0045, 0.006, 0.006, 0.0045],
                          sides: 12, seamTile: 0.04, material: "plastic.matte:2D6F3E"), to: "key")

        groundAO(&rig, height: 0.06, floor: 0.6)
        rig.states = [
            RigState("closed"),
            RigState("standby", ["key": keyOpen]),
            RigState("open", ["key": keyOpen, "flow": flowOpen]),
        ]
        return rig
    }
}
