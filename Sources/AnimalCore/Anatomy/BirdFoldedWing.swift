import Foundation
import simd
import RealCore

// Folded wing for perched and walking poses. A songbird's closed wing lies flat on the upper flank as
// one smooth teardrop, with the primary tips stacked over the rump. Folding the spread feather cards
// through the joints cannot reach that shape, so the rig swaps: spread cards (option 0) below
// `foldThreshold` on `primFold`, this shell plus a few flat cards (option 1) above it.

extension BirdRigBuilder {
    public static let foldThreshold: Float = 60

    public static func foldPartName(_ s: Side) -> String { s == .left ? "wingFoldL" : "wingFoldR" }

    /// Body surface half width at body station t (0 rear, 1 front).
    static func bodyHalfWidth(_ f: BirdFrame, _ t: Float) -> Float { 0.5 * f.a.bodyWidth * f.bodyProfile(t) }

    static func addFoldedWing(_ rig: inout Rig, _ f: BirdFrame, _ s: Side, _ rng: inout SeededRNG) {
        let a = f.a, sx = s.sign, part = foldPartName(s)
        // Station along the body: shoulder near the front, tip past the rump over the tail.
        let tS: Float = 0.78
        let L = a.wingChord * 1.32
        let n = 14
        let thick = max(0.0016, 0.07 * a.bodyWidth)
        var secs: [LoftSection] = []
        var spine: [V3] = []
        let heightProfile = Profile([V2(0, 0.42), V2(0.12, 0.78), V2(0.32, 0.86), V2(0.55, 0.66), V2(0.78, 0.36), V2(1, 0.06)])
        for i in 0..<n {
            let t = Float(i) / Float(n - 1)
            let along = t * L
            let tb = tS - along / a.bodyLength                        // body station under this section
            let onBody = tb >= 0.04
            let hw = onBody ? bodyHalfWidth(f, tb) : bodyHalfWidth(f, 0.04) * max(0.25, 1 - (0.04 - tb) * a.bodyLength / (0.35 * a.tailLength + 0.001))
            let base = f.C + f.A * ((tS - 0.5) * a.bodyLength) - f.A * along
            let lift = f.U * (0.5 * a.bodyDepth * (0.20 - 0.10 * t))
            let c = base + lift + V3(sx * (hw * 0.86 + thick * 0.3), 0, 0)
            spine.append(c)
            // Lean the panel inward toward the back so it follows the rounded flank.
            let lean = simd_quatf(angle: -sx * radians(22 + 14 * t), axis: f.A)
            let up = lean.act(f.U)
            let right = simd_normalize(simd_cross(f.A * -1, up)) * (s == .right ? 1 : -1)
            secs.append(LoftSection(center: c, right: right, up: up, halfWidth: thick * (1 - 0.6 * t),
                                    halfDorsal: 0.5 * a.bodyDepth * 0.62 * heightProfile(t), halfVentral: 0.5 * a.bodyDepth * 0.52 * heightProfile(t), exponent: 2.4))
        }
        rig.add(Loft.build(secs, segments: 18, material: f.mat(.wingFold)), to: part, option: 1)

        // Primary stack: a narrower, darker layer over the rear half that runs out to the tip.
        var ps: [LoftSection] = []
        let m = 10
        for i in 0..<m {
            let t = Float(i) / Float(m - 1)
            let gt = 0.45 + 0.55 * t
            let k = gt * Float(n - 1), i0 = min(n - 2, Int(k)), fr = k - Float(i0)
            let c = lerp(spine[i0], spine[i0 + 1], fr)
            let sec = secs[i0]
            let h = 0.5 * a.bodyDepth * 0.42 * (1 - 0.92 * pow(t, 1.4))
            ps.append(LoftSection(center: c + sec.right * (s == .right ? 1 : -1) * thick * 0.55 - sec.up * (0.5 * a.bodyDepth * 0.08 * (1 - t)),
                                  right: sec.right, up: sec.up, halfWidth: thick * 0.55 * (1 - 0.5 * t),
                                  halfDorsal: h, halfVentral: h * 0.9, exponent: 2.6))
        }
        rig.add(Loft.build(ps, segments: 14, material: f.mat(.primaryFold)), to: part, option: 1)
    }
}
