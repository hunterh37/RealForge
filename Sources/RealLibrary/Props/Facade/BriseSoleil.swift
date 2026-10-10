import simd
import Foundation

/// Brise-soleil: seven horizontal airfoil blades of extruded anodized aluminum tilted 22 degrees, held
/// between two end plates and three wall outriggers each side.
public struct BriseSoleil: RealAsset {
    public static let id = "brise-soleil"
    public static let summary = "Horizontal sun-shading louvers, 2.2 m: extruded aluminum airfoil blades on outrigger brackets."
    public static let tags = ["prop", "architecture", "facade", "metal"]
    public static let budget = 9_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 40, elevation: 12, distance: 2.4)

    public var width: Float = 2.2
    public var height: Float = 1.6
    public var blades = 7
    /// Blade chord (m) and thickness (m); tilt in degrees.
    public var chord: Float = 0.32
    public var thickness: Float = 0.04
    public var tilt: Float = 22
    public var blade: MaterialKey = "metal.anodized"
    public var bracket: MaterialKey = "metal.anodized-black"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, H = height, c = chord
        let pitch = (H - 0.2) / Float(blades - 1)
        let outline = Shape2D.superellipse(c, thickness, exponent: 2.6, segments: 24).map { V2($0.x + c / 2 + 0.12, $0.y) }
        for i in 0..<blades {
            let y = 0.1 + Float(i) * pitch
            m.add(Prim.extrude(outline, depth: W - 0.06, bevel: 0.002, bevelSegments: 1, material: blade),
                  Xform(translation: V3(0, y, 0), rotation: FA.q(-90, FA.Y) * FA.q(-tilt, FA.Z)))
        }
        for e: Float in [-1, 1] {
            let x = e * (W / 2 - 0.015)
            FA.box(&m, V3(0.03, H, 0.5), V3(x, H / 2, 0.37), bracket, r: 0.004)
            for y in [0.1, H / 2, H - 0.1] {
                FA.rod(&m, V3(x, y, 0.0), V3(x, y, 0.12), r: 0.012, bracket)
                FA.box(&m, V3(0.05, 0.05, 0.012), V3(x, y, 0.006), bracket, r: 0.002)
            }
        }
        groundAO(&m, height: 0.12, floor: 0.8)
        return LODModel(FA.centerZ(m))
    }
}
