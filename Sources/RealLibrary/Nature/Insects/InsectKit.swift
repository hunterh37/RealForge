import simd
import Foundation

/// Shared builders for the life-size insects in this folder. Every insect faces +Z with its left side
/// on +X, stands with its tarsi on y = 0 and is built twice (LOD0 detailed, LOD1 lean) into a `Rig`
/// whose part names follow the BugHunt contract: `body` (root), `head`, `abdomen`, `leg-l0...l2`,
/// `leg-r0...r2` (front to hind), `wing-l`/`wing-r` (fore), `wing-l2`/`wing-r2` (hind), `elytra-l/r`,
/// `antenna-l/r`, `segment-0...n`, `glow`.
///
/// Joints: legs swing about +Y at the coxa (forward is `-side * deg`), wings and elytra hinge about the
/// body axis (+Z) at the root (up is `side * deg`), head and abdomen pitch about +X, antennae swing
/// about +Y, segments yaw about +Y (or pitch about +X for curling).
public enum InsectKit {
    /// Per-LOD tessellation.
    public struct Detail: Sendable {
        public var lod: Int
        public var sub: Int { lod == 0 ? 7 : 4 }
        public var sides: Int { lod == 0 ? 8 : 5 }
        public var per: Int { lod == 0 ? 3 : 1 }
    }

    // MARK: solids

    /// Ellipsoid of semi-axes `r` (x width, y height, z length) at `c`. `deform` reshapes the local
    /// point before placement (taper, flatten, keel), `rot` orients it.
    public static func blob(_ c: V3, _ r: V3, material: MaterialKey, sub: Int, rot: simd_quatf = .identity,
                            deform: ((V3) -> V3)? = nil) -> Surface {
        Prim.cubeSphere(subdivisions: max(2, sub), material: material) { d in
            var p = d * r
            if let deform { p = deform(p) }
            return c + rot.act(p)
        }
    }

    /// Tapered tube through control points (Catmull-Rom smoothed), radii interpolated.
    public static func limb(_ pts: [V3], radii: [Float], material: MaterialKey, sides: Int, per: Int = 3, cap: Bool = true) -> Surface {
        precondition(pts.count == radii.count && pts.count >= 2)
        var path = pts, rad = radii
        if pts.count > 2 && per > 1 {
            path = catmull(pts, per: per)
            rad = (0..<path.count).map { i in
                let t = Float(i) / Float(per)
                let a = min(Int(t), radii.count - 1), b = min(a + 1, radii.count - 1)
                return lerp(radii[a], radii[b], t - Float(a))
            }
        }
        let seam = max(0.001, rad.max()! * 2 * .pi)
        return Prim.tube(path, radii: rad, sides: sides, seamTile: seam, material: material, capEnd: cap)
    }

    // MARK: legs

    public struct Leg: Sendable {
        /// Coxa attachment on the thorax underside.
        public var attach: V3
        /// +1 left (+X), -1 right.
        public var side: Float
        /// Heading in degrees from straight out (+X/-X): positive toward the head (+Z).
        public var yaw: Float
        public var coxa: Float, femur: Float, tibia: Float, tarsus: Float
        /// Femur elevation in degrees.
        public var lift: Float = 35
        /// Thickness at the femur.
        public var radius: Float
        /// Femur bulge (jumping hind legs 2.5, raptorial forelegs 1.8).
        public var bulge: Float = 1.2
        /// Tibia folds back under the femur (grasshopper hind leg) instead of reaching outward.
        public var folded = false
        /// Tibia heading in degrees relative to the femur heading (spread feet).
        public var tibiaYaw: Float = 0
        public init(attach: V3, side: Float, yaw: Float, coxa: Float, femur: Float, tibia: Float, tarsus: Float, lift: Float = 35, radius: Float,
                    bulge: Float = 1.2, folded: Bool = false, tibiaYaw: Float = 0) {
            self.attach = attach; self.side = side; self.yaw = yaw; self.coxa = coxa; self.femur = femur; self.tibia = tibia
            self.tarsus = tarsus; self.lift = lift; self.radius = radius; self.bulge = bulge; self.folded = folded; self.tibiaYaw = tibiaYaw
        }
    }

