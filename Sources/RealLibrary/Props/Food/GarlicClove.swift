import simd
import Foundation

/// Single peeled garlic clove lying on its side along +X: a curved crescent with a rounded back, a
/// flat inner face where it sat against its neighbors, a brown basal plate at the root end (-X) and a
/// pointed tip (+X). One closed ivory body (cut face `food.garlic-clove`) plus the basal plate shell.
public struct GarlicClove: RealFood {
    public static let id = "garlic-clove"
    public static let summary = "Peeled garlic clove, 3 cm: curved crescent with flat inner face, brown basal plate and pointed tip."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 2500
    public static let author = "realityhd"
    public static let kind = FoodKind.vegetable
    public static let preview = PreviewHint(azimuth: 30, elevation: 30, distance: 0.12, studio: true)

    /// Clove length (m).
    public var length: Float = 0.030
    /// Width across the back (m).
    public var width: Float = 0.016
    /// Thickness, back to inner face (m).
    public var thickness: Float = 0.018
    /// Material keys.
    public var flesh: MaterialKey = "food.garlic-clove"
    public var plateKey: MaterialKey = "food.garlic-skin:8C6E4C"
    public init() {}

    public var coreCenter: V3 { V3(0, width * 0.5, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == flesh ? flesh : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let L = length
        // Along +Y: base (root) at y = 0, tip at y = L. w = half thickness (back +x to inner face -x),
        // d = half width. The crescent bends the back outward.
        var s = FoodMesh.sections(edge: 0.0014, length: L, seamTile: 0.03, material: flesh) { t in
            let body = pow(sin(.pi * pow(t, 0.85)), 0.5) * (1 - 0.6 * pow(t, 1.2))
            let w = self.thickness / 2 * body
            let d = self.width / 2 * body * (1 - 0.3 * t)
            return (max(1e-4, w), max(1e-4, d), 2.4, V2(-0.006 * sin(.pi * t), 0))
        }
        let ph = rng.float(0...6.28)
        s.deform { p in
            var q = p
            let t = p.y / L
            // Flat inner face: squash the -x side toward a plane following the crescent.
            let plane = -0.006 * sin(.pi * t) - self.thickness * 0.2 * pow(sin(.pi * t), 0.5) * (1 - 0.5 * t)
            if q.x < plane { q.x = plane + (q.x - plane) * 0.25 }
            // Faint longitudinal ridges and a slight twist.
            let a = atan2(p.z, p.x)
            q.x += 0.00015 * sin(a * 6 + ph)
            q.z += 0.0008 * sin(.pi * t) * sin(ph)
            return q
        }
        s = FoodMesh.layAlongX(s)
        // After laying: x along the clove, -y the back (old +x), so flip y to stand the back up.
        s.deform { p in V3(p.x, -p.y, p.z) }
        s = s.flipped()
        // Lying on its side: rotate 90 degrees about X so the flat face is vertical and the clove rests on a flank.
        s.deform { p in V3(p.x, p.z, -p.y) }
        var m = Model(name: Self.id)
        // Basal plate: a thin brown lens capping the root end.
        let bb = s.bounds
        let cy = (bb.min.y + bb.max.y) / 2, cz = (bb.min.z + bb.max.z) / 2
        var plate = FoodMesh.revolve(edge: 0.0012, seamTile: 0.01, material: plateKey) { t in
            let a = Float.pi * t
            return V2(0.0024 * sin(a), -0.0005 * cos(a))
        }
        plate.deform { p in V3(bb.min.x + 0.0021 + p.y, cy + p.x, cz + p.z) }
        plate = plate.flipped()
        m.add(s); m.add(plate)
        m = FoodMesh.fit(m, size: V3(length, thickness, width))
        groundAO(&m, height: 0.006, floor: 0.6)
        return LODModel(m)
    }
}
