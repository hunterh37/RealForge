import simd
import Foundation

/// Clay barrel-tile roof section, 2.4 m along the eave, one gable slope at 40 degrees: alternating
/// concave pan and convex cover tiles in overlapping courses (slightly irregular, a few weathered
/// darker), mortared ridge tiles, battens on a sarked deck, exposed rafter tails, fascia and a
/// bargeboard on the gable end. The eave faces +Z, the ridge runs along X at the back; base y = 0 is
/// the bottom of the rafter tails.
public struct GableRoofPanel: RealAsset {
    public static let id = "gable-roof-panel"
    public static let summary = "Clay tile roof section, 2.4 m: one gable slope at 40 degrees with overlapping pan tiles, ridge cap, fascia, rafter tails and bargeboard."
    public static let tags = ["structure", "architecture", "roof", "ceramic", "wood"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 24, distance: 1.0, studio: true)

    /// Length along the eave (m).
    public var width: Float = 2.4
    /// Slope length (m).
    public var slopeLength: Float = 2.2
    /// Roof pitch (degrees).
    public var pitch: Float = 40
    /// Tile column pitch across the slope (m).
    public var tilePitch: Float = 0.21
    /// Exposed course length (m).
    public var courseLength: Float = 0.33
    public var tileMaterial: MaterialKey = "ceramic.terracotta"
    public var weatheredTile: MaterialKey = "ceramic.terracotta:8E4E34"
    public var woodMaterial: MaterialKey = "wood.painted-exterior:5A3A28"
    public var battenMaterial: MaterialKey = "wood.lumber-pine"
    public init() {}

