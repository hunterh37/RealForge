import simd
import Foundation

/// Dial tire pressure gauge: chrome head and chuck, black rubber boot, short hose and bleeder button. Lies on its boot along +X.
public struct TirePressureGauge: RealAsset {
    public static let id = "tire-pressure-gauge"
    public static let summary = "Analog dial tire gauge: 52 mm face reading 0-60 psi, chrome chuck, rubber hose and bleeder button, protective rubber boot."
    public static let tags = ["prop", "tool", "vehicle", "metal", "handheld"]
    public static let budget = 7000
    public static let author = "realityhd"

    /// Dial bezel radius in meters.
    public var dialRadius: Float = 0.032
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let R = dialRadius
        // Built with the dial facing +Z at the origin, handle chuck toward +X; lies on the boot.
        // Rubber boot: ring around the gauge head, 8 mm wide.
        let bootR = R + 0.007
        m.add(Prim.torus(major: R + 0.0035, minor: 0.0045, segments: 32, sides: 8, material: "rubber.silicone"), Xform(rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Chrome bezel ring and glass lens.
        m.add(Prim.torus(major: R - 0.002, minor: 0.0028, segments: 32, sides: 8, material: "metal.chrome"), Xform(translation: V3(0, 0, 0.011), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        m.add(Prim.cylinder(radius: R - 0.003, height: 0.003, bevel: 0.0005, segments: 36, material: "glass.gauge-lens"), Xform(translation: V3(0, 0, 0.0115), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Face: white card with black tick ring and red zone.
        m.add(Prim.cylinder(radius: R - 0.0035, height: 0.002, bevel: 0.0003, segments: 36, material: "paper.sheet"), Xform(translation: V3(0, 0, 0.005), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Case back.
        m.add(Prim.cylinder(radius: R - 0.003, height: 0.014, bevel: 0.003, segments: 36, material: "metal.chrome"), Xform(translation: V3(0, 0, -0.012), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Ticks 0...60 psi over 270 degrees, major every 10.
        for k in stride(from: 0, through: 30, by: 2) {
            let major = k % 10 == 0
            let a = Float.pi * 1.25 - Float(k) / 30 * Float.pi * 1.5
            let rr = R - (major ? 0.0095 : 0.0085), len: Float = major ? 0.0065 : 0.0035
            m.add(Prim.roundedBox(V3(major ? 0.0014 : 0.0008, len, 0.0006), radius: 0.0002, bevelSegments: 1, material: k >= 26 ? "plastic.orange:C8201E" : "plastic.black"),
                  Xform(translation: V3(cos(a) * rr, sin(a) * rr, 0.0062), rotation: simd_quatf(angle: a - .pi / 2, axis: V3(0, 0, 1))))
        }
        // Needle sitting at 32 psi, hub cap.
        let na = Float.pi * 1.25 - 32.0 / 60.0 * Float.pi * 1.5
        m.add(Prim.roundedBox(V3(0.0016, 0.024, 0.0007), radius: 0.0003, bevelSegments: 1, material: "plastic.orange:C8201E"),
              Xform(translation: V3(cos(na) * 0.011, sin(na) * 0.011, 0.0072), rotation: simd_quatf(angle: na - .pi / 2, axis: V3(0, 0, 1))))
        m.add(Prim.cylinder(radius: 0.0045, height: 0.003, bevel: 0.001, segments: 16, material: "metal.chrome"), Xform(translation: V3(0, 0, 0.0075), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Stem out the side: chrome collar, hose with a kink, brass chuck with rubber tip.
        let sx = bootR - 0.002
        m.add(Prim.tube([V3(sx - 0.006, 0, -0.004), V3(sx + 0.012, 0, -0.004)], radii: [0.0095, 0.0095], sides: 20, seamTile: 0.1, material: "rubber.silicone", capEnd: true))
        m.add(Prim.tube([V3(sx + 0.012, 0, -0.004), V3(sx + 0.05, 0.002, -0.004), V3(sx + 0.085, -0.004, -0.004)], radii: [0.0065, 0.0058, 0.0058], sides: 14, seamTile: 0.1, material: "plastic.black", capEnd: true))
        m.add(turned([(0, 0), (0.0062, 0), (0.0076, 0.004), (0.0076, 0.03), (0.0058, 0.034), (0.0042, 0.04), (0, 0.04)], segments: 20, material: "metal.chrome", seamTile: 0.05),
              Xform(translation: V3(sx + 0.085, -0.004, -0.004), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        m.add(Prim.cylinder(radius: 0.0052, height: 0.007, bevel: 0.0012, segments: 16, material: "rubber.silicone"), Xform(translation: V3(sx + 0.085 + 0.034, -0.004, -0.004), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        // Bleeder button on top of the stem.
        m.add(Prim.cylinder(radius: 0.0055, height: 0.008, bevel: 0.0015, segments: 16, material: "metal.chrome"), Xform(translation: V3(sx + 0.001, 0.0095, -0.004)))
        // Lay it so the dial faces up: rotate -90 about X (face +Z -> +Y), then rest the boot on y = 0.
        var out = Model(name: Self.id)
        out.add(m, Xform(rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
        let b = out.bounds
        out = out.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&out, height: 0.03, floor: 0.5)
        return LODModel(out)
    }
}
