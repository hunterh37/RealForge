import Foundation
import simd
import RealCore

// Geometry for each part of the bird rig. All geometry is authored in rig space at rest: wings
// extended along +-X in the plane of the body, tail closed, lids shut, jaw closed.

extension BirdRigBuilder {
    static func addBody(_ rig: inout Rig, _ f: BirdFrame, _ rng: inout SeededRNG) {
        let a = f.a, bp = f.bodyProfile
        var secs: [LoftSection] = []
        let n = 15
        for i in 0..<n {
            let t = Float(i) / Float(n - 1), r = bp(t)
            let c = f.C + f.A * ((t - 0.5) * a.bodyLength) - f.U * (0.02 * a.bodyDepth * r)
            secs.append(LoftSection(center: c, right: BirdFrame.X, up: f.U, halfWidth: 0.5 * a.bodyWidth * r,
                                    halfDorsal: 0.5 * a.bodyDepth * 0.86 * r, halfVentral: 0.5 * a.bodyDepth * 1.10 * r, exponent: 2.0))
        }
        rig.base[0].add(Loft.build(secs, segments: 24, material: f.mat(.body)))
    }

    static func addHead(_ rig: inout Rig, _ f: BirdFrame) {
        let a = f.a
        // Neck: from inside the body front up to the back of the head, textured with the body's front end.
        let pn = f.neckPivot
        let pe = f.headCenter + V3(0, -0.15 * a.headHeight, 0.25 * a.headLength)
        let r0 = 0.5 * a.bodyWidth * 0.80, r1 = 0.5 * a.headWidth * 0.92
        let neck = Loft.along([pn - f.neckDir * 0.012, lerp(pn, pe, 0.5), pe], up: V3(0, 1, 0.3), count: 6, segments: 18,
                              vRange: 0.88...1.0, exponent: 2, material: f.mat(.body)) { t in
            let r = lerp(r0, r1, t); return V3(r, r, r)
        }
        rig.add(neck, to: BirdJoint.neckPitch.name)

        // Head hull.
        var secs: [LoftSection] = []
        let n = 10
        for i in 0..<n {
            let t = Float(i) / Float(n - 1), hp = f.headProfile(t)
            secs.append(LoftSection(center: f.headCenterAt(t), right: BirdFrame.X, up: BirdFrame.Y, halfWidth: f.headHalfWidth(t),
                                    halfDorsal: 0.5 * a.headHeight * 0.5 * hp, halfVentral: 0.5 * a.headHeight * (0.58 + 0.2 * (1 - t)) * hp, exponent: 2.2))
        }
        rig.add(Loft.build(secs, segments: 22, material: f.mat(.head)), to: BirdJoint.headPitch.name)

        addBeak(&rig, f)
        addEyes(&rig, f)
        addCrest(&rig, f)
    }

    static func addBeak(_ rig: inout Rig, _ f: BirdFrame) {
        let a = f.a, b0 = f.beakBase
        func taper(_ t: Float, _ k: Float) -> Float { max(0.06, 1 - pow(t, k) * 0.94) }
        var up: [LoftSection] = []
        let n = 9
        for i in 0..<n {
            let t = Float(i) / Float(n - 1)
            let c = V3(0, b0.y + 0.12 * a.beakDepth * (1 - t) - a.beakCurve * t * t, b0.z - t * a.beakLength + 0.2 * a.headLength * 0.12 * (1 - t))
            up.append(LoftSection(center: c, right: BirdFrame.X, up: BirdFrame.Y, halfWidth: 0.5 * a.beakWidth * taper(t, 1.3),
                                  halfDorsal: 0.5 * a.beakDepth * 0.56 * taper(t, 1.5), halfVentral: 0.5 * a.beakDepth * 0.44 * taper(t, 1.5), exponent: 2.6))
        }
        rig.add(Loft.build(up, segments: 12, material: f.mat(.beak)), to: BirdJoint.headPitch.name)

        let g = f.gape
        let tipL = V3(0, b0.y - a.beakCurve - 0.002 * a.beakDepth, b0.z - a.beakLength * 0.97)
        var lo: [LoftSection] = []
        for i in 0..<n {
            let t = Float(i) / Float(n - 1)
            let c = lerp(g, tipL, t)
            let k = max(0.06, 1 - pow(t, 1.4) * 0.94)
            lo.append(LoftSection(center: c, right: BirdFrame.X, up: BirdFrame.Y, halfWidth: 0.5 * a.beakWidth * 0.95 * k,
                                  halfDorsal: 0.5 * a.beakDepth * 0.32 * k, halfVentral: 0.5 * a.beakDepth * 0.28 * k, exponent: 2.6))
        }
        rig.add(Loft.build(lo, segments: 12, material: f.mat(.beak)), to: BirdJoint.jaw.name)
    }