    static func heading(_ side: Float, _ yawDeg: Float) -> V3 {
        let a = radians(yawDeg)
        return V3(side * cos(a), 0, sin(a))
    }

    /// Joint positions of a leg: attach, coxa end, knee, ankle, tarsus mid, claw.
    public static func legPoints(_ l: Leg) -> [V3] {
        let h = heading(l.side, l.yaw)
        let c1 = l.attach + h * l.coxa + V3(0, -l.coxa * 0.35, 0)
        let e = radians(l.lift)
        let knee = c1 + h * (l.femur * cos(e)) + V3(0, l.femur * sin(e), 0)
        let foot = l.radius * 0.45
        let drop = max(0, knee.y - foot)
        let ht = l.folded ? -h : heading(l.side, l.yaw + l.tibiaYaw)
        let horiz = drop >= l.tibia ? l.tibia * 0.15 : sqrt(l.tibia * l.tibia - drop * drop)
        let ankle = V3(knee.x, foot, knee.z) + ht * horiz + V3(0, drop >= l.tibia ? drop - l.tibia : 0, 0)
        let th = l.folded ? heading(l.side, l.yaw) * 0.3 + (-h) * 0.7 : ht
        let tdir = simd_normalize(V3(th.x, 0, th.z))
        let mid = ankle + tdir * l.tarsus * 0.5 + V3(0, l.radius * 0.15, 0)
        let claw = ankle + tdir * l.tarsus + V3(0, -l.radius * 0.1, 0)
        return [l.attach, c1, knee, ankle, mid, claw]
    }

    /// A segmented leg: coxa, femur (bulged), tibia, tarsus, with joint knobs at LOD0.
    public static func leg(_ l: Leg, material: MaterialKey, d: Detail, spines: Int = 0) -> Surface {
        let p = legPoints(l)
        let r = l.radius
        var femurMid = (p[1] + p[2]) * 0.5
        femurMid.y += r * 0.2
        let pts = [p[0], p[1], femurMid, p[2], (p[2] + p[3]) * 0.5, p[3], p[4], p[5]]
        let radii = [r * 1.15, r * 1.0, r * l.bulge, r * 0.75, r * 0.62, r * 0.5, r * 0.4, r * 0.25]
        var s = limb(pts, radii: radii, material: material, sides: d.sides, per: d.per)
        if d.lod == 0 {
            s.append(Prim.cubeSphere(subdivisions: 2, material: material) { p[2] + $0 * r * 0.78 })
            // Tarsal segments: small swellings along the foot.
            for k in 1...3 {
                let t = Float(k) / 4
                let q = simd_mix(p[3], p[5], V3(repeating: t))
                s.append(Prim.cubeSphere(subdivisions: 2, material: material) { q + $0 * V3(r * 0.42, r * 0.38, r * 0.42) })
            }
            if spines > 0 {
                let dir = simd_normalize(p[3] - p[2])
                for k in 0..<spines {
                    let t = (Float(k) + 0.5) / Float(spines)
                    let base = simd_mix(p[2], p[3], V3(repeating: t))
                    let out = simd_normalize(V3(l.side * 0.6, -0.3, 0) - dir * 0.6)
                    s.append(limb([base, base + out * r * 1.4 + dir * r * 0.6], radii: [r * 0.18, r * 0.04], material: material, sides: 3, per: 1))
                }
            }
        }
        return s
    }

    // MARK: antennae

