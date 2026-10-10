import XCTest
import simd
@testable import AnimalCore

final class BirdBrainTests: XCTestCase {
    func yard() -> (YardView, PerchBook) {
        var v = YardView(min: V2(-5, -5), max: V2(5, 5))
        v.player.head = V3(0, 1.6, 3)
        let b = PerchBook()
        b.replace(with: [
            PerchSite(id: 0, kind: .feeder, position: V3(1, 1.5, -1), facing: 0, radius: 0.015, itemID: "bird-feeder"),
            PerchSite(id: 0, kind: .rim, position: V3(-1.5, 0.8, -1.5), radius: 0.03, itemID: "birdbath"),
            PerchSite(id: 0, kind: .branch, position: V3(2, 3, -2), radius: 0.02, itemID: "maple-tree"),
            PerchSite(id: 0, kind: .rail, position: V3(-2, 1.0, 1), radius: 0.04, itemID: "picket-fence"),
        ])
        return (v, b)
    }

    func run(_ brain: BirdBrain, seconds: Float, view: YardView, book: PerchBook, until: (BirdBrain) -> Bool = { _ in false }) -> Float {
        var t: Float = 0
        while t < seconds {
            brain.update(dt: 1 / 60, view: view, book: book)
            XCTAssertFalse(brain.body.position.x.isNaN || brain.body.position.y.isNaN || brain.body.position.z.isNaN, "NaN at \(t)")
            t += 1 / 60
            if until(brain) { break }
        }
        return t
    }

    func testEverySpeciesLandsPerchesAndLeaves() {
        for sp in BirdSpecies.allCases {
            let (view, book) = yard()
            let b = BirdBrain(id: 1, profile: sp.profile, spawn: V3(-8, 4, 6), yaw: 0.5, stay: 14, trust: 0, seed: 7)
            var landed = false
            _ = run(b, seconds: 40, view: view, book: book) { br in
                if br.isPerched || br.phase == .hover { landed = true }
                return landed
            }
            XCTAssertTrue(landed, "\(sp) never landed (phase \(b.phase))")
            if let s = b.currentSite, b.isPerched {
                let target = s.position + V3(0, b.profile.anatomy.standHeight, 0)
                if s.kind != .ground { XCTAssertLessThan(simd_distance(b.body.position, target), 0.05, "\(sp) not on site") }
            }
            _ = run(b, seconds: 90, view: view, book: book) { $0.isGone }
            XCTAssertTrue(b.isGone, "\(sp) never left (phase \(b.phase))")
        }
    }

    func testLandingIsSlowAtTouchdown() {
        let (view, book) = yard()
        let b = BirdBrain(id: 1, profile: BirdSpecies.americanRobin.profile, spawn: V3(-6, 3, 4), yaw: 0, stay: 30, trust: 0, seed: 3)
        var minSpeedAtTouch: Float = 99
        var prev = b.body.position
        var lastPhase = b.phase
        for _ in 0..<(60 * 30) {
            b.update(dt: 1 / 60, view: view, book: book)
            if lastPhase == .landing && b.phase == .perched { minSpeedAtTouch = simd_distance(prev, b.body.position) * 60 }
            lastPhase = b.phase; prev = b.body.position
            if b.isPerched { break }
        }
        XCTAssertLessThan(minSpeedAtTouch, 1.2)
    }

    func testHandOfferBringsBirdToPalm() {
        var (view, book) = yard()
        let b = BirdBrain(id: 1, profile: BirdSpecies.blackCappedChickadee.profile, spawn: V3(-4, 3, 3), yaw: 0, stay: 60, trust: 0.4, seed: 11)
        _ = run(b, seconds: 20, view: view, book: book) { $0.isPerched }
        XCTAssertTrue(b.isPerched)
        let palm = V3(0.6, 1.2, 1.2)
        var onHand = false
        var t: Float = 0
        while t < 25 {
            view.player.hand = HandOffer(palm: palm, normal: V3(0, 1, 0), fingers: V3(0, 0, -1), speed: 0.05, steady: 2 + t)
            book.setHand(PerchSite(id: 0, kind: .hand, position: palm + V3(0, 0.01, 0), radius: 0.03))
            b.update(dt: 1 / 60, view: view, book: book)
            t += 1 / 60
            if b.onHand { onHand = true; break }
        }
        XCTAssertTrue(onHand, "bird never landed on the hand (phase \(b.phase))")
        XCTAssertLessThan(simd_distance(b.body.position, palm), 0.2)
    }

    func testFastMovementSpooksPerchedBird() {
        var (view, book) = yard()
        let b = BirdBrain(id: 1, profile: BirdSpecies.americanGoldfinch.profile, spawn: V3(-4, 3, 3), yaw: 0, stay: 60, trust: 0, seed: 5)
        _ = run(b, seconds: 25, view: view, book: book) { $0.isPerched }
        XCTAssertTrue(b.isPerched)
        let p = b.body.position
        view.player.head = p + V3(0, 0, 1)
        view.player.headSpeed = 2
        b.update(dt: 1 / 60, view: view, book: book)
        XCTAssertTrue(b.drainEvents().contains(.spooked))
        XCTAssertNotEqual(b.phase, .perched)
        _ = run(b, seconds: 30, view: view, book: book) { $0.isGone }
        XCTAssertTrue(b.isGone)
    }

    func testMotionPoseRangesAreRespected() {
        for sp in BirdSpecies.allCases {
            var i = BirdMotionInput()
            i.fold = 0; i.flap = 1; i.legs = 1
            for k in 0..<20 {
                i.phase = Float(k) / 20
                let q = BirdMotion.pose(sp.profile, i)
                for j in BirdJoint.all { XCTAssertTrue(j.range.contains(q[j]), "\(sp) \(j.name) \(q[j])") }
            }
        }
    }
}
