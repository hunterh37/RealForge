import Foundation
import simd
import RealCore

/// A built ground animal: rig plus the numbers the behavior and driver code need.
public struct GroundRig: Sendable {
    public var profile: GroundProfile
    public var rig: Rig
    public var joints: [BirdJointSpec]
    /// Body center above the feet when standing.
    public var comHeight: Float
    public var triangleCount: Int { rig.base[0].triangleCount + rig.parts.reduce(0) { $0 + $1.levels[0].triangleCount } }
}

struct GroundFrame {
    let p: GroundProfile
    let a: GroundAnatomy
    let id: String
    /// Body axis (toward the head, pointing down by `pitch`), dorsal axis, center.
    let A: V3, U: V3, C: V3
    let psi: Float

    init(_ p: GroundProfile) {
        self.p = p; a = p.anatomy; id = p.species.rawValue
        psi = radians(a.pitch)
        A = V3(0, -sin(psi), -cos(psi)); U = V3(0, cos(psi), -sin(psi))
        C = V3(0, a.standHeight, 0)
    }

    func mat(_ r: FaunaMaterials.GroundRegion) -> MaterialKey { FaunaMaterials.key(id, r) }
    static let X = V3(1, 0, 0), Y = V3(0, 1, 0), Z = V3(0, 0, 1)

    var bodyProfile: Profile {
        a.pitch > 10 && p.species == .easternCottontail
            ? Profile([V2(0, 0.7), V2(0.18, 1.05), V2(0.4, 1.0), V2(0.62, 0.86), V2(0.82, 0.68), V2(1, 0.52)])
            : Profile([V2(0, 0.55), V2(0.18, 0.88), V2(0.4, 1.0), V2(0.62, 0.96), V2(0.82, 0.8), V2(1, 0.6)])
    }

    func shoulder(_ l: GroundJoint.Leg) -> V3 { C + A * (0.34 * a.bodyLength) - U * (0.26 * a.bodyDepth) + V3(l.side.sign * 0.34 * a.bodyWidth, 0, 0) }
    func hip(_ l: GroundJoint.Leg) -> V3 { C - A * (0.34 * a.bodyLength) - U * (0.2 * a.bodyDepth) + V3(l.side.sign * 0.36 * a.bodyWidth, 0, 0) }
    var neckPivot: V3 { C + A * (0.46 * a.bodyLength) + U * (0.12 * a.bodyDepth) }
    var headCenter: V3 { neckPivot + V3(0, 0.25 * a.headHeight, -0.5 * a.headLength + 0.02) }
    var rump: V3 { C - A * (0.5 * a.bodyLength) + U * (0.1 * a.bodyDepth) }
}

public enum GroundRigBuilder {
    /// Two-bone IK in the sagittal plane (coordinates are (z, y)). Returns the middle joint.
    static func twoBone(hip: V2, foot: V2, l1: Float, l2: Float, forward: Bool) -> V2 {
        let d0 = foot - hip
        let dist = max(1e-4, min(simd_length(d0), l1 + l2 - 1e-4))
        let dir = d0 / simd_length(d0)
        let a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
        let h = max(0, l1 * l1 - a * a).squareRoot()
        let base = hip + dir * a
        let perp = V2(-dir.y, dir.x)
        let k1 = base + perp * h, k2 = base - perp * h
        // Forward means smaller z.
        return (k1.x < k2.x) == forward ? k1 : k2
    }

