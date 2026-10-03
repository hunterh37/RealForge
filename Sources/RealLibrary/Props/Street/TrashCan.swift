import simd
import Foundation

public struct TrashCan: RealAsset {
    public static let id = "trash-can"
    public static let summary = "Park trash can: ribbed painted steel body, domed lid with opening, steel liner rim."
    public static let tags = ["prop", "urban", "metal"]
    public static let budget = 8_000
    public var color: UInt32 = 0x23402C
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let paint = String(format: "metal.painted:%06X", color)
        var body = turned([(0.0, 0.0), (0.26, 0.0), (0.27, 0.02), (0.27, 0.86), (0.28, 0.88), (0.28, 0.9), (0.25, 0.9), (0.25, 0.85)], segments: 72, material: paint, seamTile: 0.4)
        for i in body.positions.indices {   // vertical ribs
            let p = body.positions[i]
            guard p.y > 0.03 && p.y < 0.85 else { continue }
            let a = atan2(-p.z, p.x), k = 1 + 0.025 * pow(abs(sin(a * 12)), 6)
            body.positions[i] = V3(p.x * k, p.y, p.z * k)
        }
        body.recomputeNormals(); body.computeTangents()
        m.add(body)
        m.add(turned([(0.29, 0.9), (0.29, 0.93), (0.24, 1.02), (0.12, 1.07), (0.12, 1.02), (0.0, 1.02)], segments: 48, material: paint, seamTile: 0.4))
        groundAO(&m, height: 0.25, floor: 0.55)
        return LODModel(m)
    }
}
