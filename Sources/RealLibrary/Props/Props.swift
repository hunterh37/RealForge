import simd
import Foundation

public enum Props {
    public static let all: [any RealAsset.Type] = [
        WoodenCrate.self, Barrel.self, OilDrum.self, ParkBench.self, PicnicTable.self, StreetLamp.self,
        TrafficCone.self, FireHydrant.self, Bollard.self, Pallet.self, Mailbox.self, TrashCan.self,
    ]
}

// MARK: - building blocks

/// Board along +X centered at origin with beveled edges; grain runs along its length (U).
func plank(_ length: Float, _ width: Float, _ thick: Float, bevel: Float = 0.004, material: MaterialKey) -> Surface {
    Prim.roundedBox(V3(length, thick, width), radius: bevel, bevelSegments: 2, material: material)
}

/// Board placed between two points (its long axis), with `up` hint for its face normal.
func board(from a: V3, to b: V3, width: Float, thick: Float, up: V3 = .up, bevel: Float = 0.004, material: MaterialKey, extend: Float = 0) -> (Surface, Xform) {
    let d = b - a, len = simd_length(d) + extend * 2
    let x = d / simd_length(d)
    var y = up - x * simd_dot(up, x)
    y = simd_length(y) < 1e-4 ? x.anyPerpendicular : simd_normalize(y)
    let z = simd_cross(x, y)
    return (plank(len, width, thick, bevel: bevel, material: material), Xform(translation: (a + b) / 2, rotation: simd_quatf(simd_float3x3(x, y, z))))
}

/// Vertical lathe from (radius, y) pairs.
func turned(_ profile: [(Float, Float)], segments: Int = 40, material: MaterialKey, seamTile: Float = 0.25, grainVertical: Bool = false) -> Surface {
    Prim.lathe(profile.map { V2($0.0, $0.1) }, segments: segments, seamTile: seamTile, material: material, swapUV: grainVertical)
}

/// Contact-shadow AO toward the ground for a whole model.
func groundAO(_ m: inout Model, height: Float = 0.25, floor: Float = 0.5) {
    for i in m.surfaces.indices {
        m.surfaces[i].occlusion = m.surfaces[i].positions.map { floor + (1 - floor) * smoothstep(0, height, $0.y) }
        m.surfaces[i].bakeCavityAO(strength: 0.6, floor: 0.6)
    }
}

// MARK: - props

public struct WoodenCrate: RealAsset {
    public static let id = "wooden-crate"
    public static let summary = "Slatted pine crate with corner posts, gapped boards, beveled edges."
    public static let tags = ["prop", "wood", "container"]
    public static let budget = 8_000
    public var size: V3 = V3(0.6, 0.45, 0.4)
    public var material: MaterialKey = "wood.pine"
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let h = size / 2, t: Float = 0.016, post: Float = 0.04
        let slats = 3, gap: Float = 0.012
        let slatH = (size.y - gap * Float(slats - 1)) / Float(slats)
        for i in 0..<slats {
            let y = slatH / 2 + Float(i) * (slatH + gap)
            for z in [-h.z + t / 2, h.z - t / 2] {   // long sides
                m.add(plank(size.x - 0.004, slatH, t, material: material), Xform(translation: V3(0, y, z), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))).jittered(&rng))
            }
            for x in [-h.x + t / 2, h.x - t / 2] {   // short sides
                m.add(plank(size.z - 2 * t, slatH, t, material: material), Xform(translation: V3(x, y, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 1, 0)) * simd_quatf(degrees: 90, axis: V3(1, 0, 0))).jittered(&rng))
            }
        }
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {   // corner posts inside
            m.add(plank(size.y, post, post, material: material),
                  Xform(translation: V3(sx * (h.x - t - post / 2), h.y, sz * (h.z - t - post / 2)), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        }}
        // Bottom boards.
        for k in 0..<4 {
            let z = -h.z + t + (Float(k) + 0.5) * (size.z - 2 * t) / 4
            m.add(plank(size.x - 2 * t, (size.z - 2 * t) / 4 - 0.006, t, material: material), Xform(translation: V3(0, t / 2, z)))
        }
        groundAO(&m, height: 0.1, floor: 0.6)
        return LODModel(m)
    }
}

