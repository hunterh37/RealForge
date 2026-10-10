import Foundation
import RealCore

/// The ten bird species. Raw values are stable ids used in saved journals.
public enum BirdSpecies: String, CaseIterable, Codable, Sendable, Identifiable {
    case easternBluebird = "eastern-bluebird"
    case northernCardinal = "northern-cardinal"
    case blueJay = "blue-jay"
    case americanGoldfinch = "american-goldfinch"
    case americanRobin = "american-robin"
    case blackCappedChickadee = "black-capped-chickadee"
    case baltimoreOriole = "baltimore-oriole"
    case mourningDove = "mourning-dove"
    case rubyThroatedHummingbird = "ruby-throated-hummingbird"
    case cedarWaxwing = "cedar-waxwing"

    public var id: String { rawValue }
    public var profile: BirdProfile { BirdProfile.table[self]! }
}

/// Body proportions in meters and degrees. Birds face -Z with +Y up, feet at y = 0 when perched.
public struct BirdAnatomy: Sendable {
    /// Beak tip to tail tip.
    public var length: Float
    public var wingspan: Float
    /// Chest to vent.
    public var bodyLength: Float
    /// Back to belly.
    public var bodyDepth: Float
    public var bodyWidth: Float
    /// Angle of the body axis above horizontal when perched.
    public var restPitch: Float
    public var neckLength: Float
    /// Neck direction above the body axis, degrees.
    public var neckPitch: Float
    public var headLength: Float
    public var headWidth: Float
    public var headHeight: Float
    public var beakLength: Float
    public var beakDepth: Float
    public var beakWidth: Float
    /// Downward bend of the upper mandible over its length, meters.
    public var beakCurve: Float
    public var tailLength: Float
    public var tailWidth: Float
    /// Depth of the tail notch (0 square, positive forked, negative wedge).
    public var tailFork: Float
    public var tailFeathers: Int
    public var tarsus: Float
    public var toeLength: Float
    public var crestHeight: Float
    public var crestLength: Float
    public var eyeRadius: Float
    /// Chord at the wing root (shoulder to the trailing edge of the secondaries).
    public var wingChord: Float
    public var primaries: Int
    /// Flap the wing in burst-and-bound bouts (finches, chickadees).
    public var bounds: Bool

    /// Half span measured from the body side.
    public var halfSpan: Float { (wingspan - bodyWidth) / 2 }
    /// Height of the body center above the feet when perched.
    public var standHeight: Float { tarsus * 0.80 + tarsus * 0.45 + bodyDepth * 0.30 }
}

/// Habitat features a species looks for. Weights live in `BirdBehavior.likes`.
public enum HabitatFeature: String, CaseIterable, Codable, Sendable {
    /// Seed or nectar feeders.
    case feeder
    /// Birdbaths, fountains, barrels.
    case water
    /// Dense shrubs and hedges.
    case shrub
    /// Trees tall enough to perch in.
    case tree
    /// Flowering plants (nectar, insects).
    case flowers
    /// Grasses and seed heads.
    case seedPlants
    /// Nest boxes.
    case birdhouse
    /// Open grass or bare ground to forage on.
    case openGround
    /// Fences, rails, arches, posts to perch on.
    case perch
}

public struct BirdBehavior: Sendable {
    /// Cruise speed in m/s before `AnimalTuning.flightSpeedScale`.
    public var cruise: Float
    /// Visual wingbeat rate in Hz, capped for display frame rates.
    public var wingbeatHz: Float
    public var hovers: Bool
    /// 0...1: how readily it lands on an offered hand and tolerates people nearby.
    public var boldness: Float
    /// Distance in meters at which a sudden movement spooks it.
    public var skittishRadius: Float
    /// 0 stays on branches and fences, 1 forages on the ground.
    public var groundForaging: Float
    /// 0 low perches, 1 treetops.
    public var perchHeight: Float
    /// Chance per second to sing or call while perched and content.
    public var voiceRate: Float
    /// 0 common, 1 rare. Rare birds visit less and are worth more in the journal.
    public var rarity: Float
    public var seasons: Set<AnimalSeason>
    /// Activity multipliers by part of day.
    public var activity: [DayPart: Float]
    public var likes: [HabitatFeature: Float]
    /// Habitat score below which this species never visits.
    public var minHabitat: Float
}

