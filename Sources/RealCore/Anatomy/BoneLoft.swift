import simd

/// Lofted long-bone surface in a bone frame: y along the bone, x radial, z dorsal (right hand).
/// Cross sections are superellipses with separate dorsal and palmar exponents (D-shaped phalanx
/// shafts, the palmar ridge of a metacarpal), stations are interpolated with Catmull-Rom, and both
/// ends close with articular caps: a convex condyle, a concave fossa with a lip, a saddle, or a
/// bicondylar trochlea with its intercondylar groove. Local bumps and ridges add tubercles,
/// collateral recesses and the flexor sheath crests.
public struct BoneLoft: Sendable {
    public struct Station: Sendable {
        public var s: Float
        public var w: Float, d: Float
        /// Center offset: x radial, z dorsal.
        public var dx: Float = 0, dz: Float = 0
        /// Superellipse exponents (2 = ellipse, > 2 boxier, < 2 pointier) for the dorsal and palmar halves.
        public var nDorsal: Float = 2.2, nPalmar: Float = 2.2
        public init(_ s: Float, w: Float, d: Float, dx: Float = 0, dz: Float = 0, nDorsal: Float = 2.2, nPalmar: Float = 2.2) {
            self.s = s; self.w = w; self.d = d; self.dx = dx; self.dz = dz; self.nDorsal = nDorsal; self.nPalmar = nPalmar
        }
    }

    public struct Cap: Sendable {
        /// Axial extent; positive bulges outward (condyle), negative is a concave fossa.
        public var depth: Float
        /// Intercondylar groove (+) or median ridge (-) along x = 0, meters, and its half width as a fraction of w.
        public var groove: Float = 0
        public var grooveWidth: Float = 0.18
        /// Saddle: axial offset k * ((x/w)^2 - (z/d)^2), meters (first CMC joint).
        public var saddle: Float = 0
        /// Extra palmar reach of a condyle (metacarpal heads extend onto the palmar side).
        public var palmarReach: Float = 0
        public var articular = true
        public init(depth: Float, groove: Float = 0, grooveWidth: Float = 0.18, saddle: Float = 0, palmarReach: Float = 0, articular: Bool = true) {
            self.depth = depth; self.groove = groove; self.grooveWidth = grooveWidth; self.saddle = saddle; self.palmarReach = palmarReach; self.articular = articular
        }
    }

    /// Ellipsoidal bump (+) or pit (-) displaced along the surface normal.
    public struct Bump: Sendable {
        public var center: V3, radius: V3, amount: Float
        public init(_ center: V3, radius: V3, amount: Float) { self.center = center; self.radius = radius; self.amount = amount }
    }

    public var y0: Float, y1: Float
    public var stations: [Station]
    public var base: Cap, head: Cap
    public var bumps: [Bump] = []
    /// Periosteal micro relief, meters.
    public var roughness: Float = 0.00012
    public var seed: UInt32 = 1
    public var sides = 40, rings = 46, capRings = 9

    public init(y0: Float, y1: Float, stations: [Station], base: Cap, head: Cap) {
        self.y0 = y0; self.y1 = y1; self.stations = stations; self.base = base; self.head = head
    }

    // Catmull-Rom over non-uniform stations, clamped at the ends.
    private func interp(_ s: Float, _ f: (Station) -> Float) -> Float {
        let st = stations
        if s <= st[0].s { return f(st[0]) }
        if s >= st[st.count - 1].s { return f(st[st.count - 1]) }
        var i = 0
        while i < st.count - 2 && s > st[i + 1].s { i += 1 }
        let p1 = f(st[i]), p2 = f(st[i + 1])
        let p0 = i > 0 ? f(st[i - 1]) : p1 - (p2 - p1)
        let p3 = i + 2 < st.count ? f(st[i + 2]) : p2 + (p2 - p1)
        let t = (s - st[i].s) / max(1e-6, st[i + 1].s - st[i].s)
        let t2 = t * t, t3 = t2 * t
        return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
    }

    private struct Ring { var w, d, dx, dz, nD, nP, y: Float }

    private func ring(_ s: Float) -> Ring {
        Ring(w: max(1e-4, interp(s) { $0.w }), d: max(1e-4, interp(s) { $0.d }), dx: interp(s) { $0.dx }, dz: interp(s) { $0.dz },
             nD: interp(s) { $0.nDorsal }, nP: interp(s) { $0.nPalmar }, y: lerp(y0, y1, s))
    }

    @inline(__always) private func superPoint(_ a: Float, _ r: Ring) -> V2 {
        let c = cos(a), sn = sin(a)
        let n = sn >= 0 ? r.nD : r.nP
        let e = 2 / max(0.5, n)
        return V2((c < 0 ? -1 : 1) * pow(abs(c), e) * r.w / 2, (sn < 0 ? -1 : 1) * pow(abs(sn), e) * r.d / 2)
    }

