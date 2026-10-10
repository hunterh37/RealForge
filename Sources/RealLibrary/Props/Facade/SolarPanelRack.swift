import simd
import Foundation

/// Roof solar rack: three framed monocrystalline panels (1.0 m x 1.7 m) pitched 20 degrees on two
/// aluminum rails and four feet with cell grid lines and busbars. Sits on y = 0, centered.
public struct SolarPanelRack: RealAsset {
    public static let id = "solar-panel-rack"
    public static let summary = "Roof solar rack, 3.1 m: three framed monocrystalline panels at 20 degrees on aluminum rails and feet."
    public static let tags = ["prop", "architecture", "facade", "roof", "metal", "glass"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 25, distance: 4.0)

    public var panels = 3
    public var panelWidth: Float = 1.0
    public var panelLength: Float = 1.7
    public var tilt: Float = 20
    public var frame: MaterialKey = "metal.anodized"
    public var cells: MaterialKey = "glass.tinted"
    public var foot: MaterialKey = "metal.galvanized"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let n = panels, pw = panelWidth, pl = panelLength, W = Float(n) * (pw + 0.02) - 0.02
        let lowY: Float = 0.3, c = cos(tilt * .pi / 180), s = sin(tilt * .pi / 180)
        let dz = pl * c / 2
        let rot = FA.q(-tilt, FA.X)
        for i in 0..<n {
            let x = -W / 2 + pw / 2 + Float(i) * (pw + 0.02)
            let ctr = V3(x, lowY + pl * s / 2 + 0.02, 0.0)
            func put(_ size: V3, _ local: V3, _ mat: MaterialKey, r: Float = 0.002) {
                let p = ctr + simd_act(rot, local)
                FA.box(&m, size, p, mat, r: r, rot: rot)
            }
            put(V3(pw, 0.035, 0.035), V3(0, 0, -pl / 2 + 0.0175), frame)
            put(V3(pw, 0.035, 0.035), V3(0, 0, pl / 2 - 0.0175), frame)
            for e: Float in [-1, 1] { put(V3(0.035, 0.035, pl), V3(e * (pw / 2 - 0.0175), 0, 0), frame) }
            put(V3(pw - 0.06, 0.006, pl - 0.06), V3(0, 0.012, 0), cells, r: 0.001)
            put(V3(pw - 0.07, 0.004, pl - 0.07), V3(0, 0.008, 0), "plastic.black", r: 0.001)
            for k in 1..<6 { put(V3(0.0025, 0.002, pl - 0.08), V3(-pw / 2 + 0.035 + Float(k) * (pw - 0.07) / 6, 0.016, 0), "metal.aluminum-brushed", r: 0.0005) }
            for k in 1..<10 { put(V3(pw - 0.08, 0.002, 0.0015), V3(0, 0.016, -pl / 2 + 0.04 + Float(k) * (pl - 0.08) / 10), "metal.aluminum-brushed", r: 0.0005) }
            put(V3(0.1, 0.02, 0.06), V3(0.2 + rng.float(-0.01...0.01), -0.028, pl / 2 - 0.2), "plastic.black", r: 0.004)
        }
        // Rails and feet.
        for t: Float in [0.22, 0.78] {
            let zc = -dz + t * 2 * dz, yc = lowY + t * pl * s - 0.0
            FA.box(&m, V3(W + 0.1, 0.04, 0.04), V3(0, yc - 0.0, zc), frame, r: 0.003)
            for x in [-W / 2 + 0.25, W / 2 - 0.25] {
                FA.rod(&m, V3(x, 0.0, zc), V3(x, yc, zc), r: 0.015, foot, sides: 8)
                FA.box(&m, V3(0.12, 0.012, 0.12), V3(x, 0.006, zc), foot, r: 0.002)
            }
        }
        groundAO(&m, height: 0.12, floor: 0.8)
        return LODModel(FA.centerZ(m))
    }
}
