import simd
import Foundation

/// Mown lawn tile, 1 x 1 m, for instancing edge to edge: opaque top-down thatch quad 5 mm up, plus
/// ~550 short cut blades (3-7 cm, blunt tips). LOD1 keeps a fifth of the blades; LOD2 is the thatch alone.
public struct LawnPatch: RealAsset {
    public static let id = "lawn-patch"
    public static let summary = "Mown lawn tile, 1 x 1 m: thatch floor plus ~550 short cut geometric blades; tiles edge to edge, 3 LODs."
    public static let tags = ["nature", "grass", "ground"]
    public static let budget = 2_800
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 35, elevation: 30, distance: 0.9)

    /// Tile edge, meters.
    public var size: Float = 1
    public var blades = 550
    /// Mown height, meters.
    public var height: Float = 0.06
    public var material: MaterialKey = "grass.lawn"
    public var thatchMaterial: MaterialKey = "grass.lawn-thatch"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let phase = rng.float(0...6.28)
        var floor = Prim.terrain(size: V2(size, size), segments: 1, material: thatchMaterial) { _ in 0.005 }
        floor.occlusion = Array(repeating: 0.8, count: floor.positions.count)
        func patch(_ count: Int, _ r: inout SeededRNG) -> Surface {
            var s = Surface(material: material)
            for _ in 0..<count {
                var t = PlantKit.Tuft()
                t.count = 1; t.radius = 0.0001
                t.height = height; t.heightRange = 0.55...1.3
                t.width = 0.0025...0.0045
                t.lean = 0.05...0.5; t.splay = 0
                t.curl = 0...0.5; t.twist = 0.5
                t.segments = 2; t.mown = true
                let x = r.float(-0.48...0.48) * size, z = r.float(-0.48...0.48) * size
                s.append(PlantKit.tuft(t, at: V3(x, 0.004, z), rng: &r, material: material, phase: phase))
            }
            return s
        }
        var m0 = Model(name: Self.id), m1 = Model(name: Self.id), m2 = Model(name: Self.id)
        m0.add(floor); m0.add(patch(blades, &rng))
        m1.add(floor); m1.add(patch(blades / 5, &rng))
        m2.add(floor)
        PlantKit.finish(&m0); PlantKit.finish(&m1); PlantKit.finish(&m2)
        return LODModel(levels: [m0, m1, m2], switchDistances: [5, 14])
    }
}
