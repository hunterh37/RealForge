import Testing
import Foundation
import simd
@testable import RealCore
@testable import RealLibrary
import RealMaterials

/// The rules every catalog asset must meet. Failure messages say what to fix.
@Suite struct AssetContractTests {
    @Test(arguments: Catalog.assets.map { $0.id })
    func metadata(_ id: String) throws {
        let t = try #require(Catalog.type(id))
        #expect(isKebab(id), "\(id): id must be kebab-case")
        #expect(!t.summary.contains("TODO") && t.summary.hasSuffix(".") && t.summary.count <= 160,
                "\(id): summary must be one finished sentence ending in '.', at most 160 chars")
        let kind = try #require(t.tags.first, "\(id): tags[0] must be the kind")
        #expect(AssetTag.kinds.contains(kind), "\(id): tags[0] '\(kind)' must be one of \(AssetTag.kinds)")
        for tag in t.tags { #expect(AssetTag.vocabulary.contains(tag), "\(id): tag '\(tag)' not in AssetTag.vocabulary (Core/Tags.swift)") }
        #expect(Set(t.tags).count == t.tags.count, "\(id): duplicate tags")
        #expect(registry[kind]?.contains { $0.id == id } == true, "\(id): kind '\(kind)' assets are listed in \(kindFolder[kind] ?? "?").all")
        #expect(t.budget <= budgetCap[kind] ?? 0, "\(id): budget \(t.budget) above the \(kind) cap \(budgetCap[kind] ?? 0)")
        #expect(!t.author.isEmpty && !t.author.contains(" "), "\(id): author is a handle without spaces")
    }

    @Test(arguments: Catalog.assets.map { $0.id })
    func geometry(_ id: String) throws {
        let t = try #require(Catalog.type(id))
        let a = t.init().build(seed: 7), b = t.init().build(seed: 7)
        #expect(a.levels.count == b.levels.count)
        for (x, y) in zip(a.levels, b.levels) {
            #expect(x.triangleCount == y.triangleCount, "\(id): build(seed:) is not deterministic")
            #expect(x.surfaces.first?.positions.first == y.surfaces.first?.positions.first, "\(id): build(seed:) is not deterministic")
        }
        let lod0 = a.levels[0]
        #expect(lod0.triangleCount > 0)
        #expect(lod0.triangleCount <= t.budget, "\(id) LOD0 \(lod0.triangleCount) tris > budget \(t.budget)")
        for i in 1..<a.levels.count { #expect(a.levels[i].triangleCount <= a.levels[i - 1].triangleCount, "\(id): LOD\(i) is heavier than LOD\(i - 1)") }
        #expect(a.switchDistances.count == a.levels.count - 1)
        for m in a.levels {
            for s in m.surfaces {
                #expect(s.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }, "\(id): non-finite position")
                #expect(s.indices.count % 3 == 0)
                #expect(s.indices.allSatisfy { Int($0) < s.positions.count })
                #expect(s.occlusion.allSatisfy { $0 >= 0 && $0 <= 1 }, "\(id): occlusion outside 0...1")
                #expect(MaterialLibrary.keys.contains(baseKey(s.material)), "\(id): unknown material \(s.material)")
            }
        }
        // Grounded at y = 0 (trees/rocks sink slightly) and centered on X/Z.
        let bb = lod0.bounds, c = (bb.min + bb.max) / 2, e = bb.max - bb.min
        if t.tags.contains("ceiling") {
            #expect(bb.min.y > -0.02 && bb.max.y > 2.2 && bb.max.y < 4.5, "\(id): ceiling mount top at y \(bb.max.y), expected a ceiling height")
        } else {
            #expect(bb.min.y > -0.6 && bb.min.y < 0.2, "\(id): base at y \(bb.min.y), expected ~0")
        }
        #expect(abs(c.x) <= e.x * 0.2 + 0.05 && abs(c.z) <= e.z * 0.2 + 0.05, "\(id): not centered on X/Z (center \(c.x), \(c.z))")
        // Other seeds build too.
        for seed: UInt64 in [1, 2, 99] { #expect(t.init().build(seed: seed).levels[0].triangleCount > 0) }
    }

    @Test(arguments: Catalog.assets.map { $0.id })
    func thumbnail(_ id: String) {
        #expect(exists("docs/assets/\(id).png"), "\(id): missing docs/assets/\(id).png, run `swift run -q realityhd thumbs \(id)`")
    }

    /// One asset per file, named after the type, under the kind's folder.
    @Test func sourceLayout() {
        let files = swiftFiles(under: "Sources/RealLibrary")
        for t in Catalog.assets {
            let name = String(describing: t), kind = t.tags.first ?? ""
            let path = files[name]
            #expect(path != nil, "\(t.id): expected a file named \(name).swift")
            if let path, let folder = kindFolder[kind] {
                #expect(path.hasPrefix("Sources/RealLibrary/\(folder)/"), "\(t.id): \(path) belongs under Sources/RealLibrary/\(folder)/<Theme>/")
            }
        }
    }

    @Test func idsUnique() {
        let ids = Catalog.assets.map { $0.id } + SceneCatalog.ids
        #expect(Set(ids).count == ids.count, "asset and scene ids share one namespace")
    }
}