    /// Antenna from `base` heading `dir`, drooping/curving by `curve` (radians over its length).
    /// `elbow` bends at the scape (ants, bees), `club` swells the tip (butterflies), `beads` adds
    /// segment knobs at LOD0.
    public static func antenna(base: V3, dir: V3, length: Float, radius: Float, curve: Float = 0.5, side: Float, elbow: Float = 0,
                               club: Float = 0, beads: Int = 0, material: MaterialKey, d: Detail) -> Surface {
        var pts: [V3] = [base]
        var rad: [Float] = [radius * 1.3]
        var p = base, h = simd_normalize(dir)
        let n = 8
        for i in 1...n {
            let t = Float(i) / Float(n)
            var step = length / Float(n)
            if elbow != 0 && i == 1 { step = length * 0.28 }
            else if elbow != 0 { step = length * 0.72 / Float(n - 1) }
            let bendAxis = simd_cross(V3(0, 1, 0), h).normalized
            if elbow != 0 && i == 2 { h = simd_quatf(angle: elbow, axis: bendAxis).act(h) }
            h = simd_quatf(angle: curve / Float(n), axis: bendAxis).act(h)
            p += h * step
            pts.append(p)
            rad.append(radius * (1 - 0.45 * t) * (1 + club * smoothstep(0.65, 0.92, t) * (i == n ? 0.5 : 1)))
        }
        _ = side
        var s = limb(pts, radii: rad, material: material, sides: max(4, d.sides - 2), per: d.lod == 0 ? 2 : 1)
        if beads > 0 && d.lod == 0 {
            let path = catmull(pts, per: 3)
            for k in 0..<beads {
                let t = Float(k + 1) / Float(beads + 1)
                let i = min(path.count - 1, Int(t * Float(path.count - 1)))
                let r = radius * (1 - 0.45 * t) * 1.25
                s.append(Prim.cubeSphere(subdivisions: 1, material: material) { path[i] + $0 * r })
            }
        }
        return s
    }

    // MARK: wings

    /// Flat wing on an outline from `InsectWings`. The (u, v) wing frame maps to
    /// `root + span * (u * length) + chord * ((v - rootV) * width)`; UVs are (u, v) for the atlas
    /// programs. `droop` bends the span down toward the tip (meters at the tip). With `veins`, a cutout
    /// venation layer sits a hair above the membrane.
    public static func wing(_ shape: InsectWings.Shape, root: V3, span: V3, chord: V3, length: Float, width: Float, rootV: Float = 0.5,
                            material: MaterialKey, veins: MaterialKey? = nil, droop: Float = 0, cup: Float = 0) -> [Surface] {
        let outline = InsectWings.outline(shape)
        let sp = simd_normalize(span), ch = simd_normalize(chord)
        let n = simd_normalize(simd_cross(sp, ch))
        let up = n.y >= 0 ? n : -n
        func place(_ q: V2, _ lift: Float) -> V3 {
            let bend = droop * q.x * q.x + cup * (q.y - 0.5) * (q.y - 0.5) * 4 * q.x
            return root + sp * (q.x * length) + ch * ((q.y - rootV) * width) - up * bend + up * lift
        }
        // Interior points: a coarse grid inside the outline for smooth bending.
        var pts = outline
        let interior = interiorGrid(outline, step: 0.12)
        pts += interior
        let tris = delaunayFan(outline: outline, interior: interior)
        func surface(_ mat: MaterialKey, _ lift: Float) -> Surface {
            var s = Surface(material: mat)
            for q in pts { _ = s.add(place(q, lift), up, q) }
            s.indices = tris
            s.recomputeNormals(weldSeams: false)
            s.computeTangents()
            return s
        }
        var out = [surface(material, 0)]
        if let veins { out.append(surface(veins, max(1e-5, length * 0.002))) }
        return out
    }

