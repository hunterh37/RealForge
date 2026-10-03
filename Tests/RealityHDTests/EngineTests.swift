import Testing
import simd
@testable import RealCore
import RealMaterials
import RealKit

@Suite struct EngineTests {
    @Test func splatChannelSurvivesMerging() {
        var a = Prim.terrain(size: V2(2, 2), segments: 2, material: "ground.meadow") { _ in 0 }
        a.paintSplat { $0.x * 10 }
        #expect(a.splat.allSatisfy { (0...1).contains($0) }, "paintSplat clamps to 0...1")
        let plain = Prim.terrain(size: V2(2, 2), segments: 2, material: "ground.meadow") { _ in 0 }
        var m = Model(name: "t")
        m.add(plain)
        m.add(a, Xform(translation: V3(3, 0, 0)))
        let s = m.finalized().surfaces[0]
        #expect(s.splat.count == s.positions.count)
        #expect(s.splat.prefix(plain.vertexCount).allSatisfy { $0 == 0 }, "surfaces without splat contribute weight 0")
        #expect(Array(s.splat.suffix(a.vertexCount)) == a.splat)
    }

    @Test func shaderGraphFlagsEmitTheirInputs() {
        var o = RealShaderOptions()
        o.splat = true; o.instanceJitter = true
        let u = RealShaderGraph.usda(o)
        #expect(u.contains("int inputs:index = 2"), "splat weight comes from uv2")
        #expect(u.contains("ND_transformpoint_vector3"), "jitter hashes the instance origin")
    }
}
