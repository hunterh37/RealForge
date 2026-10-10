import simd
import Foundation

/// Gooseneck barn lamp: a wall-plate mounted enamel arm curving 0.55 m out and over to a 0.36 m
/// dome shade with a warm bulb, wire guard and a drop of light. Marine-style signage lighting.
public struct GooseneckBarnLamp: RealAsset {
    public static let id = "gooseneck-barn-lamp"
    public static let summary = "Gooseneck barn lamp: wall plate, curved arm, 0.36 m enamel dome shade, bulb and wire guard."
    public static let tags = ["prop", "architecture", "facade", "light", "metal"]
    public static let budget = 7_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 10, distance: 2.0)

    public var shadeDiameter: Float = 0.36
    public var enamel: MaterialKey = "metal.painted:1F3D2B"
    public var arm: MaterialKey = "metal.enamel"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let R = shadeDiameter / 2
        FA.box(&m, V3(0.12, 0.2, 0.02), V3(0, 0.3, 0.01), arm, r: 0.004)
        for (dx, dy) in [(-0.04, 0.22), (0.04, 0.22), (-0.04, 0.38), (0.04, 0.38)] as [(Float, Float)] { hexBolt(&m, at: V3(dx, dy, 0.022), normal: FA.Z, size: 0.012, material: "metal.steel") }
        // Gooseneck: out from the plate, rising and curving down to the shade.
        let pts = catmull([V3(0, 0.3, 0.02), V3(0, 0.3, 0.14), V3(0, 0.38, 0.3), V3(0, 0.5, 0.45), V3(0, 0.56, 0.56), V3(0, 0.52, 0.62)], per: 8)
        FA.path(&m, pts, r: 0.016, arm, sides: 10)
        FA.cylZ(&m, r: 0.024, h: 0.05, at: V3(0, 0.3, 0.02), arm, segments: 12)
        // Dome shade (open at the bottom), lip and finial cap.
        let sy: Float = 0.47, sz: Float = 0.62
        let prof: [V2] = [V2(R * 0.18, 0.2), V2(R * 0.3, 0.19), V2(R * 0.62, 0.15), V2(R * 0.9, 0.07), V2(R, 0.02), V2(R + 0.008, 0.0), V2(R - 0.004, 0.0), V2(R * 0.88, 0.07), V2(R * 0.6, 0.145), V2(R * 0.28, 0.18)]
        m.add(Prim.lathe(prof, segments: 28, material: enamel), Xform(translation: V3(0, sy, sz)))
        m.add(Prim.cylinder(radius: 0.03, height: 0.05, bevel: 0.004, segments: 14, bevelSegments: 1, material: arm), Xform(translation: V3(0, sy + 0.18, sz)))
        // Bulb and guard.
        m.add(Prim.superellipsoid(V3(0.1, 0.13, 0.1), exponent: 2, subdivisions: 5, material: "emissive.warm"), Xform(translation: V3(0, sy + 0.06, sz)))
        for k in 0..<6 {
            let a = Float(k) * .pi / 3
            FA.path(&m, [V3(cos(a) * R * 0.8, sy + 0.02, sz + sin(a) * R * 0.8), V3(cos(a) * 0.05, sy - 0.1, sz + sin(a) * 0.05)], r: 0.0025, "metal.steel", sides: 5)
        }
        m.add(Prim.torus(major: R * 0.8, minor: 0.003, segments: 28, sides: 5, material: "metal.steel"), Xform(translation: V3(0, sy + 0.02, sz)))
        groundAO(&m, height: 0.1, floor: 0.9)
        return LODModel(FC.seatY(m))
    }
}
