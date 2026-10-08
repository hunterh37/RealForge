import Testing
import Foundation
import simd
@testable import RealCore
@testable import RealLibrary
import RealMaterials

@Suite struct ArchitectureTests {
    static let footprints: [Footprint] = [
        .rect(width: 14, depth: 10), .l(width: 20, depth: 16, legWidth: 8, barDepth: 9),
        .u(width: 24, depth: 18, legWidth: 7, barDepth: 9), .courtyard(width: 26, depth: 22, ring: 9),
        .polygon([V2(-8, 6), V2(8, 6), V2(8, -2), V2(2, -2), V2(2, -6), V2(-8, -6)]),
    ]

    func hash(_ m: Model) -> Int {
        var h = Hasher()
        for s in m.surfaces { h.combine(s.material); h.combine(s.indices); for p in s.positions { h.combine(p.x); h.combine(p.y); h.combine(p.z) } }
        return h.finalize()
    }

    @Test func determinism() {
        for style in ArchStyle.ids {
            let spec = BuildingSpec(footprint: .rect(width: 15, depth: 11), floors: 3, style: style, seed: 9)
            let a = BuildingGenerator.build(spec), b = BuildingGenerator.build(spec)
            #expect(hash(a.combined().levels[0]) == hash(b.combined().levels[0]), "\(style) not deterministic")
            #expect(a.schedule == b.schedule)
            #expect(a.plans == b.plans)
        }
    }

