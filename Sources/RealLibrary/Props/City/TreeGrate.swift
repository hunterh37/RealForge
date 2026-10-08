import simd
import Foundation

/// Street tree pit: a two-piece cast-iron tree grate (concentric ring slots, radial ribs, a round
/// trunk opening) set flush inside a granite edging, over bark mulch, with a young Norway maple
/// growing through it: a staked-straight 6 cm trunk, scaffold branches from 2 m and a crown of
/// leaf-cluster cards on the `leaf.maple-norway` atlas.
public struct TreeGrate: RealAsset {
    public static let id = "tree-grate"
    public static let summary = "Cast-iron tree grate, 1 m square, over a mulched tree pit with a young street tree, trunk opening and granite edging."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "metal", "plant"]
    public static let budget = 15000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 12, distance: 1.1)

    /// Grate edge (m).
    public var grate: Float = 1.0
    /// Granite edging width (m).
    public var edging: Float = 0.12
    /// Trunk opening radius (m).
    public var opening: Float = 0.16
    /// Black steel tree guard around the trunk.
    public var guardRail = true
    /// Include the tree.
    public var tree = true
    /// Tree height (m).
    public var treeHeight: Float = 4.4
    /// Materials.
    public var iron: MaterialKey = "metal.cast-iron-street"
    public var granite: MaterialKey = "stone.granite-curb"
    public var mulch: MaterialKey = "mulch.bark"
    /// Trunk radius at the base (m).
    public var trunkRadius: Float = 0.045
    /// Leaf-cluster cards in the crown.
    public var leafCards = 1900
    /// Bark and leaf materials.
    public var bark: MaterialKey = "bark.maple"
    public var leaf: MaterialKey = "leaf.maple-norway"
    public init() {}

    private func addSapling(_ m: inout Model, rng: inout SeededRNG) {
        let H = treeHeight, clear: Float = 2.1
        // Trunk and leader, a slight seeded lean.
        let lean = V3(rng.float(-0.05...0.05), 0, rng.float(-0.05...0.05))
        let trunk = (0...8).map { i -> V3 in let t = Float(i) / 8; return V3(0, 0.02 + t * (H - 0.5), 0) + lean * t * t * H * 0.3 }
        m.add(Prim.tube(trunk, radii: trunk.indices.map { trunkRadius * (1 - 0.8 * Float($0) / 8) }, sides: 10, seamTile: 0.2, material: bark,
                        weights: trunk.indices.map { Float($0) / 16 }))
        // Scaffold branches spiralling up the leader, each with two side twigs.
        var tips: [(V3, V3)] = []
        let n = 9
        for i in 0..<n {
            let t = Float(i) / Float(n - 1)
            let y = clear + t * (H - clear - 0.9)
            let base = V3(0, y, 0) + lean * pow((y - 0.02) / (H - 0.5), 2) * H * 0.3
            let yaw = Float(i) * 2.4 + rng.float(-0.3...0.3)
            let up = rng.float(0.55...0.95) + t * 0.3
            let dir = simd_normalize(V3(cos(yaw), up, sin(yaw)))
            let len = (1.5 - t * 0.7) * rng.float(0.85...1.1)
            let pts = (0...4).map { k -> V3 in let s = Float(k) / 4; return base + dir * len * s + V3(0, -0.12 * s * s * len, 0) }
            let r0 = trunkRadius * (0.55 - 0.25 * t)
            m.add(Prim.tube(pts, radii: pts.indices.map { r0 * (1 - 0.8 * Float($0) / 4) }, sides: 6, seamTile: 0.15, material: bark,
                            weights: pts.indices.map { 0.3 + 0.7 * Float($0) / 4 }))
            tips.append((pts[4], dir)); tips.append((pts[2], dir))
            for sgn: Float in [-1, 1] {
                let sd = simd_normalize(dir + V3(-dir.z, 0.3, dir.x) * sgn * 0.8)
                let p0 = pts[2], p1 = p0 + sd * len * 0.45
                m.add(Prim.tube([p0, (p0 + p1) / 2 + V3(0, 0.03, 0), p1], radii: [r0 * 0.45, r0 * 0.3, r0 * 0.15], sides: 4, seamTile: 0.1, material: bark,
                                weights: [0.5, 0.8, 1]))
                tips.append((p1, sd))
            }
        }
        tips.append((trunk.last!, V3(0, 1, 0)))
        // Leaf-cluster cards around branch tips and along the outer crown shell.
        var leaves = Surface(material: leaf), dark = Surface(material: "\(leaf):24401A")
        for _ in 0..<leafCards {
            let (tip, dir) = tips[rng.int(0...(tips.count - 1))]
            let back = rng.float(0...0.7)
            let p = tip - dir * back + rng.inDisc(radius: 0.45).x * V3(1, 0, 0) + V3(0, rng.float(-0.3...0.35), 0) + rng.inDisc(radius: 0.45).y * V3(0, 0, 1)
            let sz = rng.float(0.2...0.3)
            var c = Prim.card(width: sz, height: sz, cell: (V2(0, 0), V2(1, 1)), material: leaf, extra: V2(1, 0))
            let out = atan2(p.x, p.z) + rng.float(-0.7...0.7)
            let q = simd_quatf(angle: out, axis: .up) * simd_quatf(angle: rng.float(-0.9...0.3), axis: V3(1, 0, 0))
            c = c.transformed(Xform(translation: p, rotation: q))
            if simd_length(V2(p.x, p.z)) < 0.7 || rng.chance(0.3) { dark.append(c) } else { leaves.append(c) }
        }
        leaves.computeTangents(); dark.computeTangents()
        m.add(leaves); m.add(dark)
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let g = grate / 2, top: Float = 0.06
        // Granite edging: four stones, mitred by overlap at the corners.
        for k in 0..<4 {
            let a = Float(k) * .pi / 2
            let len = k % 2 == 0 ? grate + 2 * edging : grate
            m.add(Prim.roundedBox(V3(len - 0.006, top, edging - 0.006), radius: 0.008, bevelSegments: 2, material: granite),
                  Xform(translation: V3(sin(a), 0, cos(a)) * (g + edging / 2) + V3(0, top / 2 - rng.float(0...0.003), 0), rotation: simd_quatf(angle: a, axis: .up)))
        }
        // Mulch bed below the grate.
        m.add(Prim.roundedBox(V3(grate - 0.01, 0.02, grate - 0.01), radius: 0.005, bevelSegments: 1, material: mulch), Xform(translation: V3(0, 0.01, 0)))
        // Grate: outer frame, rings, radial ribs, center split line.
        let gy = top - 0.012
        for k in 0..<4 {
            let a = Float(k) * .pi / 2
            m.add(Prim.roundedBox(V3(grate - 0.004, 0.024, 0.04), radius: 0.004, bevelSegments: 1, material: iron),
                  Xform(translation: V3(sin(a), 0, cos(a)) * (g - 0.02) + V3(0, gy, 0), rotation: simd_quatf(angle: a, axis: .up)))
        }
        var r = opening + 0.015
        while r < g - 0.02 {
            m.add(Prim.torus(major: r, minor: 0.008, segments: 48, sides: 4, minorY: 0.012, material: iron), Xform(translation: V3(0, gy, 0)))
            r += 0.055
        }
        // Corner fill rings clipped to the square: short arcs only where they fit inside the frame.
        for ring in 0..<3 {
            let rr = r + Float(ring) * 0.055
            for q in 0..<4 {
                let ac = Float(q) * .pi / 2 + .pi / 4, span = acos(min(1, (g - 0.04) / rr)) 
                let arcHalf = Float.pi / 4 - span
                guard arcHalf > 0.02 else { continue }
                m.add(Prim.torus(major: rr, minor: 0.008, segments: 10, sides: 4, arc: 2 * arcHalf, minorY: 0.012, material: iron),
                      Xform(translation: V3(0, gy, 0), rotation: simd_quatf(angle: ac - arcHalf, axis: .up)))
            }
        }
        for k in 0..<8 {
            let a = Float(k) * .pi / 4
            let len = (k % 2 == 0 ? g : g * 1.414) - opening - 0.04
            let mid = opening + len / 2
            m.add(Prim.roundedBox(V3(0.022, 0.024, len), radius: 0.004, bevelSegments: 1, material: iron),
                  Xform(translation: V3(sin(a) * mid, gy, cos(a) * mid), rotation: simd_quatf(angle: a, axis: .up)))
        }
        m.add(Prim.torus(major: opening, minor: 0.014, segments: 40, sides: 6, minorY: 0.012, material: iron), Xform(translation: V3(0, gy, 0)))
        if tree { addSapling(&m, rng: &rng) }
        if guardRail {
            // Tree guard: 10 flat-bar pickets on a 40 cm circle, two hoops, one picket bent by a bumper.
            let gr: Float = 0.4, gh: Float = 1.05, steel: MaterialKey = "metal.painted:1C1E1F"
            for k in 0..<10 {
                let a = Float(k) / 10 * 2 * .pi
                let bend: Float = k == 3 ? 0.06 : 0
                let p0 = V3(cos(a) * gr, top, sin(a) * gr), p1 = V3(cos(a) * (gr - bend), gh, sin(a) * (gr - bend))
                m.add(Prim.tube([p0, (p0 + p1) / 2, p1], radii: [0.008, 0.008, 0.008], sides: 5, seamTile: 0.1, material: steel))
            }
            for y in [Float(0.45), gh - 0.01] {
                m.add(Prim.torus(major: gr, minor: 0.009, segments: 40, sides: 5, minorY: 0.016, material: steel), Xform(translation: V3(0, y, 0)))
            }
        }
        // Fallen leaves and litter caught on the grate: cigarette butts, a bottle cap.
        for _ in 0..<14 {
            let p = V2(rng.float(-g...g), rng.float(-g...g)) * 0.92
            guard simd_length(p) > opening + 0.03 else { continue }
            m.add(Prim.superellipsoid(V3(rng.float(0.04...0.07), 0.002, rng.float(0.035...0.06)), exponent: 2, subdivisions: 2, material: rng.chance(0.6) ? "leaf.oak" : "mulch.bark"),
                  Xform(translation: V3(p.x, top + 0.002, p.y), rotation: simd_quatf(angle: rng.float(0...6.28), axis: .up)))
        }
        for _ in 0..<4 {
            let p = V2(rng.float(-g...g), rng.float(-g...g)) * 0.85
            m.add(Prim.cylinder(radius: 0.004, height: 0.025, bevel: 0.001, segments: 6, material: rng.chance(0.5) ? "paper.sheet" : "fabric.burlap"),
                  Xform(translation: V3(p.x, top + 0.004, p.y), rotation: simd_quatf(angle: rng.float(0...6.28), axis: .up) * simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }
        m.add(Prim.cylinder(radius: 0.014, height: 0.005, bevel: 0.001, segments: 12, material: "metal.painted:B02020"), Xform(translation: V3(g * 0.55, top + 0.001, -g * 0.4)))
        groundAO(&m, height: 0.08, floor: 0.7)
        return LODModel(m)
    }
}
