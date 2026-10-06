import XCTest
import simd
@testable import RealLibrary

/// Contract tests for `Lumber` (and `PlywoodSheet` cuts): the game builds every board and cut piece from
/// these values, so sizes, cut planes and grain continuity must hold exactly.
final class LumberTests: XCTestCase {
    let inch: Float = 0.0254

    func twoByFour(_ length: Float = 2.4384) -> Lumber { Lumber(nominal: "2x4", length: length)! }

    /// Vertices of the end-cap surface of a built board.
    func endVertices(_ b: Lumber, seed: UInt64 = 3) -> [V3] {
        b.build(seed: seed).levels[0].surfaces.first { $0.material == b.endMaterial }!.positions
    }

    func testNominalSizes() {
        let expect: [String: (Float, Float)] = [
            "1x2": (1.5, 0.75), "1x3": (2.5, 0.75), "1x4": (3.5, 0.75), "1x6": (5.5, 0.75), "1x8": (7.25, 0.75),
            "1x10": (9.25, 0.75), "1x12": (11.25, 0.75), "2x2": (1.5, 1.5), "2x4": (3.5, 1.5), "2x6": (5.5, 1.5),
            "2x8": (7.25, 1.5), "2x10": (9.25, 1.5), "2x12": (11.25, 1.5), "4x4": (3.5, 3.5)]
        for (k, v) in expect {
            let n = Lumber.nominal(k)!
            XCTAssertEqual(n.width, v.0 * inch, accuracy: 1e-6, k)
            XCTAssertEqual(n.thickness, v.1 * inch, accuracy: 1e-6, k)
        }
        XCTAssertNotNil(Lumber.nominal("2 X 4"))
        XCTAssertNil(Lumber.nominal("3x5"))
        XCTAssertNil(Lumber(nominal: "5x5", length: 1))
        let d = Lumber()
        XCTAssertEqual(d.width, 3.5 * inch, accuracy: 1e-6)
        XCTAssertEqual(d.thickness, 1.5 * inch, accuracy: 1e-6)
        XCTAssertEqual(d.length, 24 * inch, accuracy: 1e-6)
    }

    func testCrosscutConservesLengthMinusKerf() {
        let b = twoByFour()
        for x: Float in [-1.0, -0.2, 0, 0.35, 1.1] {
            guard let (l, r) = b.crosscut(atX: x) else { return XCTFail("cut at \(x)") }
            XCTAssertEqual(l.board.length + r.board.length, b.length - 0.0032, accuracy: 1e-5)
            XCTAssertEqual(l.center.x - l.board.length / 2, -b.length / 2, accuracy: 1e-5)
            XCTAssertEqual(r.center.x + r.board.length / 2, b.length / 2, accuracy: 1e-5)
            XCTAssertEqual(r.center.x - r.board.length / 2 - (l.center.x + l.board.length / 2), 0.0032, accuracy: 1e-5)
            XCTAssertEqual(l.center.y, 0); XCTAssertEqual(l.center.z, 0)
            XCTAssertEqual(l.board.width, b.width); XCTAssertEqual(r.board.thickness, b.thickness)
            XCTAssertEqual(l.board.volume + r.board.volume, b.volume - b.volume * 0.0032 / b.length, accuracy: 1e-7)
        }
        XCTAssertNil(b.crosscut(atX: 1.3))
        XCTAssertNil(b.crosscut(atX: -1.25))
        XCTAssertNil(b.crosscut(atX: 1.21, miter: 45), "miter would run off the end")
    }

