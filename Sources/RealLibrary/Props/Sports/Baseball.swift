import simd
import Foundation

/// Regulation baseball, 9 in (22.9 cm) around, 7.3 cm across: white cowhide sphere joined along the
/// classic figure-8 seam by 108 double red stitches, each a raised V across the seam. `count` lays a
/// small cluster on the ground (extra balls at lighter detail). `BaseballMesh` builds the ball at three
/// detail levels for other props (`ball-bucket`).
public struct Baseball: RealAsset {
    public static let id = "baseball"
    public static let summary = "Regulation baseball, 9 in around: two figure-8 white cowhide panels joined by 108 raised double red stitches; count knob for a small cluster."
    public static let tags = ["prop", "sports", "leather"]
    public static let budget = 9000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 22, distance: 0.32, studio: true)

    /// Ball radius (m). Regulation 9-9.25 in circumference.
    public var radius: Float = BaseballMesh.radius
    /// Number of balls; the first is full detail, the rest use the medium mesh.
    public var count: Int = 1
    /// Hide material key.
    public var hide: MaterialKey = "leather.baseball"
    /// Stitch thread material key.
    public var thread: MaterialKey = "thread.red"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var full = Model(name: Self.id), lite = Model(name: Self.id)
        var placed: [V2] = []
        for i in 0..<max(1, count) {
            var p = V2.zero
            if i > 0 {
                for _ in 0..<40 {
                    let c = rng.inDisc(radius: radius * 2 + 0.03 * Float(i))
                    if placed.allSatisfy({ simd_distance($0, c) > radius * 2.05 }) { p = c; break }
                }
            }
            placed.append(p)
            let rot = simd_quatf(angle: rng.float(0...(2 * .pi)), axis: rng.unitVector())
            let x = Xform(translation: V3(p.x, radius, p.y), rotation: rot)
            for s in BaseballMesh.ball(i == 0 ? .full : .medium, radius: radius, hide: hide, thread: thread) { full.add(s, x) }
            for s in BaseballMesh.ball(i == 0 ? .medium : .lite, radius: radius, hide: hide, thread: thread) { lite.add(s, x) }
        }
        let bb = full.bounds
        let shift = Xform(translation: V3(-(bb.min.x + bb.max.x) / 2, 0, -(bb.min.z + bb.max.z) / 2))
        full = full.transformed(shift); lite = lite.transformed(shift)
        groundAO(&full, height: radius, floor: 0.55); groundAO(&lite, height: radius, floor: 0.55)
        return LODModel(levels: [full, lite], switchDistances: [3])
    }
}

/// Shared baseball geometry, centred at the origin.
public enum BaseballMesh {
    /// Regulation radius: 9.1 in circumference.
    public static let radius: Float = 0.0368

    public enum Detail: Sendable { case full, medium, lite, filler }

    /// Unit-sphere seam curve (figure-8 / tennis-ball curve), t in 0..<2 pi. Lies exactly on the sphere.
    public static func seam(_ t: Float) -> V3 {
        let a: Float = 0.72, b: Float = 0.28, c = 2 * sqrt(a * b)
        return V3(a * cos(t) + b * cos(3 * t), c * sin(2 * t), a * sin(t) - b * sin(3 * t))
    }

    /// Points on the seam at equal arc length (unit sphere).
    public static func seamPoints(_ n: Int) -> [V3] {
        let dense = 2000
        let raw = (0..<dense).map { seam(Float($0) / Float(dense) * 2 * .pi) }
        var cum: [Float] = [0]
        for i in 1...dense { cum.append(cum[i - 1] + simd_distance(raw[i - 1], raw[i % dense])) }
        let total = cum[dense]
        var out: [V3] = [], j = 0
        for k in 0..<n {
            let s = Float(k) / Float(n) * total
            while cum[j + 1] < s { j += 1 }
            let f = (s - cum[j]) / max(cum[j + 1] - cum[j], 1e-9)
            out.append(simd_normalize(lerp(raw[j], raw[(j + 1) % dense], f)))
        }
        return out
    }

    /// Ball surfaces: hide sphere plus seam stitches (full: 108 raised V stitches; medium: two thread
    /// lines; lite: one thread line; filler: hide only).
    public static func ball(_ detail: Detail, radius r: Float = radius, hide: MaterialKey = "leather.baseball",
                            thread: MaterialKey = "thread.red") -> [Surface] {
        let sub: Int
        switch detail { case .full: sub = 18; case .medium: sub = 6; case .lite: sub = 6; case .filler: sub = 3 }
        // Hide: sphere with a shallow groove along the seam and a slight pillow either side of it.
        let groovePts = seamPoints(240)
        let groove = detail == .full || detail == .medium
        var shell = Prim.cubeSphere(subdivisions: sub, material: hide) { d in
            guard groove else { return d * r }
            let dist = groovePts.reduce(Float.infinity) { min($0, simd_distance($1, d)) } * r
            let g = -0.0005 * exp(-pow(dist / 0.0016, 2)) + 0.00025 * exp(-pow((dist - 0.004) / 0.002, 2))
            return d * (r + g)
        }
        shell.recomputeNormals()
        shell.computeTangents()
        var out = [shell]
        switch detail {
        case .full:
            var st = Surface(material: thread)
            let n = 108, pts = seamPoints(n), w: Float = 0.0032, rt: Float = 0.00055
            for i in 0..<n {
                let p = pts[i], q = pts[(i + 1) % n], nrm = p
                let tan = simd_normalize(q - p), side = simd_normalize(simd_cross(nrm, tan))
                let pitch = simd_distance(p, q) * r
                for s: Float in [-1, 1] {
                    // One leg of the V: from the outer hole forward and in to the seam centre.
                    let a = nrm * r + side * (s * w) - tan * (pitch * 0.35)
                    let b = nrm * r + side * (s * 0.0006) + tan * (pitch * 0.85)
                    let mid = (a + b) / 2
                    let lift = simd_normalize(mid) * (r + 0.00085)
                    let path = [simd_normalize(a) * (r - 0.0002), lift, simd_normalize(b) * (r + 0.0002)]
                    st.append(Prim.tube(path, radii: [rt, rt * 1.1, rt * 0.9], sides: 4, seamTile: 0.004, material: thread, capEnd: true))
                }
            }
            st.recomputeNormals(weldSeams: false)
            st.computeTangents()
            out.append(st)
        case .medium, .lite:
            let n = detail == .medium ? 56 : 24
            let pts = seamPoints(n)
            let offsets: [Float] = detail == .medium ? [-0.0019, 0.0019] : [0]
            for off in offsets {
                var path: [V3] = []
                for i in 0...n {
                    let p = pts[i % n], q = pts[(i + 1) % n]
                    let side = simd_normalize(simd_cross(p, q - p))
                    path.append(simd_normalize(p + side * (off / r)) * (r + 0.0003))
                }
                let rad: Float = detail == .medium ? 0.0011 : 0.0016
                out.append(Prim.sweep(Shape2D.circle(rad, segments: 3), along: Array(path.dropLast()), closedPath: true, material: thread))
            }
        case .filler: break
        }
        return out
    }
}
