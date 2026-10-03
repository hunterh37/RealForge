import simd
import Foundation

public extension TreeSpecies {
    /// Scots pine, ~17 m: tall clear bole, a few heavy limbs forming a flat-topped crown, needle tufts at
    /// the shoot tips. Pair with `ConiferBuild.splitBark` for the orange upper trunk.
    static let scotsPine = TreeSpecies(
        name: "scots-pine", bark: "bark.scots-pine", leaf: "leaf.pine", height: 17, trunkRadius: 0.28, trunkTipRatio: 0.1,
        trunkFraction: 0.68, trunkCurve: 10, trunkWobble: 0.012, flare: 0.22, flareLobes: 5,
        levels: [
            // Limbs from the top of the bole, rising and spreading.
            BranchLevel(density: 7, lengthRatio: 0.47, downAngle: 72, downAngleSpread: 14, curve: 34, gravity: 0.07, radiusRatio: 0.6, wobble: 0.08),
            // Side branches, near horizontal, tips turning up.
            BranchLevel(density: 1.5, span: 0.25...1, lengthRatio: 0.5, profile: .tapered, downAngle: 58, downAngleSpread: 16, curve: 24, gravity: 0.1, radiusRatio: 0.48, wobble: 0.06),
            // Shoots carrying the tufts.
            BranchLevel(density: 6.2, span: 0.6...1, lengthRatio: 0.3, downAngle: 50, downAngleSpread: 18, curve: 15, gravity: 0.16, radiusRatio: 0.5, wobble: 0.04),
        ],
        leaves: LeafParams(cardSize: V2(0.66, 0.76), density: 7, span: 0.15...1, crownNormalBlend: 0.5),
        barkTile: 0.5).woodLevels(1)

    /// Balsam fir, ~15 m: narrow cone with a spire top, dense horizontal branches in whorls of 5, flat sprays.
    static let fir = TreeSpecies(
        name: "fir", bark: "bark.fir", leaf: "leaf.fir", height: 15, trunkRadius: 0.2, trunkTipRatio: 0.03,
        trunkCurve: 1.5, trunkWobble: 0.005, flare: 0.22, flareLobes: 5,
        levels: [
            BranchLevel(density: 6.5, span: 0.04...0.985, lengthRatio: 0.24, profile: .conical, downAngle: 84, downAngleSpread: 6, curve: 8, gravity: 0.06, radiusRatio: 0.22, wobble: 0.02, whorl: 5),
            BranchLevel(density: 3.0, span: 0.12...0.95, lengthRatio: 0.38, downAngle: 60, downAngleSpread: 10, curve: 6, gravity: -0.04, radiusRatio: 0.45, wobble: 0.02),
        ],
        leaves: LeafParams(cardSize: V2(0.64, 0.74), density: 6, span: 0.0...1, crownNormalBlend: 0.45),
        leafLevels: [0, 1], barkTile: 0.4).woodLevels(0)

    /// Italian cypress, ~18 m: fastigiate column under 2 m wide, branches nearly parallel to the trunk.
    static let cypress = TreeSpecies(
        name: "cypress", bark: "bark.cypress", leaf: "leaf.cypress", height: 18, trunkRadius: 0.26, trunkTipRatio: 0.04,
        trunkCurve: 2, trunkWobble: 0.008, flare: 0.2, flareLobes: 6,
        levels: [
            BranchLevel(density: 6, span: 0.03...0.99, lengthRatio: 0.12, profile: .dome, downAngle: 20, downAngleSpread: 8, curve: 10, gravity: 0.12, radiusRatio: 0.22, wobble: 0.04),
            BranchLevel(density: 3.2, span: 0.1...1, lengthRatio: 0.55, downAngle: 32, downAngleSpread: 12, curve: 12, gravity: 0.08, radiusRatio: 0.5, wobble: 0.04),
        ],
        leaves: LeafParams(cardSize: V2(0.7, 0.85), density: 4.6, span: 0.0...1, crownNormalBlend: 0.8),
        leafLevels: [0, 1], barkTile: 0.35).woodLevels(0)

    /// European larch, ~20 m: open cone, level branches with hanging branchlets, soft light-green needle rosettes.
    static let larch = TreeSpecies(
        name: "larch", bark: "bark.larch", leaf: "leaf.larch", height: 20, trunkRadius: 0.26, trunkTipRatio: 0.03,
        trunkCurve: 3, trunkWobble: 0.008, flare: 0.25, flareLobes: 5,
        levels: [
            BranchLevel(density: 3.2, span: 0.18...0.98, lengthRatio: 0.3, profile: .conical, downAngle: 82, downAngleSpread: 10, curve: 22, gravity: 0.05, radiusRatio: 0.3, wobble: 0.04),
            BranchLevel(density: 3.6, span: 0.1...1, lengthRatio: 0.45, downAngle: 62, downAngleSpread: 14, curve: 18, gravity: -0.35, radiusRatio: 0.45, wobble: 0.04),
        ],
        leaves: LeafParams(cardSize: V2(0.5, 0.6), density: 6.5, span: 0.1...1, crownNormalBlend: 0.6),
        barkTile: 0.45).woodLevels(0)
}

