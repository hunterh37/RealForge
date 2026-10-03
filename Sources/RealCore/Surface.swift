import simd

/// Material slot names. RealKit maps each to a cached PBR material backed by GPU-generated textures.
/// Format: "<family>.<variant>", e.g. "bark.oak", "leaf.oak", "metal.painted:1F4F2A".
public typealias MaterialKey = String

/// Indexed triangle soup with smooth normals, UV0, tangent frame (xyz + handedness in w) and an
/// optional per-vertex scalar in `extra` (wind weight for foliage, AO for props). One material.
public struct Surface: Sendable {
    public var material: MaterialKey
    public var positions: [V3] = []
    public var normals: [V3] = []
    public var uvs: [V2] = []
    public var tangents: [V4] = []
    /// x: wind/bend weight (0 at anchor, 1 at tip). y: per-object phase. Default 0.
    public var extra: [V2] = []
    /// Baked per-vertex ambient occlusion (1 = open). Feeds the shader's AO and darkens albedo.
    public var occlusion: [Float] = []
    public var indices: [UInt32] = []

    public init(material: MaterialKey) { self.material = material }

    public var vertexCount: Int { positions.count }
    public var triangleCount: Int { indices.count / 3 }
    public var isEmpty: Bool { indices.isEmpty }

    @discardableResult
    public mutating func add(_ p: V3, _ n: V3, _ uv: V2, extra e: V2 = .zero) -> UInt32 {
        positions.append(p); normals.append(n); uvs.append(uv); extra.append(e); occlusion.append(1)
        return UInt32(positions.count - 1)
    }
    public mutating func tri(_ a: UInt32, _ b: UInt32, _ c: UInt32) { indices += [a, b, c] }
    public mutating func quad(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ d: UInt32) { indices += [a, b, c, a, c, d] }

    public mutating func append(_ o: Surface, _ x: Xform = .identity) {
        let base = UInt32(positions.count)
        if x == .identity {
            positions += o.positions; normals += o.normals
        } else {
            positions += o.positions.map(x.point); normals += o.normals.map(x.normal)
        }
        uvs += o.uvs
        extra += o.extra.count == o.positions.count ? o.extra : Array(repeating: .zero, count: o.positions.count)
        occlusion += o.occlusion.count == o.positions.count ? o.occlusion : Array(repeating: 1, count: o.positions.count)
        if !o.tangents.isEmpty && tangents.count == base {
            tangents += x == .identity ? o.tangents : o.tangents.map { V4(x.direction(V3($0.x, $0.y, $0.z)), $0.w) }
        } else { tangents = [] }
        indices += o.indices.map { $0 + base }
    }

    public func transformed(_ x: Xform) -> Surface { var s = Surface(material: material); s.append(self, x); return s }

    public var bounds: (min: V3, max: V3) {
        guard var lo = positions.first else { return (.zero, .zero) }
        var hi = lo
        for p in positions { lo = simd_min(lo, p); hi = simd_max(hi, p) }
        return (lo, hi)
    }

    /// Area-weighted smooth normals. Vertices at identical positions are welded for the average,
    /// so UV seams (cube-sphere faces, lathe wrap) stay smooth.
    public mutating func recomputeNormals(weldSeams: Bool = true) {
        var acc = [V3](repeating: .zero, count: positions.count)
        for t in stride(from: 0, to: indices.count, by: 3) {
            let a = Int(indices[t]), b = Int(indices[t + 1]), c = Int(indices[t + 2])
            let n = simd_cross(positions[b] - positions[a], positions[c] - positions[a])
            acc[a] += n; acc[b] += n; acc[c] += n
        }
        if weldSeams {
            var groups: [SIMD3<Int32>: [Int]] = [:]
            for (i, p) in positions.enumerated() { groups[SIMD3<Int32>((p * 1e4).rounded(.toNearestOrAwayFromZero)), default: []].append(i) }
            for (_, g) in groups where g.count > 1 {
                let s = g.reduce(V3.zero) { $0 + acc[$1] }
                for i in g { acc[i] = s }
            }
        }
        normals = acc.map { $0.normalized }
    }

