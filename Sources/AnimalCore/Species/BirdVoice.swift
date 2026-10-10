import Foundation
import RealCore

/// One note: a pitch contour, an envelope and a timbre. `AnimalKit.BirdVoiceSynth` renders it.
public struct VoiceSyllable: Sendable, Equatable {
    /// (time 0...1, frequency Hz) breakpoints, interpolated in log frequency.
    public var contour: [V2]
    public var duration: Float
    /// Silence after the note, seconds.
    public var gap: Float
    public var amp: Float
    /// Relative amplitude of partials 1, 2, 3...
    public var harmonics: [Float]
    /// Frequency modulation: peak deviation in Hz and rate in Hz.
    public var vibrato: V2
    /// Amplitude modulation: depth 0...1 and rate in Hz (trills, rasps).
    public var tremolo: V2
    /// Noise mixed into the tone, 0...1 (rasp, hiss).
    public var noise: Float

    public init(_ contour: [V2], duration: Float, gap: Float = 0.05, amp: Float = 0.8, harmonics: [Float] = [1, 0.25, 0.08],
                vibrato: V2 = .zero, tremolo: V2 = .zero, noise: Float = 0) {
        self.contour = contour; self.duration = duration; self.gap = gap; self.amp = amp; self.harmonics = harmonics
        self.vibrato = vibrato; self.tremolo = tremolo; self.noise = noise
    }

    /// Straight glide from `a` Hz to `b` Hz.
    public static func slide(_ a: Float, _ b: Float, _ d: Float, gap: Float = 0.05, amp: Float = 0.8, harmonics: [Float] = [1, 0.25, 0.08],
                             vibrato: V2 = .zero, tremolo: V2 = .zero, noise: Float = 0) -> VoiceSyllable {
        VoiceSyllable([V2(0, a), V2(1, b)], duration: d, gap: gap, amp: amp, harmonics: harmonics, vibrato: vibrato, tremolo: tremolo, noise: noise)
    }

    /// Rises or falls through `peak` in the middle.
    public static func arc(_ a: Float, _ peak: Float, _ b: Float, _ d: Float, gap: Float = 0.05, amp: Float = 0.8,
                           harmonics: [Float] = [1, 0.25, 0.08], vibrato: V2 = .zero, tremolo: V2 = .zero, noise: Float = 0) -> VoiceSyllable {
        VoiceSyllable([V2(0, a), V2(0.5, peak), V2(1, b)], duration: d, gap: gap, amp: amp, harmonics: harmonics, vibrato: vibrato, tremolo: tremolo, noise: noise)
    }

    /// Steady pitch.
    public static func hold(_ f: Float, _ d: Float, gap: Float = 0.05, amp: Float = 0.8, harmonics: [Float] = [1, 0.25, 0.08],
                            vibrato: V2 = .zero, tremolo: V2 = .zero, noise: Float = 0) -> VoiceSyllable {
        slide(f, f, d, gap: gap, amp: amp, harmonics: harmonics, vibrato: vibrato, tremolo: tremolo, noise: noise)
    }
}

/// What a species sounds like: songs (sung while perched and content), calls (alarm, flight, contact)
/// and an optional wing hum. A song or call is picked at random from its list.
public struct BirdVoice: Sendable {
    public var songs: [[VoiceSyllable]]
    public var calls: [[VoiceSyllable]]
    /// Wing hum fundamental in Hz while hovering (hummingbirds), nil for none.
    public var hum: Float?
    /// Overall level 0...1 relative to other species (hummingbirds are quiet, jays loud).
    public var loudness: Float

    public init(songs: [[VoiceSyllable]], calls: [[VoiceSyllable]], hum: Float? = nil, loudness: Float = 0.7) {
        self.songs = songs; self.calls = calls; self.hum = hum; self.loudness = loudness
    }
}

public extension BirdVoice {
    static let bluebird = BirdVoice(
        songs: [[.arc(2100, 2500, 1850, 0.26, amp: 0.7, vibrato: V2(30, 14)), .slide(2300, 1750, 0.2, amp: 0.6, vibrato: V2(25, 12)),
                 .arc(1900, 2400, 1900, 0.3, gap: 0.12, amp: 0.7, vibrato: V2(35, 14))]],
        calls: [[.slide(2600, 1900, 0.16, amp: 0.7, vibrato: V2(20, 12)), .slide(2500, 1850, 0.14, amp: 0.6, vibrato: V2(20, 12))]],
        loudness: 0.5)

