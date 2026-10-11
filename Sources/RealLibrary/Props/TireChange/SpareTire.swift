import simd
import Foundation

/// Compact temporary spare, T155/70D17 on a 5x114.3 steel wheel, lying flat with the wheel face up.
public struct SpareTire: RealAsset {
    public static let id = "spare-tire"
    public static let summary = "Compact temporary spare: 17 inch steel wheel with vent holes, five lug holes and valve stem, tread and sidewall."
    public static let tags = ["prop", "vehicle", "rubber", "metal"]
    public static let budget = 15000
    public static let author = "realityhd"

    /// Overall tire diameter in meters.
    public var diameter: Float = 0.649
    /// Section width in meters.
    public var sectionWidth: Float = 0.155
    /// Rim bead seat radius in meters (17 inch).
    public var rimRadius: Float = 0.2159
    /// Wheel paint, sRGB hex.
    public var wheelPaint: UInt32 = 0x2A2C2F
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = diameter / 2, hw = sectionWidth / 2, rr = rimRadius
        let cy = hw  // tire center height
        // Tire carcass: bead, bulged sidewall, shoulder, flat crown with three circumferential grooves.
        var prof: [V2] = []
        func side(_ s: Float) -> [V2] {
            [V2(rr - 0.006, s * (hw - 0.012)), V2(rr + 0.004, s * (hw - 0.004)), V2(rr + 0.02, s * hw), V2(rr + 0.05, s * (hw + 0.002)),
             V2(R - 0.055, s * (hw + 0.0015)), V2(R - 0.025, s * (hw - 0.004)), V2(R - 0.008, s * (hw - 0.017)), V2(R - 0.002, s * (hw - 0.026))]
        }
        let lower = side(-1), upper = side(1)
        prof += lower
        // Crown with grooves (y in -0.052...0.052 about center).
        let grooveY: [Float] = [-0.036, -0.012, 0.012, 0.036]
        var crown: [V2] = [V2(R, -0.050)]
        for g in grooveY {
            crown += [V2(R, g - 0.0045), V2(R - 0.004, g - 0.0028), V2(R - 0.004, g + 0.0028), V2(R, g + 0.0045)]
        }
        crown.append(V2(R, 0.050))
        prof += crown
        prof += upper.reversed()
        // Inner bead closure back to the start.
        prof.append(V2(rr - 0.006, hw - 0.012 - 0.004))
        prof.append(V2(rr - 0.006, -(hw - 0.012) + 0.004))
        m.add(Prim.lathe(prof.map { V2($0.x, $0.y + cy) }, segments: 72, seamTile: 0.3, material: "rubber.tire", swapUV: false))
        // Wheel: rim flange ring and dished steel center, face up. Face sits 22 mm below the tire top.
        let paintKey = "metal.powdercoat:" + String(wheelPaint, radix: 16, uppercase: true)
        let top = cy + hw
        let faceY = top - 0.03
        // Rim barrel visible as a flange lip at the top bead.
        m.add(Prim.lathe([V2(rr + 0.012, top - 0.012), V2(rr + 0.004, top - 0.004), V2(rr - 0.002, top - 0.006), V2(rr - 0.004, top - 0.02), V2(rr - 0.006, faceY + 0.012), V2(rr - 0.03, faceY + 0.002), V2(rr - 0.03, faceY - 0.002)],
                          segments: 96, seamTile: 0.3, material: paintKey, swapUV: false))
        // Dish: face disc with raised hat around the hub.
        m.add(Prim.lathe([V2(rr - 0.03, faceY), V2(0.095, faceY + 0.004), V2(0.078, faceY + 0.022), V2(0.0375, faceY + 0.022), V2(0.0345, faceY + 0.018), V2(0.0345, faceY - 0.01)],
                          segments: 64, seamTile: 0.3, material: paintKey, swapUV: false))
        // Center bore (dark) and hub ring.
        m.add(Prim.cylinder(radius: 0.0345, height: 0.002, bevel: 0.0004, segments: 32, material: "plastic.black"), Xform(translation: V3(0, faceY + 0.013, 0)))
        // Five lug holes on a 114.3 mm bolt circle: conical steel seats with dark bores.
        let lugR: Float = 0.05715
        for i in 0..<5 {
            let a = Float(i) / 5 * 2 * .pi + .pi / 2
            let p = V3(cos(a) * lugR, faceY + 0.022, sin(a) * lugR)
            m.add(Prim.torus(major: 0.0118, minor: 0.0034, segments: 20, sides: 8, material: "metal.steel"), Xform(translation: p))
            m.add(Prim.cylinder(radius: 0.0112, height: 0.0008, bevel: 0.0002, segments: 20, material: "plastic.black"), Xform(translation: p + V3(0, -0.0004, 0)))
            // Vent slots between the lugs: five oval windows, dark inside, rolled edge.
            let va = a + .pi / 5
            let vp = V3(cos(va) * 0.128, faceY + 0.0045, sin(va) * 0.128)
            m.add(Prim.torus(major: 0.0195, minor: 0.0028, segments: 16, sides: 6, material: paintKey), Xform(translation: vp, rotation: simd_quatf(angle: -va, axis: V3(0, 1, 0)), scale: V3(1.5, 1, 1)))
            m.add(Prim.cylinder(radius: 0.0195, height: 0.001, bevel: 0.0002, segments: 16, material: "plastic.black"), Xform(translation: vp + V3(0, -0.0008, 0), rotation: simd_quatf(angle: -va, axis: V3(0, 1, 0)), scale: V3(1.5, 1, 1)))
        }
        // Molded sidewall ribs: two thin concentric rings on the upper wall.
        for rr2: Float in [0.255, 0.288] {
            m.add(Prim.torus(major: rr2, minor: 0.0014, segments: 48, sides: 4, material: "rubber.silicone"), Xform(translation: V3(0, top + 0.0006, 0)))
        }
        // Compact-spare pressure sticker on the sidewall: yellow label with text bars.
        let sa = rng.float(0...(2 * .pi))
        let sr: Float = 0.27, sy = top + 0.0012
        let sq = simd_quatf(angle: -sa, axis: V3(0, 1, 0))
        let sc = V3(cos(sa) * sr, 0, sin(sa) * sr)
        m.add(Prim.roundedBox(V3(0.07, 0.0009, 0.045), radius: 0.0003, bevelSegments: 1, material: "plastic.yellow"), Xform(translation: sc + V3(0, sy, 0), rotation: sq))
        for k in -2...2 {
            m.add(Prim.roundedBox(V3(0.056 - abs(Float(k)) * 0.006, 0.0005, 0.0042), radius: 0.0002, bevelSegments: 1, material: "plastic.black"), Xform(translation: sc + V3(0, sy + 0.0007, 0) + sq.act(V3(0, 0, Float(k) * 0.0085)), rotation: sq))
        }
        // Valve stem poking from the rim, rubber with chrome cap.
        let va = rng.float(0...(2 * .pi))
        let vx = cos(va) * (rr - 0.045), vz = sin(va) * (rr - 0.045)
        m.add(Prim.tube([V3(vx, faceY + 0.004, vz), V3(vx, faceY + 0.024, vz)], radii: [0.0055, 0.0042], sides: 10, seamTile: 0.1, material: "rubber.silicone", capEnd: true))
        m.add(Prim.cylinder(radius: 0.0047, height: 0.01, bevel: 0.0012, segments: 12, material: "metal.chrome"), Xform(translation: V3(vx, faceY + 0.02, vz)))
        // Story detail: a spare lock key tag looped through a vent hole is omitted; wheel weight clip on the lip.
        let wa = rng.float(0...(2 * .pi))
        m.add(Prim.roundedBox(V3(0.02, 0.012, 0.0045), radius: 0.001, bevelSegments: 1, material: "metal.steel"),
              Xform(translation: V3(cos(wa) * (rr + 0.01), top - 0.006, sin(wa) * (rr + 0.01)), rotation: simd_quatf(angle: -wa, axis: V3(0, 1, 0))))
        var out = Model(name: Self.id)
        out.add(m, Xform(rotation: simd_quatf(degrees: rng.float(0...360), axis: V3(0, 1, 0))))
        let b = out.bounds
        out = out.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&out, height: 0.04, floor: 0.45)
        return LODModel(out)
    }
}
