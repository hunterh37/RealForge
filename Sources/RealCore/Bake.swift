import simd
import Dispatch

/// Scene-level ambient occlusion baked into vertex `occlusion`: contact shadows under furniture, dark
/// room corners, the floor beneath a desk. Rays from each receiver vertex test a BVH of every occluder
/// triangle; nothing is computed per frame and nothing is added to the GPU.
public enum AOBake {
    public struct Settings: Sendable {
        /// Hemisphere rays per vertex.
        public var rays: Int = 24
        /// Occluders farther than this (meters) do not darken.
        public var distance: Float = 1.2
        /// 0 = no effect, 1 = full ambient occlusion.
        public var strength: Float = 0.85
        /// Darkest allowed result.
        public var floor: Float = 0.25
        public init(rays: Int = 24, distance: Float = 1.2, strength: Float = 0.85, floor: Float = 0.25) {
            self.rays = rays; self.distance = distance; self.strength = strength; self.floor = floor
        }
        public static let interior = Settings()
    }

    /// Multiplies hemisphere visibility into every receiver's `occlusion`. Receivers and occluders are
    /// in one space (world). Receivers also occlude.
    public static func bake(_ receivers: inout [Model], occluders: [Model], settings: Settings = .interior) {
        var tris: [V3] = []
        for m in occluders + receivers { for s in m.surfaces where !isGlass(s.material) {
            tris.reserveCapacity(tris.count + s.indices.count)
            for i in s.indices { tris.append(s.positions[Int(i)]) }
        }}
        guard !tris.isEmpty else { return }
        let bvh = BVH(triangles: tris)
        let dirs = hemisphere(settings.rays)
        for mi in receivers.indices { for si in receivers[mi].surfaces.indices {
            var s = receivers[mi].surfaces[si]
            if s.normals.count != s.positions.count { s.recomputeNormals() }
            if s.occlusion.count != s.positions.count { s.occlusion = Array(repeating: 1, count: s.positions.count) }
            let n = s.positions.count
            var result = [Float](repeating: 1, count: n)
            let chunk = 512
            let pos = s.positions, nor = s.normals
            result.withUnsafeMutableBufferPointer { out in
                let outPtr = out
                DispatchQueue.concurrentPerform(iterations: (n + chunk - 1) / chunk) { c in
                    for v in (c * chunk)..<min(n, (c + 1) * chunk) {
                        outPtr[v] = visibility(pos[v], nor[v], seed: UInt32(truncatingIfNeeded: v &* 2654435761), dirs: dirs, bvh: bvh, settings: settings)
                    }
                }
            }
            for v in 0..<n { s.occlusion[v] *= result[v] }
            receivers[mi].surfaces[si] = s
        }}
    }

    static func isGlass(_ key: MaterialKey) -> Bool { key.hasPrefix("glass.") || key.hasPrefix("water.") }

    /// Cosine-weighted hemisphere (Fibonacci spiral, +Z up).
    static func hemisphere(_ n: Int) -> [V3] {
        (0..<n).map { i in
            let u = (Float(i) + 0.5) / Float(n), r = u.squareRoot(), a = Float(i) * 2.399963
            return V3(r * cos(a), r * sin(a), (1 - u).squareRoot())
        }
    }

    static func visibility(_ p: V3, _ nIn: V3, seed: UInt32, dirs: [V3], bvh: BVH, settings: Settings) -> Float {
        let n = simd_length_squared(nIn) > 1e-8 ? simd_normalize(nIn) : V3(0, 1, 0)
        let t = n.anyPerpendicular, b = simd_cross(n, t)
        // Per-vertex rotation of the ray set removes banding between neighbors.
        let rot = Float(seed % 1024) / 1024 * 2 * .pi
        let cr = cos(rot), sr = sin(rot)
        let origin = p + n * 0.004
        var occ: Float = 0
        for d in dirs {
            let x = d.x * cr - d.y * sr, y = d.x * sr + d.y * cr
            let w = t * x + b * y + n * d.z
            if let hit = bvh.firstHit(origin, w, tMax: settings.distance) {
                let f = hit / settings.distance
                occ += 1 - f * f
            }
        }
        let ao = 1 - occ / Float(dirs.count)
        return max(settings.floor, 1 - settings.strength * (1 - ao))
    }
}

