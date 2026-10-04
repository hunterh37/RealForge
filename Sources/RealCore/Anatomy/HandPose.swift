import simd

/// The 27 tracked hand joints, in the order and with the meaning of ARKit's `HandSkeleton.JointName`
/// on visionOS. Finger rays run metacarpal (carpometacarpal joint) -> knuckle (MCP) -> intermediate
/// base (PIP) -> intermediate tip (DIP) -> tip (pulp). The thumb has no separate metacarpal joint:
/// thumbKnuckle is the CMC joint, thumbIntermediateBase the MCP, thumbIntermediateTip the IP.
public enum HandJoint: Int, CaseIterable, Sendable {
    case wrist
    case thumbKnuckle, thumbIntermediateBase, thumbIntermediateTip, thumbTip
    case indexMetacarpal, indexKnuckle, indexIntermediateBase, indexIntermediateTip, indexTip
    case middleMetacarpal, middleKnuckle, middleIntermediateBase, middleIntermediateTip, middleTip
    case ringMetacarpal, ringKnuckle, ringIntermediateBase, ringIntermediateTip, ringTip
    case littleMetacarpal, littleKnuckle, littleIntermediateBase, littleIntermediateTip, littleTip
    case forearmWrist, forearmArm
}

public enum Chirality: Sendable { case left, right }

/// Digit rays, radial to ulnar.
public enum Digit: Int, CaseIterable, Sendable {
    case thumb, index, middle, ring, little

    /// Joints along the ray, proximal to distal. Thumb: CMC, MCP, IP, tip. Fingers: CMC, MCP, PIP, DIP, tip.
    public var joints: [HandJoint] {
        switch self {
        case .thumb: [.thumbKnuckle, .thumbIntermediateBase, .thumbIntermediateTip, .thumbTip]
        case .index: [.indexMetacarpal, .indexKnuckle, .indexIntermediateBase, .indexIntermediateTip, .indexTip]
        case .middle: [.middleMetacarpal, .middleKnuckle, .middleIntermediateBase, .middleIntermediateTip, .middleTip]
        case .ring: [.ringMetacarpal, .ringKnuckle, .ringIntermediateBase, .ringIntermediateTip, .ringTip]
        case .little: [.littleMetacarpal, .littleKnuckle, .littleIntermediateBase, .littleIntermediateTip, .littleTip]
        }
    }
}

/// Positions of the 27 joints in one space (ARKit anchor space or world), meters.
public struct HandPose: Sendable {
    public var chirality: Chirality
    public var positions: [V3]

    public init(chirality: Chirality, positions: [V3]) {
        precondition(positions.count == HandJoint.allCases.count)
        self.chirality = chirality; self.positions = positions
    }

    public subscript(_ j: HandJoint) -> V3 {
        get { positions[j.rawValue] }
        set { positions[j.rawValue] = newValue }
    }

    /// Wrist crease to middle fingertip, the anthropometric hand length.
    public var handLength: Float {
        simd_distance(self[.wrist], self[.middleKnuckle]) + simd_distance(self[.middleKnuckle], self[.middleIntermediateBase])
            + simd_distance(self[.middleIntermediateBase], self[.middleIntermediateTip]) + simd_distance(self[.middleIntermediateTip], self[.middleTip])
    }
}

/// A right-handed orthonormal frame: origin, y along the bone (proximal to distal), z dorsal, x = y x z.
/// x points ulnarly on the right hand and radially on the left; `HandFrames.radialSign` converts.
public struct BoneFrame: Sendable {
    public var origin: V3
    public var x: V3, y: V3, z: V3
    public init(origin: V3, x: V3, y: V3, z: V3) { self.origin = origin; self.x = x; self.y = y; self.z = z }

    /// Local (x lateral, y along, z dorsal) to the pose's space.
    @inlinable public func point(_ p: V3) -> V3 { origin + x * p.x + y * p.y + z * p.z }
    @inlinable public func direction(_ d: V3) -> V3 { x * d.x + y * d.y + z * d.z }

    public var rotation: simd_quatf { simd_quatf(simd_float3x3(columns: (x, y, z))) }

    public func matrix(scale: V3 = V3(1, 1, 1)) -> simd_float4x4 {
        simd_float4x4(columns: (V4(x * scale.x, 0), V4(y * scale.y, 0), V4(z * scale.z, 0), V4(origin, 1)))
    }
}