public struct BirdProfile: Sendable {
    public var species: BirdSpecies
    public var name: String
    public var latin: String
    /// One line for the journal.
    public var blurb: String
    public var anatomy: BirdAnatomy
    public var plumage: Plumage
    public var behavior: BirdBehavior
    public var voice: BirdVoice
}

extension BirdProfile {
    static let table: [BirdSpecies: BirdProfile] = Dictionary(uniqueKeysWithValues: [
        bluebird, cardinal, blueJay, goldfinch, robin, chickadee, oriole, dove, hummingbird, waxwing,
    ].map { ($0.species, $0) })

    private static let allSeasons: Set<AnimalSeason> = [.spring, .summer, .autumn, .winter]
    private static let warm: Set<AnimalSeason> = [.spring, .summer, .autumn]
    private static let dayActive: [DayPart: Float] = [.dawn: 1.2, .day: 1, .dusk: 0.8, .night: 0]

    static let bluebird = BirdProfile(
        species: .easternBluebird, name: "Eastern Bluebird", latin: "Sialia sialis",
        blurb: "Rust breast and royal blue back. Nests in boxes at the edge of open lawn.",
        anatomy: BirdAnatomy(length: 0.17, wingspan: 0.30, bodyLength: 0.088, bodyDepth: 0.054, bodyWidth: 0.050, restPitch: 40,
                             neckLength: 0.016, neckPitch: 12, headLength: 0.036, headWidth: 0.031, headHeight: 0.033,
                             beakLength: 0.011, beakDepth: 0.0062, beakWidth: 0.0058, beakCurve: 0.0012, tailLength: 0.064, tailWidth: 0.036,
                             tailFork: 0.003, tailFeathers: 12, tarsus: 0.023, toeLength: 0.014, crestHeight: 0, crestLength: 0,
                             eyeRadius: 0.0033, wingChord: 0.062, primaries: 9, bounds: false),
        plumage: Plumage(crown: 0x3E6FCF, cheek: 0x3E6FCF, mask: 0xB8683C, back: 0x3F72D2, belly: 0xF1EEE8, breast: 0xB9673A, wing: 0x3A68C4,
                         flight: 0x2F4F9A, wingEdge: 0x5A86DA, tail: 0x2F57AE, tailEdge: 0x3E6FCF, beak: 0x1A1816,
                         breastExtent: 0.42, flankLine: 0.58, crownLine: 0.62, throatExtent: 0.5, maskExtent: 0, barring: 0, fringe: 0.12),
        behavior: BirdBehavior(cruise: 8, wingbeatHz: 9, hovers: false, boldness: 0.55, skittishRadius: 1.6, groundForaging: 0.45, perchHeight: 0.45,
                               voiceRate: 0.05, rarity: 0.55, seasons: warm, activity: dayActive,
                               likes: [.birdhouse: 1, .openGround: 0.8, .perch: 0.7, .water: 0.6, .feeder: 0.3, .tree: 0.3], minHabitat: 0.22),
        voice: .bluebird)

    static let cardinal = BirdProfile(
        species: .northernCardinal, name: "Northern Cardinal", latin: "Cardinalis cardinalis",
        blurb: "Crested red male with a black face. Stays all year and loves shrubs and seed.",
        anatomy: BirdAnatomy(length: 0.22, wingspan: 0.31, bodyLength: 0.108, bodyDepth: 0.066, bodyWidth: 0.058, restPitch: 38,
                             neckLength: 0.018, neckPitch: 10, headLength: 0.044, headWidth: 0.036, headHeight: 0.042,
                             beakLength: 0.016, beakDepth: 0.0165, beakWidth: 0.0125, beakCurve: 0.0015, tailLength: 0.108, tailWidth: 0.038,
                             tailFork: -0.008, tailFeathers: 12, tarsus: 0.026, toeLength: 0.017, crestHeight: 0.026, crestLength: 0.034,
                             eyeRadius: 0.0036, wingChord: 0.07, primaries: 9, bounds: false),
        plumage: Plumage(crown: 0xC9202B, cheek: 0xC9202B, mask: 0x120D0C, back: 0xB91E28, belly: 0xCE2A2F, breast: 0xD42A30, wing: 0xA7343A,
                         flight: 0x8B3A3C, wingEdge: 0xB9484A, tail: 0xA02C32, tailEdge: 0xB63B3D, beak: 0xE8643A,
                         eyeRing: 0x120D0C, breastExtent: 0.5, flankLine: 0.55, crownLine: 0.62, throatExtent: 0.22, maskExtent: 0.3, barring: 0, fringe: 0.1),
        behavior: BirdBehavior(cruise: 8, wingbeatHz: 8, hovers: false, boldness: 0.5, skittishRadius: 1.8, groundForaging: 0.5, perchHeight: 0.35,
                               voiceRate: 0.07, rarity: 0.3, seasons: allSeasons, activity: dayActive,
                               likes: [.shrub: 1, .feeder: 0.9, .seedPlants: 0.6, .water: 0.5, .tree: 0.4, .perch: 0.4], minHabitat: 0.2),
        voice: .cardinal)

