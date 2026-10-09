import simd
import Foundation

public struct RecyclingBin: RealAsset {
    public static let id = "recycling-bin"
    public static let summary = "Street recycling bin: blue steel drum, rounded lid, mixed-recycling aperture and symbol plate."
    public static let tags = ["prop", "urban", "street", "container", "metal"]
    public static let budget = 5000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        let b: MaterialKey = "metal.painted:1F5FA8"
        cy(&m, 0.28, 0.9, V3(0,0.05,0), b, seg: 48)
        m.add(turned([(0,0.95),(0.3,0.95),(0.3,0.98),(0.22,1.1),(0,1.12)], segments: 48, material: b, seamTile: 0.4))
        bx(&m, V3(0.2,0.08,0.02), V3(0,1.0,0.27), "plastic.black", r: 0.02)
        bx(&m, V3(0.16,0.16,0.005), V3(0,0.65,0.285), "plastic.white")
        for s: Float in [-1,1] { bx(&m, V3(0.04,0.06,0.04), V3(s*0.2,0.03,0), "metal.galvanized") }
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