extension Xform {
    /// Tiny per-board rotation/offset so assembled props don't look CAD-perfect.
    func jittered(_ rng: inout SeededRNG, deg: Float = 0.6, offset: Float = 0.0015) -> Xform {
        var x = self
        x.rotation = simd_quatf(degrees: rng.float(-deg...deg), axis: rng.unitVector()) * x.rotation
        x.translation += rng.unitVector() * offset
        return x
    }
}

public struct Barrel: RealAsset {
    public static let id = "barrel"
    public static let summary = "Oak barrel: bulged lathe body with stave grooves, two rusted iron hoop pairs, inset lid."
    public static let tags = ["prop", "wood", "container"]
    public static let budget = 10_000
    public var height: Float = 0.9
    public var radius: Float = 0.29
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let h = height, r = radius, staves = 18
        // Body: bulge profile, with staves as separate lathe slices (gap via slight per-stave inset).
        var prof: [(Float, Float)] = []
        for i in 0...16 {
            let t = Float(i) / 16, bulge = sin(t * .pi) * 0.12
            prof.append((r * (0.88 + bulge), t * h))
        }
        var body = turned(prof, segments: staves * 4, material: "wood.oak", seamTile: 0.5, grainVertical: true)
        // Stave grooves: pull every 4th ring vertex column inward a little.
        for i in body.positions.indices {
            let p = body.positions[i]
            let a = atan2(-p.z, p.x), k = (a / (2 * .pi) * Float(staves)).truncatingRemainder(dividingBy: 1)
            let groove = 1 - 0.012 * smoothstep(0.08, 0, min(abs(k), abs(1 - abs(k))))
            body.positions[i] = V3(p.x * groove, p.y, p.z * groove)
        }
        body.recomputeNormals(); body.computeTangents()
        m.add(body)
        // Hoops.
        for y in [0.08, 0.25, 0.75, 0.92] as [Float] {
            let rr = r * (0.88 + sin(y * .pi) * 0.12) + 0.004
            m.add(turned([(rr - 0.002, y * h - 0.02), (rr + 0.003, y * h - 0.018), (rr + 0.003, y * h + 0.018), (rr - 0.002, y * h + 0.02)],
                         segments: 64, material: "metal.rust", seamTile: 0.3))
        }
        // Lid recessed 2 cm, with chime ring.
        m.add(turned([(0, h - 0.02), (r * 0.86, h - 0.02), (r * 0.88, h - 0.005), (r * 0.9, h)], segments: 48, material: "wood.oak", seamTile: 0.5))
        groundAO(&m, height: 0.2, floor: 0.55)
        return LODModel(m)
    }
}

public struct OilDrum: RealAsset {
    public static let id = "oil-drum"
    public static let summary = "55-gallon steel drum, rolling ribs, painted with chips and scratches."
    public static let tags = ["prop", "metal", "container", "industrial"]
    public static let budget = 6_000
    public var color: UInt32 = 0x1F4E8C
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        let r: Float = 0.286, h: Float = 0.88
        var prof: [(Float, Float)] = [(0, 0.004), (r - 0.01, 0.0), (r, 0.012), (r - 0.004, 0.02)]
        for y in [0.29, 0.59] as [Float] {
            prof += [(r - 0.004, y * h - 0.02), (r + 0.006, y * h - 0.008), (r + 0.006, y * h + 0.008), (r - 0.004, y * h + 0.02)]
        }
        prof += [(r - 0.004, h - 0.02), (r, h - 0.012), (r - 0.01, h), (r - 0.018, h - 0.006), (0, h - 0.006)]
        let key = String(format: "metal.painted:%06X", color)
        var m = Model(name: Self.id, surfaces: [turned(prof, segments: 56, material: key, seamTile: 0.45)])
        // Bung caps.
        m.add(turned([(0, 0), (0.025, 0), (0.025, 0.008), (0, 0.01)], segments: 12, material: "metal.steel"), Xform(translation: V3(0.15, h - 0.006, 0.05)))
        groundAO(&m, height: 0.15, floor: 0.55)
        return LODModel(m)
    }
}

