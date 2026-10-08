import simd
import Foundation

/// Cobblestone tile on the 3 m city grid: granite setts about 16 x 11 cm laid in running-bond rows
/// along X on a dark grit bed. Every sett is its own worn, domed block with seeded size, tilt and
/// tone. Top y ~ 0.25 so it sits flush with sidewalk and plaza tiles.
public struct CobblestoneTile: RealAsset {
    public static let id = "cobblestone-tile"
    public static let summary = "Cobblestone tile, 3 x 3 m snap cell: rows of worn granite setts with dark grit joints, sidewalk height."
    public static let tags = ["structure", "city", "street", "road", "tile", "outdoor", "stone"]
    public static let budget = 24000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 35, distance: 1.0)

    /// Cell edge length (m).
    public var cell: Float = CityGrid.walkCell
    /// Top of the setts (m).
    public var top: Float = CityGrid.walkTop
    /// Sett length along the row (X) and width across (Z) (m).
    public var settLength: Float = 0.16
    public var settWidth: Float = 0.11
    /// Joint width (m).
    public var joint: Float = 0.014
    /// Exposed sett height above the grit (m).
    public var exposed: Float = 0.035
    /// Sett tones (sRGB hex).
    public var tones: [UInt32] = [0x77746F, 0x6A6763, 0x84807A, 0x5E5B57]
    /// Sett and joint materials.
    public var stone: MaterialKey = "stone.granite-curb"
    public var grit: MaterialKey = "ground.sand:4A453E"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let h = cell / 2, bed = top - exposed
        citySlab(&m, x: cell - 0.03, z: cell - 0.03, top: bed + 0.01, material: grit)
        let keys = tones.map { "\(stone):\(String(format: "%06X", $0))" }
        let pitchZ = settWidth + joint, rows = Int(cell / pitchZ)
        let rowGap = (cell - Float(rows) * pitchZ) / Float(rows)
        for r in 0..<rows {
            let z = -h + (pitchZ + rowGap) * (Float(r) + 0.5)
            var x = -h + (r % 2 == 0 ? 0 : -settLength / 2) + rng.float(0...0.03)
            while x < h {
                let len = settLength * rng.float(0.85...1.15)
                let x0 = max(-h, x) + joint / 2, x1 = min(h, x + len) - joint / 2
                x += len + joint
                guard x1 - x0 > 0.04 else { continue }
                let w = settWidth * rng.float(0.92...1.04)
                let tall = exposed + 0.04 + rng.float(-0.006...0.004)
                var s = Prim.superellipsoid(V3(x1 - x0, tall, w), exponent: rng.float(5...7.5), subdivisions: 2,
                                            material: keys[rng.int(0...(keys.count - 1))])
                let off = V2(rng.float(0...7), rng.float(0...7))
                for v in s.positions.indices { s.uvs[v] = V2(s.positions[v].x + off.x, s.positions[v].z + s.positions[v].y + off.y) }
                s.computeTangents()
                let tilt = simd_quatf(angle: rng.float(-0.06...0.06), axis: V3(0, 1, 0)) * simd_quatf(angle: rng.float(-0.04...0.04), axis: V3(1, 0, 0)) * simd_quatf(angle: rng.float(-0.03...0.03), axis: V3(0, 0, 1))
                m.add(s, Xform(translation: V3((x0 + x1) / 2, top - tall / 2 + rng.float(-0.004...0.002), z + rng.float(-0.004...0.004)), rotation: tilt))
            }
        }
        groundAO(&m, height: 0.06, floor: 0.7)
        return LODModel(m)
    }
}