    /// Per-vertex tangents from UV gradients (Lengyel), Gram-Schmidt against the normal.
    public mutating func computeTangents() {
        var tan = [V3](repeating: .zero, count: positions.count)
        var bit = [V3](repeating: .zero, count: positions.count)
        for t in stride(from: 0, to: indices.count, by: 3) {
            let i0 = Int(indices[t]), i1 = Int(indices[t + 1]), i2 = Int(indices[t + 2])
            let e1 = positions[i1] - positions[i0], e2 = positions[i2] - positions[i0]
            let d1 = uvs[i1] - uvs[i0], d2 = uvs[i2] - uvs[i0]
            let det = d1.x * d2.y - d2.x * d1.y
            guard abs(det) > 1e-12 else { continue }
            let r = 1 / det
            let sdir = (e1 * d2.y - e2 * d1.y) * r, tdir = (e2 * d1.x - e1 * d2.x) * r
            for i in [i0, i1, i2] { tan[i] += sdir; bit[i] += tdir }
        }
        tangents = positions.indices.map { i in
            let n = normals[i]
            var t = tan[i] - n * simd_dot(n, tan[i])
            if simd_length_squared(t) < 1e-12 { t = n.anyPerpendicular }
            t = simd_normalize(t)
            let w: Float = simd_dot(simd_cross(n, t), bit[i]) < 0 ? -1 : 1
            return V4(t, w)
        }
    }

    /// Bake cavity occlusion from mesh concavity (vertex vs. average of its neighbors along the normal).
    /// Crevices darken, ridges stay bright; multiplied into `occlusion`.
    public mutating func bakeCavityAO(strength: Float = 1, floor: Float = 0.35) {
        if normals.count != positions.count { recomputeNormals() }
        var sum = [V3](repeating: .zero, count: positions.count), cnt = [Float](repeating: 0, count: positions.count)
        var edge = [Float](repeating: 0, count: positions.count)
        for t in stride(from: 0, to: indices.count, by: 3) {
            let a = Int(indices[t]), b = Int(indices[t + 1]), c = Int(indices[t + 2])
            for (i, j) in [(a, b), (b, c), (c, a), (b, a), (c, b), (a, c)] {
                sum[i] += positions[j]; cnt[i] += 1; edge[i] += simd_distance(positions[i], positions[j])
            }
        }
        if occlusion.count != positions.count { occlusion = Array(repeating: 1, count: positions.count) }
        for i in positions.indices where cnt[i] > 0 {
            let avg = sum[i] / cnt[i], e = max(edge[i] / cnt[i], 1e-5)
            let concave = simd_dot(normals[i], avg - positions[i]) / e   // >0 in pits
            occlusion[i] *= max(floor, 1 - saturate(concave * 2.5 * strength))
        }
    }

    /// Finalize: fill missing channels so every array matches positions.count.
    public mutating func finalize() {
        if normals.count != positions.count { recomputeNormals() }
        if uvs.count != positions.count { uvs = Array(repeating: .zero, count: positions.count) }
        if extra.count != positions.count { extra = Array(repeating: .zero, count: positions.count) }
        if occlusion.count != positions.count { occlusion = Array(repeating: 1, count: positions.count) }
        if tangents.count != positions.count { computeTangents() }
    }
}

/// A renderable asset: one Surface per material. Merging by material keeps draw calls minimal.
public struct Model: Sendable {
    public var name: String
    public var surfaces: [Surface]
    public init(name: String, surfaces: [Surface] = []) { self.name = name; self.surfaces = surfaces }

    public var triangleCount: Int { surfaces.reduce(0) { $0 + $1.triangleCount } }
    public var vertexCount: Int { surfaces.reduce(0) { $0 + $1.vertexCount } }
    public var materials: [MaterialKey] { surfaces.map(\.material) }

    public mutating func add(_ s: Surface, _ x: Xform = .identity) {
        guard !s.isEmpty else { return }
        if let i = surfaces.firstIndex(where: { $0.material == s.material }) { surfaces[i].append(s, x) }
        else { surfaces.append(x == .identity ? s : s.transformed(x)) }
    }
    public mutating func add(_ m: Model, _ x: Xform = .identity) { for s in m.surfaces { add(s, x) } }

    public func transformed(_ x: Xform) -> Model { var m = Model(name: name); m.add(self, x); return m }

    public var bounds: (min: V3, max: V3) {
        let bs = surfaces.filter { !$0.isEmpty }.map(\.bounds)
        guard let f = bs.first else { return (.zero, .zero) }
        return bs.dropFirst().reduce(f) { (simd_min($0.min, $1.min), simd_max($0.max, $1.max)) }
    }

    public func finalized() -> Model {
        var m = self
        for i in m.surfaces.indices { m.surfaces[i].finalize() }
        return m
    }
}

/// Discrete levels of detail for one asset. LOD 0 is the hero mesh.
public struct LODModel: Sendable {
    public var levels: [Model]
    /// Switch distances in meters: levels[i] is used up to switchDistances[i]. Count = levels.count - 1.
    public var switchDistances: [Float]
    public init(levels: [Model], switchDistances: [Float]) {
        precondition(switchDistances.count == max(0, levels.count - 1))
        self.levels = levels; self.switchDistances = switchDistances
    }
    public init(_ single: Model) { levels = [single]; switchDistances = [] }
}