public struct ParkBench: RealAsset {
    public static let id = "park-bench"
    public static let summary = "Cast-iron frame park bench with oak seat and back slats."
    public static let tags = ["prop", "urban", "furniture", "wood", "metal"]
    public static let budget = 12_000
    public var length: Float = 1.6
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let iron: MaterialKey = "metal.iron"
        // Side frames: leg + seat support + back post + armrest, as tubes.
        for sx: Float in [-1, 1] {
            let x = sx * (length / 2 - 0.12)
            let front: [V3] = [V3(x, 0, 0.24), V3(x, 0.2, 0.22), V3(x, 0.42, 0.2), V3(x, 0.6, 0.22), V3(x, 0.64, 0.12), V3(x, 0.62, -0.05)]
            let rear: [V3] = [V3(x, 0, -0.26), V3(x, 0.2, -0.22), V3(x, 0.42, -0.2), V3(x, 0.6, -0.27), V3(x, 0.85, -0.34)]
            let seatRail: [V3] = [V3(x, 0.42, 0.24), V3(x, 0.43, 0), V3(x, 0.41, -0.22)]
            for path in [front, rear, seatRail] {
                let smooth = catmull(path, per: 6)
                m.add(Prim.tube(smooth, radii: smooth.map { _ in 0.022 }, sides: 10, seamTile: 0.2, material: iron))
            }
            // Feet pads.
            for z: Float in [0.24, -0.26] { m.add(Prim.roundedBox(V3(0.07, 0.02, 0.09), radius: 0.006, material: iron), Xform(translation: V3(x, 0.01, z))) }
        }
        // Seat slats.
        for i in 0..<5 {
            let z = 0.22 - Float(i) * 0.105
            m.add(plank(length, 0.085, 0.032, bevel: 0.006, material: "wood.oak"), Xform(translation: V3(0, 0.445 + Float(i) * 0.002, z)).jittered(&rng, deg: 0.3))
        }
        // Back slats, reclined ~15 degrees.
        for i in 0..<3 {
            let t = Float(i)
            let (b, x) = board(from: V3(-length / 2, 0.56 + t * 0.1, -0.235 - t * 0.026), to: V3(length / 2, 0.56 + t * 0.1, -0.235 - t * 0.026),
                               width: 0.085, thick: 0.028, up: simd_normalize(V3(0, 0.26, 0.97)), bevel: 0.006, material: "wood.oak")
            m.add(b, x.jittered(&rng, deg: 0.3))
        }
        groundAO(&m, height: 0.3, floor: 0.6)
        return LODModel(m)
    }
}

/// Catmull-Rom resample through control points.
func catmull(_ p: [V3], per: Int) -> [V3] {
    guard p.count > 2 else { return p }
    var out: [V3] = []
    for i in 0..<(p.count - 1) {
        let p0 = p[max(0, i - 1)], p1 = p[i], p2 = p[i + 1], p3 = p[min(p.count - 1, i + 2)]
        for k in 0..<per {
            let t = Float(k) / Float(per), t2 = t * t, t3 = t2 * t
            let a = 2 * p1, b = p2 - p0, c = 2 * p0 - 5 * p1 + 4 * p2 - p3, d = -p0 + 3 * p1 - 3 * p2 + p3
            out.append(0.5 * (a + b * t + c * t2 + d * t3))
        }
    }
    out.append(p[p.count - 1])
    return out
}

public struct PicnicTable: RealAsset {
    public static let id = "picnic-table"
    public static let summary = "Weathered wooden picnic table with attached benches and A-frame legs."
    public static let tags = ["prop", "furniture", "wood", "outdoor"]
    public static let budget = 6_000
    public var length: Float = 1.8
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let w: MaterialKey = "wood.weathered"
        for i in 0..<5 {   // tabletop
            m.add(plank(length, 0.14, 0.04, bevel: 0.006, material: w), Xform(translation: V3(0, 0.74, -0.3 + Float(i) * 0.15)).jittered(&rng, deg: 0.4))
        }
        for sz: Float in [-1, 1] { for i in 0..<2 {   // benches
            m.add(plank(length, 0.14, 0.04, bevel: 0.006, material: w), Xform(translation: V3(0, 0.45, sz * (0.62 + Float(i) * 0.15) - sz * 0.075)).jittered(&rng, deg: 0.4))
        }}
        for sx: Float in [-1, 1] {
            let x = sx * (length / 2 - 0.25)
            for sz: Float in [-1, 1] {   // A-frame legs
                let (b, xf) = board(from: V3(x, 0, sz * 0.72), to: V3(x, 0.72, sz * 0.08), width: 0.14, thick: 0.04, up: V3(1, 0, 0), bevel: 0.006, material: w)
                m.add(b, xf.jittered(&rng, deg: 0.4))
            }
            m.add(plank(1.62, 0.1, 0.04, bevel: 0.006, material: w), Xform(translation: V3(x + sx * 0.04, 0.4, 0), rotation: simd_quatf(degrees: 90, axis: .up)))   // bench support
            m.add(plank(0.8, 0.1, 0.04, bevel: 0.006, material: w), Xform(translation: V3(x + sx * 0.04, 0.7, 0), rotation: simd_quatf(degrees: 90, axis: .up)))    // top support
        }
        groundAO(&m, height: 0.35, floor: 0.6)
        return LODModel(m)
    }
}

