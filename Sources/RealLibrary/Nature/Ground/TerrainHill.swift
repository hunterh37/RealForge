import simd
import Foundation

/// Hilly terrain tile, 120 m square, up to ~16 m relief: eroded rolling hills fading to y = 0 at the
/// border, meadow everywhere and a granite layer that breaks through where slopes pass ~35 degrees. 3 LODs.
public struct TerrainHill: RealAsset {
    public static let id = "terrain-hill"
    public static let summary = "Hilly 120 m terrain: eroded fBm hills fading to a flat border, meadow on gentle slopes, granite on steep faces, 3 LODs."
    public static let tags = ["nature", "terrain", "ground", "rock"]
    public static let budget = 60_000
    public static let preview = PreviewHint(azimuth: 30, elevation: 16, distance: 0.7, ground: false, fog: 0.004)

    /// Side length in meters.
    public var size: Float = 120
    /// Peak height in meters.
    public var peak: Float = 16
    /// Feature size of the hills in meters.
    public var featureSize: Float = 38
    /// Flat border width in meters (blends into a flat ground plane).
    public var border: Float = 12
    /// Slope (rise over run) where rock replaces the ground material.
    public var rockSlope: Float = 0.7
    public var material: MaterialKey = "ground.meadow"
    public var rockMaterial: MaterialKey = "rock.granite"
    /// Grid segments per LOD.
    public var detail: [Int] = [136, 68, 34]
    public var lodDistances: [Float] = [60, 150]
    public init() {}

    /// Height at (x, z), matching LOD 0 at the grid vertices.
    public func height(x: Float, z: Float, seed: UInt64) -> Float {
        let ns = UInt32(truncatingIfNeeded: seed)
        let f = 1 / featureSize
        let p = V2(x, z)
        let w = V2(Noise.perlin(V3(x * f * 0.5, 1.7, z * f * 0.5), seed: ns &+ 3),
                   Noise.perlin(V3(x * f * 0.5, 5.3, z * f * 0.5), seed: ns &+ 4)) * 0.8
        let q = p * f + w
        let e = GroundMesh.eroded(q, octaves: 6, seed: ns, gain: 0.45)
        let ridge = Noise.ridged(V3(q.x * 0.8, 0, q.y * 0.8), octaves: 4, seed: ns &+ 11)
        let h = max(0, 0.45 + 1.1 * e + 0.45 * (ridge - 0.45))
        // Fade to the flat border.
        let half = size / 2
        let edge = max(abs(x), abs(z))
        let fade = 1 - smoothstep(half - border * 2.2, half - border * 0.3, edge)
        return pow(h, 1.25) * peak * fade
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let ns = UInt32(truncatingIfNeeded: rng.next())
        func lod(_ n: Int) -> Model {
            let grid = Prim.terrain(size: V2(size, size), segments: n, material: material) { p in height(x: p.x, z: p.y, seed: seed) }
            var g = grid
            GroundMesh.shadeHollows(&g, gridSide: n + 1, radius: max(2, n / 40), relief: peak * 0.15, strength: 0.6)
            // Rock layer: a copy of the ground grid pushed out along the normal where the slope is steep and
            // sunk below it elsewhere. The two meshes cross along the smooth mask contour, so the rock edge
            // follows the slope field instead of stepping along triangle edges.
            var rock = Surface(material: rockMaterial)
            var map = [Int32](repeating: -1, count: g.vertexCount)
            var mask = [Float](repeating: 0, count: g.vertexCount)
            for i in g.positions.indices {
                let n = g.normals[i], p = g.positions[i]
                let slope = sqrt(max(0, 1 - n.y * n.y)) / max(n.y, 0.05)
                let jitter = Noise.fbm(V3(p.x * 0.08, 0, p.z * 0.08), octaves: 3, seed: ns) * 0.6
                mask[i] = smoothstep(rockSlope - 0.2, rockSlope + 0.2, slope + jitter)
            }
            for t in stride(from: 0, to: g.indices.count, by: 3) {
                let tri = [Int(g.indices[t]), Int(g.indices[t + 1]), Int(g.indices[t + 2])]
                guard tri.contains(where: { mask[$0] > 0.2 }) else { continue }
                var ids: [UInt32] = []
                for i in tri {
                    if map[i] < 0 {
                        let p = g.positions[i], n = g.normals[i]
                        let lump = Noise.ridged(V3(p.x * 0.6, p.y * 0.6, p.z * 0.6), octaves: 3, seed: ns &+ 5) * 0.9
                        let off = lerp(Float(-0.15), 0.05 + lump, mask[i])
                        let k = rock.add(p + n * off, n, g.uvs[i])
                        rock.occlusion[Int(k)] = g.occlusion[i] * (0.75 + 0.25 * mask[i])
                        map[i] = Int32(k)
                    }
                    ids.append(UInt32(map[i]))
                }
                rock.tri(ids[0], ids[1], ids[2])
            }
            if !rock.isEmpty { rock.recomputeNormals(weldSeams: false); rock.computeTangents() }
            let soil = g
            return Model(name: Self.id, surfaces: [soil, rock].filter { !$0.isEmpty })
        }
        return LODModel(levels: detail.map(lod), switchDistances: Array(lodDistances.prefix(detail.count - 1)))
    }
}
