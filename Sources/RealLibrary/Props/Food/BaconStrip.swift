import simd
import Foundation

/// Raw streaky bacon strip, 25 x 3 cm and 2.5 mm thick, lying flat with soft lengthwise ripples and
/// a slight meander. One closed rounded slab; fat and lean stripes run along the strip (`food.bacon`,
/// UVs u across the width, v along). Cook kind `protein`: shrinks in color toward crisp
/// `food.bacon-cooked`.
public struct BaconStrip: RealFood {
    public static let id = "bacon-strip"
    public static let summary = "Raw streaky bacon strip, 25 x 3 cm: wavy rippled slice with pink lean and white fat stripes; crisps when cooked."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.protein
    public static let preview = PreviewHint(azimuth: 25, elevation: 40, distance: 0.42, studio: true)

    /// Length (m).
    public var length: Float = 0.25
    /// Width (m).
    public var width: Float = 0.03
    /// Thickness (m).
    public var thickness: Float = 0.0025
    /// Material key.
    public var bacon: MaterialKey = "food.bacon"
    public init() {}

    public var coreCenter: V3 { V3(0, thickness, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == bacon ? bacon : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var s = FoodMesh.box(V3(length, thickness, width), radius: 0.0009, edge: 0.0042, bevelSegments: 2, material: bacon)
        // Stripes along the strip: u across (z), v along (x).
        s.uvs = s.positions.map { V2($0.z + 0.015, $0.x) }
        let ph = (0..<4).map { _ in rng.float(0...6.28) }
        let sd = UInt32(truncatingIfNeeded: seed)
        s.deform { p in
            var q = p
            let x = p.x
            q.y += 0.0022 * (0.5 + 0.5 * sin(x * 2 * .pi / 0.065 + ph[0])) * (0.6 + 0.4 * sin(x * 13 + ph[1]))
            q.y += 0.0006 * RecipeMesh.noise(V3(p.x, 0, p.z), 40, seed: sd)
            q.z += 0.004 * sin(x * 2 * .pi / 0.2 + ph[2])
            // Ragged width: the fat edge (+z) wanders more.
            let edge = p.z / (width / 2)
            q.z += edge * 0.0012 * RecipeMesh.noise(V3(p.x, 0, 0), 60, seed: sd &+ 1)
            return q
        }
        s.computeTangents()
        var m = Model(name: Self.id)
        m.add(s)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.004, floor: 0.75)
        return LODModel(m)
    }
}