public struct StreetLamp: RealAsset {
    public static let id = "street-lamp"
    public static let summary = "Victorian cast-iron street lamp: fluted base, tapered pole, lantern with glowing glass."
    public static let tags = ["prop", "urban", "light", "metal"]
    public static let budget = 10_000
    public var height: Float = 3.6
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let iron: MaterialKey = "metal.iron", h = height
        m.add(turned([(0.0, 0), (0.17, 0), (0.17, 0.05), (0.14, 0.08), (0.13, 0.32), (0.1, 0.38), (0.1, 0.45), (0.075, 0.5), (0.06, 0.62),
                      (0.05, h * 0.5), (0.042, h - 0.55), (0.06, h - 0.52), (0.06, h - 0.48), (0.035, h - 0.45), (0.0, h - 0.45)], segments: 32, material: iron))
        // Lantern: tapered frame (4 posts), glass, cap and finial.
        let base = h - 0.45
        m.add(turned([(0, base), (0.12, base), (0.13, base + 0.03), (0, base + 0.03)], segments: 4, material: iron, seamTile: 0.2),
              Xform(rotation: simd_quatf(degrees: 45, axis: .up)))
        m.add(turned([(0.09, base + 0.03), (0.15, base + 0.36)], segments: 4, material: "glass.lamp", seamTile: 0.2), Xform(rotation: simd_quatf(degrees: 45, axis: .up)))
        for k in 0..<4 {
            let a = Float(k) * .pi / 2
            let d0 = V3(cos(a), 0, sin(a)) * 0.095 * 1.4142 / 1.4142, d1 = V3(cos(a), 0, sin(a)) * 0.155
            m.add(Prim.tube([V3(d0.x, base + 0.03, d0.z), V3(d1.x, base + 0.37, d1.z)], radii: [0.008, 0.008], sides: 6, seamTile: 0.1, material: iron))
        }
        m.add(turned([(0.0, base + 0.36), (0.2, base + 0.36), (0.2, base + 0.38), (0.06, base + 0.5), (0.02, base + 0.52), (0.03, base + 0.56), (0, base + 0.6)],
                     segments: 4, material: iron, seamTile: 0.2), Xform(rotation: simd_quatf(degrees: 45, axis: .up)))
        groundAO(&m, height: 0.4, floor: 0.6)
        return LODModel(m)
    }
}

public struct TrafficCone: RealAsset {
    public static let id = "traffic-cone"
    public static let summary = "71 cm traffic cone: orange PVC, two reflective white bands, black rubber base."
    public static let tags = ["prop", "urban", "road"]
    public static let budget = 4_000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let base: Float = 0.035, top: Float = 0.71, r0: Float = 0.15, r1: Float = 0.03
        func r(_ y: Float) -> Float { lerp(r0, r1, (y - base) / (top - base)) }
        let bands: [(Float, Float, MaterialKey)] = [(base, 0.38, "plastic.orange"), (0.38, 0.48, "plastic.white"), (0.48, 0.53, "plastic.orange"),
                                                    (0.53, 0.6, "plastic.white"), (0.6, top, "plastic.orange")]
        for (a, b, mat) in bands {
            var prof: [(Float, Float)] = [(r(a), a), (r(b), b)]
            if b == top { prof += [(r1 * 0.9, top + 0.004), (0, top + 0.004)] }
            m.add(turned(prof, segments: 40, material: mat, seamTile: 0.2))
        }
        // Square rubber base with rounded corners and a raised collar.
        m.add(Prim.roundedBox(V3(0.38, base, 0.38), radius: 0.015, bevelSegments: 3, material: "rubber"), Xform(translation: V3(0, base / 2, 0)))
        m.add(turned([(r0 + 0.02, base), (r0 + 0.012, base + 0.012), (r0 - 0.002, base + 0.014)], segments: 40, material: "rubber"))
        groundAO(&m, height: 0.12, floor: 0.55)
        return LODModel(m)
    }
}

