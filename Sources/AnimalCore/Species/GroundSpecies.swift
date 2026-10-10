import Foundation
import RealCore

/// The four ground animals. Raw values are stable ids used in saved journals.
public enum GroundSpecies: String, CaseIterable, Codable, Sendable, Identifiable {
    case easternCottontail = "eastern-cottontail"
    case easternGraySquirrel = "eastern-gray-squirrel"
    case easternChipmunk = "eastern-chipmunk"
    case europeanHedgehog = "european-hedgehog"

    public var id: String { rawValue }
    public var profile: GroundProfile { GroundProfile.table[self]! }
}

/// How a quadruped moves.
public enum GroundGait: String, Sendable {
    /// Rabbits: both hind legs together, fore legs follow.
    case hop
    /// Squirrels and chipmunks: bounding, hind legs land ahead of the fore legs.
    case bound
    /// Hedgehogs: alternating diagonal walk.
    case walk
}

/// Body proportions in meters. Animals face -Z, feet at y = 0.
public struct GroundAnatomy: Sendable {
    /// Chest to rump.
    public var bodyLength: Float
    public var bodyDepth: Float
    public var bodyWidth: Float
    public var headLength: Float
    public var headWidth: Float
    public var headHeight: Float
    public var snout: Float
    public var earLength: Float
    public var earWidth: Float
    public var tailLength: Float
    public var tailWidth: Float
    public var foreLeg: Float
    public var hindLeg: Float
    public var legRadius: Float
    /// Torso pitch when standing, degrees (rabbits sit with a high rump).
    public var pitch: Float
    public var eyeRadius: Float
    /// Whiskers drawn.
    public var whiskers: Bool = true
    /// Back covered in spines.
    public var spines: Bool = false
    /// Height of the body center above the feet.
    public var standHeight: Float { max(foreLeg, hindLeg) * 0.74 + bodyDepth * 0.32 }
}

public struct GroundPalette: Sendable, Hashable {
    public var back: UInt32
    public var belly: UInt32
    /// Stripes, tail fringe, guard hair tips.
    public var accent: UInt32
    public var ear: UInt32
    public var nose: UInt32
    public var eye: UInt32
    public var claw: UInt32
    public var tail: UInt32
    public var tailTip: UInt32
    public var face: UInt32
    public var flankLine: Float
    /// 0...1 stripe / agouti strength.
    public var pattern: Float
    public var strands: Float
}

public struct GroundBehavior: Sendable {
    public var gait: GroundGait
    /// Walking and running speeds in m/s before `AnimalTuning.groundSpeedScale`.
    public var walk: Float
    public var run: Float
    public var climbs: Bool
    /// 0...1: approaches a low open hand and tolerates people.
    public var boldness: Float
    public var skittishRadius: Float
    public var rarity: Float
    public var seasons: Set<AnimalSeason>
    public var activity: [DayPart: Float]
    public var likes: [HabitatFeature: Float]
    public var minHabitat: Float
    /// Chance per second of stopping to stand up and look around (squirrels, chipmunks, rabbits).
    public var alertRate: Float
}

public struct GroundProfile: Sendable {
    public var species: GroundSpecies
    public var name: String
    public var latin: String
    public var blurb: String
    public var anatomy: GroundAnatomy
    public var palette: GroundPalette
    public var behavior: GroundBehavior
}

extension GroundProfile {
    static let table: [GroundSpecies: GroundProfile] = Dictionary(uniqueKeysWithValues: [rabbit, squirrel, chipmunk, hedgehog].map { ($0.species, $0) })

    private static let allSeasons: Set<AnimalSeason> = [.spring, .summer, .autumn, .winter]

