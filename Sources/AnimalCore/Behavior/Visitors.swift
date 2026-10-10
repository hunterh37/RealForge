import Foundation
import RealCore

public struct WildlifeSettings: Codable, Sendable, Equatable {
    public enum Frequency: String, Codable, CaseIterable, Sendable {
        case calm, normal, busy
        public var factor: Float { switch self { case .calm: 0.55; case .normal: 1; case .busy: 1.9 } }
        public var title: String { rawValue.capitalized }
    }
    public var enabled = true
    public var frequency: Frequency = .normal
    public var birds = true
    public var groundAnimals = true
    public var sound = true
    public init() {}
}

/// A request to bring an animal into the yard.
public struct VisitRequest: Sendable, Equatable {
    public var kind: AnimalKind
    /// Flocks: waxwings and goldfinches arrive in small groups.
    public var group: Int
    /// Seconds the visit lasts.
    public var stay: Float
}

/// Decides when and which animals arrive. Pure and deterministic given its seed.
public struct VisitScheduler: Sendable {
    public var settings = WildlifeSettings()
    private var timer: Float
    private var rng: SeededRNG
    public private(set) var visits = 0

    public init(seed: UInt64 = 1, firstVisitIn: Float = 8) {
        rng = SeededRNG(seed: seed)
        timer = firstVisitIn
    }

    public static func maxConcurrent(overall: Float, birds: Bool) -> Int { birds ? 2 + Int((overall * 4).rounded(.down)) : 1 + (overall > 0.55 ? 1 : 0) }

    /// Advances time. `present` lists species already in the yard.
    public mutating func tick(dt: Float, habitat: HabitatInventory, view: YardView, present: [AnimalKind], journal: Journal) -> [VisitRequest] {
        guard settings.enabled else { return [] }
        timer -= dt
        guard timer <= 0 else { return [] }
        let overall = habitat.overall
        let weatherFactor = view.weather.activity
        // Next arrival: better habitat and calmer conditions shorten the wait.
        let wait = rng.float(26...55) / (0.3 + 1.6 * overall) / settings.frequency.factor / max(0.2, AnimalTuning.visitRate)
        timer = wait / max(0.25, weatherFactor * (1 - habitat.disturbance * 0.7))
        let birdsNow = present.filter(\.isBird).count, groundNow = present.count - birdsNow
        var cands: [(AnimalKind, Float)] = []
        for k in AnimalKind.all {
            if present.contains(k) { continue }
            switch k {
            case .bird(let b):
                guard settings.birds, birdsNow < Self.maxConcurrent(overall: overall, birds: true) else { continue }
                let p = b.profile.behavior
                guard p.seasons.contains(view.season) else { continue }
                let att = habitat.attraction(k)
                guard att >= p.minHabitat else { continue }
                let day = p.activity[view.dayPart] ?? 1
                var w = att * day * (1 - 0.75 * p.rarity)
                if !journal.entry(k).seen { w *= 1.35 }
                cands.append((k, w))
            case .ground(let g):
                guard settings.groundAnimals, groundNow < Self.maxConcurrent(overall: overall, birds: false) else { continue }
                let p = g.profile.behavior
                guard p.seasons.contains(view.season) else { continue }
                let att = habitat.attraction(k)
                guard att >= p.minHabitat else { continue }
                let day = p.activity[view.dayPart] ?? 1
                var w = att * day * (1 - 0.75 * p.rarity) * 0.8
                if !journal.entry(k).seen { w *= 1.35 }
                cands.append((k, w))
            }
        }
        let total = cands.reduce(0) { $0 + max(0, $1.1) }
        guard total > 0.001, weatherFactor > 0.05 else { return [] }
        var r = rng.float() * total
        var pick = cands[0].0
        for (k, w) in cands { r -= max(0, w); if r <= 0 { pick = k; break } }
        let att = habitat.attraction(pick)
        var group = 1
        if case .bird(let b) = pick {
            switch b {
            case .cedarWaxwing: group = rng.int(2...4)
            case .americanGoldfinch: group = rng.int(1...3)
            case .mourningDove: group = rng.chance(0.5) ? 2 : 1
            case .blackCappedChickadee: group = rng.chance(0.4) ? 2 : 1
            default: break
            }
            group = min(group, max(1, Self.maxConcurrent(overall: overall, birds: true) - birdsNow))
        }
        let trust = journal.trust(pick)
        let stay = rng.float(35...80) * (0.7 + 0.6 * att) * (1 + 0.4 * trust)
        visits += 1
        return [VisitRequest(kind: pick, group: group, stay: stay)]
    }

    /// First visit arrives sooner on the first launch so the loop is visible right away.
    public mutating func expedite(_ seconds: Float) { timer = min(timer, seconds) }
}
