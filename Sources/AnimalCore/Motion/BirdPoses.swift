import Foundation
import RealCore

/// Static reference poses. The dynamic motion in `BirdMotion` blends and animates around these.
public enum BirdPoses {
    /// Wings folded against the flanks, legs standing, tail closed, head forward.
    public static func perched(_ p: BirdProfile) -> BirdPose {
        var q = BirdPose()
        for s in Side.allCases {
            q[s, .flap] = -64
            q[s, .sweep] = -60
            q[s, .twist] = 8
            q[s, .elbow] = 150
            q[s, .secFold] = -130
            q[s, .wrist] = -155
            q[s, .handTwist] = 0
            q[s, .primFold] = 100
        }
        q[.neckPitch] = 0
        q[.headPitch] = 0
        q[.tailPitch] = 8
        q.legs(.hip, 0)
        q.legs(.toes, 0)
        q.legs(.hallux, 0)
        return q
    }

    /// Wings out and level, legs tucked: a glide.
    public static func glide(_ p: BirdProfile) -> BirdPose {
        var q = BirdPose()
        for s in Side.allCases {
            q[s, .flap] = 8
            q[s, .sweep] = 6
            q[s, .twist] = 4
            q[s, .elbow] = 6
            q[s, .secFold] = 0
            q[s, .wrist] = -4
            q[s, .primFold] = 0
        }
        q.legs(.hip, 85)
        q.legs(.ankle, 100)
        q.legs(.toes, 60)
        q.legs(.hallux, 20)
        q[.tailFanL] = 12
        q[.tailFanR] = 12
        q[.tailPitch] = 4
        q[.neckPitch] = -8
        return q
    }
}
