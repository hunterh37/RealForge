import simd
import Foundation
import RealCore

/// Shared geometry for the Surgical instruments: lofted bars with changing sections, finger rings,
/// plan-outline plates, screw heads and rig placement. Instruments are authored flat in the XZ plane
/// (long axis X, thickness Y) with the joint at the origin, then settled onto y = 0 and centered.
enum SurgKit {
    /// Rounded-rectangle section (superellipse) with `n` points, CCW, centered.
    static func section(_ w: Float, _ h: Float, n: Int, exponent: Float = 4) -> [V2] {
        (0..<n).map { k in
            let a = Float(k) / Float(n) * 2 * .pi + .pi / Float(n)
            let c = cos(a), s = sin(a)
            return V2(copysign(pow(abs(c), 2 / exponent), c) * w / 2, copysign(pow(abs(s), 2 / exponent), s) * h / 2)
        }
    }

    /// Lofts `section(t, i)` (2D points in the path frame: x = up x travel, which is -Z for travel along
    /// +X; y up) along a path. U runs along the path (grind lines follow the part), V around. Caps close
    /// open ends; normals are made outward by the enclosed volume sign.
    static func loft(_ path: [V3], closed: Bool = false, caps: Bool = true, material: MaterialKey,
                     section: (Float, Int) -> [V2]) -> Surface {
        let pts = closed ? path + [path[0]] : path
        var len: [Float] = [0]
        for i in 1..<pts.count { len.append(len[i - 1] + simd_distance(pts[i], pts[i - 1])) }
        let total = max(len.last!, 1e-6)
        var rings: [[V3]] = []
        for i in pts.indices {
            let a: V3, b: V3
            if closed {
                let m = path.count, j = i % m
                a = path[(j + m - 1) % m]; b = path[(j + 1) % m]
            } else { a = pts[max(0, i - 1)]; b = pts[min(pts.count - 1, i + 1)] }
            let t = simd_normalize(b - a)
            let left = simd_normalize(simd_cross(V3(0, 1, 0), t))   // +Z when travelling +X
            let up = simd_cross(t, left)
            rings.append(section(len[i] / total, i).map { pts[i] + left * $0.x + up * $0.y })
        }
        var s = Prim.loft(rings, capStart: caps && !closed, capEnd: caps && !closed, material: material)
        for i in s.uvs.indices { s.uvs[i] = V2(s.uvs[i].y, s.uvs[i].x) }
        if volume(s) < 0 { s = s.flipped() }
        s.computeTangents()
        return s
    }

    /// Bar with a rounded-rectangle section of width `w(t)` and height `h(t)`.
    static func bar(_ path: [V3], w: @escaping (Float) -> Float, h: @escaping (Float) -> Float, sides: Int = 10,
                    closed: Bool = false, exponent: Float = 4, material: MaterialKey) -> Surface {
        loft(path, closed: closed, material: material) { t, _ in section(w(t), h(t), n: sides, exponent: exponent) }
    }

    /// Finger ring: an oval bar loop of inner half-axes `rx` x `rz` around `c` (x, z) at height `y`.
    static func ring(_ c: V2, y: Float, rx: Float, rz: Float, wire: Float, thick: Float, segments: Int, sides: Int,
                     material: MaterialKey) -> Surface {
        let ax = rx + wire / 2, az = rz + wire / 2
        let path = (0..<segments).map { k -> V3 in
            let a = Float(k) / Float(segments) * 2 * .pi
            return V3(c.x + ax * cos(a), y, c.y + az * sin(a))
        }
        return bar(path, w: { _ in wire }, h: { _ in thick }, sides: sides, closed: true, material: material)
    }

    /// Point on a finger ring's wire centerline at angle `deg` (0 = +X, 90 = +Z).
    static func ringPoint(_ c: V2, y: Float, rx: Float, rz: Float, wire: Float, deg: Float) -> V3 {
        let a = deg * .pi / 180
        return V3(c.x + (rx + wire / 2) * cos(a), y, c.y + (rz + wire / 2) * sin(a))
    }

    /// Flat plate from a plan outline of (x, z) points, spanning y0...y1, beveled edges.
    static func plate(_ outline: [V2], y0: Float, y1: Float, bevel: Float, segments: Int = 1, material: MaterialKey) -> Surface {
        let s = Prim.extrude(outline.map { V2($0.x, -$0.y) }, depth: y1 - y0, bevel: bevel, bevelSegments: segments, material: material)
        return s.transformed(Xform(translation: V3(0, (y0 + y1) / 2, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(1, 0, 0))))
    }

