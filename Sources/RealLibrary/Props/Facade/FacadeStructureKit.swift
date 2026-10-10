import simd
import Foundation

/// Arch geometry shared by the third facade batch (lancet, oculus, hood-mould, portal props).
extension FC {
    /// Closed CCW outline of an arched opening: base on y = 0, jambs to `spring`, then a round or
    /// equilateral-pointed arch. No repeated points.
    static func archOutline(width: Float, spring: Float, pointed: Bool, steps: Int = 12) -> [V2] {
        let hw = width / 2
        var pts: [V2] = [V2(-hw, 0), V2(hw, 0)]
        if pointed {
            for i in 0...steps {   // right arc, centre (-hw, spring), radius width: 0 to 60 degrees
                let a = Float(i) / Float(steps) * (.pi / 3)
                pts.append(V2(-hw + width * cos(a), spring + width * sin(a)))
            }
            for i in 1...steps {   // left arc, centre (hw, spring): 120 to 180 degrees
                let a = .pi * 2 / 3 + Float(i) / Float(steps) * (.pi / 3)
                pts.append(V2(hw + width * cos(a), spring + width * sin(a)))
            }
        } else {
            for i in 0...steps {
                let a = Float(i) / Float(steps) * .pi
                pts.append(V2(hw * cos(a), spring + hw * sin(a)))
            }
        }
        return pts
    }
    /// Open path up the right jamb, over the arch and down the left jamb at depth z.
    static func archPath(width: Float, spring: Float, pointed: Bool, z: Float, steps: Int = 12) -> [V3] {
        let o = archOutline(width: width, spring: spring, pointed: pointed, steps: steps)
        return (Array(o[1...]) + [o[0]]).map { V3($0.x, $0.y, z) }
    }
    /// Apex height of the opening.
    static func archRise(width: Float, spring: Float, pointed: Bool) -> Float {
        spring + (pointed ? width * 0.866 : width / 2)
    }
}

extension FC {
    /// Seats the lowest point on y = 0 and recenters Z, keeping X (wall pieces that hang above the floor).
    static func seatY(_ m: Model) -> Model {
        let bb = m.bounds
        return m.transformed(Xform(translation: V3(0, -bb.min.y, -(bb.min.z + bb.max.z) / 2)))
    }
}