    static func inside(_ p: V2, _ poly: [V2]) -> Bool {
        var c = false
        var j = poly.count - 1
        for i in 0..<poly.count {
            let a = poly[i], b = poly[j]
            if (a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { c.toggle() }
            j = i
        }
        return c
    }

    static func interiorGrid(_ poly: [V2], step: Float) -> [V2] {
        var out: [V2] = []
        var y: Float = step * 0.5
        var row = 0
        while y < 1 {
            var x: Float = step * (row % 2 == 0 ? 0.5 : 1.0)
            while x < 1 {
                let p = V2(x, y)
                if inside(p, poly) && poly.allSatisfy({ simd_distance($0, p) > step * 0.45 }) { out.append(p) }
                x += step
            }
            y += step * 0.87; row += 1
        }
        return out
    }

    /// Triangulates the outline with interior points (ear clip of the outline, then each interior
    /// point splits its containing triangle and edges are flipped toward Delaunay).
    static func delaunayFan(outline: [V2], interior: [V2]) -> [UInt32] {
        var pts = outline + interior
        var tris: [(Int, Int, Int)] = []
        let base = Shape2D.triangulate(outline)
        for i in stride(from: 0, to: base.count, by: 3) { tris.append((Int(base[i]), Int(base[i + 1]), Int(base[i + 2]))) }
        func cross(_ o: V2, _ a: V2, _ b: V2) -> Float { (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x) }
        for (k, q) in interior.enumerated() {
            let qi = outline.count + k
            guard let t = tris.firstIndex(where: { tr in
                let a = pts[tr.0], b = pts[tr.1], c = pts[tr.2]
                let s = cross(a, b, c) >= 0 ? Float(1) : -1
                return cross(a, b, q) * s >= -1e-7 && cross(b, c, q) * s >= -1e-7 && cross(c, a, q) * s >= -1e-7
            }) else { continue }
            let tr = tris.remove(at: t)
            tris += [(tr.0, tr.1, qi), (tr.1, tr.2, qi), (tr.2, tr.0, qi)]
        }
        // Edge flips (Lawson) for better shaped triangles.
        func inCircle(_ a: V2, _ b: V2, _ c: V2, _ d: V2) -> Bool {
            let ax = a.x - d.x, ay = a.y - d.y, bx = b.x - d.x, by = b.y - d.y, cx = c.x - d.x, cy = c.y - d.y
            let det = (ax * ax + ay * ay) * (bx * cy - cx * by) - (bx * bx + by * by) * (ax * cy - cx * ay) + (cx * cx + cy * cy) * (ax * by - bx * ay)
            return cross(a, b, c) > 0 ? det > 1e-9 : det < -1e-9
        }
        let boundary = Set((0..<outline.count).map { i in [i, (i + 1) % outline.count].sorted() }.map { "\($0[0])-\($0[1])" })
        for _ in 0..<6 {
            var flipped = false
            outer: for i in tris.indices {
                let t = tris[i]; let e = [(t.0, t.1, t.2), (t.1, t.2, t.0), (t.2, t.0, t.1)]
                for (a, b, c) in e {
                    if boundary.contains("\(min(a, b))-\(max(a, b))") { continue }
                    guard let j = tris.indices.first(where: { $0 != i && [tris[$0].0, tris[$0].1, tris[$0].2].contains(a) && [tris[$0].0, tris[$0].1, tris[$0].2].contains(b) }) else { continue }
                    let o = tris[j]; let dIdx = [o.0, o.1, o.2].first { $0 != a && $0 != b }!
                    if inCircle(pts[a], pts[b], pts[c], pts[dIdx]) {
                        // New triangles must keep orientation and be convex quads.
                        let s0 = cross(pts[c], pts[dIdx], pts[b]), s1 = cross(pts[dIdx], pts[c], pts[a])
                        let sOrig = cross(pts[a], pts[b], pts[c])
                        if (s0 > 0) != (sOrig > 0) || (s1 > 0) != (sOrig > 0) { continue }
                        tris[i] = (c, dIdx, b) ; tris[j] = (dIdx, c, a)
                        flipped = true
                        continue outer
                    }
                }
            }
            if !flipped { break }
        }
        pts.removeAll()
        return tris.flatMap { [UInt32($0.0), UInt32($0.1), UInt32($0.2)] }
    }

    // MARK: elytra

    /// One beetle elytron as a shell (outer cuticle, darker inner face). u runs from the suture (0)
    /// to the outer edge (1), v from the apex (0) to the shoulder (1). `atlas` UVs are (u, v) for the
    /// pattern programs; otherwise meters.
    public static func elytron(side: Float, front: Float, length: Float, halfWidth: Float, height: Float, baseY: Float,
                               wrap: Float = 1.8, material: MaterialKey, inner: MaterialKey, atlas: Bool, d: Detail,
                               shoulder: Float = 0.15, tipRound: Float = 0.35) -> [Surface] {
        let nu = d.lod == 0 ? 10 : 5, nv = d.lod == 0 ? 16 : 7
        func prof(_ v: Float) -> Float {
            // Apex rounded, shoulders slightly squared.
            let a = v < tipRound ? sqrt(max(0, 1 - pow((tipRound - v) / tipRound, 2))) : 1
            let b = v > 1 - shoulder ? 0.9 + 0.1 * sqrt(max(0, 1 - pow((v - 1 + shoulder) / shoulder, 2))) : 1
            return a * b
        }
        func point(_ u: Float, _ v: Float, _ shrink: Float) -> V3 {
            let w = halfWidth * max(0.02, prof(v)) * shrink, h = height * max(0.04, prof(v) * (0.75 + 0.25 * v)) * shrink
            let th = u * wrap
            let x = side * (w * sin(min(th, .pi * 0.5)) + (th > .pi * 0.5 ? w * 0.0 : 0))
            let y = baseY + h * cos(th)
            let z = front - (1 - v) * length
            return V3(x, y, z)
        }
        func sheet(_ mat: MaterialKey, _ shrink: Float, flip: Bool) -> Surface {
            var s = Surface(material: mat)
            for j in 0...nv { for i in 0...nu {
                let u = Float(i) / Float(nu), v = Float(j) / Float(nv)
                let p = point(u, v, shrink)
                let uv = atlas ? V2(u, v) : V2(u * halfWidth * 2, v * length)
                _ = s.add(p, .up, uv)
            }}
            let row = UInt32(nu + 1)
            for j in 0..<UInt32(nv) { for i in 0..<UInt32(nu) {
                let a = j * row + i
                if (side > 0) != flip { s.quad(a, a + row, a + row + 1, a + 1) } else { s.quad(a, a + 1, a + row + 1, a + row) }
            }}
            s.recomputeNormals(weldSeams: false)
            s.computeTangents()
            return s
        }
        return [sheet(material, 1, flip: false), sheet(inner, 0.94, flip: true)]
    }

    // MARK: rig

    /// Leg joint name for a side and pair index.
    public static func legName(_ side: Float, _ i: Int) -> String { (side > 0 ? "leg-l" : "leg-r") + "\(i)" }

    /// Tripod gait poses: walk-a swings L0, R1, L2 forward and the others back; walk-b the reverse.
    public static func gait(_ a: Float, pairs: Int = 3, swapped: Bool) -> [String: Float] {
        var j: [String: Float] = [:]
        for i in 0..<pairs {
            for side: Float in [1, -1] {
                let tripodA = (side > 0) == (i % 2 == 0)
                let fwd: Float = (tripodA != swapped) ? a : -a
                j[legName(side, i)] = -side * fwd
            }
        }
        return j
    }

    /// Declares the six legs (pivot at each coxa, hinge about +Y, ±range degrees).
    public static func declareLegs(_ rig: inout Rig, _ legs: [Leg], range: Float = 35, parent: String = "body") {
        for (k, l) in legs.enumerated() {
            rig.part(legName(l.side, k / 2), parent: parent, pivot: l.attach, joint: .hinge(axis: .up, -range...range, duration: 0.25))
        }
    }

    /// Contact AO and cavity AO scaled to the insect height.
    public static func finish(_ rig: inout Rig, height: Float) {
        groundAO(&rig, height: max(0.002, height), floor: 0.55)
    }
}
