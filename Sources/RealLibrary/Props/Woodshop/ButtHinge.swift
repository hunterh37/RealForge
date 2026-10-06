import simd
import Foundation

/// 3 x 3 in residential steel butt hinge with a removable button-tip pin, lying open on its back.
/// Real specs: two 76.2 mm (3 in) x 38.1 mm leaves of 2.2 mm (0.087 in) cold-rolled steel with 1/4 in
/// radius outer corners; 5-knuckle barrel 11 mm OD (fixed leaf carries knuckles 1, 3 and 5, the moving
/// leaf 2 and 4) on a 3.3 mm (0.13 in) steel pin with a domed button head and a press-fit button cap on
/// the bottom knuckle; three 82-degree countersunk holes per leaf for #9 screws (4.8 mm through hole,
/// 8.4 mm countersink, swaged), staggered 7/8 in and 1-1/16 in from the pin so screws miss a single grain
/// line. Satin nickel plate by default (`metal.screw-zinc` for zinc). Story detail: pine fibres caught in
/// one countersink from a test fit.
/// Frame: pin axis along Z at y = `knuckleRadius`; the fixed leaf lies on y = 0 toward -X. Joint `leaf`
/// swings the moving leaf about the pin, 0 = closed on top of the fixed leaf, 180 = open flat toward +X.
/// Joint `pin` lifts the pin along +Z (0 = seated, 0.08 m = pulled clear).
public struct ButtHinge: RealArticulated {
    public static let id = "butt-hinge"
    public static let summary = "3 x 3 in steel butt hinge: two leaves with countersunk screw holes, 5-knuckle barrel, removable button-tip pin, satin nickel."
    public static let tags = ["prop", "workshop", "handheld", "articulated", "metal"]
    public static let budget = 6_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 38, distance: 0.24, studio: true)

    /// Leaf length along the pin (m); 3 in.
    public var length: Float = 0.0762
    /// Leaf width from the pin axis to the outer edge (m); 1-1/2 in (3 in open width).
    public var leafWidth: Float = 0.0381
    /// Leaf thickness (m); 0.087 in.
    public var thickness: Float = 0.0022
    /// Knuckle outer radius (m).
    public var knuckleRadius: Float = 0.0055
    /// Pin radius (m).
    public var pinRadius: Float = 0.00165
    /// Through-hole radius (m); #9 screw clearance.
    public var holeRadius: Float = 0.0024
    /// Countersink top radius (m).
    public var countersinkRadius: Float = 0.0042
    /// Outer corner radius (m); 1/4 in.
    public var cornerRadius: Float = 0.00635
    /// Plating: `metal.hinge-satin-nickel` or `metal.screw-zinc`.
    public var plate: MaterialKey = "metal.hinge-satin-nickel"
    /// Wood fibres in one countersink.
    public var fibres = true
    public init() {}

    /// Leaf joint range (degrees).
    public static let leafRange: ClosedRange<Float> = 0...180
    /// Pin pull travel (m).
    public static let pinTravel: Float = 0.08

    // MARK: public frame

    /// Point on the pin axis at the middle of the barrel (asset space).
    public var pinOrigin: V3 { V3(0, knuckleRadius, 0) }
    /// Unit pin axis, bottom knuckle toward the button head (asset space).
    public var pinDirection: V3 { V3(0, 0, 1) }
    /// Top of the pin's button head with the pin seated (asset space).
    public var pinHead: V3 { V3(0, knuckleRadius, length / 2 + 0.0032) }
    /// Hole centers in the fixed leaf's plane, (distance from the pin, position along the pin).
    public var holeLayout: [V2] { [V2(0.0222, -0.0254), V2(0.027, 0), V2(0.0222, 0.0254)] }
    /// Countersink centers on the fixed leaf's top face (asset space), screw direction -Y.
    public var fixedLeafHoles: [V3] { holeLayout.map { V3(-$0.x, thickness, $0.y) } }
    /// Countersink centers on the moving leaf at `angle` degrees (0 closed, 180 open flat), asset space.
    public func movingLeafHoles(angle: Float) -> [V3] {
        let x = movingLeafTransform(angle: angle)
        return holeLayout.map { x.point(V3(-$0.x, thickness, $0.y)) }
    }
    /// Screw direction into the moving leaf's mounting surface at `angle` degrees (asset space).
    public func movingLeafScrewAxis(angle: Float) -> V3 { movingLeafTransform(angle: angle).rotation.act(V3(0, -1, 0)) }

    /// Fixed-leaf space to the moving leaf at `angle`: mirrored over the pin (closed), then swung about it.
    func movingLeafTransform(angle: Float) -> Xform {
        let P = V3(0, knuckleRadius, 0)
        let swing = simd_quatf(angle: angle * .pi / 180, axis: V3(0, 0, -1))
        let closed = simd_quatf(angle: .pi, axis: V3(1, 0, 0))
        // closed maps p to (x, 2R - y, -z); the swing then turns about the pin line through P.
        return Xform(translation: swing.act(P) + P, rotation: swing * closed)
    }

    var knuckleGap: Float { 0.0003 }
    func knuckle(_ i: Int) -> ClosedRange<Float> {
        let kl = (length - 4 * knuckleGap) / 5
        let z0 = -length / 2 + Float(i) * (kl + knuckleGap)
        return z0...(z0 + kl)
    }

    // MARK: geometry

    /// One leaf plate in fixed-leaf space (toward -X, y 0...thickness): three cells, each a ring between the
    /// cell outline and the countersink, with the cone, bore, underside and outer walls.
    func leafPlate(n: Int) -> [Surface] {
        let W = leafWidth, R = knuckleRadius, L = length, t = thickness, rc = cornerRadius
        let csDepth = t - 0.0002
        var top = Surface(material: plate), bottom = Surface(material: plate), cone = Surface(material: plate), wall = Surface(material: plate)
        let bounds: [(Float, Float)] = [(-L / 2, -L / 6), (-L / 6, L / 6), (L / 6, L / 2)]
        let eps: Float = 1e-5
        for (ci, (z0, z1)) in bounds.enumerated() {
            let c = V2(-holeLayout[ci].x, holeLayout[ci].y)
            let x0 = -W, x1 = -R
            // Angles: uniform plus the four cell corners.
            var angles = (0..<n).map { Float($0) / Float(n) * 2 * .pi }
            for corner in [V2(x0, z0), V2(x1, z0), V2(x1, z1), V2(x0, z1)] {
                var a = atan2(corner.y - c.y, corner.x - c.x); if a < 0 { a += 2 * .pi }
                angles.append(a)
            }
            // Extra samples along the rounded outer corner in the end cells.
            if ci != 1 {
                let sz: Float = ci == 2 ? 1 : -1
                let cc = V2(x0 + rc, sz * (L / 2 - rc))
                let arcN = max(3, n / 4)
                for k in 0...arcN {
                    let phi = Float.pi / 2 * (sz > 0 ? 1 : 2) + Float(k) / Float(arcN) * .pi / 2
                    let q = cc + V2(cos(phi), sin(phi)) * rc
                    var aa = atan2(q.y - c.y, q.x - c.x); if aa < 0 { aa += 2 * .pi }
                    angles.append(aa)
                }
            }
            angles.sort()
            var outer: [V2] = [], onEdge: [Bool] = []
            for a in angles {
                let d = V2(cos(a), sin(a))
                var tt = Float.greatestFiniteMagnitude
                if d.x > 1e-6 { tt = min(tt, (x1 - c.x) / d.x) }
                if d.x < -1e-6 { tt = min(tt, (x0 - c.x) / d.x) }
                if d.y > 1e-6 { tt = min(tt, (z1 - c.y) / d.y) }
                if d.y < -1e-6 { tt = min(tt, (z0 - c.y) / d.y) }
                var p = c + d * tt
                var edge = abs(p.x - x0) < eps || abs(p.x - x1) < eps || abs(abs(p.y) - L / 2) < eps
                // Round the leaf's outer corners.
                if p.x < x0 + rc && abs(p.y) > L / 2 - rc {
                    let cc = V2(x0 + rc, (p.y > 0 ? 1 : -1) * (L / 2 - rc))
                    let v = p - cc
                    if simd_length(v) > rc { p = cc + simd_normalize(v) * rc; edge = true }
                }
                outer.append(p); onEdge.append(edge)
            }
            let m = outer.count
            let b0 = UInt32(top.positions.count), bb = UInt32(bottom.positions.count), cb = UInt32(cone.positions.count)
            for (k, a) in angles.enumerated() {
                let d = V2(cos(a), sin(a)), p = outer[k]
                let ics = c + d * countersinkRadius, ih = c + d * holeRadius
                top.add(V3(p.x, t, p.y), .up, V2(p.x, p.y)); top.add(V3(ics.x, t, ics.y), .up, V2(ics.x, ics.y))
                bottom.add(V3(p.x, 0, p.y), -.up, V2(p.x, p.y)); bottom.add(V3(ih.x, 0, ih.y), -.up, V2(ih.x, ih.y))
                let u = a * countersinkRadius
                cone.add(V3(ics.x, t, ics.y), .up, V2(u, 0)); cone.add(V3(ih.x, t - csDepth, ih.y), .up, V2(u, 0.002))
                cone.add(V3(ih.x, 0, ih.y), .up, V2(u, 0.0042))
            }
            for k in 0..<UInt32(m) {
                let k1 = (k + 1) % UInt32(m)
                top.quad(b0 + 2 * k, b0 + 2 * k1, b0 + 2 * k1 + 1, b0 + 2 * k + 1)
                bottom.quad(bb + 2 * k, bb + 2 * k + 1, bb + 2 * k1 + 1, bb + 2 * k1)
                cone.quad(cb + 3 * k, cb + 3 * k + 1, cb + 3 * k1 + 1, cb + 3 * k1)
                cone.quad(cb + 3 * k + 1, cb + 3 * k + 2, cb + 3 * k1 + 2, cb + 3 * k1 + 1)
                let ki = Int(k), kj = Int(k1)
                if onEdge[ki] && onEdge[kj] {
                    let mid = (outer[ki] + outer[kj]) / 2
                    let midEdge = abs(mid.x - x0) < 1e-4 || abs(mid.x - x1) < 1e-4 || abs(abs(mid.y) - L / 2) < 1e-4
                        || (mid.x < x0 + rc && abs(mid.y) > L / 2 - rc)
                    if midEdge {
                        let p0 = outer[ki], p1 = outer[kj]
                        let w0 = UInt32(wall.positions.count)
                        let along = simd_distance(p0, p1)
                        wall.add(V3(p0.x, 0, p0.y), .up, V2(0, 0)); wall.add(V3(p1.x, 0, p1.y), .up, V2(along, 0))
                        wall.add(V3(p1.x, t, p1.y), .up, V2(along, t)); wall.add(V3(p0.x, t, p0.y), .up, V2(0, t))
                        // Outward = away from the hole center.
                        let nrm = simd_normalize(simd_cross(V3(p1.x - p0.x, 0, p1.y - p0.y), V3(0, 1, 0)))
                        if simd_dot(V2(nrm.x, nrm.z), mid - c) > 0 { wall.quad(w0, w0 + 1, w0 + 2, w0 + 3) } else { wall.quad(w0, w0 + 3, w0 + 2, w0 + 1) }
                    }
                }
            }
        }
        var out: [Surface] = []
        for (var s, want) in [(top, V3(0, 1, 0)), (bottom, V3(0, -1, 0))] {
            s.recomputeNormals(weldSeams: false)
            if simd_dot(s.normals.reduce(.zero, +), want) < 0 { s = s.flipped() }
            s.computeTangents(); out.append(s)
        }
        // Cone and bore face the hole axis: flip if the normals point away from it.
        cone.recomputeNormals(weldSeams: false)
        if simd_dot(cone.normals[0], V3(0, 1, 0)) < 0 && simd_dot(cone.normals[1], V3(0, 1, 0)) < 0 { cone = cone.flipped() }
        cone.computeTangents(); out.append(cone)
        wall.recomputeNormals(weldSeams: false); wall.computeTangents(); out.append(wall)
        return out
    }

    /// Knuckle i as a tube about the pin axis (fixed-leaf space), with the leaf tab running into it.
    func knuckleTube(_ i: Int, segments: Int) -> [Surface] {
        let R = knuckleRadius, z = knuckle(i), len = z.upperBound - z.lowerBound, rb = pinRadius + 0.00005, e: Float = 0.00035
        let prof = [V2(rb, 0), V2(R - e, 0), V2(R - e * 0.3, e * 0.3), V2(R, e), V2(R, len - e), V2(R - e * 0.3, len - e * 0.3), V2(R - e, len), V2(rb, len)]
        let tube = Prim.lathe(prof, segments: segments, seamTile: 0.03, material: plate)
            .transformed(Xform(translation: V3(0, R, z.lowerBound), rotation: simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))))
        // Tab joining the leaf to the knuckle (inset 0.15 mm from the knuckle ends).
        let tab = Prim.roundedBox(V3(R + 0.0003, thickness, len - 0.0003), radius: 0.0004, bevelSegments: 1, material: plate)
            .transformed(Xform(translation: V3(-R / 2 - 0.00035, thickness / 2, (z.lowerBound + z.upperBound) / 2)))
        return [tube, tab]
    }

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [0.6])
        let R = knuckleRadius, L = length
        let toZ = simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))
        let closed = Xform(translation: V3(0, 2 * R, 0), rotation: simd_quatf(angle: .pi, axis: V3(1, 0, 0)))
        rig.part("leaf", pivot: V3(0, R, 0), joint: .hinge(axis: V3(0, 0, -1), Self.leafRange, duration: 0.6))
        rig.part("pin", pivot: V3(0, R, 0), joint: .slide(axis: V3(0, 0, 1), 0...Self.pinTravel, duration: 0.5))
        for l in 0..<2 {
            let n = l == 0 ? 28 : 12, sg = l == 0 ? 24 : 10
            var m = Model(name: Self.id)
            let plateSurfaces = leafPlate(n: n)
            for s in plateSurfaces { m.add(s) }
            for i in [0, 2, 4] { for s in knuckleTube(i, segments: sg) { m.add(s) } }
            // Button cap pressed into the bottom knuckle.
            let rbtn = R * 0.78
            m.add(Prim.lathe([V2(0, -0.0026), V2(rbtn * 0.55, -0.0024), V2(rbtn * 0.9, -0.0016), V2(rbtn, -0.0007), V2(rbtn, 0.0002)],
                             segments: sg, seamTile: 0.03, material: plate), Xform(translation: V3(0, R, -L / 2), rotation: toZ))
            if l == 0 && fibres {
                // Pine fibres caught in the fixed leaf's first countersink.
                let h = fixedLeafHoles[0]
                for k in 0..<3 {
                    let a0 = rng.float(0...6.28)
                    var path: [V3] = [], radii: [Float] = []
                    for j in 0...8 {
                        let a = a0 + Float(j) / 8 * rng.float(1.2...2.2)
                        let r = holeRadius + 0.0006 + 0.0003 * Float(k)
                        path.append(V3(h.x + r * cos(a), thickness - 0.0012 + 0.00035 * Float(k), h.z + r * sin(a)))
                        radii.append(0.00012 * sin(Float(j) / 8 * .pi) + 0.00003)
                    }
                    m.add(Prim.tube(path, radii: radii, sides: 4, seamTile: 0.01, material: "wood.sawdust", capEnd: false))
                }
            }
            rig.base[l] = m

            // Moving leaf: the fixed plate mirrored over the pin (closed), knuckles 2 and 4.
            for s in plateSurfaces { rig.add(s, closed, to: "leaf", lods: l...l) }
            for i in [1, 3] {
                for (j, s) in knuckleTube(i, segments: sg).enumerated() {
                    if j == 0 { rig.add(s, to: "leaf", lods: l...l) }
                    else {
                        // Tab mirrored to the closed side; z stays on its own knuckle.
                        let zc = (knuckle(i).lowerBound + knuckle(i).upperBound) / 2
                        rig.add(s, Xform(translation: V3(0, 2 * R, 2 * zc), rotation: simd_quatf(angle: .pi, axis: V3(1, 0, 0))), to: "leaf", lods: l...l)
                    }
                }
            }

            // Pin: shaft through the barrel and a domed button head on the top knuckle.
            let rp = pinRadius, hb = L / 2
            let pinProf = [V2(0, -hb + 0.0001), V2(rp * 0.8, -hb + 0.0001), V2(rp, -hb + 0.0005), V2(rp, hb), V2(rbtn, hb + 0.0002),
                           V2(rbtn, hb + 0.0012), V2(rbtn * 0.9, hb + 0.0021), V2(rbtn * 0.55, hb + 0.0029), V2(0, hb + 0.0032)]
            rig.add(Prim.lathe(pinProf, segments: sg, seamTile: 0.03, material: plate), Xform(translation: V3(0, R, 0), rotation: toZ), to: "pin", lods: l...l)
        }
        groundAO(&rig, height: 0.004, floor: 0.6)
        rig.states = [RigState("open-flat", ["leaf": 180]), RigState("closed"), RigState("open-90", ["leaf": 90]),
                      RigState("pin-out", ["leaf": 180, "pin": Self.pinTravel])]
        return rig
    }
}
