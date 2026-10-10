import Foundation

/// Friendship with a species, from wary to tame.
public enum Friendship: Int, Codable, Sendable, CaseIterable, Comparable {
    case wary, curious, friendly, tame
    public static func < (a: Friendship, b: Friendship) -> Bool { a.rawValue < b.rawValue }

    public init(trust: Float) {
        switch trust {
        case ..<0.2: self = .wary
        case ..<0.45: self = .curious
        case ..<0.75: self = .friendly
        default: self = .tame
        }
    }

    public var title: String {
        switch self { case .wary: "Wary"; case .curious: "Curious"; case .friendly: "Friendly"; case .tame: "Tame" }
    }

    /// Trust needed to reach the level.
    public var threshold: Float {
        switch self { case .wary: 0; case .curious: 0.2; case .friendly: 0.45; case .tame: 0.75 }
    }
}

public struct JournalEntry: Codable, Sendable, Equatable {
    public var sightings = 0
    public var firstSeen: Date?
    public var lastSeen: Date?
    public var handLandings = 0
    public var handFeeds = 0
    public var trust: Float = 0
    /// Seconds spent in the yard.
    public var seconds: Float = 0
    /// Item id to visits to it.
    public var favorites: [String: Int] = [:]
    public var friendship: Friendship { Friendship(trust: trust) }
    public var seen: Bool { sightings > 0 }
    public init() {}
}

public enum JournalEvent: Sendable {
    /// A new visitor arrived.
    case visit(AnimalKind)
    case landed(AnimalKind, item: String?)
    /// Stayed calmly for `seconds`.
    case settled(AnimalKind, seconds: Float)
    case spooked(AnimalKind)
    case handLanded(AnimalKind)
    case handFed(AnimalKind)
}

public enum JournalReward: Sendable, Equatable {
    case newSpecies(AnimalKind, cash: Double)
    case friendship(AnimalKind, Friendship, cash: Double)
    case firstHand(AnimalKind, cash: Double)
    case milestone(count: Int, cash: Double)

    public var cash: Double {
        switch self {
        case .newSpecies(_, let c), .friendship(_, _, let c), .firstHand(_, let c), .milestone(_, let c): c
        }
    }

    public var message: String {
        switch self {
        case .newSpecies(let k, _): "New visitor: \(k.name)"
        case .friendship(let k, let f, _): "\(k.name) is now \(f.title.lowercased())"
        case .firstHand(let k, _): "\(k.name) landed on your hand"
        case .milestone(let n, _): "\(n) species in the journal"
        }
    }
}

/// The person's field journal: what has visited, how well each species trusts them.
public struct Journal: Codable, Sendable, Equatable {
    public var entries: [String: JournalEntry] = [:]
    public var totalVisits = 0
    public var totalHandLandings = 0
    public var milestonesPaid: Set<Int> = []

    public init() {}

    public func entry(_ k: AnimalKind) -> JournalEntry { entries[k.rawValue] ?? JournalEntry() }
    public func trust(_ k: AnimalKind) -> Float { entry(k).trust }
    public var discovered: Int { entries.values.filter(\.seen).count }
    public var total: Int { AnimalKind.all.count }
    public var completion: Float { Float(discovered) / Float(total) }

    /// Applies an event and returns any rewards it earned.
    @discardableResult
    public mutating func record(_ e: JournalEvent, now: Date = Date()) -> [JournalReward] {
        var rewards: [JournalReward] = []
        func edit(_ k: AnimalKind, _ body: (inout JournalEntry) -> Void) {
            var x = entries[k.rawValue] ?? JournalEntry()
            body(&x)
            entries[k.rawValue] = x
        }
        func trustGain(_ k: AnimalKind, _ d: Float) {
            let before = entry(k).friendship
            edit(k) { $0.trust = max(0, min(1, $0.trust + d)) }
            let after = entry(k).friendship
            if after > before { rewards.append(.friendship(k, after, cash: 25 * Double(after.rawValue))) }
        }
        switch e {
        case .visit(let k):
            let first = !entry(k).seen
            totalVisits += 1
            edit(k) { $0.sightings += 1; $0.firstSeen = $0.firstSeen ?? now; $0.lastSeen = now }
            if first {
                rewards.append(.newSpecies(k, cash: (40 + 160 * Double(k.rarity)).rounded()))
                let n = discovered
                if n % 5 == 0, !milestonesPaid.contains(n) { milestonesPaid.insert(n); rewards.append(.milestone(count: n, cash: 250)) }
            }
        case .landed(let k, let item):
            if let item { edit(k) { $0.favorites[item, default: 0] += 1 } }
        case .settled(let k, let s):
            edit(k) { $0.seconds += s }
            trustGain(k, min(0.06, s / 400))
        case .spooked(let k):
            trustGain(k, -0.04)
        case .handLanded(let k):
            let first = entry(k).handLandings == 0
            totalHandLandings += 1
            edit(k) { $0.handLandings += 1 }
            if first { rewards.append(.firstHand(k, cash: 75)) }
            trustGain(k, entry(k).handLandings < 4 ? 0.12 : 0.05)
        case .handFed(let k):
            edit(k) { $0.handFeeds += 1 }
            trustGain(k, 0.01)
        }
        return rewards
    }
}
