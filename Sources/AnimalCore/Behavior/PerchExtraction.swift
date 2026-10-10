import Foundation
import simd
import RealCore
import RealLibrary

/// How an item offers perches.
public struct PerchRule: Sendable {
    public enum Mode: Sendable {
        /// Flat up-facing narrow tops (rails, backs, caps) found in the mesh.
        case ledges(maxCount: Int, spacing: Float, minHeight: Float, maxWidth: Float)
        /// Edge midpoints of the highest broad up-facing surfaces (feeder tray, bowl).
        case edges(count: Int)
        /// Points on a circle at a fraction of the height.
        case ring(y: Float, radius: Float, count: Int)
        /// Top of the bounds.
        case apex
        /// Branch points of a generated tree.
        case crown(count: Int)
        /// Points inside the top of a shrub's volume.
        case canopy(count: Int)
        /// Points in the upper part of a flowering plant.
        case blossoms(count: Int)
    }
    public var mode: Mode
    public var kind: PerchKind
    public var feature: HabitatFeature?
    /// Grip diameter override in meters.
    public var grip: Float?
    /// Birds face the center of the item (feeders and baths) instead of across the ledge.
    public var faceCenter = false

    public init(_ mode: Mode, kind: PerchKind, feature: HabitatFeature? = nil, grip: Float? = nil, faceCenter: Bool = false) {
        self.mode = mode; self.kind = kind; self.feature = feature; self.grip = grip; self.faceCenter = faceCenter
    }
}

/// Which catalog items offer perches, and how. Item ids are RealityHD catalog ids.
public enum PerchRules {
    static func ledge(_ n: Int = 4, spacing: Float = 0.35, minHeight: Float = 0.6, maxWidth: Float = 0.3, kind: PerchKind = .rail) -> PerchRule {
        PerchRule(.ledges(maxCount: n, spacing: spacing, minHeight: minHeight, maxWidth: maxWidth), kind: kind)
    }