    static let blueJay = BirdProfile(
        species: .blueJay, name: "Blue Jay", latin: "Cyanocitta cristata",
        blurb: "Loud, bold and crested, with a black necklace and white-tipped blue wings.",
        anatomy: BirdAnatomy(length: 0.28, wingspan: 0.41, bodyLength: 0.135, bodyDepth: 0.08, bodyWidth: 0.07, restPitch: 30,
                             neckLength: 0.022, neckPitch: 8, headLength: 0.054, headWidth: 0.042, headHeight: 0.046,
                             beakLength: 0.027, beakDepth: 0.0145, beakWidth: 0.0115, beakCurve: 0.0014, tailLength: 0.128, tailWidth: 0.046,
                             tailFork: -0.01, tailFeathers: 12, tarsus: 0.034, toeLength: 0.022, crestHeight: 0.034, crestLength: 0.04,
                             eyeRadius: 0.0042, wingChord: 0.092, primaries: 10, bounds: false),
        plumage: Plumage(crown: 0x4D7FCB, cheek: 0xEEF0F4, mask: 0x131414, back: 0x5B88CC, belly: 0xE6E8EC, breast: 0xC7CCD4, wing: 0x4F83CC,
                         flight: 0x2F5FB0, wingEdge: 0xF2F4F8, tail: 0x3F73C4, tailEdge: 0xF2F4F8, beak: 0x1B1B1C, eyeRing: 0xEEF0F4,
                         breastExtent: 0.3, flankLine: 0.52, crownLine: 0.55, throatExtent: 0.12, maskExtent: 0, barring: 0.85, fringe: 0.28),
        behavior: BirdBehavior(cruise: 9, wingbeatHz: 6.5, hovers: false, boldness: 0.85, skittishRadius: 1.0, groundForaging: 0.35, perchHeight: 0.8,
                               voiceRate: 0.1, rarity: 0.4, seasons: allSeasons, activity: dayActive,
                               likes: [.tree: 1, .feeder: 0.9, .seedPlants: 0.3, .water: 0.5, .perch: 0.5], minHabitat: 0.25),
        voice: .blueJay)

    static let goldfinch = BirdProfile(
        species: .americanGoldfinch, name: "American Goldfinch", latin: "Spinus tristis",
        blurb: "Lemon yellow with a black cap. Rides seed heads and hangs from feeders.",
        anatomy: BirdAnatomy(length: 0.125, wingspan: 0.215, bodyLength: 0.064, bodyDepth: 0.04, bodyWidth: 0.036, restPitch: 28,
                             neckLength: 0.012, neckPitch: 8, headLength: 0.026, headWidth: 0.022, headHeight: 0.024,
                             beakLength: 0.0095, beakDepth: 0.0078, beakWidth: 0.0065, beakCurve: 0.0004, tailLength: 0.048, tailWidth: 0.026,
                             tailFork: 0.009, tailFeathers: 12, tarsus: 0.014, toeLength: 0.01, crestHeight: 0, crestLength: 0,
                             eyeRadius: 0.0024, wingChord: 0.044, primaries: 9, bounds: true),
        plumage: Plumage(crown: 0x15130F, cheek: 0xF3D31A, mask: 0x15130F, back: 0xF0CF1A, belly: 0xF6D82A, breast: 0xF6D82A, wing: 0x1B1814,
                         flight: 0x17140F, wingEdge: 0xF1F1EA, tail: 0x1A1713, tailEdge: 0xF1F1EA, beak: 0xE6A276,
                         eyeRing: 0xF3D31A, breastExtent: 0, flankLine: 0.6, crownLine: 0.62, throatExtent: 0, maskExtent: 0.24, barring: 0, fringe: 0.3),
        behavior: BirdBehavior(cruise: 8.5, wingbeatHz: 11, hovers: false, boldness: 0.45, skittishRadius: 1.7, groundForaging: 0.2, perchHeight: 0.4,
                               voiceRate: 0.09, rarity: 0.45, seasons: warm, activity: dayActive,
                               likes: [.feeder: 1, .seedPlants: 1, .flowers: 0.7, .water: 0.5, .shrub: 0.3], minHabitat: 0.2),
        voice: .goldfinch)

