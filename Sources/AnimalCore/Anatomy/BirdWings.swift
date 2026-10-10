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

        // Solid wing panels: an elliptical airfoil lofted along the span on each bone segment. The
        // cards below only add the feathered trailing edge and the primary fingers.
        func panel(_ x0: Float, _ x1: Float, chord: (Float) -> Float, lead: Float, to j: BirdJoint.WingJoint) {
            var secs: [LoftSection] = []
            let m = 8
            for i in 0..<m {
                let t = Float(i) / Float(m - 1)
                let xs = lerp(x0, x1, t), ch = chord(t)
                let th = max(0.0010, 0.11 * ch * (1 - 0.5 * t))
                secs.append(LoftSection(center: P(xs, lead + 0.5 * ch, th * 0.25), right: f.Bk, up: nrm, halfWidth: 0.5 * ch,
                                        halfDorsal: th * 0.6, halfVentral: th * 0.4, exponent: 2))
            }
            rig.add(Loft.build(secs, segments: 16, material: f.mat(.wingFold)), to: part(j))
        }
        panel(-0.25 * H, xE + 0.04 * hs, chord: { t in c * (1.0 - 0.05 * t) }, lead: -0.04 * c, to: .twist)
        panel(xE - 0.04 * hs, xW + 0.04 * hs, chord: { t in c * (0.97 - 0.27 * t) }, lead: -0.035 * c, to: .secFold)
        panel(xW - 0.04 * hs, xW + Dh * 1.15, chord: { t in c * 0.72 * (1 - 0.55 * t * t) }, lead: -0.03 * c, to: .handTwist)

        // Secondaries: trailing-edge cards from mid chord to just past the panel.
        let ns = 9
        for j in 0..<ns {
            let t = Float(j) / Float(ns - 1)
            let al = 96 - 10 * t + rng.float(-1...1)
            let zb0 = 0.45 * c
            let len = (c * (1.04 - 0.16 * t) - zb0) / sin(radians(al))
            let xs = xE + F * (Float(j) + 0.5) / Float(ns)
            rig.add(card(P(xs, zb0, -0.0004), dir(al), len, F / Float(ns) * 2.6, .flight, droop: 0.03), to: part(.secFold))
        }
        for (k, al) in [Float(100), 97, 94].enumerated() {
            let xs = H * (0.25 + 0.3 * Float(k))
            rig.add(card(P(xs, 0.45 * c, -0.0004), dir(al), 0.62 * c, F / Float(ns) * 2.8, .flight, droop: 0.03), to: part(.flap))
        }
        // Primaries, fanned along the hand.
        let np = a.primaries
        for i in 0..<np {
            let tt = Float(i) / Float(np - 1)
            let xs = xW + Dh * 0.95 * tt
            let zb0 = 0.18 * c
            let beta = tt * radians(78)
            let xTip = xW + (hs - xW) * sin(beta)
            let zTip = 0.98 * c * cos(beta)
            let dx = xTip - xs, dz = zTip - zb0
            let al = degrees(atan2(dz, dx))
            let len = (dx * dx + dz * dz).squareRoot() * (np == 9 && i == np - 1 ? 0.8 : 1)
            let group: BirdJoint.WingJoint = i < np / 3 ? .primA : (i < 2 * np / 3 ? .primB : .primC)
            let w = max(0.0045, Dh / Float(np) * 3.0)
            rig.add(card(P(xs, zb0), dir(al), len, w, .flight, droop: 0.04), to: part(group))
        }
    }
}

@inline(__always) func degrees(_ r: Float) -> Float { r * 180 / .pi }
