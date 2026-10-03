import Testing
import simd
@testable import RealCore
@testable import RealLibrary
import RealMaterials

/// Signed volume of a closed surface (positive when triangles wind CCW seen from outside).
func signedVolume(_ s: Surface) -> Float {
    var v: Float = 0
    for t in stride(from: 0, to: s.indices.count, by: 3) {
        let a = s.positions[Int(s.indices[t])], b = s.positions[Int(s.indices[t + 1])], c = s.positions[Int(s.indices[t + 2])]
        v += simd_dot(a, simd_cross(b, c)) / 6
    }
    return v
}

@Suite struct Primitives {
    @Test func roundedBoxIsClosedAndOutward() {
        let s = Prim.roundedBox(V3(1, 0.5, 0.3), radius: 0.05, material: "x")
        #expect(signedVolume(s) > 0.14 && signedVolume(s) < 0.151)
    }
    @Test func latheOutward() {
        let s = Prim.lathe([V2(0, 0), V2(0.5, 0), V2(0.5, 1), V2(0, 1)], segments: 48, material: "x")
        #expect(abs(signedVolume(s) - .pi * 0.25) < 0.01)
    }
    @Test func cubeSphereOutward() {
        let s = Prim.cubeSphere(subdivisions: 12, material: "x") { $0 }
        #expect(abs(signedVolume(s) - 4 / 3 * .pi) < 0.05)
    }
    @Test func tubeOutward() {
        let s = Prim.tube([V3(0, 0, 0), V3(0, 1, 0), V3(0, 2, 0)], radii: [0.2, 0.2, 0.2], sides: 16, seamTile: 0.1, material: "x")
        // Open at the base, capped at the tip: volume is still positive when outward-facing.
        #expect(signedVolume(s) > 0)
    }
    @Test func tangentsOrthonormal() {
        var s = Prim.roundedBox(V3(1, 1, 1), radius: 0.1, material: "x")
        s.finalize()
        for (n, t) in zip(s.normals, s.tangents) {
            #expect(abs(simd_dot(n, V3(t.x, t.y, t.z))) < 1e-3)
            #expect(abs(simd_length(V3(t.x, t.y, t.z)) - 1) < 1e-3)
        }
    }
}

@Suite struct TreeTests {
    @Test func skeletonIsDeterministicAndLODsShareIt() {
        let g1 = TreeGenerator(species: .oak, seed: 3), g2 = TreeGenerator(species: .oak, seed: 3)
        #expect(g1.branches.count == g2.branches.count)
        #expect(g1.crownRadius == g2.crownRadius)
        let l0 = g1.model(.lod0), l2 = g1.model(.lod2)
        #expect(l2.triangleCount * 4 < l0.triangleCount)
    }
    @Test func windWeightsInRange() {
        let m = TreeGenerator(species: .birch, seed: 1).model()
        for s in m.surfaces { #expect(s.extra.allSatisfy { $0.x >= 0 && $0.x <= 1 }) }
        for s in m.surfaces { #expect(s.occlusion.allSatisfy { $0 >= 0 && $0 <= 1 }) }
    }
    @Test func windLayersAreHierarchical() {
        let g = TreeGenerator(species: .oak, seed: 2)
        let m = g.model()
        let bark = m.surfaces.first { $0.material == "bark.oak" }!, leaves = m.surfaces.first { $0.material == "leaf.oak" }!
        #expect(bark.extra.allSatisfy { $0.y >= 0 && $0.y < 3 }, "wood packs layer 0...2 + phase")
        #expect(leaves.extra.allSatisfy { $0.y >= 3 && $0.y < 4 }, "leaves pack layer 3 + phase")
        // Children start at their parent's weight at the junction, so weights never jump down the hierarchy.
        for b in g.branches where b.parent >= 0 {
            let p = g.branches[b.parent]
            #expect(b.wind[0] >= (p.wind.min() ?? 0) - 1e-4)
            #expect(b.wind.last! >= b.wind[0])
        }
        let trunkTop = g.branches[0].wind.max() ?? 1
        #expect(trunkTop < 0.2)
    }
    @Test func deadAndBrokenOptions() {
        let snag = TreeSpecies.oak.with { $0.leafDensity = 0; $0.brokenTop = 0.6; $0.levels[0].stubChance = 1 }
        let g = TreeGenerator(species: snag, seed: 4), full = TreeGenerator(species: .oak, seed: 4)
        #expect(g.branches[0].broken)
        #expect(g.branches[0].length < full.branches[0].length * 0.65)
        #expect(g.model().surfaces.allSatisfy { $0.material == "bark.oak" }, "leafless species has no leaf surface")
        // Stubs carry no children.
        for (i, b) in g.branches.enumerated() where b.broken && b.level >= 0 {
            #expect(!g.branches.contains { $0.parent == i })
        }
    }
    @Test func autumnSplitsLeafMaterial() {
        let sp = TreeSpecies.oak.with { $0.autumn = 0.5; $0.autumnLeaf = "leaf.maple" }
        let m = TreeGenerator(species: sp, seed: 1).model()
        let green = m.surfaces.first { $0.material == "leaf.oak" }?.triangleCount ?? 0
        let red = m.surfaces.first { $0.material == "leaf.maple" }?.triangleCount ?? 0
        #expect(green > 0 && red > 0)
        #expect(abs(Float(red) / Float(green + red) - 0.5) < 0.1)
    }
    @Test func twigBarkIsNotStretched() {
        // Every branch tube wraps whole bark tiles: U spans a multiple of barkTile around the circumference,
        // and V is scaled with it, so U and V texel density stay equal.
        let sp = TreeSpecies.birch
        let m = TreeGenerator(species: sp, seed: 3).model()
        let bark = m.surfaces.first { $0.material == sp.bark }!
        let maxU = bark.uvs.map(\.x).max() ?? 0
        let k = maxU / sp.barkTile
        #expect(abs(k - k.rounded()) < 1e-3)
    }
    @Test func rootsAndCollarsAddGeometry() {
        let base = TreeGenerator(species: .oak.with { $0.roots = 0; $0.collar = 0 }, seed: 5).model().triangleCount
        let full = TreeGenerator(species: .oak, seed: 5).model().triangleCount
        #expect(full > base)
        let bb = TreeGenerator(species: .oak, seed: 5).model().bounds
        #expect(bb.min.y > -0.4)
    }
}

@Suite struct ScatterTests {
    @Test func poissonRespectsSpacing() {
        let pts = Scatter.poisson(count: 200, outerRadius: 30, minSpacing: 2, seed: 1)
        for i in pts.indices { for j in pts.indices where j > i { #expect(simd_distance(pts[i], pts[j]) >= 2) } }
    }
}
