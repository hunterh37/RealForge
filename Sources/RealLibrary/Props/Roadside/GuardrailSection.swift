import simd
import Foundation

/// W-beam highway guardrail, one 3.81 m panel on three steel posts with blockouts and a reflector.
public struct GuardrailSection: RealAsset {
    public static let id = "guardrail-section"
    public static let summary = "3.81 m W-beam steel guardrail with three steel posts at 1.905 m, blocked out, rail top at 0.76 m, galvanized with a round reflector."
    public static let tags = ["prop", "road", "barrier", "metal", "outdoor"]
    public static let budget = 8000
    public static let author = "realityhd"

    /// Panel length along X in meters.
    public var length: Float = 3.81
    /// Top of the rail above the road in meters.
    public var topHeight: Float = 0.76
    /// Rail galvanizing.
    public var railMaterial = "metal.galvanized-aged"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let Lr = length
        let hc: Float = topHeight - 0.156           // rail centre height (W-beam is 0.312 tall)
        let zr: Float = 0.26                        // rail face relative to the post centre line, toward the road (+Z)
        let th: Float = 0.0035
        // W-beam section: (depth toward road, height from centre).
        let wz: [(Float, Float)] = [(0, 0.156), (0, 0.13), (0.0825, 0.098), (0.0825, 0.072), (0, 0.04), (0, -0.04),
                                    (0.0825, -0.072), (0.0825, -0.098), (0, -0.13), (0, -0.156)]
        var outline: [V2] = wz.map { V2(-$0.0, $0.1) }
        outline += wz.reversed().map { V2(-($0.0 + th), $0.1) }
        // Outline X maps to world -Z after the yaw, so the wave bulges toward +Z... mirrored above to compensate.
        m.add(Prim.extrude(outline, depth: Lr, bevel: 0.0008, bevelSegments: 1, material: railMaterial),
              Xform(translation: V3(0, hc, zr), rotation: simd_quatf(degrees: 90, axis: .up)))
        // Splice overlap bolts at the right end.
        let boltY: [Float] = [-0.1, 0.1]
        for k in 0..<4 {
            let x: Float = Lr / 2 - 0.12 + Float(k) * 0.025
            for dy in [Float(-0.085), 0.085] {
                m.add(Prim.cylinder(radius: 0.0095, height: 0.007, bevel: 0.0025, segments: 8, material: "metal.galvanized"),
                      Xform(translation: V3(x, hc + dy, zr + 0.0865), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            }
        }
        // Three W6x9 posts with blockouts.
        let postXs: [Float] = [-Lr / 2 + 0.02, 0, Lr / 2 - 0.02]
        let h: Float = 0.92, flange: Float = 0.1, web: Float = 0.15, t: Float = 0.007
        let cy0: Float = h / 2
        for px in postXs {
            m.add(Prim.roundedBox(V3(flange, h, t), radius: 0.0015, bevelSegments: 1, material: "metal.galvanized"), Xform(translation: V3(px, cy0, 0.04 - web / 2)))
            m.add(Prim.roundedBox(V3(flange, h, t), radius: 0.0015, bevelSegments: 1, material: "metal.galvanized"), Xform(translation: V3(px, cy0, 0.04 + web / 2)))
            m.add(Prim.roundedBox(V3(t, h, web), radius: 0.0015, bevelSegments: 1, material: "metal.galvanized"), Xform(translation: V3(px, cy0, 0.04)))
            m.add(Prim.roundedBox(V3(0.2, 0.3, 0.14), radius: 0.004, bevelSegments: 2, material: "wood.pine-aged"), Xform(translation: V3(px, hc, 0.04 + web / 2 + 0.07)))
            m.add(Prim.cylinder(radius: 0.0095, height: 0.008, bevel: 0.003, segments: 8, material: "metal.galvanized"),
                  Xform(translation: V3(px, hc, zr + 0.0865), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            m.add(Prim.superellipsoid(V3(0.24, 0.06, 0.34), exponent: 3, subdivisions: 5, material: "soil.potting"), Xform(translation: V3(px, 0.03, 0.04)))
        }
        // Round orange reflector.
        m.add(Prim.cylinder(radius: 0.038, height: 0.006, bevel: 0.0015, segments: 20, material: "plastic.orange"),
              Xform(translation: V3(0, hc + 0.1, zr + 0.0885), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        let bb = m.bounds
        m = m.transformed(Xform(translation: V3(0, 0, -(bb.min.z + bb.max.z) / 2)))
        groundAO(&m, height: 0.1, floor: 0.6)
        return LODModel(m)
    }
}