    static let rabbit = GroundProfile(
        species: .easternCottontail, name: "Eastern Cottontail", latin: "Sylvilagus floridanus",
        blurb: "Nibbles clover at dawn and dusk. Freezes when watched, then bolts for cover.",
        anatomy: GroundAnatomy(bodyLength: 0.26, bodyDepth: 0.15, bodyWidth: 0.13, headLength: 0.1, headWidth: 0.066, headHeight: 0.078, snout: 0.035,
                               earLength: 0.07, earWidth: 0.026, tailLength: 0.05, tailWidth: 0.05, foreLeg: 0.1, hindLeg: 0.15, legRadius: 0.011, pitch: 14, eyeRadius: 0.008),
        palette: GroundPalette(back: 0x8C7358, belly: 0xE9E0D2, accent: 0x4A3A2C, ear: 0xC9A89A, nose: 0xC98C84, eye: 0x15100C, claw: 0x4A4036, tail: 0xF2EEE6,
                               tailTip: 0xF2EEE6, face: 0x9A8062, flankLine: 0.62, pattern: 0.55, strands: 70),
        behavior: GroundBehavior(gait: .hop, walk: 0.5, run: 4, climbs: false, boldness: 0.35, skittishRadius: 2.2, rarity: 0.25, seasons: allSeasons,
                                 activity: [.dawn: 1.4, .day: 0.6, .dusk: 1.4, .night: 0.15],
                                 likes: [.openGround: 1, .shrub: 0.9, .flowers: 0.6, .seedPlants: 0.5], minHabitat: 0.18, alertRate: 0.25))

    static let squirrel = GroundProfile(
        species: .easternGraySquirrel, name: "Eastern Gray Squirrel", latin: "Sciurus carolinensis",
        blurb: "Bold and acrobatic. Buries nuts, raids feeders and runs up any tree or fence.",
        anatomy: GroundAnatomy(bodyLength: 0.21, bodyDepth: 0.1, bodyWidth: 0.085, headLength: 0.07, headWidth: 0.05, headHeight: 0.054, snout: 0.02,
                               earLength: 0.028, earWidth: 0.02, tailLength: 0.21, tailWidth: 0.075, foreLeg: 0.07, hindLeg: 0.085, legRadius: 0.009, pitch: 8, eyeRadius: 0.0065),
        palette: GroundPalette(back: 0x8D8C88, belly: 0xE8E4DC, accent: 0xC9C8C2, ear: 0x8D8C88, nose: 0x5E4A44, eye: 0x120E0C, claw: 0x3A332E, tail: 0x8A8985,
                               tailTip: 0xD2D0CA, face: 0x9A9894, flankLine: 0.6, pattern: 0.35, strands: 90),
        behavior: GroundBehavior(gait: .bound, walk: 0.7, run: 4.5, climbs: true, boldness: 0.8, skittishRadius: 1.2, rarity: 0.15, seasons: allSeasons,
                                 activity: [.dawn: 1, .day: 1.2, .dusk: 0.9, .night: 0],
                                 likes: [.tree: 1, .feeder: 0.9, .openGround: 0.5, .seedPlants: 0.4, .perch: 0.5], minHabitat: 0.15, alertRate: 0.35))

    static let chipmunk = GroundProfile(
        species: .easternChipmunk, name: "Eastern Chipmunk", latin: "Tamias striatus",
        blurb: "Striped and quick. Stuffs its cheeks with seed and darts between rocks and planters.",
        anatomy: GroundAnatomy(bodyLength: 0.12, bodyDepth: 0.06, bodyWidth: 0.05, headLength: 0.046, headWidth: 0.034, headHeight: 0.036, snout: 0.011,
                               earLength: 0.014, earWidth: 0.011, tailLength: 0.095, tailWidth: 0.025, foreLeg: 0.038, hindLeg: 0.05, legRadius: 0.006, pitch: 10, eyeRadius: 0.0042),
        palette: GroundPalette(back: 0xA5663C, belly: 0xEFE6D5, accent: 0x1E1612, ear: 0x8A5A38, nose: 0x6A4A40, eye: 0x0E0A08, claw: 0x4A3A30, tail: 0x7C5236,
                               tailTip: 0x2A1E16, face: 0xB88A66, flankLine: 0.56, pattern: 1, strands: 80),
        behavior: GroundBehavior(gait: .bound, walk: 0.5, run: 3.2, climbs: false, boldness: 0.9, skittishRadius: 0.9, rarity: 0.35, seasons: [.spring, .summer, .autumn],
                                 activity: [.dawn: 1, .day: 1.3, .dusk: 0.5, .night: 0],
                                 likes: [.seedPlants: 1, .feeder: 0.9, .shrub: 0.6, .openGround: 0.4, .tree: 0.4], minHabitat: 0.2, alertRate: 0.45))