    static let robin = BirdProfile(
        species: .americanRobin, name: "American Robin", latin: "Turdus migratorius",
        blurb: "Brick-orange breast and yellow bill. Hops across lawns listening for worms.",
        anatomy: BirdAnatomy(length: 0.25, wingspan: 0.38, bodyLength: 0.122, bodyDepth: 0.072, bodyWidth: 0.064, restPitch: 44,
                             neckLength: 0.02, neckPitch: 12, headLength: 0.046, headWidth: 0.036, headHeight: 0.04,
                             beakLength: 0.017, beakDepth: 0.0078, beakWidth: 0.0072, beakCurve: 0.0008, tailLength: 0.092, tailWidth: 0.042,
                             tailFork: 0, tailFeathers: 12, tarsus: 0.036, toeLength: 0.02, crestHeight: 0, crestLength: 0,
                             eyeRadius: 0.0038, wingChord: 0.082, primaries: 9, bounds: false),
        plumage: Plumage(crown: 0x2F2D2B, cheek: 0x2F2D2B, mask: 0x2F2D2B, back: 0x5A5750, belly: 0xE9E5DC, breast: 0xC2652E, wing: 0x55524B,
                         flight: 0x46433D, wingEdge: 0x77746B, tail: 0x34322E, tailEdge: 0x46433D, beak: 0xE3B220,
                         eyeRing: 0xEDE9E0, breastExtent: 0.55, flankLine: 0.5, crownLine: 0.6, throatExtent: 0.3, maskExtent: 0, barring: 0, fringe: 0.18),
        behavior: BirdBehavior(cruise: 8, wingbeatHz: 8, hovers: false, boldness: 0.6, skittishRadius: 1.4, groundForaging: 0.95, perchHeight: 0.35,
                               voiceRate: 0.06, rarity: 0.1, seasons: [.spring, .summer, .autumn], activity: dayActive,
                               likes: [.openGround: 1, .water: 0.9, .tree: 0.6, .shrub: 0.4, .flowers: 0.2], minHabitat: 0.12),
        voice: .robin)

    static let chickadee = BirdProfile(
        species: .blackCappedChickadee, name: "Black-capped Chickadee", latin: "Poecile atricapillus",
        blurb: "Tiny, curious and fearless. Takes seed from a still hand.",
        anatomy: BirdAnatomy(length: 0.13, wingspan: 0.2, bodyLength: 0.066, bodyDepth: 0.044, bodyWidth: 0.038, restPitch: 30,
                             neckLength: 0.01, neckPitch: 10, headLength: 0.03, headWidth: 0.027, headHeight: 0.028,
                             beakLength: 0.0075, beakDepth: 0.0047, beakWidth: 0.0045, beakCurve: 0.0003, tailLength: 0.06, tailWidth: 0.026,
                             tailFork: 0, tailFeathers: 12, tarsus: 0.016, toeLength: 0.011, crestHeight: 0, crestLength: 0,
                             eyeRadius: 0.0028, wingChord: 0.046, primaries: 9, bounds: false),
        plumage: Plumage(crown: 0x0E0E0E, cheek: 0xF2F2EE, mask: 0x0E0E0E, back: 0x8C9298, belly: 0xF1EFE8, breast: 0xDCC3A2, wing: 0x7F868D,
                         flight: 0x6E757C, wingEdge: 0xE3E5E6, tail: 0x70777E, tailEdge: 0xB8BDC1, beak: 0x1B1B1B,
                         eyeRing: 0xF2F2EE, breastExtent: 0.0, flankLine: 0.6, crownLine: 0.52, throatExtent: 0.22, maskExtent: 0, barring: 0, fringe: 0.3),
        behavior: BirdBehavior(cruise: 7, wingbeatHz: 13, hovers: false, boldness: 1, skittishRadius: 0.7, groundForaging: 0.1, perchHeight: 0.5,
                               voiceRate: 0.12, rarity: 0.2, seasons: allSeasons, activity: dayActive,
                               likes: [.feeder: 1, .tree: 0.8, .shrub: 0.6, .birdhouse: 0.5, .water: 0.3], minHabitat: 0.15),
        voice: .chickadee)

