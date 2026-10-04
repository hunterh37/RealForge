import Foundation
import Testing
import simd
@testable import RealCore
@testable import RealKit
@testable import RealLibrary

@Suite struct PerformanceTests {
    /// Three-level box asset: 1.2k / 300 / 108 triangles roughly.
    static func asset(size: Float = 1) -> LODModel {
        let levels = [4, 2, 1].map { seg -> Model in
            var m = Model(name: "box")
            m.add(Prim.roundedBox(V3(repeating: size), radius: size * 0.1, bevelSegments: seg, material: "wood.oak"))
            return m
        }
        return LODModel(levels: levels, switchDistances: [10, 30])
    }

    static func scene() -> RealScene {
        var s = RealScene(name: "perf-test")
        var grass: [simd_float4x4] = []
        for i in 0..<40 { for j in 0..<40 { grass.append(place(Float(i) - 20, Float(j) - 20).matrix) } }
        s.fields.append(.init(asset: asset(size: 0.2), transforms: grass, options: .groundCover(cull: 30)))
        var trees: [simd_float4x4] = []
        for i in 0..<30 { trees.append(place(Float(i % 6) * 12 - 30, Float(i / 6) * 12 - 30).matrix) }
        s.fields.append(.init(asset: asset(size: 3), transforms: trees, options: .trees))
        for i in 0..<60 { s.singles.append(.init(asset: asset(size: i % 3 == 0 ? 0.3 : 1.5), at: place(Float(i) * 2 - 60, 5))) }
        for k in 0..<12 { s.lights.append(RigLight(name: "l\(k)", position: V3(Float(k), 3, 0), intensity: Float(100 * k))) }
        s.camera = .init(eye: V3(0, 1.6, 0), target: V3(0, 1, -10), fov: 60)
        return s
    }

    @Test func balancedIsTheDefault() {
        #expect(RealPerformance() == RealPerformance(.balanced))
        let b = RealPerformance(.balanced)
        #expect(b.lodBias == 1 && b.drawDistance == 0 && b.fieldDensity == 1 && b.distantThinning == 0)
        #expect(b.shadowCasterMaxLOD == 1 && b.textureScale == 1 && b.maxTextureSize == 1024 && !b.forceBatching && !b.adaptive)
    }

    @Test func settingsRoundTripThroughDefaults() throws {
        let d = try #require(UserDefaults(suiteName: "realityhd.tests.\(UUID())"))
        let s = RealPerformance(.ultra).with { $0.lodBias = 1.7; $0.tier = nil; $0.wind = false }
        s.save(to: d)
        #expect(RealPerformance.load(from: d) == s)
        d.set(Data("{}".utf8), forKey: RealPerformance.defaultsKey)
        #expect(RealPerformance.load(from: d) == nil, "unreadable settings fall back")
    }

    @Test func rebuildClassification() {
        let b = RealPerformance(.balanced)
        #expect(!b.with { $0.lodBias = 0.5; $0.drawDistance = 80; $0.shadows = false; $0.adaptive = true }.needsRebuild(from: b), "live settings")
        #expect(b.with { $0.fieldDensity = 0.5 }.needsRebuild(from: b))
        #expect(b.with { $0.wind = false }.needsRebuild(from: b))
        #expect(b.with { $0.maxTextureSize = 512 }.needsRebuild(from: b))
        #expect(b.with { $0.forceBatching = true }.needsRebuild(from: b))
    }

    @Test func levelSelectionFollowsBiasAndCulls() {
        let sw: [Float] = [10, 30]
        let b = RealPerformance(.balanced)
        #expect(b.level(distance: 9, switchDistances: sw) == 0)
        #expect(b.level(distance: 20, switchDistances: sw) == 1)
        #expect(b.level(distance: 500, switchDistances: sw) == 2, "balanced never culls")
        let low = b.with { $0.lodBias = 0.5 }
        #expect(low.level(distance: 9, switchDistances: sw) == 1)
        #expect(b.with { $0.lodBias = 2 }.level(distance: 50, switchDistances: sw) == 1)
        #expect(b.level(distance: 9, switchDistances: sw, adaptive: 0.5) == 1, "adaptive scale lowers the bias")
        let far = b.with { $0.drawDistance = 100 }
        #expect(far.level(distance: 120, switchDistances: sw) == nil)
        let detail = b.with { $0.detailCullDistance = 15; $0.detailSize = 0.6 }
        #expect(detail.level(distance: 20, switchDistances: sw, size: 0.3) == nil)
        #expect(detail.level(distance: 20, switchDistances: sw, size: 2) == 1)
        let cover = b.with { $0.groundCoverDistance = 0.5 }
        #expect(cover.level(distance: 20, switchDistances: sw, cullDistance: 30, groundCover: true) == nil)
        #expect(cover.level(distance: 20, switchDistances: sw, cullDistance: 30, groundCover: false) == 1)
    }

