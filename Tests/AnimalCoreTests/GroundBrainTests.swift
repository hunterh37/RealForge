import XCTest
@testable import AnimalCore

final class GroundBrainTests: XCTestCase {
    func testEverySpeciesForagesAndLeaves() {
        for sp in GroundSpecies.allCases {
            var v = YardView(min: V2(-5, -5), max: V2(5, 5))
            v.player.head = V3(0, 1.6, 4)
            v.cover = [V2(-3, -3)]; v.forage = [V2(1, -1)]
            let book = PerchBook()
            let b = GroundBrain(id: 1, profile: sp.profile, spawn: V2(-6, 0), yaw: -1.57, stay: 12, trust: 0, groundY: 0, seed: 3)
            var t: Float = 0
            var foraged = false
            while t < 120 && !b.isGone {
                b.update(dt: 1 / 60, view: v, book: book)
                XCTAssertFalse(b.position.x.isNaN)
                if b.phase == .foraging { foraged = true }
                t += 1 / 60
            }
            XCTAssertTrue(foraged, "\(sp) never foraged")
            XCTAssertTrue(b.isGone, "\(sp) never left (\(b.phase))")
        }
    }

    func testSpookedAnimalRuns() {
        var v = YardView(min: V2(-5, -5), max: V2(5, 5))
        v.player.head = V3(3, 1.6, 3)
        let b = GroundBrain(id: 1, profile: GroundSpecies.easternCottontail.profile, spawn: V2(0, 0), yaw: 0, stay: 60, trust: 0, groundY: 0, seed: 3)
        let book = PerchBook()
        for _ in 0..<300 { b.update(dt: 1 / 60, view: v, book: book) }
        v.player.head = V3(b.position.x + 0.5, 1.6, b.position.z); v.player.headSpeed = 2
        b.update(dt: 1 / 60, view: v, book: book)
        XCTAssertTrue(b.drainEvents().contains(.spooked))
        XCTAssertEqual(b.phase, .fleeing)
    }

    func testHabitatAndJournal() {
        let h = HabitatInventory.build(items: [("bird-feeder", 1), ("birdbath", 1), ("maple-tree", 1), ("lavender-clump", 1)], openArea: 30)
        XCTAssertGreaterThan(h.overall, 0.2)
        XCTAssertGreaterThan(h.attraction(.bird(.blackCappedChickadee)), h.attraction(.ground(.europeanHedgehog)) - 1)
        var j = Journal()
        let r = j.record(.visit(.bird(.easternBluebird)))
        XCTAssertTrue(r.contains { if case .newSpecies = $0 { true } else { false } })
        XCTAssertEqual(j.discovered, 1)
        _ = j.record(.handLanded(.bird(.easternBluebird)))
        XCTAssertGreaterThan(j.trust(.bird(.easternBluebird)), 0.1)
    }

    func testSchedulerSpawnsForGoodHabitat() {
        let h = HabitatInventory.build(items: [("bird-feeder", 1), ("birdbath", 1), ("maple-tree", 1), ("privet-hedge", 1), ("lavender-clump", 2)], openArea: 40)
        var s = VisitScheduler(seed: 5, firstVisitIn: 0.1)
        var seen = Set<AnimalKind>()
        let view = YardView()
        for _ in 0..<(60 * 600) { for r in s.tick(dt: 1 / 60, habitat: h, view: view, present: [], journal: Journal()) { seen.insert(r.kind) } }
        XCTAssertGreaterThan(seen.count, 3)
    }
}
