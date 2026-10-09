import simd
import RealityKit
import RealCore
import RealKit

/// A `RealScene` split on a square XZ grid for streaming. `core` stays resident (articulated rigs, lights,
/// far ground, statics larger than a tile, spots and lighting hints); each tile holds the singles and field
/// instances whose position falls inside it.
public struct RealTiledScene {
    public var grid: RealTileGrid
    public var core: RealScene
    public var tiles: [RealTileCoord: RealScene]
    public var coords: Set<RealTileCoord> { Set(tiles.keys) }

    /// Entity for one tile (nil when the tile is empty).
    @MainActor
    public func entity(_ c: RealTileCoord, materials: RealMaterialCache? = nil) async throws -> Entity? {
        guard let t = tiles[c] else { return nil }
        let e = try await t.entity(materials: materials)
        e.name = c.description
        return e
    }
}

public extension RealScene {
    /// Splits the scene into tiles of `tileSize` meters. Scene AO is baked once over the whole scene first,
    /// so tile seams shade the same as the unsplit scene. Statics whose bounds exceed `residentSize`
    /// (default: the tile size) stay in `core` so roads and slabs never pop with a tile.
    /// `batchCell` overrides the static batch cell inside tiles: use a divisor of `tileSize` so batches never straddle a tile edge.
    /// Pick `tileSize` as a multiple of the field cell size (16-18 m) to keep instancing cells whole.
    func tiled(tileSize: Float, origin: SIMD2<Float> = .zero, residentSize: Float? = nil, batchCell: Float? = nil) async -> RealTiledScene {
        let grid = RealTileGrid(tileSize: tileSize, origin: origin)
        let limit = residentSize ?? tileSize
        var statics = singles
        if let bake { statics = await Self.baked(statics, rigs: rigs, fields: fields, settings: bake) }

        var core = RealScene(name: name)
        core.rigs = rigs; core.lights = lights; core.camera = camera; core.spots = spots
        core.lighting = lighting; core.farGround = farGround
        core.batchStatics = batchStatics; core.batchCell = batchCell ?? self.batchCell

        var tiles: [RealTileCoord: RealScene] = [:]
        func tile(_ c: RealTileCoord) -> RealScene {
            if let t = tiles[c] { return t }
            var t = RealScene(name: "\(name):\(c)")
            t.farGround = nil
            t.batchStatics = batchStatics; t.batchCell = batchCell ?? self.batchCell
            return t
        }
        for var s in statics {
            s.bake = false
            let b = s.asset.levels[0].bounds
            if s.asset.levels[0].boundsDiagonal * s.at.scale.max() > limit { core.singles.append(s); continue }
            let c = grid.coord(s.at.point((b.min + b.max) / 2))
            var t = tile(c); t.singles.append(s); tiles[c] = t
        }
        for f in fields {
            var split: [RealTileCoord: [simd_float4x4]] = [:]
            for m in f.transforms { split[grid.coord(SIMD3(m.columns.3.x, m.columns.3.y, m.columns.3.z)), default: []].append(m) }
            for (c, list) in split {
                var t = tile(c); t.fields.append(.init(asset: f.asset, transforms: list, options: f.options)); tiles[c] = t
            }
        }
        return RealTiledScene(grid: grid, core: core, tiles: tiles)
    }
}

/// A streamed scene: add `root` to the RealityView content. `core` is always present; `streamer.root`
/// holds the tiles near the viewer.
@MainActor
public final class RealStreamedScene {
    public let root: Entity
    public let core: Entity
    public let streamer: RealWorldStreamer
    public let layout: RealTiledScene

    public init(_ layout: RealTiledScene, settings: RealWorldStreamer.Settings = .init(), materials: RealMaterialCache? = nil) async throws {
        self.layout = layout
        root = Entity()
        root.name = layout.core.name
        core = try await layout.core.entity(materials: materials)
        core.name = "core"
        streamer = RealWorldStreamer(name: "tiles", grid: layout.grid, available: layout.coords, settings: settings) { c in
            try await layout.entity(c, materials: materials)
        }
        root.addChild(core)
        root.addChild(streamer.root)
    }
}

public extension RealityHD {
    /// A catalog scene split into tiles and streamed around the viewer. `preloadAt` (scene space) loads the
    /// tiles around a start point before returning.
    @MainActor
    static func streamedScene(_ id: String, seed: UInt64 = 1, tileSize: Float = 32,
                              settings: RealWorldStreamer.Settings = .init(), batchCell: Float? = nil,
                              preloadAt: SIMD3<Float>? = nil) async throws -> RealStreamedScene {
        let layout = await Task.detached(priority: .userInitiated) { () -> RealTiledScene? in
            guard let s = SceneCatalog.build(id, seed: seed) else { return nil }
            return await s.tiled(tileSize: tileSize, batchCell: batchCell)
        }.value
        guard let layout else { throw RealityHDError.unknown(id) }
        let streamed = try await RealStreamedScene(layout, settings: settings)
        if let p = preloadAt { await streamed.streamer.preload(around: p) }
        return streamed
    }
}
