import Foundation
import RealityKit

/// Loads tiles of a large world near the viewer and unloads the rest. Attach `root` to the scene; the
/// `RealStreamingSystem` drives it from `RealViewer.position` (call `update(viewer:)` yourself without it).
///
/// Tiles inside `loadRadius` load nearest first, at most `maxConcurrentLoads` at a time. Tiles past
/// `unloadRadius` (larger, so a boundary does not thrash) leave the scene: they park disabled in an LRU
/// cache of `cacheLimit` tiles for a fast return, then their entities are released. In-flight loads that
/// fall out of range are cancelled. Memory pressure empties the cache.
@MainActor
public final class RealWorldStreamer {
    public struct Settings: Sendable, Hashable {
        /// Tiles whose nearest edge is within this XZ distance (meters) load.
        public var loadRadius: Float = 60
        /// Loaded tiles beyond this distance unload. Kept >= loadRadius.
        public var unloadRadius: Float = 80
        /// Tile builds running at once. Each build runs mesh upload on the main actor; 1-2 keeps frames smooth.
        public var maxConcurrentLoads = 2
        /// Unloaded tiles kept disabled in memory for a fast return (0 = release immediately).
        public var cacheLimit = 8
        /// Seconds between streaming evaluations.
        public var interval: Double = 0.25
        /// Seconds of viewer motion to look ahead: tiles near the predicted position load early.
        public var lookAhead: Float = 1.5
        public init() {}
        public func with(_ edit: (inout Settings) -> Void) -> Settings { var c = self; edit(&c); return c }
    }

    public enum TileState: Sendable, Equatable { case loading, active, cached, empty }

    public typealias Loader = @MainActor (RealTileCoord) async throws -> Entity?

    public let root: Entity
    public let grid: RealTileGrid
    public var settings: Settings
    /// Tiles known to have content (nil = ask the loader for any tile in range).
    public let available: Set<RealTileCoord>?
    /// Called after a tile entity enters / leaves the scene (cache parking counts as leaving).
    public var onTileActivated: ((RealTileCoord, Entity) -> Void)?
    public var onTileDeactivated: ((RealTileCoord, Entity) -> Void)?

    private let loader: Loader
    private var active: [RealTileCoord: Entity] = [:]
    private var cache: [RealTileCoord: Entity] = [:]
    private var cacheOrder: [RealTileCoord] = []
    private var loading: [RealTileCoord: (id: Int, task: Task<Void, Never>)] = [:]
    private var nextLoadID = 0
    private var empty: Set<RealTileCoord> = []
    private var wanted: [RealTileCoord] = []
    private var ahead: [RealTileCoord] = []
    private var lastViewer: SIMD3<Float>?
    private var velocity: SIMD3<Float> = .zero
    private var accumulator: Double = .greatestFiniteMagnitude
    private var memoryPressure: DispatchSourceMemoryPressure?

