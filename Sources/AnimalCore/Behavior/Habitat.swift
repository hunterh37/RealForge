import Foundation
import RealCore

/// What a placed item contributes to the yard as animal habitat. Keys are catalog ids.
public enum HabitatTable {
    public static let items: [String: [(HabitatFeature, Float)]] = [
        "bird-feeder": [(.feeder, 1)], "birdhouse": [(.birdhouse, 1), (.perch, 0.2)],
        "birdbath": [(.water, 1), (.perch, 0.1)], "garden-fountain": [(.water, 0.8)], "rain-barrel": [(.water, 0.15)],
        "maple-tree": [(.tree, 1), (.shrub, 0.15)], "birch-tree": [(.tree, 0.9), (.shrub, 0.1)], "japanese-maple": [(.tree, 0.45), (.shrub, 0.2)],
        "arborvitae": [(.shrub, 0.7), (.tree, 0.3)],
        "boxwood-shrub": [(.shrub, 0.4)], "boxwood-ball": [(.shrub, 0.25)], "privet-hedge": [(.shrub, 0.7)],
        "hydrangea-bush": [(.shrub, 0.5), (.flowers, 0.35)], "rose-bush": [(.shrub, 0.4), (.flowers, 0.5)], "knockout-azalea": [(.shrub, 0.3), (.flowers, 0.5)],
        "lavender-clump": [(.flowers, 0.8), (.seedPlants, 0.3)], "daylily-clump": [(.flowers, 0.6)], "hosta": [(.flowers, 0.1), (.shrub, 0.1)],
        "hanging-basket": [(.flowers, 0.7)], "window-box": [(.flowers, 0.55)], "terracotta-planter": [(.flowers, 0.3)], "cedar-planter-box": [(.flowers, 0.3)],
        "garden-trellis": [(.flowers, 0.3), (.shrub, 0.2)], "potted-boxwood": [(.shrub, 0.15)],
        "ornamental-grass": [(.seedPlants, 0.9)], "tomato-cage": [(.seedPlants, 0.2)], "raised-garden-bed": [(.seedPlants, 0.4), (.openGround, 0.3)],
        "sod-roll": [(.openGround, 0.6)], "mulch-bed": [(.openGround, 0.35)], "river-rock-bed": [(.openGround, 0.1)], "paver-patio": [(.openGround, 0.1)],
        "picket-fence": [(.perch, 0.5)], "split-rail-fence": [(.perch, 0.6)], "privacy-fence-panel": [(.perch, 0.4)], "garden-arch": [(.perch, 0.6)],
        "pergola": [(.perch, 0.7)], "park-bench": [(.perch, 0.3)], "stone-lantern": [(.perch, 0.2)], "tiki-torch": [(.perch, 0.2)],
        "string-light-pole": [(.perch, 0.5)], "clothesline": [(.perch, 0.7)], "garden-obelisk": [(.perch, 0.3)], "sundial": [(.perch, 0.2)],
        "garden-gate": [(.perch, 0.3)], "lattice-screen": [(.perch, 0.3)], "wheelbarrow": [(.perch, 0.3)], "hammock-stand": [(.perch, 0.3)],
        "stone-bench": [(.perch, 0.2)], "adirondack-chair": [(.perch, 0.1)], "outdoor-sofa": [(.perch, 0.1)],
    ]

    /// Items that scare animals off: noise, motion, dogs.
    public static let disturbance: [String: Float] = [
        "lawn-mower": 0.25, "trampoline": 0.12, "basketball-hoop": 0.1, "dog-house": 0.18, "sandbox": 0.06, "tire-swing": 0.08,
        "gas-grill": 0.05, "patio-heater": 0.04, "lawn-sprinkler": 0.08,
    ]

    /// Items ground animals shelter in or run to.
    public static let cover: Set<String> = [
        "boxwood-shrub", "boxwood-ball", "privet-hedge", "hydrangea-bush", "rose-bush", "knockout-azalea", "arborvitae", "ornamental-grass", "hosta",
        "daylily-clump", "lavender-clump", "compost-bin", "dog-house", "raised-garden-bed",
    ]

    /// Items with food on the ground around them.
    public static let forage: Set<String> = ["bird-feeder", "raised-garden-bed", "compost-bin", "tomato-cage", "lavender-clump", "ornamental-grass", "mulch-bed", "sod-roll"]
}

