import Testing
import Foundation
import simd
@testable import RealCore
@testable import RealLibrary
import RealMaterials

/// RealityHD 3 geometry kit: closed, outward-facing solids with the expected volume.
@Suite struct ShapeKit {
    @Test func extrudeBoxVolume() {
        let s = Prim.extrude(Shape2D.rect(0.4, 0.2), depth: 0.1, bevel: 0, material: "x")
        #expect(abs(signedVolume(s) - 0.008) < 0.0002, "extrude volume \(signedVolume(s))")
    }
    @Test func extrudeBeveledIsOutward() {
        let s = Prim.extrude(Shape2D.roundedRect(0.4, 0.2, radius: 0.03), depth: 0.1, bevel: 0.01, material: "x")
        let v = signedVolume(s)
        #expect(v > 0.0068 && v < 0.008, "beveled extrude volume \(v)")
    }
    @Test func sweepCylinderVolume() {
        let path = (0...4).map { V3(0, Float($0) * 0.25, 0) }
        let s = Prim.sweep(Shape2D.circle(0.1, segments: 48), along: path, material: "x")
        #expect(abs(signedVolume(s) - .pi * 0.01) < 0.001, "sweep volume \(signedVolume(s))")
    }
    @Test func torusVolume() {
        let s = Prim.torus(major: 0.5, minor: 0.1, segments: 64, sides: 24, material: "x")
        let exact = 2 * Float.pi * Float.pi * 0.5 * 0.01
        #expect(abs(signedVolume(s) - exact) / exact < 0.03, "torus volume \(signedVolume(s)) vs \(exact)")
    }
    @Test func superellipsoidBetweenSphereAndBox() {
        let sphere = signedVolume(Prim.superellipsoid(V3(1, 1, 1), exponent: 2, subdivisions: 16, material: "x"))
        let box = signedVolume(Prim.superellipsoid(V3(1, 1, 1), exponent: 10, subdivisions: 16, material: "x"))
        #expect(abs(sphere - .pi / 6) < 0.01)
        #expect(box > sphere && box < 1)
    }
    @Test func loftCapsOutward() {
        let rings = [Prim.ring(Shape2D.circle(0.2, segments: 32), y: 0), Prim.ring(Shape2D.circle(0.2, segments: 32), y: 0.5)]
        let s = Prim.loft(rings, capStart: true, capEnd: true, material: "x")
        #expect(abs(signedVolume(s) - .pi * 0.04 * 0.5) < 0.003, "loft volume \(signedVolume(s))")
    }
    @Test func outlinesAreRobust() {
        let dup = [V2(0, 0), V2(1, 0), V2(1, 0), V2(1, 1), V2(0, 1), V2(0, 0)]
        let r = Shape2D.rounded(dup, radius: 0.1, segments: 3)
        #expect(r.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        #expect(Shape2D.triangulate(Shape2D.rect(1, 1)).count == 6)
        let star = (0..<10).map { k -> V2 in let a = Float(k) * .pi / 5; let rr: Float = k % 2 == 0 ? 1 : 0.4; return V2(cos(a) * rr, sin(a) * rr) }
        #expect(Shape2D.triangulate(star).count == 8 * 3, "concave outline triangulates to n-2 triangles")
        #expect(Shape2D.area(Shape2D.offset(Shape2D.rect(1, 1), 0.1)) > 1.4)
    }
    @Test func subdivideKeepsShape() {
        let s = Prim.roundedBox(V3(1, 1, 1), radius: 0.1, material: "x")
        let d = s.subdivided()
        #expect(d.triangleCount == s.triangleCount * 4)
        #expect(abs(signedVolume(d) - signedVolume(s)) < 0.01)
    }
}

/// Gate math and the committed briefs and sign-offs.
@Suite struct QualityGate {
    func briefs() -> [PropBrief] {
        let dir = repoRoot.appendingPathComponent("briefs")
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.compactMap { try? PropBrief.load($0) }
    }

