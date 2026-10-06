import simd
import Foundation

/// Precast concrete stepping stone, 45 cm round by default, 5 cm thick: a hand-cast slab with a softly
/// rounded edge, pebbled exposed-aggregate face, slightly irregular outline and a small chip off the rim.
public struct ConcreteStepper: RealAsset {
    public static let id = "concrete-stepper"
    public static let summary = "Precast concrete stepping stone, 45 cm round x 5 cm: rounded edge, exposed-aggregate face, irregular outline, chipped rim."
    public static let tags = ["prop", "garden", "outdoor", "landscaping", "concrete", "stone"]
    public static let budget = 4_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 40, distance: 1.1, studio: true)

    public enum Shape: String, Sendable { case round, square, flagstone }

    /// Diameter or side length (m).
    public var size: Float = 0.45
    /// Slab thickness (m).
    public var thickness: Float = 0.05
    /// Outline shape.
    public var shape: Shape = .round
    /// Face material.
    public var concrete: MaterialKey = "concrete.exposed-aggregate"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let sd = UInt32(truncatingIfNeeded: rng.int(0...100_000))
        let r = size / 2
        let n = 56
        let chipAt = rng.float(0...(2 * .pi))
        var outline: [V2] = []
        for i in 0..<n {
            let a = Float(i) / Float(n) * 2 * .pi
            var rr: Float
            switch shape {
            case .round: rr = r
            case .square: rr = r / max(abs(cos(a)), abs(sin(a))) ; rr = min(rr, r * 1.3)
            case .flagstone: rr = r * (0.82 + 0.25 * Noise.fbm(V3(cos(a) * 1.4, sin(a) * 1.4, 0), octaves: 2, seed: sd + 9) + 0.08)
            }
            rr *= 1 + 0.012 * Noise.fbm(V3(cos(a) * 4, sin(a) * 4, 0), octaves: 3, seed: sd)
            let da = atan2(sin(a - chipAt), cos(a - chipAt))
            rr -= 0.012 * max(0, 1 - abs(da) / 0.12)
            outline.append(V2(cos(a), sin(a)) * rr)
        }
        if shape == .square { outline = Shape2D.rounded(Shape2D.rect(size, size), radius: 0.02, segments: 4) }
        var slab = Prim.extrude(outline, depth: thickness, bevel: 0.012, bevelSegments: 3, material: concrete)
        slab = slab.transformed(Xform(translation: V3(0, thickness / 2, 0), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
        var m = Model(name: Self.id)
        m.add(slab)
        // Exposed aggregate: tiny pebbles pressed into the top face.
        for k in 0..<50 {
            var q = rng.fork(k)
            let a = q.float(0...(2 * .pi)), d = sqrt(q.float()) * (r - 0.03)
            let s = q.float(0.006...0.012)
            m.add(Prim.superellipsoid(V3(s, s * 0.5, s * 0.8), exponent: 2.2, subdivisions: 2, material: "rock.river:7A7268"),
                  Xform(translation: V3(cos(a) * d, thickness + s * 0.1, sin(a) * d), rotation: simd_quatf(degrees: q.float(0...180), axis: .up)))
        }
        let bb = m.bounds
        m = m.transformed(Xform(translation: V3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2)))
        groundAO(&m, height: 0.03, floor: 0.6)
        return LODModel(m)
    }
}
