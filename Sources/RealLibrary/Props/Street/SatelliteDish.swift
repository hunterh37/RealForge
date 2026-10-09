import simd
import Foundation

public struct SatelliteDish: RealAsset {
    public static let id = "satellite-dish"
    public static let summary = "Offset satellite dish, 0.8 m, parabolic white shell on a galvanized mast arm with LNB."
    public static let tags = ["prop", "urban", "outdoor", "metal"]
    public static let budget = 3500
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        cy(&m, 0.04, 1.0, V3(0,0,0), "metal.galvanized", seg: 16)
        var prof: [(Float,Float)] = []
        for i in 0...10 { let r = Float(i)/10*0.4; prof.append((r, r*r*1.1)) }
        m.add(turned(prof, segments: 36, material: "plastic.white", seamTile: 0.5), Xform(translation: V3(0,1.1,-0.14), rotation: simd_quatf(degrees: 70, axis: V3(1,0,0))))
        rod(&m, V3(0,1.0,0), V3(0,1.1,-0.14), 0.012, "metal.galvanized"); rod(&m, V3(0,1.15,-0.14), V3(0,1.24,0.18), 0.008, "metal.galvanized")
        cy(&m, 0.02, 0.06, V3(0,1.24,0.18), "plastic.black", seg: 12)
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
