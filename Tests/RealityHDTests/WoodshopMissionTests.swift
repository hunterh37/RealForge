import XCTest
import simd
@testable import RealCore
@testable import RealLibrary

/// Mission props (butt-hinge, shingle-strip, job-ticket, wood-screw deck preset): real sizes, budgets and
/// the frame points the game reads.
final class WoodshopMissionTests: XCTestCase {
    let inch: Float = 0.0254

    func size(_ m: LODModel) -> V3 { let b = m.levels[0].bounds; return b.max - b.min }

    func testBuildAtSeedZeroWithinBudget() {
        let types: [any RealAsset.Type] = [ButtHinge.self, ShingleStrip.self, JobTicket.self]
        for t in types {
            let m = t.init().build(seed: 0)
            XCTAssertGreaterThan(m.levels[0].triangleCount, 0, t.id)
            XCTAssertLessThanOrEqual(m.levels[0].triangleCount, t.budget, t.id)
            let b = m.levels[0].bounds
            XCTAssertEqual(b.min.y, 0, accuracy: 0.002, "\(t.id) rests on y = 0")
        }
    }

    func testButtHingeDimensionsAndPoints() throws {
        let h = ButtHinge()
        let open = size(h.build(seed: 0))
        XCTAssertEqual(open.x, 3 * inch, accuracy: 0.001)
        XCTAssertEqual(open.z, 3 * inch + 0.0058, accuracy: 0.0005) // pin head and bottom cap
        XCTAssertEqual(h.fixedLeafHoles.count, 3)
        // Open flat, the moving leaf holes mirror the fixed ones across the pin.
        for (f, m) in zip(h.fixedLeafHoles, h.movingLeafHoles(angle: 180)) {
            XCTAssertEqual(m.x, -f.x, accuracy: 1e-5)
            XCTAssertEqual(m.y, f.y, accuracy: 1e-5)
        }
        // Closed, they stack over the fixed holes on the leaf face 2R - t up.
        for (f, m) in zip(h.fixedLeafHoles, h.movingLeafHoles(angle: 0)) {
            XCTAssertEqual(m.x, f.x, accuracy: 1e-5)
            XCTAssertEqual(m.y, 2 * h.knuckleRadius - h.thickness, accuracy: 1e-5)
        }
        XCTAssertEqual(simd_length(h.movingLeafScrewAxis(angle: 180) - V3(0, -1, 0)), 0, accuracy: 1e-5)
        let rig = try XCTUnwrap(Catalog.rig(ButtHinge.id, seed: 0))
        XCTAssertTrue(rig.validate().isEmpty, rig.validate().joined(separator: "; "))
        XCTAssertEqual(Set(rig.stateNames), ["open-flat", "closed", "open-90", "pin-out"])
        // Closed: the moving leaf sits over the fixed leaf, so the hinge is half as wide.
        let closed = rig.posed("closed").levels[0].bounds
        XCTAssertEqual(closed.max.x - closed.min.x, h.leafWidth + h.knuckleRadius, accuracy: 0.0005)
        let pulled = rig.posed("pin-out").levels[0].bounds
        XCTAssertGreaterThan(pulled.max.z, h.pinHead.z + 0.07)
    }

    func testShingleDimensionsAndNailLine() {
        let s = ShingleStrip()
        let e = size(s.build(seed: 0))
        XCTAssertEqual(e.x, 36 * inch, accuracy: 0.002)
        XCTAssertEqual(e.z, 12 * inch, accuracy: 0.035) // loose granules spill past the tab edge
        XCTAssertEqual(s.nailPoints.count, 4)
        for p in s.nailPoints { XCTAssertEqual(s.depth / 2 - p.z, 5.625 * inch, accuracy: 0.001) }
        XCTAssertEqual(s.tabCenters.count, 3)
        let c = ShingleStrip().with { $0.color = 0x3B4A3A }.build(seed: 0)
        XCTAssertTrue(c.levels[0].materials.contains { $0.hasPrefix("roofing.shingle-granule:3B4A3A") })
    }

    func testJobTicketSheetSitsOnBoard() {
        let j = JobTicket()
        let e = size(j.build(seed: 0))
        XCTAssertEqual(e.x, 9 * inch, accuracy: 0.002)
        XCTAssertEqual(e.z, 12.5 * inch, accuracy: 0.004) // clip lever roll overhangs the head edge
        XCTAssertEqual(j.sheetCenter.y, j.boardThickness, accuracy: 0.0005)
        XCTAssertGreaterThan(j.curledCorner.y, j.sheetCenter.y + 0.008)
        XCTAssertEqual(j.titleBlockCenter.y, j.sheetCenter.y, accuracy: 1e-5)
        XCTAssertLessThan(j.pencilSlot.center.y, j.boardThickness)
        XCTAssertGreaterThan(j.clipPress.y, j.clipJaw.y)
    }

    func testDeckScrewPreset() {
        let d = WoodScrew.deck
        XCTAssertEqual(d.clampedLength, 2.5 * inch, accuracy: 1e-5)
        XCTAssertEqual(d.drive, .star)
        let m = d.build(seed: 0)
        XCTAssertEqual(size(m).x, 2.5 * inch, accuracy: 0.002)
        XCTAssertLessThan(m.levels[0].triangleCount, 7_000)
        XCTAssertTrue(m.levels[0].materials.contains("metal.screw-ceramic-tan"))
    }
}