/// Bone and palm frames derived from joint positions only, so live tracking and synthetic poses
/// produce the same frames.
///
/// Palm: y from wrist to the middle knuckle, radial axis from little to index knuckle, z dorsal.
/// Each ray gets a flexion axis from its metacarpal frame; phalanx frames rotate about it, which is
/// how the interphalangeal joints move (hinges). Frames are right-handed; authored lateral offsets
/// are radial-positive and multiplied by `radialSign` (right -1, left +1), and rigid meshes for the
/// left hand are the mirrored right-hand meshes.
public struct HandFrames: Sendable {
    public var chirality: Chirality
    public var palm: BoneFrame
    public var forearm: BoneFrame
    /// [digit][segment]: thumb 3 segments (MC, PP, DP), fingers 4 (MC, PP, MP, DP).
    public var bones: [[BoneFrame]]
    /// [digit][segment] tracked joint-to-joint length.
    public var lengths: [[Float]]
    /// Hand length / reference hand length.
    public var scale: Float
    /// Local x of every frame is radial (+1) or ulnar (-1).
    public var radialSign: Float { chirality == .right ? -1 : 1 }

    public init(_ pose: HandPose, referenceHandLength: Float = HandMorphometry.restTrackedLength) {
        chirality = pose.chirality
        let sign: Float = pose.chirality == .right ? 1 : -1
        let wrist = pose[.wrist]
        let y = (pose[.middleKnuckle] - wrist).normalized
        let radial0 = (pose[.indexKnuckle] - pose[.littleKnuckle]).normalized
        let z = simd_cross(y, radial0).normalized * sign
        let radial = (radial0 - y * simd_dot(radial0, y)).normalized
        palm = BoneFrame(origin: wrist, x: simd_cross(y, z), y: y, z: z)

        let fa = (pose[.forearmWrist] - pose[.forearmArm])
        var fy = fa.normalized
        if simd_length(fa) < 0.02 { fy = y }
        var fz = (z - fy * simd_dot(z, fy))
        fz = simd_length(fz) < 1e-3 ? fy.anyPerpendicular : fz.normalized
        forearm = BoneFrame(origin: pose[.forearmWrist], x: simd_cross(fy, fz), y: fy, z: fz)

        scale = max(0.5, min(1.6, pose.handLength / referenceHandLength))

        var bones: [[BoneFrame]] = [], lengths: [[Float]] = []
        for d in Digit.allCases {
            let js = d.joints.map { pose[$0] }
            var frames: [BoneFrame] = [], lens: [Float] = []
            // Dorsal hint for the metacarpal. Thumb: rest thumbnail faces radially and somewhat dorsally
            // (the thumb ray is pronated ~80 degrees against the fingers).
            let hint: V3 = d == .thumb ? (radial * 0.8 + z * 0.55 - y * 0.1).normalized : z
            var flexAxis = V3.zero
            for s in 0..<(js.count - 1) {
                let a = js[s], b = js[s + 1]
                let dy = (b - a).normalized
                var dz: V3
                if s == 0 {
                    dz = hint - dy * simd_dot(hint, dy)
                    dz = simd_length(dz) < 1e-4 ? dy.anyPerpendicular : dz.normalized
                    flexAxis = simd_cross(dy, dz)
                } else {
                    dz = simd_cross(flexAxis, dy)
                    if simd_length(dz) < 1e-4 { dz = frames[s - 1].z }
                    dz = dz.normalized
                }
                frames.append(BoneFrame(origin: a, x: simd_cross(dy, dz).normalized, y: dy, z: dz))
                lens.append(simd_distance(a, b))
            }
            bones.append(frames); lengths.append(lens)
        }
        self.bones = bones; self.lengths = lengths
    }

    public func bone(_ d: Digit, _ s: Int) -> BoneFrame { bones[d.rawValue][s] }
    public func length(_ d: Digit, _ s: Int) -> Float { lengths[d.rawValue][s] }

    /// A point given in a bone's normalized coordinates: t along the tracked length (0 proximal joint,
    /// 1 distal joint), x radial-positive and z dorsal in meters at reference scale (scaled by hand size).
    public func point(_ d: Digit, _ s: Int, t: Float, x: Float = 0, z: Float = 0) -> V3 {
        let f = bone(d, s)
        return f.origin + f.y * (t * length(d, s)) + (f.x * (x * radialSign) + f.z * z) * scale
    }

    /// A point in the palm frame (x radial, y distal, z dorsal), meters at reference scale.
    public func palmPoint(_ p: V3) -> V3 { palm.point(V3(p.x * radialSign, p.y, p.z) * scale) }
    public func forearmPoint(_ p: V3) -> V3 { forearm.point(V3(p.x * radialSign, p.y, p.z) * scale) }
}