    /// Side profile of (x, y) points extruded across Z from z0 to z1.
    static func profile(_ outline: [V2], z0: Float, z1: Float, bevel: Float, segments: Int = 1, material: MaterialKey) -> Surface {
        let s = Prim.extrude(outline, depth: z1 - z0, bevel: bevel, bevelSegments: segments, material: material)
        return s.transformed(Xform(translation: V3(0, 0, (z0 + z1) / 2)))
    }

    /// Cross-section of (z, y) points extruded along X from x0 to x1.
    static func crossProfile(_ outline: [V2], x0: Float, x1: Float, bevel: Float, segments: Int = 1, material: MaterialKey) -> Surface {
        let s = Prim.extrude(outline.map { V2(-$0.x, $0.y) }, depth: x1 - x0, bevel: bevel, bevelSegments: segments, material: material)
        return s.transformed(Xform(translation: V3((x0 + x1) / 2, 0, 0), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 1, 0))))
    }

    /// Ratchet tab of a box-lock instrument at x0...x1: a half-thickness bridge from the shank (at `zShank`)
    /// across the center line to `zIn`, with `teeth` sawtooth teeth on its inner face. The upper tab is
    /// built for the member whose shank is at +Z; the lower tab is its point reflection about (0, yc),
    /// so the two mesh at rest and again after every whole pitch of relative travel along Z.
    static func ratchetTab(upper: Bool, x0: Float, x1: Float, zShank: Float, zIn: Float, yc: Float, h: Float,
                           pitch p: Float, depth d: Float, teeth: Int, material: MaterialKey) -> Surface {
        let y0 = yc - h / 2 + 0.0002, y1 = yc + h / 2 - 0.0001
        func mesh(_ z: Float) -> Float { yc + d * (saw(z + 0.36 * p, pitch: p) - 0.5) + 0.00003 }
        var o: [V2] = [V2(zShank, y1), V2(zIn, y1)]
        let zEnd = zIn + Float(teeth) * p
        var breaks: [Float] = [zIn, zEnd]
        var k = floor(zIn / p) - 1
        while k * p < zEnd + p {
            for z in [k * p - 0.36 * p, k * p + 0.36 * p] where z > zIn + 1e-5 && z < zEnd - 1e-5 { breaks.append(z) }
            k += 1
        }
        for z in breaks.sorted() { o.append(V2(z, mesh(z))) }
        o.append(V2(zEnd + 0.0002, yc + d / 2 + 0.00003))
        o.append(V2(zEnd + 0.0004, y0))
        o.append(V2(zShank, y0))
        o = Shape2D.deduped(o)
        if !upper { o = o.map { V2(-$0.x, 2 * yc - $0.y) } }
        return crossProfile(o, x0: x0, x1: x1, bevel: 0.00015, material: material)
    }

    /// Screw head: low dome of radius `r` and height `h` on a plane at `y`, facing +Y (or -Y), with an
    /// optional driver slot along `slotDir` degrees.
    static func screwHead(at p: V3, r: Float, h: Float, down: Bool = false, segments: Int = 16, material: MaterialKey) -> Surface {
        var prof: [V2] = [V2(0, 0), V2(r, 0), V2(r, h * 0.35)]
        for k in 1...3 { let a = Float(k) / 3 * .pi / 2; prof.append(V2(r * cos(a) * 0.92 + 0.0001, h * 0.35 + h * 0.65 * sin(a))) }
        prof.append(V2(0, h))
        var s = Prim.lathe(prof, segments: segments, seamTile: 0.01, material: material)
        if down { s = s.transformed(Xform(rotation: simd_quatf(angle: .pi, axis: V3(1, 0, 0)))) }
        return s.transformed(Xform(translation: p))
    }

    /// Catmull-Rom path through plan points (x, z) at heights `y`.
    static func path(_ p: [V3], per: Int) -> [V3] { catmullPath(p, per: per) }

    static func catmullPath(_ p: [V3], per: Int) -> [V3] {
        guard p.count > 2 else {
            return (0...per).map { lerp(p[0], p[1], Float($0) / Float(per)) }
        }
        var out: [V3] = []
        for i in 0..<(p.count - 1) {
            let p0 = p[max(0, i - 1)], p1 = p[i], p2 = p[i + 1], p3 = p[min(p.count - 1, i + 2)]
            for k in 0..<per {
                let t = Float(k) / Float(per), t2 = t * t, t3 = t2 * t
                let a: V3 = 2 * p1, b: V3 = p2 - p0
                let c: V3 = 2 * p0 - 5 * p1 + 4 * p2 - p3
                let d: V3 = 3 * p1 - 3 * p2 + p3 - p0
                let q: V3 = a + b * t + c * t2 + d * t3
                out.append(q * 0.5)
            }
        }
        out.append(p.last!)
        return out
    }

    /// The part of a polyline between x0 and x1 (x0 < x1), resampled to `n` points by x.
    static func span(_ path: [V3], x0: Float, x1: Float, n: Int) -> [V3] {
        func at(_ x: Float) -> V3 {
            for i in 1..<path.count {
                let a = path[i - 1], b = path[i]
                if (x - a.x) * (x - b.x) <= 0 && a.x != b.x { return lerp(a, b, (x - a.x) / (b.x - a.x)) }
            }
            return abs(path[0].x - x) < abs(path.last!.x - x) ? path[0] : path.last!
        }
        return (0..<n).map { at(x0 + (x1 - x0) * Float($0) / Float(n - 1)) }
    }

    /// Signed enclosed volume (positive = outward winding).
    static func volume(_ s: Surface) -> Float {
        var v: Float = 0
        for t in stride(from: 0, to: s.indices.count, by: 3) {
            let a = s.positions[Int(s.indices[t])], b = s.positions[Int(s.indices[t + 1])], c = s.positions[Int(s.indices[t + 2])]
            v += simd_dot(a, simd_cross(b, c)) / 6
        }
        return v
    }

    /// Applies a rigid transform to every piece of a rig (geometry, pivots, lights).
    static func transform(_ rig: inout Rig, _ x: Xform) {
        rig.base = rig.base.map { $0.transformed(x) }
        for i in rig.parts.indices {
            rig.parts[i].levels = rig.parts[i].levels.map { $0.transformed(x) }
            rig.parts[i].alternates = rig.parts[i].alternates.map { $0.map { $0.transformed(x) } }
            rig.parts[i].pivot = rig.parts[i].pivot.then(x)
        }
        for i in rig.lights.indices {
            rig.lights[i].position = x.point(rig.lights[i].position)
            rig.lights[i].direction = x.direction(rig.lights[i].direction)
        }
    }

    /// Tilts (optional), then puts the default state's lowest point on y = 0 centered on X/Z, then
    /// bakes contact and cavity AO.
    static func settle(_ rig: inout Rig, tilt: Xform? = nil, aoHeight: Float = 0.004, aoFloor: Float = 0.62) {
        if let tilt { transform(&rig, tilt) }
        let b = rig.posed().levels[0].bounds
        transform(&rig, Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&rig, height: aoHeight, floor: aoFloor)
    }

    /// Asymmetric ratchet sawtooth: height in 0...1 at lateral position `u` for tooth pitch `p`.
    static func saw(_ u: Float, pitch p: Float) -> Float {
        let f = u / p - floor(u / p)
        return f < 0.72 ? f / 0.72 : 1 - (f - 0.72) / 0.28
    }
}

