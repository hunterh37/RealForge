import simd
import Foundation

/// Fallen-leaf litter, ~1 m patch: 60-100 dry oak, maple, beech and willow leaves (5-12 cm) as curled
/// cards stacked a fraction of a millimeter apart on the ground. LOD1: flat cards.
public struct LeafLitter: RealAsset {
    public static let id = "leaf-litter"
    public static let summary = "Fallen-leaf litter, ~1 m: 60-100 curled dry leaf cards (oak, maple, beech, willow) hugging the ground; 2 LODs."
    public static let tags = ["nature", "ground", "plant"]
    public static let budget = 480
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 50, distance: 0.9, ground: false)

    public var radius: Float = 0.5
    public var leaves: ClosedRange<Int> = 60...100
    public var material: MaterialKey = "litter.dry"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m0 = Model(name: Self.id), m1 = Model(name: Self.id)
        let n = rng.int(leaves)
        // A few drift centers so leaves bunch up the way wind leaves them.
        let centers = (0..<3).map { _ in rng.inDisc(radius: radius * 0.5) }
        for i in 0..<n {
            var p = rng.inDisc(radius: radius)
            if rng.chance(0.5) { p = centers[i % 3] + rng.inDisc(radius: radius * 0.35) }
            let c = PlantKit.cell(rng.int(0...15), cols: 4, rows: 4)
            var b = PlantKit.Blade()
            b.length = rng.float(0.05...0.12); b.width = b.length
            b.yaw = rng.float(0...6.28)
            // Root sits half a leaf back so the leaf is centered on p.
            let d = V3(cos(b.yaw), 0, sin(b.yaw))
            b.root = V3(p.x, 0.003 + Float(i) * 0.0004, p.y) - d * b.length / 2
            b.constantWidth = true; b.tipWidth = 1
            b.lean = rng.float(1.42...1.56); b.curl = rng.float(-0.05...0.08); b.segments = 1
            b.u = V2(c.origin.x, c.origin.x + c.size.x); b.v = V2(c.origin.y, c.origin.y + c.size.y)
            b.weight = V2(0, 0); b.ao = V2(0.75, 0.9); b.upNormal = 0.2
            var hi = b; hi.fold = rng.float(-0.18...0.04)
            m0.add(PlantKit.blade(hi, material: material))
            m1.add(PlantKit.blade(b, material: material))
        }
        PlantKit.finish(&m0); PlantKit.finish(&m1)
        return LODModel(levels: [m0, m1], switchDistances: [6])
    }
}
