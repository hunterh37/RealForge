import simd
import Foundation

/// Semicircular fanlight over a door: painted timber frame, eleven radiating bars, two concentric
/// astragal rings, a keystone and a glazed fan. Wall plane at z = 0, spring line at y = 0.
public struct FanlightTransom: RealAsset {
    public static let id = "fanlight-transom"
    public static let summary = "Semicircular fanlight, 1.2 m wide: painted frame, 11 radiating glazing bars, astragal rings, keystone."
    public static let tags = ["prop", "architecture", "facade", "window", "door", "wood", "glass"]
    public static let budget = 3500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 8, distance: 2.0)

    public var width: Float = 1.2
    public var bars: Int = 11
    public var frame: MaterialKey = "wood.painted-exterior"
    public var glass: MaterialKey = "glass.pane"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let R = width / 2, depth: Float = 0.08
        // Glazed fan.
        var fan: [V2] = [V2(-R, 0)]
        for i in 0...32 { let a = Float.pi - Float(i) / 32 * .pi; fan.append(V2(cos(a) * (R - 0.04), sin(a) * (R - 0.04))) }
        fan = Shape2D.deduped(fan)
        m.add(Prim.extrude(fan, depth: 0.012, bevel: 0.001, bevelSegments: 1, material: glass), Xform(translation: V3(0, 0.0, 0.04)))
        // Frame arc as a swept bead plus the sill rail.
        let arc: [V3] = (0...36).map { i in let a = Float(i) / 36 * .pi; return V3(cos(a) * (R - 0.025), sin(a) * (R - 0.025), 0.04) }
        m.add(Prim.sweep([V2(-0.025, -0.02), V2(0.025, -0.02), V2(0.025, 0.02), V2(-0.025, 0.02)], along: arc, up: FA.Z, material: frame))
        FA.box(&m, V3(width, 0.05, depth), V3(0, 0.0, depth / 2), frame, r: 0.004)
        for k in 0..<bars {
            let a = Float(k + 1) / Float(bars + 1) * .pi
            FA.box(&m, V3(R - 0.06, 0.016, 0.03), V3(cos(a), sin(a), 0) * ((R - 0.06) / 2 + 0.03) + V3(0, 0, 0.045), frame, r: 0.002,
                   rot: FA.q(a * 180 / .pi, FA.Z))
        }
        for f: Float in [0.38, 0.7] {
            m.add(Prim.torus(major: R * f, minor: 0.008, segments: 28, sides: 6, arc: .pi, material: frame),
                  Xform(translation: V3(0, 0, 0.05), rotation: FA.q(90, FA.X)))
        }
        FC.bead(&m, r: 0.045, at: V3(0, 0.035, 0.05), frame)
        FA.box(&m, V3(0.1, 0.12, 0.04), V3(0, R, 0.04), "stone.cast-stone", r: 0.004)
        groundAO(&m, height: 0.1, floor: 0.9)
        return LODModel(FC.place(m))
    }
}
