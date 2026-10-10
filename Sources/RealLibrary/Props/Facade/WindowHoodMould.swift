import simd
import Foundation

/// Victorian window hood mould: a projecting label moulding over a 1.1 m opening that steps down in
/// vertical returns, ending in carved stops; a stone keyblock sits at the crown.
public struct WindowHoodMould: RealAsset {
    public static let id = "window-hood-mould"
    public static let summary = "Window hood mould, 1.1 m: arched label moulding with returns, carved stops and crown keyblock."
    public static let tags = ["prop", "architecture", "facade", "trim", "stone"]
    public static let budget = 8_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 22, elevation: 8, distance: 2.0)

    public var width: Float = 1.1
    public var returnLength: Float = 0.5
    public var stone: MaterialKey = "stone.sandstone"
    public var accent: MaterialKey = "stone.limestone"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, L = returnLength
        let pts = FC.archPath(width: W, spring: 0, pointed: false, z: 0.05, steps: 16)
            .map { V3($0.x, $0.y + L, $0.z) }
        let path = [V3(pts[0].x, 0, 0.05)] + pts + [V3(pts[pts.count - 1].x, 0, 0.05)]
        FA.path(&m, path, r: 0.04, stone, sides: 10)
        FA.path(&m, path.map { $0 + V3(0, 0, -0.012) }, r: 0.056, stone, sides: 8)
        for e: Float in [-1, 1] {
            // Carved stop: a squashed boss with a rosette.
            let c = V3(e * (W / 2), 0.0, 0.07)
            m.add(Prim.superellipsoid(V3(0.12, 0.12, 0.07), exponent: 2, subdivisions: 4, material: accent), Xform(translation: c + V3(0, 0.06, 0)))
            m.add(Prim.torus(major: 0.03, minor: 0.008, segments: 12, sides: 5, material: stone), Xform(translation: c + V3(0, 0.06, 0.03), rotation: FA.q(90, FA.X)))
        }
        let crownY = L + W / 2 + 0.04
        FA.box(&m, V3(0.1, 0.16 + rng.float(0...0.004), 0.1), V3(0, crownY, 0.06), accent, r: 0.006)
        FA.box(&m, V3(0.15, 0.03, 0.12), V3(0, crownY + 0.095, 0.06), accent, r: 0.004)
        groundAO(&m, height: 0.1, floor: 0.85)
        return LODModel(FC.seatY(m))
    }
}
