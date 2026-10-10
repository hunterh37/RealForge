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

    /// Overcast greys the sky (blue/red ratio falls toward 1), stays finite, and removes the sun disk.
    func testOvercastSkyIsGreyAndFinite() throws {
        let synth = try TextureSynth()
        func stats(_ overcast: Float) throws -> (ratio: Float, peak: Float) {
            let t = try synth.skyTexture(SkyParams(sunDir: simd_normalize([0.3, 0.6, 0.2]), width: 256, drawSun: true, overcast: overcast, cloudSeed: 0.4))
            var px = [Float16](repeating: 0, count: t.width * t.height * 4)
            t.getBytes(&px, bytesPerRow: t.width * 8, from: MTLRegionMake2D(0, 0, t.width, t.height), mipmapLevel: 0)
            var r: Float = 0, b: Float = 0, peak: Float = 0
            for y in 0..<t.height / 2 { for x in 0..<t.width {
                let k = (y * t.width + x) * 4
                let v = [Float(px[k]), Float(px[k + 1]), Float(px[k + 2])]
                XCTAssertTrue(v.allSatisfy { $0.isFinite && $0 >= 0 }, "sky texel \(x),\(y) not finite")
                r += v[0]; b += v[2]; peak = max(peak, v.max()!)
            }}
            return (b / max(r, 1e-6), peak)
        }
        let clear = try stats(0), grey = try stats(1)
        XCTAssertLessThan(grey.ratio, clear.ratio, "overcast sky is less blue")
        XCTAssertLessThan(grey.ratio, 1.35, "overcast sky is near neutral")
        XCTAssertLessThan(grey.peak, clear.peak * 0.2, "no sun disk under overcast")
        _ = try RealityHD.environment({ var s = SunSky.midday; s.overcast = 0.9; return s }(), skybox: true)
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
