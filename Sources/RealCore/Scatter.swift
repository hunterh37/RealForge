import simd

/// Placement helpers for scenes (deterministic, grid-accelerated dart throwing).
public enum Scatter {
    /// Up to `count` points in an annulus with a minimum spacing. `accept` can reject by position.
    public static func poisson(count: Int, outerRadius: Float, innerRadius: Float = 0, minSpacing: Float, seed: UInt64,
                               maxTries: Int = 30, accept: ((V2) -> Bool)? = nil) -> [V2] {
        var rng = SeededRNG(seed: seed)
        let cell = max(minSpacing / 1.4142, 1e-3)
        var grid: [SIMD2<Int32>: V2] = [:]
        var pts: [V2] = []
        var attempts = 0
        while pts.count < count && attempts < count * maxTries {
            attempts += 1
            let p = rng.inDisc(radius: outerRadius)
            if simd_length(p) < innerRadius { continue }
            if let accept, !accept(p) { continue }
            let c = SIMD2<Int32>(Int32((p.x / cell).rounded(.down)), Int32((p.y / cell).rounded(.down)))
            var ok = true
            outer: for dy in -2...2 { for dx in -2...2 {
                if let q = grid[c &+ SIMD2(Int32(dx), Int32(dy))], simd_distance(p, q) < minSpacing { ok = false; break outer }
            }}
            if ok { grid[c] = p; pts.append(p) }
        }
        return pts
    }

    /// Dense random points (no spacing test) for grass and pebbles.
    public static func uniform(count: Int, outerRadius: Float, innerRadius: Float = 0, seed: UInt64, accept: ((V2) -> Bool)? = nil) -> [V2] {
        var rng = SeededRNG(seed: seed)
        var pts: [V2] = []
        var guardN = 0
        while pts.count < count && guardN < count * 20 {
            guardN += 1
            let p = rng.inDisc(radius: outerRadius)
            if simd_length(p) < innerRadius { continue }
            if let accept, !accept(p) { continue }
            pts.append(p)
        }
        return pts
    }
}
