import simd
import Foundation

/// Temporary protective grounding jumper (Hastings/Chance class): 1.8 m of 2/0 fine-strand copper in a
/// clear PVC jacket, loosely coiled on the ground, with an aluminium threaded ferrule and black shrink at
/// each end and a bronze C clamp with a hot-stick eye screw on each ferrule.
public struct GroundingSet: RealAsset, RealHandTool {
    public static let id = "grounding-set"
    public static let summary = "Temporary grounding jumper: coiled clear-jacket copper lead with ferrules and two bronze C clamps."
    public static let tags = ["prop", "tool", "handheld", "utility", "electrical", "metal"]
    public static let budget = 14000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 45, distance: 1.0, studio: true)
    static let R: Float = 0.0085
    static let path: [V3] = {
        var p: [V3] = [V3(-0.34, R, -0.2), V3(-0.25, R, -0.2)]
        let turns: Float = 2.2, n = 60
        for i in 0...n {
            let u = Float(i) / Float(n), a = -.pi / 2 + u * turns * 2 * .pi
            let r = 0.2 - 0.035 * u + 0.012 * sin(u * 17)
            let lift = R + 2 * R * floor(u * turns) * 0.9 + 0.004 * sin(a * 3)
            p.append(V3(0.02 + r * cos(a), lift, 0.0 + r * sin(a) * 0.85))
        }
        p += [V3(0.26, 3 * R, 0.17), V3(0.31, R, 0.23), V3(0.36, R, 0.26)]
        return catmull(p, per: 2)
    }()
    /// Raise so the lowest point (shrink sleeve under the lead) sits on y = 0.
    static let lift: Float = 0.0
    /// Clamp eye screw of end A (where the hot stick or hand takes it).
    public static let grip = SIMD3<Float>(-0.42, 0.11, -0.2)
    /// Jaw of clamp A.
    public static let tip = SIMD3<Float>(-0.42, 0.045, -0.2)

    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let jacket: MaterialKey = "plastic.pvc-clear", cu: MaterialKey = "metal.copper-strand"
        let bronze: MaterialKey = "metal.brass-aged", alu: MaterialKey = "metal.satin-aluminum", shrink: MaterialKey = "rubber"
        var levels: [Model] = []
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let pth = Self.path, sides = l == 0 ? 14 : 8
            m.add(Prim.tube(pth, radii: Array(repeating: 0.0062, count: pth.count), sides: sides, seamTile: 0.02, material: cu))
            m.add(Prim.tube(pth, radii: Array(repeating: Self.R, count: pth.count), sides: sides + 2, seamTile: 0.06, material: jacket))
            for (end, dirFrom) in [(pth[0], pth[1]), (pth[pth.count - 1], pth[pth.count - 2])] {
                let dd = end - dirFrom, d = simd_normalize(V3(dd.x, 0, dd.z))
                let rot = simd_quatf(from: V3(0, 1, 0), to: d)
                // Shrink sleeve, ferrule, then the clamp body on the ferrule stud.
                m.add(Prim.cylinder(radius: 0.0102, height: 0.045, bevel: 0.002, segments: sides + 2, material: shrink), Xform(translation: end - d * 0.04, rotation: rot))
                m.add(Prim.cylinder(radius: 0.011, height: 0.05, bevel: 0.002, segments: sides + 2, material: alu), Xform(translation: end, rotation: rot))
                let cc = end + d * 0.08 + V3(0, 0.03, 0)
                let side = simd_normalize(simd_cross(d, V3(0, 1, 0)))
                // C clamp: cast bronze C in the vertical plane through the lead axis.
                var cpts: [V3] = []
                for i in 0...16 { let a = (-0.75 + Float(i) / 16 * 1.5) * .pi; cpts.append(cc + d * (0.034 * cos(a)) + V3(0, 0.034 * sin(a) + 0.014, 0)) }
                m.add(Prim.sweep(Shape2D.roundedRect(0.022, 0.016, radius: 0.004), along: cpts, up: side, material: bronze))
                // Eye screw: threaded rod with T eye on top.
                let top = cc + V3(0, 0.062, 0)
                m.add(Prim.tube([cc + V3(0, 0.0, 0), top], radii: [0.005, 0.005], sides: 10, seamTile: 0.02, material: "metal.galvanized"))
                m.add(Prim.torus(major: 0.014, minor: 0.004, segments: 18, sides: 8, material: bronze),
                      Xform(translation: top + V3(0, 0.012, 0), rotation: simd_quatf(from: V3(0, 1, 0), to: side)))
                _ = rng.float()
            }
            var out = Model(name: Self.id)
            out.add(m, Xform(translation: V3(0, Self.lift, 0)))
            groundAO(&out, height: 0.04)
            levels.append(out)
        }
        return LODModel(levels: levels, switchDistances: [4])
    }
}
