import Foundation

/// Season as the animals see it. Apps map their own season type onto this.
public enum AnimalSeason: String, Codable, CaseIterable, Sendable {
    case spring, summer, autumn, winter
}

/// Coarse time of day. Birds are most active at dawn and dusk.
public enum DayPart: String, Codable, CaseIterable, Sendable {
    case dawn, day, dusk, night

    /// Part of day for an hour in 0..<24.
    public init(hour: Double) {
        switch hour {
        case 5..<8: self = .dawn
        case 8..<18: self = .day
        case 18..<21: self = .dusk
        default: self = .night
        }
    }
}

/// Weather as the animals see it.
public struct AnimalWeather: Sendable, Equatable {
    public enum Kind: String, Sendable, CaseIterable { case clear, fog, rain, snow, storm }
    public var kind: Kind
    /// 0...1.
    public var intensity: Float
    public init(kind: Kind = .clear, intensity: Float = 0) { self.kind = kind; self.intensity = intensity }

    /// How much of its usual activity an animal keeps in this weather (0 stays hidden).
    public var activity: Float {
        switch kind {
        case .clear: 1
        case .fog: 0.8
        case .rain: max(0, 0.55 - intensity * 0.55)
        case .snow: max(0.15, 0.7 - intensity * 0.4)
        case .storm: 0
        }
    }
}
