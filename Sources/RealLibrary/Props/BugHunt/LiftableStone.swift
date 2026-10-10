import simd
import Foundation

/// Flat field stone, 35 cm long and 8 cm thick, light enough to lift: weathered granite top with
/// lichen-grey speckle, a damp dark underside with soil clinging to it, rounded worn edges.
public struct LiftableStone: RealAsset {
    public static let id = "liftable-stone"
    public static let summary = "Flat field stone, 35 cm: weathered granite top, damp dark underside with clinging soil; handheld, liftable."
    public static let tags = ["prop", "rock", "stone", "outdoor", "handheld"]
    public static let budget = 6_000
    public static let preview = PreviewHint(azimuth: 30, elevation: 25, distance: 1.0)

    public var size = V3(0.35, 0.08, 0.26)
    public var top: MaterialKey = "rock.granite-bare"
    public var underside: MaterialKey = "rock.river-wet:4A4238"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, sub: 14), model(seed: seed, sub: 7)], switchDistances: [5])
    }

    func model(seed: UInt64, sub: Int) -> Model {
        var rng = SeededRNG(seed: seed)
        let sd = rng.float(0...40)
        let half = size * 0.5
        let rock = Prim.cubeSphere(subdivisions: sub, material: top) { d in
            // Slab: superellipse in plan, flat top and bottom with rounded rims, lumpy outline.
            let e: Float = 3.2
            let q = pow(pow(abs(d.x), e) + pow(abs(d.y), e) + pow(abs(d.z), e), 1 / e)
            var p = d / q
            let n = Noise.fbm(p * 2.2 + V3(sd, 0, 0), octaves: 4)
            let plan = 1 + 0.16 * n
            p.x *= half.x * plan; p.z *= half.z * plan
            p.y = p.y * half.y * (1 + 0.25 * Noise.fbm(p * 6 + V3(0, sd, 0), octaves: 2))
            if p.y < 0 { p.y *= 0.8 }
            return p + V3(0, half.y * 0.9, 0)
        }
        // Split faces: underside (normal down) gets the damp material.
        var upper = Surface(material: top), lower = Surface(material: underside)
        upper.positions = rock.positions; upper.normals = rock.normals; upper.uvs = rock.uvs; upper.tangents = rock.tangents
        upper.extra = rock.extra; upper.occlusion = rock.occlusion; upper.splat = rock.splat
        lower.positions = rock.positions; lower.normals = rock.normals; lower.uvs = rock.uvs; lower.tangents = rock.tangents
        lower.extra = rock.extra; lower.occlusion = rock.occlusion; lower.splat = rock.splat
        for t in stride(from: 0, to: rock.indices.count, by: 3) {
            let a = rock.indices[t], b = rock.indices[t + 1], c = rock.indices[t + 2]
            let ny = (rock.normals[Int(a)].y + rock.normals[Int(b)].y + rock.normals[Int(c)].y) / 3
            let y = (rock.positions[Int(a)].y + rock.positions[Int(b)].y + rock.positions[Int(c)].y) / 3
            if ny < -0.25 || y < size.y * 0.18 { lower.indices += [a, b, c] } else { upper.indices += [a, b, c] }
        }
        var m = Model(name: Self.id)
        m.add(upper); m.add(lower)
        if sub > 10 {
            var g = rng.fork(3)
            var soil = Surface(material: "ground.mud:3A2E22")
            for _ in 0..<14 {
                let q = V2(g.float(-0.6...0.6) * half.x, g.float(-0.6...0.6) * half.z)
                let s = g.float(0.006...0.016)
                let c = V3(q.x, 0.004, q.y)
                soil.append(Prim.cubeSphere(subdivisions: 2, material: soil.material) { c + $0 * V3(s, s * 0.35, s * 1.2) })
            }
            m.add(soil)
        }
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: size.y, floor: 0.55)
        return m
    }
}
