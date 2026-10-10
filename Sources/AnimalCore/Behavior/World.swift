import Foundation
import simd
import RealCore

/// How an animal can stand on something.
public enum PerchKind: String, Sendable, CaseIterable, Codable {
    /// Tree branch or twig: thin, round, high.
    case branch
    /// Fence rail, bench back, arch top: flat narrow ledge.
    case rail
    /// Feeder perch: food here.
    case feeder
    /// Rim of a bath or fountain: water here.
    case rim
    /// Roof, lid, flat top of a box or barrel.
    case roof
    /// Post, pole or lantern top.
    case post
    /// Ground, lawn, patio, mulch.
    case ground
    /// A flower or plant top a hovering bird feeds at.
    case blossom
    /// The player's hand.
    case hand

    public var defaultFeature: HabitatFeature {
        switch self {
        case .feeder: .feeder
        case .rim: .water
        case .ground: .openGround
        case .blossom: .flowers
        case .branch: .tree
        case .rail, .roof, .post, .hand: .perch
        }
    }

    /// Food is available here.
    public var food: Bool { self == .feeder || self == .blossom }
    public var water: Bool { self == .rim }
    public var isGround: Bool { self == .ground }
}

/// A place an animal can stand. `position` is where the feet go, in yard-local meters.
public struct PerchSite: Sendable, Identifiable, Equatable {
    public var id: Int
    public var kind: PerchKind
    public var position: V3
    /// Preferred heading in radians (0 faces -Z, positive turns left). nil = any.
    public var facing: Float?
    /// Grip thickness in meters: branches are 0.01 to 0.03, rails 0.04 or more.
    public var radius: Float
    public var capacity: Int
    /// Placement that owns the site.
    public var source: UUID?
    /// Item the site was derived from.
    public var itemID: String?
    /// Habitat feature that makes species like this site.
    public var feature: HabitatFeature

    public init(id: Int, kind: PerchKind, position: V3, facing: Float? = nil, radius: Float = 0.02, capacity: Int = 1, source: UUID? = nil,
                itemID: String? = nil, feature: HabitatFeature? = nil) {
        self.id = id; self.kind = kind; self.position = position; self.facing = facing; self.radius = radius
        self.capacity = capacity; self.source = source; self.itemID = itemID
        self.feature = feature ?? kind.defaultFeature
    }
}

/// Registry of perch sites and who stands on them. Rebuilt when placements change; occupancy survives.
public final class PerchBook {
    public private(set) var sites: [PerchSite] = []
    private var occupants: [Int: Set<Int>] = [:]
    private var nextID = 1
    /// The player's hand as a moving site (nil when no hand is offered).
    public private(set) var handSite: PerchSite?
    public static let handID = -1

    public init() {}

    /// Replaces all static sites. Ids stay stable for sites with the same source and index.
    public func replace(with new: [PerchSite]) {
        var out: [PerchSite] = []
        for var s in new { s.id = nextID; nextID += 1; out.append(s) }
        sites = out
        occupants = occupants.filter { id, _ in out.contains { $0.id == id } }
    }

    public func setHand(_ site: PerchSite?) {
        handSite = site.map { var s = $0; s.id = Self.handID; s.kind = .hand; return s }
    }

    public func site(_ id: Int) -> PerchSite? { id == Self.handID ? handSite : sites.first { $0.id == id } }

    public func occupancy(_ id: Int) -> Int { occupants[id]?.count ?? 0 }
    public func isFree(_ id: Int) -> Bool { guard let s = site(id) else { return false }; return occupancy(id) < s.capacity }

    public func claim(_ id: Int, by animal: Int) { occupants[id, default: []].insert(animal) }
    public func release(_ id: Int, by animal: Int) { occupants[id]?.remove(animal) }
    public func releaseAll(by animal: Int) { for k in occupants.keys { occupants[k]?.remove(animal) } }

    /// Sites within `radius` meters horizontally of `p`.
    public func near(_ p: V3, radius: Float, kinds: Set<PerchKind>? = nil) -> [PerchSite] {
        sites.filter { s in
            (kinds?.contains(s.kind) ?? true) && simd_length(V2(s.position.x - p.x, s.position.z - p.z)) <= radius
        }
    }
}

/// The player's offered hand, in yard-local meters.
public struct HandOffer: Sendable, Equatable {
    public var palm: V3
    /// Unit vector out of the palm.
    public var normal: V3
    /// Unit vector from the wrist toward the fingers.
    public var fingers: V3
    /// Speed in m/s.
    public var speed: Float
    /// Seconds the palm has been up, open and steady.
    public var steady: Float
    public init(palm: V3, normal: V3 = V3(0, 1, 0), fingers: V3 = V3(0, 0, -1), speed: Float = 0, steady: Float = 0) {
        self.palm = palm; self.normal = normal; self.fingers = fingers; self.speed = speed; self.steady = steady
    }
}

/// Everything animals sense about the person.
public struct PlayerState: Sendable, Equatable {
    public var head: V3 = V3(0, 1.6, 0)
    /// Head speed in m/s.
    public var headSpeed: Float = 0
    public var hand: HandOffer?
    /// A moving hand that is not offered (waving, grabbing, pointing).
    public var handSpeed: Float = 0
    public var handPosition: V3?
    public init() {}
}

/// A circular obstacle on the ground (a prop footprint). Ground animals walk around them.
public struct Obstacle: Sendable, Equatable {
    public var center: V2
    public var radius: Float
    public init(center: V2, radius: Float) { self.center = center; self.radius = radius }
}

/// Snapshot of the yard each animal reads every tick.
public struct YardView: Sendable {
    /// Yard-local rectangle animals stay inside while visiting: min and max x, z.
    public var min: V2
    public var max: V2
    /// Ground height.
    public var groundY: Float = 0
    public var player = PlayerState()
    public var obstacles: [Obstacle] = []
    public var weather = AnimalWeather()
    public var dayPart: DayPart = .day
    public var season: AnimalSeason = .summer
    /// Loud things that just happened near a point (placing, dropping): spooks animals nearby.
    public var noises: [(at: V3, loudness: Float)] = []
    /// Cover points ground animals run to (shrubs, hedges).
    public var cover: [V2] = []
    /// Food points on the ground (under feeders, flower beds).
    public var forage: [V2] = []

    public init(min: V2 = V2(-4, -4), max: V2 = V2(4, 4)) { self.min = min; self.max = max }

    public func contains(_ p: V2, margin: Float = 0) -> Bool {
        p.x >= min.x + margin && p.x <= max.x - margin && p.y >= min.y + margin && p.y <= max.y - margin
    }

    public func clamp(_ p: V2, margin: Float = 0) -> V2 {
        V2(Swift.min(Swift.max(p.x, min.x + margin), max.x - margin), Swift.min(Swift.max(p.y, min.y + margin), max.y - margin))
    }
}

public func wrapAngle(_ a: Float) -> Float {
    var x = a.truncatingRemainder(dividingBy: 2 * .pi)
    if x > .pi { x -= 2 * .pi }
    if x < -.pi { x += 2 * .pi }
    return x
}

/// Heading vector for a yaw in radians (0 faces -Z, positive turns toward -X).
public func forward(yaw: Float) -> V3 { V3(-sin(yaw), 0, -cos(yaw)) }
public func yaw(of d: V3) -> Float { atan2(-d.x, -d.z) }
public func headingOf(_ d: V3) -> Float { yaw(of: d) }