/// Bounding volume hierarchy over a triangle soup (3 positions per triangle). Median split on the
/// longest centroid axis; any-hit and nearest-hit queries.
public struct BVH: Sendable {
    struct Node: Sendable { var lo: V3; var hi: V3; var first: Int32; var count: Int32; var right: Int32 }
    var nodes: [Node] = []
    var v0: [V3] = [], e1: [V3] = [], e2: [V3] = []

    public init(triangles t: [V3]) {
        let n = t.count / 3
        var order = Array(0..<n)
        var cen = [V3](repeating: .zero, count: n), tlo = cen, thi = cen
        for i in 0..<n {
            let a = t[i * 3], b = t[i * 3 + 1], c = t[i * 3 + 2]
            cen[i] = (a + b + c) / 3; tlo[i] = simd_min(a, simd_min(b, c)); thi[i] = simd_max(a, simd_max(b, c))
        }
        nodes.reserveCapacity(2 * n / 4 + 1)
        func build(_ start: Int, _ end: Int) -> Int32 {
            var lo = V3(repeating: .greatestFiniteMagnitude), hi = -lo, clo = lo, chi = hi
            for k in start..<end { let i = order[k]; lo = simd_min(lo, tlo[i]); hi = simd_max(hi, thi[i]); clo = simd_min(clo, cen[i]); chi = simd_max(chi, cen[i]) }
            let me = Int32(nodes.count)
            nodes.append(Node(lo: lo, hi: hi, first: Int32(start), count: Int32(end - start), right: -1))
            if end - start <= 4 { return me }
            let ext = chi - clo
            let axis = ext.x > ext.y ? (ext.x > ext.z ? 0 : 2) : (ext.y > ext.z ? 1 : 2)
            if ext[axis] < 1e-7 { return me }
            let mid = (start + end) / 2
            order[start..<end].sort { cen[$0][axis] < cen[$1][axis] }
            _ = build(start, mid)
            let r = build(mid, end)
            nodes[Int(me)].count = 0
            nodes[Int(me)].right = r
            return me
        }
        if n > 0 { _ = build(0, n) }
        v0.reserveCapacity(n); e1.reserveCapacity(n); e2.reserveCapacity(n)
        for i in order { let a = t[i * 3]; v0.append(a); e1.append(t[i * 3 + 1] - a); e2.append(t[i * 3 + 2] - a) }
    }

    @inline(__always) static func slab(_ o: V3, _ inv: V3, _ lo: V3, _ hi: V3, _ tMax: Float) -> Bool {
        let t0 = (lo - o) * inv, t1 = (hi - o) * inv
        let tn = simd_reduce_max(simd_min(t0, t1)), tf = simd_reduce_min(simd_max(t0, t1))
        return tf >= max(tn, 0) && tn <= tMax
    }

    /// Distance to the nearest triangle hit along `d` (unit) within `tMax`, or nil.
    public func firstHit(_ o: V3, _ d: V3, tMax: Float) -> Float? {
        guard !nodes.isEmpty else { return nil }
        let inv = V3(1 / (abs(d.x) > 1e-9 ? d.x : 1e-9), 1 / (abs(d.y) > 1e-9 ? d.y : 1e-9), 1 / (abs(d.z) > 1e-9 ? d.z : 1e-9))
        var best = tMax
        var hit = false
        return withUnsafeTemporaryAllocation(of: Int32.self, capacity: 64) { stack -> Float? in
        var sp = 1
        stack[0] = 0
        while sp > 0 {
            sp -= 1
            let ni = Int(stack[sp])
            let node = nodes[ni]
            guard Self.slab(o, inv, node.lo, node.hi, best) else { continue }
            if node.count > 0 {
                for k in Int(node.first)..<Int(node.first + node.count) {
                    let p = simd_cross(d, e2[k])
                    let det = simd_dot(e1[k], p)
                    if abs(det) < 1e-10 { continue }
                    let id = 1 / det, s = o - v0[k]
                    let u = simd_dot(s, p) * id
                    if u < 0 || u > 1 { continue }
                    let q = simd_cross(s, e1[k])
                    let v = simd_dot(d, q) * id
                    if v < 0 || u + v > 1 { continue }
                    let t = simd_dot(e2[k], q) * id
                    if t > 1e-4 && t < best { best = t; hit = true }
                }
            } else if sp + 2 <= stack.count {
                stack[sp] = node.right; stack[sp + 1] = Int32(ni + 1); sp += 2
            }
        }
        return hit ? best : nil
        }
    }
}
