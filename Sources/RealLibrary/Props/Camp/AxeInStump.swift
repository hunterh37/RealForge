import simd
import Foundation

/// Chopping block with an axe: a 45 cm oak round, 40 cm tall, sawn both ends, a 1.25 kg felling axe
/// (forged head with a ground bevel, 70 cm hickory handle with a swelled knob) driven into the end grain,
/// and split chips on the ground around it.
public struct AxeInStump: RealAsset {
    public static let id = "axe-in-stump"
    public static let summary = "Chopping block with a felling axe sunk in the end grain: oak round, forged head, hickory handle, split chips around."
    public static let tags = ["prop", "camp", "wood", "tool"]
    public static let budget = 5_000
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 20, elevation: 22, distance: 1.1)

    public var blockDiameter: Float = 0.45
    public var blockHeight: Float = 0.4
    public var handleLength: Float = 0.7
    public var chips = 7
    public init() {}

    /// Felling axe head, eye at the origin: length along +X (poll at x < 0, bit at +X), blade edge along Y.
    static func axeHead(material: MaterialKey, edge: MaterialKey) -> [Surface] {
        let nu = 14, nv = 10
        func yr(_ u: Float) -> (Float, Float) {
            // Bottom and top of the head along its length; the bit flares into a curved edge.
            let flare = pow(max(0, u - 0.35) / 0.65, 1.6)
            return (-0.032 - 0.05 * flare, 0.032 + 0.035 * flare)
        }
        func half(_ u: Float) -> Float { 0.017 * pow(1 - u, 0.7) + 0.0008 }
        let x0: Float = -0.045, x1: Float = 0.155
        var sides: [Surface] = []
        for s: Float in [-1, 1] {
            var rows: [[V3]] = [], uvs: [[V2]] = []
            for i in 0...nu {
                let u = Float(i) / Float(nu)
                let (b, t) = yr(u)
                var row: [V3] = [], uv: [V2] = []
                for j in 0...nv {
                    let v = Float(j) / Float(nv)
                    let e = 2 * v - 1
                    let round = pow(max(0, 1 - pow(abs(e), 6)), 0.5)
                    let bitCurve = 0.012 * (1 - e * e) * smoothstep(0.8, 1, u)
                    let x = x0 + (x1 - x0) * u + bitCurve
                    row.append(V3(x, b + (t - b) * v, s * half(u) * round)); uv.append(V2(x, b + (t - b) * v))
                }
                rows.append(row); uvs.append(uv)
            }
            var g = WoodParts.grid(rows, uvs: uvs, material: material)
            WoodParts.orientOutward(&g) { p in V3(p.x, p.y, 0) }
            g.recomputeNormals(weldSeams: false); g.computeTangents()
            sides.append(g)
            // Ground bevel: the last 2 cm of the bit is bright steel.
            var bevel = Surface(material: edge)
            let last = rows.count - 1
            for i in [last - 1, last] { for p in rows[i] { bevel.add(p + V3(0, 0, s * 0.0004), .up, V2(p.x, p.y)) } }
            let r = UInt32(nv + 1)
            for k in 0..<UInt32(nv) { bevel.quad(k, k + 1, k + r + 1, k + r) }
            WoodParts.orientOutward(&bevel) { p in V3(p.x, p.y, 0) }
            bevel.recomputeNormals(weldSeams: false); bevel.computeTangents()
            sides.append(bevel)
        }
        // Poll face.
        let (b, t) = yr(0)
        let poll = [V3(x0, b, -half(0)), V3(x0, b, half(0)), V3(x0, t, half(0)), V3(x0, t, -half(0))]
        var cap = WoodParts.cap(poll, normal: V3(-1, 0, 0), pith: V3(x0, 0, 0), e1: V3(0, 1, 0), e2: V3(0, 0, 1), radius: 0.05, spin: 0, material: material)
        cap.computeTangents()
        sides.append(cap)
        return sides
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = rng.vary(blockDiameter / 2, 0.08), H = rng.vary(blockHeight, 0.08)
        // Block: a full round stood on end.
        let round = WoodParts.splitPiece(length: H, radius: R, start: 0, sweep: 2 * .pi, barkThickness: 0.02, bark: "bark.oak-dry",
                                         split: "wood.oak", end: "wood.endgrain-weathered", arcSegments: 16, lengthSegments: 3, barkScale: 1.2,
                                         seed: seed &+ 11)
        m.add(round, Xform(translation: V3(0, H / 2, 0), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1))))
        // Axe: bit sunk 3 cm into the top, handle rising toward -X at about 25 degrees.
        let lean = rng.float(18...32)
        let rot = simd_quatf(degrees: -90 - lean, axis: V3(0, 0, 1))
        let bitDir = rot.act(V3(1, 0, 0))
        let bitTip = V3(rng.float(-0.04...0.04), H - 0.03, rng.float(-0.05...0.05))
        let eye = bitTip - bitDir * 0.15
        let headX = Xform(translation: eye, rotation: rot)
        for s in Self.axeHead(material: "metal.iron", edge: "metal.steel") { m.add(s, headX) }
        // Handle: through the eye, slight S-curve, swelled knob.
        var local: [V3] = []
        let hl = rng.vary(handleLength, 0.05)
        for i in 0...10 {
            let t = Float(i) / 10
            local.append(V3(0.008 * sin(t * .pi * 1.6) + 0.006 * t, 0.045 - (hl + 0.045) * t, 0))
        }
        let radii: [Float] = local.indices.map { i in
            let t = Float(i) / 10
            return 0.015 - 0.003 * sin(t * .pi) + (t > 0.9 ? 0.006 * (t - 0.9) / 0.1 : 0)
        }
        var handle = Prim.tube(local.map { headX.point($0) }, radii: radii, sides: 10, seamTile: 0.1, material: "wood.pine")
        handle.uvs = handle.uvs.map { V2($0.y, $0.x) }
        handle.computeTangents()
        m.add(handle)
        // Chips and splinters scattered around the block.
        for i in 0..<chips {
            let a = rng.float(0...(2 * .pi)), d = R + rng.float(0.05...0.35)
            let chip = WoodParts.splitPiece(length: rng.float(0.05...0.12), radius: rng.float(0.03...0.06), start: 0, sweep: rng.float(0.3...0.7),
                                            barkThickness: 0.006, bark: "bark.oak-dry", split: "wood.oak", end: "wood.endgrain",
                                            arcSegments: 2, lengthSegments: 1, seed: seed &+ UInt64(i) &* 31)
            var c = chip.transformed(Xform(rotation: simd_quatf(degrees: rng.float(0...360), axis: V3(1, 0, 0))))
            let mn = c.bounds.min.y
            c = c.transformed(Xform(translation: V3(cos(a) * d, -mn - 0.003, sin(a) * d), rotation: simd_quatf(degrees: rng.float(0...360), axis: .up)))
            m.add(c)
        }
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
