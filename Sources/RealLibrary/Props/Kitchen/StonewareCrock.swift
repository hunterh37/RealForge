import simd
import Foundation

/// Salt-glazed stoneware crock, 3 US gallons, 34 x 36 x 30 cm: wheel-thrown body with throwing rings and
/// a 12 mm wall, rolled rim, unglazed foot ring, cobalt slip band, two pulled lug handles, and a loose
/// three-board pine lid on a batten.
public struct StonewareCrock: RealAsset {
    public static let id = "stoneware-crock"
    public static let summary = "Salt-glazed stoneware crock, 3 gallon: wheel-thrown body with throwing rings, cobalt band, rolled lip, lug handles, wooden lid."
    public static let tags = ["prop", "kitchen", "ceramic", "container", "antique"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 18, distance: 1.2, studio: true)

    /// Body radius at the belly (m).
    public var radius: Float = 0.15
    /// Body height to the rim top (m).
    public var height: Float = 0.33
    /// Glaze key; `ceramic.celadon` or a tint (`ceramic.stoneware:B9A27A`) changes the look.
    public var glaze: MaterialKey = "ceramic.stoneware"
    /// Band glaze key.
    public var band: MaterialKey = "ceramic.cobalt"
    /// Lid board wood.
    public var lidWood: MaterialKey = "wood.pine-aged"
    /// Cobalt capacity numeral on the front.
    public var showCapacity = true
    /// Lid on (true) or off (shows the interior).
    public var lid = true
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let r = radius, h = height, wall: Float = 0.012
        let ringPhase = rng.float(0...6.28), ringAmp = rng.float(0.0004...0.0007)
        // Outer silhouette r(y): foot, belly at 40 %, slight shoulder taper, rolled rim.
        func outer(_ y: Float) -> Float {
            let t = y / h
            let belly = r * (0.86 + 0.14 * sin(min(1, t / 0.4) * .pi / 2)) - r * 0.06 * smoothstep(0.45, 0.95, t)
            let rings = ringAmp * (sin(y * 2 * .pi / 0.019 + ringPhase) + 0.5 * sin(y * 2 * .pi / 0.031 + ringPhase * 2.3)) * smoothstep(0.03, 0.08, y) * (1 - smoothstep(0.9, 0.97, t))
            return belly + rings
        }
        // Sample the wall every 5 mm; split by material bands (foot, glaze, band, glaze).
        let footTop: Float = 0.014, bandLo = h * 0.6, bandHi = h * 0.67
        func span(_ y0: Float, _ y1: Float) -> [V2] {
            let n = max(2, Int((y1 - y0) / 0.005))
            return (0...n).map { k in let y = y0 + (y1 - y0) * Float(k) / Float(n); return V2(outer(y), y) }
        }
        let seg = 40
        var foot = [V2(0, 0.0), V2(outer(0) - 0.012, 0.0), V2(outer(0) - 0.004, 0.002)]
        foot += span(0.004, footTop)
        m.add(Prim.lathe(foot, segments: seg, seamTile: 0.3, material: "ceramic.bisque"))
        // Hand-brushed cobalt band: an overlay 0.7 mm proud of the glaze with wavering edges.
        var bandRing = Prim.lathe(span(bandLo, bandHi).map { V2($0.x + 0.0007, $0.y) }, segments: seg * 2, seamTile: 0.3, material: band)
        let wob = rng.float(0...6.28)
        bandRing.deform { p in
            let a = atan2(p.z, p.x)
            let edge = p.y < (bandLo + bandHi) / 2 ? Float(-1) : 1
            let wav = 0.0018 * sin(a * 3 + wob) + 0.0012 * sin(a * 7 + wob * 2) + 0.0008 * sin(a * 13 + edge)
            let atEdge = abs(p.y - (edge < 0 ? bandLo : bandHi)) < 0.002 ? Float(1) : 0
            return V3(p.x, p.y + wav * atEdge, p.z)
        }
        m.add(bandRing)
        // Capacity numeral "3" slip-trailed in cobalt on the front, above the band.
        if showCapacity {
            var stroke: [V2] = []
            for k in 0...8 { let a = Float.pi * (0.85 - 1.35 * Float(k) / 8); stroke.append(V2(cos(a) * 0.016, 0.017 + sin(a) * 0.014)) }
            for k in 1...9 { let a = Float.pi * (0.5 - 1.35 * Float(k) / 9); stroke.append(V2(cos(a) * 0.018, -0.014 + sin(a) * 0.016)) }
            let a0: Float = .pi / 2 - 0.35, y0 = h * 0.78
            let flat = catmull(stroke.map { V3($0.x, $0.y, 0) }, per: 2)
            let path = flat.map { q -> V3 in
                let y: Float = y0 + q.y
                let r: Float = outer(y) + 0.0008
                let a: Float = a0 - q.x / r
                return V3(cos(a) * r, y, sin(a) * r)
            }
            let n = Float(path.count)
            let radii: [Float] = path.indices.map { i in 0.0026 * (1 - 0.35 * Float(i) / n) }
            m.add(Prim.tube(path, radii: radii, sides: 6, seamTile: 0.02, material: band))
        }
        // Upper body, rolled rim, inner wall down to the floor (one surface so the lip shades smoothly).
        var upper = span(footTop, h - 0.012)
        let rimR = outer(h - 0.012), lipC = V2(rimR - wall * 0.5 + 0.002, h - 0.008)
        for k in 0...6 { let a = -Float.pi / 2 + Float(k) / 6 * Float.pi * 1.1; upper.append(lipC + V2(cos(a), sin(a) + 0.4) * (wall * 0.62)) }
        let inner = stride(from: h - 0.02, through: 0.03, by: -0.03).map { y in V2(outer(y) - wall, y) }
        upper += inner
        upper += [V2(outer(0.03) - wall - 0.006, 0.024), V2(0, 0.022)]
        // A chip knocked out of the rim: dent the lip and show the bisque body inside it.
        var upperS = Prim.lathe(upper, segments: seg, seamTile: 0.3, material: glaze)
        let chipA = rng.float(0...6.28), chipC = V3(cos(chipA) * outer(h - 0.012), h - 0.004, -sin(chipA) * outer(h - 0.012))
        upperS.deform { p in
            let d = simd_distance(p, chipC)
            guard d < 0.016 else { return p }
            let k = (1 - d / 0.016) * (1 - d / 0.016)
            return p - V3(0, 0.006 * k, 0) - V3(cos(chipA), 0, -sin(chipA)) * 0.002 * k
        }
        m.add(upperS)
        m.add(Prim.superellipsoid(V3(0.02, 0.006, 0.014), exponent: 2.5, subdivisions: 3, material: "ceramic.bisque"),
              Xform(translation: chipC - V3(0, 0.0045, 0), rotation: simd_quatf(angle: chipA, axis: .up)))
        // Lug handles: horizontal clay ears on +-X below the rim, arched outward, open underneath.
        for s: Float in [-1, 1] {
            let y0 = h * 0.82
            let base = outer(y0) - 0.004
            let path = catmull([V3(s * base, y0, -0.042), V3(s * (base + 0.014), y0 + 0.002, -0.03), V3(s * (base + 0.022), y0 + 0.003, 0),
                                V3(s * (base + 0.014), y0 + 0.002, 0.03), V3(s * base, y0, 0.042)], per: 4)
            m.add(Prim.sweep(Shape2D.superellipse(0.02, 0.013, exponent: 2.6, segments: 12), along: path, up: .up, material: glaze))
        }
        if lid {
            // Three pine boards on a cross batten, sitting on the rim, slightly askew.
            let lr = outer(h - 0.012) + 0.012, t: Float = 0.017
            let yaw = rng.float(-25...25), slide = V3(rng.float(-0.008...0.008), 0, rng.float(-0.008...0.008))
            let widths: [Float] = [0.62, 0.76, 0.62].map { $0 * lr * 2 / 2 }
            var x0 = -lr
            var lidModel = Model(name: "lid")
            for (i, w) in widths.enumerated() {
                // Boards run along X (grain on U): each is a strip of the disc between z0 and z1.
                let x1 = min(lr, x0 + w) - (i < 2 ? 0.0015 : 0)
                var outline: [V2] = []
                let a0 = asin(max(-1, min(1, x0 / lr))), a1 = asin(max(-1, min(1, x1 / lr)))
                let steps = 10
                for k in 0...steps { let a = a0 + (a1 - a0) * Float(k) / Float(steps); outline.append(V2(cos(a) * lr, sin(a) * lr)) }
                for k in 0...steps { let a = a1 + (a0 - a1) * Float(k) / Float(steps); outline.append(V2(-cos(a) * lr, sin(a) * lr)) }
                let board = Prim.extrude(Shape2D.rounded(outline, radius: 0.004, segments: 1), depth: t, bevel: 0.003, bevelSegments: 2, material: lidWood)
                lidModel.add(board, Xform(translation: V3(0, h + t / 2 + 0.001, 0), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))).jittered(&rng, deg: 0.4, offset: 0.0008))
                x0 = x1 + 0.0015
            }
            lidModel.add(plank(lr * 1.5, 0.045, 0.022, bevel: 0.004, material: lidWood),
                         Xform(translation: V3(0, h + t + 0.012, 0), rotation: simd_quatf(degrees: 90, axis: .up)))
            for z: Float in [-lr * 0.45, lr * 0.45] {
                rivet(&lidModel, at: V3(0, h + t + 0.023, z), normal: .up, radius: 0.004, material: "metal.iron")
            }
            m.add(lidModel, Xform(translation: slide, rotation: simd_quatf(degrees: yaw, axis: .up)))
        }
        groundAO(&m, height: 0.09, floor: 0.45)
        return LODModel(m)
    }
}
