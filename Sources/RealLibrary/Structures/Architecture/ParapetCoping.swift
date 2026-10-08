import simd
import Foundation

/// Parapet segment: brick wall under saddle-back cast stone coping with throated drips on both faces
/// and bedded joints. Centered on X/Z (the wall's center plane at z = 0); tile every `length`.
public struct ParapetCoping: RealAsset {
    public static let id = "parapet-coping"
    public static let summary = "Parapet segment, 1.2 m: brick wall in stretcher bond under weathered cast stone coping with drips; tiles along X."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone", "brick", "wall"]
    public static let budget = 6_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 14, distance: 1.0)

    /// Run length along X (m).
    public var length: Float = 1.2
    /// Wall height below the coping (m).
    public var wallHeight: Float = 0.78
    /// Wall thickness (m), one and a half bricks by default.
    public var wallThickness: Float = 0.23
    /// Coping overhang past each wall face (m).
    public var overhang: Float = 0.05
    /// Coping stone length (m); joints fall between stones.
    public var stoneLength: Float = 0.6
    /// Rain streak and soot strength (0 = new).
    public var weathering: Float = 0.7
    public var wallMaterial: MaterialKey = "brick.common"
    public var copingMaterial: MaterialKey = "stone.cast-grey"
    public var mortarMaterial: MaterialKey = "concrete.smooth:A39E92"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        let rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let t = wallThickness, L = length
        m.add(Prim.roundedBox(V3(L, wallHeight, t), radius: 0.003, bevelSegments: 1, material: wallMaterial),
              Xform(translation: V3(0, wallHeight / 2, 0)))
        // Mortar bed under the coping.
        m.add(Prim.roundedBox(V3(L, 0.012, t + 0.004), radius: 0.002, bevelSegments: 1, material: mortarMaterial),
              Xform(translation: V3(0, wallHeight + 0.006, 0)))
        // Saddle-back coping section (z, y) with a throated drip under each overhang.
        let w = t / 2 + overhang, base: Float = 0.06, apex: Float = 0.11, d: Float = overhang - 0.022
        let outline: [V2] = [
            V2(-w, 0), V2(-w + d, 0), V2(-w + d, 0.01), V2(-w + d + 0.01, 0.01), V2(-w + d + 0.01, 0),
            V2(w - d - 0.01, 0), V2(w - d - 0.01, 0.01), V2(w - d, 0.01), V2(w - d, 0), V2(w, 0),
            V2(w, base), V2(0.012, apex), V2(-0.012, apex), V2(-w, base)
        ]
        let n = max(1, Int((L / stoneLength).rounded())), pitch = L / Float(n)
        let y0 = wallHeight + 0.012
        for i in 0..<n {
            var r = rng.fork(i)
            let tint = r.pick(["", ":A4A096", ":928E84"])
            let stone = Prim.extrude(outline, depth: pitch - 0.008, bevel: 0.004, bevelSegments: 2, material: copingMaterial + tint)
            m.add(stone, Xform(translation: V3(-L / 2 + pitch * (Float(i) + 0.5), y0, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 1, 0))))
            if i > 0 {
                m.add(Prim.roundedBox(V3(0.009, base * 0.9, 2 * w - 0.01), radius: 0.002, bevelSegments: 1, material: mortarMaterial),
                      Xform(translation: V3(-L / 2 + pitch * Float(i), y0 + base * 0.45, 0)))
            }
        }
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        groundAO(&m, height: 0.25, floor: 0.6)
        return LODModel(ArchTrimKit.ground(m))
    }
}