/// Box-lock ringed instrument (hemostat, needle holder): two coplanar members crossing at a box joint,
/// each a jaw ahead of the joint and a shank back to a finger ring, with interlocking ratchet tabs by the
/// rings. Member "a" has its ring at +Z and its jaw on the -Z side of the center line; member "b"
/// mirrors it and carries the female box and its flush screw heads. Both hinge about Y through the
/// box screw, "b" mimicking "a" at ratio -1, so the instrument opens symmetrically.
struct BoxLockInstrument {
    /// Member thickness (Y) of shanks and rings.
    var h: Float = 0.0034
    /// Ring inner half-axes and wire.
    var ringInner = V2(0.0102, 0.0088)
    var wire: Float = 0.0034
    /// Ring center (x, |z|).
    var ringC = V2(-0.0863, 0.0136)
    /// Shank plan control points for member "a" between the box and the ring (x, z).
    var shankCtrl: [V2] = [V2(-0.02, 0.0012), V2(-0.045, 0.003), V2(-0.062, 0.0045)]
    /// Shank width at the box and at the ring.
    var shankW = V2(0.0046, 0.0035)
    /// Angle on the ring (degrees from +X toward +Z for member a, mirrored for b) where the shank joins.
    var ringJoin: Float = -50
    /// Ratchet: center x, tab length, pitch, depth, teeth.
    var ratchetX: Float = -0.0625
    var ratchetLen: Float = 0.0055
    var pitch: Float = 0.0013
    var toothDepth: Float = 0.0007
    var teeth = 3
    /// Box (x length, z width) and its cheek overhang above/below the members.
    var box = V2(0.0108, 0.0070)
    var boxCheek: Float = 0.0006
    var body: MaterialKey = "metal.surgical"
    var ringMaterial: MaterialKey = "metal.surgical"
    /// ID tape color on member b (0 = none).
    var tape: UInt32 = 0
    var tapeX: Float = -0.05

    var yc: Float { h / 2 + boxCheek + 0.0002 }