    func testMiteredEndFacesLieOnTheCutPlane() {
        let b = twoByFour(1.2)
        for (miter, bevel) in [(Float(45), Float(0)), (30, 20), (-22.5, -10), (0, 45)] {
            let x: Float = 0.12, kerf: Float = 0.0032
            guard let (l, r) = b.crosscut(atX: x, kerf: kerf, miter: miter, bevel: bevel) else { return XCTFail() }
            let n = simd_normalize(V3(1, tan(bevel * .pi / 180), tan(miter * .pi / 180)))
            let p0 = V3(x, b.thickness / 2, 0)
            let left = endVertices(l.board).filter { $0.x > 0 }.map { $0 + l.center }
            let right = endVertices(r.board).filter { $0.x < 0 }.map { $0 + r.center }
            XCTAssertGreaterThan(left.count, 8); XCTAssertGreaterThan(right.count, 8)
            for p in left { XCTAssertEqual(simd_dot(n, p - p0), -kerf / 2, accuracy: 2e-5, "left \(miter)/\(bevel)") }
            for p in right { XCTAssertEqual(simd_dot(n, p - p0), kerf / 2, accuracy: 2e-5, "right \(miter)/\(bevel)") }
            XCTAssertEqual(simd_dot(l.board.endPlane(right: true).normal, n), 1, accuracy: 1e-5)
            XCTAssertEqual(simd_dot(r.board.endPlane(right: false).normal, -n), 1, accuracy: 1e-5)
            // The untouched ends stay where the parent's were.
            for p in endVertices(l.board).filter({ $0.x < 0 }).map({ $0 + l.center }) { XCTAssertEqual(p.x, -0.6, accuracy: 1e-5) }
        }
    }

    func testMiterSignConvention() {
        var b = twoByFour(1.0)
        b.easedEdges = false; b.stamp = false
        b.miterRight = 45; b.miterLeft = 45
        let ends = endVertices(b)
        let backRight = ends.filter { $0.z < -0.04 }.map(\.x).max()!, frontRight = ends.filter { $0.z > 0.04 }.map(\.x).max()!
        XCTAssertGreaterThan(backRight, frontRight, "positive miter: back edge longer at +X")
        let backLeft = ends.filter { $0.z < -0.04 }.map(\.x).min()!, frontLeft = ends.filter { $0.z > 0.04 }.map(\.x).min()!
        XCTAssertLessThan(backLeft, frontLeft, "positive miter: back edge longer at -X")
        b.miterRight = 0; b.miterLeft = 0; b.bevelRight = 30
        let e2 = endVertices(b).filter { $0.x > 0.3 }
        XCTAssertGreaterThan(e2.filter { $0.y < 0.001 }.map(\.x).max()!, e2.filter { $0.y > b.thickness - 0.001 }.map(\.x).max()!,
                             "positive bevel: bottom longer")
    }

    func testGrainContinuesAcrossCuts() {
        var b = twoByFour(1.5)
        b.grainOffset = V2(0.05, -0.01)
        let seed: UInt64 = 7
        guard let (_, r) = b.crosscut(atX: 0.2, miter: 15), let (f, k) = r.board.rip(atZ: 0.01) else { return XCTFail() }
        // Grain mapping in the root frame: u = x + g.x, v = z + g.y on the wide faces, u = x + g.x on edges.
        for (piece, origin) in [(r.board, r.center), (f.board, r.center + f.center), (k.board, r.center + k.center)] {
            let face = piece.build(seed: seed).levels[0].surfaces.first { $0.material == piece.material }!
            var checked = 0
            for i in face.positions.indices {
                let p = face.positions[i] + origin, n = face.normals[i]
                XCTAssertEqual(face.uvs[i].x, p.x + b.grainOffset.x, accuracy: 1e-5)
                if abs(n.y) > 0.99 { XCTAssertEqual(face.uvs[i].y, p.z + b.grainOffset.y, accuracy: 1e-5); checked += 1 }
            }
            XCTAssertGreaterThan(checked, 3)
            // Pith stays put in the root frame.
            XCTAssertEqual(piece.pith(seed: seed).x + origin.z, b.pith(seed: seed).x, accuracy: 1e-6)
            XCTAssertEqual(piece.pith(seed: seed).y, b.pith(seed: seed).y, accuracy: 1e-6)
        }
        // Explicit pith follows rips too.
        var c = b; c.endGrainCenter = V2(0.02, -0.05)
        let (cf, _) = c.rip(atZ: -0.01)!
        XCTAssertEqual(cf.board.endGrainCenter!.x + cf.center.z, 0.02, accuracy: 1e-6)
    }