    @Test func scoreRequiresVerdictAndFloors() {
        let lod = LODModel(Model(name: "t", surfaces: [Prim.roundedBox(V3(0.5, 0.5, 0.5), radius: 0.02, material: "wood.oak").transformed(Xform(translation: V3(0, 0.25, 0)))]))
        let g = GeometryLint.run(lod, budget: 5000)
        #expect(g.errors == 0)
        let none = GateResult.compute(id: "t", geometry: g, brief: nil, image: nil, verdict: nil)
        #expect(none.status == "needs-vision" && none.final == nil)
        let good = Verdict(scores: Dictionary(uniqueKeysWithValues: Rubric.criteria.filter { $0.id != "reference" }.map { ($0.id, 9) }))
        #expect(GateResult.compute(id: "t", geometry: g, brief: nil, image: nil, verdict: good).status == "pass")
        var weak = good; weak.scores["materials"] = 5
        let r = GateResult.compute(id: "t", geometry: g, brief: nil, image: nil, verdict: weak)
        #expect(r.status == "fail" && r.reasons.contains { $0.contains("materials") }, "a criterion under the floor fails the gate")
    }

    @Test func lintCatchesFloatingAndBudget() {
        let floating = LODModel(Model(name: "f", surfaces: [Prim.roundedBox(V3(0.2, 0.2, 0.2), radius: 0.01, material: "wood.oak").transformed(Xform(translation: V3(0, 0.5, 0)))]))
        let g = GeometryLint.run(floating, budget: 10)
        #expect(g.issues.contains { $0.code == "floating" })
        #expect(g.issues.contains { $0.code == "budget" })
    }

    @Test func sizeScoreIsGaussian() throws {
        var b = PropBrief(id: "x", name: "x", theme: "T", summary: "x.", tags: ["prop"], size: [1, 1, 1], materials: [], parts: [])
        b.tolerance = 0.1
        #expect(GeometryLint.sizeScore([1, 1, 1], b) > 0.999)
        #expect(abs(GeometryLint.sizeScore([1.1, 1, 1], b) - (2 + 0.5) / 3) < 0.01)
    }

    /// Every brief names a registered asset whose metadata and size match it.
    @Test func briefsMatchAssets() {
        for b in briefs() {
            guard let t = Catalog.type(b.id) else { Issue.record("briefs/\(b.id).json: no asset with id \(b.id) (realityhd new prop \(b.id) --brief ...)"); continue }
            #expect(t.summary == b.summary, "\(b.id): summary differs from briefs/\(b.id).json")
            #expect(t.budget <= 15_000)
            let e = t.init().build(seed: 1).levels[0].bounds
            let size = e.max - e.min
            for i in 0..<3 where b.size[i] > 0 {
                let err = abs(size[i] - b.size[i]) / b.size[i]
                #expect(err <= b.tolerance * 2, "\(b.id): axis \(i) \(size[i]) m vs brief \(b.size[i]) m")
            }
        }
    }

    /// A sign-off is valid only for the geometry it judged; changed assets must be re-gated.
    @Test func signoffsAreCurrent() {
        let dir = repoRoot.appendingPathComponent("briefs/signoff")
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for f in files where f.pathExtension == "json" {
            guard let data = try? Data(contentsOf: f), let s = try? JSONDecoder().decode(Signoff.self, from: data) else { Issue.record("\(f.lastPathComponent): unreadable"); continue }
            guard let t = Catalog.type(s.id) else { Issue.record("signoff for unknown id \(s.id)"); continue }
            #expect(s.final >= s.threshold, "\(s.id): signed off below threshold")
            #expect(GeometryLint.fingerprint(t.init().build(seed: s.seed)) == s.fingerprint,
                    "\(s.id): geometry changed since sign-off; run realityhd gate \(s.id) and sign off again")
        }
    }
}
