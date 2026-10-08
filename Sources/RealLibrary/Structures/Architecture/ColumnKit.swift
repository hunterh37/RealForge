import simd
import Foundation

/// Shared parts for the classical column orders (Doric, Ionic, Corinthian): fluted shafts with entasis,
/// attic bases and square plinths. Radii in meters; shafts are lathed around +Y.
public enum ColumnKit {
    /// Fluting styles: Doric scoops meet at sharp arrises; Ionic and Corinthian flutes are separated by fillets.
    public enum Fluting: Sendable { case none, arris(Int), fillet(Int) }

    /// Fluted shaft from `y0` to `y1` with entasis: radius `r0` at the foot easing to `r1` at the neck
    /// (straight for the lower third, then curving in).
    public static func shaft(y0: Float, y1: Float, r0: Float, r1: Float, fluting: Fluting, depth: Float,
                             material: MaterialKey) -> Surface {
        let rows = max(6, Int((y1 - y0) / 0.25))
        var p = ArchProfile(V2(r0, y0))
        for i in 1...rows {
            let t = Float(i) / Float(rows)
            let e = t < 0.33 ? 0 : pow((t - 0.33) / 0.67, 1.6)
            p.push(V2(r0 + (r1 - r0) * e, y0 + (y1 - y0) * t), sharp: false)
        }
        p.sharp[p.sharp.count - 1] = true
        let fade: (Float) -> Float = { y in smoothstep(y0, y0 + 0.06, y) * (1 - smoothstep(y1 - 0.06, y1, y)) }
        switch fluting {
        case .none:
            return ArchTrimKit.lathe(p, segments: 48, material: material, maxSeg: 0.2)
        case .arris(let n):
            return ArchTrimKit.lathe(p, segments: n * 6, material: material, maxSeg: 0.3) { a, y, _ in
                let u = (a * Float(n) / (2 * .pi)).truncatingRemainder(dividingBy: 1) * 2 - 1
                return -depth * sqrt(max(0, 1 - u * u)) * fade(y)
            }
        case .fillet(let n):
            return ArchTrimKit.lathe(p, segments: n * 7, material: material, maxSeg: 0.3) { a, y, _ in
                let u = (a * Float(n) / (2 * .pi)).truncatingRemainder(dividingBy: 1) * 2 - 1
                let f = abs(u) / 0.78
                return f >= 1 ? 0 : -depth * sqrt(1 - f * f) * fade(y)
            }
        }
    }

    /// Attic base (torus, scotia, torus) sitting at `y0`, rising to the shaft radius `r`. Returns its top y.
    public static func atticBase(_ m: inout Model, y0: Float, r: Float, material: MaterialKey) -> Float {
        var p = ArchProfile(V2(0, y0))
        p.to(V2(r * 1.22, y0))
        p.torus(r * 0.13)
        p.step(-r * 0.1); p.fillet(r * 0.03)
        p.scotia(r * 0.16, depth: r * 0.07)
        p.fillet(r * 0.03); p.step(r * 0.03)
        p.torus(r * 0.09)
        p.step(-(p.end.x - r * 1.04)); p.cavetto(r * 0.06, -r * 0.04)
        let top = p.end.y
        p.to(V2(0, top))
        m.add(ArchTrimKit.lathe(p, segments: 48, material: material))
        return top
    }

    /// Square plinth of side `side` and height `h` with softened arrises.
    public static func plinth(_ m: inout Model, side: Float, h: Float, material: MaterialKey) {
        m.add(Prim.roundedBox(V3(side, h, side), radius: 0.006, bevelSegments: 2, material: material), Xform(translation: V3(0, h / 2, 0)))
    }
}
