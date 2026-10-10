import Foundation

/// A quadruped rig joint by index. Values are degrees. Rotation about +X swings a downward-pointing
/// limb forward; ears and tail segments lay back with positive values.
public struct GroundJoint: Hashable, Sendable {
    public let index: Int
    init(_ i: Int) { index = i }

    public static let spine = GroundJoint(0)
    public static let neckPitch = GroundJoint(1)
    public static let headYaw = GroundJoint(2)
    public static let headPitch = GroundJoint(3)
    public static let jaw = GroundJoint(4)
    public static let earL = GroundJoint(5)
    public static let earR = GroundJoint(6)
    public static let nose = GroundJoint(7)
    public static let tailYaw = GroundJoint(8)
    public static let tail0 = GroundJoint(9)
    public static let tail1 = GroundJoint(10)
    public static let tail2 = GroundJoint(11)
    public static let lidL = GroundJoint(12)
    public static let lidR = GroundJoint(13)

    public enum Leg: Int, CaseIterable, Sendable {
        case foreL, foreR, hindL, hindR
        public var isFore: Bool { self == .foreL || self == .foreR }
        public var side: Side { (self == .foreL || self == .hindL) ? .left : .right }
        public var name: String { ["foreL", "foreR", "hindL", "hindR"][rawValue] }
    }
    public enum Segment: Int, CaseIterable, Sendable { case hip, knee, ankle }

    static let legBase = 14
    public static func leg(_ l: Leg, _ s: Segment) -> GroundJoint { GroundJoint(legBase + l.rawValue * 3 + s.rawValue) }

    public static let count = legBase + 12
    public static let all: [GroundJoint] = (0..<count).map { GroundJoint($0) }

    public var name: String { Self.names[index] }

    static let names: [String] = {
        var n = ["spine", "neckPitch", "headYaw", "headPitch", "jaw", "earL", "earR", "nose", "tailYaw", "tail0", "tail1", "tail2", "lidL", "lidR"]
        for l in Leg.allCases { for s in Segment.allCases { n.append("\(l.name)_\(s)") } }
        return n
    }()

    public var range: ClosedRange<Float> { Self.ranges[index] }

    static let ranges: [ClosedRange<Float>] = {
        var r: [ClosedRange<Float>] = [-40...50, -50...60, -90...90, -55...60, 0...35, -40...70, -40...70, -8...8, -60...60, -70...70, -70...70, -70...70, 0...130, 0...130]
        for l in Leg.allCases { r += l.isFore ? [-70...80, -100...40, -60...60] : [-70...80, -140...20, -60...90] }
        return r
    }()
}

public struct GroundPose: Sendable, Equatable {
    public var values: [Float]
    public init() { values = [Float](repeating: 0, count: GroundJoint.count) }
    public subscript(j: GroundJoint) -> Float {
        get { values[j.index] }
        set { values[j.index] = newValue }
    }
    public subscript(l: GroundJoint.Leg, s: GroundJoint.Segment) -> Float {
        get { values[GroundJoint.leg(l, s).index] }
        set { values[GroundJoint.leg(l, s).index] = newValue }
    }
    public static func blend(_ a: GroundPose, _ b: GroundPose, _ t: Float) -> GroundPose {
        var o = a
        for i in 0..<GroundJoint.count { o.values[i] = a.values[i] + (b.values[i] - a.values[i]) * t }
        return o
    }
    public mutating func clamp() {
        for i in 0..<GroundJoint.count { let r = GroundJoint.ranges[i]; values[i] = min(max(values[i], r.lowerBound), r.upperBound) }
    }
}