/// How much of each feature the yard has, and how attractive that is to each species.
public struct HabitatInventory: Sendable, Equatable {
    /// Raw weighted counts.
    public var raw: [HabitatFeature: Float] = [:]
    /// Saturated 0...1 scores.
    public var score: [HabitatFeature: Float] = [:]
    /// 0...1: how disturbed the yard is.
    public var disturbance: Float = 0
    public var itemCounts: [String: Int] = [:]

    public init() {}

    static let saturation: [HabitatFeature: Float] = [
        .feeder: 0.9, .water: 1.0, .shrub: 0.6, .tree: 0.8, .flowers: 0.45, .seedPlants: 0.7, .birdhouse: 1.0, .perch: 0.55, .openGround: 0.5,
    ]

    /// `items` pairs a catalog id with its uniform scale; `openArea` is the region's open lawn in square meters.
    public static func build(items: [(id: String, scale: Float)], openArea: Float) -> HabitatInventory {
        var h = HabitatInventory()
        var dist: Float = 0
        for (id, scale) in items {
            h.itemCounts[id, default: 0] += 1
            if let c = HabitatTable.items[id] { for (f, w) in c { h.raw[f, default: 0] += w * max(0.6, min(1.5, scale)) } }
            dist += HabitatTable.disturbance[id] ?? 0
        }
        h.raw[.openGround, default: 0] += min(3, openArea / 8)
        for f in HabitatFeature.allCases { h.score[f] = 1 - exp(-(saturation[f] ?? 0.6) * (h.raw[f] ?? 0)) }
        h.disturbance = min(0.7, dist)
        return h
    }

    /// 0...1: how well the yard suits an animal that weights features by `likes`.
    public func attraction(likes: [HabitatFeature: Float]) -> Float {
        let weights = likes.values.sorted(by: >)
        let top = weights.prefix(3).reduce(0, +)
        guard top > 0 else { return 0 }
        var sum: Float = 0
        for (f, w) in likes { sum += w * (score[f] ?? 0) }
        return min(1, sum / top)
    }

    public func attraction(_ k: AnimalKind) -> Float {
        switch k {
        case .bird(let b): attraction(likes: b.profile.behavior.likes)
        case .ground(let g): attraction(likes: g.profile.behavior.likes)
        }
    }

    /// Headline score: how welcoming the yard is overall, 0...1.
    public var overall: Float {
        let a = AnimalKind.all.map { attraction($0) }
        let mean = a.reduce(0, +) / Float(max(1, a.count))
        let best = a.sorted(by: >).prefix(4).reduce(0, +) / 4
        return min(1, (mean * 0.5 + best * 0.5) * (1 - disturbance * 0.6))
    }

    /// Species this yard attracts above their minimum.
    public func attracted() -> [AnimalKind] {
        AnimalKind.all.filter { attraction($0) >= minHabitat($0) }
    }

    public func minHabitat(_ k: AnimalKind) -> Float {
        switch k { case .bird(let b): b.profile.behavior.minHabitat; case .ground(let g): g.profile.behavior.minHabitat }
    }

    /// What the yard lacks most for a species: the liked feature with the biggest gap.
    public func hint(for k: AnimalKind) -> HabitatFeature? {
        let likes: [HabitatFeature: Float]
        switch k { case .bird(let b): likes = b.profile.behavior.likes; case .ground(let g): likes = g.profile.behavior.likes }
        return likes.max { (a, b) in a.value * (1 - (score[a.key] ?? 0)) < b.value * (1 - (score[b.key] ?? 0)) }?.key
    }
}

public extension HabitatFeature {
    /// Short player-facing name.
    var title: String {
        switch self {
        case .feeder: "Feeder"; case .water: "Water"; case .shrub: "Shrubs"; case .tree: "Trees"; case .flowers: "Flowers"
        case .seedPlants: "Seed plants"; case .birdhouse: "Nest box"; case .openGround: "Open lawn"; case .perch: "Perches"
        }
    }

    /// Catalog items that add this feature, best first.
    var suggestedItems: [String] {
        switch self {
        case .feeder: ["bird-feeder"]
        case .water: ["birdbath", "garden-fountain"]
        case .shrub: ["privet-hedge", "hydrangea-bush", "boxwood-shrub"]
        case .tree: ["maple-tree", "birch-tree", "japanese-maple"]
        case .flowers: ["lavender-clump", "hanging-basket", "rose-bush"]
        case .seedPlants: ["ornamental-grass", "lavender-clump"]
        case .birdhouse: ["birdhouse"]
        case .openGround: ["sod-roll", "mulch-bed"]
        case .perch: ["split-rail-fence", "garden-arch", "pergola"]
        }
    }
}
