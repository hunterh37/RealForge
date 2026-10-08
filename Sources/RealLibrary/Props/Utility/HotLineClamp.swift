import simd
import Foundation

/// Bronze hot-line clamp for up to 4/0 main conductor (HLB class), lying on its side as it comes out
/// of the tool bag: a cast bronze barrel carrying the stainless eye screw, the hooked inverted-V jaw
/// that drapes over the main line, a sliding saddle on the screw tip under the jaw, a tap-conductor
/// clamp (stud, saddle, hex nut, washer) on the barrel end, and raised catalog numbers on the barrel.
/// Turning the eye with a shotgun stick drives the saddle up and bites the main conductor.
public struct HotLineClamp: RealAsset {
    public static let id = "hot-line-clamp"
    public static let summary = "Bronze hot-line clamp for 4/0 conductor: cast body with jaw and saddle, stainless eye screw with hot-stick eye, tap conductor clamp bolt."
    public static let tags = ["prop", "utility", "electrical", "handheld", "metal"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 30, distance: 1.0, studio: true)

    /// Saddle travel from closed (m).
    public var opening: Float = 0.014
    /// Cast body material.
    public var body: MaterialKey = "metal.bronze-cast"
    /// Eye screw and tap hardware.
    public var screw: MaterialKey = "metal.stainless"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let yc: Float = 0.0145, rb: Float = 0.0135
        let alongX = simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))
        // Barrel: cast tube along X with a collar at the screw end.
        let x0: Float = -0.045, x1: Float = 0.022
        m.add(Prim.lathe([V2(0, 0), V2(rb - 0.002, 0), V2(rb, 0.002), V2(rb, x1 - x0 - 0.006), V2(rb + 0.0015, x1 - x0 - 0.004),
                          V2(rb + 0.0015, x1 - x0), V2(0.007, x1 - x0 + 0.001), V2(0, x1 - x0 + 0.001)], segments: 28, seamTile: 0.1, material: body),
              Xform(translation: V3(x0, yc, 0), rotation: alongX))
        // Jaw: inverted-V hook rising off the barrel's back end, open along Z for the main conductor.
        let roof = Shape2D.rounded([V2(-0.019, 0.004), V2(-0.012, 0.004), V2(0.004, 0.034), V2(0.017, 0.022), V2(0.024, 0.026), V2(0.007, 0.047), V2(-0.002, 0.047)],
                                   radius: 0.003, segments: 2)
        m.add(Prim.extrude(roof, depth: 0.048, bevel: 0.002, bevelSegments: 2, material: body),
              Xform(translation: V3(-0.022, yc, 0), rotation: simd_quatf(angle: .pi / 2, axis: .up)))
        // Web joining the roof to the barrel.
        m.add(Prim.roundedBox(V3(0.044, 0.016, 0.014), radius: 0.004, bevelSegments: 2, material: body), Xform(translation: V3(-0.022, yc + 0.012, 0.004)))
        // Saddle on the screw tip under the roof: small V block.
        let sx: Float = -0.022 + opening * 0.3
        m.add(Prim.extrude(Shape2D.rounded([V2(-0.008, 0), V2(0.008, 0), V2(0.008, 0.009), V2(0.003, 0.012), V2(0, 0.006), V2(-0.003, 0.012), V2(-0.008, 0.009)], radius: 0.0012, segments: 2),
                           depth: 0.022, bevel: 0.0012, bevelSegments: 1, material: body), Xform(translation: V3(sx, yc + rb - 0.001, 0.0)))
        // Tap clamp on the barrel's far end: stud standing out of the barrel (+Z), tap saddle, nut, washer.
        let tp = V3(-0.04, yc + 0.002, rb - 0.002)
        let outZ = simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))
        m.add(Prim.roundedBox(V3(0.022, 0.024, 0.006), radius: 0.002, bevelSegments: 2, material: body), Xform(translation: tp + V3(0, 0, 0.003)))
        m.add(Prim.cylinder(radius: 0.0055, height: 0.028, bevel: 0.0008, segments: 14, material: screw), Xform(translation: tp, rotation: outZ))
        for k in 0..<6 { m.add(Prim.torus(major: 0.0055, minor: 0.0008, segments: 14, sides: 4, material: screw), Xform(translation: tp + V3(0, 0, 0.016 + Float(k) * 0.0022), rotation: outZ)) }
        m.add(Prim.cylinder(radius: 0.0095, height: 0.0016, bevel: 0.0005, segments: 18, material: screw), Xform(translation: tp + V3(0, 0, 0.006), rotation: outZ))
        m.add(Prim.cylinder(radius: 0.0102, height: 0.0078, bevel: 0.0013, segments: 6, material: screw), Xform(translation: tp + V3(0, 0, 0.0076), rotation: outZ))
        // Eye screw: threaded stub showing at the collar, smooth shank, flat forged eye.
        m.add(Prim.cylinder(radius: 0.0058, height: 0.012, bevel: 0.0008, segments: 14, material: screw), Xform(translation: V3(x1, yc, 0), rotation: alongX))
        for k in 0..<4 { m.add(Prim.torus(major: 0.0058, minor: 0.0008, segments: 14, sides: 4, material: screw), Xform(translation: V3(x1 + 0.002 + Float(k) * 0.0024, yc, 0), rotation: alongX)) }
        m.add(Prim.tube([V3(x1 + 0.012, yc, 0), V3(x1 + 0.03, yc - 0.002, 0), V3(x1 + 0.047, yc - 0.008, 0)], radii: [0.0052, 0.0048, 0.0062], sides: 12, seamTile: 0.05, material: screw))
        let eye = V3(x1 + 0.066, yc - 0.0105, 0)
        m.add(Prim.lathe([V2(0.0115, -0.0028), V2(0.0185, -0.0028), V2(0.0198, -0.0014), V2(0.0198, 0.0014), V2(0.0185, 0.0028), V2(0.0115, 0.0028),
                          V2(0.0106, 0.0014), V2(0.0106, -0.0014), V2(0.0115, -0.0028)], segments: 36, material: screw),
              Xform(translation: eye, rotation: simd_quatf(angle: 0.18, axis: V3(0, 0, 1))))
        // Raised catalog numbers on the barrel top.
        for i in 0..<7 where i != 3 {
            let x = -0.03 + Float(i) * 0.0052
            m.add(Prim.roundedBox(V3(0.0036, 0.0009, rng.float(0.0035...0.0045)), radius: 0.0003, bevelSegments: 1, material: body),
                  Xform(translation: V3(x, yc + rb + 0.0002, 0.006)))
        }
        groundAO(&m, height: 0.02, floor: 0.6)
        let b = m.bounds, c = (b.min + b.max) / 2
        var out = Model(name: Self.id); out.add(m, Xform(translation: V3(-c.x, -b.min.y, -c.z)))
        return LODModel(out)
    }
}
