import simd
import Foundation

/// Dual-head acoustic stethoscope (Littmann Classic III class, 69 cm) lying in a relaxed loop: polished
/// stainless chestpiece (43 mm diaphragm with a dark grey silicone rim on one face, 33 mm bell cup with a
/// non-chill rim on the other) turning on its stem, single-lumen black PVC tube (9 mm) from the stem to
/// a Y junction, two branches over the ends of the satin stainless eartubes, a bowed leaf tension
/// spring between the eartubes, angled tips and soft-seal grey ear tips, plus a clip-on ID tag on the
/// tube. The chestpiece indexes 180 degrees on the stem (diaphragm or bell up); the eartubes spread as a
/// mirrored pair.
public struct Stethoscope: RealArticulated {
    public static let id = "stethoscope"
    public static let summary = "Littmann Classic III class stethoscope lying in a loose loop: dual-head chestpiece, Y-split PVC tube, stainless headset with ear tips."
    public static let tags = ["prop", "medical", "handheld", "articulated", "tool", "metal", "rubber"]
    public static let budget = 6_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 15, elevation: 48, distance: 1.0, studio: true)

    /// Tube colour (sRGB hex): black, navy, burgundy...
    public var tubeColor: UInt32 = 0x1A1B1D
    /// Tube outer radius (m).
    public var tubeRadius: Float = 0.0045
    /// Eartube spread in the "spread" state (degrees per side).
    public var spreadAngle: Float = 22
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3])
        let tube: MaterialKey = "rubber.tubing:" + String(format: "%06X", tubeColor)
        let steel: MaterialKey = "metal.surgical", mirror: MaterialKey = "metal.surgical-mirror"
        let rim: MaterialKey = "rubber.silicone:4E5256", tipMat: MaterialKey = "rubber.silicone:9DA3A8"
        let rT = tubeRadius, rB: Float = 0.0036
        let ox: Float = -0.065, oz: Float = 0.0          // recentre the footprint
        func P(_ x: Float, _ y: Float, _ z: Float) -> V3 { V3(x + ox, y, z + oz) }
        let sides = [10, 6], per = [5, 3]

        // MARK: chestpiece geometry (diaphragm down at rest; stem along +Z).
        let C = P(0.125, 0.011, -0.065)
        let stemEnd = C + V3(0, 0, 0.042)
        // MARK: tube paths
        let J = P(0, rB, 0.075)
        let main: [V3] = [J, P(0.0, rT, 0.105), P(0.03, rT, 0.15), P(0.09, rT, 0.172), P(0.15, rT, 0.15), P(0.178, rT, 0.085), P(0.165, rT, 0.025),
                          P(0.135, rT + 0.002, -0.006), stemEnd + V3(0, 0, 0.004)]
        let bL = P(-0.035, rB, -0.012), bR = P(0.035, rB, -0.012)
        let branchL: [V3] = [J, P(-0.012, rB, 0.05), P(-0.03, rB, 0.015), bL]
        let branchR: [V3] = [J, P(0.012, rB, 0.05), P(0.03, rB, 0.015), bR]
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let mp = catmull(main, per: per[l])
            var radii = mp.map { _ in rT }
            radii[radii.count - 1] = rT * 0.92
            m.add(Prim.tube(mp, radii: radii, sides: sides[l], seamTile: 0.028, material: tube))
            for b in [branchL, branchR] {
                let bp = catmull(b, per: per[l])
                m.add(Prim.tube(bp, radii: bp.map { _ in rB }, sides: sides[l], seamTile: 0.022, material: tube))
            }
            // Y junction: moulded swelling where the branches leave the main tube.
            m.add(Prim.superellipsoid(V3(0.0118, 0.0084, 0.02), exponent: 2.2, subdivisions: l == 0 ? 5 : 3, material: tube),
                  Xform(translation: J + V3(0, 0.0006, 0.004)))
            // Stem (fixed to the tube): chrome rod into the tube end.
            m.add(Prim.cylinder(radius: 0.0031, height: 0.03, bevel: 0.0008, segments: l == 0 ? 14 : 8, bevelSegments: 1, material: mirror),
                  Xform(translation: C + V3(0, 0, 0.012), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            rig.base[l] = m
        }
        // ID tag clipped on the main tube (story detail): band and a white tag with a label tile.
        let tagAt = catmull(main, per: 6)[9]
        rig.base[0].add(Prim.torus(major: rT + 0.0009, minor: 0.0009, segments: 14, sides: 5, material: "plastic.matte:E6E4DE"),
                        Xform(translation: tagAt, rotation: simd_quatf(from: V3(0, 1, 0), to: simd_normalize(catmull(main, per: 6)[10] - catmull(main, per: 6)[8]))))
        let tagC = tagAt + V3(0.011, -rT + 0.0012, 0.004), tagYaw = rng.float(10...25)
        rig.base[0].add(Prim.roundedBox(V3(0.018, 0.0016, 0.011), radius: 0.0007, bevelSegments: 1, material: "plastic.matte:E6E4DE"),
                        Xform(translation: tagC, rotation: simd_quatf(degrees: tagYaw, axis: V3(0, 1, 0))))
        var tagLabel = Surface(material: "label.biomed")
        let up = V3(0, 1, 0)
        let ty = tagC.y + 0.00085, q0 = simd_quatf(degrees: tagYaw, axis: V3(0, 1, 0))
        let corners = [V3(-0.0075, 0, -0.0042), V3(-0.0075, 0, 0.0042), V3(0.0075, 0, 0.0042), V3(0.0075, 0, -0.0042)].map { q0.act($0) + V3(tagC.x, ty, tagC.z) }
        let i0 = tagLabel.add(corners[0], up, V2(0, 0)), i1 = tagLabel.add(corners[1], up, V2(0, 0.012))
        let i2 = tagLabel.add(corners[2], up, V2(0.012, 0.012)), i3 = tagLabel.add(corners[3], up, V2(0.012, 0))
        tagLabel.quad(i0, i1, i2, i3)
        tagLabel.computeTangents()

        // MARK: chestpiece part (turns on the stem axis, Z).
        rig.part("chest", pivot: C, joint: .hinge(axis: V3(0, 0, 1), 0...180, duration: 0.5))
        for l in 0..<2 {
            let sg = l == 0 ? 32 : 16
            let at = Xform(translation: V3(C.x, 0, C.z))
            // Diaphragm side: silicone suspension rim and the dark diaphragm disc.
            rig.add(Prim.lathe([V2(0.0175, 0.0001), V2(0.0205, 0.0002), V2(0.0216, 0.0016), V2(0.0217, 0.0062), V2(0.0206, 0.0078), V2(0.0185, 0.0081)],
                               segments: sg, seamTile: 0.03, material: rim), at, to: "chest", lods: l...l)
            rig.add(Prim.lathe([V2(0, 0.0004), V2(0.0182, 0.0003), V2(0.0184, 0.0012)], segments: sg, seamTile: 0.03,
                               material: "plastic.matte:2B2D30"), at, to: "chest", lods: l...l)
            // Polished head: diaphragm cup, waist, bell cup with flared mouth.
            rig.add(Prim.lathe([V2(0.0184, 0.0012), V2(0.0186, 0.0078), V2(0.0168, 0.0098), V2(0.0122, 0.0108), V2(0.0112, 0.0118),
                                V2(0.0128, 0.0132), V2(0.0152, 0.0175), V2(0.016, 0.0202), V2(0.0154, 0.0209), V2(0.0138, 0.0205),
                                V2(0.0102, 0.0168), V2(0.0052, 0.0152), V2(0, 0.015)], segments: sg, seamTile: 0.03, material: mirror), at, to: "chest", lods: l...l)
            // Non-chill ring on the bell rim.
            rig.add(Prim.lathe([V2(0.0136, 0.0204), V2(0.0154, 0.0208), V2(0.0164, 0.0213), V2(0.0162, 0.022), V2(0.0148, 0.0221), V2(0.0137, 0.0214)],
                               segments: sg, seamTile: 0.03, material: rim), at, to: "chest", lods: l...l)
        }
        // Stem boss on the head rim, turning with it.
        rig.add(Prim.cylinder(radius: 0.0052, height: 0.006, bevel: 0.0012, segments: 16, bevelSegments: 1, material: mirror),
                Xform(translation: C + V3(0, 0, 0.0158), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "chest")

        // MARK: headset: eartubes as a mirrored pair pivoting at their lower ends.
        func eartube(_ sx: Float) -> (path: [V3], tip: V3, dir: V3) {
            let b = sx < 0 ? bL : bR
            let p0 = b + V3(0, 0, 0.016), p1 = b + V3(-sx * 0.004, 0.0005, -0.04)
            let p2 = P(sx * 0.016, rB + 0.0004, -0.148), p3 = P(sx * 0.0135, rB + 0.0016, -0.158), p4 = P(sx * 0.0122, rB + 0.0052, -0.168)
            let path = catmull([p0, p1, p2, p3, p4], per: 5)
            let dir = simd_normalize(p4 - p3)
            return (path, p4, dir)
        }
        rig.part("earL", pivot: bL, joint: .hinge(axis: V3(0, 1, 0), 0...spreadAngle, duration: 0.4))
        rig.part("earR", pivot: bR, joint: Joint(.revolute, axis: V3(0, 1, 0), range: -spreadAngle...0, duration: 0.4, mimic: .init("earL", ratio: -1)))
        for (name, sx) in [("earL", Float(-1)), ("earR", Float(1))] {
            let e = eartube(sx)
            for l in 0..<2 {
                let path = l == 0 ? e.path : stride(from: 0, to: e.path.count, by: 2).map { e.path[$0] } + [e.path.last!]
                rig.add(Prim.tube(path, radii: path.map { _ in 0.0021 }, sides: l == 0 ? 10 : 6, seamTile: 0.013, material: steel), to: name, lods: l...l)
                // Soft-seal ear tip: rounded mushroom on the eartube end.
                let tip = Prim.lathe([V2(0.0022, -0.001), V2(0.0058, 0.002), V2(0.0068, 0.006), V2(0.0062, 0.0098), V2(0.004, 0.0118), V2(0.0016, 0.0122),
                                      V2(0.0014, 0.0112)], segments: l == 0 ? 20 : 10, seamTile: 0.02, material: tipMat)
                rig.add(tip, Xform(translation: e.tip, rotation: simd_quatf(from: V3(0, 1, 0), to: e.dir)), to: name, lods: l...l)
            }
        }
        // Leaf tension spring: bowed strip between the eartubes just above the branch ends (moves little as they spread).
        let spring = (0...10).map { k -> V3 in
            let t = Float(k) / 10
            return V3(bL.x + 0.0028 + (bR.x - bL.x - 0.0056) * t, bL.y + 0.0004, bL.z - 0.006 - 0.007 * sin(t * .pi))
        }
        rig.base[0].add(Prim.sweep(Shape2D.roundedRect(0.0042, 0.0009, radius: 0.0003, segments: 1), along: spring, up: V3(0, 1, 0), material: steel))
        rig.base[1].add(Prim.sweep(Shape2D.roundedRect(0.0042, 0.0009, radius: 0.0003, segments: 1), along: stride(from: 0, to: 11, by: 2).map { spring[$0] }, up: V3(0, 1, 0), material: steel))

        groundAO(&rig, height: 0.01, floor: 0.6)
        rig.base[0].add(tagLabel)
        rig.states = [RigState("resting"), RigState("diaphragm", ["chest": 180, "earL": 14]), RigState("bell", ["earL": 14]),
                      RigState("spread", ["earL": spreadAngle])]
        return rig
    }
}
