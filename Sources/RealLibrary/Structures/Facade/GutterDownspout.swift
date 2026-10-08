import simd
import Foundation

/// K-style aluminum gutter run with downspout: 5 in ogee-front gutter along the eave (`length`),
/// hidden hangers every 600 mm, end caps, an outlet drop (anywhere along the run), two offset elbows back to
/// the wall, a 2 x 3 in rectangular downspout with wall straps and a kick-out shoe. Streaks of dirt
/// run down the face below the seams. Wall plane at z = -depth/2, the gutter projects +Z; base y = 0
/// is the bottom of the shoe.
public struct GutterDownspout: RealAsset {
    public static let id = "gutter-downspout"
    public static let summary = "K-style aluminum gutter run, 3 m, with hangers, end cap, outlet, elbows and a downspout with straps and kick-out shoe."
    public static let tags = ["structure", "architecture", "roof", "metal"]
    public static let budget = 8_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 34, elevation: 12, distance: 1.0, studio: true)

    /// Gutter length along the eave (m).
    public var length: Float = 3.0
    /// Height of the gutter bottom above the shoe (m).
    public var height: Float = 2.9
    /// Gutter projection from the fascia/wall (m).
    public var depth: Float = 0.3
    /// Outlet position along the run, -1 (left end) ... 1 (right end); 0 is a centre drop.
    public var outletPosition: Float = 0.1
    public var gutterMaterial: MaterialKey = "metal.powder-white:ECEBE6"
    public var strapMaterial: MaterialKey = "metal.galvanized"
    public var dirtMaterial: MaterialKey = "decal.rubber-scuff"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let Lg = length, H = height, zw = -depth / 2
        let gm = gutterMaterial
        // K profile in (z, y): back flat against the fascia, flat bottom, ogee front, rolled lip.
        let outer: [V2] = [V2(0, 0.127), V2(0, 0.0), V2(0.085, 0.0), V2(0.098, 0.022), V2(0.1, 0.05),
                           V2(0.112, 0.07), V2(0.118, 0.095), V2(0.128, 0.115), V2(0.134, 0.127), V2(0.126, 0.133)]
        let t: Float = 0.0018
        var inner = outer.map { p -> V2 in V2(p.x + (p.x < 0.01 ? t : -t), p.y + (p.y < 0.01 ? t : 0)) }
        inner[inner.count - 1] = V2(0.122, 0.128)
        let shell = outer + inner.reversed()
        let gutter = Prim.extrude(shell, depth: Lg, bevel: 0.0006, bevelSegments: 1, material: gm)
        let gz = zw + 0.02                      // fascia face
        let gy = H
        m.add(gutter, Xform(translation: V3(0, gy, gz), rotation: simd_quatf(degrees: -90, axis: .up)))
        // Fascia board the gutter hangs on.
        m.add(HK.box(V3(Lg + 0.04, 0.2, 0.025), V3(0, gy + 0.08, zw + 0.0075), "wood.painted-exterior", r: 0.004))
        // End caps.
        for sx: Float in [-1, 1] {
            m.add(Prim.extrude(outer + [V2(0, 0.127)], depth: 0.002, bevel: 0.0005, bevelSegments: 1, material: gm),
                  Xform(translation: V3(sx * (Lg / 2 + 0.001), gy, gz), rotation: simd_quatf(degrees: -90, axis: .up)))
        }
        // Hidden hangers: clips across the top from the back to the lip, screw heads at the back.
        var x = -Lg / 2 + 0.3
        while x < Lg / 2 - 0.1 {
            m.add(HK.box(V3(0.025, 0.004, 0.13), V3(x, gy + 0.122, gz + 0.065), strapMaterial, r: 0.001, seg: 1))
            m.add(HK.cyl(r: 0.006, len: 0.004, at: V3(x, gy + 0.11, gz + 0.003), axis: V3(0, 0, 1), mat: strapMaterial, seg: 10))
            x += 0.6
        }
        // Dirt streaks below the lip at the end seams and hangers.
        for i in 0..<5 {
            let sx = -Lg / 2 + Lg * (Float(i) + rng.float(0.2...0.8)) / 5
            m.add(HK.box(V3(rng.float(0.03...0.07), 0.05, 0.001), V3(sx, gy + 0.03, gz + 0.1 + 0.0015), dirtMaterial, r: 0.0003, seg: 1))
        }

        // Outlet drop and downspout.
        let ox = max(-1, min(1, outletPosition)) * (Lg / 2 - 0.12)
        let dw: Float = 0.076, dd: Float = 0.051     // 3 x 2 in
        let zOut = gz + 0.05
        let zWall = zw + 0.035
        func box(_ a: V3, _ b: V3) {
            let (s, xf) = board(from: a, to: b, width: dw, thick: dd, up: V3(1, 0, 0), bevel: 0.004, material: gm, extend: 0.01)
            m.add(s, xf)
        }
        m.add(HK.box(V3(dw, 0.06, dd), V3(ox, gy - 0.03, zOut), gm, r: 0.004))
        // Offset: elbow, short diagonal, elbow back to vertical against the wall.
        let e1 = V3(ox, gy - 0.07, zOut), e2 = V3(ox, gy - 0.22, zWall)
        box(e1, e2)
        let bottom: Float = 0.24
        box(e2, V3(ox, bottom, zWall))
        // Section joint crimps.
        for y in stride(from: gy - 0.6, to: bottom + 0.2, by: -1.0) {
            m.add(HK.box(V3(dw + 0.004, 0.02, dd + 0.004), V3(ox, y, zWall), gm, r: 0.004))
        }
        // Wall straps.
        for y in [gy - 0.6, (gy + bottom) / 2, bottom + 0.4] {
            m.add(HK.box(V3(dw + 0.012, 0.025, 0.003), V3(ox, y, zWall + dd / 2 + 0.0015), strapMaterial, r: 0.001, seg: 1))
            for s: Float in [-1, 1] {
                m.add(HK.box(V3(0.003, 0.025, dd + 0.005), V3(ox + s * (dw / 2 + 0.006), y, zWall), strapMaterial, r: 0.001, seg: 1))
                m.add(HK.box(V3(0.025, 0.025, 0.003), V3(ox + s * (dw / 2 + 0.018), y, zw + 0.0015 + 0.02), strapMaterial, r: 0.001, seg: 1))
            }
        }
        // Kick-out shoe at the foot.
        box(V3(ox, bottom + 0.02, zWall), V3(ox, 0.05, zWall + 0.16))
        m.add(HK.box(V3(dw + 0.004, 0.006, 0.04), V3(ox, 0.04, zWall + 0.17), gm, r: 0.002))
        // Splash block.
        m.add(HK.box(V3(0.3, 0.035, 0.6), V3(ox, 0.0175, zWall + 0.4 - 0.15), "concrete.smooth", r: 0.008))

        groundAO(&m, height: 0.1, floor: 0.8)
        let b = m.bounds
        return LODModel(m.transformed(Xform(translation: V3(0, -b.min.y, -(b.min.z + b.max.z) / 2))))
    }
}
