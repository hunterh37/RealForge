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

@Suite struct CatalogTests {
    @Test(arguments: Catalog.assets.map { $0.id })
    func assetIsValid(_ id: String) throws {
        let t = try #require(Catalog.type(id))
        let a = t.init().build(seed: 7), b = t.init().build(seed: 7)
        // Deterministic.
        #expect(a.levels.count == b.levels.count)
        for (x, y) in zip(a.levels, b.levels) {
            #expect(x.triangleCount == y.triangleCount)
            #expect(x.surfaces.first?.positions.first == y.surfaces.first?.positions.first)
        }
        let lod0 = a.levels[0]
        #expect(lod0.triangleCount > 0)
        #expect(lod0.triangleCount <= t.budget, "\(id) LOD0 \(lod0.triangleCount) > budget \(t.budget)")
        // LODs get cheaper.
        for i in 1..<a.levels.count { #expect(a.levels[i].triangleCount <= a.levels[i - 1].triangleCount) }
        #expect(a.switchDistances.count == a.levels.count - 1)
        for m in a.levels {
            for s in m.surfaces {
                #expect(s.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
                #expect(s.indices.allSatisfy { Int($0) < s.positions.count })
                // Every material key resolves to a built-in spec.
                let base = String(s.material.split(separator: ":")[0])
                #expect(MaterialLibrary.keys.contains(base) || base == "metal.painted", "unknown material \(s.material)")
            }
        }
        // Grounded: base near y = 0 (trees/rocks sink slightly), centered on X/Z.
        let bb = lod0.bounds
        #expect(bb.min.y > -0.6 && bb.min.y < 0.2, "\(id) min.y \(bb.min.y)")
    }

    @Test func idsUnique() {
        let ids = Catalog.assets.map { $0.id }
        #expect(Set(ids).count == ids.count)
    }

    @Test func scenesBuild() {
        for id in SceneCatalog.ids {
            let s = SceneCatalog.build(id, seed: 1)
            #expect(s != nil)
            #expect(!(s!.fields.isEmpty && s!.singles.isEmpty))
        }
    }
}

@Suite struct Materials {
    @Test func everyKeyHasProgramOrScalars() {
        for k in MaterialLibrary.keys {
            let s = MaterialLibrary.spec(for: k)
            #expect(s.key == k)
            if s.mode == .cutout { #expect(s.program != nil && s.twoSided) }
        }
    }
    @Test func tintSuffixParses() {
        let s = MaterialLibrary.spec(for: "metal.painted:FF0000")
        #expect(s.colorA.x > 0.9 && s.colorA.y < 0.01)
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
}

@Suite struct ScatterTests {
    @Test func poissonRespectsSpacing() {
        let pts = Scatter.poisson(count: 200, outerRadius: 30, minSpacing: 2, seed: 1)
        for i in pts.indices { for j in pts.indices where j > i { #expect(simd_distance(pts[i], pts[j]) >= 2) } }
    }
}