    static let cardinal = BirdVoice(
        songs: [[.slide(3900, 1800, 0.3, gap: 0.12, amp: 0.8), .slide(3900, 1800, 0.3, gap: 0.12, amp: 0.8), .slide(3900, 1800, 0.3, gap: 0.12, amp: 0.8),
                 .slide(2000, 3500, 0.1, gap: 0.05, amp: 0.7), .slide(2000, 3500, 0.1, gap: 0.05, amp: 0.7), .slide(2000, 3500, 0.1, gap: 0.05, amp: 0.7),
                 .slide(2000, 3500, 0.1, gap: 0.08, amp: 0.7)]],
        calls: [[.hold(5200, 0.045, gap: 0.12, amp: 0.9, harmonics: [1, 0.4, 0.2], noise: 0.12)]],
        loudness: 0.75)

    static let blueJay = BirdVoice(
        songs: [[.arc(2900, 3300, 2400, 0.22, gap: 0.2, amp: 0.95, harmonics: [1, 0.7, 0.5, 0.3], tremolo: V2(0.35, 70), noise: 0.3),
                 .arc(2900, 3300, 2400, 0.22, gap: 0.2, amp: 0.95, harmonics: [1, 0.7, 0.5, 0.3], tremolo: V2(0.35, 70), noise: 0.3)]],
        calls: [[.arc(2700, 3100, 2300, 0.2, gap: 0.1, amp: 0.95, harmonics: [1, 0.7, 0.5, 0.3], tremolo: V2(0.4, 80), noise: 0.35)],
                [.slide(1900, 2600, 0.35, gap: 0.1, amp: 0.7, harmonics: [1, 0.2], vibrato: V2(30, 9))]],
        loudness: 1)

    static let goldfinch = BirdVoice(
        songs: [[.slide(3300, 5000, 0.07, gap: 0.02, amp: 0.7), .slide(3600, 5200, 0.07, gap: 0.02, amp: 0.7), .slide(3400, 4900, 0.07, gap: 0.04, amp: 0.7),
                 .arc(4200, 5600, 3800, 0.12, gap: 0.03, amp: 0.6), .slide(3500, 5100, 0.06, gap: 0.02, amp: 0.7), .slide(5000, 3300, 0.09, gap: 0.05, amp: 0.7),
                 .slide(3200, 4800, 0.07, gap: 0.02, amp: 0.7), .arc(3900, 5400, 3700, 0.14, gap: 0.05, amp: 0.6)]],
        calls: [[.slide(3000, 4400, 0.09, gap: 0.05, amp: 0.75), .slide(3200, 4600, 0.08, gap: 0.05, amp: 0.75), .slide(3300, 4700, 0.08, gap: 0.05, amp: 0.75),
                 .slide(2600, 3700, 0.12, gap: 0.05, amp: 0.75)]],
        loudness: 0.5)

    static let robin = BirdVoice(
        songs: [[.arc(2100, 2900, 2500, 0.2, amp: 0.8, vibrato: V2(20, 9)), .slide(2900, 2200, 0.16, gap: 0.08, amp: 0.8),
                 .arc(2300, 3100, 2200, 0.22, gap: 0.14, amp: 0.8, vibrato: V2(25, 11)), .slide(2300, 2800, 0.14, gap: 0.05, amp: 0.7),
                 .slide(2800, 2150, 0.18, gap: 0.2, amp: 0.8), .arc(2000, 2700, 2400, 0.24, gap: 0.1, amp: 0.8, vibrato: V2(30, 10))]],
        calls: [[.hold(2900, 0.05, gap: 0.08, amp: 0.8, harmonics: [1, 0.5, 0.3], noise: 0.1), .hold(2900, 0.05, gap: 0.08, amp: 0.8, harmonics: [1, 0.5, 0.3], noise: 0.1),
                 .hold(2900, 0.05, gap: 0.08, amp: 0.8, harmonics: [1, 0.5, 0.3], noise: 0.1)]],
        loudness: 0.7)

