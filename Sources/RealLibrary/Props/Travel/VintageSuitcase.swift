import simd
import Foundation

/// 1930s leather suitcase standing on its base edge, 66 x 44 x 20 cm with handle: tan hide over a
/// rounded frame split into lid and base with a canvas-lined seam, saddle stitching along both faces,
/// eight brass corner caps, two draw-bolt latches and a lock on the top, rolled leather handle on brass
/// loops, two buckled straps around the case, brass studs underneath.
public struct VintageSuitcase: RealAsset {
    public static let id = "vintage-suitcase"
    public static let summary = "1930s leather suitcase, 66 cm: stitched tan hide over a frame, brass latches and corners, leather handle and straps."
    public static let tags = ["prop", "travel", "leather", "container", "antique"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 14, distance: 1.15, studio: true)

    /// Case body size without hardware (m): width, height, depth.
    public var body = V3(0.65, 0.38, 0.19)
    /// Hide and strap leathers.
    public var hide: MaterialKey = "leather.tan"
    public var strap: MaterialKey = "leather.tan:4A2A16"
    public var brass: MaterialKey = "metal.brass-aged"
    public var straps = true
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = body.x, H = body.y, D = body.z, lift: Float = 0.006
        let cy = lift + H / 2
        let outline = Shape2D.roundedRect(W, H, radius: 0.034, segments: 5)
        // Base and lid shells with a recessed canvas valance in the seam.
        let zs = D / 2 - 0.068, gap: Float = 0.005
        let baseDepth = zs - gap / 2 + D / 2, lidDepth = D / 2 - zs - gap / 2
        m.add(Prim.extrude(outline, depth: baseDepth, bevel: 0.009, bevelSegments: 3, material: hide), Xform(translation: V3(0, cy, -D / 2 + baseDepth / 2)))
        m.add(Prim.extrude(outline, depth: lidDepth, bevel: 0.009, bevelSegments: 3, material: hide), Xform(translation: V3(0, cy, D / 2 - lidDepth / 2)))
        m.add(Prim.extrude(Shape2D.offset(outline, -0.004), depth: gap + 0.02, bevel: 0.001, bevelSegments: 1, material: "fabric.canvas:3A2E22"),
              Xform(translation: V3(0, cy, zs)))
        // Saddle stitching 11 mm in from each face edge, and either side of the seam.
        func loop(_ inset: Float, z: Float) -> [V3] {
            let o = Shape2D.offset(outline, -inset)
            return (o + [o[0]]).map { V3($0.x, $0.y + cy, z) }
        }
        let faceN: (Float) -> (V3) -> V3 = { sz in { _ in V3(0, 0, sz) } }
        var detail = Model(name: "stitching")
        detail.add(stitches(along: loop(0.016, z: D / 2 + 0.0002), normal: faceN(1), pitch: 0.006, thread: 0.0008, material: "fabric.canvas:D8CDB0"))
        detail.add(stitches(along: loop(0.016, z: -D / 2 - 0.0002), normal: faceN(-1), pitch: 0.006, thread: 0.0008, material: "fabric.canvas:D8CDB0"))
        // Brass corner caps over all eight corners, with two pins each.
        for sx: Float in [-1, 1] { for sy: Float in [-1, 1] { for sz: Float in [-1, 1] {
            let c = V3(sx * (W / 2 - 0.019), cy + sy * (H / 2 - 0.019), sz * (D / 2 - 0.017))
            m.add(Prim.superellipsoid(V3(0.052, 0.052, 0.048), exponent: 3.2, subdivisions: 4, material: brass), Xform(translation: c))
            rivet(&m, at: c + V3(sx * 0.0262, sy * 0.004, sz * 0.004), normal: V3(sx, 0, 0), radius: 0.0022, material: brass)
            rivet(&m, at: c + V3(sx * 0.004, sy * 0.004, sz * 0.0242), normal: V3(0, 0, sz), radius: 0.0022, material: brass)
        }}}
        // Top hardware: two draw-bolt latches straddling the seam, center lock, handle on brass loops.
        let top = lift + H
        for sx: Float in [-1, 1] {
            let x = sx * W * 0.31
            m.add(Prim.roundedBox(V3(0.034, 0.005, 0.03), radius: 0.002, bevelSegments: 2, material: brass), Xform(translation: V3(x, top + 0.0015, zs - 0.018)))
            m.add(Prim.roundedBox(V3(0.03, 0.007, 0.034), radius: 0.003, bevelSegments: 2, material: brass), Xform(translation: V3(x, top + 0.0025, zs + 0.016)))
            m.add(Prim.cylinder(radius: 0.006, height: 0.005, bevel: 0.0018, segments: 14, material: brass), Xform(translation: V3(x, top + 0.005, zs + 0.016)))
            for dx: Float in [-0.012, 0.012] { rivet(&m, at: V3(x + dx, top + 0.004, zs - 0.026), normal: .up, radius: 0.0018, material: brass) }
        }
        m.add(Prim.roundedBox(V3(0.044, 0.006, 0.036), radius: 0.003, bevelSegments: 2, material: brass), Xform(translation: V3(0, top + 0.002, zs)))
        m.add(Prim.roundedBox(V3(0.0035, 0.002, 0.009), radius: 0.0008, bevelSegments: 1, material: "plastic.black"), Xform(translation: V3(0, top + 0.0052, zs)))
        let hw: Float = 0.065
        let hz = zs - 0.02
        let arch = catmull([V3(-hw - 0.012, top + 0.014, hz), V3(-hw + 0.004, top + 0.04, hz), V3(-hw * 0.4, top + 0.052, hz), V3(hw * 0.4, top + 0.052, hz),
                            V3(hw - 0.004, top + 0.04, hz), V3(hw + 0.012, top + 0.014, hz)], per: 4)
        let thick = arch.indices.map { i -> Float in let t = Float(i) / Float(arch.count - 1); return 1 + 0.35 * sin(t * .pi) }
        m.add(Prim.sweep(Shape2D.superellipse(0.024, 0.017, exponent: 2.4, segments: 14), along: arch, up: V3(0, 0, 1), scales: thick, material: strap))
        detail.add(stitches(along: arch.map { $0 + V3(0, 0.0105, 0) }, normal: { _ in .up }, pitch: 0.006, thread: 0.0006, material: "fabric.canvas:D8CDB0"))
        for sx: Float in [-1, 1] {
            let p = V3(sx * (hw + 0.014), top + 0.008, hz)
            m.add(Prim.torus(major: 0.009, minor: 0.0028, segments: 16, sides: 6, arc: .pi * 1.2, material: brass),
                  Xform(translation: p, rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1)) * simd_quatf(degrees: -20, axis: .up)))
            m.add(Prim.roundedBox(V3(0.026, 0.004, 0.022), radius: 0.0015, bevelSegments: 1, material: brass), Xform(translation: V3(p.x, top + 0.0012, hz)))
        }
        // Straps: a band around the case in the YZ plane, buckle on the front face.
        if straps {
            for sx: Float in [-1, 1] {
                let x = sx * W * 0.24 + rng.float(-0.006...0.006)
                let ring = Shape2D.roundedRect(H + 0.006, D + 0.006, radius: 0.03, segments: 5).map { V3(x, cy + $0.x, $0.y) }
                m.add(Prim.sweep(Shape2D.roundedRect(0.028, 0.0032, radius: 0.0012, segments: 1), along: ring, up: V3(1, 0, 0), closedPath: true, caps: false, material: strap))
                let by = cy + H * 0.18, bz = D / 2 + 0.006
                let frame = Shape2D.roundedRect(0.026, 0.038, radius: 0.005, segments: 3).map { V3(x + $0.y, by + $0.x, bz) }
                m.add(Prim.sweep(Shape2D.circle(0.0018, segments: 6), along: frame, closedPath: true, caps: false, material: brass))
                m.add(Prim.tube([V3(x, by - 0.013, bz + 0.001), V3(x, by + 0.012, bz + 0.002)], radii: [0.0014, 0.0012], sides: 6, seamTile: 0.02, material: brass))
                // Free strap end tucked through a keeper below the buckle.
                m.add(Prim.roundedBox(V3(0.034, 0.012, 0.004), radius: 0.0015, bevelSegments: 1, material: strap), Xform(translation: V3(x, by - 0.035, bz)))
            }
        }
        // Brass studs under the base.
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
            m.add(turned([(0, 0), (0.007, 0), (0.0072, 0.003), (0.005, lift + 0.002), (0, lift + 0.002)], segments: 12, material: brass),
                  Xform(translation: V3(sx * W * 0.4, 0, sz * D * 0.3)))
        }}
        groundAO(&m, height: 0.07, floor: 0.55)
        var full = m
        full.add(detail)
        // LOD1 drops the stitching (invisible past a few meters).
        return LODModel(levels: [full, m], switchDistances: [4])
    }
}
