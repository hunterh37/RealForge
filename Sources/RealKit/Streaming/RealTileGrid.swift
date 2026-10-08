import simd

/// Integer address of one square tile on the XZ plane.
public struct RealTileCoord: Hashable, Sendable, Comparable, CustomStringConvertible {
    public var x: Int32
    public var z: Int32
    public init(_ x: Int32, _ z: Int32) { self.x = x; self.z = z }
    public var description: String { "tile_\(x)_\(z)" }
    public static func < (a: Self, b: Self) -> Bool { a.x != b.x ? a.x < b.x : a.z < b.z }
}

/// Square XZ tiling of a world. Tile (0, 0) spans `origin ..< origin + tileSize` on X and Z.
public struct RealTileGrid: Sendable, Hashable {
    public var tileSize: Float
    public var origin: SIMD2<Float>

    public init(tileSize: Float, origin: SIMD2<Float> = .zero) {
        precondition(tileSize > 0, "tileSize must be positive")
        self.tileSize = tileSize; self.origin = origin
    }

    /// Tile containing a point (Y ignored).
    public func coord(_ p: SIMD3<Float>) -> RealTileCoord {
        let q = (SIMD2(p.x, p.z) - origin) / tileSize
        return RealTileCoord(Int32(q.x.rounded(.down)), Int32(q.y.rounded(.down)))
    }

    /// Tile center at y = 0.
    public func center(_ c: RealTileCoord) -> SIMD3<Float> {
        let m = origin + (SIMD2(Float(c.x), Float(c.z)) + 0.5) * tileSize
        return SIMD3(m.x, 0, m.y)
    }

    /// XZ distance from a point to the nearest edge of a tile (0 inside it).
    public func distance(from p: SIMD3<Float>, to c: RealTileCoord) -> Float {
        let lo = origin + SIMD2(Float(c.x), Float(c.z)) * tileSize
        let q = SIMD2(p.x, p.z)
        let d = simd_max(simd_max(lo - q, q - (lo + tileSize)), .zero)
        return simd_length(d)
    }

    /// Writes tiles within `radius` of `p` into `out` (cleared first), nearest first. Reuses `out`'s storage.
    public func tiles(around p: SIMD3<Float>, radius: Float, into out: inout [RealTileCoord]) {
        out.removeAll(keepingCapacity: true)
        let r = radius + 1e-3  // inclusive: a tile edge exactly at `radius` counts
        let lo = coord(p - SIMD3(r, 0, r)), hi = coord(p + SIMD3(r, 0, r))
        for x in lo.x...hi.x { for z in lo.z...hi.z {
            let c = RealTileCoord(x, z)
            if distance(from: p, to: c) <= radius { out.append(c) }
        }}
        out.sort { distance(from: p, to: $0) < distance(from: p, to: $1) }
    }

    public func tiles(around p: SIMD3<Float>, radius: Float) -> [RealTileCoord] {
        var out: [RealTileCoord] = []
        tiles(around: p, radius: radius, into: &out)
        return out
    }
}
