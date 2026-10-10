import simd
import Foundation

/// Roof-mounted solar array, three 1.7 x 1.0 m modules tilted 30 degrees on aluminum rails with cell grid and frame.
public struct SolarPanelArray: RealAsset {
    public static let id = "solar-panel-array"
    public static let summary = "Solar array: three 1.7 x 1.0 m framed modules tilted 30 degrees on aluminum rails and legs."
    public static let tags = ["prop", "roof", "building", "glass", "metal"]
    public static let budget = 4200
    public static let author = "hunterh37"

    /// Module count in a row.
    public var modules = 3
    /// Tilt in degrees.
    public var tilt: Float = 30
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let n = max(1, modules), pw: Float = 1.0, pl: Float = 1.7, rot = simd_quatf(degrees: tilt, axis: V3(1, 0, 0))
        let W = Float(n) * (pw + 0.02), lowY: Float = 0.3, mid = V3(0, lowY + pl / 2 * sin(tilt * .pi / 180), 0)
        for i in 0..<n {
            let x = -W / 2 + (Float(i) + 0.5) * (pw + 0.02)
            m.add(Prim.roundedBox(V3(pw, 0.035, pl), radius: 0.006, material: "metal.anodized"), Xform(translation: mid + V3(x, 0, 0), rotation: rot))
            m.add(Prim.roundedBox(V3(pw - 0.05, 0.004, pl - 0.05), radius: 0.001, bevelSegments: 1, material: "glass.tinted"),
                  Xform(translation: mid + V3(x, 0.019, 0) + rot.act(V3(0, 0.002, 0)), rotation: rot))
            for c in 1..<6 {
                let z = -pl / 2 + 0.025 + (pl - 0.05) * Float(c) / 6
                m.add(Prim.roundedBox(V3(pw - 0.05, 0.002, 0.004), radius: 0.001, bevelSegments: 1, material: "metal.aluminum-brushed"),
                      Xform(translation: mid + V3(x, 0, 0) + rot.act(V3(0, 0.0235, z)), rotation: rot))
            }
        }
        for x: Float in [-W / 2 + 0.2, W / 2 - 0.2] {
            let hi = mid + rot.act(V3(0, -0.018, -pl * 0.4)), lo = mid + rot.act(V3(0, -0.018, pl * 0.4))
            rod(&m, V3(x, 0, hi.z), V3(x, hi.y, hi.z), 0.015, "metal.aluminum-brushed", sides: 8)
            rod(&m, V3(x, 0, lo.z), V3(x, lo.y, lo.z), 0.015, "metal.aluminum-brushed", sides: 8)
            rod(&m, V3(x, hi.y, hi.z), V3(x, lo.y, lo.z), 0.015, "metal.aluminum-brushed", sides: 8)
        }
        return K.finish(&m, ao: 0.1)
    }
}