    public static func build(_ p: GroundProfile, seed: UInt64 = 1) -> GroundRig {
        let f = GroundFrame(p)
        let a = f.a
        var rig = Rig(name: p.species.rawValue, lods: 1, switchDistances: [])
        var specs = [BirdJointSpec?](repeating: nil, count: GroundJoint.count)

        func declare(_ j: GroundJoint, parent: GroundJoint?, pivot: V3, axis: V3) {
            let ax = simd_normalize(axis)
            rig.part(j.name, parent: parent?.name, pivot: pivot, joint: Joint(.revolute, axis: ax, range: j.range, duration: 0.4))
            specs[j.index] = BirdJointSpec(name: j.name, parent: parent?.index, pivot: pivot, axis: ax, range: j.range, mimic: nil)
        }

        // Legs first so the leg geometry is known; chain endpoints.
        struct Chain { var hip: V3, knee: V3, ankle: V3, toe: V3 }
        var chains: [GroundJoint.Leg: Chain] = [:]
        for l in GroundJoint.Leg.allCases {
            let hip = l.isFore ? f.shoulder(l) : f.hip(l)
            let total = l.isFore ? a.foreLeg : a.hindLeg
            let l1 = total * (l.isFore ? 0.52 : 0.5), l2 = total * (l.isFore ? 0.48 : 0.5)
            let footLen = l.isFore ? total * 0.22 : total * 0.42
            let groundY: Float = a.legRadius * 0.8
            let ankleTarget = V2(hip.z + (l.isFore ? -0.015 : 0.03), groundY + (l.isFore ? 0 : a.legRadius * 0.6))
            let knee = twoBone(hip: V2(hip.z, hip.y), foot: ankleTarget, l1: l1, l2: l2, forward: !l.isFore)
            let k = V3(hip.x, knee.y, knee.x), an = V3(hip.x, ankleTarget.y, ankleTarget.x)
            chains[l] = Chain(hip: hip, knee: k, ankle: an, toe: an + V3(0, -a.legRadius * 0.2, -footLen))
        }

        declare(.spine, parent: nil, pivot: f.C, axis: GroundFrame.X)
        declare(.tailYaw, parent: .spine, pivot: f.rump, axis: GroundFrame.Y)
        let tl = a.tailLength
        let tailSeg = tl / 3
        // Tail rest path: out from the rump, curling up for squirrels and chipmunks.
        let curl: Float = p.species == .easternGraySquirrel ? 1 : (p.species == .easternChipmunk ? 0.75 : 0)
        func tailPoint(_ i: Int) -> V3 {
            var pos = f.rump
            var ang = radians(-8 + (a.pitch))
            for k in 0..<i {
                ang += radians(24) * curl * (k == 0 ? 0.4 : 1)
                // Direction: rearward (+z) rotating up by `ang`.
                pos += V3(0, sin(ang), cos(ang)) * tailSeg
            }
            return pos
        }
        declare(.tail0, parent: .tailYaw, pivot: tailPoint(0), axis: GroundFrame.X)
        declare(.tail1, parent: .tail0, pivot: tailPoint(1), axis: GroundFrame.X)
        declare(.tail2, parent: .tail1, pivot: tailPoint(2), axis: GroundFrame.X)

        declare(.neckPitch, parent: nil, pivot: f.neckPivot, axis: GroundFrame.X)
        let headPivot = f.headCenter + V3(0, -0.1 * a.headHeight, 0.4 * a.headLength)
        declare(.headYaw, parent: .neckPitch, pivot: headPivot, axis: GroundFrame.Y)
        declare(.headPitch, parent: .headYaw, pivot: headPivot, axis: GroundFrame.X)
        let gape = f.headCenter + V3(0, -0.28 * a.headHeight, -0.15 * a.headLength)
        declare(.jaw, parent: .headPitch, pivot: gape, axis: -GroundFrame.X)
        let earBase: (Side) -> V3 = { s in f.headCenter + V3(s.sign * 0.26 * a.headWidth, 0.2 * a.headHeight, 0.16 * a.headLength) }
        declare(.earL, parent: .headPitch, pivot: earBase(.left), axis: GroundFrame.X)
        declare(.earR, parent: .headPitch, pivot: earBase(.right), axis: GroundFrame.X)
        let noseTip = f.headCenter + V3(0, -0.04 * a.headHeight, -0.5 * a.headLength)
        declare(.nose, parent: .headPitch, pivot: noseTip, axis: GroundFrame.X)
        let eyeAt: (Side) -> V3 = { s in f.headCenter + V3(s.sign * 0.5 * a.headWidth * 0.8, 0.12 * a.headHeight, -0.12 * a.headLength) }
        declare(.lidL, parent: .headPitch, pivot: eyeAt(.left), axis: V3(0, 0, -1))
        declare(.lidR, parent: .headPitch, pivot: eyeAt(.right), axis: V3(0, 0, 1))
        for l in GroundJoint.Leg.allCases {
            let c = chains[l]!
            let parent: GroundJoint = l.isFore ? .neckPitch : .spine
            _ = parent
            // Fore legs hang from the chest (base, via no parent), hind legs from the spine part.
            declare(.leg(l, .hip), parent: l.isFore ? nil : .spine, pivot: c.hip, axis: GroundFrame.X)
            declare(.leg(l, .knee), parent: .leg(l, .hip), pivot: c.knee, axis: GroundFrame.X)
            declare(.leg(l, .ankle), parent: .leg(l, .knee), pivot: c.ankle, axis: GroundFrame.X)
        }
        precondition(specs.allSatisfy { $0 != nil })

        // Body: chest in the base, rump in the spine part, both from one profile and one atlas.
        let bp = f.bodyProfile
        let fur = f.mat(.body)
        func section(_ t: Float) -> LoftSection {
            let r = bp(t)
            let c = f.C + f.A * ((t - 0.5) * a.bodyLength)
            let depthK: Float = p.species == .europeanHedgehog ? 1.0 : 1
            return LoftSection(center: c, right: GroundFrame.X, up: f.U, halfWidth: 0.5 * a.bodyWidth * r, halfDorsal: 0.5 * a.bodyDepth * 1.0 * r * depthK,
                               halfVentral: 0.5 * a.bodyDepth * 0.9 * r, exponent: 2.2)
        }
        func lofted(_ t0: Float, _ t1: Float, _ n: Int, material: MaterialKey, uv: ((Float, Float) -> V2)? = nil) -> Surface {
            let secs = (0..<n).map { section(t0 + (t1 - t0) * Float($0) / Float(n - 1)) }
            return Loft.build(secs, segments: 20, vRange: t0...t1, material: material, uv: uv)
        }
        if a.spines {
            // Hedgehog: spine dome over the back, fur belly.
            func dome(_ t0: Float, _ t1: Float) -> Surface {
                let secs = (0..<7).map { i -> LoftSection in
                    var s = section(t0 + (t1 - t0) * Float(i) / 6)
                    s.halfDorsal *= 1.9; s.halfWidth *= 1.06; s.halfVentral *= 0.8
                    s.center += f.U * (0.18 * a.bodyDepth)
                    return s
                }
                let circ = 2 * Float.pi * 0.5 * (a.bodyWidth + a.bodyDepth) / 2
                return Loft.build(secs, segments: 24, vRange: t0...t1, material: f.mat(.quill)) { u, v in V2(u * circ, v * a.bodyLength) }
            }
            rig.base[0].add(lofted(0.46, 1, 6, material: fur))
            rig.add(lofted(0, 0.54, 6, material: fur), to: GroundJoint.spine.name)
            rig.base[0].add(dome(0.5, 1.02))
            rig.add(dome(-0.02, 0.52), to: GroundJoint.spine.name)
        } else {
            rig.base[0].add(lofted(0.46, 1, 6, material: fur))
            rig.add(lofted(0, 0.54, 6, material: fur), to: GroundJoint.spine.name)
        }

        // Neck and head.
        let hc = f.headCenter, hl = a.headLength
        let neckEnd = hc + V3(0, -0.1 * a.headHeight, 0.3 * hl)
        let neck = Loft.along([f.neckPivot - f.A * 0.02, neckEnd], up: GroundFrame.Y, count: 4, segments: 16, vRange: 0.9...1.0, material: fur) { t in
            let r = lerp(0.5 * a.bodyWidth * 0.55, 0.5 * a.headWidth * 0.95, t); return V3(r, r, r)
        }
        rig.add(neck, to: GroundJoint.neckPitch.name)
        let hp = Profile([V2(0, 0.8), V2(0.2, 1.0), V2(0.45, 0.92), V2(0.7, 0.6), V2(0.9, 0.3), V2(1, 0.14)])
        var hs: [LoftSection] = []
        for i in 0..<9 {
            let t = Float(i) / 8
            let c = hc + V3(0, -0.12 * a.headHeight * t * t, (0.5 - t) * hl)
            let r = hp(t)
            hs.append(LoftSection(center: c, right: GroundFrame.X, up: GroundFrame.Y, halfWidth: 0.5 * a.headWidth * r,
                                  halfDorsal: 0.5 * a.headHeight * 0.55 * r, halfVentral: 0.5 * a.headHeight * 0.45 * r, exponent: 2.2))
        }
        rig.add(Loft.build(hs, segments: 18, material: f.mat(.head)), to: GroundJoint.headPitch.name)
        // Lower jaw.
        let jawLoft = Loft.ellipsoid(center: gape + V3(0, 0.0, -0.18 * hl), axis: V3(0, 0, -1), up: GroundFrame.Y,
                                     radii: V3(0.2 * a.headWidth, 0.07 * a.headHeight, 0.26 * hl), rings: 6, segments: 10, material: f.mat(.head), uv: { u, v in V2(0.5 + 0.1 * cos(u * 2 * .pi), 0.8) })
        rig.add(jawLoft, to: GroundJoint.jaw.name)
        // Nose, eyes, lids.
        rig.add(Prim.cubeSphere(subdivisions: 3, material: f.mat(.nose)) { $0 * (0.1 * a.headWidth) }, Xform(translation: noseTip + V3(0, 0, 0.004)), to: GroundJoint.headPitch.name)
        for s in Side.allCases {
            let c = eyeAt(s)
            rig.add(Prim.cubeSphere(subdivisions: 3, material: f.mat(.eye)) { $0 * a.eyeRadius }, Xform(translation: c), to: GroundJoint.headPitch.name)
            let face = simd_quatf(angle: -s.sign * .pi / 2, axis: GroundFrame.Z)
            var prof: [V2] = []
            let R = a.eyeRadius * 1.2
            for k in 0...5 { let al = Float(k) / 5 * radians(78); prof.append(V2(R * sin(al), R * cos(al))) }
            rig.add(Prim.lathe(prof, segments: 14, seamTile: 0.02, material: f.mat(.head)), Xform(translation: c, rotation: face),
                    to: s == .left ? GroundJoint.lidL.name : GroundJoint.lidR.name)
        }
        // Ears: flattened shells, inner skin and outer fur.
        for s in Side.allCases {
            let base = earBase(s)
            let dir = simd_normalize(V3(s.sign * (p.species == .easternCottontail ? 0.18 : 0.5), 1, p.species == .easternCottontail ? 0.25 : 0.1))
            let len = a.earLength
            let center = base + dir * (len * 0.45)
            let side = simd_normalize(simd_cross(dir, V3(0, 0, 1)))
            let normal = simd_normalize(simd_cross(side, dir))
            let outer = Loft.ellipsoid(center: center - normal * 0.0008, axis: dir, up: normal, radii: V3(a.earWidth * 0.5, 0.0022, len * 0.5), rings: 7, segments: 10, material: f.mat(.head),
                                       uv: { u, v in V2(0.22 + 0.1 * cos(u * 2 * .pi), 0.5 + 0.1 * v) })
            let inner = Loft.ellipsoid(center: center + normal * 0.0012, axis: dir, up: normal, radii: V3(a.earWidth * 0.42, 0.0016, len * 0.44), rings: 7, segments: 10, material: f.mat(.ear))
            let part = s == .left ? GroundJoint.earL.name : GroundJoint.earR.name
            rig.add(outer, to: part); rig.add(inner, to: part)
        }
        // Whiskers.
        if a.whiskers {
            let r = 0.0004 + a.headLength * 0.003
            for s in Side.allCases { for k in 0..<4 {
                let y = (Float(k) - 1.5) * 0.004 * a.headHeight / 0.05
                let start = noseTip + V3(s.sign * 0.1 * a.headWidth, 0.1 * a.headHeight * 0.3 + y, 0.2 * hl)
                let len = a.headLength * (0.8 - 0.08 * Float(k))
                let ang = radians(25 + 12 * Float(k))
                let d = V3(s.sign * sin(ang), 0.1 - 0.1 * Float(k), cos(ang) * 0.5 + 0.35)
                let dn = simd_normalize(d)
                let pts = [start, start + dn * (len * 0.5) + V3(0, 0.002, 0), start + dn * len + V3(0, -0.004, 0.004)]
                rig.add(Prim.tube(pts, radii: [r, r * 0.7, r * 0.3], sides: 3, seamTile: 0.02, material: f.mat(.whisker)), to: GroundJoint.headPitch.name)
            }}
        }

        // Tail segments.
        func tailMaterial() -> MaterialKey { f.mat(.tail) }
        let tw = a.tailWidth
        for i in 0..<3 {
            let p0 = tailPoint(i), p1 = tailPoint(i + 1)
            let t0 = Float(i) / 3, t1 = Float(i + 1) / 3
            let wTail: (Float) -> Float = { t in
                switch p.species {
                case .easternGraySquirrel: return tw * 0.5 * (0.55 + 0.5 * sin(.pi * min(1, t * 1.15)) + 0.1)
                case .easternChipmunk: return tw * 0.5 * (0.8 - 0.4 * t)
                case .easternCottontail: return tw * 0.5 * sin(.pi * max(0.15, 1 - t * 0.8) * 0.9)
                default: return tw * 0.5 * (1 - 0.5 * t)
                }
            }
            let pm = lerp(p0, p1, 0.5) + V3(0, curl * tailSeg * 0.07, 0)
            let seg = Loft.along([p0 - (p1 - p0) * 0.1, pm, p1 + (p1 - p0) * 0.06], up: GroundFrame.Y, count: 5, segments: 14, vRange: t0...t1, exponent: 2, material: tailMaterial()) { t in
                let r = wTail(lerp(t0, t1, t)); return V3(r, r * (p.species == .easternGraySquirrel ? 0.8 : 1), r * (p.species == .easternGraySquirrel ? 0.8 : 1))
            }
            let partName = [GroundJoint.tail0, .tail1, .tail2][i].name
            rig.add(seg, to: partName)
        }
        if p.species == .easternCottontail {
            // Pom-pom: replace segmented tail look with a ball.
            rig.add(Prim.cubeSphere(subdivisions: 4, material: tailMaterial()) { $0 * (a.tailWidth * 0.5) }, Xform(translation: f.rump + V3(0, 0.01, 0.02)), to: GroundJoint.tail0.name)
        }

        // Legs.
        let legU = max(0.1, p.palette.flankLine * 0.5 * 0.6)
        for l in GroundJoint.Leg.allCases {
            let c = chains[l]!
            let r = a.legRadius
            let thighR = l.isFore ? r * 1.4 : r * 2.0
            func leg(_ pts: [V3], _ radii: [Float], vr: ClosedRange<Float>) -> Surface {
                Loft.along(pts, up: GroundFrame.X, count: 5, segments: 10, vRange: vr, exponent: 2, material: fur, radius: { t in
                    let r = lerp(radii[0], radii[1], t); return V3(r, r, r)
                }, uv: { u, v in V2(legU + 0.05 * cos(u * 2 * .pi), 0.3 + 0.3 * v) })
            }
            rig.add(leg([c.hip + V3(0, 0.004, 0), c.knee], [thighR, r * 1.05], vr: 0...0.5), to: GroundJoint.leg(l, .hip).name)
            rig.add(leg([c.knee, c.ankle], [r * 1.05, r * 0.8], vr: 0.5...1), to: GroundJoint.leg(l, .knee).name)
            rig.add(leg([c.ankle, c.toe], [r * 0.85, r * 0.9], vr: 0.5...1), to: GroundJoint.leg(l, .ankle).name)
            // Paw and claws.
            rig.add(Loft.ellipsoid(center: c.toe + V3(0, 0, 0.004), axis: V3(0, 0, -1), up: GroundFrame.Y, radii: V3(r * 1.1, r * 0.7, r * 1.7), rings: 5, segments: 8, material: fur,
                                   uv: { u, v in V2(legU + 0.04 * cos(u * 2 * .pi), 0.45) }), to: GroundJoint.leg(l, .ankle).name)
            for k in -1...1 {
                let cl = c.toe + V3(Float(k) * r * 0.7, -r * 0.3, -r * 1.4)
                rig.add(Prim.tube([cl, cl + V3(0, -0.0006, -r * 1.6)], radii: [r * 0.22, r * 0.05], sides: 3, seamTile: 0.01, material: f.mat(.claw)), to: GroundJoint.leg(l, .ankle).name)
            }
        }

        rig.states = [RigState("stand", GroundPoses.stand(p).named), RigState("sit", GroundPoses.sit(p).named)]
        rig.defaultState = "stand"
        return GroundRig(profile: p, rig: rig, joints: specs.map { $0! }, comHeight: a.standHeight)
    }
}

extension GroundPose {
    var named: [String: Float] {
        var d: [String: Float] = [:]
        for j in GroundJoint.all { d[j.name] = values[j.index] }
        return d
    }
}
