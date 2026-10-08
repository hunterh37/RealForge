import simd
import Foundation

/// Rusticated base course panel: chamfered ashlar blocks in running bond with recessed V-joints over a
/// projecting molded plinth. Back on the wall plane; tile every `length` along X.
public struct RusticatedBase: RealAsset {
    public static let id = "rusticated-base"
    public static let summary = "Rusticated base panel, 1.2 m square: chamfered rusticated blocks in running bond above a projecting plinth; tiles along X."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone", "wall"]
    public static let budget = 6_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 28, elevation: 8, distance: 1.0)

    /// Panel width along X (m).
    public var length: Float = 1.2
    /// Panel height including the plinth (m).
    public var height: Float = 1.2
    /// Plinth height (m).
    public var plinthHeight: Float = 0.2
    /// Course height (m).
    public var courseHeight: Float = 0.25
    /// Block length (m); courses offset by half a block.
    public var blockLength: Float = 0.6
    /// Block projection from the wall plane (m).
    public var blockDepth: Float = 0.12
    /// Chamfer width at block edges (m).
    public var chamfer: Float = 0.018
    /// Rain streak and soot strength.
    public var weathering: Float = 0.45
    public var material: MaterialKey = "stone.sandstone"
    public var jointMaterial: MaterialKey = "concrete.smooth:9C9284"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length
        // Plinth: plain face with a cyma reversa sloping back to the block face.
        var p = ArchProfile()
        p.step(blockDepth + 0.04); p.fillet(plinthHeight - 0.05)
        p.cymaReversa(0.035, -0.03); p.fillet(0.006); p.step(-0.01)
        p.fillet(0.009)
        m.add(ArchTrimKit.sweep(p, length: L, material: material))
        // Joint backing.
        let y0 = plinthHeight
        m.add(Prim.roundedBox(V3(L, height - y0, blockDepth - 0.04), radius: 0.002, bevelSegments: 1, material: jointMaterial),
              Xform(translation: V3(0, y0 + (height - y0) / 2, (blockDepth - 0.04) / 2 + 0.004)))
        let courses = max(1, Int(((height - y0) / courseHeight).rounded())), ch = (height - y0) / Float(courses)
        let tints = ["", ":C4A47A", ":BE9C70", ":CCAE86"]
        for c in 0..<courses {
            let off: Float = c % 2 == 0 ? 0 : blockLength / 2
            var x = -L / 2 - off
            var j = 0
            while x < L / 2 - 1e-3 {
                var r = rng.fork(c * 100 + j)
                let a = max(x, -L / 2), b = min(x + blockLength, L / 2)
                let gapA: Float = a > -L / 2 + 1e-4 ? 0.005 : 0, gapB: Float = b < L / 2 - 1e-4 ? 0.005 : 0
                let w = b - a - gapA - gapB, hgt = ch - 0.01
                if w > 0.05 {
                    let rect = Shape2D.rect(w, hgt)
                    var blk = Prim.extrude(rect, depth: blockDepth - 0.012, bevel: chamfer, bevelSegments: 1, material: material + r.pick(tints))
                    // Tooled face: slight pillow and a few mm of unevenness.
                    blk = blk.transformed(Xform(translation: V3(0, 0, blockDepth / 2)))
                    let ns = UInt32(truncatingIfNeeded: seed &+ UInt64(c * 31 + j))
                    blk.positions = blk.positions.map { q in
                        guard q.z > blockDepth - 0.003 else { return q }
                        return q + V3(0, 0, 0.002 * Noise.perlin(V3(q.x * 9, q.y * 9, 0), seed: ns))
                    }
                    blk.recomputeNormals(); blk.computeTangents()
                    m.add(blk, Xform(translation: V3((a + gapA + b - gapB) / 2, y0 + ch * (Float(c) + 0.5), 0.012)))
                }
                x += blockLength; j += 1
            }
        }
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        groundAO(&m, height: 0.3, floor: 0.6)
        return LODModel(ArchTrimKit.ground(m))
    }
}
