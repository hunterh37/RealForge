import simd
import Foundation

/// Door pediment hood: a flat entablature with a dentil bed and a triangular pediment with a recessed
/// tympanum, carried on two scrolled console brackets. Painted wood with a faded finish.
public struct DoorPedimentHood: RealAsset {
    public static let id = "door-pediment-hood"
    public static let summary = "Door pediment hood, 1.5 m: triangular pediment with dentil bed on two scroll consoles."
    public static let tags = ["prop", "architecture", "facade", "trim", "wood"]
    public static let budget = 9_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 12, distance: 1.8)

    public var width: Float = 1.5
    public var projection: Float = 0.3
    public var pediment: Float = 0.3
    public var paint: MaterialKey = "wood.painted-exterior"
    public var shadow: MaterialKey = "wood.painted-exterior:C9C2B2"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, P = projection, base: Float = 0.30, ent: Float = 0.08
        // Console brackets: scroll profile in (out, up).
        let prof = Shape2D.rounded([V2(0, 0.02), V2(0.012, base), V2(P * 0.9, base), V2(P * 0.9, base - 0.05), V2(P * 0.55, base - 0.1),
                                   V2(P * 0.38, base - 0.2), V2(P * 0.3, 0.0), V2(0.07, 0)], radius: 0.012)
        for e: Float in [-1, 1] {
            FA.side(&m, prof, thick: 0.1, at: V3(e * (W / 2 - 0.12), 0, 0), paint)
            m.add(Prim.torus(major: 0.035, minor: 0.012, segments: 16, sides: 8, material: paint),
                  Xform(translation: V3(e * (W / 2 - 0.12) + e * 0.052, base - 0.1, P * 0.45), rotation: FA.q(90, FA.Z)))
        }
        // Entablature and dentils.
        FA.box(&m, V3(W, ent, P), V3(0, base + ent / 2, P / 2), paint, r: 0.004)
        FA.box(&m, V3(W + 0.06, 0.03, P + 0.04), V3(0, base + ent + 0.015, P / 2 + 0.01), paint, r: 0.004)
        let n = Int((W - 0.2) / 0.05)
        for i in 0..<n {
            let x = -(Float(n - 1) * 0.05) / 2 + Float(i) * 0.05
            FA.box(&m, V3(0.028, 0.04, 0.03), V3(x, base - 0.02, P - 0.015), shadow, r: 0.002)
        }
        // Pediment.
        let top = base + ent + 0.03
        let tri = [V2(-W / 2 - 0.03, 0), V2(W / 2 + 0.03, 0), V2(0, pediment)]
        m.add(Prim.extrude(tri, depth: 0.05, bevel: 0.003, bevelSegments: 1, material: paint), Xform(translation: V3(0, top, P - 0.025)))
        let inset = [V2(-W / 2 + 0.1, 0.02), V2(W / 2 - 0.1, 0.02), V2(0, pediment - 0.08)]
        m.add(Prim.extrude(inset, depth: 0.03, bevel: 0.002, bevelSegments: 1, material: shadow), Xform(translation: V3(0, top, P - 0.065)))
        let ang = atan2(pediment, W / 2 + 0.03) * 180 / .pi
        let rl = ((W / 2 + 0.03) * (W / 2 + 0.03) + pediment * pediment).squareRoot()
        for e: Float in [-1, 1] {
            FA.box(&m, V3(rl, 0.045, 0.07), V3(e * (W / 4 + 0.015), top + pediment / 2 + 0.01, P - 0.03), paint, r: 0.004, rot: FA.q(e * -ang, FA.Z))
        }
        groundAO(&m, height: 0.1, floor: 0.8)
        return LODModel(FA.centerZ(m))
    }
}
