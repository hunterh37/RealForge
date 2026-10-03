import simd
import Foundation

/// Fallen trunk section, 3.6 m long tapering from 40 to 24 cm: slight bow, sawn butt with weathered end
/// grain, snapped top with splintered wood, broken branch stubs, bark peeling off in patches over grey
/// wood, moss on the upper side. Rests sunk a few centimeters into the litter. 3 LODs.
public struct FallenLog: RealAsset {
    public static let id = "fallen-log"
    public static let summary = "Fallen trunk, 3.6 m: tapered and bowed, sawn butt, snapped top, branch stubs, peeling bark over grey wood, moss on top."
    public static let tags = ["nature", "wood"]
    public static let budget = 6_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 22, distance: 0.75)

    public var length: Float = 3.6
    /// Diameter at the butt and at the top, meters.
    public var buttDiameter: Float = 0.4
    public var topDiameter: Float = 0.24
    /// Fraction of bark peeled away (0...0.6).
    public var peeled: Float = 0.25
    public var branchStubs = 4
    /// Depth the log has settled into the ground, meters.
    public var sink: Float = 0.04
    public var barkThickness: Float = 0.018
    public var bark: MaterialKey = "bark.oak-mossy"
    public var wood: MaterialKey = "wood.deadwood"
    public var end: MaterialKey = "wood.endgrain-weathered"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let ns = UInt32(truncatingIfNeeded: seed)
        let L = rng.vary(length, 0.12), r0 = rng.vary(buttDiameter / 2, 0.12), r1 = rng.vary(topDiameter / 2, 0.12)
        let bow = rng.float(-0.12...0.12), sag = rng.float(0...0.03)
        let half = L / 2
        let spin = rng.float(0...(2 * .pi))
        let peelAmount = min(max(peeled, 0), 0.6)
        // Break profile at the top end: splinter length per angle.
        let breakSeed = ns &+ 17
        func splinter(_ a: Float) -> Float {
            let n = abs(Noise.fbm(V3(cos(a) * 5, sin(a) * 5, 0.5), octaves: 3, seed: breakSeed))
            let big = max(0, Noise.perlin(V3(cos(a) * 1.5, sin(a) * 1.5, 2.5), seed: breakSeed &+ 1))
            return r1 * (0.1 + 6 * n * n + 1.5 * big)
        }
        struct Stub { var t: Float; var a: Float; var len: Float; var r: Float; var tilt: Float }
        let stubs = (0..<branchStubs).map { _ -> Stub in
            // Upper and side directions only; stubs underneath broke off when it fell.
            Stub(t: rng.float(0.15...0.9), a: rng.float(-1.9...1.9), len: rng.float(0.1...0.35), r: rng.float(0.025...0.05), tilt: rng.float(25...60))
        }
        // Axis and radius along the log (t in 0...1 from butt to top).
        func taper(_ t: Float) -> Float { r0 + (r1 - r0) * t + r0 * 0.12 * exp(-t * 18) }
        func center(_ t: Float) -> V3 {
            let x = -half + L * t
            let b = 4 * t * (1 - t)
            return V3(x, taper(t) - sink - sag * b, bow * b)
        }
        func radial(_ a: Float) -> V3 { V3(0, cos(a), sin(a)) }
        func r(_ t: Float, _ a: Float) -> Float {
            let p = V3(t * L * 1.3, cos(a) * 1.4, sin(a) * 1.4)
            return taper(t) * (1 + 0.05 * Noise.fbm(p, octaves: 3, seed: ns) + 0.03 * Noise.perlin(p * 3, seed: ns &+ 1))
        }
        func lod(_ nl: Int, _ na: Int, detail: Int) -> Model {
            var m = Model(name: Self.id)
            let barkTile = MaterialLibrary.spec(for: bark).tileSize
            let uTotal = max(barkTile, (2 * .pi * (r0 + r1) / 2 / barkTile).rounded() * barkTile)
            var rows: [[V3]] = [], uvs: [[V2]] = []
            for i in 0...nl {
                let t = Float(i) / Float(nl)
                var row: [V3] = [], uv: [V2] = []
                for k in 0...na {
                    let a = Float(k % na) / Float(na) * 2 * .pi
                    row.append(center(t) + radial(a) * r(t, a)); uv.append(V2(Float(k) / Float(na) * uTotal, t * L))
                }
                rows.append(row); uvs.append(uv)
            }
            var shell = WoodParts.grid(rows, uvs: uvs, material: bark)
            func axisPoint(_ p: V3) -> V3 { center(min(max((p.x + half) / L, 0), 1)) }
            WoodParts.orientOutward(&shell, center: axisPoint)
            if detail >= 1 && peelAmount > 0 {
                WoodParts.peel(&shell, thickness: barkThickness) { p in
                    let t = (p.x + half) / L
                    if t < 0.04 || t > 0.97 { return true }
                    let n = Noise.fbm(V3(p.x * 1.6, p.y * 5, p.z * 5), octaves: 3, seed: ns &+ 5)
                    return n > peelAmount * 0.9 - 0.25
                }
                // Weathered wood under the bark, along the grain (U = length).
                let cl = max(6, nl / 2), ca = max(6, na / 2)
                var core: [[V3]] = [], cuv: [[V2]] = []
                for i in 0...cl {
                    let t = Float(i) / Float(cl)
                    var row: [V3] = [], uv: [V2] = []
                    for k in 0...ca {
                        let a = Float(k % ca) / Float(ca) * 2 * .pi
                        row.append(center(t) + radial(a) * (taper(t) * 0.93 - barkThickness)); uv.append(V2(t * L, Float(k) / Float(ca) * 2 * .pi * taper(t)))
                    }
                    core.append(row); cuv.append(uv)
                }
                var cs = WoodParts.grid(core, uvs: cuv, material: wood)
                WoodParts.orientOutward(&cs, center: axisPoint)
                cs.recomputeNormals()
                m.add(cs)
            } else {
                shell.recomputeNormals()
            }
            m.add(shell)
            // Sawn butt: end grain inside a bark ring.
            let c0 = center(0)
            let rim0 = rows[0].dropLast()
            let inner0 = rim0.map { p -> V3 in let d = p - c0; return c0 + d * ((simd_length(d) - barkThickness) / simd_length(d)) + V3(0.004, 0, 0) }
            let n0 = V3(-1, 0, 0)
            m.add(WoodParts.ring(inner: Array(inner0), outer: Array(rim0), normal: n0, material: "bark.oak"))
            m.add(WoodParts.cap(Array(inner0), normal: n0, pith: c0, e1: V3(0, 1, 0), e2: V3(0, 0, 1), radius: r0 - barkThickness, spin: spin, material: end))
            // Snapped top: splintered wood from the bark rim out to jagged tips.
            let c1 = center(1), axis = simd_normalize(center(1) - center(0.97))
            var brk: [[V3]] = [], buv: [[V2]] = []
            let steps = detail >= 1 ? 4 : 2
            for j in 0...steps {
                let s = Float(j) / Float(steps)
                var row: [V3] = [], uv: [V2] = []
                for k in 0...na {
                    let a = Float(k % na) / Float(na) * 2 * .pi
                    let rr = (r(1, a) - barkThickness * (j == 0 ? 0 : 1)) * (1 - 0.55 * s)
                    let lead = splinter(a) * (j == 0 ? 0 : pow(s, 0.7)) + (j == 0 ? 0 : 0.01)
                    row.append(c1 + radial(a) * rr + axis * lead); uv.append(V2(L + lead, a * r1))
                }
                brk.append(row); buv.append(uv)
            }
            var br = WoodParts.grid(brk, uvs: buv, material: wood)
            WoodParts.orientOutward(&br) { p in c1 + axis * (simd_dot(p - c1, axis) - 0.05) }
            br.recomputeNormals(weldSeams: false)
            br.bakeCavityAO(strength: 1.2, floor: 0.4)
            m.add(br)
            // Torn heartwood between the splinters, recessed behind them.
            let crown = brk[steps].dropLast().map { p -> V3 in let d = p - c1; let l = simd_dot(d, axis); return c1 + (d - axis * l) + axis * (l * 0.55) }
            var torn = WoodParts.cap(Array(crown), normal: axis, pith: c1, e1: V3(0, 1, 0), e2: V3(0, 0, 1), radius: r1, spin: spin, material: wood)
            torn.positions[0] -= axis * 0.03
            torn.recomputeNormals(weldSeams: false)
            m.add(torn)
            // Bridge from splinter tips back to the recessed crown.
            var bridge = WoodParts.grid([brk[steps], crown + [crown[0]]], uvs: [buv[steps], buv[steps]], material: wood)
            WoodParts.orientOutward(&bridge) { p in c1 + axis * (simd_dot(p - c1, axis) - 0.05) }
            bridge.recomputeNormals(weldSeams: false)
            m.add(bridge)
            // Branch stubs: short bark tubes with broken wood ends.
            if detail >= 1 {
                for s in stubs {
                    let base = center(s.t), a = s.a
                    let out = simd_normalize(radial(a) * cos(radians(90 - s.tilt)) + V3(1, 0, 0) * sin(radians(90 - s.tilt)) * 0.6)
                    let p0 = base + radial(a) * taper(s.t) * 0.6
                    let p1 = base + radial(a) * taper(s.t) + out * s.len * 0.5
                    let p2 = base + radial(a) * taper(s.t) + out * s.len
                    let path = catmull([p0, p1, p2], per: 3)
                    let radii = path.indices.map { i in s.r * (1.5 - 0.6 * Float(i) / Float(path.count - 1)) }
                    let sides = detail >= 2 ? 9 : 6
                    m.add(Prim.tube(path, radii: radii, sides: sides, seamTile: barkTile, material: bark, capEnd: false))
                    let tan = simd_normalize(path[path.count - 1] - path[path.count - 2])
                    let e1 = tan.anyPerpendicular, e2 = simd_cross(tan, e1)
                    let tip = path[path.count - 1], rt = radii[radii.count - 1]
                    let ring = (0..<sides).map { k -> V3 in
                        let ang = Float(k) / Float(sides) * 2 * .pi
                        return tip + (e1 * cos(ang) + e2 * sin(ang)) * rt + tan * rt * 0.6 * abs(sin(ang * 1.5 + s.a))
                    }
                    m.add(WoodParts.cap(ring, normal: tan, pith: tip, e1: e1, e2: e2, radius: rt, spin: s.a, material: end))
                }
            }
            for i in m.surfaces.indices {
                if m.surfaces[i].tangents.count != m.surfaces[i].positions.count { m.surfaces[i].computeTangents() }
                // Contact shadow where the log meets the litter.
                for v in m.surfaces[i].positions.indices {
                    m.surfaces[i].occlusion[v] *= 0.45 + 0.55 * smoothstep(-0.02, 0.18, m.surfaces[i].positions[v].y)
                }
            }
            return m
        }
        return LODModel(levels: [lod(48, 32, detail: 2), lod(16, 12, detail: 1), lod(6, 7, detail: 0)], switchDistances: [12, 35])
    }
}
