import simd
import Foundation

/// Round stone fire pit kit, 1.1 m outside diameter, 0.38 m tall: two courses of tapered split-face
/// concrete wedge blocks in running bond, a ring of cap stones, a 3 mm weathering-steel liner ring,
/// lava-rock floor, a soot-blackened inner face, and a burnt-down log fire with ash.
public struct StoneFirePit: RealAsset {
    public static let id = "stone-fire-pit"
    public static let summary = "Round stone fire pit, 1.1 m: two courses of tapered split-face wedge blocks, cap ring, Corten liner, lava-rock floor and charred logs in ash."
    public static let tags = ["prop", "garden", "outdoor", "landscaping", "stone", "camp"]
    public static let budget = 14_500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 30, distance: 1.0, studio: true)

    /// Outside diameter (m).
    public var diameter: Float = 1.1
    /// Number of block courses.
    public var courses: Int = 2
    /// Blocks per course.
    public var blocksPerCourse: Int = 12
    /// Block height and radial depth (m).
    public var blockHeight: Float = 0.14
    public var blockDepth: Float = 0.2
    /// Wall block material.
    public var block: MaterialKey = "stone.wall-block"
    /// Cap material.
    public var cap: MaterialKey = "stone.cap"
    /// Liner ring material.
    public var liner: MaterialKey = "metal.corten"
    /// Show the burnt-down fire.
    public var showFire = true
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id), lite = Model(name: Self.id + "-lite")
        let R = diameter / 2, r0 = R - blockDepth, n = max(6, blocksPerCourse)
        let gapA: Float = 0.006 / R
        func wedge(_ a0: Float, _ a1: Float, rIn: Float, rOut: Float, h: Float, key: MaterialKey, split: Bool, _ r: inout SeededRNG) -> Surface {
            // Wedge outline in XZ (as XY of the extrude), extruded along Y.
            var pts: [V2] = []
            let segs = 3
            for i in 0...segs { let a = a0 + (a1 - a0) * Float(i) / Float(segs); pts.append(V2(cos(a), sin(a)) * rOut) }
            for i in stride(from: segs, through: 0, by: -1) { let a = a0 + (a1 - a0) * Float(i) / Float(segs); pts.append(V2(cos(a), sin(a)) * rIn) }
            var s = Prim.extrude(Shape2D.rounded(pts, radius: 0.006, segments: 1), depth: h, bevel: split ? 0.006 : 0, bevelSegments: 1, material: key)
            s = s.transformed(Xform(translation: V3(0, h / 2, 0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            if split {
                let sd = UInt32(truncatingIfNeeded: r.int(0...100_000))
                s.displace { p, nrm in
                    let radial = V3(p.x, 0, p.z)
                    let out = simd_dot(nrm, simd_normalize(radial))
                    guard out > 0.6 else { return 0 }
                    return 0.008 * Noise.fbm(p * 22, octaves: 3, seed: sd) + 0.004
                }
            }
            return s
        }
        for c in 0..<max(1, courses) {
            let off = c % 2 == 0 ? 0 : Float.pi / Float(n)
            for i in 0..<n {
                var r = rng.fork(c * 100 + i)
                let a0 = off + Float(i) / Float(n) * 2 * .pi + gapA / 2, a1 = off + Float(i + 1) / Float(n) * 2 * .pi - gapA / 2
                let y = Float(c) * blockHeight
                let xf = Xform(translation: V3(0, y + r.float(0...0.0015), 0), rotation: simd_quatf(degrees: r.float(-0.3...0.3), axis: .up))
                m.add(wedge(a0, a1, rIn: r0, rOut: R, h: blockHeight - 0.003, key: block, split: true, &r), xf)
                lite.add(wedge(a0, a1, rIn: r0, rOut: R, h: blockHeight - 0.003, key: block, split: false, &r), xf)
            }
        }
        // Cap ring: overhangs 2.5 cm out and in.
        let capY = Float(max(1, courses)) * blockHeight
        let nc = n - 2
        for i in 0..<nc {
            var r = rng.fork(500 + i)
            let a0 = Float(i) / Float(nc) * 2 * .pi + gapA / 2 + 0.1, a1 = Float(i + 1) / Float(nc) * 2 * .pi - gapA / 2 + 0.1
            let s = wedge(a0, a1, rIn: r0 - 0.02, rOut: R + 0.025, h: 0.05, key: cap, split: false, &r)
            m.add(s, Xform(translation: V3(0, capY + 0.002, 0))); lite.add(s, Xform(translation: V3(0, capY + 0.002, 0)))
        }
        // Liner ring inside the blocks, with a rolled lip resting on the cap.
        let lr = r0 - 0.008, lh = capY + 0.03
        let ring = Prim.lathe([V2(lr, 0.0), V2(lr + 0.003, 0.0), V2(lr + 0.003, lh - 0.01), V2(lr + 0.025, lh - 0.004), V2(lr + 0.026, lh),
                               V2(lr + 0.02, lh + 0.002), V2(lr, lh - 0.006), V2(lr, 0.0)], segments: 64, seamTile: 0.5, material: liner)
        m.add(ring); lite.add(ring)
        // Lava-rock floor and ash bed.
        let sd = UInt32(truncatingIfNeeded: rng.int(0...100_000))
        let floor = Prim.terrain(size: V2(lr * 2, lr * 2), segments: 28, material: "ground.gravel:3A3230") { xz in
            let d = simd_length(xz) / lr
            return d > 0.99 ? 0.03 : 0.05 - 0.02 * d * d + 0.008 * Noise.fbm(V3(xz.x * 14, 0, xz.y * 14), seed: sd)
        }
        var floorM = floor
        floorM.deform { p in
            let l = simd_length(V2(p.x, p.z)); let k = l > lr - 0.004 ? (lr - 0.004) / l : 1
            return V3(p.x * k, p.y, p.z * k)
        }
        m.add(floorM); lite.add(floorM)
        if showFire {
            let ash = Prim.superellipsoid(V3(0.42, 0.04, 0.38), exponent: 2.2, subdivisions: 6, material: "wood.ash")
            m.add(ash, Xform(translation: V3(0, 0.055, 0)))
            // Burnt-down pile: two long logs crossed, three short charred ends, embers in the gaps.
            let specs: [(Float, Float, Float, Float)] = [(0.3, 0.42, 0.045, 0.08), (2.0, 0.38, 0.04, 0.1), (3.6, 0.22, 0.035, 0.07), (4.6, 0.18, 0.03, 0.065), (5.5, 0.2, 0.032, 0.07)]
            for (k, sp) in specs.enumerated() {
                var r = rng.fork(800 + k)
                let a = sp.0 + r.float(-0.25...0.25)
                let dir = V3(cos(a), 0, sin(a))
                let side = V3(-dir.z, 0, dir.x) * r.float(-0.08...0.08)
                let a0 = side - dir * sp.1 * 0.5 + V3(0, sp.3, 0)
                let a1 = side + dir * sp.1 * 0.5 + V3(0, sp.3 - r.float(0.0...0.03), 0)
                let rad = sp.2
                let pts = [a0, (a0 + a1) / 2 + V3(0, 0.004, 0), a1]
                var log = Prim.tube(pts, radii: [rad * 0.6, rad, rad * 0.8], sides: 10, seamTile: 0.2, material: "wood.charred")
                log.displace { p, _ in 0.004 * Noise.ridged(p * 30, octaves: 2, seed: UInt32(k)) }
                m.add(log)
                if k < 3 { m.add(Prim.superellipsoid(V3(0.05, 0.025, 0.04), exponent: 2.5, subdivisions: 3, material: "emissive.ember"), Xform(translation: a1 - V3(0, rad * 0.6, 0))) }
            }
        }
        // Soot on the inner cap edge comes from cavity AO; settle the whole kit.
        let bb = m.bounds
        let shift = V3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2)
        m = m.transformed(Xform(translation: shift)); lite = lite.transformed(Xform(translation: shift))
        groundAO(&m, height: 0.15, floor: 0.55); groundAO(&lite, height: 0.15, floor: 0.55)
        return LODModel(levels: [m, lite], switchDistances: [10])
    }
}
