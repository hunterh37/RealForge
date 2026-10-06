import simd
import Foundation

/// Broccoli floret lying on its side: a pale green stalk that splits into five short branches, each
/// ending in a tight crown cluster (closed domes with sub-floret lumps; bead buds in
/// `food.broccoli`). Built upright, then tipped over to rest on crown and stalk end. Stalk cut face
/// `food.broccoli-flesh`. Cook kind `vegetable`: brightens to vivid green.
public struct BroccoliFloret: RealFood {
    public static let id = "broccoli-floret"
    public static let summary = "Broccoli floret, 7.5 cm: pale green branching stem, tight dark-green beaded crown clusters; brightens when cooked."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let kind = FoodKind.vegetable
    public static let preview = PreviewHint(azimuth: 30, elevation: 30, distance: 0.24, studio: true)

    /// Stalk height before the split (m).
    public var stalk: Float = 0.032
    /// Crown width (m).
    public var crown: Float = 0.055
    /// Material keys.
    public var buds: MaterialKey = "food.broccoli"
    public var stem: MaterialKey = "food.broccoli-stem"
    public var flesh: MaterialKey = "food.broccoli-flesh"
    public init() {}

    public var coreCenter: V3 { V3(0, 0.02, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == stem || key == buds ? flesh : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let H = stalk, W = crown / 2
        let sd = UInt32(truncatingIfNeeded: seed)
        var stems = Surface(material: stem)
        var crowns = Surface(material: buds)
        let main = catmull([V3(0, 0, 0), V3(0.001, H * 0.5, 0), V3(0, H, 0.001)], per: 3)
        stems.append(FoodMesh.tube(main, radii: main.indices.map { 0.0072 - 0.0012 * Float($0) / Float(main.count - 1) }, sides: 12,
                                   endBulge: 0.08, seamTile: 0.03, material: stem))
        // Cluster centers on a domed crown: one in the middle, four around.
        var centers: [(V3, Float)] = [(V3(0, H + 0.022, 0), 0.0155)]
        let ph = rng.float(0...6.28)
        for k in 0..<4 {
            let a = ph + Float(k) / 4 * 2 * .pi + rng.float(-0.25...0.25)
            let rr = W * rng.float(0.55...0.68)
            centers.append((V3(rr * cos(a), H + 0.012 + rng.float(-0.002...0.002), rr * sin(a)), rng.float(0.0125...0.0145)))
        }
        for (i, c) in centers.enumerated() {
            // Branch from the stalk top to under the cluster.
            let start = V3(0, H - 0.004, 0)
            let end = c.0 - V3(0, c.1 * 0.35, 0)
            let mid = (start + end) / 2 + V3(0, 0.004, 0)
            let br = catmull([start, mid, end], per: 3)
            stems.append(FoodMesh.tube(br, radii: br.indices.map { 0.0042 - 0.0018 * Float($0) / Float(br.count - 1) }, sides: 9,
                                       endBulge: 0.4, seamTile: 0.03, material: stem))
            // Cluster dome: rounded top, flatter underside.
            let r = c.1
            var dome = FoodMesh.revolve(edge: 0.0024, seamTile: 0.05, material: buds) { t in
                let a = Float.pi * t
                let rad = r * sin(a) * (1 + 0.08 * sin(a * 2))
                let y = -r * 0.55 * cos(a) * (t < 0.5 ? 0.75 : 1.0)
                return V2(rad, y)
            }
            let tiltAxis = simd_normalize(V3(c.0.z, 0, -c.0.x) + V3(1e-4, 0, 0))
            let tilt = simd_quatf(angle: simd_length(V2(c.0.x, c.0.z)) / W * 0.5, axis: tiltAxis)
            dome.deform { p in c.0 + tilt.act(p) }
            dome.displace { p, n in
                let lumps = RecipeMesh.noise(p, 130, seed: sd &+ UInt32(i)) * 0.0011 + RecipeMesh.noise(p, 260, seed: sd &+ 9) * 0.0004
                return n.y > -0.2 ? lumps : lumps * 0.3
            }
            crowns.append(dome)
        }
        var m = Model(name: Self.id)
        m.add(stems)
        m.add(crowns)
        // Tip it over onto its side.
        m = m.transformed(Xform(rotation: simd_quatf(angle: -1.3, axis: V3(0, 0, 1))))
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.01, floor: 0.6)
        return LODModel(m)
    }
}
