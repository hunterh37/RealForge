import simd
import Foundation

/// Stone balustrade run: 2.4 m of turned baluster between a moulded top rail and plinth, with a pier
/// and urn at each end. 0.95 m tall including urns' base; a roof-edge or terrace parapet.
public struct StoneBalustradeRun: RealAsset {
    public static let id = "stone-balustrade-run"
    public static let summary = "Stone balustrade, 2.4 m: 15 turned balusters, moulded rails, end piers with urns."
    public static let tags = ["prop", "architecture", "facade", "trim", "stone"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 14, distance: 4.4)

    public var length: Float = 2.4
    public var railHeight: Float = 0.82
    public var balusterPitch: Float = 0.14
    public var stone: MaterialKey = "stone.limestone"
    public var weathered: MaterialKey = "stone.limestone-sooted"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length, H = railHeight
        FA.box(&m, V3(L, 0.12, 0.3), V3(0, 0.06, 0), stone, r: 0.006)
        FA.box(&m, V3(L - 0.5, 0.1, 0.34), V3(0, H + 0.05, 0), stone, r: 0.008)
        FA.box(&m, V3(L - 0.5, 0.03, 0.38), V3(0, H + 0.115, 0), stone, r: 0.006)
        let n = Int((L - 0.7) / balusterPitch)
        let prof: [V2] = [V2(0.0, 0.0), V2(0.07, 0.0), V2(0.07, 0.03), V2(0.05, 0.05), V2(0.04, 0.12), V2(0.065, 0.22), V2(0.075, 0.3), V2(0.055, 0.4), V2(0.04, 0.46), V2(0.065, 0.5), V2(0.065, 0.55), V2(0.0, 0.55)]
        let sc = (H - 0.12) / 0.55
        for i in 0..<n {
            let x = -Float(n - 1) * balusterPitch / 2 + Float(i) * balusterPitch
            m.add(Prim.lathe(prof.map { V2($0.x, $0.y * sc) }, segments: 14, material: i % 4 == 0 ? weathered : stone), Xform(translation: V3(x, 0.12, 0)))
        }
        for e: Float in [-1, 1] {
            let x = e * (L / 2 - 0.15)
            FA.box(&m, V3(0.3, H + 0.14, 0.34), V3(x, (H + 0.14) / 2 + 0.0, 0), stone, r: 0.008)
            FA.box(&m, V3(0.38, 0.06, 0.42), V3(x, H + 0.17, 0), stone, r: 0.006)
            FA.box(&m, V3(0.26, 0.04, 0.3), V3(x, H + 0.1, 0.0), weathered, r: 0.004)
            // Urn: lathe body with gadrooned belly and a fruit finial.
            let u: [V2] = [V2(0.0, 0.0), V2(0.06, 0.0), V2(0.06, 0.04), V2(0.05, 0.07), V2(0.1, 0.14), V2(0.13, 0.22), V2(0.11, 0.3), V2(0.08, 0.34), V2(0.1, 0.37), V2(0.0, 0.37)]
            m.add(Prim.lathe(u, segments: 20, material: stone), Xform(translation: V3(x, H + 0.2, 0)))
            FA.ball(&m, r: 0.045 + rng.float(0...0.004), at: V3(x, H + 0.2 + 0.4, 0), stone)
        }
        groundAO(&m, height: 0.12, floor: 0.82)
        return LODModel(FC.place(m))
    }
}