    /// Relative opening (degrees between the members) at which the ratchet re-engages `clicks` teeth back.
    func clickAngle(_ clicks: Int) -> Float { Float(clicks) * pitch / abs(ratchetX) * 180 / .pi }

    /// Adds both members to a fresh rig ("a" driving, "b" mimic). `jaw(side, lod)` returns the jaw
    /// surfaces for a member (side +1 = a, -1 = b) in asset space at rest.
    func rig(name: String, halfOpen: Float, switchDistance: Float, seed: UInt64,
             jaw: (Float, Int) -> [Surface]) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: name, lods: 2, switchDistances: [switchDistance])
        rig.part("a", pivot: .zero, joint: .hinge(axis: V3(0, 1, 0), 0...halfOpen, duration: 0.45))
        rig.part("b", pivot: .zero, joint: Joint(.revolute, axis: V3(0, 1, 0), range: -halfOpen...0, duration: 0.45, mimic: .init("a", ratio: -1)))
        let yc = self.yc
        for l in 0..<2 {
            for side: Float in [1, -1] {
                let part = side > 0 ? "a" : "b"
                let c = V2(ringC.x, side * ringC.y)
                let ring = SurgKit.ring(c, y: yc, rx: ringInner.x, rz: ringInner.y, wire: wire, thick: h,
                                        segments: l == 0 ? 28 : 14, sides: l == 0 ? 8 : 6, material: ringMaterial)
                rig.add(ring, to: part, lods: l...l)
                let end = SurgKit.ringPoint(c, y: yc, rx: ringInner.x, rz: ringInner.y, wire: wire, deg: side * ringJoin)
                let ctrl = [V3(0.001, yc, 0)] + shankCtrl.map { V3($0.x, yc, side * $0.y) } + [end]
                let sp = SurgKit.catmullPath(ctrl, per: l == 0 ? 6 : 3)
                let sw = shankW
                rig.add(SurgKit.bar(sp, w: { t in sw.x + (sw.y - sw.x) * t }, h: { _ in self.h }, sides: l == 0 ? 8 : 6, material: body), to: part, lods: l...l)
                // Ratchet tab on the inner side of the shank by the ring.
                let zs = abs(SurgKit.span(sp, x0: ratchetX, x1: ratchetX + 0.0001, n: 2)[0].z)
                let zIn = -(Float(teeth) * pitch / 2 + 0.0002)
                if l == 0 {
                    rig.add(SurgKit.ratchetTab(upper: side > 0, x0: ratchetX - ratchetLen / 2, x1: ratchetX + ratchetLen / 2, zShank: zs,
                                               zIn: zIn, yc: yc, h: h, pitch: pitch, depth: toothDepth, teeth: teeth + 1, material: body),
                            to: part, lods: 0...0)
                } else {
                    let t = SurgKit.plate([V2(ratchetX - ratchetLen / 2, side * zs), V2(ratchetX + ratchetLen / 2, side * zs),
                                           V2(ratchetX + ratchetLen / 2, side * zIn), V2(ratchetX - ratchetLen / 2, side * zIn)],
                                          y0: side > 0 ? yc : yc - h / 2 + 0.0002, y1: side > 0 ? yc + h / 2 - 0.0001 : yc, bevel: 0.0002, material: body)
                    rig.add(t, to: part, lods: 1...1)
                }
                for s in jaw(side, l) { rig.add(s, to: part, lods: l...l) }
                if side < 0 {
                    // Female box with flush screw heads, top and bottom.
                    rig.add(Prim.roundedBox(V3(box.x, h + 2 * boxCheek, box.y), radius: 0.0011, bevelSegments: l == 0 ? 2 : 1, material: body),
                            Xform(translation: V3(0, yc, 0)), to: part, lods: l...l)
                    if l == 0 {
                        for up: Float in [1, -1] {
                            rig.add(SurgKit.screwHead(at: V3(0, yc + up * (h / 2 + boxCheek - 0.0001), 0), r: 0.0021, h: 0.00028, down: up < 0, segments: 14, material: body),
                                    to: part, lods: 0...0)
                        }
                        if tape != 0 {
                            let seg = SurgKit.span(sp, x0: tapeX - 0.0035, x1: tapeX + 0.0035, n: 4)
                            let band = SurgKit.bar(seg, w: { _ in sw.x + (sw.y - sw.x) * 0.6 + 0.0005 }, h: { _ in self.h + 0.0002 }, sides: 10,
                                                   material: "plastic.gloss:" + String(format: "%06X", tape))
                            rig.add(band, Xform(translation: V3(0, 0, 0)).jittered(&rng, deg: 0.3, offset: 0.00004), to: part, lods: 0...0)
                        }
                    }
                }
            }
        }
        return rig
    }
}