public struct FireHydrant: RealAsset {
    public static let id = "fire-hydrant"
    public static let summary = "Cast-iron fire hydrant, red paint with wear, pentagon nuts, two hose outlets and a pumper nozzle."
    public static let tags = ["prop", "urban", "metal"]
    public static let budget = 10_000
    public var color: UInt32 = 0xB0241A
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let paint = String(format: "metal.painted:%06X", color)
        m.add(turned([(0, 0), (0.15, 0), (0.15, 0.03), (0.115, 0.05), (0.11, 0.09), (0.125, 0.1), (0.125, 0.12), (0.1, 0.13), (0.1, 0.52), (0.12, 0.53),
                      (0.125, 0.56), (0.11, 0.58), (0.105, 0.62), (0.09, 0.68), (0.06, 0.71), (0.0, 0.72)], segments: 36, material: paint))
        // Bolt ring on the flange.
        for k in 0..<8 {
            let a = Float(k) / 8 * 2 * .pi
            m.add(turned([(0, 0), (0.012, 0), (0.012, 0.012), (0, 0.014)], segments: 6, material: "metal.iron"), Xform(translation: V3(cos(a) * 0.115, 0.12, sin(a) * 0.115)))
        }
        // Top pentagon operating nut.
        m.add(turned([(0, 0.71), (0.03, 0.71), (0.03, 0.75), (0, 0.75)], segments: 5, material: paint, seamTile: 0.1))
        // Outlets: two side hose outlets and a front pumper, each with a cap nut.
        let outlets: [(V3, Float, Float)] = [(V3(1, 0, 0), 0.04, 0.09), (V3(-1, 0, 0), 0.04, 0.09), (V3(0, 0, 1), 0.055, 0.11)]
        for (dir, rr, len) in outlets {
            var o = turned([(0, 0), (rr, 0), (rr, len * 0.6), (rr + 0.01, len * 0.62), (rr + 0.01, len * 0.85), (rr * 0.6, len), (0, len)], segments: 24, material: paint, seamTile: 0.15)
            o.append(turned([(0, len), (0.02, len), (0.02, len + 0.025), (0, len + 0.03)], segments: 5, material: paint, seamTile: 0.1))
            let rot = simd_quatf(from: V3(0, 1, 0), to: dir)
            m.add(o, Xform(translation: V3(0, 0.44, 0) + dir * 0.07, rotation: rot))
        }
        groundAO(&m, height: 0.2, floor: 0.5)
        return LODModel(m)
    }
}

public struct Bollard: RealAsset {
    public static let id = "bollard"
    public static let summary = "Cast concrete bollard with domed top and chamfered base."
    public static let tags = ["prop", "urban", "concrete"]
    public static let budget = 3_000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        var prof: [(Float, Float)] = [(0, 0), (0.15, 0), (0.15, 0.03), (0.13, 0.06), (0.12, 0.75)]
        for i in 1...8 { let a = Float(i) / 8 * .pi / 2; prof.append((0.12 * cos(a), 0.75 + 0.07 * sin(a))) }
        m.add(turned(prof, segments: 40, material: "concrete.rough", seamTile: 0.75))
        groundAO(&m, height: 0.2, floor: 0.55)
        return LODModel(m)
    }
}

public struct Pallet: RealAsset {
    public static let id = "pallet"
    public static let summary = "EUR pallet (1.2 x 0.8 m): deck boards, blocks, bottom runners, rough pine."
    public static let tags = ["prop", "wood", "industrial"]
    public static let budget = 10_000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let w: MaterialKey = "wood.weathered"
        for z: Float in [-0.35, 0, 0.35] { m.add(plank(1.2, 0.1, 0.022, material: w), Xform(translation: V3(0, 0.011, z)).jittered(&rng)) }
        for x: Float in [-0.545, 0, 0.545] { for z: Float in [-0.35, 0, 0.35] {
            m.add(Prim.roundedBox(V3(0.1, 0.078, z == 0 ? 0.145 : 0.1), radius: 0.004, material: w), Xform(translation: V3(x, 0.022 + 0.039, z)).jittered(&rng))
        }}
        for x: Float in [-0.545, 0, 0.545] { m.add(plank(0.8, 0.1, 0.022, material: w), Xform(translation: V3(x, 0.111, 0), rotation: simd_quatf(degrees: 90, axis: .up)).jittered(&rng)) }
        for (i, z) in ([-0.35, -0.2, -0.0, 0.2, 0.35] as [Float]).enumerated() {
            m.add(plank(1.2, i % 2 == 0 ? 0.145 : 0.1, 0.022, material: w), Xform(translation: V3(0, 0.133, z)).jittered(&rng))
        }
        groundAO(&m, height: 0.1, floor: 0.6)
        return LODModel(m)
    }
}

