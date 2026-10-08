import XCTest
import RealityKit
@testable import RealKit
@testable import RealLibrary
import RealCore

final class StreamingTests: XCTestCase {
    func testGridCoordAndDistance() {
        let g = RealTileGrid(tileSize: 10)
        XCTAssertEqual(g.coord(SIMD3(0.5, 3, 9.9)), RealTileCoord(0, 0))
        XCTAssertEqual(g.coord(SIMD3(-0.1, 0, 10)), RealTileCoord(-1, 1))
        XCTAssertEqual(g.distance(from: SIMD3(5, 0, 5), to: RealTileCoord(0, 0)), 0)
        XCTAssertEqual(g.distance(from: SIMD3(5, 0, 5), to: RealTileCoord(2, 0)), 15, accuracy: 1e-5)
        let near = g.tiles(around: SIMD3(5, 0, 5), radius: 6)
        XCTAssertEqual(near.first, RealTileCoord(0, 0))
        XCTAssertEqual(Set(near), [RealTileCoord(0, 0), RealTileCoord(-1, 0), RealTileCoord(1, 0), RealTileCoord(0, -1), RealTileCoord(0, 1)])
    }

    func testTiledScenePreservesContent() async throws {
        let ids = ["lineman-district", "forest-glade"]
        for id in ids {
            guard let s = SceneCatalog.build(id, seed: 1) else { continue }
            let t = await s.tiled(tileSize: 32)
            let singles = t.core.singles.count + t.tiles.values.reduce(0) { $0 + $1.singles.count }
            let inst = t.tiles.values.reduce(0) { $0 + $1.fields.reduce(0) { $0 + $1.transforms.count } }
            XCTAssertEqual(singles, s.singles.count, id)
            XCTAssertEqual(inst, s.fields.reduce(0) { $0 + $1.transforms.count }, id)
            XCTAssertEqual(t.core.rigs.count, s.rigs.count, id)
            XCTAssertTrue(t.tiles.values.allSatisfy { $0.rigs.isEmpty && $0.lights.isEmpty && $0.farGround == nil }, id)
        }
    }

    @MainActor
    func testStreamerLoadsNearAndUnloadsFar() async throws {
        let grid = RealTileGrid(tileSize: 10)
        var loads = 0
        let s = RealWorldStreamer(grid: grid, settings: .init().with {
            $0.loadRadius = 5; $0.unloadRadius = 12; $0.maxConcurrentLoads = 16; $0.cacheLimit = 5; $0.lookAhead = 0
        }) { c in loads += 1; let e = Entity(); e.name = c.description; return e }
        await s.preload(around: SIMD3(5, 0, 5))
        XCTAssertEqual(s.activeCount, 5)
        XCTAssertEqual(s.state(RealTileCoord(0, 0)), .active)
        s.update(viewer: SIMD3(205, 0, 5))
        XCTAssertEqual(s.activeCount, 0)
        XCTAssertEqual(s.cachedCount, 5)
        while !s.isIdle { await Task.yield() }
        XCTAssertEqual(s.activeCount, 5)
        let before = loads
        s.update(viewer: SIMD3(5, 0, 5))
        XCTAssertEqual(s.activeCount, 5, "cache hits return synchronously")
        while !s.isIdle { await Task.yield() }
        XCTAssertEqual(s.activeCount, 5)
        XCTAssertEqual(loads - before, 0)
        s.unloadAll()
        XCTAssertEqual(s.root.children.count, 0)
    }

    @MainActor
    func testStreamerSkipsUnavailableTiles() async {
        let s = RealWorldStreamer(grid: RealTileGrid(tileSize: 10), available: [RealTileCoord(0, 0)]) { _ in Entity() }
        await s.preload(around: .zero, radius: 30)
        XCTAssertEqual(s.activeCount, 1)
    }
}