    public static let table: [String: PerchRule] = [
        "bird-feeder": PerchRule(.edges(count: 2), kind: .feeder, feature: .feeder, grip: 0.02, faceCenter: true),
        "birdbath": PerchRule(.ring(y: 0.985, radius: 0.9, count: 5), kind: .rim, feature: .water, grip: 0.03, faceCenter: true),
        "garden-fountain": PerchRule(.edges(count: 4), kind: .rim, feature: .water, grip: 0.04, faceCenter: true),
        "birdhouse": PerchRule(.apex, kind: .roof, feature: .birdhouse, grip: 0.03),
        "picket-fence": ledge(5, spacing: 0.4), "split-rail-fence": ledge(4, spacing: 0.5, minHeight: 0.5),
        "privacy-fence-panel": ledge(4, spacing: 0.45), "garden-gate": ledge(2), "lattice-screen": ledge(3),
        "garden-arch": ledge(3, minHeight: 0.8), "pergola": ledge(6, spacing: 0.5, minHeight: 0.85, maxWidth: 0.4),
        "park-bench": ledge(3, spacing: 0.4, minHeight: 0.5), "stone-bench": ledge(3, spacing: 0.4, minHeight: 0.3, maxWidth: 0.5, kind: .roof),
        "stone-lantern": PerchRule(.apex, kind: .post), "sundial": PerchRule(.apex, kind: .post, grip: 0.06),
        "garden-obelisk": PerchRule(.apex, kind: .post), "tiki-torch": PerchRule(.apex, kind: .post, grip: 0.03),
        "string-light-pole": ledge(2, spacing: 0.5, minHeight: 0.8, kind: .post), "clothesline": ledge(3, spacing: 0.6, minHeight: 0.8),
        "wheelbarrow": ledge(3, spacing: 0.4, minHeight: 0.4, kind: .roof), "rain-barrel": ledge(2, spacing: 0.4, minHeight: 0.6, maxWidth: 0.7, kind: .roof),
        "adirondack-chair": ledge(2, minHeight: 0.6), "outdoor-sofa": ledge(3, spacing: 0.45, minHeight: 0.6), "bistro-set": ledge(3, spacing: 0.4, minHeight: 0.6),
        "hammock-stand": ledge(2, spacing: 0.9, minHeight: 0.8), "basketball-hoop": ledge(2, spacing: 0.6, minHeight: 2.5, maxWidth: 0.5),
        "dog-house": ledge(2, spacing: 0.5, minHeight: 0.7, maxWidth: 0.8, kind: .roof), "gas-grill": ledge(2, spacing: 0.6, minHeight: 0.9, maxWidth: 0.8, kind: .roof),
        "compost-bin": ledge(2, spacing: 0.5, minHeight: 0.7, maxWidth: 0.8, kind: .roof), "cedar-planter-box": ledge(3, spacing: 0.4, minHeight: 0.3),
        "raised-garden-bed": ledge(4, spacing: 0.5, minHeight: 0.2), "terracotta-planter": ledge(2, spacing: 0.25, minHeight: 0.25),
        "galvanized-bucket": ledge(1, minHeight: 0.3), "garden-gnome": PerchRule(.apex, kind: .post, grip: 0.04), "tomato-cage": PerchRule(.apex, kind: .post, grip: 0.02),
        "maple-tree": PerchRule(.crown(count: 8), kind: .branch, feature: .tree), "birch-tree": PerchRule(.crown(count: 7), kind: .branch, feature: .tree),
        "japanese-maple": PerchRule(.crown(count: 5), kind: .branch, feature: .tree), "arborvitae": PerchRule(.apex, kind: .branch, feature: .shrub, grip: 0.02),
        "boxwood-shrub": PerchRule(.canopy(count: 2), kind: .branch, feature: .shrub), "boxwood-ball": PerchRule(.canopy(count: 1), kind: .branch, feature: .shrub),
        "privet-hedge": PerchRule(.canopy(count: 3), kind: .branch, feature: .shrub), "hydrangea-bush": PerchRule(.canopy(count: 2), kind: .branch, feature: .shrub),
        "rose-bush": PerchRule(.canopy(count: 2), kind: .branch, feature: .shrub), "knockout-azalea": PerchRule(.canopy(count: 2), kind: .branch, feature: .shrub),
        "ornamental-grass": PerchRule(.canopy(count: 2), kind: .branch, feature: .seedPlants, grip: 0.008),
        "lavender-clump": PerchRule(.blossoms(count: 3), kind: .blossom), "daylily-clump": PerchRule(.blossoms(count: 2), kind: .blossom),
        "hanging-basket": PerchRule(.blossoms(count: 2), kind: .blossom), "window-box": PerchRule(.blossoms(count: 3), kind: .blossom),
        "hosta": PerchRule(.blossoms(count: 1), kind: .blossom),
    ]

    public static func has(_ itemID: String) -> Bool { table[itemID] != nil }

    /// Tree species for crown rules.
    static func species(for item: String) -> TreeSpecies? {
        switch item {
        case "maple-tree": TreeSpecies.maple.with { $0.height = 14 }
        case "birch-tree": TreeSpecies.birch.with { $0.height = 12 }
        case "japanese-maple": TreeSpecies.japaneseMaple.with { $0.height = 5 }
        default: nil
        }
    }
}

/// Pose of a placed item: yard-local position, yaw about +Y and per-axis scale.
public struct ItemFrame: Sendable, Equatable {
    public var position: V3
    public var yaw: Float
    public var scale: V3
    public init(position: V3, yaw: Float = 0, scale: V3 = V3(1, 1, 1)) { self.position = position; self.yaw = yaw; self.scale = scale }

    func point(_ p: V3) -> V3 {
        let s = p * scale
        let c = cos(yaw), sn = sin(yaw)
        return position + V3(s.x * c + s.z * sn, s.y, -s.x * sn + s.z * c)
    }
    /// Local yaw (0 faces -Z) to world yaw.
    func facing(_ local: Float) -> Float { wrapAngle(local + yaw) }
}

