import simd
import Foundation

/// Heap of fresh pine sawdust under a saw, about 0.4 m across and 7 cm high: a lobed, slumped mound of
/// `wood.sawdust` with a thin scatter skirt that feathers into the floor (rim sunk 2 mm so it never
/// floats), curled planer and chisel shavings (thin pine ribbons rolled 1 to 2 turns) and small offcut
/// chips and slivers. Set `height` to 0.004-0.01 for a thin floor scatter; the curls and chips then lie
/// flat on the floor. Base at y = 0, centered.
public struct SawdustPile: RealAsset {
    public static let id = "sawdust-pile"
    public static let summary = "Heap of sawdust under a saw with curled pine shavings and small offcut chips; flattens to a thin floor scatter with the height knob."
    public static let tags = ["prop", "workshop", "wood"]
    public static let budget = 11_500
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 28, distance: 0.75, studio: true)

    /// Overall diameter (m).
    public var size: Float = 0.4
    /// Peak height of the mound (m). 0.004-0.01 reads as a thin floor scatter.
    public var height: Float = 0.065
    /// Number of curled shavings and offcut chips.
    public var shavings: Int = 12
    public var chips: Int = 9
    /// Dust and shaving materials.
    public var dust: MaterialKey = "wood.sawdust"
    public var shavingWood: MaterialKey = "wood.lumber-pine"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = size / 2
        let phase = rng.float(0...6.28), phase2 = rng.float(0...6.28)
        let peak = V2(rng.float(-0.03...0.03), rng.float(-0.03...0.03)) * size
        let p1 = rng.float(0...6.28), p2 = rng.float(0...6.28)
        func edge(_ th: Float) -> Float {
            R * (1 + 0.1 * sin(3 * th + phase) + 0.06 * sin(5 * th + phase2) + 0.035 * sin(11 * th + p1) + 0.025 * sin(19 * th + p2) + 0.02 * sin(31 * th + phase) + 0.012 * sin(37 * th + p1))
        }
        func lumps(_ x: Float, _ z: Float) -> Float {
            sin(x * 23 + p1) * cos(z * 19 + p2) + 0.5 * sin((x * 0.7 + z) * 41 + phase) * cos((x - z * 0.6) * 37)
        }
        func grain(_ x: Float, _ z: Float) -> Float { sin(x * 170 + z * 40) * cos(z * 150 - x * 30) }
        func clumps(_ x: Float, _ z: Float) -> Float { sin(x * 97 + p2) * cos(z * 113 + p1) * 0.6 + sin((x + z * 0.4) * 131 + phase) * 0.4 }
        /// Surface height at (x, z): soft dome (fluffy, rounded top) on a feathered scatter skirt; the rim
        /// sinks 2.5 mm below the floor so the outline never shows an edge.
        func h(_ x: Float, _ z: Float) -> Float {
            let rp = simd_length(V2(x, z)) / R
            let d = V2(x, z) - peak * max(0, 1 - rp)
            let th = atan2(d.y, d.x)
            let dl = simd_length(d)
            let rho = min(1.2, dl / edge(th))
            // The dome only follows the broad lobes, and only away from the top (no radial creases).
            let broad = R * (1 + (0.1 * sin(3 * th + phase) + 0.06 * sin(5 * th + phase2)) * smoothstep(0, R * 0.6, dl))
            let q = dl / broad / 0.74
            let dome = height * 0.9 * pow(max(0, 1 - q * q), 1.35)
            let skirt = 0.003 * smoothstep(1.0, 0.45, rho)
            let lump = (0.035 * height) * lumps(x, z) * smoothstep(0.95, 0.3, rho) + 0.0006 * grain(x, z) * smoothstep(1.0, 0.6, rho) + 0.0022 * clumps(x, z) * smoothstep(0.95, 0.2, rho)
            return max(dome, skirt) + lump - 0.0025 * smoothstep(0.82, 1.0, rho)
        }
        // Polar mesh out to the lobed rim.
        var s = Surface(material: dust)
        let nr = 22, ns = 76
        let c0 = s.add(V3(peak.x, h(peak.x, peak.y), peak.y), .up, peak)
        for i in 1...nr {
            let t = Float(i) / Float(nr), tt = pow(t, 0.85)
            for k in 0..<ns {
                let th = Float(k) / Float(ns) * 2 * .pi
                let r = edge(th) * tt
                let x = peak.x * (1 - tt) + cos(th) * r, z = peak.y * (1 - tt) + sin(th) * r
                _ = s.add(V3(x, h(x, z), z), .up, V2(x, z))
            }
        }
        for k in 0..<UInt32(ns) { s.tri(c0, 1 + (k + 1) % UInt32(ns), 1 + k) }
        for i in 1..<UInt32(nr) { for k in 0..<UInt32(ns) {
            let a = 1 + (i - 1) * UInt32(ns) + k, b = 1 + (i - 1) * UInt32(ns) + (k + 1) % UInt32(ns)
            s.quad(a, b, b + UInt32(ns), a + UInt32(ns))
        }}
        s.recomputeNormals(weldSeams: true)
        s.computeTangents()
        m.add(s)

        // Curled shavings: thin pine ribbons rolled into tightening spirals, resting on the surface.
        func rest(_ x: Float, _ z: Float) -> Float { max(0, h(x, z)) }
        for k in 0..<shavings {
            var r = rng.fork(100 + k)
            let ang = r.float(0...6.28), dist = sqrt(r.float(0.02...0.9)) * R * 0.95
            let x = cos(ang) * dist, z = sin(ang) * dist
            let rad = r.float(0.009...0.016), width = r.float(0.012...0.024), turns = r.float(1.2...2.4)
            let n = 26
            var path: [V3] = []
            for q in 0...n {
                let t = Float(q) / Float(n), a = t * turns * 2 * .pi
                let rr = rad * (1 - 0.45 * t)
                path.append(V3(cos(a) * rr, sin(a) * rr, t * width * 0.6))
            }
            // Ribbon cross-section: width along the spiral axis (z), 0.5 mm thick.
            let ribbon = Shape2D.rect(width, 0.0006)
            let curl = Prim.sweep(ribbon, along: path, up: V3(0, 0, 1), caps: true, grainAlongPath: true, material: shavingWood)
            let lie = simd_quatf(angle: r.float(0...6.28), axis: .up) * simd_quatf(degrees: r.float(-25...25), axis: V3(1, 0, 0))
            let y = rest(x, z) + rad * 0.55
            m.add(curl, Xform(translation: V3(x, y, z), rotation: lie))
        }
        // Coarse flecks: tiny chips and splinters strewn over the mound and past the rim (breaks up the even dust).
        var fr = rng.fork(500)
        for _ in 0..<150 {
            let ang = fr.float(0...6.28), dist = sqrt(fr.float(0...1)) * edge(ang) * 1.08
            let x = cos(ang) * dist, z = sin(ang) * dist
            let sz = V3(fr.float(0.002...0.007), fr.float(0.0007...0.0016), fr.float(0.0015...0.004))
            let mat: MaterialKey = fr.chance(0.3) ? "wood.endgrain-fresh" : shavingWood
            m.add(cuboid(sz, material: mat), Xform(translation: V3(x, rest(x, z) + sz.y * 0.1, z),
                                                   rotation: simd_quatf(angle: fr.float(0...6.28), axis: .up) * simd_quatf(degrees: fr.float(-20...20), axis: V3(1, 0, 0))))
        }
        // Rim scatter: denser flecks where the dust thins out, so the outline breaks up.
        for _ in 0..<110 {
            let ang = fr.float(0...6.28), dist = edge(ang) * fr.float(0.92...1.16)
            let x = cos(ang) * dist, z = sin(ang) * dist
            let sz = V3(fr.float(0.0015...0.005), fr.float(0.0006...0.0012), fr.float(0.0012...0.003))
            m.add(cuboid(sz, material: fr.chance(0.5) ? dust : shavingWood), Xform(translation: V3(x, rest(x, z) + sz.y * 0.1, z), rotation: simd_quatf(angle: fr.float(0...6.28), axis: .up)))
        }
        // Offcut chips and slivers: a few end-grain cubes and flat splinters.
        var placed: [V2] = []
        for k in 0..<chips {
            var r = rng.fork(300 + k)
            var x: Float = 0, z: Float = 0
            for _ in 0..<12 {
                let ang = r.float(0...6.28), dist = sqrt(r.float(0.1...1.0)) * R * 1.05
                x = cos(ang) * dist; z = sin(ang) * dist
                if placed.allSatisfy({ simd_distance($0, V2(x, z)) > 0.06 }) { break }
            }
            placed.append(V2(x, z))
            let sliver = k % 3 != 0
            let sz = sliver ? V3(r.float(0.03...0.07), r.float(0.002...0.004), r.float(0.006...0.012)) : V3(r.float(0.012...0.025), r.float(0.008...0.016), r.float(0.012...0.02))
            let chip = Prim.roundedBox(sz, radius: min(sz.y, sz.z) * 0.18, bevelSegments: 1, material: sliver ? shavingWood : "wood.endgrain-fresh")
            let tilt = simd_quatf(angle: r.float(0...6.28), axis: .up) * simd_quatf(degrees: r.float(-12...12), axis: V3(0, 0, 1))
            m.add(chip, Xform(translation: V3(x, rest(x, z) + sz.y * 0.35, z), rotation: tilt))
        }
        groundAO(&m, height: max(0.02, height), floor: 0.7)
        for i in m.surfaces.indices where m.surfaces[i].material == dust {
            m.surfaces[i].occlusion = m.surfaces[i].positions.map { 0.8 + 0.2 * smoothstep(0, height, $0.y) }
        }
        // Shavings are thin and translucent: keep only a light contact term, no cavity darkening inside the curls.
        for i in m.surfaces.indices where m.surfaces[i].material == shavingWood {
            m.surfaces[i].occlusion = m.surfaces[i].positions.map { 0.82 + 0.18 * smoothstep(0, 0.02, $0.y) }
        }
        return LODModel(m)
    }
}
