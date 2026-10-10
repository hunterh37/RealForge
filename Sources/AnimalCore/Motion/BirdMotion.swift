import Foundation
import RealCore

/// Drivers for one frame of bird pose. Everything is a plain value so behavior code can set the
/// fields it cares about and `BirdMotion.pose` turns them into joint angles.
public struct BirdMotionInput: Sendable, Equatable {
    /// 1 wings folded at the flanks, 0 wings extended.
    public var fold: Float = 1
    /// Flap effort 0...1 (amplitude).
    public var flap: Float = 0
    /// Wingbeat phase 0...1: 0 top of the upstroke, 0.45 bottom of the downstroke.
    public var phase: Float = 0
    /// 0...1 blend into the hover stroke (wings sweep forward and back).
    public var hover: Float = 0
    /// 0...1 landing flare: wings cupped and braking, tail fanned down, feet reaching.
    public var flare: Float = 0
    /// 0 standing legs, 1 tucked for flight.
    public var legs: Float = 0
    /// Toe curl 0...1 around a perch.
    public var grip: Float = 0
    /// Knee bend 0...1 (hop, landing absorb, crouch before takeoff).
    public var crouch: Float = 0
    public var tailSpread: Float = 0.1
    /// Added to the tail pitch, degrees (positive lowers the tail).
    public var tailPitch: Float = 0
    public var headYaw: Float = 0
    public var headPitch: Float = 0
    public var headRoll: Float = 0
    public var neck: Float = 0
    /// Jaw open 0...1.
    public var beak: Float = 0
    /// 0 eyes open, 1 shut.
    public var blink: Float = 0
    /// 0 crest flat, 1 raised.
    public var crest: Float = 0
    /// Perched wing droop or stretch: 0 folded, 1 half open.
    public var wingOpen: Float = 0
    /// Left and right wing extension differences for banking and balance (degrees added to flap).
    public var rollTrim: Float = 0

    public init() {}
}