    @Test(arguments: RoofType.allCases)
    func everyRoofAndFootprintBuilds(_ roof: RoofType) {
        for fp in Self.footprints {
            let spec = BuildingSpec(footprint: fp, floors: 3, style: "federal").with { $0.roof = roof }
            let b = BuildingGenerator.build(spec)
            for m in b.exterior.levels { #expect(m.triangleCount > 0) }
            for l in b.combined().levels { for s in l.surfaces {
                #expect(MaterialLibrary.keys.contains(baseKey(s.material)), "unknown material \(s.material)")
                #expect(s.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
                #expect(s.indices.allSatisfy { Int($0) < s.positions.count })
            }}
            #expect(b.schedule.roomCount > 0, "\(fp) \(roof) no rooms")
        }
    }

    @Test func scheduleCounts() {
        let spec = BuildingSpec(footprint: .rect(width: 15, depth: 11), floors: 3, style: "georgian")
        let b = BuildingGenerator.build(spec)
        let s = b.schedule
        var windows = 0, ext = 0, int = 0
        for p in b.plans { for w in p.walls { for o in w.openings {
            if o.kind == .window { windows += 1 } else if o.kind == .door { if w.exterior { ext += 1 } else { int += 1 } }
        }}}
        #expect(s.windowCount == windows)
        #expect(s.exteriorDoors == 1 && ext == 1)
        #expect(s.interiorDoors == int)
        #expect(s.roomCount == b.plans.flatMap(\.rooms).filter { $0.kind != .corridor && $0.kind != .stair }.count)
        #expect(abs(s.grossFloorArea - 15 * 11 * 3) < 0.01)
        #expect(s.netFloorArea < s.grossFloorArea && s.netFloorArea > s.grossFloorArea * 0.6)
        #expect(ArchStyle.georgian.glazingTarget.contains(s.glazingRatio) || (0.1...0.35).contains(s.glazingRatio), "glazing \(s.glazingRatio)")
        // Modernist glazing is much higher.
        let m = BuildingGenerator.build(spec.with { $0.style = "modernist" }).schedule
        #expect(m.glazingRatio > s.glazingRatio * 2)
        // Every room reachable: each non-corridor room has at least one doorway.
        for p in b.plans { for r in p.rooms where r.kind != .corridor {
            #expect(p.walls.contains { w in w.openings.contains { $0.kind != .window && $0.rooms.contains(r.id) } }, "floor \(p.floor) \(r.name) has no door")
        }}
    }

    /// Every plan door is a real hole: no wall triangle of that floor covers the door center.
    @Test func openingsAlignWithPlanDoors() {
        let spec = BuildingSpec(footprint: .l(width: 20, depth: 16, legWidth: 8, barDepth: 9), floors: 2, style: "italianate")
        let b = BuildingGenerator.build(spec)
        let walls = b.combined().levels[0].surfaces.filter { $0.material.hasPrefix("paint.wall") || $0.material.hasPrefix(spec.material(.groundFloor)) || $0.material == spec.material(.wall) }
        for p in b.plans {
            #expect(!p.doors.isEmpty)
            for d in p.doors {
                let q = V3(d.position.x, p.level + 1.0, d.position.y)
                let wall = p.walls[d.wall]
                let n = V3(wall.normal.x, 0, wall.normal.y)
                let mid = q + n * (wall.exterior ? -wall.thickness / 2 : 0)
                // Probe across the wall: a covered point would sit inside some wall box face set; test segment-triangle hits.
                let a = mid - n * 0.4, c = mid + n * 0.4
                var hit = false
                for s in walls { for t in stride(from: 0, to: s.indices.count, by: 3) where !hit {
                    hit = segmentHits(a, c, s.positions[Int(s.indices[t])], s.positions[Int(s.indices[t + 1])], s.positions[Int(s.indices[t + 2])])
                }}
                #expect(!hit, "floor \(p.floor) door at \(d.position) is covered by wall geometry")
            }
        }
    }

    func segmentHits(_ p: V3, _ q: V3, _ a: V3, _ b: V3, _ c: V3) -> Bool {
        let d = q - p, e1 = b - a, e2 = c - a
        let h = simd_cross(d, e2), det = simd_dot(e1, h)
        guard abs(det) > 1e-9 else { return false }
        let f = 1 / det, s = p - a, u = f * simd_dot(s, h)
        guard u >= 0, u <= 1 else { return false }
        let qv = simd_cross(s, e1), v = f * simd_dot(d, qv)
        guard v >= 0, u + v <= 1 else { return false }
        let t = f * simd_dot(e2, qv)
        return t > 0 && t < 1
    }

    @Test func codableRoundTrip() throws {
        var spec = BuildingSpec(footprint: .u(width: 24, depth: 18, legWidth: 7, barDepth: 9), floors: 4, style: "haussmann", seed: 5)
        spec.facades = [FacadeOverride(facade: 0, bays: 7, doorBays: [3], windowTypes: [0: .storefront, 3: .casement], blankBays: [0])]
        spec.materials[.wall] = "rock.sandstone"
        spec.pieces[.window] = "double-hung-window"
        let back = try BuildingSpec.from(json: spec.json())
        #expect(back == spec)
        let plans = BuildingGenerator.build(spec).plans
        let decoded = try JSONDecoder().decode([FloorPlan].self, from: JSONEncoder().encode(plans))
        #expect(decoded == plans)
        // Edited rooms drive the walls.
        var edited = spec
        var rooms = plans[1].rooms
        rooms[rooms.count - 1].name = "Library"
        edited.roomOverrides[1] = rooms
        let e = BuildingGenerator.build(edited)
        #expect(e.plans[1].rooms.contains { $0.name == "Library" })
        #expect(e.schedule.rooms.contains { $0.name == "Library" && $0.area > 0 })
        for s in ArchStyle.presets { #expect(try JSONDecoder().decode(ArchStyle.self, from: JSONEncoder().encode(s)) == s) }
        let city = CitySpec.street(columns: 10).with { $0.addLot(CityLot(column: 0, row: 0, width: 4, depth: 4, building: nil), spec: spec) }
        #expect(try CitySpec.from(json: city.json()) == city)
    }

    @Test func injectedPiecesById() {
        var reg = FacadePieceRegistry()
        reg.register("test-window") { ctx in
            var m = MeshBucket(); m.aabb(center: V3(0, ctx.height / 2, 0.05), size: V3(ctx.width, ctx.height, 0.1), "metal.chrome"); return m.model("w")
        }
        let spec = BuildingSpec().with { $0.pieces[.window] = "test-window" }
        let b = BuildingGenerator(provider: reg).build(spec)
        #expect(b.exterior.levels[0].materials.contains("metal.chrome"))
        // Catalog asset ids resolve too.
        let c = BuildingGenerator.build(BuildingSpec().with { $0.pieces[.window] = "office-window" })
        #expect(c.exterior.levels[0].triangleCount > 0)
    }

    @Test func budget() {
        let a = GeneratedBuilding().build(seed: 1)
        #expect(a.levels[0].triangleCount <= GeneratedBuilding.budget)
        for i in 1..<a.levels.count { #expect(a.levels[i].triangleCount <= a.levels[i - 1].triangleCount) }
        let scene = CityBlock().build(seed: 1)
        #expect(scene.worstCaseTriangles < 1_000_000, "city-block \(scene.worstCaseTriangles)")
    }
}

extension CitySpec {
    func with(_ edit: (inout CitySpec) -> Void) -> CitySpec { var c = self; edit(&c); return c }
}
