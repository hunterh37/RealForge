import simd
import Foundation

/// Frame 1.29 m by 1.89 m with two layers of 20 mm slats at 45 degrees, 120 mm pitch.
public struct LatticeScreen: RealAsset {
    public static let id = "lattice-screen"
    public static let summary = "Diamond lattice screen, 1.2 m by 1.8 m: crossed slats in a painted frame on two short feet."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "fence", "wood"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    /// Paint color (sRGB hex).
    public var paint: UInt32 = 0xF0ECE0
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let wood = String(format: "wood.barn-white:%06X", paint)
        let W: Float = 1.2, H: Float = 1.8, y0: Float = 0.07, pitch: Float = 0.12
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * (W / 2 + 0.02), y0 + H / 2, 0), V3(0.045, H + 0.09, 0.05), wood)
            K.box(&m, V3(s * (W / 2 + 0.02), 0.035, 0), V3(0.05, 0.07, 0.3), wood)
        }
        for y: Float in [y0 - 0.02, y0 + H + 0.02] { K.box(&m, V3(0, y, 0), V3(W + 0.09, 0.045, 0.05), wood) }
        var c = -W
        while c < H {
            let x0 = max(0, -c), x1 = min(W, H - c)
            if x1 - x0 > 0.05 {
                K.slat(&m, V3(x0 - W / 2, y0 + x0 + c, 0.008), V3(x1 - W / 2, y0 + x1 + c, 0.008), 0.02, 0.012, wood, up: V3(0, 0, 1))
            }
            c += pitch
        }
        c = 0
        while c < H + W {
            let x0 = max(0, c - H), x1 = min(W, c)
            if x1 - x0 > 0.05 {
                K.slat(&m, V3(x0 - W / 2, y0 + c - x0, -0.008), V3(x1 - W / 2, y0 + c - x1, -0.008), 0.02, 0.012, wood, up: V3(0, 0, 1))
            }
            c += pitch
        }
        return K.finish(&m)
    }
}
