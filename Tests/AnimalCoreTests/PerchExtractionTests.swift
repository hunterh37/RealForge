import XCTest
import RealLibrary
@testable import AnimalCore

final class PerchExtractionTests: XCTestCase {
    func testEveryRuleItemYieldsSitesInsideBounds() {
        for (id, rule) in PerchRules.table.sorted(by: { $0.key < $1.key }) {
            guard let t = Catalog.type(id) else { XCTFail("catalog missing \(id)"); continue }
            let lod = t.init().build(seed: 1)
            let m = lod.levels[0]
            let sites = PerchExtractor.localSites(itemID: id, model: m, seed: 1)
            XCTAssertFalse(sites.isEmpty, "\(id) has no sites")
            let b = m.bounds
            var line = "\(id): "
            for s in sites {
                XCTAssertGreaterThanOrEqual(s.position.y, b.min.y - 0.01, id)
                XCTAssertLessThanOrEqual(s.position.y, b.max.y + 0.2, id)
                XCTAssertGreaterThanOrEqual(s.position.x, b.min.x - 0.3, id)
                XCTAssertLessThanOrEqual(s.position.x, b.max.x + 0.3, id)
                line += String(format: "(%.2f %.2f %.2f) ", s.position.x, s.position.y, s.position.z)
            }
            print(line, "top", b.max.y, "kind", rule.kind)
        }
    }

    func testFrameTransform() {
        let f = ItemFrame(position: V3(1, 0, 2), yaw: .pi / 2, scale: V3(1, 1, 1))
        let p = f.point(V3(1, 0.5, 0))
        XCTAssertEqual(p.x, 1, accuracy: 1e-5); XCTAssertEqual(p.z, 1, accuracy: 1e-5); XCTAssertEqual(p.y, 0.5, accuracy: 1e-5)
    }
}
