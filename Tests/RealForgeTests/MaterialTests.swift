import Testing
import simd
@testable import RealMaterials

@Suite struct MaterialTests {
    /// Keys that predate the family.variant rule.
    static let legacyKeys: Set<String> = ["asphalt", "rubber"]

    @Test func keysUniqueAndNamed() {
        let keys = MaterialLibrary.keys
        #expect(Set(keys).count == keys.count, "duplicate material key")
        for k in keys where !Self.legacyKeys.contains(k) {
            #expect(k.range(of: "^[a-z]+\\.[a-z0-9]+(-[a-z0-9]+)*$", options: .regularExpression) != nil, "\(k): keys are family.variant")
        }
    }

    @Test func everyKeyHasProgramOrScalars() {
        for k in MaterialLibrary.keys {
            let s = MaterialLibrary.spec(for: k)
            #expect(s.key == k)
            if s.mode == .cutout { #expect(s.program != nil && s.twoSided, "\(k): cutout needs an atlas program and twoSided") }
            if s.program != nil && s.mode != .cutout { #expect(s.tileSize > 0, "\(k): tiling materials need tileSize > 0 (meters per repeat)") }
            #expect((128...4096).contains(s.resolution))
            #expect(s.roughness >= 0 && s.roughness <= 1 && s.metallic >= 0 && s.metallic <= 1)
        }
    }

    @Test func everyProgramIsUsed() {
        let used = Set(MaterialLibrary.all.compactMap { $0.program })
        for p in TextureProgram.allCases { #expect(used.contains(p), "\(p): add a material that uses it") }
    }

    @Test func dispatchCoversEveryProgram() {
        for p in TextureProgram.allCases {
            #expect(realForgeMetalSource.contains("S \(p)(float2 uv, constant RFParams &P)"), "\(p): Metal function missing")
            #expect(realForgeMetalSource.contains("case \(p.rawValue): return \(p)(uv, P);"))
        }
    }

    @Test func tintSuffixParses() {
        let s = MaterialLibrary.spec(for: "metal.painted:FF0000")
        #expect(s.colorA.x > 0.9 && s.colorA.y < 0.01)
    }
}
