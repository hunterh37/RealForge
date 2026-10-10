import simd
import Foundation

/// Ionic pilaster: a 0.4 m wide, 3.0 m tall engaged column with Attic base, seven shallow flutes, an
/// entasis-free shaft and a capital with volutes, echinus and abacus, in cast stone.
public struct IonicPilaster: RealAsset {
    public static let id = "ionic-pilaster"
    public static let summary = "Ionic pilaster, 3.0 m: Attic base, fluted shaft, volute capital with echinus and abacus."
    public static let tags = ["prop", "architecture", "facade", "trim", "stone"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 8, distance: 5.4)

    public var width: Float = 0.4
    public var height: Float = 3.0
    public var stone: MaterialKey = "stone.cast-stone"
    public var shade: MaterialKey = "stone.limestone-sooted"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, H = height, pd: Float = 0.1
        let baseH: Float = 0.3, capH: Float = 0.3
        FA.box(&m, V3(W + 0.12, 0.1, pd + 0.06), V3(0, 0.05, (pd + 0.06) / 2), stone, r: 0.004)
        FA.box(&m, V3(W + 0.06, 0.06, pd + 0.04), V3(0, 0.13, (pd + 0.04) / 2), stone, r: 0.004)
        FA.cylX(&m, r: 0.04, h: W + 0.04, at: V3(0, 0.19, pd / 2 + 0.01), stone, segments: 14)
        FA.box(&m, V3(W - 0.04, 0.05, pd), V3(0, 0.255, pd / 2), stone, r: 0.003)
        let shaftH = H - baseH - capH
        FA.box(&m, V3(W - 0.06, shaftH, pd), V3(0, baseH + shaftH / 2, pd / 2), stone, r: 0.003)
        // Flutes: seven shallow dark grooves with rounded ends.
        for i in 0..<7 {
            let x = (Float(i) - 3) * (W - 0.12) / 6
            FA.box(&m, V3(0.024, shaftH - 0.2, 0.008), V3(x, baseH + shaftH / 2, pd + 0.0), shade, r: 0.01)
        }
        // Capital: echinus, volute scrolls, abacus.
        let cy = H - capH
        FA.box(&m, V3(W - 0.06, 0.06, pd + 0.02), V3(0, cy + 0.03, (pd + 0.02) / 2), stone, r: 0.003)
        FA.cylX(&m, r: 0.045, h: W + 0.1, at: V3(0, cy + 0.15, pd / 2 + 0.02), stone, segments: 14)
        for e: Float in [-1, 1] {
            m.add(Prim.torus(major: 0.07, minor: 0.018, segments: 22, sides: 8, material: stone),
                  Xform(translation: V3(e * (W / 2 + 0.01), cy + 0.15, pd / 2 + 0.03), rotation: FA.q(90, FA.X)))
            m.add(Prim.torus(major: 0.035, minor: 0.014, segments: 16, sides: 6, material: stone),
                  Xform(translation: V3(e * (W / 2 + 0.01), cy + 0.15, pd / 2 + 0.03), rotation: FA.q(90, FA.X)))
        }
        FA.box(&m, V3(W + 0.12, 0.05, pd + 0.06), V3(0, H - 0.025, (pd + 0.06) / 2), stone, r: 0.004)
        groundAO(&m, height: 0.15, floor: 0.82)
        return LODModel(FA.centerZ(m))
    }
}