    static func addEyes(_ rig: inout Rig, _ f: BirdFrame) {
        let a = f.a, er = a.eyeRadius
        let ring = f.p.plumage.eyeRing != f.p.plumage.cheek
        for s in Side.allCases {
            let c = f.eyeCenter(s)
            let eye = Prim.cubeSphere(subdivisions: 4, material: f.mat(.eye)) { $0 * er }
            rig.add(eye, Xform(translation: c), to: BirdJoint.headPitch.name)
            let face = simd_quatf(angle: -s.sign * .pi / 2, axis: BirdFrame.Z)   // lathe +Y -> outward X
            if ring {
                let r = Prim.lathe([V2(er * 1.0, 0), V2(er * 1.05, er * 0.34), V2(er * 1.55, er * 0.2), V2(er * 1.8, 0)], segments: 20,
                                   seamTile: 0.02, material: f.mat(.ring))
                rig.add(r, Xform(translation: c + V3(s.sign * er * 0.35, 0, 0), rotation: face), to: BirdJoint.headPitch.name)
            }
            // Lid: a shallow cap over the eye. Rotating it about Z slides it up into the head.
            let R = er * 1.2
            var prof: [V2] = []
            for k in 0...6 { let al = Float(k) / 6 * radians(78); prof.append(V2(R * sin(al), R * cos(al))) }
            let lid = Prim.lathe(prof, segments: 16, seamTile: 0.02, material: f.mat(.ring))
            rig.add(lid, Xform(translation: c, rotation: face), to: s == .left ? BirdJoint.lidL.name : BirdJoint.lidR.name)
        }
    }

    static func addCrest(_ rig: inout Rig, _ f: BirdFrame) {
        let a = f.a
        guard a.crestHeight > 0 else { return }
        // Tuft rising from the crown and sweeping back to a point.
        let root = f.headCenter + V3(0, 0.30 * a.headHeight, -0.10 * a.headLength)
        let mid = root + V3(0, 0.55 * a.crestHeight, 0.30 * a.crestLength)
        let tip = root + V3(0, 0.95 * a.crestHeight, 0.75 * a.crestLength)
        let w = 0.5 * a.headWidth * 0.55
        let tuft = Loft.along([root - V3(0, 0.2 * a.headHeight, 0), root, mid, tip], up: V3(0, 0.3, 1), count: 10, segments: 14, exponent: 2,
                              material: f.mat(.crest)) { t in
            let k = t < 0.15 ? 1 : max(0.04, 1 - pow((t - 0.15) / 0.85, 1.3))
            return V3(w * k, w * 0.75 * k, w * 0.75 * k)
        }
        rig.add(tuft, to: BirdJoint.crest.name)
    }

