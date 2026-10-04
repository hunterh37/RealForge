import simd
import Foundation

/// Round 30 L pedal bin (Brabantia NewIcon class), 29.5 cm diameter x 66 cm: brushed stainless drum with
/// a rolled top rim, black plastic base ring, domed stainless lid on a black rear hinge housing, and a
/// steel foot pedal with a rubber tread at the front base. Pressing the pedal lifts the lid through a
/// linkage (lid mimics pedal); a removable grey inner bucket with a wire bail shows when it is open.
public struct PedalBin: RealArticulated {
    public static let id = "pedal-bin"
    public static let summary = "Round 30 L stainless pedal bin: rolled-rim drum, black base ring, domed lid on a rear hinge, foot pedal and grey inner bucket."
    public static let tags = ["prop", "office", "metal", "container", "articulated"]
    public static let budget = 6_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 16, distance: 1.0, studio: true)

    public var radius: Float = 0.1475
    public var height: Float = 0.66
    public var body: MaterialKey = "metal.stainless"
    /// Inner bucket plastic tint (sRGB hex).
    public var bucket: UInt32 = 0x46494C
    /// Lid opening at full pedal travel (degrees).
    public var lidOpen: Float = 78
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [6])
        let R = radius, H = height
        let black: MaterialKey = "plastic.matte:1C1C1E"
        let inner: MaterialKey = "plastic.matte:" + String(format: "%06X", bucket)
        let rimY = H - 0.034            // top of the drum (rolled rim)
        let segs = [48, 24]

        for l in 0..<2 {
            var m = Model(name: Self.id)
            let sg = segs[l]
            // Black plastic base ring, slightly proud of the drum, with a chamfered foot.
            m.add(Prim.lathe([V2(0, 0.0), V2(R - 0.004, 0), V2(R + 0.003, 0.004), V2(R + 0.004, 0.03),
                              V2(R + 0.001, 0.036), V2(R - 0.002, 0.037), V2(0, 0.037)], segments: sg, material: black))
            // Drum: straight wall, rolled rim, inner wall going down to the bucket.
            var prof: [V2] = [V2(R - 0.002, 0.034), V2(R, 0.038), V2(R, rimY - 0.006)]
            let rr: Float = 0.0045
            for k in 0...(l == 0 ? 6 : 3) {
                let t = Float(k) / Float(l == 0 ? 6 : 3) * .pi
                prof.append(V2(R - rr + rr * cos(t), rimY - 0.006 + rr * sin(t)))
            }
            prof.append(V2(R - 2 * rr, rimY - 0.03))
            prof.append(V2(R - 0.012, rimY - 0.05))
            m.add(Prim.lathe(prof, segments: sg, material: body))
            // Inner bucket: grey liner with a flared lip resting just inside the rim.
            let bR = R - 0.012
            m.add(Prim.lathe([V2(0, 0.08), V2(bR - 0.004, 0.08), V2(bR - 0.004, rimY - 0.014)], segments: sg, material: inner).flipped())
            m.add(Prim.lathe([V2(bR + 0.006, rimY - 0.02), V2(bR + 0.006, rimY - 0.013), V2(bR + 0.004, rimY - 0.009), V2(bR - 0.002, rimY - 0.009),
                              V2(bR - 0.004, rimY - 0.014)], segments: sg, material: inner))
            if l == 0 {
                // Wire bail handle of the bucket, folded flat along the rim.
                let bail = (0...16).map { k -> V3 in
                    let a = Float(k) / 16 * .pi
                    return V3(cos(a) * (bR - 0.008), rimY - 0.016 + 0.003 * sin(a), -sin(a) * (bR - 0.008) * 0.96)
                }
                m.add(Prim.tube(bail, radii: bail.map { _ in 0.002 }, sides: 6, seamTile: 0.05, material: "metal.chrome", capEnd: false))
                // Pedal housing: black plastic bracket at the front base.
                m.add(Prim.roundedBox(V3(0.12, 0.034, 0.03), radius: 0.008, bevelSegments: 2, material: black),
                      Xform(translation: V3(0, 0.034, R - 0.008)))
            }
            // Hinge housing at the back under the lid.
            m.add(Prim.roundedBox(V3(0.13, 0.03, 0.03), radius: 0.009, bevelSegments: l == 0 ? 2 : 1, material: black),
                  Xform(translation: V3(0, rimY - 0.008, -R - 0.006)))
            // Lid lift rod channel down the back.
            m.add(Prim.roundedBox(V3(0.024, rimY - 0.07, 0.008), radius: 0.003, bevelSegments: 1, material: body),
                  Xform(translation: V3(0, (rimY + 0.04) / 2, -R - 0.002)))
            rig.base[l] = m
        }

        // Pedal: steel tongue with rubber tread, pivot inside the base ring. Axis -X so a negative value
        // presses the front down.
        let pz = R - 0.006, py: Float = 0.04
        rig.part("pedal", pivot: V3(0, py, pz), joint: .hinge(axis: V3(-1, 0, 0), -12...0, duration: 0.3))
        let tongue = Shape2D.rounded([V2(-0.055, 0), V2(0.055, 0), V2(0.05, 0.075), V2(-0.05, 0.075)], radius: 0.012, segments: 3)
        rig.add(Prim.extrude(tongue, depth: 0.007, bevel: 0.002, bevelSegments: 2, material: body),
                Xform(translation: V3(0, py - 0.004, pz - 0.005), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "pedal")
        rig.add(Prim.extrude(Shape2D.offset(tongue, -0.008), depth: 0.003, bevel: 0.001, bevelSegments: 1, material: "rubber"),
                Xform(translation: V3(0, py, pz - 0.002), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "pedal", lods: 0...0)

        // Lid: shallow stainless dome with a rolled edge; hinge pin at the back top of the housing.
        let hy = rimY + 0.004, hz = -R - 0.008
        rig.part("lid", pivot: V3(0, hy, hz), joint: Joint(.revolute, axis: V3(1, 0, 0), range: -lidOpen...0, duration: 0.6,
                                                         mimic: .init("pedal", ratio: lidOpen / 12)))
        let lR = R + 0.003
        var lidProf: [V2] = [V2(lR - 0.006, rimY - 0.002), V2(lR, rimY + 0.001), V2(lR + 0.0005, rimY + 0.006)]
        for k in 0...8 {
            let t = Float(k) / 8
            lidProf.append(V2(lR * (1 - t) + 0.0001, rimY + 0.008 + 0.03 * sin(t * .pi / 2) * (1 - 0.15 * t)))
        }
        lidProf.append(V2(0, rimY + 0.0345))
        for l in 0..<2 {
            rig.add(Prim.lathe(lidProf, segments: segs[l], material: body), Xform(translation: V3(0, 0, 0)).jittered(&rng, deg: 0.05, offset: 0.0002), to: "lid", lods: l...l)
            rig.add(Prim.lathe([V2(0, rimY - 0.0015), V2(lR - 0.006, rimY - 0.002)], segments: segs[l], material: black), to: "lid", lods: l...l)
        }
        rig.add(Prim.roundedBox(V3(0.1, 0.012, 0.02), radius: 0.005, bevelSegments: 2, material: black),
                Xform(translation: V3(0, rimY + 0.004, -R - 0.006)), to: "lid")

        groundAO(&rig, height: 0.08, floor: 0.55)
        rig.states = [RigState("closed"), RigState("open", ["pedal": -12])]
        return rig
    }
}
