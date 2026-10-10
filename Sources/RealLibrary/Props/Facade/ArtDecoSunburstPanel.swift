import simd
import Foundation

/// Art Deco sunburst panel: a 1.0 x 0.6 m stepped-frame half-sun with 17 radiating brass rays in two
/// lengths, concentric stepped arcs, a rising center disc and chevron corner details on a dark ground.
public struct ArtDecoSunburstPanel: RealAsset {
    public static let id = "art-deco-sunburst-panel"
    public static let summary = "Art Deco sunburst panel 1.0 x 0.6 m: stepped frame, 17 brass rays, concentric arcs, sun disc."
    public static let tags = ["prop", "architecture", "facade", "trim", "metal", "decor"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 6, distance: 1.9)

    public var width: Float = 1.0
    public var rays: Int = 17
    public var brass: MaterialKey = "metal.brass"
    public var ground: MaterialKey = "stone.marble-dark"
    public var frame: MaterialKey = "metal.brass-aged"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, hw = W / 2, H = W * 0.6
        // Stepped back panel and frame.
        for (i, ins) in ([0.0, 0.04, 0.08] as [Float]).enumerated() {
            FA.box(&m, V3(W - ins * 2, H - ins, 0.02), V3(0, (H - ins) / 2, 0.01 + Float(i) * 0.012), i == 2 ? ground : frame, r: 0.003)
        }
        let cx: Float = 0, cy: Float = 0.1, z: Float = 0.045
        // Rays: long and short alternate; each a tapered extruded wedge.
        for k in 0..<rays {
            let a = Float(k) / Float(rays - 1) * .pi
            let long = k % 2 == 0
            let r0: Float = 0.1, r1 = hw * (long ? 0.88 : 0.66)
            let wedge = [V2(r0, -0.012), V2(r1, -0.026), V2(r1 + 0.012, 0), V2(r1, 0.026), V2(r0, 0.012)]
            m.add(Prim.extrude(wedge, depth: 0.008, bevel: 0.001, bevelSegments: 1, material: brass),
                  Xform(translation: V3(cx, cy, z), rotation: FA.q(a * 180 / .pi, FA.Z)))
        }
        // Concentric stepped arcs (half-rings) using torus arcs in the XY plane.
        for (i, r) in [0.12 as Float, 0.16, 0.2].enumerated() {
            m.add(Prim.torus(major: r, minor: 0.006, segments: 28, sides: 6, arc: .pi, material: frame),
                  Xform(translation: V3(cx, cy, z + 0.002 + Float(i) * 0.001), rotation: FA.q(90, FA.X) * FA.q(0, FA.Y)))
        }
        // Sun disc as a half-cylinder rising from the base line.
        m.add(Prim.cylinder(radius: 0.09, height: 0.02, bevel: 0.004, segments: 24, bevelSegments: 1, material: brass), Xform(translation: V3(cx, cy, z + 0.01), rotation: FA.q(90, FA.X)))
        // Corner chevrons.
        for e: Float in [-1, 1] {
            for k in 0..<3 {
                let c = V3(e * (hw - 0.1 - Float(k) * 0.025), H - 0.08 - Float(k) * 0.0, z)
                let chev = [V2(-0.025, 0), V2(0, -0.025), V2(0.025, 0), V2(0.025, 0.01), V2(0, -0.012), V2(-0.025, 0.01)]
                m.add(Prim.extrude(chev, depth: 0.006, bevel: 0.0008, bevelSegments: 1, material: brass), Xform(translation: c + V3(0, Float(k) * -0.03, 0)))
            }
        }
        groundAO(&m, height: 0.08, floor: 0.9)
        return LODModel(FA.centerZ(m))
    }
}
