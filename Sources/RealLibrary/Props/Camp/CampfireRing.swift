import simd
import Foundation

/// Campfire ring, about 1 m across: 11 to 13 river stones sooted on the inside, a mounded ash bed,
/// four half-burnt logs laid like spokes toward the center with charred, alligatored wood and glowing tips,
/// and scattered embers. 2 LODs.
public struct CampfireRing: RealAsset {
    public static let id = "campfire-ring"
    public static let summary = "Campfire ring, 1 m: sooted stones, ash bed, half-burnt logs with charred alligator checks and glowing tips, embers."
    public static let tags = ["prop", "camp", "stone", "wood", "light"]
    public static let budget = 10_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 32, distance: 1.05)

    /// Ring radius to the stone centers, meters.
    public var radius: Float = 0.45
    public var stones = 12
    public var logs = 4
    /// Number of glowing ember chunks; 0 for a cold fire pit.
    public var embers = 16
    public var stone: MaterialKey = "rock.river"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let R = rng.vary(radius, 0.08)
        let n = max(6, stones + rng.int(-1...1))
        struct StoneP { var a: Float; var size: V3; var yaw: Float; var seed: UInt64 }
        let stoneP = (0..<n).map { i -> StoneP in
            let s = rng.float(0.17...0.26)
            return StoneP(a: Float(i) / Float(n) * 2 * .pi + rng.float(-0.1...0.1),
                          size: V3(s * 1.2, s * rng.float(0.65...0.9), s), yaw: rng.float(0...360), seed: rng.next())
        }
        struct LogP { var a: Float; var len: Float; var r: Float; var spin: Float; var seed: UInt64 }
        let logP = (0..<logs).map { i -> LogP in
            LogP(a: Float(i) / Float(max(logs, 1)) * 2 * .pi + rng.float(-0.35...0.35), len: rng.float(0.42...0.58), r: rng.float(0.035...0.055),
                 spin: rng.float(0...6), seed: rng.next())
        }
        struct Ember { var p: V3; var r: Float; var hot: Bool; var seed: UInt32 }
        let emberP = (0..<embers).map { _ -> Ember in
            let d = rng.inDisc(radius: R * 0.45)
            return Ember(p: V3(d.x, 0.035, d.y), r: rng.float(0.01...0.024), hot: rng.chance(0.55), seed: UInt32(truncatingIfNeeded: rng.next()))
        }
        func lod(_ detail: Int) -> Model {
            var m = Model(name: Self.id)
            // Stones, sooted where they face the fire.
            for s in stoneP {
                var b = Boulder().with { $0.size = s.size; $0.facets = 4; $0.roughness = 0.14; $0.detail = [detail >= 1 ? 6 : 3]; $0.material = stone }
                    .build(seed: s.seed).levels[0]
                let c = V3(cos(s.a) * R, 0, sin(s.a) * R)
                b = b.transformed(Xform(translation: c, rotation: simd_quatf(degrees: s.yaw, axis: .up)))
                for i in b.surfaces.indices {
                    for v in b.surfaces[i].positions.indices {
                        let p = b.surfaces[i].positions[v], nn = b.surfaces[i].normals[v]
                        let toCenter = simd_normalize(V3(-p.x, 0, -p.z))
                        let facing = max(0, simd_dot(nn, toCenter))
                        let near = 1 - smoothstep(R * 0.7, R * 1.15, simd_length(V2(p.x, p.z)))
                        b.surfaces[i].occlusion[v] *= 1 - 0.75 * facing * near
                    }
                }
                m.add(b)
            }
            // Ash bed: low mound inside the ring.
            let ashR = R * 0.82
            let prof: [V2] = [V2(ashR * 1.08, -0.02), V2(ashR, 0.004), V2(ashR * 0.7, 0.018), V2(ashR * 0.35, 0.03), V2(0, 0.035)]
            var ash = Prim.lathe(prof, segments: detail >= 1 ? 40 : 16, seamTile: 0.5, material: "wood.ash")
            ash.uvs = ash.positions.map { V2($0.x, -$0.z) }
            ash.computeTangents()
            ash.occlusion = ash.positions.map { 0.75 + 0.25 * smoothstep(ashR, ashR * 0.4, simd_length(V2($0.x, $0.z))) }
            m.add(ash)
            // Half-burnt logs: outer end still barked, inner part charred and tapering to a glowing tip.
            for l in logP {
                let dir = V3(cos(l.a), 0, sin(l.a))
                let outer = dir * (R * 0.95) + V3(0, l.r + 0.03, 0)
                let inner = dir * max(R * 0.95 - l.len, 0.07 + l.r) + V3(0, l.r + 0.11, 0)
                let sides = detail >= 1 ? 10 : 6
                let mid = outer + (inner - outer) * 0.28
                let barkPath = [outer, mid]
                m.add(Prim.tube(barkPath, radii: [l.r, l.r * 0.98], sides: sides, seamTile: 0.5, material: "bark.oak-dry", capEnd: false))
                let steps = detail >= 1 ? 6 : 3
                var charPath: [V3] = [], charR: [Float] = []
                for i in 0...steps {
                    let t = Float(i) / Float(steps)
                    charPath.append(mid + (inner - mid) * t * 0.9); charR.append(l.r * (0.98 - 0.45 * t * t))
                }
                var charred = Prim.tube(charPath, radii: charR, sides: sides, seamTile: 0.3, material: "wood.charred", capEnd: false)
                charred.uvs = charred.uvs.map { $0 * 2 }   // finer checks on thin logs
                m.add(charred)
                let glowPath = [charPath[charPath.count - 1], inner]
                m.add(Prim.tube(glowPath, radii: [charR[charR.count - 1], charR[charR.count - 1] * 0.6], sides: sides, seamTile: 0.3, material: "emissive.ember"))
                // Sawn outer end.
                let ax = simd_normalize(outer - mid), e1 = simd_normalize(simd_cross(ax, .up)), e2 = simd_cross(e1, ax)
                let ring = (0..<sides).map { k -> V3 in let a = Float(k) / Float(sides) * 2 * .pi; return outer + (e1 * cos(a) + e2 * sin(a)) * l.r }
                m.add(WoodParts.cap(ring, normal: ax, pith: outer, e1: e1, e2: e2, radius: l.r, spin: l.spin, material: "wood.endgrain"))
            }
            // Embers: lumpy coals half sunk in the ash, most still glowing.
            for e in emberP {
                let sub = detail >= 1 ? 2 : 1
                let ns = e.seed
                let coal = Prim.cubeSphere(subdivisions: sub, material: e.hot ? "emissive.ember" : "wood.charred") { d in
                    d * e.r * (1 + 0.3 * Noise.perlin(d * 2.5, seed: ns)) * V3(1.2, 0.55, 1)
                }
                m.add(coal, Xform(translation: e.p, rotation: simd_quatf(degrees: Float(ns % 360), axis: .up)))
            }
            for i in m.surfaces.indices where m.surfaces[i].tangents.count != m.surfaces[i].positions.count { m.surfaces[i].computeTangents() }
            return m
        }
        return LODModel(levels: [lod(1), lod(0)], switchDistances: [12])
    }
}
