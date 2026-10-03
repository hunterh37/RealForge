import Testing
import Foundation
import simd
@testable import RealCore
@testable import RealLibrary
import RealMaterials

@Suite struct SceneTests {
    @Test(arguments: SceneCatalog.ids)
    func sceneContract(_ id: String) throws {
        let t = try #require(SceneCatalog.type(id))
        #expect(isKebab(id))
        #expect(!t.summary.contains("TODO") && t.summary.hasSuffix(".") && t.summary.count <= 200, "\(id): summary")
        for tag in t.tags { #expect(AssetTag.vocabulary.contains(tag) || AssetTag.sceneExtras.contains(tag), "\(id): tag '\(tag)' not in vocabulary") }
        let a = t.init().build(seed: 3), b = t.init().build(seed: 3)
        #expect(!(a.fields.isEmpty && a.singles.isEmpty), "\(id): empty scene")
        #expect(a.name == id)
        #expect(a.camera != nil, "\(id): set scene.camera so render and the demo frame it")
        #expect(a.fields.map { $0.transforms.count } == b.fields.map { $0.transforms.count }, "\(id): not deterministic")
        #expect(a.singles.count == b.singles.count, "\(id): not deterministic")
        #expect(a.worstCaseTriangles == b.worstCaseTriangles, "\(id): not deterministic")
        let models = a.singles.flatMap { $0.asset.levels } + a.fields.flatMap { $0.asset.levels }
        for m in models { for s in m.surfaces { #expect(MaterialLibrary.keys.contains(baseKey(s.material)), "\(id): unknown material \(s.material)") } }
        for f in a.fields { for m in f.transforms { #expect(m.columns.3.x.isFinite && m.columns.3.y.isFinite && m.columns.3.z.isFinite) } }
        #expect(exists("docs/scenes/\(id).png"), "\(id): missing docs/scenes/\(id).png, run `swift run -q realityhd thumbs \(id)`")
        #expect(swiftFiles(under: "Sources/RealLibrary/Scenes")[String(describing: t)] != nil, "\(id): expected Scenes/\(String(describing: t)).swift")
    }

    @Test func propYardShowsEveryProp() throws {
        let s = try #require(SceneCatalog.build("prop-yard"))
        #expect(s.singles.count == Props.all.count + 1)
    }
}
