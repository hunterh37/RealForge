import simd
import Foundation

/// Two-seat swing set, 2.4 m high and 3.2 m wide: galvanized A-frame legs, top beam, chains and rubber belt seats.
public struct SwingSet: RealAsset {
    public static let id = "swing-set"
    public static let summary = "Two-seat swing set, 2.4 m high: galvanized A-frame legs, top beam, chains and rubber belt seats."
    public static let tags = ["prop", "playground", "park", "outdoor", "metal"]
    public static let budget = 2300
    public static let author = "hunterh37"

    /// Seat count.
    public var seats = 2
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let n = max(1, seats), W = 1.6 * Float(n), top: Float = 2.4, mat: MaterialKey = "metal.galvanized"
        for x: Float in [-W / 2, W / 2] {
            for z: Float in [-0.9, 0.9] { rod(&m, V3(x, 0, z), V3(x, top, 0), 0.04, mat, sides: 14) }
            bx(&m, V3(0.1, 0.012, 0.3), V3(x, 0.006, 0.9), "metal.galvanized", r: 0.003)
            bx(&m, V3(0.1, 0.012, 0.3), V3(x, 0.006, -0.9), "metal.galvanized", r: 0.003)
        }
        rod(&m, V3(-W / 2 - 0.15, top, 0), V3(W / 2 + 0.15, top, 0), 0.04, mat, sides: 14)
        for i in 0..<n {
            let x = -W / 2 + W * (Float(i) + 0.5) / Float(n), sw = rng.float(-0.08...0.08)
            for dx: Float in [-0.2, 0.2] {
                rod(&m, V3(x + dx * 0.4, top - 0.03, 0), V3(x + dx, 0.52, sw), 0.006, "metal.steel", sides: 6)
            }
            m.add(Prim.roundedBox(V3(0.44, 0.04, 0.17), radius: 0.015, material: "rubber.tire"), Xform(translation: V3(x, 0.5, sw)))
        }
        return K.finish(&m, ao: 0.2)
    }
}
