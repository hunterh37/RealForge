import simd
import Foundation

/// Granite boulder: cube-sphere with ridged displacement, planar fracture facets, flattened, sunk base.
public struct Boulder: RealAsset {
    public static let id = "boulder"
    public static let summary = "Faceted granite boulder, cube-sphere + ridged noise + fracture planes, 3 LODs."
    public static let tags = ["nature", "rock"]
    public static let budget = 12_000

    public var size: V3 = V3(1.6, 1.0, 1.3)
    public var material: MaterialKey = "rock.granite"
    public var facets = 9
    public var roughness: Float = 0.3
    /// Cube-sphere subdivisions per LOD.
    public var detail: [Int] = [28, 12, 5]
    public var lodDistances: [Float] = [10, 30]
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let s = V3(rng.vary(size.x, 0.2), rng.vary(size.y, 0.25), rng.vary(size.z, 0.2)) / 2
        let ns = UInt32(truncatingIfNeeded: seed)
        var planes: [(V3, Float)] = []
        for _ in 0..<facets {
            var n = rng.unitVector(); n.y = abs(n.y) * 0.8 + 0.1
            planes.append((simd_normalize(n), rng.float(0.62...0.85)))
        }
        let r = roughness
        func shape(_ d: V3) -> V3 {
            var p = d
            let big = Noise.fbm(d * 1.3, octaves: 3, seed: ns) * 0.35
            let ridge = Noise.ridged(d * 2.4, octaves: 4, seed: ns &+ 7) * 0.5
            p *= 1 + (big + ridge - 0.2) * r * 2.2
            // Fracture facets: clamp to random planes (scaled space) for broken-stone flats.
            for (n, k) in planes { let dd = simd_dot(p, n); if dd > k { p -= n * (dd - k) * 0.92 } }
            var q = p * s
            if q.y < -s.y * 0.55 { q.y = -s.y * 0.55 + (q.y + s.y * 0.55) * 0.15 }  // flat-ish base
            return q
        }
        func lod(_ n: Int) -> Model {
            var surf = Prim.cubeSphere(subdivisions: n, material: material, radius: shape)
            let minY = surf.bounds.min.y
            surf.positions = surf.positions.map { V3($0.x, $0.y - minY - s.y * 0.18, $0.z) }  // sink into ground
            surf.occlusion = surf.positions.map { 0.35 + 0.65 * smoothstep(-0.05, s.y * 0.5, $0.y) }  // contact shadow
            surf.bakeCavityAO(strength: 1.2)
            return Model(name: Self.id, surfaces: [surf])
        }
        return LODModel(levels: detail.map(lod), switchDistances: Array(lodDistances.prefix(detail.count - 1)))
    }
}

/// Scatter of small stones (single mesh, one draw).
public struct Pebbles: RealAsset {
    public static let id = "pebbles"
    public static let summary = "Cluster of 8-20 small rounded stones in one mesh."
    public static let tags = ["nature", "rock"]
    public static let budget = 10_000
    public var radius: Float = 0.6
    public var count = 14
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        for i in 0..<count {
            let p = rng.inDisc(radius: radius), sz = rng.float(0.04...0.14)
            let b = Boulder().with { $0.size = V3(sz * 1.4, sz * 0.8, sz * 1.1); $0.facets = 2; $0.roughness = 0.12; $0.detail = [5] }
            let one = b.build(seed: seed &+ UInt64(i)).levels[0]
            m.add(one, Xform(translation: V3(p.x, 0, p.y), rotation: simd_quatf(degrees: rng.float(0...360), axis: .up)))
        }
        return LODModel(m)
    }
}

/// Terrain patch with gentle relief. UVs in meters for the ground material's tile size.
public struct GroundPatch: RealAsset {
    public static let id = "ground-patch"
    public static let summary = "Square heightfield terrain with fBm relief and forest-floor material."
    public static let tags = ["nature", "ground", "terrain"]
    public static let budget = 60_000
    public var size: Float = 40
    public var segments = 128
    public var relief: Float = 0.35
    public var material: MaterialKey = "ground.forest"
    /// Keep the center flat (radius, meters) so props sit cleanly.
    public var flatCenter: Float = 3
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        let ns = UInt32(truncatingIfNeeded: seed)
        let s = Prim.terrain(size: V2(size, size), segments: segments, material: material) { p in
            let h = Noise.fbm(V3(p.x * 0.08, 0, p.y * 0.08), octaves: 5, seed: ns) * relief * 2
            let r = simd_length(p)
            let edge = smoothstep(size * 0.42, size * 0.5, max(abs(p.x), abs(p.y)))
            return h * smoothstep(flatCenter, flatCenter * 2.5, r) - edge * 0.05
        }
        return LODModel(Model(name: Self.id, surfaces: [s]))
    }

    /// Height at (x, z) matching the mesh (for placing instances on the ground).
    public func height(x: Float, z: Float, seed: UInt64) -> Float {
        let ns = UInt32(truncatingIfNeeded: seed)
        let p = V2(x, z)
        let h = Noise.fbm(V3(p.x * 0.08, 0, p.y * 0.08), octaves: 5, seed: ns) * relief * 2
        return h * smoothstep(flatCenter, flatCenter * 2.5, simd_length(p))
    }
}

/// Grass clump: 3 crossed alpha cards with bottom-anchored wind weights. Instance by the thousand.
public struct GrassClump: RealAsset {
    public static let id = "grass-clump"
    public static let summary = "Three crossed grass-blade cards, wind-weighted from root to tip."
    public static let tags = ["nature", "grass", "foliage"]
    public static let budget = 64
    public var height: Float = 0.42
    public var width: Float = 0.5
    public var material: MaterialKey = "grass.meadow"
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var s = Surface(material: material)
        let phase = rng.float(0...6.28)
        for k in 0..<3 {
            let a = Float(k) * 60 + rng.float(-10...10)
            var c = Prim.card(width: width * rng.vary(1, 0.15), height: height * rng.vary(1, 0.2), cell: (V2(0, 0), V2(1, 1)), material: material, normal: .up)
            c.extra = [V2(0, phase), V2(0, phase), V2(1, phase), V2(1, phase)]
            c.occlusion = [0.55, 0.55, 1, 1]
            // Up-facing normals light grass like a lawn instead of like flat cards.
            c.normals = [V3(0, 1, 0), V3(0, 1, 0), simd_normalize(V3(0.15, 1, 0)), simd_normalize(V3(-0.15, 1, 0))]
            s.append(c, Xform(rotation: simd_quatf(degrees: a, axis: .up)))
        }
        s.computeTangents()
        let m = Model(name: Self.id, surfaces: [s])
        return LODModel(levels: [m], switchDistances: [])
    }
}