    static let hedgehog = GroundProfile(
        species: .europeanHedgehog, name: "European Hedgehog", latin: "Erinaceus europaeus",
        blurb: "Snuffles through the garden after dusk, hunting beetles and snails under the leaves.",
        anatomy: GroundAnatomy(bodyLength: 0.2, bodyDepth: 0.11, bodyWidth: 0.12, headLength: 0.085, headWidth: 0.06, headHeight: 0.055, snout: 0.04,
                               earLength: 0.014, earWidth: 0.016, tailLength: 0.02, tailWidth: 0.014, foreLeg: 0.035, hindLeg: 0.038, legRadius: 0.0085, pitch: 4, eyeRadius: 0.0042,
                               whiskers: true, spines: true),
        palette: GroundPalette(back: 0x5A4A3A, belly: 0xC9B79A, accent: 0xD8CBB0, ear: 0xB69B80, nose: 0x241A16, eye: 0x0C0806, claw: 0x4A3C32, tail: 0xB69B80,
                               tailTip: 0xB69B80, face: 0xB39A7C, flankLine: 0.55, pattern: 0.6, strands: 60),
        behavior: GroundBehavior(gait: .walk, walk: 0.3, run: 1.1, climbs: false, boldness: 0.5, skittishRadius: 1.0, rarity: 0.7, seasons: [.spring, .summer, .autumn],
                                 activity: [.dawn: 0.5, .day: 0.05, .dusk: 1.4, .night: 1.6],
                                 likes: [.shrub: 1, .openGround: 0.7, .flowers: 0.4, .water: 0.5], minHabitat: 0.3, alertRate: 0.1))
}

/// Everything that can visit.
public enum AnimalKind: Hashable, Sendable, Codable, Identifiable {
    case bird(BirdSpecies)
    case ground(GroundSpecies)

    public var id: String { rawValue }

    public var rawValue: String {
        switch self { case .bird(let b): b.rawValue; case .ground(let g): g.rawValue }
    }

    public init?(rawValue: String) {
        if let b = BirdSpecies(rawValue: rawValue) { self = .bird(b) } else if let g = GroundSpecies(rawValue: rawValue) { self = .ground(g) } else { return nil }
    }

    public init(from d: Decoder) throws {
        let s = try d.singleValueContainer().decode(String.self)
        guard let k = AnimalKind(rawValue: s) else { throw DecodingError.dataCorrupted(.init(codingPath: d.codingPath, debugDescription: "unknown animal \(s)")) }
        self = k
    }

    public func encode(to e: Encoder) throws { var c = e.singleValueContainer(); try c.encode(rawValue) }

    public static var all: [AnimalKind] { BirdSpecies.allCases.map { .bird($0) } + GroundSpecies.allCases.map { .ground($0) } }

    public var name: String {
        switch self { case .bird(let b): b.profile.name; case .ground(let g): g.profile.name }
    }
    public var latin: String {
        switch self { case .bird(let b): b.profile.latin; case .ground(let g): g.profile.latin }
    }
    public var blurb: String {
        switch self { case .bird(let b): b.profile.blurb; case .ground(let g): g.profile.blurb }
    }
    public var rarity: Float {
        switch self { case .bird(let b): b.profile.behavior.rarity; case .ground(let g): g.profile.behavior.rarity }
    }
    public var isBird: Bool { if case .bird = self { true } else { false } }
}

public extension AnimalTuning {
    nonisolated(unsafe) static var groundSpeedScale: Float = 1
}
