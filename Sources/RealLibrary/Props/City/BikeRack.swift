import simd
import Foundation

/// Inverted-U bike rack: three 48 mm galvanized pipe hoops welded to a flat steel rail with bolted
/// base plates. Hoop tops are scuffed bright where locks and frames rub.
public struct BikeRack: RealAsset {
    public static let id = "bike-rack"
    public static let summary = "Inverted-U bike rack: three galvanized steel pipe hoops on a surface-mount rail."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "metal"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 15, distance: 1.1)

    /// Number of hoops.
    public var hoops = 3
    /// Hoop spacing along X (m).
    public var spacing: Float = 0.7
    /// Hoop width and height (m).
    public var hoopWidth: Float = 0.5
    public var height: Float = 0.9
    /// Pipe radius (m).
    public var pipe: Float = 0.024
    /// Materials.
    public var steel: MaterialKey = "metal.galvanized"
    public var worn: MaterialKey = "metal.galvanized-aged"
    public var bolts: MaterialKey = "metal.steel"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let span = Float(hoops - 1) * spacing, railLen = span + hoopWidth + 0.1
        m.add(Prim.roundedBox(V3(railLen, 0.012, 0.08), radius: 0.003, bevelSegments: 1, material: worn), Xform(translation: V3(0, 0.006, 0)))
        for e: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.1, 0.008, 0.12), radius: 0.003, bevelSegments: 1, material: worn), Xform(translation: V3(e * (railLen / 2 - 0.05), 0.004, 0)))
            for dz: Float in [-0.04, 0.04] { hexBolt(&m, at: V3(e * (railLen / 2 - 0.05), 0.008, dz), normal: .up, size: 0.016, material: bolts) }
        }
        let r = hoopWidth / 2
        for i in 0..<hoops {
            let cx = -span / 2 + Float(i) * spacing
            var path: [V3] = [V3(-r, 0.012, 0), V3(-r, height - r, 0)]
            for k in 1..<16 { let a = Float.pi - Float.pi * Float(k) / 16; path.append(V3(r * cos(a), height - r + r * sin(a) - pipe, 0)) }
            path += [V3(r, height - r, 0), V3(r, 0.012, 0)]
            let tilt = simd_quatf(angle: rng.float(-0.006...0.006), axis: V3(0, 0, 1))
            m.add(Prim.tube(path, radii: Array(repeating: pipe, count: path.count), sides: 14, seamTile: 0.15, material: i == 1 ? worn : steel),
                  Xform(translation: V3(cx, 0, 0), rotation: tilt))
            // Weld beads at the feet.
            for e: Float in [-1, 1] {
                m.add(Prim.torus(major: pipe + 0.002, minor: 0.004, segments: 16, sides: 6, material: worn), Xform(translation: V3(cx + e * r, 0.014, 0)))
            }
            // Rubbed-bright band across the top where U-locks sit.
            m.add(Prim.torus(major: pipe + 0.0004, minor: 0.0008, segments: 14, sides: 4, material: "metal.steel"),
                  Xform(translation: V3(cx + rng.float(-0.08...0.08), height - pipe, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        }
        groundAO(&m, height: 0.12, floor: 0.6)
        return LODModel(m)
    }
}
