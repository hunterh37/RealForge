import simd
import Foundation

/// Dentil cornice: a classical crown with bed mould, a row of 40 mm square dentils at 80 mm pitch, an
/// egg-and-dart band and a projecting corona with drip, 2.0 m long, in painted wood.
public struct DentilCornice: RealAsset {
    public static let id = "dentil-cornice"
    public static let summary = "Dentil cornice, 2.0 m: bed mould, 25 dentils, egg-and-dart band, corona and crown."
    public static let tags = ["prop", "architecture", "facade", "trim", "wood"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 15, distance: 3.2)

    public var length: Float = 2.0
    public var dentilPitch: Float = 0.08
    public var paint: MaterialKey = "wood.barn-white"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let L = length
        // Frieze board, bed mould, corona and crown as profiles (x out from the wall, y up).
        FA.run(&m, [V2(0, 0), V2(0.015, 0), V2(0.015, 0.16), V2(0, 0.16)], length: L, paint, bevel: 0.002)
        let bed = [V2(0.0, 0.16), V2(0.05, 0.16), V2(0.065, 0.175), V2(0.065, 0.195), V2(0.0, 0.195)]
        FA.run(&m, bed, length: L, paint, bevel: 0.002)
        let corona = [V2(0.0, 0.195), V2(0.17, 0.195), V2(0.175, 0.205), V2(0.175, 0.235), V2(0.15, 0.245), V2(0.0, 0.245)]
        FA.run(&m, corona, length: L, paint, bevel: 0.002)
        let crown = [V2(0.0, 0.245), V2(0.12, 0.25), V2(0.19, 0.28), V2(0.215, 0.32), V2(0.2, 0.34), V2(0.0, 0.34)]
        FA.run(&m, crown, length: L, paint, bevel: 0.003)
        let n = Int(L / dentilPitch) - 1
        for i in 0..<n {
            let x = -Float(n - 1) * dentilPitch / 2 + Float(i) * dentilPitch
            FA.box(&m, V3(0.04, 0.05, 0.05), V3(x, 0.133, 0.04), paint, r: 0.002)
        }
        // Egg-and-dart band under the corona.
        let m2 = Int(L / 0.06) - 1
        for i in 0..<m2 {
            let x = -Float(m2 - 1) * 0.06 / 2 + Float(i) * 0.06
            m.add(Prim.superellipsoid(V3(0.028, 0.034, 0.02), exponent: 2, subdivisions: 3, material: paint), Xform(translation: V3(x, 0.178, 0.07)))
        }
        groundAO(&m, height: 0.08, floor: 0.9)
        return LODModel(FA.centerZ(m))
    }
}
