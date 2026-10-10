import simd
import Foundation

/// Window air conditioner 0.6 x 0.4 x 0.5 m: white cabinet, front grille, control panel and side curtains.
public struct WindowAcUnit: RealAsset {
    public static let id = "window-ac-unit"
    public static let summary = "Window air conditioner 0.6 x 0.4 x 0.5 m: white cabinet, front grille, control panel and side curtains."
    public static let tags = ["prop", "facade", "window", "appliance", "plastic"]
    public static let budget = 2600
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "plastic.white"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let w: Float = 0.6, h: Float = 0.4, d: Float = 0.5
        K.box(&m, V3(0, h / 2, 0), V3(w, h, d), material, bevel: 0.012)
        K.box(&m, V3(0, h / 2, d / 2 + 0.004), V3(w - 0.04, h - 0.04, 0.012), "plastic.gloss", bevel: 0.006)
        for i in 0..<9 { K.box(&m, V3(0, 0.08 + 0.025 * Float(i), d / 2 + 0.012), V3(w - 0.14, 0.008, 0.012), material, bevel: 0.002) }
        K.box(&m, V3(0.21, 0.3, d / 2 + 0.014), V3(0.1, 0.12, 0.01), "plastic.black", bevel: 0.002)
        for i in 0..<3 { cy(&m, 0.012, 0.012, V3(0.21, 0.26 + 0.04 * Float(i), d / 2 + 0.02), "plastic.matte", bevel: 0.002, seg: 12) }
        for sx: Float in [-1, 1] { K.box(&m, V3(sx * (w / 2 + 0.03), h / 2 - 0.02, -0.05), V3(0.06, h - 0.1, 0.18), "plastic.matte", bevel: 0.003) }
        K.box(&m, V3(0, 0.02, 0), V3(w - 0.1, 0.04, d - 0.1), "metal.galvanized", bevel: 0.004)
        return K.finish(&m, ao: 0.05)
    }
}
