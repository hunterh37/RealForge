import simd
import Foundation

/// Otoscope: clinic wall-set handle, chrome knurl worn bright where held, matte black head. Parts: knurled chrome C-cell handle with smooth bands, rheostat collar with red index dot, bayonet neck, black MacroView head housing, rear magnifier window on a hinge, front nose cone with fiber-optic ring, black disposable speculum, insufflation port.
public struct Otoscope: RealAsset {
    public static let id = "otoscope"
    public static let summary = "Welch Allyn MacroView class otoscope standing on a knurled C-cell handle with rheostat collar, magnifier window and black disposable speculum."
    public static let tags = ["prop", "medical", "handheld", "articulated", "tool", "electronics", "metal", "plastic"]
    public static let budget = 6000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.036, 0.205, 0.105)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: metal.chrome metal.surgical plastic.matte plastic.clear emissive.bulb label.rx. Gate: realityhd gate otoscope. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "metal.chrome"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
