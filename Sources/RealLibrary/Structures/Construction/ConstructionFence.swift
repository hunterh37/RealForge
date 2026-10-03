import simd
import Foundation

/// Temporary construction fence panel (Heras type), 3.5 m x 2.0 m: 42 mm galvanized tube frame, welded 4 mm
/// wire mesh at 100 x 300 mm, legs standing in concrete-filled feet, top coupler clamp. Origin at the base
/// center; tile along X every `length` with `trailingFoot = false` on all but the last panel.
public struct ConstructionFence: RealAsset {
    public static let id = "construction-fence"
    public static let summary = "Temporary mesh fence panel, 3.5 m: galvanized tube frame, welded wire mesh, concrete feet, clamp."
    public static let tags = ["structure", "construction", "fence", "barrier", "metal"]
    public static let budget = 4_500
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 20, elevation: 10)

    public var length: Float = 3.5
    public var height: Float = 2.0
    /// Foot and clamp at the +X end (the -X end always has one).
    public var trailingFoot = true
    public var frame: MaterialKey = "metal.galvanized"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length / 2, tr: Float = 0.021, y0: Float = 0.12, y1 = y0 + height
        let lean = rng.float(-1.2...1.2)
        var panel = Model(name: "panel")
        // Frame: two legs that run into the feet, top and bottom rails with rounded corners.
        let ix = L - 0.06
        let framePath: [V3] = [V3(-ix, 0.0, 0), V3(-ix, y1 - 0.06, 0), V3(-ix + 0.02, y1 - 0.015, 0), V3(-ix + 0.06, y1, 0),
                               V3(ix - 0.06, y1, 0), V3(ix - 0.02, y1 - 0.015, 0), V3(ix, y1 - 0.06, 0), V3(ix, 0.0, 0)]
        panel.add(CFKit.pipe(framePath, radius: tr, sides: 10, per: 3, material: frame))
        panel.add(CFKit.pipe([V3(-ix, y0 + 0.05, 0), V3(ix, y0 + 0.05, 0)], radius: tr, sides: 10, material: frame))
        // Mesh: vertical wires every 0.1 m, horizontal every 0.3 m, on alternate faces so they cross.
        var mesh = Surface(material: frame)
        let mx0 = -ix + tr, mx1 = ix - tr, my0 = y0 + 0.05 + tr, my1 = y1 - tr
        let wr: Float = 0.002
        var x = mx0 + 0.04
        while x < mx1 - 0.02 { mesh.append(Prim.tube([V3(x, my0, 0.0025), V3(x, my1, 0.0025)], radii: [wr, wr], sides: 4, seamTile: 0.02, material: frame, capEnd: false)); x += 0.1 }
        var y = my0 + 0.08
        while y < my1 - 0.02 { mesh.append(Prim.tube([V3(mx0, y, -0.0015), V3(mx1, y, -0.0015)], radii: [wr, wr], sides: 4, seamTile: 0.02, material: frame, capEnd: false)); y += 0.3 }
        mesh.computeTangents()
        panel.add(mesh)
        m.add(panel, Xform(rotation: simd_quatf(degrees: lean, axis: V3(1, 0, 0))))
        // Feet: concrete blocks with two leg holes, plus the clamp joining neighbours at the top.
        let feet: [Float] = trailingFoot ? [-L, L] : [-L]
        for fx in feet {
            var f = CFKit.blob(half: V3(0.36, 0.07, 0.11), power: 6, subdivisions: 5, material: "concrete.rough")
            f.positions = f.positions.map { V3($0.x, $0.y + 0.07, $0.z) }
            f.recomputeNormals(); f.computeTangents()
            m.add(f, Xform(translation: V3(fx, 0, 0), rotation: simd_quatf(degrees: rng.float(-4...4), axis: .up)))
            for dx: Float in [-0.06, 0.06] {
                m.add(turned([(0.03, 0.14), (0.034, 0.141), (0.034, 0.146), (0.0, 0.146)], segments: 12, material: "rubber"), Xform(translation: V3(fx + dx, 0, 0)))
            }
            let cy = y1 - 0.25
            m.add(Prim.roundedBox(V3(0.16, 0.05, 0.035), radius: 0.008, bevelSegments: 1, material: frame), Xform(translation: V3(fx, cy, 0)))
            m.add(turned([(0, 0), (0.009, 0), (0.009, 0.07), (0, 0.072)], segments: 8, material: frame),
                  Xform(translation: V3(fx, cy, -0.035), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }
        groundAO(&m, height: 0.25, floor: 0.6)
        return LODModel(m)
    }
}