public struct Mailbox: RealAsset {
    public static let id = "mailbox"
    public static let summary = "US-style curbside mailbox on a wooden post: tunnel body, door, red flag."
    public static let tags = ["prop", "urban", "metal"]
    public static let budget = 6_000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let paint: MaterialKey = "metal.painted:2A2C30"
        m.add(plank(1.05, 0.1, 0.1, bevel: 0.008, material: "wood.weathered"), Xform(translation: V3(0, 0.525, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        m.add(plank(0.5, 0.2, 0.02, bevel: 0.004, material: "wood.weathered"), Xform(translation: V3(0, 1.06, 0), rotation: simd_quatf(degrees: 90, axis: .up)))
        // Tunnel: box bottom half + half-cylinder top, along Z.
        let L: Float = 0.48, W: Float = 0.17
        m.add(Prim.roundedBox(V3(W, 0.11, L), radius: 0.008, material: paint), Xform(translation: V3(0, 1.07 + 0.055, 0)))
        var arch: [(Float, Float)] = []
        for i in 0...10 { let a = Float(i) / 10 * .pi; arch.append((W / 2 * cos(a), W / 2 * sin(a))) }
        // Half cylinder as a tube along Z (sides chosen so the tube's lower half hides in the box).
        m.add(Prim.tube([V3(0, 1.18, -L / 2), V3(0, 1.18, L / 2)], radii: [W / 2 - 0.001, W / 2 - 0.001], sides: 24, seamTile: 0.3, material: paint, capEnd: true))
        m.add(turned([(0, 0), (W / 2 - 0.001, 0), (W / 2 - 0.001, 0.004), (0, 0.004)], segments: 24, material: paint), Xform(translation: V3(0, 1.18, -L / 2), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
        // Flag.
        m.add(Prim.roundedBox(V3(0.01, 0.2, 0.03), radius: 0.003, material: "metal.painted:B8261C"), Xform(translation: V3(W / 2 + 0.01, 1.2, 0.05)))
        m.add(Prim.roundedBox(V3(0.01, 0.06, 0.08), radius: 0.003, material: "metal.painted:B8261C"), Xform(translation: V3(W / 2 + 0.01, 1.28, 0.08)))
        _ = arch
        return LODModel(m)
    }
}

public struct TrashCan: RealAsset {
    public static let id = "trash-can"
    public static let summary = "Park trash can: ribbed painted steel body, domed lid with opening, steel liner rim."
    public static let tags = ["prop", "urban", "metal"]
    public static let budget = 8_000
    public var color: UInt32 = 0x23402C
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let paint = String(format: "metal.painted:%06X", color)
        var body = turned([(0.0, 0.0), (0.26, 0.0), (0.27, 0.02), (0.27, 0.86), (0.28, 0.88), (0.28, 0.9), (0.25, 0.9), (0.25, 0.85)], segments: 72, material: paint, seamTile: 0.4)
        for i in body.positions.indices {   // vertical ribs
            let p = body.positions[i]
            guard p.y > 0.03 && p.y < 0.85 else { continue }
            let a = atan2(-p.z, p.x), k = 1 + 0.025 * pow(abs(sin(a * 12)), 6)
            body.positions[i] = V3(p.x * k, p.y, p.z * k)
        }
        body.recomputeNormals(); body.computeTangents()
        m.add(body)
        m.add(turned([(0.29, 0.9), (0.29, 0.93), (0.24, 1.02), (0.12, 1.07), (0.12, 1.02), (0.0, 1.02)], segments: 48, material: paint, seamTile: 0.4))
        groundAO(&m, height: 0.25, floor: 0.55)
        return LODModel(m)
    }
}