public enum PerchExtractor {
    /// Item-local sites for `itemID`, built from the asset's own geometry. Positions are in the model's space.
    public static func localSites(itemID: String, model: Model, seed: UInt64) -> [PerchSite] {
        guard let rule = PerchRules.table[itemID] else { return [] }
        let b = model.bounds
        let top = b.max.y
        var out: [PerchSite] = []
        func site(_ p: V3, _ face: Float?, _ r: Float) -> PerchSite {
            PerchSite(id: 0, kind: rule.kind, position: p, facing: face, radius: rule.grip ?? r, capacity: 1, itemID: itemID, feature: rule.feature)
        }
        let center = V3((b.min.x + b.max.x) / 2, 0, (b.min.z + b.max.z) / 2)
        switch rule.mode {
        case .apex:
            out.append(site(V3(center.x, top, center.z), nil, 0.03))

        case .ring(let yf, let rf, let count):
            let r = rf * min(b.max.x - b.min.x, b.max.z - b.min.z) / 2
            for i in 0..<count {
                let a = Float(i) / Float(count) * 2 * .pi + 0.3
                let p = V3(center.x + cos(a) * r, top * yf, center.z + sin(a) * r)
                let inward = V3(center.x - p.x, 0, center.z - p.z)
                out.append(site(p, rule.faceCenter ? yaw(of: inward) : nil, 0.03))
            }

        case .ledges(let maxCount, let spacing, let minHeight, let maxWidth):
            let ledges = findLedges(model).filter { $0.y >= top * minHeight - 1e-4 && $0.width <= maxWidth && $0.length >= 0.05 }
                .sorted { $0.y > $1.y }
            for l in ledges {
                let n = max(1, min(maxCount - out.count, Int(l.length / spacing) + 1))
                if n <= 0 { break }
                for k in 0..<n {
                    let t = n == 1 ? 0.5 : (Float(k) + 0.5) / Float(n)
                    let along = l.alongX
                    let p = along ? V3(l.minX + (l.maxX - l.minX) * t, l.y, (l.minZ + l.maxZ) / 2) : V3((l.minX + l.maxX) / 2, l.y, l.minZ + (l.maxZ - l.minZ) * t)
                    let across = along ? V3(0, 0, 1) : V3(1, 0, 0)
                    out.append(site(p, yaw(of: across), l.width))
                }
                if out.count >= maxCount { break }
            }
            if out.isEmpty { out.append(site(V3(center.x, top, center.z), nil, 0.04)) }

        case .edges(let count):
            let big = findLedges(model).filter { $0.width >= 0.12 && $0.y > top * 0.25 }.sorted { $0.y > $1.y }
            guard let l = big.first else { out.append(site(V3(center.x, top * 0.85, center.z), nil, 0.03)); break }
            let cx = (l.minX + l.maxX) / 2, cz = (l.minZ + l.maxZ) / 2
            let hx = (l.maxX - l.minX) / 2 * 0.9, hz = (l.maxZ - l.minZ) / 2 * 0.9
            for i in 0..<count {
                let a = Float(i) / Float(count) * 2 * .pi
                let p = V3(cx + cos(a) * hx, l.y, cz + sin(a) * hz)
                out.append(site(p, yaw(of: V3(cx - p.x, 0, cz - p.z)), 0.02))
            }

        case .crown(let count):
            guard let sp = PerchRules.species(for: itemID) else { break }
            let g = TreeGenerator(species: sp, seed: seed)
            let h = sp.height
            var rng = SeededRNG(seed: seed &+ 99)
            let cands = g.branches.filter { $0.level >= 1 && !$0.broken && $0.points.count >= 3 }
                .filter { $0.points[$0.points.count - 1].y > h * 0.38 }
            var picked: [V3] = []
            for var br in cands.shuffled(using: &rng) {
                guard picked.count < count else { break }
                let k = max(1, Int(Float(br.points.count - 1) * rng.float(0.7...0.93)))
                let p = br.points[k]
                br.points = []
                if picked.contains(where: { simd_distance($0, p) < 0.9 }) { continue }
                picked.append(p)
                let t = br.radii.indices.contains(k) ? br.radii[k] : 0.02
                out.append(site(p + V3(0, max(0.01, t), 0), rng.float(-3...3), max(0.012, min(0.05, t * 2))))
            }

        case .canopy(let count):
            let w = (b.max.x - b.min.x) * 0.5, d = (b.max.z - b.min.z) * 0.5
            var rng = SeededRNG(seed: seed &+ 7)
            for i in 0..<count {
                let a = Float(i) / Float(max(count, 1)) * 2 * .pi + rng.float(0...1)
                let r = rng.float(0.15...0.55)
                out.append(site(V3(center.x + cos(a) * w * r, top * rng.float(0.82...0.94), center.z + sin(a) * d * r), rng.float(-3...3), 0.015))
            }

        case .blossoms(let count):
            let w = (b.max.x - b.min.x) * 0.5, d = (b.max.z - b.min.z) * 0.5
            var rng = SeededRNG(seed: seed &+ 13)
            for i in 0..<count {
                let a = Float(i) / Float(max(count, 1)) * 2 * .pi + rng.float(0...1)
                let r = rng.float(0.2...0.6)
                out.append(site(V3(center.x + cos(a) * w * r, top * rng.float(0.7...0.95), center.z + sin(a) * d * r), nil, 0.01))
            }
        }
        return out
    }

