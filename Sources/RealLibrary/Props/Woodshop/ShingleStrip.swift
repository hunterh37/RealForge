import simd
import Foundation

/// One 3-tab asphalt roofing shingle lying flat, granule side up. Real specs (ASTM D3462 strip shingle):
/// 36 x 12 in (914 x 305 mm), 3.2 mm (1/8 in) fibreglass mat saturated and coated with asphalt, ceramic
/// mineral granules on top; 5 in (127 mm) exposure; two cutouts 1/4 in wide x 5 in deep with round
/// keyway ends dividing three 12 in tabs; a painted nail line 5-5/8 in up from the tab edge,
/// a dashed thermoplastic self-seal strip at 6-1/4 in with four nails per shingle (1 in from each end and
/// above each cutout). Factory blend drops shade each tab slightly differently.
/// Story detail: a few granules shed onto the bench at one tab corner.
/// Frame: length along X, tab edge (exposed butt) at +Z, headlap at -Z, bottom on y = 0.
public struct ShingleStrip: RealAsset {
    public static let id = "shingle-strip"
    public static let summary = "3-tab asphalt roofing shingle, 36 x 12 in: granule surface, two keyway cutouts, self-seal strip, painted nail line."
    public static let tags = ["prop", "workshop", "construction"]
    public static let budget = 3_600
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 15, elevation: 42, distance: 1.25, studio: true)

    /// Length (m); 36 in.
    public var length: Float = 0.9144
    /// Depth, tab edge to top edge (m); 12 in.
    public var depth: Float = 0.3048
    /// Thickness (m).
    public var thickness: Float = 0.0032
    /// Exposure: cutout depth from the tab edge (m); 5 in.
    public var exposure: Float = 0.127
    /// Cutout width (m); 1/4 in.
    public var slotWidth: Float = 0.00635
    /// Granule color (sRGB hex); 5C5A57 weathered grey, 3E3A36 charcoal, 7A5A3E brown, 3B4A3A green.
    public var color: UInt32 = 0x5C5A57
    /// Tab-to-tab shade variation (fraction of the color).
    public var blend: Float = 0.1
    /// Nail line paint color (sRGB hex).
    public var nailLineColor: UInt32 = 0xE6E2D6
    public init() {}

    // MARK: public frame

    /// Distance of the nail line from the tab edge (m); 5-5/8 in.
    public var nailLineOffset: Float { 0.1429 }
    /// Distance of the self-seal strip center from the tab edge (m).
    public var sealStripOffset: Float { 0.1588 }
    /// The four nail points on the nail line (asset space, on the top face).
    public var nailPoints: [V3] {
        let z = depth / 2 - nailLineOffset, y = thickness
        return [-length / 2 + 0.0254, -length / 6, length / 6, length / 2 - 0.0254].map { V3($0, y, z) }
    }
    /// Centers of the three exposed tabs (asset space, top face).
    public var tabCenters: [V3] { [-length / 3, 0, length / 3].map { V3($0, thickness, depth / 2 - exposure / 2) } }
    /// Keyway ends of the two cutouts (asset space).
    public var cutoutTops: [V3] { [-length / 6, length / 6].map { V3($0, thickness, depth / 2 - exposure) } }
    /// Granule material for this shingle's color.
    public var granuleMaterial: MaterialKey { "roofing.shingle-granule:" + String(format: "%06X", color) }

    /// Outline in the XY plane (y here = asset -Z): tab edge at y = -depth/2, with two keyway cutouts.
    func outline(arc: Int) -> [V2] {
        let L = length, D = depth, w = slotWidth / 2, e = exposure
        var o: [V2] = [V2(-L / 2, -D / 2)]
        for xc in [-L / 6, L / 6] {
            o.append(V2(xc - w, -D / 2))
            for k in 0...arc {
                let a = Float.pi - Float(k) / Float(arc) * .pi
                o.append(V2(xc + w * cos(a), -D / 2 + e - w + w * sin(a)))
            }
            o.append(V2(xc + w, -D / 2))
        }
        o += [V2(L / 2, -D / 2), V2(L / 2, D / 2), V2(-L / 2, D / 2)]
        return o
    }

    /// Flat quad grid on the top face (x0...x1, z0...z1), `lift` above it.
    func patch(_ x0: Float, _ x1: Float, _ z0: Float, _ z1: Float, lift: Float, nx: Int, nz: Int, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let y = thickness + lift
        for j in 0...nz { for i in 0...nx {
            let x = x0 + (x1 - x0) * Float(i) / Float(nx), z = z0 + (z1 - z0) * Float(j) / Float(nz)
            s.add(V3(x, y, z), .up, V2(x, z))
        }}
        let row = UInt32(nx + 1)
        for j in 0..<UInt32(nz) { for i in 0..<UInt32(nx) {
            let a = j * row + i
            s.quad(a, a + row, a + row + 1, a + 1)
        }}
        s.recomputeNormals(weldSeams: false)
        if s.normals[0].y < 0 { s = s.flipped() }
        s.computeTangents()
        return s
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let L = length, D = depth, t = thickness, w = slotWidth / 2, zEdge = D / 2, zSlot = D / 2 - exposure
        var levels: [Model] = []
        for l in 0..<2 {
            var m = Model(name: Self.id)
            // Asphalt-coated mat: dark core shows on the cut edges and in the cutouts.
            let body = Prim.extrude(outline(arc: l == 0 ? 6 : 2), depth: t, bevel: 0.0006, bevelSegments: 1, material: "asphalt")
            m.add(body, Xform(translation: V3(0, t / 2, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(1, 0, 0))))

            // Granule coat: three tab patches with blend-drop shading, plus the headlap.
            var tr = rng.fork(3)
            let lift: Float = 0.00012
            let nx = l == 0 ? 6 : 2
            let xs: [(Float, Float)] = [(-L / 2 + 0.0006, -L / 6 - w), (-L / 6 + w, L / 6 - w), (L / 6 + w, L / 2 - 0.0006)]
            for (x0, x1) in xs {
                let shade = 1 + tr.float(-blend...blend)
                let c = scaled(color, shade)
                m.add(patch(x0, x1, zSlot - w, zEdge - 0.0006, lift: lift, nx: nx, nz: 2, material: "roofing.shingle-granule:" + c))
            }
            m.add(patch(-L / 2 + 0.0006, L / 2 - 0.0006, -zEdge + 0.0006, zSlot - w, lift: lift, nx: nx * 3, nz: 3, material: "roofing.shingle-granule:" + scaled(color, 0.94)))

            // Nail line: painted stripe across the headlap.
            let zn = zEdge - nailLineOffset
            m.add(patch(-L / 2 + 0.004, L / 2 - 0.004, zn - 0.0016, zn + 0.0016, lift: lift * 3, nx: nx * 3, nz: 1, material: "plastic.matte:" + String(format: "%06X", nailLineColor)))

            // Self-seal strip: dashes of thermoplastic asphalt, 1 in on, 1/2 in off.
            let zs = zEdge - sealStripOffset
            if l == 0 {
                var x = -L / 2 + 0.019
                var dr = rng.fork(5)
                while x + 0.0254 < L / 2 - 0.012 {
                    let len = 0.0254 + dr.float(-0.002...0.002)
                    m.add(Prim.superellipsoid(V3(len, 0.0012, 0.0072), exponent: 5, subdivisions: 3, material: "roofing.shingle-sealant"),
                          Xform(translation: V3(x + len / 2, t + 0.0002, zs + dr.float(-0.0008...0.0008))))
                    x += 0.0381
                }
            } else {
                m.add(patch(-L / 2 + 0.019, L / 2 - 0.012, zs - 0.0036, zs + 0.0036, lift: 0.0004, nx: 4, nz: 1, material: "roofing.shingle-sealant"))
            }

            // Story detail (LOD0): loose granules shed on the bench.
            if l == 0 {
                var g = rng.fork(9)
                let scuff = V2(L / 2 - 0.05, zEdge - 0.02)
                for _ in 0..<10 {
                    let p = V3(scuff.x + g.float(-0.04...0.06), 0.0004, zEdge + g.float(0.004...0.03))
                    m.add(Prim.superellipsoid(V3(repeating: g.float(0.0009...0.0016)), exponent: 3, subdivisions: 1,
                                              material: g.chance(0.5) ? granuleMaterial : "roofing.shingle-granule:A8A49C"), Xform(translation: p))
                }
            }
            groundAO(&m, height: 0.004, floor: 0.7)
            levels.append(m)
        }
        return LODModel(levels: levels, switchDistances: [3])
    }

    func scaled(_ c: UInt32, _ f: Float) -> String {
        let r = min(255, Float((c >> 16) & 0xFF) * f), g = min(255, Float((c >> 8) & 0xFF) * f), b = min(255, Float(c & 0xFF) * f)
        return String(format: "%02X%02X%02X", Int(r), Int(g), Int(b))
    }
}
