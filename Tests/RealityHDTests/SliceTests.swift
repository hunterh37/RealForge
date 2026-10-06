import Testing
import simd
@testable import RealCore

@Suite struct SliceTests {
    func sphere(_ r: Float = 0.05, material: MaterialKey = "food.test") -> Model {
        var s = Prim.cubeSphere(subdivisions: 12, material: material) { $0 * r }
        s.finalize()
        var m = Model(name: "ball"); m.add(s); return m
    }

    @Test func sphereIsClosed() {
        #expect(sphere().surfaces[0].isClosed())
    }

    @Test func halvesAreClosedAndConserveVolume() {
        let m = sphere()
        let v0 = m.volume
        let plane = SlicePlane(point: V3(0.012, 0, 0), normal: V3(1, 0.3, 0.1))
        let (a, b) = m.sliced(by: plane) { _ in SliceCap(material: "food.flesh") }
        #expect(a.surfaces.count == 2 && b.surfaces.count == 2)
        for half in [a, b] {
            var all = Surface(material: "x")
            for s in half.surfaces { all.append(s) }
            #expect(all.isClosed(), "cut half must stay watertight")
        }
        #expect(abs(a.volume + b.volume - v0) / v0 < 0.01)
        #expect(a.volume > b.volume)
        // Every vertex of each half lies on its side of the plane (cap included).
        for s in a.surfaces { for p in s.positions { #expect(plane.distance(p) < 1e-4) } }
        for s in b.surfaces { for p in s.positions { #expect(plane.distance(p) > -1e-4) } }
    }

    @Test func capFacesOutward() {
        let (a, _) = sphere().sliced(by: SlicePlane(point: .zero, normal: V3(0, 1, 0))) { _ in SliceCap(material: "food.flesh") }
        let cap = a.surfaces.first { $0.material == "food.flesh" }!
        #expect(cap.normals.allSatisfy { simd_dot($0, V3(0, 1, 0)) > 0.99 })
        // Triangles wind counter-clockwise seen from the normal.
        let i = cap.indices
        let n = simd_cross(cap.positions[Int(i[1])] - cap.positions[Int(i[0])], cap.positions[Int(i[2])] - cap.positions[Int(i[0])])
        #expect(n.y > 0)
    }

    @Test func nestedShellCutGivesAnnulus() {
        // Thick-walled hollow ball: outer shell + inward-facing inner shell, same material.
        var outer = Prim.cubeSphere(subdivisions: 10, material: "food.test") { $0 * 0.05 }; outer.finalize()
        var inner = Prim.cubeSphere(subdivisions: 10, material: "food.test") { $0 * 0.04 }; inner.finalize()
        var s = outer; s.append(inner.flippedFacing())
        var m = Model(name: "shell"); m.add(s)
        let v0 = m.volume
        _ = v0
        let (a, b) = m.sliced(by: SlicePlane(point: .zero, normal: V3(0, 0, 1))) { _ in SliceCap(material: "food.flesh") }
        let cap = a.surfaces.first { $0.material == "food.flesh" }!
        // Annulus area = pi (R^2 - r^2); no triangle covers the hole center.
        var area: Float = 0
        var t = 0
        while t + 2 < cap.indices.count {
            let p0 = cap.positions[Int(cap.indices[t])], p1 = cap.positions[Int(cap.indices[t + 1])], p2 = cap.positions[Int(cap.indices[t + 2])]
            area += simd_length(simd_cross(p1 - p0, p2 - p0)) / 2
            t += 3
        }
        let expected = Float.pi * (0.05 * 0.05 - 0.04 * 0.04)
        #expect(abs(area - expected) / expected < 0.05)
        #expect(!b.surfaces.isEmpty)
    }

    @Test func planeMissLeavesOneSideEmpty() {
        let (a, b) = sphere().sliced(by: SlicePlane(point: V3(0.2, 0, 0), normal: V3(1, 0, 0))) { _ in SliceCap(material: "food.flesh") }
        #expect(b.surfaces.isEmpty)
        #expect(a.triangleCount == sphere().triangleCount)
    }
}
