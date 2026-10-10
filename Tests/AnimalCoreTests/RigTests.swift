import XCTest
@testable import AnimalCore

final class RigTests: XCTestCase {
    func testTenBirdsAndFourGroundAnimals() {
        XCTAssertEqual(BirdSpecies.allCases.count, 10)
        XCTAssertEqual(GroundSpecies.allCases.count, 4)
        XCTAssertEqual(AnimalKind.all.count, 14)
    }

    func testBirdRigsBuildAndValidate() {
        for s in BirdSpecies.allCases {
            let r = BirdRigBuilder.build(s.profile)
            XCTAssertEqual(r.joints.count, BirdJoint.count)
            XCTAssertEqual(r.rig.validate(), [], "\(s)")
            XCTAssertGreaterThan(r.triangleCount, 3000, "\(s)")
            XCTAssertLessThan(r.triangleCount, 15000, "\(s)")
        }
    }

    func testBirdRigDeterministic() {
        let a = BirdRigBuilder.build(BirdSpecies.blueJay.profile, seed: 4), b = BirdRigBuilder.build(BirdSpecies.blueJay.profile, seed: 4)
        XCTAssertEqual(a.rig.base[0].surfaces.map(\.positions), b.rig.base[0].surfaces.map(\.positions))
    }

    func testGroundRigsBuild() {
        for s in GroundSpecies.allCases {
            let r = GroundRigBuilder.build(s.profile)
            XCTAssertEqual(r.joints.count, GroundJoint.count)
            XCTAssertEqual(r.rig.validate(), [], "\(s)")
            XCTAssertGreaterThan(r.triangleCount, 2000)
            XCTAssertGreaterThan(r.comHeight, 0.03)
        }
    }

    func testMaterialKeysUniqueAndComplete() {
        var keys = Set<String>()
        for s in BirdSpecies.allCases { for m in FaunaMaterials.specs(for: s.profile) { XCTAssertTrue(keys.insert(m.key).inserted, m.key) } }
        for s in GroundSpecies.allCases { for m in FaunaMaterials.specs(for: s.profile) { XCTAssertTrue(keys.insert(m.key).inserted, m.key) } }
        for s in BirdSpecies.allCases {
            let r = BirdRigBuilder.build(s.profile)
            let have = Set(FaunaMaterials.specs(for: s.profile).map(\.key))
            for m in r.rig.base[0].materials + r.rig.parts.flatMap({ $0.levels[0].materials }) { XCTAssertTrue(have.contains(m), "\(s) missing \(m)") }
        }
    }

    func testLoftNormalsPointOutward() {
        let r = BirdRigBuilder.build(BirdSpecies.americanRobin.profile)
        guard let body = r.rig.base[0].surfaces.first(where: { $0.material.hasSuffix(".body") }) else { return XCTFail() }
        let c = body.positions.reduce(V3.zero, +) / Float(body.positions.count)
        var out = 0
        for (p, n) in zip(body.positions, body.normals) where simd_dot(n, p - c) > 0 { out += 1 }
        XCTAssertGreaterThan(Float(out) / Float(body.positions.count), 0.9)
    }
}
