import simd
import Foundation

/// Bundle of 20 to 36 #5 rebar (16 mm), 3 m cut lengths, lying on two timber dunnage blocks: hexagonal stack,
/// staggered ends, sag between supports, two longitudinal ribs per bar, three wire ties, mill-scale rust.
public struct RebarBundle: RealAsset {
    public static let id = "rebar-bundle"
    public static let summary = "Bundle of 16 mm rebar, 3 m: 20 to 36 rusted bars with sag and staggered ends, wire ties, timber dunnage."
    public static let tags = ["prop", "construction", "metal", "industrial"]
    public static let budget = 12_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 25, elevation: 32, distance: 0.8)

    public var length: Float = 3.0
    public var barDiameter: Float = 0.016
    public var material: MaterialKey = "metal.rebar"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let r = barDiameter / 2, L = length / 2
        let rows = rng.int(4...6)
        let support: Float = 0.12 // dunnage height
        var bars: [(V2, Float, Float, Float)] = [] // (zy center, x offset, sag, phase)
        for row in 0..<rows {
            let n = 8 - row - (row > 2 ? 1 : 0)
            for i in 0..<n {
                let z = (Float(i) - Float(n - 1) / 2) * barDiameter * 1.12 + rng.float(-0.003...0.003)
                let y = support + r + Float(row) * barDiameter * 0.88 + rng.float(0...0.003)
                bars.append((V2(z, y), rng.float(-0.18...0.18), rng.float(0.006...0.02), rng.float(0...6.28)))
            }
        }
        let sx: Float = L * 0.62     // dunnage positions
        func level(sides: Int, step: Float, ties: Bool) -> Model {
            var m = Model(name: Self.id)
            var steel = Surface(material: material)
            for (c, dx, sag, ph) in bars {
                var path: [V3] = []
                let x0 = -L + dx, x1 = L + dx
                var x = x0
                while x < x1 { path.append(V3(x, 0, 0)); x += step }
                path.append(V3(x1, 0, 0))
                path = path.map { p in
                    // Sag between supports, droop past them.
                    let u = p.x / sx
                    let dy = abs(u) < 1 ? -sag * (1 - u * u) : -sag * 0.6 * (abs(u) - 1) * (abs(u) - 1) * 2
                    return V3(p.x, c.y + dy + 0.003 * sin(p.x * 3 + ph), c.x + 0.006 * sin(p.x * 1.7 + ph))
                }
                var tube = Prim.tube(path, radii: path.map { _ in r }, sides: sides, seamTile: 0.05, material: material) { t, _ in
                    // Two longitudinal ribs.
                    let d = min(abs(t - 0.25), abs(t - 0.75))
                    return 1 + 0.12 * max(0, 1 - d * Float(sides) * 0.9)
                }
                // Flat start cap (Prim.tube caps the far end).
                let c0 = tube.add(path[0] - V3(r * 0.2, 0, 0), V3(-1, 0, 0), .zero)
                for k in 0..<UInt32(sides) { tube.tri(c0, k + 1, k) }
                steel.append(tube)
            }
            steel.computeTangents()
            m.add(steel)
            // Dunnage blocks.
            for x in [-sx, sx] {
                m.add(Prim.roundedBox(V3(0.1, support, 0.5), radius: 0.008, bevelSegments: 1, material: "wood.weathered"),
                      Xform(translation: V3(x, support / 2, 0), rotation: simd_quatf(degrees: 90, axis: .up)).jittered(&rng, deg: 2, offset: 0.004))
            }
            if ties {
                let topY = bars.map { $0.0.y }.max()! + r, botY = support
                let halfW = bars.map { abs($0.0.x) }.max()! + r
                for tx in [-L * 0.75, 0, L * 0.75] {
                    let pts = (0..<16).map { k -> V3 in
                        let p = CFKit.superellipse(Float(k) / 16 * 2 * .pi, half: V2(halfW + 0.002, (topY - botY) / 2 + 0.002), power: 2.6)
                        return V3(tx, (topY + botY) / 2 + p.y, p.x)
                    }
                    m.add(CFKit.loop(pts, radius: 0.0012, sides: 4, material: "metal.galvanized"))
                }
            }
            groundAO(&m, height: 0.2, floor: 0.55)
            return m
        }
        return LODModel(levels: [level(sides: 6, step: 0.25, ties: true), level(sides: 4, step: 0.6, ties: false)], switchDistances: [14])
    }
}