    static func addTail(_ rig: inout Rig, _ f: BirdFrame, _ rng: inout SeededRNG) {
        let a = f.a
        let nT = simd_normalize(f.U - f.tailDir * simd_dot(f.U, f.tailDir))
        let nH = max(2, a.tailFeathers / 2)
        let pitch = BirdJoint.tailPitch.name
        for s in Side.allCases {
            let part = s == .left ? BirdJoint.tailFanL.name : BirdJoint.tailFanR.name
            for i in 0..<nH {
                let t = Float(i) / Float(nH - 1)
                var len = a.tailLength
                if a.tailFork > 0 { len -= a.tailFork * (1 - t) } else { len += a.tailFork * t }
                let w = a.tailWidth * 0.5 / Float(nH) * 2.1
                let off = (Float(i) + 0.5) * (a.tailWidth * 0.5 / Float(nH)) * 0.5
                let base = f.tailPivot + V3(s.sign * off, 0, 0) - nT * (Float(i) * 0.00035)
                let omega = radians(0.4 + 0.9 * Float(i)) * s.sign
                let d = simd_quatf(angle: omega, axis: nT).act(f.tailDir)
                let c = Feather.card(base: base, direction: d, normal: nT, length: len, width: w, camber: 0.0003, droop: a.tailLength * 0.015,
                                     shade: V2(0.55, 1), flipSide: s == .left, material: f.mat(.tail))
                rig.add(c, to: part, option: 1)
            }
        }
        // Solid core so the closed tail reads as one surface; the cards above give the feather edges.
        var core: [LoftSection] = []
        let side = simd_normalize(simd_cross(f.tailDir, nT))
        for i in 0..<8 {
            let t = Float(i) / 7
            let c = f.tailPivot + f.tailDir * (t * a.tailLength * 0.94) - nT * (0.0012 + a.tailLength * 0.015 * t * t)
            let hw = 0.5 * a.tailWidth * (0.55 + 0.35 * min(1, t * 1.6)) * (t > 0.92 ? 0.9 : 1)
            core.append(LoftSection(center: c, right: side, up: nT, halfWidth: hw, halfDorsal: max(0.0006, 0.004 * (1 - t)), halfVentral: max(0.0005, 0.003 * (1 - t)), exponent: 3))
        }
        rig.add(Loft.build(core, segments: 16, material: f.mat(.tailCore)), to: pitch)
    }

    static func addLeg(_ rig: inout Rig, _ f: BirdFrame, _ s: Side) {
        let a = f.a
        let hip = f.hip(s), ankle = f.ankle(s), foot = f.foot(s)
        // Thigh: feathered, in belly plumage, from the hip down to the ankle.
        let thighR = max(0.0035, a.tarsus * 0.2)
        let thigh = Loft.along([hip + V3(0, 0.004, 0), lerp(hip, ankle, 0.55), ankle + V3(0, 0.001, 0)], up: BirdFrame.Y, count: 6, segments: 12, vRange: 0.2...0.3,
                               material: f.mat(.body), radius: { t in let r = thighR * (1 - 0.7 * t); return V3(r, r, r) },
                               uv: { u, v in V2(0.5 + 0.12 * cos(u * 2 * .pi), v) })
        rig.add(thigh, to: BirdJoint.leg(s, .hip).name)
        // Tarsus.
        let tr = min(0.002, max(0.0007, a.tarsus * 0.045))
        let tars = Prim.tube([ankle, lerp(ankle, foot, 0.5), foot + V3(0, 0.001, 0)], radii: [tr * 1.1, tr, tr * 1.1], sides: 6, seamTile: 0.03, material: f.mat(.leg))
        rig.add(tars, to: BirdJoint.leg(s, .ankle).name)
        // Toes: three forward, one back. Curl joints rotate them about the foot.
        let base = foot + V3(0, 0.001, 0)
        let tl = a.toeLength
        for k in 0..<3 {
            let yaw = radians(Float(k - 1) * 30)
            let dir = V3(sin(yaw) * s.sign, 0, -cos(yaw))
            let len = tl * (k == 1 ? 1.0 : 0.84)
            rig.add(toe(base, dir, len, tr * 0.8, f), to: BirdJoint.leg(s, .toes).name)
        }
        rig.add(toe(base, V3(0, 0, 1), tl * 0.8, tr * 0.8, f), to: BirdJoint.leg(s, .hallux).name)
    }

    /// One toe: three segments with a pointed claw, lying flat.
    static func toe(_ base: V3, _ dir: V3, _ len: Float, _ r: Float, _ f: BirdFrame) -> Surface {
        let pts = [base, base + dir * (len * 0.4), base + dir * (len * 0.75) + V3(0, -0.0002, 0), base + dir * len + V3(0, -0.0008, 0)]
        return Prim.tube(pts, radii: [r, r * 0.85, r * 0.7, r * 0.12], sides: 5, seamTile: 0.03, material: f.mat(.leg))
    }
}