    static let oriole = BirdProfile(
        species: .baltimoreOriole, name: "Baltimore Oriole", latin: "Icterus galbula",
        blurb: "Flame orange and black. Arrives in spring for nectar, fruit and tall trees.",
        anatomy: BirdAnatomy(length: 0.19, wingspan: 0.29, bodyLength: 0.098, bodyDepth: 0.054, bodyWidth: 0.048, restPitch: 36,
                             neckLength: 0.016, neckPitch: 10, headLength: 0.04, headWidth: 0.031, headHeight: 0.033,
                             beakLength: 0.021, beakDepth: 0.0085, beakWidth: 0.0072, beakCurve: 0.0008, tailLength: 0.078, tailWidth: 0.034,
                             tailFork: 0.002, tailFeathers: 12, tarsus: 0.024, toeLength: 0.015, crestHeight: 0, crestLength: 0,
                             eyeRadius: 0.0033, wingChord: 0.066, primaries: 9, bounds: false),
        plumage: Plumage(crown: 0x100E0D, cheek: 0x100E0D, mask: 0x100E0D, back: 0x141210, belly: 0xF58A1C, breast: 0xF58A1C, wing: 0x171412,
                         flight: 0x121010, wingEdge: 0xF3F0E8, tail: 0x141210, tailEdge: 0xF58A1C, beak: 0x8C97A4,
                         eyeRing: 0x100E0D, breastExtent: 0, flankLine: 0.38, crownLine: 0.8, throatExtent: 0, maskExtent: 0, barring: 0, fringe: 0.3),
        behavior: BirdBehavior(cruise: 8.5, wingbeatHz: 9, hovers: false, boldness: 0.4, skittishRadius: 2, groundForaging: 0.1, perchHeight: 0.95,
                               voiceRate: 0.08, rarity: 0.7, seasons: [.spring, .summer], activity: dayActive,
                               likes: [.tree: 1, .flowers: 0.8, .feeder: 0.8, .water: 0.4, .shrub: 0.2], minHabitat: 0.3),
        voice: .oriole)

    static let dove = BirdProfile(
        species: .mourningDove, name: "Mourning Dove", latin: "Zenaida macroura",
        blurb: "Soft grey-brown and long-tailed. Feeds on the ground and coos from wires.",
        anatomy: BirdAnatomy(length: 0.31, wingspan: 0.45, bodyLength: 0.15, bodyDepth: 0.078, bodyWidth: 0.07, restPitch: 20,
                             neckLength: 0.034, neckPitch: 22, headLength: 0.034, headWidth: 0.027, headHeight: 0.029,
                             beakLength: 0.012, beakDepth: 0.0052, beakWidth: 0.005, beakCurve: 0.0014, tailLength: 0.15, tailWidth: 0.04,
                             tailFork: -0.05, tailFeathers: 12, tarsus: 0.02, toeLength: 0.018, crestHeight: 0, crestLength: 0,
                             eyeRadius: 0.0034, wingChord: 0.092, primaries: 10, bounds: false),
        plumage: Plumage(crown: 0xA39C98, cheek: 0xB8A590, mask: 0x2B2622, back: 0xA38C78, belly: 0xCDB8A2, breast: 0xCFA896, wing: 0xA08A76,
                         flight: 0x6E6A68, wingEdge: 0xB9B0A8, tail: 0x8F8985, tailEdge: 0xE7E4DF, beak: 0x2B2825, leg: 0xC4626C,
                         eyeRing: 0x6B9ACB, breastExtent: 0.4, flankLine: 0.55, spotting: 0.0, crownLine: 0.55, throatExtent: 0.0, maskExtent: 0, barring: 0.25, fringe: 0.22),
        behavior: BirdBehavior(cruise: 9.5, wingbeatHz: 5.5, hovers: false, boldness: 0.55, skittishRadius: 1.5, groundForaging: 0.9, perchHeight: 0.45,
                               voiceRate: 0.06, rarity: 0.12, seasons: allSeasons, activity: dayActive,
                               likes: [.openGround: 1, .seedPlants: 0.8, .feeder: 0.6, .water: 0.7, .perch: 0.8, .tree: 0.5], minHabitat: 0.12),
        voice: .dove)

