import simd
import Foundation

/// 3/4 in bevel-edge bench chisel, 246 mm overall, lying bevel-up on its back: tool-steel blade 19 mm
/// wide and 4.5 mm thick with ground side bevels down to 0.8 mm lands, a 25 degree honed primary bevel
/// and a flat back; round neck and flared bolster; brass ferrule; turned ash handle swelling to 30 mm;
/// steel strike hoop with the end grain mushroomed slightly past it from mallet blows.
///
/// Tool frame: blade along -X from the cutting edge at the origin, flat back on y = 0, handle axis at
/// y = `axisY`. `rest` rolls it about the edge until the handle's belly touches the bench.
public struct WoodChisel: RealAsset {
    public static let id = "wood-chisel"
    public static let summary = "3/4 in bevel-edge chisel: ground steel blade with honed bevel and flat back, bolster, brass ferrule, ash handle with a steel strike hoop."
    public static let tags = ["prop", "workshop", "tool", "handheld", "metal", "wood"]
    public static let budget = 5_200
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 36, distance: 0.58)

    /// Blade width (m), 3/4 in.
    public var width: Float = 0.019
    /// Primary bevel angle (degrees).
    public var bevelAngle: Float = 25
    public var blade: MaterialKey = "metal.tool-ground"
    public var honed: MaterialKey = "metal.surgical-mirror"
    public var ferrule: MaterialKey = "metal.brass-aged"
    public var handle: MaterialKey = "wood.chisel-ash"
    public var hoop: MaterialKey = "metal.hammer-forged"
    public init() {}

    static let axisY: Float = 0.0045
    /// Handle lathe profile (radius, x) from the ferrule to the strike end.
    static let handleProfile: [(r: Float, x: Float)] = [
        (0.0090, -0.1255), (0.0101, -0.1390), (0.0110, -0.1440), (0.0126, -0.1560), (0.0140, -0.1780), (0.0148, -0.2030),
        (0.0146, -0.2160), (0.0138, -0.2280), (0.0134, -0.2330), (0.0134, -0.2400), (0.0130, -0.2420), (0.0118, -0.2448),
        (0.0080, -0.2460), (0.0, -0.2463),
    ]

    /// Roll about the edge until the first handle station touches (the handle belly), center on X/Z.
    func rest() -> Xform {
        var alpha: Float = 0
        for (r, xc) in Self.handleProfile where r > 0 {
            let a = -xc, b = Self.axisY
            let d = sqrt(a * a + b * b)
            alpha = max(alpha, asin(min(1, r / d)) - atan2(b, a))
        }
        // Hoop (radius 14.2 mm) and ferrule (10.8 mm) are supports too.
        for (r, xc) in [(Float(0.0142), Float(-0.236)), (0.0108, -0.132)] {
            let a = -xc, b = Self.axisY, d = sqrt(a * a + b * b)
            alpha = max(alpha, asin(min(1, r / d)) - atan2(b, a))
        }
        var x = Xform(rotation: simd_quatf(angle: -alpha, axis: V3(0, 0, 1)))
        let c = x.point(V3(-0.1232, 0, 0))
        x.translation = V3(-c.x, 0, 0)
        return x
    }

    /// Center of the cutting edge, asset space.
    public var edgeCenter: V3 { rest().point(V3(0, 0.0001, 0)) }
    /// Unit direction the edge cuts in: along the blade from the handle toward the edge, asset space.
    public var edgeDirection: V3 { rest().direction(V3(1, 0, 0)) }
    /// Center of the hand hold on the handle, asset space.
    public var grip: V3 { rest().point(V3(-0.19, Self.axisY, 0)) }

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, land: Float = 0.0008, sideBev: Float = 0.0029

        // Trapezoid section with ground side bevels, 18 points (3 per edge), back on y = 0.
        func blade(_ th: Float) -> [V2] {
            let l = min(land, th * 0.5)
            let b = sideBev * max(0, min(1, (th - l) / (0.0038 - land)))
            let c: [V2] = [V2(-W / 2, 0), V2(W / 2, 0), V2(W / 2, l), V2(W / 2 - b, th), V2(-W / 2 + b, th), V2(-W / 2, l)]
            var out: [V2] = []
            for i in 0..<6 { let a = c[i], d = c[(i + 1) % 6]; for k in 0..<3 { out.append(a + (d - a) * (Float(k) / 3)) } }
            return out
        }
        func round(_ like: [V2], r: Float) -> [V2] {
            let cen = V2(0, Self.axisY)
            return like.map { q in let d = q - V2(0, 0.002); let a = atan2(d.y, d.x); return cen + V2(cos(a), sin(a)) * r }
        }
        let tanB = tan(bevelAngle * .pi / 180)
        // Honed primary bevel (crisp facet: its own surface).
        let bx: [Float] = [0, -0.0004, -0.0025, -0.0055, -0.0038 / tanB]
        let bevelPath = bx.map { V3($0, 0, 0) }
        m.add(HTKit.loft(bevelPath, up: V3(0, 1, 0), material: honed) { i in blade(max(0.00022, -bx[i] * tanB)) })
        // Blade body: slight thickening toward the neck.
        let body: [(x: Float, th: Float)] = [(-0.0038 / tanB, 0.0038), (-0.03, 0.0039), (-0.07, 0.0042), (-0.1, 0.0045)]
        m.add(HTKit.loft(body.map { V3($0.x, 0, 0) }, up: V3(0, 1, 0), material: self.blade) { i in blade(body[i].th) })
        // Neck: blade section morphs to a round 9 mm shank.
        let nk: [(x: Float, t: Float, r: Float)] = [(-0.1, 0, 0), (-0.106, 0.35, 0.0052), (-0.111, 0.75, 0.0047), (-0.115, 1, 0.0045), (-0.121, 1, 0.0045)]
        let base = blade(0.0045)
        m.add(HTKit.loft(nk.map { V3($0.x, 0, 0) }, up: V3(0, 1, 0), material: self.blade) { i in
            let rr = round(base, r: max(nk[i].r, 0.0045))
            return zip(base, rr).map { $0 + ($1 - $0) * nk[i].t }
        })
        // Bolster, ferrule, handle, strike hoop: turned about the handle axis (lathes about +Y, turned to -X).
        let toAxis = Xform(translation: V3(0, Self.axisY, 0), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1)))
        func lathe(_ prof: [(Float, Float)], seg: Int, mat: MaterialKey) -> Surface {
            // prof: (radius, x) with x decreasing; lathe y = -x.
            Prim.lathe(prof.map { V2($0.0, -$0.1) }, segments: seg, seamTile: 0.05, material: mat, swapUV: true).transformed(toAxis)
        }
        m.add(lathe([(0.0, -0.1190), (0.0047, -0.1192), (0.0050, -0.1200), (0.0070, -0.1214), (0.0085, -0.1228), (0.0086, -0.1240),
                     (0.0084, -0.1250), (0.0, -0.1252)], seg: 24, mat: self.blade))
        m.add(lathe([(0.0, -0.1246), (0.0100, -0.1248), (0.0107, -0.1256), (0.0108, -0.1380), (0.0104, -0.1392), (0.0, -0.1394)],
                    seg: 28, mat: ferrule))
        var wood = lathe(Self.handleProfile.map { ($0.r, $0.x) }, seg: 28, mat: handle)
        // Grime where the palm wraps the belly; end grain bruised dark by mallet blows past the hoop.
        wood.paintSplat { q in
            let grip = smoothstep(-0.150, -0.175, q.x) * smoothstep(-0.232, -0.212, q.x) * 0.85
            return max(grip, smoothstep(-0.2395, -0.2425, q.x))
        }
        m.add(wood)
        m.add(lathe([(0.0128, -0.2328), (0.0140, -0.2330), (0.0142, -0.2342), (0.0142, -0.2392), (0.0139, -0.2402), (0.0128, -0.2404)],
                    seg: 28, mat: hoop))

        let x = rest()
        var out = Model(name: Self.id)
        for s in m.surfaces { out.add(s, x) }
        groundAO(&out, height: 0.015, floor: 0.55)
        return LODModel(out)
    }
}
