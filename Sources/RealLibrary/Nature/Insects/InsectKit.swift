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
        let nPts = pts.count
        func edgeKey(_ a: Int, _ b: Int) -> Int { min(a, b) * nPts + max(a, b) }
        let boundary = Set((0..<outline.count).map { edgeKey($0, ($0 + 1) % outline.count) })
        func has(_ t: (Int, Int, Int), _ v: Int) -> Bool { t.0 == v || t.1 == v || t.2 == v }
        for _ in 0..<6 {
            var flipped = false
            outer: for i in tris.indices {
                let t = tris[i]
                for (a, b, c) in [(t.0, t.1, t.2), (t.1, t.2, t.0), (t.2, t.0, t.1)] {
                    if boundary.contains(edgeKey(a, b)) { continue }
                    guard let j = tris.indices.first(where: { $0 != i && has(tris[$0], a) && has(tris[$0], b) }) else { continue }
                    let o = tris[j]; let dIdx = o.0 != a && o.0 != b ? o.0 : (o.1 != a && o.1 != b ? o.1 : o.2)
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

// MARK: plans

/// Declarative insect: body blobs, legs (left side, mirrored), antennae, wings and elytra. `assemble`
/// declares the contract parts, builds both LODs and the standard states.
public struct InsectPlan {
    public struct Blob { public var c: V3, r: V3, mat: MaterialKey, deform: ((V3) -> V3)? = nil, mirror = false
        public init(_ c: V3, _ r: V3, _ mat: MaterialKey, mirror: Bool = false, deform: ((V3) -> V3)? = nil) { self.c = c; self.r = r; self.mat = mat; self.mirror = mirror; self.deform = deform } }
    public struct Wing {
        public var shape: InsectWings.Shape, root: V3, span: V3, chord: V3, length: Float, width: Float, rootV: Float = 0.5
        public var mat: MaterialKey, veins: MaterialKey? = nil, droop: Float = 0
        /// Folded rest geometry (root, span, chord, length, width); nil = one geometry, rest by angle.
        public var folded: (root: V3, span: V3, chord: V3, length: Float, width: Float)? = nil
        public init(_ shape: InsectWings.Shape, root: V3, span: V3, chord: V3, length: Float, width: Float, rootV: Float = 0.5, mat: MaterialKey,
                    veins: MaterialKey? = nil, droop: Float = 0, folded: (root: V3, span: V3, chord: V3, length: Float, width: Float)? = nil) {
            self.shape = shape; self.root = root; self.span = span; self.chord = chord; self.length = length; self.width = width; self.rootV = rootV
            self.mat = mat; self.veins = veins; self.droop = droop; self.folded = folded
        }
    }
    public struct Antenna { public var base: V3, dir: V3, length: Float, radius: Float, curve: Float = 0.3, elbow: Float = 0, club: Float = 0, beads: Int = 0
        public init(base: V3, dir: V3, length: Float, radius: Float, curve: Float = 0.3, elbow: Float = 0, club: Float = 0, beads: Int = 0) {
            self.base = base; self.dir = dir; self.length = length; self.radius = radius; self.curve = curve; self.elbow = elbow; self.club = club; self.beads = beads } }
    public struct Elytra { public var front: Float, length: Float, halfWidth: Float, height: Float, baseY: Float, mat: MaterialKey, inner: MaterialKey, atlas: Bool, wrap: Float = 1.8
        public init(front: Float, length: Float, halfWidth: Float, height: Float, baseY: Float, mat: MaterialKey, inner: MaterialKey, atlas: Bool, wrap: Float = 1.8) {
            self.front = front; self.length = length; self.halfWidth = halfWidth; self.height = height; self.baseY = baseY; self.mat = mat; self.inner = inner; self.atlas = atlas; self.wrap = wrap } }

    public var name: String
    public var bodyPivot: V3 = .zero
    public var thorax: [Blob] = []
    public var neck: V3 = .zero
    public var head: [Blob] = []
    public var abdomenPivot: V3 = .zero
    public var abdomen: [Blob] = []
    /// Left legs front to hind (mirrored for the right side).
    public var legs: [InsectKit.Leg] = []
    public var legMat: MaterialKey = "insect.chitin"
    public var spines: [Int] = [0, 0, 0]
    public var antenna: Antenna?
    public var antennaMat: MaterialKey = "insect.chitin"
    /// Fore wings (`wing-l/r`) and hind wings (`wing-l2/r2`).
    public var fore: Wing?
    public var hind: Wing?
    public var elytra: Elytra?
    /// Wing angle at rest for wings without folded geometry (butterflies close up over the back).
    public var restWing: Float = 0
    public var openWing: Float = 15
    public var height: Float = 0.01
    public var switchDistance: Float = 1.0
    /// Extra geometry per LOD: (rig, detail, lod range).
    public var extra: ((inout Rig, InsectKit.Detail, ClosedRange<Int>) -> Void)?
    public var extraStates: [RigState] = []
    /// Extra part declarations (after the standard parts, before geometry).
    public var extraParts: ((inout Rig) -> Void)?
    public var defaultState: String?
    public init(name: String) { self.name = name }
}

public extension InsectKit {
    static func mirror(_ v: V3) -> V3 { V3(-v.x, v.y, v.z) }

    static func assemble(_ p: InsectPlan) -> Rig {
        var rig = Rig(name: p.name, lods: 2, switchDistances: [p.switchDistance])
        rig.part("body", pivot: p.bodyPivot, joint: .fixed)
        if !p.head.isEmpty { rig.part("head", parent: "body", pivot: p.neck, joint: .hinge(axis: V3(1, 0, 0), -20...20, duration: 0.3)) }
        if !p.abdomen.isEmpty { rig.part("abdomen", parent: "body", pivot: p.abdomenPivot, joint: .hinge(axis: V3(1, 0, 0), -25...25, duration: 0.3)) }
        var legs: [Leg] = []
        for l in p.legs { legs.append(l); var r = l; r.side = -1; r.attach = mirror(l.attach); legs.append(r) }
        declareLegs(&rig, legs)
        if let e = p.elytra {
            rig.part("elytra-l", parent: "body", pivot: V3(0.0001, e.baseY + e.height, e.front), joint: .hinge(axis: V3(0, 0, 1), 0...75, duration: 0.25))
            rig.part("elytra-r", parent: "body", pivot: V3(-0.0001, e.baseY + e.height, e.front), joint: .hinge(axis: V3(0, 0, 1), -75...0, duration: 0.25))
        }
        for (w, suffix) in [(p.fore, ""), (p.hind, "2")] {
            guard let w else { continue }
            let opts = w.folded == nil ? 1 : 2
            rig.part("wing-l" + suffix, parent: "body", pivot: w.root, joint: .hinge(axis: V3(0, 0, 1), -90...90, duration: 0.05), options: opts)
            rig.part("wing-r" + suffix, parent: "body", pivot: mirror(w.root), joint: .hinge(axis: V3(0, 0, 1), -90...90, duration: 0.05), options: opts)
        }
        if let a = p.antenna {
            let parent = p.head.isEmpty ? "body" : "head"
            rig.part("antenna-l", parent: parent, pivot: a.base, joint: .hinge(axis: .up, -30...30, duration: 0.3))
            rig.part("antenna-r", parent: parent, pivot: mirror(a.base), joint: .hinge(axis: .up, -30...30, duration: 0.3))
        }
        p.extraParts?(&rig)
        for lod in 0..<2 {
            let d = Detail(lod: lod), L = lod...lod
            func put(_ bs: [InsectPlan.Blob], _ part: String) {
                for b in bs {
                    let sub = max(2, d.sub - (simd_reduce_max(b.r) < p.height * 0.08 ? 3 : 0))
                    rig.add(blob(b.c, b.r, material: b.mat, sub: sub, deform: b.deform), to: part, lods: L)
                    if b.mirror { rig.add(blob(mirror(b.c), b.r, material: b.mat, sub: sub, deform: b.deform.map { f in { q in mirror(f(mirror(q))) } }), to: part, lods: L) }
                }
            }
            put(p.thorax, "body"); put(p.head, "head"); put(p.abdomen, "abdomen")
            for (k, l) in legs.enumerated() {
                rig.add(leg(l, material: p.legMat, d: d, spines: p.spines[min(2, k / 2)]), to: legName(l.side, k / 2), lods: L)
            }
            if let a = p.antenna {
                for side: Float in [1, -1] {
                    let base = side > 0 ? a.base : mirror(a.base), dir = side > 0 ? a.dir : mirror(a.dir)
                    rig.add(antenna(base: base, dir: dir, length: a.length, radius: a.radius, curve: a.curve, side: side, elbow: a.elbow, club: a.club,
                                    beads: a.beads, material: p.antennaMat, d: d), to: side > 0 ? "antenna-l" : "antenna-r", lods: L)
                }
            }
            if let e = p.elytra {
                for side: Float in [1, -1] {
                    for s in elytron(side: side, front: e.front, length: e.length, halfWidth: e.halfWidth, height: e.height, baseY: e.baseY,
                                     wrap: e.wrap, material: e.mat, inner: e.inner, atlas: e.atlas, d: d) {
                        rig.add(s, to: side > 0 ? "elytra-l" : "elytra-r", lods: L)
                    }
                }
            }
            for (w, suffix) in [(p.fore, ""), (p.hind, "2")] {
                guard let w else { continue }
                for side: Float in [1, -1] {
                    let f: (V3) -> V3 = side > 0 ? { $0 } : mirror
                    let part = (side > 0 ? "wing-l" : "wing-r") + suffix
                    let veins = lod == 0 ? w.veins : (w.veins == nil ? nil : w.veins)
                    for s in wing(w.shape, root: f(w.root), span: f(w.span), chord: f(w.chord), length: w.length, width: w.width, rootV: w.rootV,
                                  material: w.mat, veins: veins, droop: w.droop) {
                        rig.add(s, to: part, option: w.folded == nil ? 0 : 1, lods: L)
                    }
                    if let fo = w.folded {
                        for s in wing(w.shape, root: f(fo.root), span: f(fo.span), chord: f(fo.chord), length: fo.length, width: fo.width, rootV: w.rootV,
                                      material: w.mat, veins: veins) {
                            rig.add(s, to: part, option: 0, lods: L)
                        }
                    }
                }
            }
            p.extra?(&rig, d, L)
        }
        var states: [RigState] = []
        let hasWings = p.fore != nil || p.hind != nil
        var rest: [String: Float] = [:], open: [String: Float] = [:], opts: [String: Int] = [:]
        for (w, suffix) in [(p.fore, ""), (p.hind, "2")] {
            guard let w else { continue }
            if w.folded == nil { rest["wing-l" + suffix] = p.restWing; rest["wing-r" + suffix] = -p.restWing }
            else { opts["wing-l" + suffix] = 1; opts["wing-r" + suffix] = 1 }
            open["wing-l" + suffix] = p.openWing; open["wing-r" + suffix] = -p.openWing
        }
        if p.elytra != nil { open["elytra-l"] = 60; open["elytra-r"] = -60 }
        func merge(_ a: [String: Float], _ b: [String: Float]) -> [String: Float] { a.merging(b) { _, n in n } }
        states.append(RigState("rest", rest))
        if hasWings { states.append(RigState("wings-open", open, options: opts)) }
        if !p.legs.isEmpty {
            states.append(RigState("walk-a", merge(rest, gait(22, swapped: false))))
            states.append(RigState("walk-b", merge(rest, gait(22, swapped: true))))
        }
        states += p.extraStates
        rig.states = states
        rig.defaultState = p.defaultState
        finish(&rig, height: p.height)
        return rig
    }
}

public extension InsectKit {
    /// Lepidopteran plan: fuzzy thorax, slender abdomen, big eyes, coiled proboscis, clubbed (or
    /// feathered) antennae, reduced forelegs (brush-footed butterflies), and fore/hind wings on the
    /// shared outlines. Dimensions scale from a monarch (10 cm span).
    struct Lepidoptera {
        public var k: Float = 1
        public var fore: (InsectWings.Shape, MaterialKey, length: Float, width: Float, rootV: Float)
        public var hind: (InsectWings.Shape, MaterialKey, length: Float, width: Float, rootV: Float)
        public var hindSweep: Float = -0.35
        public var thorax: MaterialKey = "insect.fur:1A1714"
        public var abdomen: MaterialKey = "insect.fur:2A2018"
        public var thoraxSpots: MaterialKey? = "insect.chitin:E8E4DA"
        public var antennaClub: Float = 2.5
        public var feathered = false
        public var reducedForelegs = true
        public var restWing: Float = 80
        public init(fore: (InsectWings.Shape, MaterialKey, length: Float, width: Float, rootV: Float), hind: (InsectWings.Shape, MaterialKey, length: Float, width: Float, rootV: Float)) {
            self.fore = fore; self.hind = hind
        }
    }

    static func lepidoptera(_ name: String, _ s: Lepidoptera) -> InsectPlan {
        let k = s.k
        var p = InsectPlan(name: name)
        let y: Float = 0.0095 * k
        p.height = y + 0.004 * k
        p.bodyPivot = V3(0, y, 0.003 * k)
        p.thorax = [.init(V3(0, y, 0.003 * k), V3(0.0030, 0.0030, 0.0046) * k, s.thorax)]
        p.neck = V3(0, y, 0.0075 * k)
        p.head = [.init(V3(0, y, 0.0088 * k), V3(0.0020, 0.0021, 0.0018) * k, s.thorax),
                  .init(V3(0.0016, y + 0.0004 * k, 0.0092 * k), V3(0.0012, 0.0014, 0.0013) * k, "insect.eye:3A3428", mirror: true)]
        p.abdomenPivot = V3(0, y, -0.0012 * k)
        p.abdomen = [.init(V3(0, y - 0.0006 * k, -0.0115 * k), V3(0.0019, 0.0021, 0.0105) * k, s.abdomen) { q in
            V3(q.x * (1 - max(0, -q.z) * 25 / k), q.y * (1 - max(0, -q.z) * 25 / k), q.z) }]
        p.legs = [
            s.reducedForelegs
                ? .init(attach: V3(0.0012, y - 0.0022 * k, 0.0058 * k), side: 1, yaw: 70, coxa: 0.0008 * k, femur: 0.0025 * k, tibia: 0.0012 * k, tarsus: 0.0004 * k, lift: 60, radius: 0.0003 * k)
                : .init(attach: V3(0.0012, y - 0.0022 * k, 0.0058 * k), side: 1, yaw: 45, coxa: 0.0008 * k, femur: 0.0055 * k, tibia: 0.0080 * k, tarsus: 0.004 * k, lift: 40, radius: 0.0003 * k),
            .init(attach: V3(0.0013, y - 0.0024 * k, 0.0032 * k), side: 1, yaw: 10, coxa: 0.0008 * k, femur: 0.0060 * k, tibia: 0.0085 * k, tarsus: 0.0050 * k, lift: 42, radius: 0.0003 * k, bulge: 1),
            .init(attach: V3(0.0013, y - 0.0024 * k, 0.0008 * k), side: 1, yaw: -35, coxa: 0.0008 * k, femur: 0.0065 * k, tibia: 0.0090 * k, tarsus: 0.0052 * k, lift: 42, radius: 0.0003 * k, bulge: 1),
        ]
        p.legMat = "insect.chitin:2A2420"; p.antennaMat = s.feathered ? "insect.fur:C8B070" : "insect.chitin:1A1816"
        p.antenna = .init(base: V3(0.0007, y + 0.0016 * k, 0.0098 * k), dir: V3(0.35, s.feathered ? 0.2 : 0.4, 0.9),
                          length: (s.feathered ? 0.011 : 0.021) * k, radius: (s.feathered ? 0.0005 : 0.00018) * k, curve: s.feathered ? -0.4 : 0.1,
                          club: s.feathered ? 0 : s.antennaClub, beads: s.feathered ? 10 : 0)
        p.fore = .init(s.fore.0, root: V3(0.0018 * k, y + 0.0012 * k, 0.0050 * k), span: V3(1, 0, 0.18), chord: V3(-0.18, 0, 1),
                       length: s.fore.length * k, width: s.fore.width * k, rootV: s.fore.rootV, mat: s.fore.1, droop: 0.002 * k)
        p.hind = .init(s.hind.0, root: V3(0.0018 * k, y + 0.0008 * k, 0.0012 * k), span: V3(1, 0, s.hindSweep), chord: V3(-s.hindSweep, 0, 1),
                       length: s.hind.length * k, width: s.hind.width * k, rootV: s.hind.rootV, mat: s.hind.1, droop: 0.001 * k)
        p.restWing = s.restWing; p.openWing = 0
        p.defaultState = s.restWing > 30 ? "wings-open" : nil
        if s.restWing <= 30 { p.openWing = 25 }
        let thorax = s.thorax, spots = s.thoraxSpots
        p.extra = { rig, d, L in
            // Coiled proboscis under the head.
            var pts: [V3] = []
            for i in 0...14 {
                let t = Float(i) / 14, a = t * 2.4 * .pi, r = (0.0011 - 0.0008 * t) * k
                pts.append(V3(0, y - 0.0018 * k - r * (1 - cos(a)), 0.0102 * k + r * sin(a)))
            }
            rig.add(limb(pts, radii: pts.map { _ in 0.00012 * k }, material: "insect.chitin:2A2420", sides: 4, per: 1), to: "head", lods: L)
            // Palps.
            rig.add(blob(V3(0, y - 0.0006 * k, 0.0106 * k), V3(0.0008, 0.0012, 0.0006) * k, material: thorax, sub: 2), to: "head", lods: L)
            if let spots, d.lod == 0 {
                for (i, q) in [V3(0.0012, 0.0022, 0.004), V3(-0.0012, 0.0022, 0.004), V3(0.0008, 0.0026, 0.0015), V3(-0.0008, 0.0026, 0.0015),
                               V3(0.0016, 0.0003, 0.0098), V3(-0.0016, 0.0003, 0.0098)].enumerated() {
                    rig.add(blob(V3(q.x, y + q.y, q.z) * V3(k, 1, k) + V3(0, (k - 1) * q.y, 0), V3(repeating: 0.00028 * k), material: spots, sub: 1), to: i < 4 ? "body" : "head", lods: L)
                }
            }
        }
        return p
    }
}

public extension InsectKit {
    /// Bee plan (honey bee scale, 14 mm): hairy thorax, banded abdomen of telescoping tergites,
    /// elbowed antennae, big compound eyes, fore and hind wings folded flat over the abdomen at rest.
    struct Bee {
        public var k: Float = 1
        public var head: MaterialKey = "insect.chitin:2A2018"
        public var collar: MaterialKey = "insect.fur:A8865A"
        public var thorax: MaterialKey = "insect.fur:9C7A4A"
        /// Tergite materials front to back.
        public var bands: [MaterialKey] = ["insect.chitin:C88A30", "insect.chitin:C88A30", "insect.chitin:3A2616", "insect.chitin:B07828", "insect.chitin:2E2014", "insect.chitin:2A1E14"]
        public var plump: Float = 1
        public var membrane: MaterialKey = "insect.membrane"
        public var legs: MaterialKey = "insect.chitin:2A2018"
        public init() {}
    }

    static func bee(_ name: String, _ s: Bee) -> InsectPlan {
        let k = s.k, f = s.plump
        var p = InsectPlan(name: name)
        let y: Float = 0.0042 * k
        p.height = y + 0.003 * k
        p.bodyPivot = V3(0, y, 0.0028 * k)
        p.thorax = [.init(V3(0, y + 0.0002 * k, 0.0028 * k), V3(0.0020 * f, 0.0020 * f, 0.0022) * k, s.thorax),
                    .init(V3(0, y + 0.0004 * k, 0.0042 * k), V3(0.0018 * f, 0.0015 * f, 0.0010) * k, s.collar)]
        p.neck = V3(0, y, 0.0048 * k)
        p.head = [.init(V3(0, y, 0.0058 * k), V3(0.0018, 0.0017, 0.0011) * k, s.head),
                  .init(V3(0.0012, y + 0.0002 * k, 0.0058 * k), V3(0.0007, 0.0013, 0.0009) * k, "insect.eye:3A3026", mirror: true),
                  .init(V3(0, y - 0.0014 * k, 0.0064 * k), V3(0.0008, 0.0006, 0.0005) * k, s.head)]
        p.abdomenPivot = V3(0, y, 0.0007 * k)
        let n = s.bands.count
        p.abdomen = s.bands.enumerated().map { i, m in
            let t = Float(i) / Float(n - 1)
            let r = (0.0022 - 0.0012 * t * t) * f
            return .init(V3(0, y - 0.0003 * k - t * 0.0006 * k, (-0.0004 - Float(i) * 0.0012) * k), V3(r, r * 0.92, 0.0013 * f) * k, m)
        }
        p.legs = [
            .init(attach: V3(0.0008, y - 0.0016 * k, 0.0038 * k), side: 1, yaw: 50, coxa: 0.0006 * k, femur: 0.0025 * k, tibia: 0.0030 * k, tarsus: 0.0022 * k, lift: 35, radius: 0.00022 * k),
            .init(attach: V3(0.0009, y - 0.0017 * k, 0.0026 * k), side: 1, yaw: 0, coxa: 0.0006 * k, femur: 0.0030 * k, tibia: 0.0034 * k, tarsus: 0.0025 * k, lift: 38, radius: 0.00022 * k),
            .init(attach: V3(0.0009, y - 0.0017 * k, 0.0014 * k), side: 1, yaw: -45, coxa: 0.0006 * k, femur: 0.0036 * k, tibia: 0.0040 * k, tarsus: 0.0030 * k, lift: 40, radius: 0.00028 * k, bulge: 1.5),
        ]
        p.legMat = s.legs; p.antennaMat = s.head
        p.antenna = .init(base: V3(0.0005, y + 0.0004 * k, 0.0068 * k), dir: V3(0.3, 0.6, 0.75), length: 0.0050 * k, radius: 0.00011 * k, curve: 0.3, elbow: 1.2, beads: 8)
        p.fore = .init(.beeFore, root: V3(0.0012 * k, y + 0.0018 * k, 0.0034 * k), span: V3(1, 0.1, -0.2), chord: V3(0.2, 0, 1), length: 0.0095 * k, width: 0.0034 * k,
                       rootV: 0.5, mat: s.membrane, veins: "insect.veins-bee-fore",
                       folded: (V3(0.0010 * k, y + 0.0020 * k, 0.0034 * k), V3(0.12, 0.04, -1), V3(1, 0.1, 0.12), 0.0090 * k, 0.0030 * k))
        p.hind = .init(.beeHind, root: V3(0.0012 * k, y + 0.0016 * k, 0.0022 * k), span: V3(1, 0.05, -0.55), chord: V3(0.55, 0, 1), length: 0.0068 * k, width: 0.0024 * k,
                       rootV: 0.5, mat: s.membrane, veins: "insect.veins-bee-hind",
                       folded: (V3(0.0010 * k, y + 0.0018 * k, 0.0022 * k), V3(0.15, 0.03, -1), V3(1, 0.1, 0.15), 0.0064 * k, 0.0022 * k))
        p.openWing = 20
        let tip = s.bands.last!
        let tipZ = (-0.0004 - Float(n - 1) * 0.0012 - 0.0012) * k
        p.extra = { rig, d, L in
            // Stinger and mandibles.
            rig.add(limb([V3(0, y - 0.0008 * k, tipZ), V3(0, y - 0.0010 * k, tipZ - 0.0008 * k)], radii: [0.00012 * k, 0.00002], material: tip, sides: 4, per: 1), to: "abdomen", lods: L)
            for side: Float in [1, -1] {
                rig.add(limb([V3(side * 0.0006 * k, y - 0.0016 * k, 0.0064 * k), V3(side * 0.0002 * k, y - 0.0020 * k, 0.0068 * k)], radii: [0.00015 * k, 0.00006 * k],
                             material: "insect.chitin:6A4A20", sides: 4, per: 1), to: "head", lods: L)
            }
        }
        return p
    }
}

public extension InsectKit {
    /// Orthopteran plan (grasshopper scale, 4 cm): vertical-faced head, saddle pronotum, jumping hind
    /// legs with a swollen femur and the tibia folded under it, leathery tegmina held along the back at
    /// rest over fan-folded hind wings.
    struct Orthoptera {
        public var k: Float = 1
        public var body: MaterialKey = "insect.chitin-soft"
        public var pronotum: MaterialKey = "insect.chitin-soft"
        public var legs: MaterialKey = "insect.chitin-soft"
        public var femur: MaterialKey? = nil
        public var tegmen: MaterialKey = "insect.tegmen-grasshopper"
        public var tegmenShape: InsectWings.Shape = .tegmen
        public var tegmenLength: Float = 0.028
        public var tegmenWidth: Float = 0.006
        /// Roof angle: 0 flat on the back, 1 vertical along the flanks.
        public var roof: Float = 0.55
        public var hindMembrane: MaterialKey = "insect.membrane-smoky"
        public var antennaLength: Float = 0.012
        public var antennaRadius: Float = 0.00022
        public var headRound: Float = 1
        public var cerci = false
        public var hindFemur: Float = 0.017
        public var hindBulge: Float = 2.4
        public var abdomenLength: Float = 0.010
        public init() {}
    }

    static func orthoptera(_ name: String, _ s: Orthoptera) -> InsectPlan {
        let k = s.k
        var p = InsectPlan(name: name)
        let y: Float = 0.0062 * k
        p.height = y + 0.006 * k
        p.bodyPivot = V3(0, y, 0.006 * k)
        p.thorax = [.init(V3(0, y + 0.0010 * k, 0.0075 * k), V3(0.0030, 0.0035, 0.0036) * k, s.pronotum) { q in V3(q.x * (1 + max(0, q.y) * 60 / k), q.y, q.z) },
                    .init(V3(0, y - 0.0004 * k, 0.0040 * k), V3(0.0026, 0.0028, 0.0035) * k, s.body)]
        p.neck = V3(0, y + 0.0006 * k, 0.0105 * k)
        p.head = [.init(V3(0, y + 0.0010 * k, 0.0122 * k), V3(0.0027, 0.0036 * s.headRound, 0.0026) * k, s.body) { q in V3(q.x, q.y, q.z - max(0, -q.y) * 0.25) },
                  .init(V3(0.0023, y + 0.0024 * k, 0.0124 * k), V3(0.0010, 0.0013, 0.0011) * k, "insect.eye:6A5A3A", mirror: true),
                  .init(V3(0, y - 0.0024 * k, 0.0134 * k), V3(0.0016, 0.0009, 0.0010) * k, s.legs)]
        p.abdomenPivot = V3(0, y, 0.0028 * k)
        let al = s.abdomenLength
        p.abdomen = [.init(V3(0, y - 0.0004 * k, (0.0025 - al * 0.85) * k), V3(0.0025, 0.0029, al) * k, s.body) { q in
            V3(q.x * (1 + q.z * 30 / k), q.y * (1 + q.z * 25 / k), q.z) }]
        p.legs = [
            .init(attach: V3(0.0011, y - 0.0028, 0.0088) * V3(k, 1, k) + V3(0, (k - 1) * -0.0028, 0), side: 1, yaw: 55, coxa: 0.0008 * k, femur: 0.0045 * k, tibia: 0.0050 * k, tarsus: 0.0022 * k, lift: 30, radius: 0.00038 * k),
            .init(attach: V3(0.0013, y - 0.0028, 0.0055) * V3(k, 1, k) + V3(0, (k - 1) * -0.0028, 0), side: 1, yaw: 5, coxa: 0.0008 * k, femur: 0.0048 * k, tibia: 0.0052 * k, tarsus: 0.0024 * k, lift: 30, radius: 0.00038 * k),
            .init(attach: V3(0.0016, y - 0.0022, 0.0030) * V3(k, 1, k) + V3(0, (k - 1) * -0.0022, 0), side: 1, yaw: -72, coxa: 0.0008 * k, femur: s.hindFemur * k, tibia: s.hindFemur * 0.92 * k, tarsus: 0.004 * k, lift: 24, radius: 0.0005 * k, bulge: s.hindBulge, folded: true),
        ]
        p.legMat = s.legs; p.antennaMat = s.legs; p.spines = [0, 0, 8]
        p.antenna = .init(base: V3(0.0010, y + 0.0024 * k, 0.0140 * k), dir: V3(0.25, 0.35, 0.9), length: s.antennaLength * k, radius: s.antennaRadius * k,
                          curve: s.antennaLength > 0.03 ? 1.4 : 0.4, beads: s.antennaLength > 0.03 ? 0 : 12)
        let r = s.roof
        p.fore = .init(s.tegmenShape, root: V3(0.0016 * k, y + 0.0036 * k, 0.0068 * k), span: V3(1, 0.1, -0.15), chord: V3(0.15, 0, 1),
                       length: s.tegmenLength * 1.05 * k, width: s.tegmenWidth * 1.15 * k, rootV: 0.5, mat: s.tegmen,
                       folded: (V3(0.0010 * k, y + 0.0040 * k, 0.0068 * k), V3(0.03, -0.06, -1), V3(1 - r, -r, 0.0), s.tegmenLength * k, s.tegmenWidth * k))
        p.hind = .init(.membraneHind, root: V3(0.0016 * k, y + 0.0032 * k, 0.0045 * k), span: V3(1, 0.05, -0.35), chord: V3(0.35, 0, 1),
                       length: s.tegmenLength * 0.9 * k, width: s.tegmenLength * 0.55 * k, rootV: 0.5, mat: s.hindMembrane, veins: "insect.veins-fan",
                       folded: (V3(0.0007 * k, y + 0.0034 * k, 0.0045 * k), V3(0.03, -0.05, -1), V3(1 - r, -r, 0), s.tegmenLength * 0.85 * k, s.tegmenWidth * 0.7 * k))
        p.openWing = 18
        let legs = s.legs, cerci = s.cerci, tipZ = (0.0025 - al * 1.8) * k
        p.extra = { rig, d, L in
            // Mandibles and palps.
            for side: Float in [1, -1] {
                rig.add(limb([V3(side * 0.0009 * k, y - 0.0030 * k, 0.0138 * k), V3(side * 0.0013 * k, y - 0.0042 * k, 0.0140 * k)], radii: [0.00018 * k, 0.0001 * k],
                             material: legs, sides: 4, per: 1), to: "head", lods: L)
                if cerci {
                    rig.add(limb([V3(side * 0.0008 * k, y + 0.0002 * k, tipZ + 0.0008 * k), V3(side * 0.0022 * k, y + 0.0012 * k, tipZ - 0.008 * k)], radii: [0.00022 * k, 0.00005 * k],
                                 material: legs, sides: 4, per: 1), to: "abdomen", lods: L)
                }
            }
        }
        return p
    }
}

public extension InsectKit {
    /// Segmented body (caterpillar, pill bug, centipede): `body` carries the head capsule,
    /// `segment-0...n-1` chain front to back (each parented to the one before, pivot at its front
    /// edge), legs `leg-l0...l2`/`leg-r0...r2` ride the first three segments and any further leg pairs
    /// are part of their segment's geometry.
    struct Segmented {
        public var name: String
        public var count: Int
        public var segLength: Float
        /// Cross-section semi-axes (x, y) by position 0 (front) ... 1 (rear).
        public var radius: (Float) -> V2
        public var centerY: (Float) -> Float
        public var material: (Int) -> MaterialKey
        /// Arched dorsal plates (pill bug): flat underside, segment overlaps.
        public var plates = false
        public var head: [InsectPlan.Blob] = []
        public var neck: V3 = .zero
        public var antenna: InsectPlan.Antenna?
        public var antennaMat: MaterialKey = "insect.chitin"
        /// Leg for segment i (left side) or nil; the first three non-nil become the named legs.
        public var leg: (Int) -> InsectKit.Leg? = { _ in nil }
        public var legMat: MaterialKey = "insect.chitin"
        /// Joint axis for segment bends and range in degrees.
        public var axis: V3 = V3(1, 0, 0)
        public var range: ClosedRange<Float> = -20...20
        /// Atlas UVs per segment (u around, v along 0...1) for banded materials.
        public var bandUV = false
        public var height: Float = 0.006
        public var extra: ((inout Rig, InsectKit.Detail, ClosedRange<Int>, (Int) -> Float) -> Void)?
        public var states: [RigState] = []
        public init(name: String, count: Int, segLength: Float, radius: @escaping (Float) -> V2, centerY: @escaping (Float) -> Float, material: @escaping (Int) -> MaterialKey) {
            self.name = name; self.count = count; self.segLength = segLength; self.radius = radius; self.centerY = centerY; self.material = material
        }
    }

    static func segmentName(_ i: Int) -> String { "segment-\(i)" }

    static func assemble(_ s: Segmented) -> Rig {
        var rig = Rig(name: s.name, lods: 2, switchDistances: [1.0])
        let n = s.count
        let z0 = Float(n) * s.segLength * 0.5
        func zFront(_ i: Int) -> Float { z0 - Float(i) * s.segLength }
        func t(_ i: Int) -> Float { n > 1 ? Float(i) / Float(n - 1) : 0 }
        rig.part("body", pivot: V3(0, s.centerY(0), z0), joint: .fixed)
        rig.part("head", parent: "body", pivot: s.neck, joint: .hinge(axis: V3(1, 0, 0), -25...25, duration: 0.3))
        for i in 0..<n {
            rig.part(segmentName(i), parent: i == 0 ? "body" : segmentName(i - 1), pivot: V3(0, s.centerY(t(i)), zFront(i)),
                     joint: .hinge(axis: s.axis, s.range, duration: 0.3))
        }
        var named: [(Int, Leg)] = []
        for i in 0..<n { if let l = s.leg(i), named.count < 3 { named.append((i, l)) } }
        for (k, (i, l)) in named.enumerated() {
            for side: Float in [1, -1] {
                rig.part(legName(side, k), parent: segmentName(i), pivot: side > 0 ? l.attach : mirror(l.attach), joint: .hinge(axis: .up, -35...35, duration: 0.25))
            }
        }
        if s.antenna != nil {
            rig.part("antenna-l", parent: "head", pivot: s.antenna!.base, joint: .hinge(axis: .up, -30...30, duration: 0.3))
            rig.part("antenna-r", parent: "head", pivot: mirror(s.antenna!.base), joint: .hinge(axis: .up, -30...30, duration: 0.3))
        }
        for lod in 0..<2 {
            let d = Detail(lod: lod), L = lod...lod
            for b in s.head {
                rig.add(blob(b.c, b.r, material: b.mat, sub: max(2, d.sub - 2), deform: b.deform), to: "head", lods: L)
                if b.mirror { rig.add(blob(mirror(b.c), b.r, material: b.mat, sub: max(2, d.sub - 2)), to: "head", lods: L) }
            }
            for i in 0..<n {
                let r = s.radius(t(i))
                let zc = zFront(i) - s.segLength * 0.5
                let len = s.segLength * (s.plates ? 0.72 : 0.62)
                var sf = blob(V3(0, s.centerY(t(i)), zc), V3(r.x, r.y, len), material: s.material(i), sub: d.sub - 1) { q in
                    s.plates ? V3(q.x, max(q.y, -r.y * 0.25) + (q.y > 0 ? 0 : 0), q.z) : q
                }
                if s.bandUV {
                    let cy = s.centerY(t(i))
                    sf.uvs = sf.positions.map { p in
                        V2((atan2(p.x, p.y - cy) / (2 * .pi) + 0.5) * 2, (p.z - (zc - len)) / (2 * len)) }
                    sf.computeTangents()
                }
                rig.add(sf, to: segmentName(i), lods: L)
                if let l = s.leg(i), !named.contains(where: { $0.0 == i }) {
                    for side: Float in [1, -1] {
                        var m = l; m.side = side; if side < 0 { m.attach = mirror(l.attach) }
                        rig.add(leg(m, material: s.legMat, d: Detail(lod: 1)), to: segmentName(i), lods: L)
                    }
                }
            }
            for (k, (_, l)) in named.enumerated() {
                for side: Float in [1, -1] {
                    var m = l; m.side = side; if side < 0 { m.attach = mirror(l.attach) }
                    rig.add(leg(m, material: s.legMat, d: d), to: legName(side, k), lods: L)
                }
            }
            if let a = s.antenna {
                for side: Float in [1, -1] {
                    rig.add(antenna(base: side > 0 ? a.base : mirror(a.base), dir: side > 0 ? a.dir : mirror(a.dir), length: a.length, radius: a.radius,
                                    curve: a.curve, side: side, elbow: a.elbow, club: a.club, beads: a.beads, material: s.antennaMat, d: d),
                            to: side > 0 ? "antenna-l" : "antenna-r", lods: L)
                }
            }
            s.extra?(&rig, d, L, { zFront($0) })
        }
        rig.states = s.states
        finish(&rig, height: s.height)
        return rig
    }

    /// Travelling-wave pose over the segments (phase 0 or 0.5 of a wavelength).
    static func wave(_ count: Int, amplitude: Float, wavelength: Float, phase: Float) -> [String: Float] {
        var j: [String: Float] = [:]
        for i in 0..<count { j[segmentName(i)] = amplitude * sin((Float(i) / wavelength + phase) * 2 * .pi) }
        return j
    }
}
