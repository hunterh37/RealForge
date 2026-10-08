import simd
import Foundation

/// Scroll corbel (console bracket): S-scroll side profile with a large volute under the bearing block and
/// a small one at the foot, volute bosses on both cheeks, a raised strap down the front and a cap
/// block. Back on the wall plane; base (foot of the scroll) at y = 0.
public struct ScrollCorbel: RealAsset {
    public static let id = "scroll-corbel"
    public static let summary = "Scroll corbel, 0.46 m: S-scroll console with volute bosses, a front strap and a bearing block."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone", "ornament"]
    public static let budget = 9_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 40, elevation: 8, distance: 1.1)

    /// Height (m), projection at the top (m) and width (m).
    public var height: Float = 0.42
    public var projection: Float = 0.28
    public var width: Float = 0.14
    /// Rain streak and soot strength.
    public var weathering: Float = 0.45
    public var material: MaterialKey = "stone.limestone"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let H = height, P = projection, W = width
        // Side outline (z, y): back on z = 0, S-curved front from the upper volute to the foot.
        let rU = H * 0.2, cU = V2(P - rU, H - rU)        // upper volute
        let rL = H * 0.11, cL = V2(rL * 1.2, rL)           // lower volute
        var o: [V2] = [V2(0, 0), V2(cL.x, 0)]
        for k in 1...6 { let a = -Float.pi / 2 + Float(k) / 6 * Float.pi * 0.9; o.append(cL + V2(cos(a), sin(a)) * rL) }
        let pA = o.last!, pB = cU + V2(cos(-Float.pi * 0.62), sin(-Float.pi * 0.62)) * rU
        for k in 1..<10 {
            let t = Float(k) / 10, s = t * t * (3 - 2 * t)
            let base = pA + (pB - pA) * t
            o.append(base + V2(-0.035 * sin(.pi * t * 2) * H / 0.42, 0) + V2(0, (s - t) * 0.02))
        }
        for k in 0...10 { let a = -Float.pi * 0.62 + Float(k) / 10 * Float.pi * 1.12; o.append(cU + V2(cos(a), sin(a)) * rU) }
        o.append(V2(cU.x - rU * 0.3, H)); o.append(V2(0, H))
        o = Shape2D.deduped(o)
        let body = Prim.extrude(o, depth: W, bevel: 0.006, bevelSegments: 2, material: material)
        m.add(body, Xform(rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 1, 0))))
        // Volute bosses on both cheeks.
        let vu = ArchTrimKit.volute(radius: rU * 0.92, turns: 2.5, wire: 0.007, material: material)
        let vl = ArchTrimKit.volute(radius: rL * 0.9, turns: 2, wire: 0.005, material: material)
        for s in [Float(-1), 1] {
            let face = simd_quatf(angle: s * .pi / 2, axis: V3(0, 1, 0))
            m.add(vu, Xform(translation: V3(s * (W / 2 + 0.001), cU.y, cU.x), rotation: face))
            m.add(vl, Xform(translation: V3(s * (W / 2 + 0.001), cL.y, cL.x), rotation: face))
        }
        // Front strap: a raised fillet band down the S-curve, flanked by the cheeks.
        let strap = o.filter { $0.x > 0.02 && $0.y > 0.01 && $0.y < H - 0.005 }
        if strap.count > 2 {
            let path = strap.map { V3(0, $0.y, $0.x + 0.002) }.reversed().map { $0 }
            let sec: [V2] = [V2(-W * 0.22, -0.004), V2(W * 0.22, -0.004), V2(W * 0.2, 0.006), V2(-W * 0.2, 0.006)]
            m.add(Prim.sweep(sec, along: path, up: V3(1, 0, 0), material: material))
        }
        // Bearing block on top and a fillet under it.
        m.add(Prim.roundedBox(V3(W + 0.03, 0.035, P + 0.02), radius: 0.004, bevelSegments: 2, material: material),
              Xform(translation: V3(0, H + 0.0175, (P + 0.02) / 2)))
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        return LODModel(ArchTrimKit.ground(m))
    }
}
