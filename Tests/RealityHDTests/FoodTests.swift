import Testing
import Foundation
import simd
@testable import RealCore
@testable import RealLibrary
import RealMaterials

/// Food assets are cut at runtime: every LOD0 surface must be a closed, consistently wound manifold.
@Suite struct FoodTests {
    static let foods: [any RealFood.Type] = Catalog.assets.compactMap { $0 as? any RealFood.Type }

    /// Welds positions within 1e-5 m and returns triangles as welded index triples.
    static func welded(_ s: Surface) -> [SIMD3<Int>] {
        var ids: [SIMD3<Int64>: Int] = [:]
        let map = s.positions.map { p -> Int in
            let q: SIMD3<Float> = (p / 1e-5).rounded(.toNearestOrAwayFromZero)
            let k = SIMD3<Int64>(Int64(q.x), Int64(q.y), Int64(q.z))
            if let i = ids[k] { return i }
            ids[k] = ids.count
            return ids.count - 1
        }
        var out: [SIMD3<Int>] = []
        for t in stride(from: 0, to: s.indices.count, by: 3) {
            let a: Int = map[Int(s.indices[t])], b: Int = map[Int(s.indices[t + 1])], c: Int = map[Int(s.indices[t + 2])]
            out.append(SIMD3<Int>(a, b, c))
        }
        return out
    }

    /// Problems with a surface's closure: open/non-manifold edges, flipped neighbors, degenerate triangles.
    static func closureProblems(_ s: Surface) -> [String] {
        var undirected: [SIMD2<Int>: Int] = [:], directed: [SIMD2<Int>: Int] = [:]
        var problems: [String] = []
        var degenerate = 0
        for t in welded(s) {
            if t.x == t.y || t.y == t.z || t.x == t.z { degenerate += 1; continue }
            for (a, b) in [(t.x, t.y), (t.y, t.z), (t.z, t.x)] {
                undirected[SIMD2(min(a, b), max(a, b)), default: 0] += 1
                directed[SIMD2(a, b), default: 0] += 1
            }
        }
        if degenerate > 0 { problems.append("\(degenerate) degenerate triangles") }
        let open = undirected.values.filter { $0 != 2 }.count
        if open > 0 { problems.append("\(open) edges not shared by exactly two triangles") }
        let flipped = directed.values.filter { $0 != 1 }.count
        if flipped > 0 { problems.append("\(flipped) directed edges repeated (inconsistent winding)") }
        return problems
    }

    static func signedVolume(_ s: Surface) -> Float {
        var v: Float = 0
        for t in stride(from: 0, to: s.indices.count, by: 3) {
            let a = s.positions[Int(s.indices[t])], b = s.positions[Int(s.indices[t + 1])], c = s.positions[Int(s.indices[t + 2])]
            v += simd_dot(a, simd_cross(b, c)) / 6
        }
        return v
    }

    @Test func foodsRegistered() {
        #expect(Self.foods.count >= 12, "expected the food set in Props/Food, found \(Self.foods.map { $0.id })")
    }

    @Test(arguments: foods.map { $0.id })
    func closedShells(_ id: String) throws {
        let t = try #require(Catalog.type(id) as? any RealFood.Type)
        for seed: UInt64 in [1, 7] {
            let lod = t.init().build(seed: seed)
            #expect(lod.levels.count == 1, "\(id): food assets ship a single LOD")
            for s in lod.levels[0].surfaces {
                let problems = Self.closureProblems(s)
                #expect(problems.isEmpty, "\(id) seed \(seed) \(s.material): \(problems.joined(separator: ", "))")
                #expect(Self.signedVolume(s) > 0, "\(id) \(s.material): shell winds inward")
            }
        }
    }

    @Test(arguments: foods.map { $0.id })
    func contract(_ id: String) throws {
        let t = try #require(Catalog.type(id) as? any RealFood.Type)
        for tag in ["prop", "food", "kitchen", "handheld"] { #expect(t.tags.contains(tag), "\(id): missing tag \(tag)") }
        let food = t.init()
        let lod = food.build(seed: 1)
        let bb = lod.levels[0].bounds
        let c = food.coreCenter
        #expect(c.x >= bb.min.x && c.x <= bb.max.x && c.y >= bb.min.y && c.y <= bb.max.y && c.z >= bb.min.z && c.z <= bb.max.z,
                "\(id): coreCenter \(c) outside the bounds")
        #expect(lod.levels[0].triangleCount >= 1000 && lod.levels[0].triangleCount <= 8000, "\(id): \(lod.levels[0].triangleCount) tris outside 1k-8k")
        for s in lod.levels[0].surfaces {
            if let cap = food.capMaterial(for: s.material) {
                #expect(MaterialLibrary.keys.contains(baseKey(cap)), "\(id): cap material \(cap) unknown")
            }
            let spec = MaterialLibrary.spec(for: s.material)
            if let cooked = spec.cooked { #expect(MaterialLibrary.keys.contains(cooked), "\(id): cooked \(cooked) unknown") }
        }
    }

    @Test func cookedKeysResolve() {
        for spec in MaterialLibrary.all where spec.key.hasPrefix("food.") {
            if let cooked = spec.cooked {
                #expect(MaterialLibrary.keys.contains(cooked), "\(spec.key): cooked key \(cooked) missing")
            }
        }
    }

    @Test func meshBuildersAreClosed() {
        let shells: [Surface] = [
            FoodMesh.revolve(edge: 0.004, material: "x") { t in V2(0.04 * sin(t * .pi), -0.04 * cos(t * .pi)) },
            FoodMesh.tube([V3(0, 0, 0), V3(0.01, 0.02, 0), V3(0.0, 0.05, 0.01)], radii: [0.004, 0.003, 0.002], sides: 8, material: "x"),
            FoodMesh.box(V3(0.12, 0.03, 0.06), radius: 0.003, edge: 0.006, extra: [[0.01], [], [0.0]], material: "x"),
            FoodMesh.sections(edge: 0.005, length: 0.1, material: "x") { s in (0.03 * sin(s * .pi), 0.01 * sin(s * .pi), 2.5, .zero) },
            FoodMesh.hollow(FoodMesh.revolve(edge: 0.004, material: "x") { t in V2(0.04 * sin(t * .pi), -0.04 * cos(t * .pi)) }, wall: 0.005),
        ]
        for s in shells {
            #expect(Self.closureProblems(s).isEmpty, "\(Self.closureProblems(s))")
            #expect(Self.signedVolume(s) > 0)
        }
    }
}