    @Test func shadowPolicy() {
        let b = RealPerformance(.balanced)
        #expect(b.castsShadow(lod: 1, size: 1) && !b.castsShadow(lod: 2, size: 1))
        #expect(!b.castsShadow(lod: 0, size: 1, eligible: false))
        #expect(!b.castsShadow(lod: 0, size: 1, lodShift: -2), "ground cover never casts")
        #expect(RealPerformance(.ultra).castsShadow(lod: 2, size: 1))
        let perf = RealPerformance(.performance)
        #expect(!perf.castsShadow(lod: 0, size: 0.1) && perf.castsShadow(lod: 0, size: 1) && !perf.castsShadow(lod: 1, size: 1))
        #expect(!b.with { $0.shadows = false }.castsShadow(lod: 0, size: 5))
    }

    @Test func thinningIsDeterministicAndProportional() {
        var t: [simd_float4x4] = []
        for i in 0..<100 { for j in 0..<100 { t.append(place(Float(i) * 0.37, Float(j) * 0.41).matrix) } }
        let half = RealPerformance(.balanced).with { $0.fieldDensity = 0.5 }
        let a = half.thinned(t), b = half.thinned(t)
        #expect(a.count == b.count)
        #expect(abs(Double(a.count) / Double(t.count) - 0.5) < 0.05)
        let thin = RealPerformance(.balanced).with { $0.distantThinning = 0.6 }
        #expect(thin.instances(t, level: 0, levels: 3).count == t.count, "LOD0 keeps everything")
        let coarse = thin.instances(t, level: 2, levels: 3)
        #expect(abs(Double(coarse.count) / Double(t.count) - 0.4) < 0.05)
        #expect(coarse.allSatisfy { simd_length(SIMD3($0.columns.0.x, $0.columns.0.y, $0.columns.0.z)) > 1.2 }, "survivors grow to cover")
    }

    @Test func tiersOrderByCost() {
        let s = Self.scene()
        let w = RealPerformance.Tier.allCases.map { s.estimate(settings: RealPerformance($0)) }
        for (a, b) in zip(w, w.dropFirst()) { #expect(a.weight <= b.weight, "\(a) vs \(b)") }
        let battery = w[0], balanced = w[2]
        #expect(battery.weight * 2 < balanced.weight, "battery at least halves the frame weight")
        #expect(battery.lights == 2 && balanced.lights == 8)
        #expect(balanced.instances > battery.instances)
    }

    @Test func balancedEstimateMatchesScene() {
        let s = Self.scene()
        let c = s.estimate(settings: RealPerformance(.balanced))
        #expect(c.instances == 1600 + 30 + 60, "balanced keeps every grass, tree and static instance")
    }

    @Test func forcedBatchingKeepsSmallObjectsApart() {
        let s = Self.scene()
        let batched = s.uploadedStatics(RealPerformance(.balanced).with { $0.forceBatching = true })
        #expect(batched.count < s.singles.count)
        let sizes = batched.map { $0.asset.levels[0].boundsDiagonal }
        #expect(sizes.contains { $0 < 0.6 }, "small props batch on their own")
        #expect(s.uploadedStatics(RealPerformance(.balanced)).count == s.singles.count)
    }

    @Test func lightBudgetKeepsTheBrightest() {
        let l = RealScene.budgetLights(Self.scene().lights, max: 3)
        #expect(l.map(\.name) == ["l11", "l10", "l9"])
    }
}
