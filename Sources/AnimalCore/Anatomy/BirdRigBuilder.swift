import Foundation
import simd
import RealCore

/// Joint metadata the runtime needs next to the `Rig`.
public struct BirdJointSpec: Sendable {
    public var name: String
    public var parent: Int?
    public var pivot: V3
    public var axis: V3
    public var range: ClosedRange<Float>
    public var mimic: (master: Int, ratio: Float)?
}

/// A built bird: the articulated rig plus the numbers the behavior and driver code need.
public struct BirdRig: Sendable {
    public var profile: BirdProfile
    public var rig: Rig
    public var joints: [BirdJointSpec]
    /// Body center above the feet when perched, meters.
    public var comHeight: Float
    /// Foot grip points (rig space, y = 0) per side.
    public var feet: [V3]
    /// Wing root and tip positions (rig space) for each side, used by the flight code for clearances.
    public var wingRoot: [V3]
    public var halfSpan: Float
    public var bodyPitch: Float { profile.anatomy.restPitch }
    public var triangleCount: Int { rig.base[0].triangleCount + rig.parts.reduce(0) { $0 + $1.levels[0].triangleCount + $1.alternates.reduce(0) { $0 + $1[0].triangleCount } } }
}

/// Frame constants shared by the geometry builders (rig space, +Y up, bird faces -Z).
struct BirdFrame {
    let p: BirdProfile
    let a: BirdAnatomy
    let id: String
    /// Body axis (toward the head), dorsal axis, rearward axis.
    let A: V3, U: V3, Bk: V3
    let C: V3
    let psi: Float

    init(_ p: BirdProfile) {
        self.p = p; a = p.anatomy; id = p.species.rawValue
        psi = radians(a.restPitch)
        A = V3(0, sin(psi), -cos(psi)); U = V3(0, cos(psi), sin(psi)); Bk = -A
        C = V3(0, a.standHeight, 0)
    }

    func mat(_ r: FaunaMaterials.Region) -> MaterialKey { FaunaMaterials.key(id, r) }
    static let X = V3(1, 0, 0), Y = V3(0, 1, 0), Z = V3(0, 0, 1)

    /// Mirror an axis (a pseudovector) for the left side.
    func axis(_ v: V3, _ s: Side) -> V3 { s == .right ? v : V3(v.x, -v.y, -v.z) }

    var bodyProfile: Profile { Profile([V2(0, 0.36), V2(0.14, 0.66), V2(0.36, 0.93), V2(0.6, 1.0), V2(0.8, 0.95), V2(0.93, 0.82), V2(1, 0.66)]) }

    /// Front-center of the body loft.
    var bodyFront: V3 { C + A * (a.bodyLength / 2) }
    var neckPivot: V3 { bodyFront - A * (0.10 * a.bodyLength) + U * (0.10 * a.bodyDepth) }
    var neckDir: V3 { let e = psi + radians(a.neckPitch); return V3(0, sin(e), -cos(e)) }
    var headCenter: V3 { neckPivot + neckDir * (a.neckLength * 0.7) }
    var headJoint: V3 { headCenter + V3(0, -0.2 * a.headHeight, 0.18 * a.headLength) }

    var headProfile: Profile { Profile([V2(0, 0.50), V2(0.12, 0.86), V2(0.32, 1.0), V2(0.55, 0.97), V2(0.75, 0.80), V2(0.9, 0.56), V2(1, 0.42)]) }
    func headHalfWidth(_ t: Float) -> Float { 0.5 * a.headWidth * headProfile(t) }
    func headCenterAt(_ t: Float) -> V3 { headCenter + BirdFrame.Z * ((0.5 - t) * a.headLength) + BirdFrame.Y * (0.02 * a.headHeight * sin(.pi * t)) }
    var beakBase: V3 { headCenterAt(1) + V3(0, -0.04 * a.headHeight, 0) }
    var gape: V3 { beakBase + V3(0, -0.3 * a.beakDepth - 0.02 * a.headHeight, 0.28 * a.headLength) }
    var eyeCenter: (Side) -> V3 {
        { s in
            let t: Float = 0.66
            let c = headCenterAt(t)
            return V3(s.sign * (headHalfWidth(t) * 0.97 - 0.62 * a.eyeRadius), c.y + 0.06 * a.headHeight, c.z)
        }
    }

    var shoulderX: Float { 0.5 * a.bodyWidth * 0.58 }
    func shoulder(_ s: Side) -> V3 { C + A * (0.20 * a.bodyLength) + U * (0.12 * a.bodyDepth) + V3(s.sign * shoulderX, 0, 0) }
    var wingHalfSpan: Float { a.wingspan / 2 - shoulderX }

