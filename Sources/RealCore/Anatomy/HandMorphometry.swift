import simd

/// Reference adult hand dimensions used to shape the anatomy meshes. Meshes are built at reference
/// size and scaled at runtime to the tracked hand: each long bone along its axis to the tracked
/// joint-to-joint length, cross sections by tracked hand length / `referenceHandLength`.
///
/// Sources:
/// - Segment lengths as a fraction of hand length: Buchholz, Armstrong & Goldstein (1992),
///   "Anthropometric data for describing the kinematics of the human hand", Ergonomics 35(3) 261-273.
/// - Hand length 189 mm: adult mean of the ANSUR II (2012) male and female hand-length means.
/// - Bone widths and depths (base, mid-shaft, head) and carpal sizes: approximate adult values read
///   from standard references (Gray's Anatomy, 42nd ed., hand chapter; Netter, Atlas of Human Anatomy,
///   wrist and hand plates) and rounded to 0.5 mm. Not measured from a single specimen or dataset.
/// - Muscle attachments and courses: same references. Dorsal veins follow the most common pattern,
///   a dorsal venous arch draining radially to the cephalic and ulnarly to the basilic vein.
public enum HandMorphometry {
    public static let referenceHandLength: Float = 0.189
    /// Joint-path hand length (wrist -> middle knuckle -> tip) of the reference rest pose. Tracked
    /// hands are scaled against this, so the reference skeleton maps to scale 1.
    public static let restTrackedLength: Float = HandPose.rest(.right, curl: 0).handLength

    /// [digit][segment] length / hand length (Buchholz 1992). Thumb: MC, PP, DP. Fingers: MC, PP, MP, DP.
    public static let lengthRatio: [[Float]] = [
        [0.251, 0.196, 0.158],
        [0.374, 0.265, 0.143, 0.097],
        [0.373, 0.277, 0.170, 0.108],
        [0.336, 0.259, 0.165, 0.107],
        [0.295, 0.206, 0.117, 0.093],
    ]

    public static func length(_ d: Digit, _ s: Int) -> Float { lengthRatio[d.rawValue][s] * referenceHandLength }

    /// Width (radio-ulnar) and depth (dorso-palmar) in meters at the base, mid-shaft and head.
    public struct Section: Sendable { public var w: Float; public var d: Float }
    public struct Dims: Sendable { public var base: Section; public var shaft: Section; public var head: Section }

    private static func mm(_ bw: Float, _ bd: Float, _ sw: Float, _ sd: Float, _ hw: Float, _ hd: Float) -> Dims {
        Dims(base: Section(w: bw / 1000, d: bd / 1000), shaft: Section(w: sw / 1000, d: sd / 1000), head: Section(w: hw / 1000, d: hd / 1000))
    }

    /// [digit][segment] cross-section dimensions. For distal phalanges `head` is the ungual tuft.
    public static let dims: [[Dims]] = [
        // Thumb: MC1 (saddle base, wide flat head), PP, DP.
        [mm(15, 13, 10, 9, 15, 12), mm(15, 11, 10, 6.5, 12, 8.5), mm(13, 9, 7, 5, 10, 4)],
        // Index
        [mm(16, 14, 8.5, 9, 14, 16), mm(15, 11, 9, 6.5, 11, 8), mm(12, 9, 7.5, 5.5, 9, 7), mm(10, 7, 5, 4, 7.5, 3.5)],
        // Middle
        [mm(15, 16, 8.5, 9, 14, 16), mm(16, 12, 9.5, 7, 12, 8.5), mm(13, 9.5, 8, 6, 10, 7), mm(10.5, 7.5, 5.5, 4, 8, 3.5)],
        // Ring
        [mm(12, 12, 7, 8, 12, 14), mm(14, 11, 8.5, 6.5, 11, 8), mm(12, 9, 7.5, 5.5, 9, 6.5), mm(10, 7, 5, 4, 7.5, 3.5)],
        // Little
        [mm(13, 11, 7, 7.5, 12, 13), mm(12, 9, 7.5, 5.5, 9.5, 7), mm(10, 7.5, 6.5, 5, 8, 6), mm(8.5, 6, 4.5, 3.5, 6.5, 3)],
    ]

    /// Reference relaxed right hand in the palm frame (x radial, y distal, z dorsal), meters.
    /// CMC joints, knuckles (MCP) and thumb, with the transverse metacarpal arch.
    public static let restCMC: [V3] = [
        V3(0.019, 0.010, -0.011),   // thumb CMC (trapezium)
        V3(0.0115, 0.027, 0.002),
        V3(0.0, 0.026, 0.004),
        V3(-0.011, 0.024, 0.002),
        V3(-0.0205, 0.020, -0.001),
    ]

    /// Direction of each metacarpal at rest (palm frame), before normalization.
    public static let restMetacarpalDirection: [V3] = [
        V3(0.6, 0.74, -0.27),
        V3(0.12, 1, -0.06),
        V3(0, 1, -0.05),
        V3(-0.10, 1, -0.06),
        V3(-0.24, 1, -0.11),
    ]
}
