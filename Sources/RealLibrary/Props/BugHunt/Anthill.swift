import simd
import Foundation

/// Black garden ant mound, 25 cm across and 8 cm tall: crumbly excavated soil heaped around a
/// slightly off-centre entrance crater that drops into a dark tunnel, scattered with loose grains and
/// a few spoil pellets carried out by workers.
public struct Anthill: RealAsset {
    public static let id = "anthill"
    public static let summary = "Ant mound, 25 cm: crumbly soil heap with an off-centre entrance crater, dark tunnel and loose grains."
    public static let tags = ["prop", "ground", "outdoor", "garden"]
    public static let budget = 14_000
    public static let preview = PreviewHint(azimuth: 30, elevation: 35, distance: 1.0)

    /// Mound diameter and height in meters.
    public var diameter: Float = 0.25
    public var height: Float = 0.065
    public var soil: MaterialKey = "soil.ant-mound"
    public var grains: MaterialKey = "ground.dirt:8A7058"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [4])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        let R = diameter * 0.5, H = height
        let hole = V2(rng.float(-0.012...0.012), rng.float(-0.012...0.012))
        let sd = rng.float(0...50)
        let extent = diameter * 1.2
        func h(_ q: V2) -> Float {
            let r = simd_length(q)
            let n = Noise.fbm(V3(q.x * 30 + sd, 0, q.y * 30), octaves: 3)
            let fine = Noise.fbm(V3(q.x * 160, sd, q.y * 160), octaves: 2)
            var y = H * exp(-pow(r / (R * 0.85), 2) * 1.6) * (1 + 0.18 * n) + 0.004 * fine
            let rr = simd_length(q - hole)
            y -= 0.016 * exp(-pow(rr / 0.011, 2))                       // crater
            y += 0.004 * exp(-pow((rr - 0.016) / 0.006, 2))              // spoil lip
            let ang = atan2(q.y, q.x)
            let lobe = 1 + 0.12 * Noise.fbm(V3(cos(ang) * 2 + sd, sin(ang) * 2, 0), octaves: 3)
            let edge = smoothstep(extent * 0.47 * lobe, extent * 0.25 * lobe, simd_length(q))
            return max(0.0005, y) * edge - 0.002 * (1 - edge)
        }
        var m = Model(name: Self.id)
        // Heightfield clipped to a disc; the rim tucks just under the ground plane.
        let outer = extent * 0.5
        var mound = Prim.terrain(size: V2(extent, extent), segments: detail ? 64 : 26, material: soil) { q in
            simd_length(q) > outer * 0.97 ? -0.003 : h(q)
        }
        var keep: [UInt32] = []
        for t in stride(from: 0, to: mound.indices.count, by: 3) {
            let tri = mound.indices[t..<(t + 3)]
            if tri.allSatisfy({ let p = mound.positions[Int($0)]; return simd_length(V2(p.x, p.z)) <= outer * 1.001 }) { keep += tri }
        }
        mound.indices = keep
        m.add(mound)
        if detail {
            var g = rng.fork(2)
            var crumbs = Surface(material: grains)
            for _ in 0..<300 {
                let a = g.float(0...(2 * .pi)), r = R * 1.15 * sqrt(g.float())
                let q = V2(cos(a), sin(a)) * r
                let s = g.float(0.0006...0.0016)
                let c = V3(q.x, h(q) + s * 0.4, q.y)
                crumbs.append(Prim.cubeSphere(subdivisions: 1, material: grains) { c + $0 * V3(s, s * 0.7, s * g.float(0.8...1.2)) })
            }
            m.add(crumbs)
            var pel = Surface(material: "ground.mud:5A4632")
            for _ in 0..<40 {
                let q = hole + g.inDisc(radius: 0.04)
                let s = g.float(0.0015...0.003)
                let c = V3(q.x, h(q) + s * 0.5, q.y)
                pel.append(Prim.cubeSphere(subdivisions: 1, material: pel.material) { c + $0 * s })
            }
            m.add(pel)
            // Plant debris worked into the mound: twig bits and dry needles.
            var twigs = Surface(material: "bark.dead")
            for _ in 0..<26 {
                let q = g.inDisc(radius: R * 0.85)
                let a = g.float(0...(2 * .pi)), l = g.float(0.008...0.022)
                let c = V3(q.x, h(q) + 0.0006, q.y), d = V3(cos(a), g.float(-0.1...0.25), sin(a)) * l * 0.5
                twigs.append(Prim.tube([c - d, c + d], radii: [g.float(0.0005...0.0011), 0.0005], sides: 4, seamTile: 0.01, material: twigs.material, capEnd: true))
            }
            m.add(twigs)
            // A trail of workers heading for the entrance.
            var ants = Surface(material: "insect.chitin:221C18")
            for k in 0..<9 {
                let t = Float(k) / 9
                let ang = 0.6 + t * 0.9
                let q = hole + V2(cos(ang), sin(ang)) * (0.03 + 0.11 * t) + g.inDisc(radius: 0.004)
                let dir = simd_normalize(hole - q)
                let base = V3(q.x, h(q) + 0.0011, q.y)
                let fwd = V3(dir.x, 0, dir.y)
                for (off, r) in [(Float(0.0016), V3(0.0005, 0.00045, 0.0005)), (0.0006, V3(0.00032, 0.0003, 0.0006)), (-0.0008, V3(0.0006, 0.0005, 0.0008))] {
                    let c = base + fwd * off
                    let rot = simd_quatf(from: V3(0, 0, 1), to: fwd)
                    ants.append(Prim.cubeSphere(subdivisions: 2, material: ants.material) { c + rot.act($0 * r) })
                }
                for leg in 0..<3 { for sd: Float in [1, -1] {
                    let side = simd_normalize(simd_cross(fwd, V3(0, 1, 0))) * sd
                    let a0 = base + fwd * (0.0010 - Float(leg) * 0.0004)
                    ants.append(Prim.tube([a0, a0 + side * 0.0012 + fwd * (0.0006 - Float(leg) * 0.0006) - V3(0, 0.0009, 0)], radii: [0.00008, 0.00005], sides: 3, seamTile: 0.01, material: ants.material, capEnd: false))
                }}
            }
            m.add(ants)
        }
        groundAO(&m, height: H, floor: 0.6)
        // Tunnel throat: dark tube dropping from the crater floor.
        let top = V3(hole.x, h(hole) + 0.002, hole.y)
        m.add(Prim.tube([top, top + V3(0.002, -0.025, 0.003), top + V3(0.006, -0.045, 0.004)], radii: [0.0062, 0.0055, 0.004], sides: 12,
                        seamTile: 0.04, material: "ground.mud:1E1812", capEnd: true).flipped())
        m.add(Prim.cubeSphere(subdivisions: 2, material: "ground.mud:120E0A") { top + V3(0, -0.006, 0) + $0 * V3(0.0055, 0.002, 0.0055) })
        return m
    }
}
