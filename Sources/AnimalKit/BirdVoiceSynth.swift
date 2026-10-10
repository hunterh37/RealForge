import Foundation
import AVFoundation
import RealityKit
import AnimalCore

/// Procedural bird song and call synthesis. No audio files ship in the package.
@MainActor
public enum BirdVoiceSynth {
    nonisolated static let rate: Double = 44_100
    private static var cache: [String: AudioBufferResource] = [:]

    public enum Clip: Hashable, Sendable {
        case song(Int), call(Int), hum, takeoff, clap
    }

    public static func resource(_ s: BirdSpecies, _ clip: Clip) -> AudioBufferResource? {
        let key = "\(s.rawValue)#\(clip)"
        if let r = cache[key] { return r }
        let v = s.profile.voice
        var samples: [Float]
        var loop = false
        switch clip {
        case .song(let i): guard !v.songs.isEmpty else { return nil }; samples = render(v.songs[i % v.songs.count], gain: v.loudness)
        case .call(let i): guard !v.calls.isEmpty else { return nil }; samples = render(v.calls[i % v.calls.count], gain: v.loudness)
        case .hum: guard let hz = v.hum else { return nil }; samples = hum(hz); loop = true
        case .takeoff: samples = flutter(seconds: 0.35, level: 0.35, seed: 4)
        case .clap: samples = flutter(seconds: 0.25, level: 0.7, seed: 9, clap: true)
        }
        guard let r = make(samples, loop: loop) else { return nil }
        cache[key] = r
        return r
    }

    private static func make(_ s: [Float], loop: Bool) -> AudioBufferResource? {
        guard !s.isEmpty, let fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(s.count)) else { return nil }
        buf.frameLength = AVAudioFrameCount(s.count)
        let ch = buf.floatChannelData![0]
        for i in s.indices { ch[i] = s[i] }
        return try? AudioBufferResource(buffer: buf, configuration: .init(shouldLoop: loop))
    }

    /// Renders notes to mono PCM.
    nonisolated static func render(_ notes: [VoiceSyllable], gain: Float) -> [Float] {
        var out: [Float] = []
        var rng = SeededRNG(seed: UInt64(notes.count * 977 + 13))
        var phase: Double = 0
        for n in notes {
            let len = Int(Double(n.duration) * rate)
            for i in 0..<len {
                let u = Float(i) / Float(max(1, len - 1))
                let t = Float(i) / Float(rate)
                var f = contour(n.contour, u)
                if n.vibrato.x > 0 { f += n.vibrato.x * sin(2 * .pi * n.vibrato.y * t) }
                phase += 2 * Double.pi * Double(f) / rate
                var s: Float = 0
                for (k, h) in n.harmonics.enumerated() { s += h * Float(sin(phase * Double(k + 1))) }
                s /= max(1, n.harmonics.reduce(0, +))
                if n.noise > 0 { s = s * (1 - n.noise) + s * rng.float(-1...1) * n.noise * 2 }
                var env = pow(max(0, sin(.pi * u)), 0.45)
                env *= min(1, Float(i) / 220) * min(1, Float(len - i) / 330)
                if n.tremolo.x > 0 { env *= 1 - n.tremolo.x * (0.5 + 0.5 * sin(2 * .pi * n.tremolo.y * t)) }
                out.append(s * env * n.amp * gain * 0.6)
            }
            out.append(contentsOf: [Float](repeating: 0, count: Int(Double(n.gap) * rate)))
        }
        out.append(contentsOf: [Float](repeating: 0, count: 2_000))
        return out
    }

    nonisolated static func contour(_ pts: [V2], _ u: Float) -> Float {
        guard let f = pts.first, let l = pts.last else { return 3000 }
        if u <= f.x { return f.y }
        if u >= l.x { return l.y }
        for i in 0..<(pts.count - 1) where u <= pts[i + 1].x {
            let a = pts[i], b = pts[i + 1]
            let k = (u - a.x) / max(1e-5, b.x - a.x)
            return exp(log(a.y) + (log(b.y) - log(a.y)) * k)
        }
        return l.y
    }

    /// Looping wing hum: a buzzing fundamental with amplitude beats.
    nonisolated static func hum(_ hz: Float) -> [Float] {
        let n = Int(rate)
        return (0..<n).map { i in
            let t = Double(i) / rate
            let beat = 0.75 + 0.25 * sin(2 * Double.pi * 3 * t)
            let tone = sin(2 * Double.pi * Double(hz) * t) + 0.5 * sin(2 * Double.pi * Double(hz) * 2 * t) + 0.25 * sin(2 * Double.pi * Double(hz) * 3 * t)
            return Float(tone * beat * 0.12)
        }
    }

    /// Short feathery noise burst: takeoff flutter or a dove's wing clap.
    nonisolated static func flutter(seconds: Float, level: Float, seed: UInt64, clap: Bool = false) -> [Float] {
        var rng = SeededRNG(seed: seed)
        let n = Int(Double(seconds) * rate)
        var lp: Float = 0
        return (0..<n).map { i in
            let u = Float(i) / Float(n)
            let beats = clap ? 0.5 + 0.5 * sin(u * 2 * .pi * 3 * (1 - u)) : 0.5 + 0.5 * sin(u * 2 * .pi * 9)
            let env = sin(.pi * min(1, u * 1.2)) * (1 - u) * beats
            lp += (rng.float(-1...1) - lp) * (clap ? 0.45 : 0.2)
            return lp * env * level
        }
    }
}
