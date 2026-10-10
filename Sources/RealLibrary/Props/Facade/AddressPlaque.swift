import simd
import Foundation

/// House number plaque: aged brass backing with a raised rim and bright block numerals built from
/// seven-segment bars, held on four stainless pins. Default reads 127.
public struct AddressPlaque: RealAsset {
    public static let id = "address-plaque"
    public static let summary = "House number plaque, 0.36 m: cast brass backing with raised block numerals on stainless pins."
    public static let tags = ["prop", "architecture", "facade", "trim", "metal"]
    public static let budget = 5_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 8, distance: 0.6)

    /// Digits to show, 0...9 each.
    public var digits = [1, 2, 7]
    public var backing: MaterialKey = "metal.brass-aged"
    public var numerals: MaterialKey = "metal.brass"
    public var pins: MaterialKey = "metal.stainless"
    public init() {}

    // Segments a b c d e f g for each digit.
    static let seg: [[Bool]] = [
        [1, 1, 1, 1, 1, 1, 0], [0, 1, 1, 0, 0, 0, 0], [1, 1, 0, 1, 1, 0, 1], [1, 1, 1, 1, 0, 0, 1], [0, 1, 1, 0, 0, 1, 1],
        [1, 0, 1, 1, 0, 1, 1], [1, 0, 1, 1, 1, 1, 1], [1, 1, 1, 0, 0, 0, 0], [1, 1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 0, 1, 1],
    ].map { $0.map { $0 == 1 } }

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let n = max(1, digits.count)
        let dw: Float = 0.07, dh: Float = 0.11, sp: Float = 0.088, bar: Float = 0.014
        let W = Float(n) * sp + 0.12, H: Float = 0.18, y0: Float = 0.0
        FA.box(&m, V3(W, H, 0.01), V3(0, y0 + H / 2, 0.005), backing, r: 0.004)
        for e: Float in [-1, 1] { FA.box(&m, V3(W, 0.012, 0.006), V3(0, y0 + H / 2 + e * (H / 2 - 0.006), 0.012), backing, r: 0.002) }
        for e: Float in [-1, 1] { FA.box(&m, V3(0.012, H - 0.024, 0.006), V3(e * (W / 2 - 0.006), y0 + H / 2, 0.012), backing, r: 0.002) }
        for (i, d) in digits.enumerated() {
            let cx = (Float(i) - Float(n - 1) / 2) * sp, cy = y0 + H / 2
            let s = Self.seg[max(0, min(9, d))]
            let pos: [(Float, Float, Bool)] = [(0, dh / 2, true), (dw / 2, dh / 4, false), (dw / 2, -dh / 4, false), (0, -dh / 2, true),
                                              (-dw / 2, -dh / 4, false), (-dw / 2, dh / 4, false), (0, 0, true)]
            for (k, on) in s.enumerated() where on {
                let (px, py, horiz) = pos[k]
                FA.box(&m, horiz ? V3(dw, bar, 0.012) : V3(bar, dh / 2, 0.012), V3(cx + px, cy + py, 0.016), numerals, r: 0.003)
            }
        }
        for sx: Float in [-1, 1] { for sy: Float in [-1, 1] {
            FA.cylZ(&m, r: 0.004, h: 0.012, at: V3(sx * (W / 2 - 0.02), y0 + H / 2 + sy * (H / 2 - 0.02), 0.0), pins, bevel: 0.001, segments: 10)
        }}
        return LODModel(FA.centerZ(m))
    }
}
