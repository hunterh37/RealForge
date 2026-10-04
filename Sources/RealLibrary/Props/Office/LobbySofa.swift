import simd
import Foundation

/// Modern three-seat lobby sofa, 210 x 85 x 75 cm: leather-wrapped box frame (block arms 17 cm wide, back
/// rail, front deck rail), three loose seat cushions and three back cushions with self-piped welts on
/// both boxing seams, crowned faces and a slight sitting sag, on two brushed stainless sled legs.
public struct LobbySofa: RealAsset {
    public static let id = "lobby-sofa"
    public static let summary = "Three-seat lobby sofa: black leather box frame, piped seat and back cushions with a slight sag, brushed stainless sled legs."
    public static let tags = ["prop", "furniture", "leather", "interior", "office"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 14, distance: 1.05, studio: true)

    public var width: Float = 2.1
    public var depth: Float = 0.85
    public var height: Float = 0.75
    /// Upholstery: `leather.black`, `leather.tan`, `fabric.upholstery:RRGGBB`.
    public var cover: MaterialKey = "leather.black"
    public var legs: MaterialKey = "metal.stainless"
    public var seats = 3
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [6])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, D = depth, H = height, L = cover
        let legH: Float = 0.14, armW: Float = 0.17, armH: Float = 0.62, backD: Float = 0.2, deckTop: Float = 0.3
        let seg = detail ? 2 : 1
        let welt: Float = 0.0035

        // Frame: arms full depth, back rail between them, deck under the seat cushions.
        for s: Float in [-1, 1] {
            let c = V3(s * (W / 2 - armW / 2), legH + (armH - legH) / 2, 0)
            let sz = V3(armW, armH - legH, D)
            m.add(Prim.roundedBox(sz, radius: 0.03, bevelSegments: seg, material: L), Xform(translation: c).jittered(&rng, deg: 0.1, offset: 0.0005))
            if detail {
                // Boxing welts around the front and back faces of the arm.
                for zs: Float in [-1, 1] {
                    let ring = Shape2D.roundedRect(sz.x - 0.004, sz.y - 0.004, radius: 0.028, segments: 4)
                        .map { V3(c.x + $0.x, c.y + $0.y, zs * (D / 2 - 0.009)) }
                    m.add(Prim.sweep(Shape2D.circle(welt, segments: 6), along: ring, closedPath: true, caps: false, material: L))
                }
            }
        }
        let innerW = W - 2 * armW
        m.add(Prim.roundedBox(V3(innerW + 0.01, H - 0.07 - legH, backD), radius: 0.03, bevelSegments: seg, material: L),
              Xform(translation: V3(0, legH + (H - 0.07 - legH) / 2, -D / 2 + backD / 2)))
        m.add(Prim.roundedBox(V3(innerW + 0.01, deckTop - legH, D - backD + 0.02), radius: 0.02, bevelSegments: seg, material: L),
              Xform(translation: V3(0, legH + (deckTop - legH) / 2, -D / 2 + backD + (D - backD) / 2 - 0.01)))

        // Seat cushions: crowned, sagging toward the front middle, welts on both boxing seams.
        let n = max(1, seats)
        let cw = innerW / Float(n) - 0.006, cd = D - backD - 0.012, ch: Float = 0.15
        let sub = detail ? 10 : 5
        for i in 0..<n {
            var r = rng.fork(i)
            let cx = -innerW / 2 + (Float(i) + 0.5) * innerW / Float(n)
            let cz = -D / 2 + backD + cd / 2 + 0.004
            let sag = r.float(0.008...0.016)
            var cushion = Prim.superellipsoid(V3(cw, ch, cd), exponent: 6, subdivisions: sub, material: L) { d in
                1 + 0.04 * max(0, d.y) * (1 - d.x * d.x)
            }
            cushion.deform { p in
                let fx = p.x / (cw / 2), fz = p.z / (cd / 2)
                let dip = max(0, 1 - fx * fx) * max(0, 1 - pow(fz - 0.2, 2)) * (p.y > 0 ? 1 : 0.2)
                return p - V3(0, dip * sag, 0)
            }
            let x = Xform(translation: V3(cx, deckTop + ch / 2, cz), rotation: simd_quatf(degrees: r.float(-0.6...0.6), axis: .up))
            m.add(cushion, x)
            if detail { pipe(&m, size: V3(cw, ch, cd), exponent: 6, x: x, sag: sag) }
        }
        // Back cushions: resting on the seat, leaning back 9 degrees against the rail.
        let bh: Float = H - deckTop - ch - 0.005, bt: Float = 0.17
        for i in 0..<n {
            var r = rng.fork(i + 10)
            let cx = -innerW / 2 + (Float(i) + 0.5) * innerW / Float(n)
            var cushion = Prim.superellipsoid(V3(cw, bh, bt), exponent: 5, subdivisions: sub, material: L) { d in
                1 + 0.05 * max(0, d.z) * (1 - d.x * d.x) * (1 - d.y * d.y)
            }
            let slump = r.float(0.006...0.012)
            cushion.deform { p in
                let fx = p.x / (cw / 2), fy = p.y / (bh / 2)
                return p - V3(0, 0, max(0, 1 - fx * fx) * max(0, 1 - fy * fy) * slump * (p.z > 0 ? 1 : 0.2))
            }
            let tilt = simd_quatf(degrees: -9 + r.float(-1...1), axis: V3(1, 0, 0))
            let base = V3(cx, deckTop + ch - 0.012, -D / 2 + backD + 0.012)
            let x = Xform(translation: base + tilt.act(V3(0, bh / 2, bt / 2)), rotation: tilt)
            m.add(cushion, x)
            if detail { pipe(&m, size: V3(cw, bt, bh), exponent: 5, x: Xform(translation: x.translation, rotation: x.rotation * simd_quatf(degrees: 90, axis: V3(1, 0, 0))), sag: 0) }
        }

        // Sled legs: 12 x 28 mm brushed stainless flat bar bent into a closed loop, one at each end.
        let loopD = D - 0.12, loopH = legH - 0.006
        let path = Shape2D.roundedRect(loopD, loopH - 0.028, radius: 0.035, segments: detail ? 5 : 2)
            .map { V3(0, 0.014 + (loopH - 0.028) / 2 + $0.y, $0.x) }
        let bar = Shape2D.roundedRect(0.012, 0.028, radius: 0.004, segments: detail ? 2 : 1)
        for s: Float in [-1, 1] {
            m.add(Prim.sweep(bar, along: path, up: V3(1, 0, 0), closedPath: true, caps: false, material: legs),
                  Xform(translation: V3(s * (W / 2 - armW / 2), 0, 0)))
        }
        groundAO(&m, height: 0.16, floor: 0.5)
        return m
    }

    /// Welts on both boxing seams of a cushion of `size` (seams on the local Y faces) placed by `x`.
    func pipe(_ m: inout Model, size: V3, exponent n: Float, x: Xform, sag: Float) {
        for ys: Float in [-1, 1] {
            let yy = ys * (size.y / 2 - 0.018)
            let k = pow(max(0, 1 - pow(abs(yy) / (size.y / 2), n)), 1 / n)
            let ring = Shape2D.roundedRect(size.x * k + 0.001, size.z * k + 0.001, radius: 0.05, segments: 4)
                .map { x.point(V3($0.x, yy - (ys > 0 ? sag * 0.1 : 0), -$0.y)) }
            m.add(Prim.sweep(Shape2D.circle(0.0035, segments: 6), along: ring, closedPath: true, caps: false, material: cover))
        }
    }
}
