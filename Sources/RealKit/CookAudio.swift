import Foundation
import AVFoundation
import RealityKit
import RealCore

/// Procedural kitchen sounds as RealityKit audio resources: no audio files ship in the package.
/// Loops (sizzle, boil, burner roar) are meant for one `AudioPlaybackController` each with gain
/// driven from the cooking state; one-shots (chop, ignite, flip) are played per event.
@MainActor
public enum RealCookAudio {
    public enum Sound: String, CaseIterable, Sendable {
        /// Fat spitting around wet food in a hot pan: hiss plus crackle pops. Loop.
        case sizzle
        /// Rolling boil: low bubbling. Loop.
        case boil
        /// Gas burner: soft broadband roar. Loop.
        case burner
        /// Knife through food onto an end-grain board. One-shot.
        case chop
        /// Piezo igniter clicks then the whump of the flame. One-shot.
        case ignite
        /// Food dropped into a hot pan: burst of sizzle. One-shot.
        case drop
        /// Whisk wires against a steel bowl. Loop.
        case whisk
    }

    private static var cache: [Sound: AudioBufferResource] = [:]
    nonisolated static let rate: Double = 44_100

    /// Spatial audio resource for `sound`, generated on first use (~10 ms) and cached.
    public static func resource(_ sound: Sound) throws -> AudioBufferResource {
        if let r = cache[sound] { return r }
        let loop: Bool
        let samples: [Float]
        var rng = SeededRNG(seed: UInt64(sound.rawValue.hashValue & 0xFFFF) &+ 7)
        switch sound {
        case .sizzle: samples = sizzle(seconds: 4, &rng); loop = true
        case .boil: samples = boil(seconds: 4, &rng); loop = true
        case .burner: samples = roar(seconds: 3, &rng); loop = true
        case .chop: samples = chop(&rng); loop = false
        case .ignite: samples = ignite(&rng); loop = false
        case .drop: samples = drop(&rng); loop = false
        case .whisk: samples = whisk(seconds: 2, &rng); loop = true
        }
        let r = try make(loop ? crossfadeLoop(samples) : samples, loop: loop)
        cache[sound] = r
        return r
    }

    /// Gain in decibels for a 0...1 intensity (silence below 0.01).
    public static func decibels(_ intensity: Float) -> Double {
        intensity < 0.01 ? -80 : Double(20 * log10(max(intensity, 0.0001)))
    }

    // MARK: synthesis