    func testRip() {
        let b = twoByFour(1.0)
        guard let (f, k) = b.rip(atZ: 0.01, kerf: 0.003) else { return XCTFail() }
        XCTAssertEqual(f.board.width + k.board.width, b.width - 0.003, accuracy: 1e-6)
        XCTAssertEqual(f.center.z + f.board.width / 2, b.width / 2, accuracy: 1e-6)
        XCTAssertEqual(k.center.z - k.board.width / 2, -b.width / 2, accuracy: 1e-6)
        XCTAssertEqual(f.board.sawnSides, [.back]); XCTAssertEqual(k.board.sawnSides, [.front])
        XCTAssertEqual(f.board.length, b.length, accuracy: 1e-6)
        XCTAssertNil(b.rip(atZ: 0.05)); XCTAssertNil(b.rip(atZ: b.width / 2 - 0.001))
        // Mitered parent: pieces follow the miter at their own centerline.
        var m = b; m.miterRight = 45
        let (mf, mk) = m.rip(atZ: 0)!
        XCTAssertLessThan(mf.board.length, mk.board.length)
        XCTAssertEqual(mf.center.x + mf.board.length / 2, 0.5 - mf.center.z, accuracy: 1e-5)
    }

    func testVolumeAndBoardFeet() {
        var b = twoByFour(12 * inch)
        b.easedEdges = false
        XCTAssertEqual(b.volume, 3.5 * 1.5 * 12 * inch * inch * inch, accuracy: 1e-8)
        XCTAssertEqual(b.boardFeet, 0.4375, accuracy: 1e-4)
        b.easedEdges = true
        XCTAssertLessThan(b.volume, 3.5 * 1.5 * 12 * inch * inch * inch)
        b.easedEdges = false; b.miterRight = 30; b.miterLeft = -30
        XCTAssertEqual(b.volume, 3.5 * 1.5 * 12 * inch * inch * inch, accuracy: 1e-8, "parallel miters keep volume")
    }

    func testBuildContract() {
        let b = Lumber()
        let m = b.build(seed: 2).levels[0]
        XCTAssertLessThanOrEqual(m.triangleCount, Lumber.budget)
        XCTAssertEqual(m.bounds.min.y, 0, accuracy: 1e-5)
        XCTAssertEqual(m.bounds.max.x, b.length / 2, accuracy: 1e-4)
        XCTAssertEqual(m.triangleCount, b.build(seed: 2).levels[0].triangleCount)
        XCTAssertTrue(m.materials.contains("wood.lumber-stamp"))
        var hard = b; hard.material = "wood.lumber-walnut"; hard.stamp = false; hard.easedEdges = false
        XCTAssertFalse(hard.build(seed: 2).levels[0].materials.contains("wood.lumber-stamp"))
    }

    func testPlywoodCuts() {
        let p = PlywoodSheet()
        guard let (l, r) = p.crosscut(atX: 0.3), let (f, k) = l.board.rip(atZ: 0.1) else { return XCTFail() }
        XCTAssertEqual(l.board.length + r.board.length, p.length - 0.0032, accuracy: 1e-5)
        XCTAssertEqual(f.board.width + k.board.width, p.width - 0.0032, accuracy: 1e-5)
        XCTAssertEqual(f.board.grainOffset.x, l.center.x + f.center.x, accuracy: 1e-6)
        XCTAssertEqual(f.board.grainOffset.y, f.center.z, accuracy: 1e-6)
        XCTAssertNil(p.crosscut(atX: 0.7)); XCTAssertNil(p.rip(atZ: -0.4))
    }
}