    /// Builds the bone. `cartilage` receives the articular caps (nil: everything goes to `bone`).
    public func build(bone: MaterialKey, cartilage: MaterialKey?) -> [Surface] {
        var all = Surface(material: bone)
        // Ring parameters: base cap (pole first), shaft, head cap (pole last).
        struct RingSpec { var s: Float; var cap: Int; var phi: Float }   // cap: -1 base, 0 shaft, 1 head
        var specs: [RingSpec] = []
        for k in stride(from: capRings, through: 1, by: -1) { specs.append(RingSpec(s: 0, cap: -1, phi: Float(k) / Float(capRings) * .pi / 2)) }
        for i in 0..<rings {
            // Denser rings near the ends where curvature lives.
            let u = Float(i) / Float(rings - 1)
            let s = 0.45 * u + 0.55 * (0.5 - 0.5 * cos(u * .pi))
            specs.append(RingSpec(s: min(1, max(0, s)), cap: 0, phi: 0))
        }
        for k in 1...capRings { specs.append(RingSpec(s: 1, cap: 1, phi: Float(k) / Float(capRings) * .pi / 2)) }

        let row = sides + 1
        var capFlag: [Bool] = []
        for spec in specs {
            let r = ring(spec.s)
            let cap = spec.cap < 0 ? base : head
            let shrink = spec.cap == 0 ? 1 : cos(spec.phi)
            let lift = spec.cap == 0 ? 0 : sin(spec.phi)
            for j in 0...sides {
                let a = Float(j) / Float(sides) * 2 * .pi
                let q = superPoint(a, r) * shrink
                var y = r.y
                if spec.cap != 0 {
                    let xn = q.x / (r.w / 2), zn = q.y / (r.d / 2)
                    let u = spec.phi / (.pi / 2)
                    // Concave fossa: rounded lip rolling over before the dish.
                    var ax = cap.depth >= 0 ? cap.depth * lift : (0.25 * -cap.depth + 0.0006) * sin(u * .pi) + cap.depth * u * u
                    ax += cap.saddle * (xn * xn - zn * zn) * lift
                    ax -= cap.groove * exp(-pow(q.x / (cap.grooveWidth * r.w), 2)) * lift
                    // Palmar reach: the palmar half of a condyle rolls further around the end.
                    if zn < 0 { ax += cap.palmarReach * (-zn) * (1 - lift) * lift * 2 }
                    y += spec.cap < 0 ? -ax : ax
                }
                var p = V3(r.dx + q.x, y, r.dz + q.y)
                // Bumps and relief along the section's outward direction.
                var out = V3(q.x / (r.w * r.w), 0, q.y / (r.d * r.d))
                out = simd_length(out) < 1e-9 ? V3(0, spec.cap < 0 ? -1 : 1, 0) : out.normalized
                if spec.cap != 0 { out = simd_normalize(out * shrink + V3(0, spec.cap < 0 ? -1 : 1, 0) * (lift + 0.2)) }
                var disp: Float = 0
                for b in bumps {
                    let dd = (p - b.center) / b.radius
                    disp += b.amount * exp(-simd_length_squared(dd))
                }
                disp += roughness * Noise.fbm(p * 900, octaves: 3, seed: seed)
                p += out * disp
                all.add(p, out, V2(a / (2 * .pi) * .pi * (r.w + r.d) / 2, y))
            }
            let capCore = spec.cap != 0 && spec.phi / (.pi / 2) >= ((spec.cap < 0 ? base : head).depth >= 0 ? 0.2 : 0.3)
            capFlag.append(capCore)
        }
        for i in 0..<(specs.count - 1) {
            for j in 0..<sides {
                let a = UInt32(i * row + j)
                all.quad(a, a + UInt32(row), a + UInt32(row) + 1, a + 1)
            }
        }
        all.recomputeNormals()
        all.bakeCavityAO(strength: 0.8, floor: 0.55)
        all.computeTangents()
        guard let cartilage else { return [all] }
        // Split triangles: quads between two cap rings (or the rim and the first cap ring) are articular.
        var b = Surface(material: bone), c = Surface(material: cartilage)
        var mapB: [UInt32: UInt32] = [:], mapC: [UInt32: UInt32] = [:]
        func take(_ dst: inout Surface, _ map: inout [UInt32: UInt32], _ i: UInt32) -> UInt32 {
            if let m = map[i] { return m }
            let k = Int(i)
            let n = dst.add(all.positions[k], all.normals[k], all.uvs[k])
            dst.occlusion[Int(n)] = all.occlusion[k]
            dst.tangents.append(all.tangents[k])
            map[i] = n
            return n
        }
        for t in stride(from: 0, to: all.indices.count, by: 3) {
            let tri = [all.indices[t], all.indices[t + 1], all.indices[t + 2]]
            let ringIdx = Int(tri[0]) / row
            let nextCap = ringIdx + 1 < capFlag.count ? capFlag[ringIdx + 1] : true
            let isBase = ringIdx < capRings
            let inCap = capFlag[ringIdx] && nextCap
            let articular = inCap && (isBase ? base.articular : head.articular)
            if articular { c.tri(take(&c, &mapC, tri[0]), take(&c, &mapC, tri[1]), take(&c, &mapC, tri[2])) }
            else { b.tri(take(&b, &mapB, tri[0]), take(&b, &mapB, tri[1]), take(&b, &mapB, tri[2])) }
        }
        return [b, c].filter { !$0.isEmpty }
    }
}

public extension Surface {
    /// Mirror across x = 0 keeping faces outward (right-hand mesh -> left-hand mesh).
    func mirroredX() -> Surface {
        var s = self
        s.positions = positions.map { V3(-$0.x, $0.y, $0.z) }
        s.normals = normals.map { V3(-$0.x, $0.y, $0.z) }
        if tangents.count == positions.count { s.tangents = tangents.map { V4(-$0.x, $0.y, $0.z, -$0.w) } }
        for t in stride(from: 0, to: s.indices.count, by: 3) { s.indices.swapAt(t + 1, t + 2) }
        return s
    }
}

public extension Model {
    func mirroredX() -> Model { Model(name: name, surfaces: surfaces.map { $0.mirroredX() }) }
}
