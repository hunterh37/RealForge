import simd
import Foundation

/// Turned brass candlestick, 43 cm with its candle: stepped domed base, baluster stem with two knops,
/// drip pan (bobeche) and socket, ivory taper burned down a little with a wick and one wax run.
/// Aged brass throughout; seeds vary the stem proportions and how far the candle has burned.
public struct BrassCandlestick: RealAsset {
    public static let id = "brass-candlestick"
    public static let summary = "Turned brass candlestick, 43 cm with its candle: stepped round base, baluster stem with knops, drip pan socket, ivory taper candle."
    public static let tags = ["prop", "decor", "metal", "antique", "handheld"]
    public static let budget = 8000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 12, distance: 1.25, studio: true)

    /// Brass for base, stem and socket.
    public var brass: MaterialKey = "metal.brass-aged"
    /// Candle wax.
    public var wax: MaterialKey = "plastic.matte:EFE7D4"
    /// Base radius (m).
    public var baseRadius: Float = 0.06
    /// Holder height to the socket rim (m).
    public var holderHeight: Float = 0.26
    /// Unburned candle length (m).
    public var candleLength: Float = 0.18
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = baseRadius, H = holderHeight
        let k = rng.vary(1, 0.04)
        // Base: foot rim, step, dome rising into the stem.
        m.add(turned([(0, 0), (R - 0.002, 0), (R, 0.003), (R, 0.009), (R - 0.004, 0.013), (R * 0.82, 0.015),
                      (R * 0.8, 0.022), (R * 0.72, 0.026), (R * 0.5, 0.042), (R * 0.32, 0.056), (0.016, 0.064)],
                     segments: 48, material: brass))
        // Stem: baluster with two knops, profile scaled by the seed.
        let s0: Float = 0.064, s1 = H - 0.03
        func y(_ t: Float) -> Float { s0 + (s1 - s0) * t }
        m.add(turned([(0.016, y(0)), (0.022, y(0.03)), (0.024, y(0.06)), (0.014, y(0.1)), (0.012, y(0.16)),
                      (0.0165 * k, y(0.28)), (0.024 * k, y(0.36)), (0.0165 * k, y(0.44)), (0.011, y(0.52)),
                      (0.0105, y(0.7)), (0.019, y(0.78)), (0.02, y(0.81)), (0.012, y(0.86)), (0.0115, y(1))],
                     segments: 40, material: brass))
        // Drip pan with rolled lip, then the socket cup.
        m.add(turned([(0, s1 - 0.002), (0.011, s1 - 0.002), (0.042, s1 + 0.004), (0.046, s1 + 0.007), (0.046, s1 + 0.01),
                      (0.043, s1 + 0.011), (0.04, s1 + 0.008), (0.012, s1 + 0.004), (0, s1 + 0.004)],
                     segments: 48, material: brass))
        m.add(turned([(0.012, s1 + 0.003), (0.0135, s1 + 0.006), (0.0128, H - 0.004), (0.0145, H - 0.002), (0.0145, H),
                      (0.0118, H), (0.0112, H - 0.004), (0.0112, s1 + 0.008)], segments: 36, material: brass))
        // Taper: burned down, cupped top, wick, one wax run down the side.
        let cr: Float = 0.0108
        let top = H - 0.012 + candleLength * (1 - rng.vary(0.18, 0.08))
        m.add(turned([(0, s1 + 0.008), (cr, s1 + 0.008), (cr, top - 0.003), (cr * 0.97, top), (cr * 0.75, top - 0.002),
                      (0.002, top - 0.004), (0, top - 0.004)], segments: 32, material: wax))
        m.add(Prim.tube([V3(0, top - 0.005, 0), V3(0.0005, top + 0.004, 0), V3(0.0018, top + 0.009, 0.0004)],
                        radii: [0.0009, 0.0008, 0.0006], sides: 6, seamTile: 0.01, material: "metal.iron"))
        let a = rng.float(0...(2 * Float.pi))
        let dir = V3(cos(a), 0, sin(a))
        let run = (0..<6).map { i -> V3 in
            let t = Float(i) / 5
            return dir * (cr + 0.0012 + 0.0008 * t) + V3(0, top - 0.002 - t * 0.05, 0)
        }
        m.add(Prim.tube(run, radii: [0.0018, 0.0022, 0.002, 0.0021, 0.0025, 0.002], sides: 8, seamTile: 0.02, material: wax))
        groundAO(&m)
        return LODModel(m)
    }
}
