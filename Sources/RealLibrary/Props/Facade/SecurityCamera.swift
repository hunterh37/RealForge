import simd
import Foundation

/// Bullet security camera: wall plate, short swivel arm with a ball joint, white aluminum body under a
/// sun shield, a glass lens ring with IR LEDs and a cable gland at the back.
public struct SecurityCamera: RealAsset {
    public static let id = "security-camera"
    public static let summary = "Bullet security camera, 0.28 m: aluminum body, sun shield, glass lens, swivel arm and wall mount."
    public static let tags = ["prop", "architecture", "facade", "electronics", "metal", "urban"]
    public static let budget = 6_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 55, elevation: 12, distance: 0.8)

    public var bodyLength: Float = 0.18
    public var bodyRadius: Float = 0.032
    public var shell: MaterialKey = "plastic.matte:E8E8E4"
    public var mount: MaterialKey = "metal.painted:D8D8D4"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let L = bodyLength, R = bodyRadius, by: Float = 0.034, bz: Float = 0.1
        FA.box(&m, V3(0.075, 0.075, 0.012), V3(0, by + 0.03, 0.006), mount, r: 0.004)
        for sx: Float in [-1, 1] { hexBolt(&m, at: V3(sx * 0.025, by + 0.03, 0.013), normal: FA.Z, size: 0.008, material: "metal.steel") }
        FA.cylZ(&m, r: 0.011, h: 0.06, at: V3(0, by + 0.03, 0.012), mount, bevel: 0.002, segments: 14)
        FA.ball(&m, r: 0.02, at: V3(0, by + 0.012, bz - 0.01), mount)
        // Body, shield and lens.
        FA.cylZ(&m, r: R, h: L, at: V3(0, by, bz - 0.02), shell, bevel: 0.004, segments: 24)
        FA.box(&m, V3(R * 2 + 0.012, 0.004, L * 0.75), V3(0, by + R + 0.004, bz - 0.02 + L * 0.5), shell, r: 0.002)
        FA.box(&m, V3(R * 1.2, 0.006, L * 0.75), V3(0, by + R + 0.001, bz - 0.02 + L * 0.5), shell, r: 0.002)
        let fz = bz - 0.02 + L
        m.add(Prim.torus(major: R - 0.005, minor: 0.005, segments: 24, sides: 6, material: "plastic.black"), Xform(translation: V3(0, by, fz - 0.001), rotation: FA.q(90, FA.X)))
        FA.cylZ(&m, r: R * 0.62, h: 0.008, at: V3(0, by, fz - 0.004), "glass.led-lens", bevel: 0.002, segments: 20)
        for k in 0..<6 {
            let a = Float(k) * .pi / 3
            FA.cylZ(&m, r: 0.0035, h: 0.003, at: V3((R - 0.008) * cos(a), by + (R - 0.008) * sin(a), fz - 0.003), "emissive.led-red", bevel: 0.0005, segments: 8)
        }
        FA.cylZ(&m, r: 0.007, h: 0.03, at: V3(0, by, bz - 0.02 - 0.02), "plastic.black", bevel: 0.001, segments: 10)
        return LODModel(FA.centerZ(m))
    }
}
