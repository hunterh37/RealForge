import simd
import Foundation

public struct BasketballHoop: RealAsset {
    public static let id = "basketball-hoop"
    public static let summary = "Driveway basketball hoop, 3.05 m rim: square pole, arm, 1.37 m backboard, orange rim and net."
    public static let tags = ["prop", "landscaping", "outdoor", "sports", "metal"]
    public static let budget = 9000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let b = "metal.powdercoat"
        m.add(Prim.cylinder(radius: 0.25, height: 0.04, bevel: 0.01, segments: 24, material: "concrete.smooth"))
        K.box(&m, V3(0, 1.6, 0), V3(0.12, 3.2, 0.12), b, bevel: 0.01)
        K.rod(&m, [V3(0, 2.9, 0.06), V3(0, 2.95, 0.5), V3(0, 3.0, 1.0)], r: 0.035, b, sides: 10)
        K.box(&m, V3(0, 3.2, 1.05), V3(1.37, 0.9, 0.03), "plastic.clear")
        K.box(&m, V3(0, 3.1, 1.075), V3(0.6, 0.45, 0.005), "plastic.white")
        K.rod(&m, K.arc(V3(0, 0, 0), 0.23, 0, 360, n: 28).map { V3($0.x, 3.05, 1.3 + $0.y) }, r: 0.008, "metal.fire-extinguisher-red", sides: 6)
        for i in 0..<12 {
            let a = Float(i) / 12 * 2 * .pi
            K.rod(&m, [V3(cos(a) * 0.23, 3.05, 1.3 + sin(a) * 0.23), V3(cos(a) * 0.15, 2.85, 1.3 + sin(a) * 0.15), V3(cos(a + 0.3) * 0.14, 2.7, 1.3 + sin(a + 0.3) * 0.14)], r: 0.0015, "plastic.white", sides: 4)
        }
        return K.finish(&m)
    }
}
