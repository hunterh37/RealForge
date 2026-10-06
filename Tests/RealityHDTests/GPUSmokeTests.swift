import XCTest
import Metal
@testable import RealMaterials
@testable import RealKit
@testable import RealLibrary

/// Runs every GPU path the apps hit at scene load. Run on the visionOS simulator with
/// MTL_DEBUG_LAYER=1: the simulator lacks non-uniform threadgroups and writable sRGB.
@MainActor
final class GPUSmokeTests: XCTestCase {
    func testSkyAndEnvironment() throws {
        let synth = try TextureSynth()
        _ = try synth.skyTexture(SkyParams(sunDir: [0, 1, 0], width: 512, drawSun: true))
        _ = try RealityHD.environment(skybox: true)
        for b in SceneCatalog.all where b.id.contains("kitchen") || b.id.contains("cook") {
            _ = try RealityHD.environment(for: b.init().build(seed: 1), skybox: true)
        }
    }

    func testEveryMaterialGenerates() throws {
        let synth = try TextureSynth()
        for spec in MaterialLibrary.all where spec.program != nil { _ = try synth.generate(spec, size: 64) }
    }

    func testMaterialCacheLowLevelPath() throws {
        let cache = RealMaterialCache()
        for spec in MaterialLibrary.all where spec.program != nil {
            _ = try cache.textures(spec)
        }
    }
}
