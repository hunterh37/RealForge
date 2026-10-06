import simd
import Foundation

/// Rolled turf sod, 0.6 m wide, ~0.32 m roll diameter: a 1.5 m strip of 2.5 cm soil-and-root mat with
/// soil outside and mown grass rolled inside, the loose end grass-up unrolled on the ground. Torn, fibrous edges
/// on the strip sides; a few crumbs of soil fall off.
public struct SodRoll: RealAsset {
    public static let id = "sod-roll"
    public static let summary = "Rolled turf sod, 0.6 m wide: 2.5 cm soil-and-root mat rolled grass-in to a ~0.3 m roll with its loose end unrolled on the ground."
    public static let tags = ["prop", "garden", "outdoor", "landscaping", "grass", "ground"]
    public static let budget = 14_800
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 34, elevation: 26, distance: 1.0, studio: true)

    /// Strip width along X (m).
    public var width: Float = 0.6
    /// Mat thickness (m).
    public var thickness: Float = 0.025
    /// Rolled turns.
    public var turns: Float = 2.6
    /// Unrolled tail length on the ground (m).
    public var tail: Float = 0.35
    /// Grass-side material.
    public var grass: MaterialKey = "grass.lawn-thatch"
    /// Standing blades over the tail.
    public var bladeCount: Int = 420
    /// Standing grass blade material.
    public var blades: MaterialKey = "plant.stem:4E8A2C"
    /// Soil-side material.
    public var soil: MaterialKey = "soil.sod"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let th = thickness, r0: Float = 0.035
        let pitch = th * 1.02
        // Spiral path in the YZ plane (roll axis along X), from the core out, then flat tail along +Z.
        func spiral(per: Int) -> [V3] {
            var pts: [V3] = []
            let steps = Int(turns * Float(per))
            let maxR = r0 + pitch * turns
            for k in 0...steps {
                let t = Float(k) / Float(per)
                let a = t * 2 * .pi
                let r = r0 + pitch * t
                // Angle measured so the outer end exits at the bottom heading +Z.
                let ang = a - turns * 2 * .pi
                pts.append(V3(0, maxR + th / 2 - r * cos(ang), -r * sin(ang) * -1))
            }
            let last = pts[pts.count - 1]
            let segs = max(2, Int(tail / 0.05))
            for k in 1...segs { pts.append(last + V3(0, 0, tail * Float(k) / Float(segs))) }
            return pts
        }
        func strip(per: Int, lite: Bool) -> [Surface] {
            let path = spiral(per: per)
            var r = rng.fork(lite ? 2 : 1)
            let hw = width / 2
            let edgeN = lite ? 2 : 6
            // Mat profile in sweep frame: x follows `up` (radial / thickness), y across width.
            func profile(_ a: Float, _ b: Float) -> [V2] {
                var p: [V2] = []
                for k in 0...edgeN { p.append(V2(a + (b - a) * Float(k) / Float(edgeN), -hw + (k == 0 || k == edgeN ? 0 : r.float(-0.006...0.006)))) }
                for k in 0...edgeN { p.append(V2(b - (b - a) * Float(k) / Float(edgeN), hw + (k == 0 || k == edgeN ? 0 : r.float(-0.006...0.006)))) }
                return p
            }
            // Grass layer on the inner face (rolled grass-in), thicker soil layer outside.
            let soilS = Prim.sweep(profile(-th * 0.25, th / 2), along: path, up: V3(0, 1, 0), material: soil)
            let grassS = Prim.sweep(profile(-th / 2, -th * 0.25 + 0.001), along: path, up: V3(0, 1, 0), material: grass)
            return [soilS, grassS]
        }
        var m = Model(name: Self.id), lite = Model(name: Self.id + "-lite")
        for s in strip(per: 40, lite: false) { m.add(s) }
        for s in strip(per: 14, lite: true) { lite.add(s) }
        // Root fibres hanging from the cut edges of the tail.
        let pathEnd = spiral(per: 40)
        let tailStart = pathEnd[pathEnd.count - 1 - max(2, Int(tail / 0.05))]
        for k in 0..<36 {
            var r = rng.fork(200 + k)
            let sx: Float = r.chance(0.5) ? -1 : 1
            let z = tailStart.z + r.float(0.02...tail)
            let base = V3(sx * (width / 2 - 0.002), r.float(0.004...th * 0.6), z)
            let tip = base + V3(sx * r.float(0.008...0.025), -base.y + 0.001, r.float(-0.01...0.01))
            m.add(Prim.tube([base, (base + tip) / 2 + V3(sx * 0.004, 0.002, 0), tip], radii: [0.0012, 0.0009, 0.0005], sides: 4, seamTile: 0.02, material: "plant.stem:8A7A5A"))
        }
        // Grass blades standing up out of the thatch along the unrolled tail.
        for k in 0..<bladeCount {
            var r = rng.fork(300 + k)
            let x = r.float(-width / 2 + 0.01...width / 2 - 0.01)
            let z = tailStart.z + r.float(0.01...tail - 0.01)
            let base = V3(x, th - 0.001, z)
            let hgt = r.float(0.012...0.03)
            let lean = V3(r.float(-0.006...0.006), 0, r.float(-0.006...0.006))
            m.add(Prim.tube([base, base + V3(0, hgt * 0.6, 0) + lean * 0.4, base + V3(0, hgt, 0) + lean], radii: [0.0013, 0.0009, 0.0002], sides: 3, seamTile: 0.02, material: r.chance(0.3) ? "plant.stem:7A9A3C" : blades))
        }
        // Cut end of the tail: dark soil-and-root layer showing on the edge face.
        let endZ = pathEnd[pathEnd.count - 1].z
        m.add(Prim.roundedBox(V3(width - 0.004, th * 0.7, 0.004), radius: 0.0015, bevelSegments: 1, material: "soil.sod:2A1E14"),
              Xform(translation: V3(0, th * 0.4, endZ + 0.001)))
        for k in 0..<24 {
            var r = rng.fork(900 + k)
            let b0 = V3(r.float(-width / 2...width / 2), r.float(0.003...th * 0.6), endZ + 0.002)
            let tip = b0 + V3(r.float(-0.01...0.01), -b0.y + 0.001, r.float(0.01...0.03))
            m.add(Prim.tube([b0, (b0 + tip) / 2 + V3(0, 0.002, 0.004), tip], radii: [0.0012, 0.0009, 0.0005], sides: 4, seamTile: 0.02, material: "plant.stem:8A7A5A"))
        }
        // Soil crumbs fallen beside the roll.
        for k in 0..<10 {
            var r = rng.fork(50 + k)
            let p = V3(r.float(-0.38...0.38), 0.006, r.float(-0.1...0.3))
            guard abs(p.x) > width / 2 + 0.01 || p.z > 0.2 else { continue }
            m.add(Prim.superellipsoid(V3(r.float(0.012...0.025), 0.012, r.float(0.012...0.022)), exponent: 2.5, subdivisions: 2, material: soil), Xform(translation: p))
        }
        let bb = m.bounds
        let shift = V3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2)
        m = m.transformed(Xform(translation: shift)); lite = lite.transformed(Xform(translation: shift))
        groundAO(&m, height: 0.08, floor: 0.6); groundAO(&lite, height: 0.08, floor: 0.6)
        return LODModel(levels: [m, lite], switchDistances: [10])
    }
}