extension TreeSpecies {
    /// Copy with `woodLevels` set (deepest branch level meshed as wood at LOD 0).
    func woodLevels(_ n: Int) -> TreeSpecies { var c = self; c.woodLevels = n; return c }
}

/// Shared steps for the conifer assets.
enum ConiferBuild {
    /// Three LODs from one skeleton, with an optional per-level edit.
    static func lods(_ species: TreeSpecies, seed: UInt64, distances: [Float] = [14, 40], edit: (inout Model, Int) -> Void = { _, _ in }) -> LODModel {
        let g = TreeGenerator(species: species, seed: seed)
        var levels = [g.model(.lod0), g.model(.lod1), g.model(.lod2)]
        for i in levels.indices { edit(&levels[i], i) }
        return LODModel(levels: levels, switchDistances: distances)
    }

    /// Splits a surface by triangle: triangles whose centroid passes `take` move to a new surface with `material`.
    static func split(_ s: Surface, material: MaterialKey, take: (V3) -> Bool) -> (keep: Surface, moved: Surface) {
        var a = Surface(material: s.material), b = Surface(material: material)
        var mapA = [Int](repeating: -1, count: s.positions.count), mapB = mapA
        let hasTan = s.tangents.count == s.positions.count
        func put(_ out: inout Surface, _ map: inout [Int], _ i: Int) -> UInt32 {
            if map[i] >= 0 { return UInt32(map[i]) }
            let n = out.add(s.positions[i], s.normals[i], s.uvs[i], extra: s.extra[i])
            out.occlusion[Int(n)] = s.occlusion[i]
            if hasTan { out.tangents.append(s.tangents[i]) }
            map[i] = Int(n)
            return n
        }
        for t in stride(from: 0, to: s.indices.count, by: 3) {
            let i0 = Int(s.indices[t]), i1 = Int(s.indices[t + 1]), i2 = Int(s.indices[t + 2])
            let c = (s.positions[i0] + s.positions[i1] + s.positions[i2]) / 3
            if take(c) { b.tri(put(&b, &mapB, i0), put(&b, &mapB, i1), put(&b, &mapB, i2)) }
            else { a.tri(put(&a, &mapA, i0), put(&a, &mapA, i1), put(&a, &mapA, i2)) }
        }
        return (a, b)
    }

    /// Replaces surface `material` in `m` with the two halves of `split`.
    static func splitSurface(_ m: inout Model, _ material: MaterialKey, into newMaterial: MaterialKey, take: (V3) -> Bool) {
        guard let i = m.surfaces.firstIndex(where: { $0.material == material }) else { return }
        let (keep, moved) = split(m.surfaces[i], material: newMaterial, take: take)
        m.surfaces.remove(at: i)
        if !keep.isEmpty { m.surfaces.insert(keep, at: i) }
        if !moved.isEmpty { m.surfaces.append(moved) }
    }

    /// Column and cone crowns: leaf normals and AO from a vertical envelope (max radius per height band)
    /// instead of a crown sphere. Outer cards face out and stay bright; inner cards darken.
    static func envelopeShade(_ m: inout Model, leaf: MaterialKey, blend: Float, up: Float = 0.25) {
        guard let i = m.surfaces.firstIndex(where: { $0.material == leaf }) else { return }
        var s = m.surfaces[i]
        guard let lo = s.positions.map(\.y).min(), let hi = s.positions.map(\.y).max(), hi > lo else { return }
        let bands = 24
        func band(_ y: Float) -> Int { min(bands - 1, max(0, Int((y - lo) / (hi - lo) * Float(bands)))) }
        var env = [Float](repeating: 0.05, count: bands)
        for p in s.positions { let b = band(p.y); env[b] = max(env[b], simd_length(V2(p.x, p.z))) }
        // Smooth the envelope so single long cards don't dominate a band.
        env = env.indices.map { k in (env[max(0, k - 1)] + env[k] * 2 + env[min(bands - 1, k + 1)]) / 4 }
        for v in s.positions.indices {
            let p = s.positions[v]
            let r = simd_length(V2(p.x, p.z)), e = max(env[band(p.y)], 0.05)
            let radial = r > 1e-4 ? V3(p.x / r, 0, p.z / r) : V3(1, 0, 0)
            let topness = smoothstep(0.8, 1.0, (p.y - lo) / (hi - lo))
            let outward = simd_normalize(radial + V3(0, up + topness * 1.5, 0))
            s.normals[v] = simd_normalize(lerp(s.normals[v], outward, blend))
            s.occlusion[v] = saturate(0.4 + 0.6 * smoothstep(0.15, 1.0, r / e)) * (0.75 + 0.25 * smoothstep(0, 2.5, p.y))
        }
        s.computeTangents()
        m.surfaces[i] = s
    }
}
