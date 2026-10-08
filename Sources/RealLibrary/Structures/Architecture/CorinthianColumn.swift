import simd
import Foundation

/// Corinthian column, simplified: plinth, attic base, 24 filleted flutes with entasis, and a bell
/// capital lathed with two rows of eight acanthus leaves pushed out by displacement (serrated lobes, tips
/// curling outward), corner volutes, and a concave-sided abacus with a fleuron on each face.
/// Centered on X/Z, base at y = 0.
public struct CorinthianColumn: RealAsset {
    public static let id = "corinthian-column"
    public static let summary = "Corinthian column, 4.5 m: attic base, filleted flutes, bell capital with two acanthus rows, corner volutes, concave abacus."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone", "ornament"]
    public static let budget = 30_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 22, elevation: 6, distance: 1.0)

    /// Overall height (m).
    public var height: Float = 4.5
    /// Lower shaft diameter (m).
    public var diameter: Float = 0.45
    /// Number of flutes (0 = plain shaft).
    public var flutes = 24
    /// Acanthus projection scale (1 = classical).
    public var leafRelief: Float = 1
    /// Rain streak and soot strength.
    public var weathering: Float = 0.45
    public var material: MaterialKey = "stone.limestone"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let r = diameter / 2, H = height
        let ph = r * 0.45
        ColumnKit.plinth(&m, side: diameter * 1.4, h: ph, material: material)
        let by = ColumnKit.atticBase(&m, y0: ph, r: r, material: material)
        let abH = r * 0.3, capH = diameter * 1.1
        let bellTop = H - abH, bellBot = H - capH
        let r1 = r * 0.85
        m.add(ColumnKit.shaft(y0: by - 0.004, y1: bellBot - r * 0.08, r0: r, r1: r1,
                              fluting: flutes > 0 ? .fillet(flutes) : .none, depth: r * 0.06, material: material))
        // Astragal.
        var a = ArchProfile(V2(0, bellBot - r * 0.09)); a.to(V2(r1, a.end.y)); a.bead(r * 0.045); a.to(V2(0, a.end.y))
        m.add(ArchTrimKit.lathe(a, segments: 40, material: material))
        // Bell with acanthus displacement.
        let hb = bellTop - bellBot
        var bell = ArchProfile(V2(0, bellBot))
        bell.to(V2(r1 * 0.98, bellBot))
        for i in 1...24 {
            let t = Float(i) / 24
            bell.push(V2(r1 * 0.98 + (r * 1.02 - r1 * 0.98) * t * t, bellBot + hb * t), sharp: false)
        }
        bell.sharp[bell.sharp.count - 1] = true
        bell.step(r * 0.06); bell.to(V2(0, bell.end.y))
        let relief = leafRelief * r
        let rows: [(y0: Float, h: Float, phase: Float)] = [(0, 0.38, 0), (0.18, 0.42, .pi / 8), (0.5, 0.42, 0)]
        let leaves = ArchTrimKit.lathe(bell, segments: 120, material: material, maxSeg: hb / 20) { ang, y, _ in
            let t = (y - bellBot) / hb
            guard t > 0, t < 1 else { return 0 }
            var d: Float = 0
            for (k, row) in rows.enumerated() {
                let lt = (t - row.y0) / row.h
                guard lt > 0, lt < 1 else { continue }
                let n: Float = k == 2 ? 4 : 8
                // Angular distance to the nearest leaf center, as a fraction of the leaf spacing.
                var u = ((ang - row.phase) * n / (2 * .pi)).truncatingRemainder(dividingBy: 1)
                if u < 0 { u += 1 }
                let du = abs(u - 0.5) * 2               // 0 at the leaf center, 1 between leaves
                let halfW = (k == 2 ? 0.55 : 0.85) * sin(.pi * pow(lt, 0.7)) + 0.05
                guard du < halfW else { continue }
                let across = du / halfW
                let lobes = 0.88 + 0.12 * cos(across * 10 + lt * 14)
                let rib = 1 - 0.25 * exp(-across * across * 60)                   // midrib groove
                let curl = 0.25 + 1.6 * pow(lt, 2.2) * (1 - smoothstep(0.88, 1, lt) * 0.7)
                d = max(d, relief * 0.16 * (1 - across * across) * lobes * rib * curl)
            }
            return d
        }
        m.add(leaves)
        // Corner volutes under the abacus horns, facing out on the diagonals.
        let vol = ArchTrimKit.volute(radius: r * 0.22, turns: 2.25, wire: r * 0.026, material: material)
        for k in 0..<4 {
            let ang = Float.pi / 4 + Float(k) * .pi / 2
            let dir = V3(cos(ang), 0, sin(ang))
            let rot = simd_quatf(from: V3(0, 0, 1), to: dir)
            m.add(vol, Xform(translation: dir * (r * 1.12) + V3(0, bellTop - r * 0.2, 0), rotation: rot))
        }
        // Concave-sided abacus with chamfered horns, and a fleuron per face.
        let s = r * 1.42, bow = r * 0.2
        var o: [V2] = []
        for side in 0..<4 {
            let a0 = Float(side) * .pi / 2
            let c0 = V2(cos(a0 + .pi / 4), sin(a0 + .pi / 4)) * s * 1.414, c1 = V2(cos(a0 + 3 * .pi / 4), sin(a0 + 3 * .pi / 4)) * s * 1.414
            let ch = Float(0.08)
            let p0 = c0 + (c1 - c0) * ch, p1 = c1 + (c0 - c1) * ch
            for j in 0...8 {
                let t = Float(j) / 8
                let mid = V2(cos(a0 + .pi / 2), sin(a0 + .pi / 2))
                o.append(p0 + (p1 - p0) * t - mid * bow * sin(.pi * t))
            }
        }
        o = Shape2D.deduped(o)
        m.add(Prim.extrude(o, depth: abH, bevel: 0.006, bevelSegments: 2, material: material),
              Xform(translation: V3(0, bellTop + abH / 2, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(1, 0, 0))))
        let fl = ArchTrimKit.rosette(radius: r * 0.12, height: r * 0.07, petals: 6, material: material)
        for k in 0..<4 {
            let ang = Float(k) * .pi / 2
            let dir = V3(cos(ang), 0, sin(ang))
            m.add(fl, Xform(translation: dir * (s - bow + 0.004) + V3(0, bellTop + abH * 0.5, 0), rotation: simd_quatf(from: V3(0, 1, 0), to: dir)))
        }
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        groundAO(&m, height: 0.4, floor: 0.6)
        return LODModel(ArchTrimKit.ground(m))
    }
}
