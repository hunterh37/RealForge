import simd
import Foundation

/// Freestanding playground slide, 1.2 m deck: steel ladder, guarded platform, polyethylene chute with rolled side rails.
public struct PlaygroundSlide: RealAsset {
    public static let id = "playground-slide"
    public static let summary = "Playground slide, 1.2 m deck: steel ladder, guarded platform and polyethylene chute with side rails."
    public static let tags = ["prop", "playground", "park", "outdoor", "plastic"]
    public static let budget = 2900
    public static let author = "hunterh37"

    /// Platform height in meters.
    public var deckHeight: Float = 1.2
    /// Chute color, sRGB hex.
    public var chuteColor: UInt32 = 0xE0B21A
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let h = deckHeight, frame: MaterialKey = "metal.painted:2D6FB5"
        let chute = MaterialKey(stringLiteral: "metal.painted:" + String(chuteColor, radix: 16, uppercase: true))
        for (x, z) in [(Float(-0.4), Float(-0.35)), (-0.4, 0.35), (0.35, -0.35), (0.35, 0.35)] { rod(&m, V3(x, 0, z), V3(x, h + 0.9, z), 0.03, frame, sides: 12) }
        bx(&m, V3(0.8, 0.04, 0.8), V3(0, h, 0), "wood.painted-exterior", r: 0.006)
        for z: Float in [-0.35, 0.35] {
            rod(&m, V3(-0.4, h + 0.55, z), V3(0.35, h + 0.55, z), 0.018, frame, sides: 8)
            rod(&m, V3(-0.4, h + 0.9, z), V3(0.35, h + 0.9, z), 0.025, frame, sides: 10)
        }
        rod(&m, V3(-0.4, h + 0.9, -0.35), V3(-0.4, h + 0.9, 0.35), 0.025, frame, sides: 10)
        let a = V3(0.4, h + 0.02, 0), b = V3(2.1, 0.15, 0)
        let len = simd_length(b - a), ang = atan2(a.y - b.y, b.x - a.x) * 180 / .pi
        let c = (a + b) / 2
        let rot = simd_quatf(degrees: -ang, axis: V3(0, 0, 1))
        m.add(Prim.roundedBox(V3(len, 0.02, 0.5), radius: 0.006, material: chute), Xform(translation: c, rotation: rot))
        for z: Float in [-0.26, 0.26] { m.add(Prim.roundedBox(V3(len, 0.08, 0.025), radius: 0.008, material: chute), Xform(translation: c + V3(0, 0.05, z), rotation: rot)) }
        for z: Float in [-0.25, 0.25] { rod(&m, V3(1.2, 0.0, z), V3(1.2, h * 0.55, z), 0.02, frame, sides: 8) }
        for i in 0..<5 {
            let y = 0.25 + Float(i) * 0.24
            rod(&m, V3(-0.75, y, -0.25), V3(-0.75, y, 0.25), 0.014, "metal.galvanized", sides: 8)
        }
        for z: Float in [-0.25, 0.25] { rod(&m, V3(-0.75, 0, z), V3(-0.4, h, z), 0.025, frame, sides: 10) }
        return K.finish(&m, ao: 0.2)
    }
}
