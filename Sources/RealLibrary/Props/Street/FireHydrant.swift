import simd
import Foundation

public struct FireHydrant: RealAsset {
    public static let id = "fire-hydrant"
    public static let summary = "Cast-iron fire hydrant, red paint with wear, pentagon nuts, two hose outlets and a pumper nozzle."
    public static let tags = ["prop", "urban", "metal"]
    public static let budget = 10_000
    public var color: UInt32 = 0xB0241A
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let paint = String(format: "metal.painted:%06X", color)
        m.add(turned([(0, 0), (0.15, 0), (0.15, 0.03), (0.115, 0.05), (0.11, 0.09), (0.125, 0.1), (0.125, 0.12), (0.1, 0.13), (0.1, 0.52), (0.12, 0.53),
                      (0.125, 0.56), (0.11, 0.58), (0.105, 0.62), (0.09, 0.68), (0.06, 0.71), (0.0, 0.72)], segments: 36, material: paint))
        // Bolt ring on the flange.
        for k in 0..<8 {
            let a = Float(k) / 8 * 2 * .pi
            m.add(turned([(0, 0), (0.012, 0), (0.012, 0.012), (0, 0.014)], segments: 6, material: "metal.iron"), Xform(translation: V3(cos(a) * 0.115, 0.12, sin(a) * 0.115)))
        }
        // Top pentagon operating nut.
        m.add(turned([(0, 0.71), (0.03, 0.71), (0.03, 0.75), (0, 0.75)], segments: 5, material: paint, seamTile: 0.1))
        // Outlets: two side hose outlets and a front pumper, each with a cap nut.
        let outlets: [(V3, Float, Float)] = [(V3(1, 0, 0), 0.04, 0.09), (V3(-1, 0, 0), 0.04, 0.09), (V3(0, 0, 1), 0.055, 0.11)]
        for (dir, rr, len) in outlets {
            var o = turned([(0, 0), (rr, 0), (rr, len * 0.6), (rr + 0.01, len * 0.62), (rr + 0.01, len * 0.85), (rr * 0.6, len), (0, len)], segments: 24, material: paint, seamTile: 0.15)
            o.append(turned([(0, len), (0.02, len), (0.02, len + 0.025), (0, len + 0.03)], segments: 5, material: paint, seamTile: 0.1))
            let rot = simd_quatf(from: V3(0, 1, 0), to: dir)
            m.add(o, Xform(translation: V3(0, 0.44, 0) + dir * 0.07, rotation: rot))
        }
        groundAO(&m, height: 0.2, floor: 0.5)
        return LODModel(m)
    }
}