    private static func make(_ s: [Float], loop: Bool) throws -> AudioBufferResource {
        let fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(s.count))!
        buf.frameLength = AVAudioFrameCount(s.count)
        let ch = buf.floatChannelData![0]
        for i in s.indices { ch[i] = s[i] }
        let cfg = AudioBufferResource.Configuration(shouldLoop: loop)
        return try AudioBufferResource(buffer: buf, configuration: cfg)
    }

    /// Blends the tail into the head so the loop point is seamless.
    private static func crossfadeLoop(_ s: [Float]) -> [Float] {
        let n = s.count, f = min(n / 4, Int(rate * 0.25))
        var out = Array(s[0..<(n - f)])
        for i in 0..<f {
            let t = Float(i) / Float(f)
            out[i] = s[i] * t + s[n - f + i] * (1 - t)
        }
        return out
    }

    private struct Biquad {
        var b0: Float, b1: Float, b2: Float, a1: Float, a2: Float
        var z1: Float = 0, z2: Float = 0
        static func make(_ kind: Int, _ f: Double, _ q: Double) -> Biquad {
            let w = 2 * Double.pi * f / RealCookAudio.rate, cw = cos(w), sw = sin(w), alpha = sw / (2 * q)
            var b0 = 0.0, b1 = 0.0, b2 = 0.0
            switch kind {
            case 0: b0 = (1 - cw) / 2; b1 = 1 - cw; b2 = (1 - cw) / 2              // low-pass
            case 1: b0 = (1 + cw) / 2; b1 = -(1 + cw); b2 = (1 + cw) / 2           // high-pass
            default: b0 = alpha; b1 = 0; b2 = -alpha                                // band-pass
            }
            let a0 = 1 + alpha
            return Biquad(b0: Float(b0 / a0), b1: Float(b1 / a0), b2: Float(b2 / a0), a1: Float(-2 * cw / a0), a2: Float((1 - alpha) / a0))
        }
        mutating func run(_ x: Float) -> Float {
            let y = b0 * x + z1
            z1 = b1 * x - a1 * y + z2
            z2 = b2 * x - a2 * y
            return y
        }
    }

    private static func noise(_ rng: inout SeededRNG) -> Float { rng.float(-1...1) }

    private static func normalize(_ s: inout [Float], peak: Float = 0.8) {
        let m = s.reduce(0) { max($0, abs($1)) }
        guard m > 0 else { return }
        for i in s.indices { s[i] *= peak / m }
    }

    static func sizzle(seconds: Double, _ rng: inout SeededRNG) -> [Float] {
        let n = Int(seconds * rate)
        var out = [Float](repeating: 0, count: n)
        var hp = Biquad.make(1, 2600, 0.7), bp = Biquad.make(2, 5200, 0.9)
        var env: Float = 0.6, target: Float = 0.6
        // Pops: short bright clicks with ringing, Poisson spaced (~45 per second).
        var nextPop = 0
        var popAmp: Float = 0, popRing = Biquad.make(2, 3800, 6)
        for i in 0..<n {
            if i % 512 == 0 { target = 0.45 + rng.float(0...0.55) }
            env += (target - env) * 0.004
            let hiss = bp.run(hp.run(noise(&rng))) * env
            if i >= nextPop {
                popAmp = rng.float(0.3...1)
                nextPop = i + Int(-log(Double(max(rng.float(0...1), 1e-4))) * rate / 45)
                popRing = Biquad.make(2, Double(rng.float(2200...7000)), Double(rng.float(3...9)))
            }
            let pop = popRing.run(noise(&rng) * popAmp)
            popAmp *= 0.986
            out[i] = hiss * 0.8 + pop * 1.6
        }
        normalize(&out)
        return out
    }

    static func boil(seconds: Double, _ rng: inout SeededRNG) -> [Float] {
        let n = Int(seconds * rate)
        var out = [Float](repeating: 0, count: n)
        var lp = Biquad.make(0, 900, 0.7)
        var bubbles: [(start: Int, f: Float, len: Int, a: Float)] = []
        var t = 0
        while t < n { bubbles.append((t, rng.float(180...620), Int(rate * Double(rng.float(0.02...0.07))), rng.float(0.3...1))); t += Int(rate * Double(rng.float(0.008...0.05))) }
        for b in bubbles {
            for k in 0..<b.len where b.start + k < n {
                let x = Float(k) / Float(b.len)
                // Rising chirp: bubbles resonate up as they detach.
                let f = b.f * (1 + x * 0.8)
                out[b.start + k] += sin(2 * .pi * f * Float(k) / Float(rate)) * b.a * (1 - x) * x * 4
            }
        }
        for i in 0..<n { out[i] = out[i] * 0.7 + lp.run(noise(&rng)) * 0.25 }
        normalize(&out, peak: 0.7)
        return out
    }

    static func roar(seconds: Double, _ rng: inout SeededRNG) -> [Float] {
        let n = Int(seconds * rate)
        var out = [Float](repeating: 0, count: n)
        var lp = Biquad.make(0, 700, 0.6), bp = Biquad.make(2, 240, 0.8)
        for i in 0..<n {
            let x = noise(&rng)
            out[i] = lp.run(x) * 0.7 + bp.run(x) * 0.8
        }
        normalize(&out, peak: 0.5)
        return out
    }

    static func chop(_ rng: inout SeededRNG) -> [Float] {
        let n = Int(0.22 * rate)
        var out = [Float](repeating: 0, count: n)
        var bp = Biquad.make(2, 1400, 1.2), lp = Biquad.make(0, 400, 0.9)
        let f0 = rng.float(150...210)
        for i in 0..<n {
            let t = Float(i) / Float(rate)
            // Crunch of the cut (bright, 25 ms) then the board knock (woody, 150 Hz).
            let crunch = bp.run(noise(&rng)) * exp(-t * 90)
            let knock = sin(2 * .pi * f0 * t) * exp(-t * 38) + lp.run(noise(&rng)) * exp(-t * 60) * 0.6
            out[i] = crunch * 0.9 + knock * 0.8
        }
        normalize(&out, peak: 0.9)
        return out
    }

    static func ignite(_ rng: inout SeededRNG) -> [Float] {
        let n = Int(1.1 * rate)
        var out = [Float](repeating: 0, count: n)
        var hp = Biquad.make(1, 3000, 0.7), lp = Biquad.make(0, 500, 0.7)
        let clicks = [0.0, 0.11, 0.22, 0.33]
        for c in clicks {
            let s = Int(c * rate)
            for k in 0..<Int(0.012 * rate) where s + k < n { out[s + k] += hp.run(noise(&rng)) * exp(-Float(k) / 90) * 1.4 }
        }
        let whump = Int(0.36 * rate)
        for k in 0..<(n - whump) {
            let t = Float(k) / Float(rate)
            out[whump + k] += lp.run(noise(&rng)) * (1 - exp(-t * 40)) * exp(-t * 2.6) * 1.2
        }
        normalize(&out, peak: 0.8)
        return out
    }

    static func drop(_ rng: inout SeededRNG) -> [Float] {
        var s = sizzle(seconds: 1.4, &rng)
        for i in s.indices {
            let t = Float(i) / Float(rate)
            s[i] *= min(1, t * 60) * exp(-t * 1.8) * 1.2
        }
        normalize(&s, peak: 0.95)
        return s
    }

    static func whisk(seconds: Double, _ rng: inout SeededRNG) -> [Float] {
        let n = Int(seconds * rate)
        var out = [Float](repeating: 0, count: n)
        var bp = Biquad.make(2, 3200, 2)
        for i in 0..<n {
            let t = Float(i) / Float(rate)
            // Strokes at ~4 Hz: each a scrape (band noise) with a metallic tick at the turn.
            let phase = (t * 4).truncatingRemainder(dividingBy: 1)
            let env = sin(.pi * phase) * 0.8 + 0.1
            let tick = phase < 0.02 ? sin(2 * .pi * 2700 * t) * 0.5 : 0
            out[i] = bp.run(noise(&rng)) * env + tick
        }
        normalize(&out, peak: 0.6)
        return out
    }
}