    public init(name: String = "streamed-world", grid: RealTileGrid, available: Set<RealTileCoord>? = nil,
                settings: Settings = Settings(), loader: @escaping Loader) {
        root = Entity()
        root.name = name
        self.grid = grid; self.available = available; self.settings = settings; self.loader = loader
        root.components.set(RealStreamingComponent(streamer: self))
        let src = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        src.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.purgeCache() } }
        src.resume()
        memoryPressure = src
    }

    deinit { memoryPressure?.cancel() }

    // MARK: state

    public func state(_ c: RealTileCoord) -> TileState? {
        if active[c] != nil { return .active }
        if loading[c] != nil { return .loading }
        if cache[c] != nil { return .cached }
        return empty.contains(c) ? .empty : nil
    }
    public var activeTiles: [RealTileCoord: Entity] { active }
    public var activeCount: Int { active.count }
    public var cachedCount: Int { cache.count }
    public var loadingCount: Int { loading.count }
    public var isIdle: Bool { loading.isEmpty }

    // MARK: driving

    /// Called by `RealStreamingSystem`; throttled to `settings.interval`.
    func tick(deltaTime: Double, viewer: SIMD3<Float>) {
        accumulator += deltaTime
        guard accumulator >= settings.interval else { return }
        let dt = Float(min(accumulator, 1))
        accumulator = 0
        update(viewer: viewer, deltaTime: dt)
    }

    /// One streaming step. `viewer` is in scene (world) space; the root may be moved or scaled freely.
    public func update(viewer: SIMD3<Float>, deltaTime: Float = 0) {
        let p = root.scene != nil ? root.convert(position: viewer, from: nil) : viewer
        if let last = lastViewer, deltaTime > 0 {
            let v = (p - last) / deltaTime
            // Teleports (> 50 m/s) reset the estimate instead of predicting along the jump.
            velocity = simd_length(v) > 50 ? .zero : simd_mix(velocity, v, SIMD3(repeating: 0.5))
        }
        lastViewer = p
        let loadR = settings.loadRadius, unloadR = max(settings.unloadRadius, settings.loadRadius)
        let predicted = p + velocity * settings.lookAhead

        grid.tiles(around: p, radius: loadR, into: &wanted)
        if settings.lookAhead > 0, simd_length_squared(velocity) > 0.01 {
            grid.tiles(around: predicted, radius: loadR, into: &ahead)
            for c in ahead where !wanted.contains(c) { wanted.append(c) }
        }

        // Unload: anything loaded or loading that is far from both the viewer and the prediction.
        func far(_ c: RealTileCoord) -> Bool {
            grid.distance(from: p, to: c) > unloadR && grid.distance(from: predicted, to: c) > unloadR
        }
        // Cache hits first, so parking far tiles below cannot evict a tile about to return.
        for c in wanted where active[c] == nil {
            if let e = cache.removeValue(forKey: c) { cacheOrder.removeAll { $0 == c }; activate(c, e) }
        }
        for (c, e) in active where far(c) { deactivate(c, e) }
        for (c, l) in loading where far(c) { l.task.cancel(); loading[c] = nil }

        // Builds: nearest first, up to the concurrency limit.
        for c in wanted where loading.count < settings.maxConcurrentLoads {
            if active[c] != nil || loading[c] != nil || empty.contains(c) { continue }
            if let a = available, !a.contains(c) { continue }
            startLoad(c)
        }
    }

    /// Loads every tile within `radius` (default `loadRadius`) of `viewer` and waits for them. Use before
    /// revealing the world so the spawn area is complete.
    public func preload(around viewer: SIMD3<Float>, radius: Float? = nil) async {
        let p = root.scene != nil ? root.convert(position: viewer, from: nil) : viewer
        lastViewer = p
        for c in grid.tiles(around: p, radius: radius ?? settings.loadRadius) {
            if active[c] != nil || empty.contains(c) { continue }
            if let a = available, !a.contains(c) { continue }
            if let e = cache.removeValue(forKey: c) { cacheOrder.removeAll { $0 == c }; activate(c, e); continue }
            if let l = loading[c] { await l.task.value; continue }
            startLoad(c)
            await loading[c]?.task.value
        }
    }

    /// Removes and releases every tile and cancels pending loads.
    public func unloadAll() {
        for (_, l) in loading { l.task.cancel() }
        loading.removeAll()
        for (c, e) in active { e.removeFromParent(); onTileDeactivated?(c, e) }
        active.removeAll()
        purgeCache()
        lastViewer = nil
        velocity = .zero
    }

    /// Releases cached (parked) tiles.
    public func purgeCache() {
        for (_, e) in cache { e.removeFromParent() }
        cache.removeAll()
        cacheOrder.removeAll()
    }

    // MARK: internals

    private func startLoad(_ c: RealTileCoord) {
        let loader = self.loader
        nextLoadID += 1
        let id = nextLoadID
        let task = Task { [weak self] in
            let e = try? await loader(c)
            // A cancelled or superseded load drops its result.
            guard let self, !Task.isCancelled, self.loading[c]?.id == id else { return }
            self.loading[c] = nil
            guard let e else { self.empty.insert(c); return }
            e.name = e.name.isEmpty ? c.description : e.name
            self.activate(c, e)
        }
        loading[c] = (id, task)
    }

    private func activate(_ c: RealTileCoord, _ e: Entity) {
        e.isEnabled = true
        if e.parent !== root { root.addChild(e) }
        active[c] = e
        onTileActivated?(c, e)
    }

    private func deactivate(_ c: RealTileCoord, _ e: Entity) {
        active[c] = nil
        onTileDeactivated?(c, e)
        guard settings.cacheLimit > 0 else { e.removeFromParent(); return }
        // Parked tiles stay parented but disabled: no rendering, no systems, instant return.
        e.isEnabled = false
        cache[c] = e
        cacheOrder.append(c)
        while cacheOrder.count > settings.cacheLimit {
            let old = cacheOrder.removeFirst()
            cache.removeValue(forKey: old)?.removeFromParent()
        }
    }
}

/// Marks a streamed world root. Registered by `RealKitSetup.register()`.
public struct RealStreamingComponent: Component {
    public let streamer: RealWorldStreamer
    public init(streamer: RealWorldStreamer) { self.streamer = streamer }
}

/// Ticks every `RealWorldStreamer` in the scene from `RealViewer.position`.
public struct RealStreamingSystem: System {
    static let query = EntityQuery(where: .has(RealStreamingComponent.self))
    public init(scene: RealityKit.Scene) {}

    public mutating func update(context: SceneUpdateContext) {
        let dt = context.deltaTime
        for e in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let s = e.components[RealStreamingComponent.self]?.streamer else { continue }
            MainActor.assumeIsolated { s.tick(deltaTime: dt, viewer: RealViewer.position) }
        }
    }
}
