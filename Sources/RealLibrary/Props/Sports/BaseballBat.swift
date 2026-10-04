import simd
import Foundation

/// 34 in pro wooden bat lying on the ground along X (knob at -X): flared knob, 0.93 in handle, long
/// taper into a 2.6 in barrel with a cupped end. Grain runs along the bat. `twoTone` switches from
/// natural ash to maple with a natural handle and a black lacquered barrel. A pine-tar band smears the
/// upper handle. The bat rests on its knob and barrel, so the handle stands a few mm off the ground.
public struct BaseballBat: RealAsset {
    public static let id = "baseball-bat"
    public static let summary = "34 in wooden baseball bat lying on the ground: flared knob, thin handle with a pine-tar band, long taper to a 2.6 in cupped barrel."
    public static let tags = ["prop", "sports", "wood"]
    public static let budget = 5000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 20, elevation: 25, distance: 1.3, studio: true)

    static let inch: Float = 0.0254
    /// Bat length (m), 34 in.
    public var length: Float = 34 * 0.0254
    /// Barrel diameter (m), 2.6 in.
    public var barrel: Float = 2.6 * 0.0254
    /// false: natural ash (`ash`). true: two-tone maple, natural handle (`handleWood`) and black barrel (`barrelWood`).
    public var twoTone: Bool = false
    /// Ash bat material key.
    public var ash: MaterialKey = "wood.ash-bat"
    /// Two-tone handle material key.
    public var handleWood: MaterialKey = "wood.maple-natural"
    /// Two-tone barrel material key.
    public var barrelWood: MaterialKey = "wood.maple-bat"
    /// Pine tar on the handle (0 = none, 1 = full band).
    public var pineTar: Float = 1
    public init() {}

    /// Radius along the bat (inches, from the knob end) for a pro 271-style turning.
    func profile() -> [(Float, Float)] {
        let s = length / (34 * Self.inch), rb = barrel / 2 / Self.inch
        let pts: [(Float, Float)] = [
            (0, 0), (0.55, 0), (0.74, 0.08), (0.8, 0.22), (0.76, 0.38), (0.6, 0.5), (0.5, 0.62), (0.47, 0.9),
            (0.465, 3), (0.47, 7), (0.49, 10), (0.53, 12.5), (0.6, 15), (0.72, 17.5), (0.88, 20), (1.04, 22.5),
            (rb * 0.94, 24.5), (rb * 0.99, 26.5), (rb, 29), (rb, 32.6), (rb * 0.985, 33.3), (rb * 0.94, 33.75),
            (rb * 0.84, 34), (rb * 0.66, 34), (rb * 0.6, 33.9), (rb * 0.4, 33.45), (0, 33.3),
        ]
        return pts.map { ($0.0 * Self.inch, $0.1 * Self.inch * s) }
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let prof = profile()
        func radius(at y: Float) -> Float {
            for i in 1..<prof.count where prof[i].1 >= y && prof[i - 1].1 <= y && prof[i].1 > prof[i - 1].1 {
                let t = (y - prof[i - 1].1) / (prof[i].1 - prof[i - 1].1)
                return lerp(prof[i - 1].0, prof[i].0, t)
            }
            return prof.last!.0
        }
        if twoTone {
            // Natural handle to 18 in, black lacquer barrel beyond.
            let split = 18 * Self.inch * length / (34 * Self.inch)
            let rs = radius(at: split)
            let lower = prof.filter { $0.1 < split } + [(rs, split), (0, split)]
            let upper = [(0, split), (rs, split)] + prof.filter { $0.1 > split }
            m.add(turned(lower, segments: 28, material: handleWood, seamTile: 0.12, grainVertical: true))
            m.add(turned(upper, segments: 28, material: barrelWood, seamTile: 0.12, grainVertical: true))
        } else {
            m.add(turned(prof, segments: 28, material: ash, seamTile: 0.12, grainVertical: true))
        }
        // Pine tar: a thin sleeve over the upper handle, pushed under the wood where the smear thins out,
        // so it reads as patchy hand-applied tar rather than a band.
        if pineTar > 0 {
            let y0 = 7.5 * Self.inch, y1 = y0 + 8 * Self.inch * pineTar
            let steps = 40
            var tar: [(Float, Float)] = []
            for k in 0...steps {
                let y = y0 + (y1 - y0) * Float(k) / Float(steps)
                tar.append((radius(at: y), y))
            }
            let p1 = rng.float(0...6.28), p2 = rng.float(0...6.28), p3 = rng.float(0...6.28)
            var sleeve = turned(tar, segments: 28, material: "tar.pine", seamTile: 0.12, grainVertical: true)
            sleeve.deform { p in
                let a = atan2(p.z, p.x), t = (p.y - y0) / (y1 - y0)
                let edge = min(t, 1 - t) * 6
                let n = 0.55 * sin(a * 2 + t * 9 + p1) + 0.35 * sin(a * 5 - t * 23 + p2) + 0.25 * sin(a * 3 + t * 41 + p3)
                let cover = n + min(1, edge) * 1.1 - 0.35
                let r = simd_length(V2(p.x, p.z))
                let off: Float = cover > 0 ? 0.00045 * min(1, cover * 3) : -0.0012
                let k = (r + off) / max(r, 1e-5)
                return V3(p.x * k, p.y, p.z * k)
            }
            m.add(sleeve)
        }
        // Lay it down: axis along +X, knob at -X; tilt so knob flare and barrel both touch the ground.
        let knobR = prof.map(\.0).prefix(6).max() ?? 0.02
        let tilt = atan2(barrel / 2 - knobR, length * 0.92)
        let lay = simd_quatf(angle: tilt, axis: V3(0, 0, 1)) * simd_quatf(degrees: -90, axis: V3(0, 0, 1))
        m = m.transformed(Xform(rotation: simd_quatf(degrees: rng.float(-4...4), axis: .up) * lay))
        let bb = m.bounds
        m = m.transformed(Xform(translation: V3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2)))
        groundAO(&m, height: 0.03, floor: 0.55)
        return LODModel(m)
    }
}