/// Steam, smoke and oil-spatter emitters for cooking vessels.
@MainActor
public enum RealCookFX {
    /// Rising steam, scaled by `rate` (0...1) via `birthRate` updates. Attach at the pan's floor center.
    public static func steam(radius: Float) -> ParticleEmitterComponent {
        var p = ParticleEmitterComponent()
        p.emitterShape = .cylinder
        p.emitterShapeSize = SIMD3(radius * 1.6, 0.01, radius * 1.6)
        p.birthLocation = .volume
        p.speed = 0.09
        p.speedVariation = 0.04
        p.emissionDirection = SIMD3(0, 1, 0)
        p.mainEmitter.birthRate = 0
        p.mainEmitter.lifeSpan = 2.2
        p.mainEmitter.lifeSpanVariation = 0.6
        p.mainEmitter.size = 0.035
        p.mainEmitter.sizeVariation = 0.015
        p.mainEmitter.sizeMultiplierAtEndOfLifespan = 4
        p.mainEmitter.color = .evolving(start: .single(.init(white: 1, alpha: 0.16)), end: .single(.init(white: 1, alpha: 0)))
        p.mainEmitter.blendMode = .alpha
        p.mainEmitter.opacityCurve = .gradualFadeInOut
        p.mainEmitter.acceleration = SIMD3(0, 0.05, 0)
        p.mainEmitter.noiseStrength = 0.03
        p.mainEmitter.noiseScale = 2
        p.mainEmitter.dampingFactor = 0.6
        return p
    }

    /// Acrid grey-brown smoke for burning oil or charring food.
    public static func smoke(radius: Float) -> ParticleEmitterComponent {
        var p = steam(radius: radius)
        p.mainEmitter.lifeSpan = 3.2
        p.speed = 0.14
        p.mainEmitter.size = 0.05
        p.mainEmitter.sizeMultiplierAtEndOfLifespan = 6
        p.mainEmitter.color = .evolving(start: .single(.init(red: 0.42, green: 0.4, blue: 0.38, alpha: 0.35)),
                                        end: .single(.init(red: 0.6, green: 0.6, blue: 0.6, alpha: 0)))
        return p
    }

    /// Tiny bright oil droplets thrown up from a sizzling pan.
    public static func spatter(radius: Float) -> ParticleEmitterComponent {
        var p = ParticleEmitterComponent()
        p.emitterShape = .cylinder
        p.emitterShapeSize = SIMD3(radius * 1.4, 0.005, radius * 1.4)
        p.birthLocation = .volume
        p.speed = 0.55
        p.speedVariation = 0.3
        p.emissionDirection = SIMD3(0, 1, 0)
        p.mainEmitter.birthRate = 0
        p.mainEmitter.lifeSpan = 0.45
        p.mainEmitter.size = 0.0018
        p.mainEmitter.color = .constant(.single(.init(red: 1, green: 0.92, blue: 0.7, alpha: 0.9)))
        p.mainEmitter.acceleration = SIMD3(0, -9.8, 0)
        p.mainEmitter.spreadingAngle = 0.5
        return p
    }
}