    static let hummingbird = BirdProfile(
        species: .rubyThroatedHummingbird, name: "Ruby-throated Hummingbird", latin: "Archilochus colubris",
        blurb: "Hovers at flowers and feeders on wings too fast to see. Gorget flashes ruby.",
        anatomy: BirdAnatomy(length: 0.09, wingspan: 0.118, bodyLength: 0.042, bodyDepth: 0.025, bodyWidth: 0.021, restPitch: 22,
                             neckLength: 0.007, neckPitch: 8, headLength: 0.019, headWidth: 0.016, headHeight: 0.0165,
                             beakLength: 0.02, beakDepth: 0.0026, beakWidth: 0.0026, beakCurve: 0.0008, tailLength: 0.026, tailWidth: 0.016,
                             tailFork: 0.008, tailFeathers: 10, tarsus: 0.006, toeLength: 0.006, crestHeight: 0, crestLength: 0,
                             eyeRadius: 0.0018, wingChord: 0.02, primaries: 10, bounds: false),
        plumage: Plumage(crown: 0x2E8A4A, cheek: 0x2E7A44, mask: 0xC0102E, back: 0x2F9A4C, belly: 0xDCDCD2, breast: 0xDCDCD2, wing: 0x4A4A48,
                         flight: 0x3B3A3A, wingEdge: 0x55524F, tail: 0x2E3A36, tailEdge: 0x2E3A36, beak: 0x141211, leg: 0x2B2825,
                         eyeRing: 0x2E7A44, breastExtent: 0, flankLine: 0.55, crownLine: 0.62, throatExtent: 0.5, maskExtent: 0, barring: 0, fringe: 0.05,
                         featherRows: 44, iridescence: 1),
        behavior: BirdBehavior(cruise: 7, wingbeatHz: 22, hovers: true, boldness: 0.7, skittishRadius: 1.2, groundForaging: 0, perchHeight: 0.6,
                               voiceRate: 0.04, rarity: 0.8, seasons: [.spring, .summer], activity: [.dawn: 1, .day: 1, .dusk: 0.7, .night: 0],
                               likes: [.flowers: 1, .feeder: 0.9, .shrub: 0.3, .water: 0.3, .tree: 0.2], minHabitat: 0.35),
        voice: .hummingbird)

    static let waxwing = BirdProfile(
        species: .cedarWaxwing, name: "Cedar Waxwing", latin: "Bombycilla cedrorum",
        blurb: "Silky fawn with a black mask, yellow tail band and red wax tips. Travels in flocks.",
        anatomy: BirdAnatomy(length: 0.17, wingspan: 0.29, bodyLength: 0.088, bodyDepth: 0.052, bodyWidth: 0.046, restPitch: 34,
                             neckLength: 0.014, neckPitch: 10, headLength: 0.036, headWidth: 0.029, headHeight: 0.032,
                             beakLength: 0.0105, beakDepth: 0.0068, beakWidth: 0.0068, beakCurve: 0.0006, tailLength: 0.056, tailWidth: 0.032,
                             tailFork: 0, tailFeathers: 12, tarsus: 0.018, toeLength: 0.013, crestHeight: 0.018, crestLength: 0.026,
                             eyeRadius: 0.0032, wingChord: 0.064, primaries: 9, bounds: false),
        plumage: Plumage(crown: 0xA98B6A, cheek: 0xB59877, mask: 0x131110, back: 0x9C8363, belly: 0xE6D493, breast: 0xC3A47D, wing: 0x8C8479,
                         flight: 0x6F6A66, wingEdge: 0xB43A2C, tail: 0x7A7C80, tailEdge: 0xF2D126, beak: 0x232120,
                         eyeRing: 0x131110, breastExtent: 0.5, flankLine: 0.55, crownLine: 0.6, throatExtent: 0.1, maskExtent: 0.28, barring: 0, fringe: 0.4),
        behavior: BirdBehavior(cruise: 9, wingbeatHz: 9, hovers: false, boldness: 0.35, skittishRadius: 2, groundForaging: 0.05, perchHeight: 0.8,
                               voiceRate: 0.08, rarity: 0.85, seasons: [.summer, .autumn, .winter], activity: dayActive,
                               likes: [.water: 1, .tree: 0.9, .shrub: 0.7, .flowers: 0.4, .feeder: 0.2], minHabitat: 0.3),
        voice: .waxwing)
}
