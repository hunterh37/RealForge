import simd
import Foundation

/// English picnic hamper, 46 x 40 x 30 cm with handle: stake-and-strand willow body flaring slightly to
/// a two-strand braided rim, flat woven base on two oak skids, twin lids hinged on the center line with
/// leather hinge tabs, bentwood rattan handle wrapped in leather at the ends, two leather closure straps
/// with brass buckles on the front.
public struct WickerBasket: RealAsset {
    public static let id = "wicker-basket"
    public static let summary = "Woven willow picnic basket: stake-and-strand weave, braided rim, hinged twin lids, bentwood handle, leather straps and buckles."
    public static let tags = ["prop", "decor", "wood", "container", "leather"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 20, distance: 1.15, studio: true)

    public var weave: MaterialKey = "wicker.willow"
    public var leather: MaterialKey = "leather.tan:5A3A22"
    /// Body footprint at the base (m) and wall height (m).
    public var footprint = V2(0.42, 0.26)
    public var wallHeight: Float = 0.2
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let skid: Float = 0.014
        let b0 = footprint, flare: Float = 0.012
        let topY = skid + wallHeight
        // Body: lofted rounded-rect rings, slight belly and flare.
        func outline(_ grow: Float) -> [V2] { Shape2D.roundedRect(b0.x + grow * 2, b0.y + grow * 2, radius: 0.045 + grow * 0.5, segments: 5) }
        var rings: [[V3]] = []
        for k in 0...6 {
            let t = Float(k) / 6
            let grow = flare * t + 0.004 * sin(t * .pi)
            rings.append(Prim.ring(outline(grow), y: skid + 0.004 + (wallHeight - 0.004) * t))
        }
        rings.insert(Prim.ring(outline(-0.006), y: skid), at: 0)
        m.add(Prim.loft(rings, capStart: true, material: weave))
        // Two-strand braided rim.
        let rimRing = Shape2D.offset(outline(flare), 0.002)
        let rimPath = (rimRing + [rimRing[0]]).map { V3($0.x, topY, -$0.y) }
        let dense = resample(rimPath, spacing: 0.0065)
        for strand in 0..<2 {
            var pts: [V3] = []
            var acc: Float = 0
            for i in dense.indices {
                if i > 0 { acc += simd_distance(dense[i], dense[i - 1]) }
                let a = dense[max(0, i - 1)], b = dense[min(dense.count - 1, i + 1)]
                let tng = simd_normalize(b - a)
                let out = simd_normalize(simd_cross(tng, .up))
                let ph = acc / 0.04 * 2 * .pi + Float(strand) * .pi
                pts.append(dense[i] + out * cos(ph) * 0.0055 + V3(0, sin(ph) * 0.0055, 0))
            }
            m.add(Prim.tube(pts, radii: pts.map { _ in 0.0058 }, sides: 5, seamTile: 0.02, material: "wood.rattan", capEnd: false))
        }
        // Skids.
        for z: Float in [-b0.y * 0.3, b0.y * 0.3] {
            m.add(plank(b0.x - 0.03, 0.022, skid, bevel: 0.003, material: "wood.oak"), Xform(translation: V3(0, skid / 2, z)))
        }
        // Twin lids: shallow domed woven panels with a rolled edge, hinged at z = 0.
        let lidW = b0.x + flare * 2 + 0.008, lidD = (b0.y + flare * 2 + 0.008) / 2
        let lift = rng.float(0...0.004)
        for s: Float in [-1, 1] {
            var panel = Prim.superellipsoid(V3(lidW, 0.03, lidD), exponent: 6, subdivisions: 8, material: weave)
            panel.deform { p in V3(p.x, max(p.y, -0.004) * 0.9, p.z) }
            m.add(panel, Xform(translation: V3(0, topY + 0.008 + (s > 0 ? lift : 0), s * (lidD / 2 + 0.002))))
            let edge = Shape2D.roundedRect(lidW - 0.006, lidD - 0.004, radius: 0.03, segments: 4).map { V3($0.x, topY + 0.006, s * (lidD / 2 + 0.002) - $0.y) }
            m.add(Prim.sweep(Shape2D.circle(0.005, segments: 6), along: edge, closedPath: true, caps: false, grainAlongPath: true, material: "wood.rattan"))
        }
        // Leather hinge tabs on the center line.
        for x: Float in [-0.12, 0.12] {
            m.add(Prim.roundedBox(V3(0.04, 0.003, 0.05), radius: 0.001, bevelSegments: 1, material: leather), Xform(translation: V3(x, topY + 0.024, 0)))
        }
        // Bentwood handle across the lids, ends wrapped in leather where they meet the rim.
        let hx = b0.x / 2 + flare - 0.012, hTop = topY + 0.165
        let arch = catmull([V3(-hx, topY - 0.02, 0), V3(-hx, topY + 0.03, 0), V3(-hx * 0.86, topY + 0.11, 0), V3(-hx * 0.5, hTop - 0.008, 0),
                            V3(0, hTop, 0), V3(hx * 0.5, hTop - 0.008, 0), V3(hx * 0.86, topY + 0.11, 0), V3(hx, topY + 0.03, 0), V3(hx, topY - 0.02, 0)], per: 4)
        m.add(Prim.sweep(Shape2D.roundedRect(0.022, 0.012, radius: 0.005, segments: 2), along: arch, up: V3(0, 0, 1), grainAlongPath: true, material: "wood.rattan"))
        for s: Float in [-1, 1] {
            for k in 0..<4 {
                let y = topY - 0.012 + Float(k) * 0.009
                m.add(Prim.roundedBox(V3(0.03, 0.007, 0.02), radius: 0.0025, bevelSegments: 1, material: leather), Xform(translation: V3(s * (hx + 0.002), y, 0)))
            }
        }
        // Closure straps: from the front lid, over the edge, down to a buckle on the wall.
        let fz = b0.y / 2 + flare + 0.002
        for x: Float in [-0.11, 0.11] {
            let path = [V3(x, topY + 0.026, fz - 0.07), V3(x, topY + 0.027, fz - 0.02), V3(x, topY + 0.018, fz + 0.006), V3(x, topY - 0.01, fz + 0.007), V3(x, topY - 0.06, fz + 0.004)]
            m.add(Prim.sweep(Shape2D.roundedRect(0.022, 0.003, radius: 0.001, segments: 1), along: catmull(path, per: 3), up: V3(1, 0, 0), material: leather))
            let by = topY - 0.05, bz = fz + 0.01
            let frame = Shape2D.roundedRect(0.026, 0.022, radius: 0.004, segments: 2).map { V3(x + $0.x, by + $0.y, bz) }
            m.add(Prim.sweep(Shape2D.circle(0.0016, segments: 5), along: frame, closedPath: true, caps: false, material: "metal.brass"))
            m.add(Prim.tube([V3(x - 0.011, by, bz + 0.001), V3(x + 0.004, by, bz + 0.002)], radii: [0.0012, 0.0011], sides: 5, seamTile: 0.02, material: "metal.brass"))
            m.add(Prim.roundedBox(V3(0.022, 0.05, 0.003), radius: 0.001, bevelSegments: 1, material: leather), Xform(translation: V3(x, topY - 0.085, fz + 0.003)))
        }
        groundAO(&m, height: 0.06, floor: 0.55)
        return LODModel(m)
    }
}
