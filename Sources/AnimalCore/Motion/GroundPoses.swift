import Foundation
import RealCore

public enum GroundPoses {
    public static func stand(_ p: GroundProfile) -> GroundPose { GroundPose() }

    /// Hind legs folded under the haunches, fore legs straight.
    public static func sit(_ p: GroundProfile) -> GroundPose {
        var q = GroundPose()
        for l in [GroundJoint.Leg.hindL, .hindR] {
            q[l, .hip] = 55; q[l, .knee] = -105; q[l, .ankle] = 60
        }
        q[.spine] = 6
        return q
    }
}

public struct GroundMotionInput: Sendable, Equatable {
    public var gait: GroundGait = .walk
    /// Gait cycle phase 0...1.
    public var phase: Float = 0
    /// 0 standing still, 1 full speed.
    public var speed: Float = 0
    /// 0 standing, 1 sitting on the haunches.
    public var sit: Float = 0
    /// Fore paws raised to the mouth (eating, begging), 0...1.
    public var paws: Float = 0
    public var headYaw: Float = 0
    public var headPitch: Float = 0
    public var neck: Float = 0
    /// 0 ears relaxed, 1 upright and alert.
    public var alert: Float = 0
    public var jaw: Float = 0
    public var blink: Float = 0
    /// Tail raise 0...1 and sideways sway in degrees.
    public var tailRaise: Float = 0
    public var tailSway: Float = 0
    /// Nose twitch phase in radians.
    public var twitch: Float = 0
    public init() {}
}

public enum GroundMotion {
    static func smooth(_ keys: [Float], _ ph: Float) -> Float {
        let n = keys.count
        let x = (ph - floor(ph)) * Float(n)
        let i = Int(x) % n, j = (i + 1) % n
        let k = x - floor(x)
        let e = k * k * (3 - 2 * k)
        return keys[i] + (keys[j] - keys[i]) * e
    }

    public static func pose(_ p: GroundProfile, _ i: GroundMotionInput) -> GroundPose {
        var q = GroundPose.blend(GroundPoses.stand(p), GroundPoses.sit(p), saturate(i.sit))
        let sp = saturate(i.speed)
        if sp > 0.01 && i.sit < 0.5 {
            switch p.behavior.gait {
            case .walk:
                let A: Float = 16 + 12 * sp
                let offs: [GroundJoint.Leg: Float] = [.foreL: 0, .hindR: 0.25, .foreR: 0.5, .hindL: 0.75]
                for l in GroundJoint.Leg.allCases {
                    let ph = (i.phase + offs[l]!).truncatingRemainder(dividingBy: 1)
                    let swing = ph >= 0.6
                    let u = swing ? (ph - 0.6) / 0.4 : ph / 0.6
                    let hip = swing ? -A + 2 * A * u : A * (1 - 2 * u)
                    let lift = swing ? sin(.pi * u) : 0
                    q[l, .hip] = hip
                    q[l, .knee] = l.isFore ? -35 * lift : -40 * lift - 8
                    q[l, .ankle] = (l.isFore ? 15 : 20) * lift
                }
            case .bound:
                // Gallop: fore legs together, hind legs together just behind; spine flexes.
                let fores = [Float(40), 55, 30, -10], hips = [Float(-35), 5, 55, 35]
                for l in GroundJoint.Leg.allCases {
                    let ph = i.phase + (l.isFore ? 0 : 0.18)
                    q[l, .hip] = smooth(l.isFore ? fores : hips, ph) * sp
                    q[l, .knee] = l.isFore ? -smooth([10, 25, 40, 20], ph) * sp : -smooth([20, 70, 110, 50], ph) * sp
                    q[l, .ankle] = l.isFore ? 0 : smooth([-30, 10, 40, 0], ph) * sp
                }
                q[.spine] = smooth([-14, 8, 22, 4], i.phase) * sp
            case .hop:
                let hipH = [Float(60), -40, -50, 20], kneeH = [Float(-100), -10, -5, -70], ankH = [Float(50), -40, -30, 30]
                let hipF = [Float(10), 50, 55, 20]
                for l in GroundJoint.Leg.allCases {
                    q[l, .hip] = (l.isFore ? smooth(hipF, i.phase) : smooth(hipH, i.phase + 0.05)) * sp
                    q[l, .knee] = l.isFore ? -smooth([10, 30, 20, 10], i.phase) * sp : smooth(kneeH, i.phase + 0.05) * sp
                    q[l, .ankle] = l.isFore ? 0 : smooth(ankH, i.phase + 0.05) * sp
                }
                q[.spine] = smooth([14, -10, -12, 10], i.phase) * sp
            }
        }
        // Fore paws up to the mouth.
        if i.paws > 0 {
            for l in [GroundJoint.Leg.foreL, .foreR] { q[l, .hip] = lerp(q[l, .hip], 62, i.paws); q[l, .knee] = lerp(q[l, .knee], -85, i.paws); q[l, .ankle] = lerp(q[l, .ankle], -30, i.paws) }
        }
        q[.neckPitch] += i.neck
        q[.headYaw] = i.headYaw
        q[.headPitch] += i.headPitch
        q[.jaw] = saturate(i.jaw) * 25
        let a = saturate(i.alert)
        q[.earL] = lerp(25, -10, a); q[.earR] = lerp(25, -10, a)
        q[.nose] = 4 * sin(i.twitch)
        q[.tailYaw] = i.tailSway
        let r = saturate(i.tailRaise)
        q[.tail0] = -30 * r; q[.tail1] = -20 * r; q[.tail2] = -12 * r
        q[.lidL] = 125 * (1 - saturate(i.blink)); q[.lidR] = 125 * (1 - saturate(i.blink))
        q.clamp()
        return q
    }

    /// Static poses for the preview tool.
    public static func preview(_ name: String, _ p: GroundProfile) -> GroundPose {
        var i = GroundMotionInput()
        i.gait = p.behavior.gait
        switch name {
        case "sit": i.sit = 1
        case "eat": i.sit = 1; i.paws = 1; i.jaw = 0.5
        case "walk0", "walk1", "walk2", "walk3":
            i.speed = 0.7; i.phase = Float(Int(name.dropFirst(4))!) / 4
        default: break
        }
        i.alert = name == "sit" ? 1 : 0
        return pose(p, i)
    }

    /// Body pitch to show a preview pose at (degrees nose up beyond the rest tilt).
    public static func previewPitch(_ name: String, _ p: GroundProfile) -> Float {
        switch name {
        case "sit", "eat": return p.species == .easternCottontail ? 26 : 38
        default: return 0
        }
    }
}
