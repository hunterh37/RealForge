import Foundation
import simd
import RealCore

extension BirdRigBuilder {
    /// One wing at rest: arm tubes, secondaries, tertials, coverts and ten fanned primaries, all as
    /// feather cards on the parts named in `BirdJoint`. Spanwise `xs` is measured from the shoulder,
    /// `zb` rearward from the shoulder line.
    static func addWing(_ rig: inout Rig, _ f: BirdFrame, _ s: Side, _ rng: inout SeededRNG) {
        let a = f.a
        let S = f.shoulder(s), sx = s.sign
        let hs = f.wingHalfSpan, c = a.wingChord
        let H = 0.24 * hs, F = 0.30 * hs, Dh = 0.22 * hs
        let xE = H, xW = H + F
        let nrm = f.U
        func P(_ xs: Float, _ zb: Float, _ yn: Float = 0) -> V3 { S + V3(sx * xs, 0, 0) + f.Bk * zb + f.U * yn }
        func dir(_ alphaDeg: Float) -> V3 { let al = radians(alphaDeg); return simd_normalize(V3(sx * cos(al), 0, 0) + f.Bk * sin(al)) }
        func layer(_ l: Int) -> Float { Float(l) * 0.0008 }
        func part(_ j: BirdJoint.WingJoint) -> String { BirdJoint.wing(s, j).name }
        let flip = s == .left

        func card(_ base: V3, _ d: V3, _ len: Float, _ w: Float, _ mat: FaunaMaterials.Region, droop: Float, shade: V2 = V2(0.55, 1)) -> Surface {
            let jitter = rng.float(0.97...1.03)
            return Feather.card(base: base, direction: d, normal: nrm, length: len * jitter, width: w, camber: min(0.0009, w * 0.12), droop: droop * len,
                                curl: rng.float(-0.0006...0.0006), shade: shade, flipSide: flip, material: f.mat(mat))
        }

        // Arm: smooth tubes under the coverts.
        let rh = max(0.0035, 0.045 * hs)
        func arm(_ x0: Float, _ x1: Float, _ r0: Float, _ r1: Float, to j: BirdJoint.WingJoint) {
            let tube = Loft.along([P(x0, 0.05 * c), P(x1, 0.05 * c)], up: f.U, count: 5, segments: 10, material: f.mat(.arm)) { t in
                let r = lerp(r0, r1, t); return V3(r, r * 0.8, r * 0.8)
            }
            rig.add(tube, to: part(j))
        }
        arm(0, xE, rh * 1.15, rh, to: .twist)
        arm(xE, xW, rh, rh * 0.8, to: .elbow)
        arm(xW, xW + Dh, rh * 0.8, rh * 0.5, to: .handTwist)

        // Secondaries.
        let ns = 9
        for j in 0..<ns {
            let t = Float(j) / Float(ns - 1)
            let al = 100 - 16 * t + rng.float(-1.5...1.5)
            let zb0 = 0.08 * c
            let len = (c * (0.97 - 0.08 * t) - zb0) / sin(radians(al))
            let xs = xE + F * (Float(j) + 0.5) / Float(ns)
            rig.add(card(P(xs, zb0), dir(al), len, F / Float(ns) * 2.2, .flight, droop: 0.05), to: part(.secFold))
        }
        // Tertials ride on the humerus.
        for (k, al) in [Float(106), 101, 97].enumerated() {
            let xs = H * (0.3 + 0.3 * Float(k))
            rig.add(card(P(xs, 0.1 * c, layer(1)), dir(al), 0.82 * c, F / Float(ns) * 2.4, .flight, droop: 0.06), to: part(.flap))
        }
        // Covert rows: greater, median, lesser. Forearm rows fold with the secondaries.
        let rows: [(z: Float, len: Float, layer: Int)] = [(0.30, 0.42, 1), (0.20, 0.32, 2), (0.10, 0.24, 3)]
        for row in rows {
            let nc = 10
            for j in 0..<nc {
                let t = Float(j) / Float(nc - 1)
                let al = 98 - 14 * t + rng.float(-2...2)
                let xs = xE + F * (Float(j) + 0.5) / Float(nc)
                rig.add(card(P(xs, row.z * c, layer(row.layer)), dir(al), row.len * c, F / Float(nc) * 2.5, .covert, droop: 0.05), to: part(.secFold))
            }
            for j in 0..<4 {
                let xs = H * (Float(j) + 0.5) / 4
                rig.add(card(P(xs, row.z * c * 0.8, layer(row.layer)), dir(102), row.len * c, H / 4 * 2.5, .covert, droop: 0.05), to: part(.flap))
            }
        }
        // Scapulars along the back.
        for j in 0..<4 {
            let xs = H * (0.1 + 0.22 * Float(j))
            rig.add(card(P(xs, 0.0, layer(3)), dir(108 + 3 * Float(j)), 0.6 * c, H / 3, .covert, droop: 0.05), to: part(.flap))
        }
        // Primaries, fanned along the hand.
        let np = a.primaries
        for i in 0..<np {
            let tt = Float(i) / Float(np - 1)
            let xs = xW + Dh * 0.95 * tt
            let zb0 = 0.10 * c
            let beta = tt * radians(78)
            let xTip = xW + (hs - xW) * sin(beta)
            let zTip = 0.98 * c * cos(beta)
            let dx = xTip - xs, dz = zTip - zb0
            let al = degrees(atan2(dz, dx))
            let len = (dx * dx + dz * dz).squareRoot() * (np == 9 && i == np - 1 ? 0.8 : 1)
            let group: BirdJoint.WingJoint = i < np / 3 ? .primA : (i < 2 * np / 3 ? .primB : .primC)
            let w = max(0.0035, Dh / Float(np) * 2.1)
            rig.add(card(P(xs, zb0), dir(al), len, w, .flight, droop: 0.04), to: part(group))
            rig.add(card(P(xs, 0.28 * c, layer(1)), dir(al), min(len * 0.4, 0.4 * c), w * 1.1, .covert, droop: 0.04), to: part(group))
        }
    }
}

@inline(__always) func degrees(_ r: Float) -> Float { r * 180 / .pi }