    var tailPivot: V3 { C - A * (0.46 * a.bodyLength) + U * (0.02 * a.bodyDepth) }
    var tailDir: V3 { simd_normalize(Bk - U * 0.12) }

    var legX: Float { 0.5 * a.bodyWidth * 0.5 }
    func foot(_ s: Side) -> V3 { V3(s.sign * legX, 0, -0.02) }
    func ankle(_ s: Side) -> V3 { foot(s) + V3(0, 0.80 * a.tarsus, 0.30 * a.tarsus) }
    func hip(_ s: Side) -> V3 { ankle(s) + V3(0, 0.45 * a.tarsus, -0.3 * a.tarsus) }
}

public enum BirdRigBuilder {
    public static let tailFanThreshold: Float = 3
    /// Wing parts that carry spread-feather geometry; hidden (option 1, empty) while folded.
    public static let spreadParts: [BirdJoint.WingJoint] = [.flap, .twist, .elbow, .secFold, .handTwist, .primA, .primB, .primC]

    public static func build(_ p: BirdProfile, seed: UInt64 = 1) -> BirdRig {
        let f = BirdFrame(p)
        var rng = SeededRNG(seed: seed &+ UInt64(abs(p.species.rawValue.hashValue) & 0xFFFF))
        var rig = Rig(name: p.species.rawValue, lods: 1, switchDistances: [])
        var specs = [BirdJointSpec?](repeating: nil, count: BirdJoint.count)

        func declare(_ j: BirdJoint, parent: BirdJoint?, pivot: V3, axis: V3, mimic: (BirdJoint, Float)? = nil, options: Int = 1) {
            let ax = simd_length(axis) > 0 ? simd_normalize(axis) : BirdFrame.X
            let joint: Joint
            if let m = mimic {
                joint = Joint(.revolute, axis: ax, range: j.range, duration: 0.2, mimic: .init(m.0.name, ratio: m.1))
            } else {
                joint = Joint(.revolute, axis: ax, range: j.range, duration: 0.4)
            }
            rig.part(j.name, parent: parent?.name, pivot: pivot, joint: joint, options: options)
            specs[j.index] = BirdJointSpec(name: j.name, parent: parent?.index, pivot: pivot, axis: ax, range: j.range,
                                           mimic: mimic.map { ($0.0.index, $0.1) })
        }

        // Head chain.
        let neckPivot = f.neckPivot, headJoint = f.headJoint
        declare(.neckPitch, parent: nil, pivot: neckPivot, axis: BirdFrame.X)
        declare(.headYaw, parent: .neckPitch, pivot: headJoint, axis: BirdFrame.Y)
        declare(.headRoll, parent: .headYaw, pivot: headJoint, axis: -BirdFrame.Z)
        declare(.headPitch, parent: .headRoll, pivot: headJoint, axis: BirdFrame.X)
        declare(.jaw, parent: .headPitch, pivot: f.gape, axis: -BirdFrame.X)
        let eyeL = f.eyeCenter(.left), eyeR = f.eyeCenter(.right)
        declare(.lidL, parent: .headPitch, pivot: eyeL, axis: V3(0, 0, -1))
        declare(.lidR, parent: .headPitch, pivot: eyeR, axis: V3(0, 0, 1))
        let crestPivot = f.headCenter + V3(0, 0.2 * f.a.headHeight, 0.2 * f.a.headLength)
        declare(.crest, parent: .headPitch, pivot: crestPivot, axis: BirdFrame.X)
        // Tail.
        declare(.tailPitch, parent: nil, pivot: f.tailPivot, axis: BirdFrame.X)
        let tailBase = f.tailPivot
        declare(.tailFanL, parent: .tailPitch, pivot: tailBase - V3(0.002, 0, 0), axis: f.axis(f.U, .left), options: 2)
        declare(.tailFanR, parent: .tailPitch, pivot: tailBase + V3(0.002, 0, 0), axis: f.U, options: 2)
        // Legs.
        for s in Side.allCases {
            declare(.leg(s, .hip), parent: nil, pivot: f.hip(s), axis: BirdFrame.X)
            declare(.leg(s, .ankle), parent: .leg(s, .hip), pivot: f.ankle(s), axis: BirdFrame.X)
            declare(.leg(s, .toes), parent: .leg(s, .ankle), pivot: f.foot(s) + V3(0, 0.001, 0), axis: -BirdFrame.X)
            declare(.leg(s, .hallux), parent: .leg(s, .ankle), pivot: f.foot(s) + V3(0, 0.001, 0), axis: BirdFrame.X)
        }
        // Wings.
        for s in Side.allCases {
            let S = f.shoulder(s)
            let hs = f.wingHalfSpan
            let E = S + V3(s.sign * 0.24 * hs, 0, 0), Wr = E + V3(s.sign * 0.30 * hs, 0, 0)
            let handTip = Wr + V3(s.sign * 0.22 * hs, 0, 0)
            declare(.wing(s, .flap), parent: nil, pivot: S, axis: f.axis(f.Bk, s), options: 2)
            declare(.wing(s, .sweep), parent: .wing(s, .flap), pivot: S, axis: f.axis(f.U, s))
            declare(.wing(s, .twist), parent: .wing(s, .sweep), pivot: S, axis: BirdFrame.X, options: 2)
            declare(.wing(s, .elbow), parent: .wing(s, .twist), pivot: E, axis: f.axis(f.U, s), options: 2)
            declare(.wing(s, .secFold), parent: .wing(s, .elbow), pivot: E, axis: f.axis(f.U, s), options: 2)
            declare(.wing(s, .wrist), parent: .wing(s, .elbow), pivot: Wr, axis: f.axis(f.U, s))
            declare(.wing(s, .handTwist), parent: .wing(s, .wrist), pivot: Wr, axis: BirdFrame.X, options: 2)
            // Master control for the primary fan; the three groups follow it.
            declare(.wing(s, .primFold), parent: nil, pivot: Wr, axis: f.axis(f.U, s))
            let mid = lerp(Wr, handTip, 0.5)
            declare(.wing(s, .primA), parent: .wing(s, .handTwist), pivot: Wr, axis: f.axis(f.U, s), mimic: (.wing(s, .primFold), 0.46), options: 2)
            declare(.wing(s, .primB), parent: .wing(s, .handTwist), pivot: mid, axis: f.axis(f.U, s), mimic: (.wing(s, .primFold), 0.47), options: 2)
            declare(.wing(s, .primC), parent: .wing(s, .handTwist), pivot: handTip, axis: f.axis(f.U, s), mimic: (.wing(s, .primFold), 0.28), options: 2)
        }
        precondition(specs.allSatisfy { $0 != nil })
        // Tail feather cards show once the fan opens; the closed tail is the solid core.
        for j in [BirdJoint.tailFanL, .tailFanR] { rig.optionLinks.append(RigOptionLink(part: j.name, joint: j.name, thresholds: [tailFanThreshold])) }
        // Folded wing shells, swapped in above `foldThreshold` of primFold.
        for s in Side.allCases {
            rig.part(foldPartName(s), parent: nil, pivot: f.shoulder(s), joint: Joint(.revolute, axis: BirdFrame.X, range: 0...1, duration: 0.2), options: 2)
            let fold = BirdJoint.wing(s, .primFold).name
            rig.optionLinks.append(RigOptionLink(part: foldPartName(s), joint: fold, thresholds: [foldThreshold]))
            for w in spreadParts { rig.optionLinks.append(RigOptionLink(part: BirdJoint.wing(s, w).name, joint: fold, thresholds: [foldThreshold])) }
        }

        addBody(&rig, f, &rng)
        addHead(&rig, f)
        addTail(&rig, f, &rng)
        for s in Side.allCases { addLeg(&rig, f, s); addWing(&rig, f, s, &rng); addFoldedWing(&rig, f, s, &rng) }

        var folded: [String: Int] = [:]
        for s in Side.allCases {
            folded[foldPartName(s)] = 1
            for w in spreadParts { folded[BirdJoint.wing(s, w).name] = 1 }
        }
        rig.states = [RigState("perched", BirdPoses.perched(p).named, options: folded), RigState("flight", BirdPoses.glide(p).named)]
        rig.defaultState = "perched"
        let feet = Side.allCases.map { f.foot($0) }
        let roots = Side.allCases.map { f.shoulder($0) }
        return BirdRig(profile: p, rig: rig, joints: specs.map { $0! }, comHeight: f.a.standHeight, feet: feet, wingRoot: roots, halfSpan: f.wingHalfSpan)
    }
}

extension BirdPose {
    /// Joint name to value map for `RigState`.
    var named: [String: Float] {
        var d: [String: Float] = [:]
        for j in BirdJoint.all {
            let n = j.name
            if (n.hasPrefix("primA") || n.hasPrefix("primB") || n.hasPrefix("primC")) { continue }
            d[n] = values[j.index]
        }
        return d
    }
}