public enum BirdMotion {
    /// Joint values for `i`.
    public static func pose(_ p: BirdProfile, _ i: BirdMotionInput) -> BirdPose {
        let perched = BirdPoses.perched(p), glide = BirdPoses.glide(p)
        let fold = saturate(i.fold) * (1 - saturate(i.wingOpen) * 0.55)
        var q = BirdPose.blend(glide, perched, fold)

        // Flapping: asymmetric stroke, wrist and elbow flexing on the upstroke, primaries opening on the downstroke.
        if i.flap > 0.001 {
            let u = i.phase.truncatingRemainder(dividingBy: 1)
            let s = u < 0.45 ? 0.5 * u / 0.45 : 0.5 + 0.5 * (u - 0.45) / 0.55
            let c = cos(2 * .pi * s)
            let lagElbow = cos(2 * .pi * (s - 0.10)), lagWrist = cos(2 * .pi * (s - 0.18))
            let e = saturate(i.flap)
            let amp: Float = 52
            let flapAngle = 6 + amp * c
            let hoverBlend = saturate(i.hover)
            for side in Side.allCases {
                let trim: Float = (side == .left ? -1 : 1) * i.rollTrim
                var flap = lerp(q[side, .flap], flapAngle, e) + trim
                var sweep = q[side, .sweep] + e * 10 * sin(2 * .pi * s)
                var twist = lerp(q[side, .twist], -6 + 22 * sin(2 * .pi * s), e)
                var elbow = lerp(q[side, .elbow], 6 + 26 * (0.5 - 0.5 * lagElbow), e)
                var wrist = lerp(q[side, .wrist], -4 - 52 * (0.5 - 0.5 * lagWrist), e)
                let prim = lerp(q[side, .primFold], 22 * max(0, -sin(2 * .pi * s)), e)
                if hoverBlend > 0 {
                    // Figure-eight stroke: sweep dominates, flap stays shallow, twist flips each reversal.
                    let h = hoverBlend
                    flap = lerp(flap, 10 * c + trim, h)
                    sweep = lerp(sweep, 8 - 60 * sin(2 * .pi * u), h)
                    twist = lerp(twist, 50 * cos(2 * .pi * u), h)
                    elbow = lerp(elbow, 10, h)
                    wrist = lerp(wrist, -8, h)
                }
                q[side, .flap] = flap
                q[side, .sweep] = sweep
                q[side, .twist] = twist
                q[side, .elbow] = elbow
                q[side, .wrist] = wrist
                q[side, .primFold] = prim
                q[side, .handTwist] = e * (-10 + 28 * sin(2 * .pi * s))
            }
            q[.tailPitch] = lerp(q[.tailPitch], 10 + 6 * c, e * 0.5)
        }

        // Landing flare: cupped, braking wings, tail fanned and down, feet forward.
        let fl = saturate(i.flare)
        if fl > 0 {
            for side in Side.allCases {
                q[side, .flap] = lerp(q[side, .flap], 42, fl)
                q[side, .sweep] = lerp(q[side, .sweep], -4, fl)
                q[side, .twist] = lerp(q[side, .twist], 30, fl)
                q[side, .elbow] = lerp(q[side, .elbow], 24, fl)
                q[side, .wrist] = lerp(q[side, .wrist], -30, fl)
                q[side, .primFold] = lerp(q[side, .primFold], 0, fl)
            }
            q[.tailFanL] = lerp(q[.tailFanL], 34, fl); q[.tailFanR] = lerp(q[.tailFanR], 34, fl)
            q[.tailPitch] = lerp(q[.tailPitch], 42, fl)
        }

        // Legs.
        let tuck = saturate(i.legs), bend = saturate(i.crouch)
        for side in Side.allCases {
            q[side, .hip] = lerp(0, 85, tuck) + bend * 26 - fl * 70 * (1 - tuck)
            q[side, .ankle] = lerp(0, 100, tuck) + bend * 30 + fl * 30
            q[side, .toes] = lerp(0, 60, tuck) + saturate(i.grip) * 68 * (1 - tuck)
            q[side, .hallux] = lerp(0, 20, tuck) + saturate(i.grip) * 52 * (1 - tuck)
        }

        // Tail.
        let spread = saturate(i.tailSpread) * 30
        q[.tailFanL] = max(q[.tailFanL], spread); q[.tailFanR] = max(q[.tailFanR], spread)
        q[.tailPitch] += i.tailPitch

        // Head and face.
        q[.neckPitch] += i.neck
        q[.headYaw] = i.headYaw
        q[.headRoll] = i.headRoll
        q[.headPitch] += i.headPitch
        q[.jaw] = saturate(i.beak) * 30
        let open: Float = 125
        q[.lidL] = open * (1 - saturate(i.blink)); q[.lidR] = open * (1 - saturate(i.blink))
        q[.crest] = lerp(32, -18, saturate(i.crest))
        q.clamp()
        return q
    }

    /// Named static poses for the preview tool.
    public static func preview(_ name: String, _ p: BirdProfile) -> BirdPose {
        var i = BirdMotionInput()
        i.fold = 0; i.legs = 1; i.flap = 1; i.blink = 0
        switch name {
        case "up": i.phase = 0
        case "mid": i.phase = 0.22
        case "down": i.phase = 0.45
        case "back": i.phase = 0.75
        case "flare": i.flap = 0; i.flare = 1; i.legs = 0
        case "hover": i.hover = 1; i.phase = 0.1
        case "gape": i.fold = 1; i.flap = 0; i.legs = 0; i.beak = 1; i.crest = 1; i.grip = 1
        case "look": i.fold = 1; i.flap = 0; i.legs = 0; i.headYaw = 70; i.headRoll = 12; i.grip = 1
        case "preen": i.fold = 1; i.flap = 0; i.legs = 0; i.headYaw = 100; i.headPitch = 35; i.neck = 25; i.headRoll = 20; i.wingOpen = 0.5
        default: break
        }
        return pose(p, i)
    }
}