    /// Curved tile sheet: arc across X (radius r, half-angle a), length along +Z, tapered.
    func tile(r: Float, halfAngle a: Float, length: Float, taper: Float, convex: Bool, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let nu = 7, nv = 3
        for j in 0...nv { for i in 0...nu {
            let v = Float(j) / Float(nv)
            let rr = r * (1 - taper * v)
            let t = -a + 2 * a * Float(i) / Float(nu)
            let y = convex ? rr * cos(t) - rr * cos(a) : rr * (1 - cos(t))
            _ = s.add(V3(rr * sin(t), y, length * v), .up, V2(rr * t, length * v))
        }}
        let row = UInt32(nu + 1)
        for j in 0..<nv { for i in 0..<nu {
            let k = UInt32(j) * row + UInt32(i)
            s.quad(k, k + row, k + row + 1, k + 1)
        }}
        s.recomputeNormals(weldSeams: false)
        s.computeTangents()
        return s
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id), lite = Model(name: Self.id + "-lite")
        let W = width, L = slopeLength
        let p = pitch * .pi / 180
        let rot = simd_quatf(degrees: pitch, axis: V3(1, 0, 0)) * simd_quatf(degrees: 180, axis: .up)
        let origin = V3(0, 0.22, 0)
        func place(_ s: Surface, _ x: Xform = .identity, lite l: Bool = true) {
            let X = Xform(translation: origin + rot.act(x.translation), rotation: rot * x.rotation)
            m.add(s, X); if l { lite.add(s, X) }
        }
        // Deck and battens (local frame: x across, z up the slope, y normal), trimmed to the tiles.
        let cols = Int(W / tilePitch)
        let DW = Float(cols) * tilePitch + 0.02
        place(HK.box(V3(DW, 0.02, L), V3(0, -0.03, L / 2), "wood.plywood", r: 0.002, seg: 1))
        let courses = Int(L / courseLength)
        for c in 0...courses { place(HK.box(V3(DW, 0.025, 0.05), V3(0, -0.008, Float(c) * courseLength + 0.03), battenMaterial, r: 0.003), lite: false) }
        // Tiles: pans (concave) then covers (convex) straddling the pan joints.
        let x0 = -Float(cols - 1) * tilePitch / 2
        let pan = tile(r: 0.11, halfAngle: 0.85, length: courseLength + 0.08, taper: 0.12, convex: false, material: tileMaterial)
        let panW = tile(r: 0.11, halfAngle: 0.85, length: courseLength + 0.08, taper: 0.12, convex: false, material: weatheredTile)
        let cover = tile(r: 0.075, halfAngle: 1.15, length: courseLength + 0.08, taper: 0.15, convex: true, material: tileMaterial)
        let coverW = tile(r: 0.075, halfAngle: 1.15, length: courseLength + 0.08, taper: 0.15, convex: true, material: weatheredTile)
        for c in 0..<courses {
            let z = Float(c) * courseLength
            for i in 0..<cols {
                let x = x0 + Float(i) * tilePitch
                let old = rng.chance(0.12)
                let tilt = simd_quatf(degrees: -3 + rng.float(-0.6...0.6), axis: V3(1, 0, 0)) * simd_quatf(degrees: rng.float(-1...1), axis: .up)
                place(old ? panW : pan, Xform(translation: V3(x + rng.float(-0.004...0.004), 0.0, z), rotation: tilt), lite: c % 2 == 0)
                for cx in (i == 0 ? [x - tilePitch / 2, x + tilePitch / 2] : [x + tilePitch / 2]) {
                    let tilt2 = simd_quatf(degrees: -3 + rng.float(-0.6...0.6), axis: V3(1, 0, 0))
                    place(rng.chance(0.1) ? coverW : cover, Xform(translation: V3(cx, 0.065 + 0.012, z + 0.01), rotation: tilt2), lite: c % 2 == 0)
                }
            }
        }
        // Ridge: large convex tiles along X bedded on mortar.
        let ridgeTile = tile(r: 0.12, halfAngle: 1.2, length: 0.42, taper: 0.1, convex: true, material: tileMaterial)
        let ridgeZ = Float(courses) * courseLength + 0.05
        place(HK.box(V3(W, 0.06, 0.16), V3(0, 0.03, ridgeZ), "concrete.smooth", r: 0.02))
        var x = -W / 2
        while x < W / 2 - 0.05 {
            place(ridgeTile, Xform(translation: V3(x + 0.02, 0.06, ridgeZ), rotation: simd_quatf(degrees: 90, axis: .up)))
            x += 0.38
        }
        // Rafter tails, fascia, bargeboard (world space; eave at z ~ 0).
        let run = L * cos(p)
        _ = run
        let nr = Int(W / 0.6) + 1
        for i in 0..<nr {
            let rx = -W / 2 + 0.1 + (W - 0.2) * Float(i) / Float(nr - 1)
            let (s, xf) = board(from: V3(rx, 0.1, 0.05), to: V3(rx, 0.1 + 0.6 * sin(p), 0.05 - 0.6 * cos(p)),
                                width: 0.14, thick: 0.05, up: V3(1, 0, 0), bevel: 0.006, material: woodMaterial)
            m.add(s, xf); lite.add(s, xf)
        }
        let fascia = HK.box(V3(W + 0.04, 0.16, 0.03), V3(0, 0.15, 0.075), woodMaterial, r: 0.005)
        m.add(fascia); lite.add(fascia)
        // Bargeboard along the gable (left) end, following the slope.
        let bb0 = V3(-W / 2 - 0.03, 0.15, 0.09), bb1 = origin + rot.act(V3(-W / 2 - 0.03 - 0.0, 0.0, L)) + V3(-W / 2 - 0.03 + W / 2 + 0.03, 0, 0)
        let (bs, bx) = board(from: bb0, to: V3(-W / 2 - 0.03, bb1.y, bb1.z), width: 0.2, thick: 0.035, up: V3(1, 0, 0), bevel: 0.006, material: woodMaterial)
        m.add(bs, bx); lite.add(bs, bx)

        groundAO(&m, height: 0.15, floor: 0.75)
        let b = m.bounds
        let c = Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2))
        return LODModel(levels: [m.transformed(c), lite.transformed(c)], switchDistances: [12])
    }
}
