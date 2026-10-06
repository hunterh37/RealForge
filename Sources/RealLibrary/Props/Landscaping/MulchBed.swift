import simd
import Foundation

/// Shredded-bark mulch bed, 0.9 m radius by default: a 5-8 cm crowned layer with a ragged, feathered
/// edge where chips spill onto the ground, loose chips scattered past the rim. Shape: round, oval or
/// kidney. Mulch is shredded hardwood bark (`mulch.bark`), partly sun bleached on top.
public struct MulchBed: RealAsset {
    public static let id = "mulch-bed"
    public static let summary = "Shredded-bark mulch bed, 0.9 m radius: crowned 6 cm layer with a spade-cut turf edge, bark slabs and loose chips; round, oval or kidney shape."
    public static let tags = ["prop", "garden", "outdoor", "landscaping", "wood", "ground"]
    public static let budget = 14_500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 34, distance: 1.0, studio: true)

    public enum Shape: String, Sendable { case round, oval, kidney }

    /// Bed radius (m); for oval and kidney, the half-length along X.
    public var radius: Float = 0.9
    /// Outline shape.
    public var shape: Shape = .round
    /// Crown depth of the mulch layer (m).
    public var depth: Float = 0.065
    /// Mulch material.
    public var mulch: MaterialKey = "mulch.bark"
    /// Lawn collar material around the cut edge.
    public var lawn: MaterialKey = "grass.lawn-thatch"
    /// Trench floor material.
    public var trench: MaterialKey = "ground.dirt:4A3626"
    /// Number of loose chips scattered past the rim.
    public var looseChips: Int = 40
    /// Number of large chips modelled on the surface.
    public var surfaceChips: Int = 260
    public init() {}

    /// Boundary radius at angle `a` (radians) as a fraction of `radius`.
    func boundary(_ a: Float) -> V2 {
        switch shape {
        case .round: return V2(cos(a), sin(a))
        case .oval: return V2(cos(a), sin(a) * 0.62)
        case .kidney:
            let r = 1 - 0.28 * pow(max(0, sin(a)), 3)
            return V2(cos(a) * r, sin(a) * 0.6 * r)
        }
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let sd = UInt32(truncatingIfNeeded: rng.int(0...100_000))
        func layer(rings: Int, segs: Int) -> Surface {
            var s = Surface(material: mulch)
            for j in 0...rings {
                let t = Float(j) / Float(rings)
                for i in 0...segs {
                    let a = Float(i) / Float(segs) * 2 * .pi
                    let b = boundary(a) * radius
                    let wob = 1 + 0.09 * Noise.fbm(V3(cos(a) * 3, sin(a) * 3, 0), octaves: 3, seed: sd)
                    let p2 = b * t * (j == rings ? wob * 1.03 : wob)
                    let edge = 1 - t
                    // Crowned profile: flat top falling off over the last 25%, feathered to 0 at the rim.
                    let crown = depth * min(1, edge / 0.03)
                    let lump = (0.02 * Noise.fbm(V3(p2.x * 3, 0, p2.y * 3), octaves: 4, seed: sd + 1) + 0.012 * Noise.ridged(V3(p2.x * 22, 0, p2.y * 22), octaves: 2, seed: sd + 2)) * min(1, edge * 4)
                    s.add(V3(p2.x, max(0.001, crown + lump), p2.y), .up, V2(p2.x, -p2.y))
                }
            }
            let row = UInt32(segs + 1)
            for j in 0..<UInt32(rings) { for i in 0..<UInt32(segs) {
                let a = j * row + i
                s.quad(a, a + 1, a + row + 1, a + row)
            }}
            s.recomputeNormals(weldSeams: true)
            s.computeTangents()
            return s
        }
        var m = Model(name: Self.id)
        m.add(layer(rings: 18, segs: 84))
        // Loose chips spilled past the rim.
        for k in 0..<looseChips {
            var r = rng.fork(k)
            let a = r.float(0...(2 * .pi))
            let p = boundary(a) * radius * r.float(1.0...1.04)
            let chip = Prim.roundedBox(V3(r.float(0.025...0.06), r.float(0.004...0.008), r.float(0.01...0.02)), radius: 0.0018, bevelSegments: 1, material: mulch)
            m.add(chip, Xform(translation: V3(p.x, 0.003, p.y), rotation: simd_quatf(degrees: r.float(0...360), axis: .up) * simd_quatf(degrees: r.float(-8...8), axis: V3(1, 0, 0))))
        }
        // Large chips and bark strips lying on the surface, following the crown.
        func heightAt(_ q: V2) -> Float {
            let a = atan2(q.y, q.x)
            let bl = simd_length(boundary(a) * radius) * (1 + 0.09 * Noise.fbm(V3(cos(a) * 3, sin(a) * 3, 0), octaves: 3, seed: sd))
            let edge = max(0, 1 - simd_length(q) / bl)
            let crown = depth * min(1, edge / 0.03)
            let lump = (0.02 * Noise.fbm(V3(q.x * 3, 0, q.y * 3), octaves: 4, seed: sd + 1) + 0.012 * Noise.ridged(V3(q.x * 22, 0, q.y * 22), octaves: 2, seed: sd + 2)) * min(1, edge * 4)
            return max(0.001, crown + lump)
        }
        for k in 0..<surfaceChips {
            var r = rng.fork(1000 + k)
            let a = r.float(0...(2 * .pi))
            let q = boundary(a) * radius * sqrt(r.float()) * 0.96
            let len = r.float(0.03...0.08)
            let chip = Prim.superellipsoid(V3(len, r.float(0.004...0.009), len * r.float(0.2...0.45)), exponent: 3, subdivisions: 1, material: mulch)
            m.add(chip, Xform(translation: V3(q.x, heightAt(q) + 0.001, q.y), rotation: simd_quatf(degrees: r.float(0...360), axis: .up) * simd_quatf(degrees: r.float(-14...14), axis: V3(1, 0, 0))))
        }
        // Spade-cut edge: a turf collar whose cut face slopes down into the trench around the bed.
        var turf = Surface(material: lawn)
        let segs = 96
        let prof: [(Float, Float)] = [(1.0, 0.001), (1.025, 0.0015), (1.03, 0.004), (1.06, 0.03), (1.07, 0.035), (1.25, 0.035)]
        for i in 0...segs {
            let a = Float(i) / Float(segs) * 2 * .pi
            let b = boundary(a) * radius * (1 + 0.09 * Noise.fbm(V3(cos(a) * 3, sin(a) * 3, 0), octaves: 3, seed: sd))
            for (f, y) in prof { let q = b * f; turf.add(V3(q.x, y, q.y), .up, V2(q.x, -q.y)) }
        }
        let rw = UInt32(prof.count)
        for i in 0..<UInt32(segs) { for j in 0..<(rw - 1) { let a = i * rw + j; turf.quad(a, a + rw, a + rw + 1, a + 1) } }
        turf.recomputeNormals(weldSeams: true); turf.computeTangents()
        m.add(turf)
        // Bare trench floor between mulch and turf.
        var dirt = Surface(material: trench)
        for i in 0...segs {
            let a = Float(i) / Float(segs) * 2 * .pi
            let b = boundary(a) * radius * (1 + 0.09 * Noise.fbm(V3(cos(a) * 3, sin(a) * 3, 0), octaves: 3, seed: sd))
            for f: Float in [0.985, 1.045] { let q = b * f; dirt.add(V3(q.x, 0.0025, q.y), .up, V2(q.x, -q.y)) }
        }
        for i in 0..<UInt32(segs) { let a = i * 2; dirt.quad(a, a + 2, a + 3, a + 1) }
        dirt.recomputeNormals(weldSeams: true); dirt.computeTangents()
        m.add(dirt)
        // Large bark slabs on top.
        for k in 0..<18 {
            var r = rng.fork(3000 + k)
            let a = r.float(0...(2 * .pi))
            let q = boundary(a) * radius * sqrt(r.float()) * 0.9
            let len = r.float(0.08...0.14)
            m.add(Prim.superellipsoid(V3(len, 0.012, len * 0.4), exponent: 3, subdivisions: 2, material: mulch) { d in 1 + 0.15 * d.y },
                  Xform(translation: V3(q.x, heightAt(q) + 0.004, q.y), rotation: simd_quatf(degrees: r.float(0...360), axis: .up) * simd_quatf(degrees: r.float(-10...10), axis: V3(1, 0, 0))))
        }
        var lite = Model(name: Self.id + "-lite")
        lite.add(layer(rings: 8, segs: 40))
        let bb = m.bounds
        let shift = V3(-(bb.min.x + bb.max.x) / 2, 0, -(bb.min.z + bb.max.z) / 2)
        m = m.transformed(Xform(translation: shift)); lite = lite.transformed(Xform(translation: shift))
        groundAO(&m, height: 0.06, floor: 0.6)
        return LODModel(levels: [m, lite], switchDistances: [12])
    }
}