    /// Sites in the yard for a placed item.
    public static func sites(itemID: String, local: [PerchSite], frame: ItemFrame, source: UUID?) -> [PerchSite] {
        local.map { s in
            var o = s
            o.position = frame.point(s.position)
            o.facing = s.facing.map { frame.facing($0) }
            o.source = source
            return o
        }
    }

    // MARK: ledge detection

    struct Ledge {
        var y: Float
        var minX: Float, maxX: Float, minZ: Float, maxZ: Float
        var area: Float
        var alongX: Bool { (maxX - minX) >= (maxZ - minZ) }
        var width: Float { min(maxX - minX, maxZ - minZ) }
        var length: Float { max(maxX - minX, maxZ - minZ) }
    }

    /// Clusters up-facing triangles by height band and connectivity.
    static func findLedges(_ model: Model) -> [Ledge] {
        struct Tri { var c: V3; var area: Float }
        var tris: [Tri] = []
        for s in model.surfaces where !s.isEmpty {
            for t in stride(from: 0, to: s.indices.count, by: 3) {
                let a = s.positions[Int(s.indices[t])], b = s.positions[Int(s.indices[t + 1])], c = s.positions[Int(s.indices[t + 2])]
                let n = simd_cross(b - a, c - a)
                let len = simd_length(n)
                guard len > 1e-8, n.y / len > 0.88 else { continue }
                tris.append(Tri(c: (a + b + c) / 3, area: len / 2))
            }
        }
        // Bucket by height band, then grid cells.
        let cell: Float = 0.03, band: Float = 0.025
        var cells: [SIMD3<Int32>: (area: Float, y: Float)] = [:]
        for t in tris {
            let k = SIMD3<Int32>(Int32((t.c.x / cell).rounded(.down)), Int32((t.c.y / band).rounded()), Int32((t.c.z / cell).rounded(.down)))
            let e = cells[k] ?? (0, 0)
            cells[k] = (e.area + t.area, e.y + t.c.y * t.area)
        }
        var seen = Set<SIMD3<Int32>>()
        var out: [Ledge] = []
        for (k, v) in cells where !seen.contains(k) && v.area > 1e-5 {
            var stack = [k]
            seen.insert(k)
            var l = Ledge(y: 0, minX: .greatestFiniteMagnitude, maxX: -.greatestFiniteMagnitude, minZ: .greatestFiniteMagnitude, maxZ: -.greatestFiniteMagnitude, area: 0)
            var ySum: Float = 0
            while let c = stack.popLast() {
                guard let e = cells[c] else { continue }
                l.area += e.area; ySum += e.y
                l.minX = min(l.minX, Float(c.x) * cell); l.maxX = max(l.maxX, Float(c.x + 1) * cell)
                l.minZ = min(l.minZ, Float(c.z) * cell); l.maxZ = max(l.maxZ, Float(c.z + 1) * cell)
                for dx in -1...1 { for dz in -1...1 { for dy in -1...1 {
                    let n = SIMD3<Int32>(c.x + Int32(dx), c.y + Int32(dy), c.z + Int32(dz))
                    if !seen.contains(n), let ne = cells[n], ne.area > 1e-5 { seen.insert(n); stack.append(n) }
                }}}
            }
            l.y = ySum / max(l.area, 1e-9)
            if l.area > 4e-4 { out.append(l) }
        }
        return out
    }
}
