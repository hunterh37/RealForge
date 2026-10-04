import simd
import Foundation

/// Top-loading bottled water cooler: white gloss cabinet 32 x 32 x 99 cm with a grey recessed dispensing
/// alcove, removable drip tray and slotted grate, hot (red) and cold (blue) push-paddle taps, bottle
/// collar on top, black condenser grille on the back. Carries an inverted 18.9 L (5 gal) blue-tinted
/// PET bottle, 27 cm across and 49 cm tall with ribbed walls, about two thirds full.
public struct WaterCooler: RealAsset {
    public static let id = "water-cooler"
    public static let summary = "Bottled water cooler: white gloss cabinet, grey alcove with drip tray, hot and cold taps, inverted ribbed 18.9 L blue PET bottle."
    public static let tags = ["prop", "office", "plastic", "kitchen"]
    public static let budget = 7_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 10, distance: 1.1, studio: true)

    public var cabinet: MaterialKey = "plastic.gloss"
    public var trim: MaterialKey = "plastic.matte:6A6E72"
    public var bottle: MaterialKey = "glass.clear:8DBCEB"
    public var water: MaterialKey = "glass.frosted:6FA6E0"
    /// Water level in the bottle, 0 empty to 1 full.
    public var fill: Float = 0.65
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [6])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W: Float = 0.32, D: Float = 0.32, H: Float = 0.99
        let base: Float = 0.02, alcove0: Float = 0.6, alcove1: Float = 0.85, recess: Float = 0.085
        let seg = detail ? 2 : 1
        let white = cabinet, black: MaterialKey = "plastic.black"
        // Recessed base, lower body, rear block behind the alcove, side cheeks, hood.
        m.add(Prim.roundedBox(V3(W - 0.02, base + 0.01, D - 0.02), radius: 0.004, bevelSegments: 1, material: trim), Xform(translation: V3(0, (base + 0.01) / 2, 0)))
        m.add(Prim.roundedBox(V3(W, alcove0 - base, D), radius: 0.016, bevelSegments: seg, material: white), Xform(translation: V3(0, base + (alcove0 - base) / 2, 0)))
        m.add(Prim.roundedBox(V3(W, alcove1 - alcove0 + 0.04, D - recess), radius: 0.016, bevelSegments: seg, material: white),
              Xform(translation: V3(0, (alcove0 + alcove1) / 2, -recess / 2)))
        for s: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.03, alcove1 - alcove0 + 0.04, D), radius: 0.012, bevelSegments: seg, material: white),
                  Xform(translation: V3(s * (W / 2 - 0.015), (alcove0 + alcove1) / 2, 0)))
        }
        m.add(Prim.roundedBox(V3(W, H - alcove1, D), radius: 0.016, bevelSegments: seg, material: white), Xform(translation: V3(0, alcove1 + (H - alcove1) / 2, 0)))
        // Grey alcove liner on the back wall and a grey hood underside.
        m.add(Prim.roundedBox(V3(W - 0.06, alcove1 - alcove0 - 0.004, 0.006), radius: 0.002, bevelSegments: 1, material: trim),
              Xform(translation: V3(0, (alcove0 + alcove1) / 2, D / 2 - recess + 0.003)))
        m.add(cuboid(V3(W - 0.06, 0.003, recess), material: trim), Xform(translation: V3(0, alcove1 - 0.0005, D / 2 - recess / 2)))

        // Drip tray with slotted grate, proud of the front by 12 mm.
        let trayD = recess + 0.012, trayY = alcove0 + 0.018
        m.add(Prim.roundedBox(V3(W - 0.07, 0.036, trayD), radius: 0.006, bevelSegments: detail ? 2 : 1, material: trim),
              Xform(translation: V3(0, alcove0 + 0.0, D / 2 - recess + trayD / 2)))
        let bars = detail ? 9 : 4
        for i in 0..<bars {
            let x = (Float(i) / Float(bars - 1) - 0.5) * (W - 0.1)
            m.add(cuboid(V3(0.012, 0.004, trayD - 0.02), material: white),
                  Xform(translation: V3(x, trayY + 0.0005, D / 2 - recess + trayD / 2)))
        }

        // Taps: white faucet bodies under the hood, nozzle, colored push paddles (cold blue, hot red).
        for (s, tint) in [(Float(-1), "2C64C6"), (1, "C9302C")] {
            let x = s * 0.06, z = D / 2 - recess + 0.035
            m.add(Prim.roundedBox(V3(0.04, 0.05, 0.05), radius: 0.01, bevelSegments: detail ? 2 : 1, material: white),
                  Xform(translation: V3(x, alcove1 - 0.025, z)))
            m.add(Prim.cylinder(radius: 0.008, height: 0.03, bevel: 0.002, segments: detail ? 14 : 8, bevelSegments: 1, material: white),
                  Xform(translation: V3(x, alcove1 - 0.075, z - 0.004)))
            let paddle = simd_quatf(degrees: -12, axis: V3(1, 0, 0))
            m.add(Prim.roundedBox(V3(0.034, 0.05, 0.012), radius: 0.005, bevelSegments: detail ? 2 : 1, material: "plastic.gloss:\(tint)"),
                  Xform(translation: V3(x, alcove1 - 0.035, z + 0.031), rotation: paddle).jittered(&rng, deg: 0.3, offset: 0.0002))
        }
        if detail {
            // Condenser grille on the back: black steel sheet and wire rows.
            m.add(cuboid(V3(W - 0.08, 0.42, 0.004), material: black), Xform(translation: V3(0, 0.36, -D / 2 - 0.012)))
            for i in 0..<10 {
                m.add(Prim.sweep(Shape2D.circle(0.0025, segments: 5), along: [V3(-W / 2 + 0.045, 0, 0), V3(W / 2 - 0.045, 0, 0)], material: black),
                      Xform(translation: V3(0, 0.17 + Float(i) * 0.042, -D / 2 - 0.016)))
            }
            for x: Float in [-0.1, 0.1] {
                m.add(cuboid(V3(0.01, 0.42, 0.014), material: black), Xform(translation: V3(x, 0.36, -D / 2 - 0.006)))
            }
        }

        // Bottle collar on the hood.
        m.add(Prim.lathe([V2(0.03, H - 0.002), V2(0.1, H - 0.002), V2(0.104, H + 0.004), V2(0.1, H + 0.012), V2(0.085, H + 0.016),
                          V2(0.05, H + 0.012), V2(0.04, H - 0.02), V2(0.0, H - 0.02)], segments: detail ? 36 : 18, seamTile: 0.1, material: white))

        // Inverted 5-gallon bottle: neck down into the collar, shoulder, ribbed body, domed base on top.
        let r: Float = 0.135, neckR: Float = 0.027, y0 = H - 0.05, shoulder = H + 0.11, top = H + 0.44
        var prof: [V2] = [V2(0, y0), V2(neckR, y0), V2(neckR, H + 0.03), V2(neckR + 0.004, H + 0.034), V2(neckR + 0.004, H + 0.04)]
        let sh = detail ? 7 : 4
        for k in 1...sh {
            let t = Float(k) / Float(sh), a = t * .pi / 2
            prof.append(V2(neckR + (r - neckR) * sin(a), H + 0.04 + (shoulder - H - 0.04) * (1 - cos(a))))
        }
        // Ribs: four shallow waist grooves.
        let ribs = [0.2, 0.27, 0.34, 0.41].map { H + Float($0) }
        for ry in ribs {
            prof += [V2(r, ry - 0.016), V2(r - 0.006, ry - 0.008), V2(r - 0.006, ry + 0.008), V2(r, ry + 0.016)]
        }
        let dome = detail ? 5 : 3
        for k in 0...dome {
            let t = Float(k) / Float(dome), a = t * .pi / 2
            prof.append(V2(0.025 + (r - 0.025) * cos(a), top + 0.02 * sin(a)))
        }
        prof.append(V2(0, top + 0.012))
        let segs = detail ? 32 : 16
        // Split the bottle at the water line: the full part reads through the water (one transparent layer
        // everywhere, so no sorting fights), the empty part is clear PET, the water surface a flat disc.
        let level = shoulder + (top - shoulder) * max(0.02, min(1, fill)) * 0.95
        var wet: [V2] = [], dry: [V2] = []
        for i in prof.indices {
            let p = prof[i]
            if p.y <= level { wet.append(p) } else {
                if dry.isEmpty, i > 0 {
                    let q = prof[i - 1], t = (level - q.y) / (p.y - q.y)
                    let c = q + (p - q) * t
                    wet.append(c); dry.append(c)
                }
                dry.append(p)
            }
        }
        m.add(Prim.lathe(wet, segments: segs, seamTile: 0.1, material: water))
        if dry.count > 1 { m.add(Prim.lathe(dry, segments: segs, seamTile: 0.1, material: bottle)) }
        if let rim = wet.last {
            m.add(Prim.lathe([V2(0, level), V2(rim.x - 0.001, level)], segments: segs, seamTile: 0.1, material: water).flipped())
        }
        groundAO(&m, height: 0.1, floor: 0.55)
        return m
    }
}
