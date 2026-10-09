import simd
import Foundation

/// Two parallel arches 400 mm apart, legs 1.1 m apart, 22 mm tube.
public struct GardenArch: RealAsset {
    public static let id = "garden-arch"
    public static let summary = "Garden arch, 2.27 m tall: twin black steel tube arches with cross ties, ground spikes, 1.1 m clear width."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "decor", "metal"]
    public static let budget = 5000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let iron = "metal.painted:26262A"
        for z: Float in [-0.2, 0.2] {
            var pts = [V3(-0.55, 0, z), V3(-0.55, 1.7, z)]
            pts += K.arc(V3(0, 1.7, z), 0.55, 180, 0, n: 24).dropFirst().dropLast()
            pts += [V3(0.55, 1.7, z), V3(0.55, 0, z)]
            K.rod(&m, pts, r: 0.011, iron)
        }
        for s: Float in [-1, 1] {
            for y: Float in [0.05, 0.5, 1.0, 1.7] { K.rod(&m, [V3(s * 0.55, y, -0.2), V3(s * 0.55, y, 0.2)], r: 0.008, iron) }
            for y: Float in [0.3, 0.75, 1.25] { K.rod(&m, [V3(s * 0.55, y, -0.2), V3(s * 0.55, y + 0.2, 0.2)], r: 0.005, iron, sides: 6) }
        }
        for a: Float in [150, 120, 90, 60, 30] {
            let r = a * .pi / 180
            K.rod(&m, [V3(cos(r) * 0.55, 1.7 + sin(r) * 0.55, -0.2), V3(cos(r) * 0.55, 1.7 + sin(r) * 0.55, 0.2)], r: 0.008, iron)
        }
        return K.finish(&m)
    }
}