    static let chickadee = BirdVoice(
        songs: [[.hold(3500, 0.42, gap: 0.08, amp: 0.7, harmonics: [1, 0.12]), .hold(3050, 0.52, gap: 0.5, amp: 0.7, harmonics: [1, 0.12]),
                 .hold(3500, 0.4, gap: 0.08, amp: 0.7, harmonics: [1, 0.12]), .hold(3050, 0.5, gap: 0.4, amp: 0.7, harmonics: [1, 0.12])]],
        calls: [[.slide(4200, 3800, 0.06, gap: 0.04, amp: 0.7, noise: 0.15), .slide(4400, 3900, 0.06, gap: 0.04, amp: 0.7, noise: 0.15),
                 .slide(3900, 3100, 0.12, gap: 0.03, amp: 0.8, harmonics: [1, 0.6, 0.3], tremolo: V2(0.4, 55), noise: 0.2),
                 .slide(3700, 3000, 0.12, gap: 0.03, amp: 0.8, harmonics: [1, 0.6, 0.3], tremolo: V2(0.4, 55), noise: 0.2)]],
        loudness: 0.45)

    static let oriole = BirdVoice(
        songs: [[.arc(1900, 2400, 2000, 0.24, amp: 0.8, harmonics: [1, 0.15], vibrato: V2(20, 8)), .hold(2700, 0.1, gap: 0.04, amp: 0.8, harmonics: [1, 0.15]),
                 .slide(2100, 2800, 0.2, gap: 0.08, amp: 0.8, harmonics: [1, 0.15]), .hold(2300, 0.14, gap: 0.05, amp: 0.8, harmonics: [1, 0.15]),
                 .arc(2600, 3000, 2200, 0.26, gap: 0.1, amp: 0.8, harmonics: [1, 0.15], vibrato: V2(25, 9))]],
        calls: [[.slide(2200, 3000, 0.16, gap: 0.05, amp: 0.8, vibrato: V2(30, 14)), .slide(2300, 3100, 0.16, gap: 0.05, amp: 0.8, vibrato: V2(30, 14))],
                [.hold(3000, 0.4, gap: 0.05, amp: 0.7, harmonics: [1, 0.5, 0.4], tremolo: V2(0.7, 45), noise: 0.35)]],
        loudness: 0.65)

    static let dove = BirdVoice(
        songs: [[.slide(430, 530, 0.4, gap: 0.12, amp: 0.8, harmonics: [1, 0.1], vibrato: V2(6, 6)), .arc(560, 640, 520, 0.8, gap: 0.12, amp: 1, harmonics: [1, 0.12], vibrato: V2(10, 6.5)),
                 .hold(520, 0.42, gap: 0.14, amp: 0.8, harmonics: [1, 0.1], vibrato: V2(7, 6)), .hold(510, 0.42, gap: 0.14, amp: 0.75, harmonics: [1, 0.1], vibrato: V2(7, 6)),
                 .hold(500, 0.42, gap: 0.2, amp: 0.7, harmonics: [1, 0.1], vibrato: V2(7, 6))]],
        calls: [[.slide(1400, 1700, 0.16, gap: 0.04, amp: 0.5, harmonics: [1, 0.2], noise: 0.3)]],
        loudness: 0.6)

    static let hummingbird = BirdVoice(
        songs: [[.slide(5200, 7600, 0.04, gap: 0.03, amp: 0.55), .slide(7400, 5600, 0.04, gap: 0.03, amp: 0.55), .slide(5400, 7900, 0.04, gap: 0.03, amp: 0.55),
                 .slide(7600, 5200, 0.05, gap: 0.03, amp: 0.55), .slide(5300, 7800, 0.04, gap: 0.03, amp: 0.55), .slide(7700, 5500, 0.04, gap: 0.05, amp: 0.55)]],
        calls: [[.slide(6800, 8200, 0.035, gap: 0.05, amp: 0.55), .slide(6900, 8300, 0.035, gap: 0.05, amp: 0.55)]],
        hum: 95, loudness: 0.35)

    static let waxwing = BirdVoice(
        songs: [[.slide(7400, 8400, 0.9, gap: 0.3, amp: 0.45, harmonics: [1, 0.05], vibrato: V2(120, 14), tremolo: V2(0.25, 22))]],
        calls: [[.slide(7000, 8200, 0.7, gap: 0.2, amp: 0.45, harmonics: [1, 0.05], vibrato: V2(150, 16), tremolo: V2(0.3, 24))]],
        loudness: 0.4)
}
