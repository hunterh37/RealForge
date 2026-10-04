import Testing
import Foundation
import simd
@testable import RealCore
@testable import RealLibrary
import RealMaterials

/// Rules for articulated assets (`RealArticulated`) and the rig math they rely on.
@Suite struct ArticulationTests {
    @Test(arguments: Catalog.articulated.map { $0.id })
    func rigContract(_ id: String) throws {
        let t = try #require(Catalog.type(id))
        let rig = try #require(Catalog.rig(id, seed: 7))
        #expect(rig.validate().isEmpty, "\(id): \(rig.validate().joined(separator: "; "))")
        #expect(rig.switchDistances.count == rig.lodCount - 1)
        for st in rig.stateNames {
            let p = rig.posed(st)
            #expect(p.levels[0].triangleCount <= t.budget, "\(id) state \(st): \(p.levels[0].triangleCount) tris > budget \(t.budget)")
            for i in 1..<p.levels.count { #expect(p.levels[i].triangleCount <= p.levels[i - 1].triangleCount, "\(id) \(st): LOD\(i) heavier") }
            for m in p.levels { for s in m.surfaces {
                #expect(s.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }, "\(id) \(st): non-finite")
                #expect(MaterialLibrary.keys.contains(baseKey(s.material)), "\(id): unknown material \(s.material)")
            }}
        }
        // build(seed:) is the default state.
        #expect(t.init().build(seed: 7).levels[0].triangleCount == rig.posed().levels[0].triangleCount)
        // Deterministic.
        let again = try #require(Catalog.rig(id, seed: 7))
        #expect(again.posed(rig.stateNames.last!).levels[0].surfaces.first?.positions.first == rig.posed(rig.stateNames.last!).levels[0].surfaces.first?.positions.first)
    }

    @Test func hingeSwingsAboutPivot() {
        var rig = Rig(name: "t")
        rig.part("leaf", pivot: V3(1, 0, 0), joint: .hinge(-90...0))
        rig.add(Prim.roundedBox(V3(0.2, 0.2, 0.2), radius: 0.01, material: "wood.oak"), Xform(translation: V3(2, 0, 0)), to: "leaf")
        rig.states = [RigState("closed"), RigState("open", ["leaf": -90])]
        let b = rig.posed("open").levels[0].bounds, c = (b.min + b.max) / 2
        // Box center 1 m from the pivot on +X, rotated -90 about +Y lands at z = +1.
        #expect(simd_distance(c, V3(1, 0, 1)) < 1e-3)
        #expect(rig.validate().isEmpty)
    }

    @Test func childFollowsParentAndMimic() {
        var rig = Rig(name: "t")
        rig.part("slide", pivot: .zero, joint: .slide(axis: V3(0, 0, 1), 0...1))
        rig.part("knob", parent: "slide", pivot: V3(0, 1, 0), joint: .hinge(axis: V3(0, 0, 1), 0...90))
        rig.part("half", pivot: .zero, joint: Joint(.prismatic, axis: V3(0, 0, 1), range: 0...0.5, mimic: .init("slide", ratio: 0.5)))
        rig.add(Prim.roundedBox(V3(0.1, 0.1, 0.1), radius: 0.01, material: "wood.oak"), Xform(translation: V3(1, 1, 0)), to: "knob")
        rig.add(Prim.roundedBox(V3(0.1, 0.1, 0.1), radius: 0.01, material: "metal.chrome"), to: "half")
        rig.states = [RigState("in"), RigState("out", ["slide": 1, "knob": 90])]
        let v = rig.values("out")
        #expect(v["half"] == 0.5)
        let xf = rig.partTransforms(v)
        // Knob geometry at (1,1,0): rotate 90 about Z around (0,1,0) -> (0,2,0), then slide +1 z.
        #expect(simd_distance(xf[1].point(V3(1, 1, 0)), V3(0, 2, 1)) < 1e-4)
        #expect(simd_distance(xf[2].point(.zero), V3(0, 0, 0.5)) < 1e-4)
        // Runtime local transforms chain to the same pose.
        let world = rig.localJointTransform(1, value: 90).then(rig.localJointTransform(0, value: 1))
        #expect(simd_distance(rig.parts[1].pivot.inverse.then(world).point(V3(1, 1, 0)), V3(0, 2, 1)) < 1e-4)
    }

    @Test func validateCatchesBadStates() {
        var rig = Rig(name: "t")
        rig.part("lid", pivot: .zero, joint: .hinge(0...90))
        rig.states = [RigState("a"), RigState("b", ["lid": 120, "nope": 1])]
        let issues = rig.validate()
        #expect(issues.contains { $0.contains("outside") } && issues.contains { $0.contains("unknown joint") })
    }

    @Test func bvhAndBakeDarkenContact() {
        var floor = Model(name: "floor", surfaces: [Prim.terrain(size: V2(2, 2), segments: 10, material: "concrete.smooth") { _ in 0 }])
        let block = Model(name: "b", surfaces: [Prim.roundedBox(V3(0.6, 0.6, 0.6), radius: 0.01, material: "wood.oak").transformed(Xform(translation: V3(0, 0.3, 0)))])
        var receivers = [floor]
        AOBake.bake(&receivers, occluders: [block], settings: .init(rays: 32, distance: 1))
        floor = receivers[0]
        let s = floor.surfaces[0]
        let near = s.positions.indices.filter { abs(s.positions[$0].x - 0.4) < 0.11 && abs(s.positions[$0].z) < 0.11 }.map { s.occlusion[$0] }
        let far = s.positions.indices.filter { abs(s.positions[$0].x) > 0.9 && abs(s.positions[$0].z) > 0.9 }.map { s.occlusion[$0] }
        #expect(!near.isEmpty && !far.isEmpty)
        #expect(near.max()! < far.min()!, "contact AO: next to the block darker than the corners")
    }

    @Test func staticBatchingMergesByCell() {
        var scene = RealScene(name: "t")
        let m = Model(name: "m", surfaces: [Prim.roundedBox(V3(0.2, 0.2, 0.2), radius: 0.01, material: "wood.oak")])
        for i in 0..<20 { scene.add(m, at: place(Float(i % 5) * 0.5, Float(i / 5) * 0.5)) }
        scene.batchStatics = true
        let b = RealScene.batches(scene.singles, cell: 8)
        #expect(b.count == 1 && b[0].asset.levels[0].triangleCount == m.triangleCount * 20)
    }
}
