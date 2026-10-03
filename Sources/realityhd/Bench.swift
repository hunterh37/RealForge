import Foundation
import RealityKit
import RealCore
import RealMaterials
import RealKit
import RealLibrary

/// Release-mode timing: CPU generation, GPU texture synthesis, scene upload, scene stats.
@MainActor
func benchCommand() async throws {
    RealKitSetup.register()
    func ms(_ t: Date) -> String { String(format: "%6.1f ms", Date().timeIntervalSince(t) * 1000) }
    print("-- geometry generation (all LODs)")
    for t in Catalog.assets {
        let t0 = Date(); let m = t.init().build(seed: 1)
        print(pad(t.id), ms(t0), "tris", m.levels.map { "\($0.triangleCount)" }.joined(separator: "/"))
    }
    print("-- GPU texture synthesis (1024², full PBR set + mips)")
    guard let synth = TextureSynth.shared else { throw CLIError("Metal unavailable") }
    for k in ["bark.oak", "leaf.oak", "rock.granite", "ground.forest", "wood.oak", "metal.painted"] {
        let spec = MaterialLibrary.spec(for: k)
        _ = try synth.generate(spec, size: 256)
        let t0 = Date(); _ = try synth.generate(spec, size: 1024)
        print(pad(k), ms(t0))
    }
    print("-- texture disk cache (every material of every scene, at the current quality)")
    do {
        var keys = Set<MaterialKey>()
        for id in SceneCatalog.ids {
            let sc = SceneCatalog.build(id, seed: 1)!
            for lod in sc.fields.map(\.asset) + sc.singles.map(\.asset) { for m in lod.levels { keys.formUnion(m.materials) } }
            if let f = sc.farGround { keys.insert(f) }
        }
        let cache = RealMaterialCache.shared
        let specs = keys.sorted().map { cache.spec($0) }.filter { $0.program != nil }
        func pass(_ label: String) throws {
            cache.purge(); cache.waitForGPU()
            let t0 = Date()
            for s in specs { _ = try cache.textures(s) }
            cache.waitForGPU()
            print(pad(label, 22), ms(t0), "\(specs.count) materials, \(cache.textureBytes / 1_048_576)MB")
        }
        let was = RealTextureDiskCache.isEnabled
        RealTextureDiskCache.isEnabled = false
        try pass("synthesize (no cache)")
        RealTextureDiskCache.isEnabled = true
        RealTextureDiskCache.clear()
        try pass("synthesize + store")
        RealTextureDiskCache.flush()
        try pass("load from disk")
        print(pad("on disk", 22), "\(RealTextureDiskCache.bytesOnDisk / 1_048_576)MB in \(RealTextureDiskCache.directory.path)")
        RealTextureDiskCache.isEnabled = was
    }
    print("-- scenes (build + upload, cold materials)")
    for id in SceneCatalog.ids {
        RealMaterialCache.shared.purge()
        let t0 = Date()
        let scene = SceneCatalog.build(id, seed: 1)!
        let gen = ms(t0)
        let t1 = Date()
        let e = try await scene.entity()
        var models = 0, instanced = 0, instances = 0
        func walk(_ x: Entity) {
            if x.components.has(ModelComponent.self) { models += 1 }
            if let mi = x.components[MeshInstancesComponent.self], let p = mi[partIndex: 0] { instanced += 1; instances += p.data.instanceCount }
            x.children.forEach(walk)
        }
        walk(e)
        print(pad(id, 14), "gen", gen, "upload", ms(t1), "entities \(models) (instanced \(instanced), \(instances) instances)",
              "worst-case LOD0 tris \(scene.worstCaseTriangles / 1000)k", "tex \(RealMaterialCache.shared.textureBytes / 1_048_576)MB")
    }
}
