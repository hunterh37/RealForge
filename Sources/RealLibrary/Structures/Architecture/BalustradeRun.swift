import simd
import Foundation

/// Balustrade run: plinth, bottom rail, turned single-vase balusters on square plinths and abaci, a
/// molded handrail, and square end pedestals with caps. Freestanding, centered on X/Z; tile every
/// `length` (set `pedestals` off at one end to share them between runs).
public struct BalustradeRun: RealAsset {
    public static let id = "balustrade-run"
    public static let summary = "Balustrade run, 2.4 m: plinth rail, turned double-vase balusters, molded handrail and end pedestals; tiles along X."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone", "fence"]
    public static let budget = 25_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 28, elevation: 10, distance: 1.0)

    /// Run length along X including pedestals (m).
    public var length: Float = 2.4
    /// Overall height (m).
    public var height: Float = 0.95
    /// Rail width (Z, m).
    public var railWidth: Float = 0.26
    /// Baluster centers (m).
    public var spacing: Float = 0.27
    /// End pedestals at -X / +X.
    public var pedestalStart = true
    public var pedestalEnd = true
    /// Pedestal width (m).
    public var pedestalWidth: Float = 0.34
    /// Rain streak and soot strength.
    public var weathering: Float = 0.5
    public var material: MaterialKey = "stone.cast-stone"
    public init() {}

    /// Symmetric rail section (z, y) from a right-half profile drawn bottom to top from z = 0.
    static func section(_ half: ArchProfile) -> [V2] {
        let r = half.points.map { V2($0.x, $0.y) }
        let l = r.reversed().map { V2(-$0.x, $0.y) }
        return Shape2D.deduped(r + l.dropFirst().dropLast())
    }

    func rail(_ half: ArchProfile, y: Float, x0: Float, x1: Float) -> (Surface, Xform) {
        let s = Prim.extrude(Self.section(half), depth: x1 - x0, bevel: 0.003, bevelSegments: 1, material: material)
        return (s, Xform(translation: V3((x0 + x1) / 2, y, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 1, 0))))
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length, H = height, hw = railWidth / 2
        let pw = pedestalWidth
        let xa = -L / 2 + (pedestalStart ? pw : 0), xb = L / 2 - (pedestalEnd ? pw : 0)
        // Plinth + bottom rail with a sloped top.
        var bot = ArchProfile(V2(0, 0)); bot.step(hw + 0.02); bot.fillet(0.1); bot.step(-0.02); bot.fillet(0.03); bot.to(V2(hw - 0.03, 0.15)); bot.to(V2(0, 0.155))
        let (bs, bx) = rail(bot, y: 0, x0: xa - 0.01, x1: xb + 0.01)
        m.add(bs, bx)
        // Handrail: fillet, cyma reversa, fascia, ovolo, cushioned top.
        let topH: Float = 0.13
        var top = ArchProfile(V2(0, 0)); top.step(hw - 0.03); top.fillet(0.012); top.cymaReversa(0.03, 0.03); top.fillet(0.05)
        top.ovolo(0.025, -0.02); top.to(V2(0, topH))
        let (ts, tx) = rail(top, y: H - topH, x0: xa - 0.01, x1: xb + 0.01)
        m.add(ts, tx)
        // Balusters.
        let b0: Float = 0.155, b1 = H - topH
        let bh = b1 - b0
        let blockH: Float = 0.035
        var p = ArchProfile(V2(0, blockH))
        let k = bh - 2 * blockH
        func Y(_ t: Float) -> Float { blockH + k * t }
        p.to(V2(0.05, Y(0)))
        p.torus(k * 0.025); p.fillet(k * 0.02)
        p.cavetto(k * 0.03, -0.012)
        // Vase belly (smooth), neck, then cap.
        let belly: [V2] = [V2(0.048, Y(0.14)), V2(0.062, Y(0.24)), V2(0.066, Y(0.32)), V2(0.058, Y(0.44)), V2(0.04, Y(0.58)),
                           V2(0.026, Y(0.7)), V2(0.022, Y(0.76))]
        for q in belly { p.push(q, sharp: false) }
        p.sharp[p.sharp.count - 1] = true
        p.bead(k * 0.012); p.fillet(k * 0.02)
        p.ovolo(k * 0.06, 0.028); p.fillet(k * 0.03)
        p.cavetto(k * 0.05, 0.01); p.fillet(k * 0.03)
        p.to(V2(0, p.end.y))
        let turned = ArchTrimKit.lathe(p.scaled(V2(1, 1)), segments: 24, material: material, maxSeg: 0.03)
        let block = Prim.roundedBox(V3(0.12, blockH, 0.12), radius: 0.004, bevelSegments: 1, material: material)
        let n = max(1, Int(((xb - xa) / spacing).rounded())), pitch = (xb - xa) / Float(n)
        for i in 0..<n {
            var r = rng.fork(i)
            let x = xa + pitch * (Float(i) + 0.5)
            let t = Xform(translation: V3(x, b0, 0), rotation: simd_quatf(angle: r.float(0...6.28), axis: V3(0, 1, 0)))
            m.add(turned, t)
            m.add(block, Xform(translation: V3(x, b0 + blockH / 2, 0)))
            m.add(block, Xform(translation: V3(x, b0 + bh - blockH / 2 - 0.002, 0)))
        }
        // Pedestals: die with base and cap moldings.
        for (on, x) in [(pedestalStart, -L / 2 + pw / 2), (pedestalEnd, L / 2 - pw / 2)] where on {
            m.add(Prim.roundedBox(V3(pw, 0.16, pw), radius: 0.006, bevelSegments: 2, material: material), Xform(translation: V3(x, 0.08, 0)))
            m.add(Prim.roundedBox(V3(pw - 0.05, H - 0.3, pw - 0.05), radius: 0.006, bevelSegments: 2, material: material), Xform(translation: V3(x, 0.16 + (H - 0.3) / 2, 0)))
            m.add(Prim.roundedBox(V3(pw + 0.03, 0.05, pw + 0.03), radius: 0.008, bevelSegments: 2, material: material), Xform(translation: V3(x, H - 0.115, 0)))
            m.add(Prim.roundedBox(V3(pw + 0.05, 0.09, pw + 0.05), radius: 0.012, bevelSegments: 3, material: material), Xform(translation: V3(x, H - 0.045, 0)))
        }
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        groundAO(&m, height: 0.3, floor: 0.6)
        return LODModel(ArchTrimKit.ground(m))
    }
}
