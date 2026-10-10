import Foundation

public enum Side: Int, CaseIterable, Sendable {
    case left = 0, right = 1
    /// +1 for the animal's right (+X).
    public var sign: Float { self == .right ? 1 : -1 }
    public var suffix: String { self == .right ? "R" : "L" }
    public var other: Side { self == .right ? .left : .right }
}

/// A rig joint by index. Values are degrees (percent for `primFold`). Part names are `name`.
///
/// Wing chain per side: `flap` raises the tip, `sweep` swings it forward, `twist` raises the leading
/// edge, `elbow` folds the forearm (positive), `wrist` folds the hand (negative), `handTwist` rolls
/// the hand, `secFold` closes the secondaries, `primFold` closes the primaries (0 fanned, 100 shut).
public struct BirdJoint: Hashable, Sendable {
    public let index: Int
    init(_ i: Int) { index = i }

    // Head chain.
    public static let neckPitch = BirdJoint(0)
    public static let headYaw = BirdJoint(1)
    public static let headRoll = BirdJoint(2)
    public static let headPitch = BirdJoint(3)
    public static let jaw = BirdJoint(4)
    public static let lidL = BirdJoint(5)
    public static let lidR = BirdJoint(6)
    public static let crest = BirdJoint(7)
    // Tail.
    public static let tailPitch = BirdJoint(8)
    public static let tailFanL = BirdJoint(9)
    public static let tailFanR = BirdJoint(10)

    public enum LegJoint: Int, CaseIterable, Sendable { case hip, ankle, toes, hallux }
    public enum WingJoint: Int, CaseIterable, Sendable {
        case flap, sweep, twist, elbow, secFold, wrist, handTwist, primFold, primA, primB, primC
    }

    static let legBase = 11
    static let wingBase = 19

    public static func leg(_ s: Side, _ j: LegJoint) -> BirdJoint { BirdJoint(legBase + s.rawValue * 4 + j.rawValue) }
    public static func wing(_ s: Side, _ j: WingJoint) -> BirdJoint { BirdJoint(wingBase + s.rawValue * WingJoint.allCases.count + j.rawValue) }

    public static let count = wingBase + 2 * WingJoint.allCases.count
    public static let all: [BirdJoint] = (0..<count).map { BirdJoint($0) }

    public var name: String { Self.names[index] }

    static let names: [String] = {
        var n = ["neckPitch", "headYaw", "headRoll", "headPitch", "jaw", "lidL", "lidR", "crest", "tailPitch", "tailFanL", "tailFanR"]
        for s in Side.allCases { for j in LegJoint.allCases { n.append("\(j)\(s.suffix)") } }
        for s in Side.allCases { for j in WingJoint.allCases { n.append("\(j)\(s.suffix)") } }
        return n
    }()

    /// Allowed range in degrees.
    public var range: ClosedRange<Float> { Self.ranges[index] }

    static let ranges: [ClosedRange<Float>] = {
        var r: [ClosedRange<Float>] = [-55...55, -100...100, -40...40, -50...55, 0...38, 0...130, 0...130, -25...45, -35...50, -4...34, -4...34]
        for _ in Side.allCases { r += [-30...115, -35...110, 0...95, -30...30] }
        for _ in Side.allCases {
            r += [-100...90, -85...75, -40...40, 0...165, -150...20, -170...10, -60...60, 0...100, -120...120, -120...120, -120...120]
        }
        return r
    }()
}

/// Joint values for one pose, indexed by `BirdJoint`.
public struct BirdPose: Sendable, Equatable {
    public var values: [Float]
    public init() { values = [Float](repeating: 0, count: BirdJoint.count) }
    public init(_ values: [Float]) { precondition(values.count == BirdJoint.count); self.values = values }
    public subscript(j: BirdJoint) -> Float {
        get { values[j.index] }
        set { values[j.index] = newValue }
    }
    public subscript(s: Side, j: BirdJoint.WingJoint) -> Float {
        get { values[BirdJoint.wing(s, j).index] }
        set { values[BirdJoint.wing(s, j).index] = newValue }
    }
    public subscript(s: Side, j: BirdJoint.LegJoint) -> Float {
        get { values[BirdJoint.leg(s, j).index] }
        set { values[BirdJoint.leg(s, j).index] = newValue }
    }

    /// Both wings get the same value (symmetric flight poses).
    public mutating func wings(_ j: BirdJoint.WingJoint, _ v: Float) { self[.left, j] = v; self[.right, j] = v }
    public mutating func legs(_ j: BirdJoint.LegJoint, _ v: Float) { self[.left, j] = v; self[.right, j] = v }

    /// Linear blend between poses.
    public static func blend(_ a: BirdPose, _ b: BirdPose, _ t: Float) -> BirdPose {
        var o = a
        for i in 0..<BirdJoint.count { o.values[i] = a.values[i] + (b.values[i] - a.values[i]) * t }
        return o
    }

    /// Clamps every value into its joint range.
    public mutating func clamp() {
        for i in 0..<BirdJoint.count {
            let r = BirdJoint.ranges[i]
            values[i] = min(max(values[i], r.lowerBound), r.upperBound)
        }
    }
}
