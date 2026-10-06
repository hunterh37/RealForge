import simd
import Foundation

/// Wraparound safety glasses (ANSI Z87.1 style), standing on the lens bottom and the temple tips:
/// one-piece 2.2 mm clear polycarbonate shield wrapped on an ellipse (148 mm across, 39 mm of wrap into
/// integral side shields), nose bridge cutout with a grey rubber nose pad, molded yellow brow bar, hinge
/// blocks at the shield ends, 145 mm yellow temples tapering to a ribbed ear bend. Story detail: sawdust
/// caught on the brow bar. Front faces +Z.
/// Rig: `temple-right` (+X side) and `temple-left` hinge about Y at the hinge blocks; 0 = open.
/// States `folded` (default, right folds first, left over it) and `open`.
public struct SafetyGlasses: RealArticulated {
    public static let id = "safety-glasses"
    public static let summary = "Wraparound clear polycarbonate safety glasses: one-piece shield with side shields, brow bar, rubber nose pad, hinged yellow temples."
    public static let tags = ["prop", "workshop", "handheld", "articulated", "plastic", "rubber"]
    public static let budget = 7_400
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 24, distance: 0.42, studio: true)

    /// Shield wrap half-width and depth (m): ellipse semi-axes in X and Z.
    public var wrap = V2(0.074, 0.05)
    /// Shield end angle on the wrap ellipse (radians).
    public var wrapAngle: Float = 1.35
    /// Lens thickness (m).
    public var lensThickness: Float = 0.0022
    /// Lens height at the brow (m, from the lowest edge).
    public var lensHeight: Float = 0.048
    /// Temple length from the hinge (m).
    public var templeLength: Float = 0.145
    public var lens: MaterialKey = "plastic.lens-clear"
    /// Lens edge finish.
    public var lensEdge: MaterialKey = "plastic.frosted"
    /// Frame (brow bar, hinge blocks, temples) plastic.
    public var frameMaterial: MaterialKey = "plastic.matte:E2A60E"
    public var noseMaterial: MaterialKey = "rubber:55585B"
    /// Fold angles of the `folded` state (degrees): right, left.
    public var foldAngles = V2(88, 80)
    public init() {}

    // MARK: shape

    var z0: Float { 0.026 }
    func front(_ phi: Float) -> V2 { V2(wrap.x * sin(phi), wrap.y * (cos(phi) - 1) + z0) }        // (x, z)
    func normal(_ phi: Float) -> V2 { simd_normalize(V2(wrap.y * sin(phi), wrap.x * cos(phi))) }
    func top(_ phi: Float) -> Float { lensHeight - 0.005 * pow(abs(phi) / wrapAngle, 2) }
    func bottom(_ phi: Float) -> Float {
        let u = abs(phi) / wrapAngle
        var y = 0.010 * pow(max(0, u - 0.25) / 0.75, 2) + 0.013 * pow(u, 6)
        if abs(phi) < 0.27 { y += 0.019 * pow(cos(.pi / 2 * abs(phi) / 0.27), 1.4) }
        return y
    }
    /// Hinge pivot, right side (+X); the left mirrors it.
    var hinge: V3 {
        let e = front(wrapAngle)
        return V3(e.x + 0.0022, 0.035, e.y - 0.0035)
    }
    /// Lateral offsets of the temples from their hinge axes (m): the left sits farther out so it folds over the right.
    var templeOffset: V2 { V2(0.0024, 0.0058) }

    // MARK: public points

    /// Nose bridge: top of the nose cutout, on the inner lens face (asset space).
    public var bridge: V3 { let f = front(0); return V3(0, bottom(0) + 0.002, f.y - lensThickness) }
    /// Pinch point on the brow bar center (asset space).
    public var grip: V3 { let f = front(0); return V3(0, top(0) - 0.003, f.y + 0.002) }

    public func rig(seed: UInt64) -> Rig {
        let rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [1.5])
        let t = lensThickness

        for l in 0..<2 {
            var m = Model(name: Self.id)
            let C = l == 0 ? 44 : 22, R = l == 0 ? 5 : 3
            // Shield: front and back grids plus the edge band.
            var s = Surface(material: lens)
            func p(_ phi: Float, _ v: Float, _ back: Bool) -> V3 {
                let f = front(phi), n = normal(phi)
                let y = bottom(phi) + (top(phi) - bottom(phi)) * v
                let q = back ? f - n * t : f
                return V3(q.x, y, q.y)
            }
            let phis = (0...C).map { -wrapAngle + 2 * wrapAngle * Float($0) / Float(C) }
            for back in [false, true] {
                let base = UInt32(s.positions.count)
                for j in 0...R { for phi in phis { let q = p(phi, Float(j) / Float(R), back); s.add(q, .up, V2(q.x, q.y)) } }
                let row = UInt32(C + 1)
                for j in 0..<UInt32(R) { for i in 0..<UInt32(C) {
                    let a = base + j * row + i
                    back ? s.quad(a, a + row, a + row + 1, a + 1) : s.quad(a, a + 1, a + row + 1, a + row)
                }}
            }
            // Edge band around the perimeter (bottom left->right, right end up, top right->left, left end down).
            var ring: [(Float, Float)] = phis.map { ($0, 0) }
            for j in 1..<R { ring.append((wrapAngle, Float(j) / Float(R))) }
            ring += phis.reversed().map { ($0, 1) }
            for j in (1..<R).reversed() { ring.append((-wrapAngle, Float(j) / Float(R))) }
            s.recomputeNormals(weldSeams: false)
            s.computeTangents()
            m.add(s)
            // Molded edge: frosted, so the shield outline catches light.
            var edge = Surface(material: lensEdge)
            for (phi, v) in ring { let a = p(phi, v, false), b = p(phi, v, true); edge.add(a, .up, V2(a.x, 0)); edge.add(b, .up, V2(a.x, t)) }
            let n = UInt32(ring.count)
            for i in 0..<n { let a = 2 * i, b = 2 * ((i + 1) % n); edge.quad(a, a + 1, b + 1, b) }
            edge.recomputeNormals(weldSeams: false)
            edge.computeTangents()
            m.add(edge)

            // Brow bar along the top front edge, ends tucked into the hinge blocks.
            let pb = wrapAngle - 0.06
            let browPath = (0...(l == 0 ? 22 : 10)).map { k -> V3 in
                let phi = -pb + 2 * pb * Float(k) / Float(l == 0 ? 22 : 10)
                let f = front(phi), nn = normal(phi)
                let q = f + nn * 0.0004
                return V3(q.x, top(phi) - 0.0016, q.y)
            }
            let browProf = Shape2D.rounded([V2(-0.0026, -0.0006), V2(0.0026, -0.0006), V2(0.0030, 0.0016), V2(0.0018, 0.0024), V2(-0.0028, 0.0010)], radius: 0.0007, segments: 1)
            m.add(Prim.sweep(browProf, along: browPath, up: V3(0, 1, 0), material: frameMaterial))
            // Hinge blocks: bridge the shield end to the hinge barrel.
            let h = hinge
            for side: Float in [-1, 1] {
                let e = front(wrapAngle * side)
                let mid = V3((e.x + h.x * side) / 2, h.y, (e.y + h.z) / 2)
                let dir = simd_normalize(V3(h.x * side - e.x, 0, h.z - e.y))
                let yaw = atan2(dir.x, dir.z)
                m.add(Prim.roundedBox(V3(0.0062, 0.016, 0.012), radius: 0.0018, bevelSegments: l == 0 ? 2 : 1, material: frameMaterial),
                      Xform(translation: mid + V3(side * 0.0012, 0.002, 0.001), rotation: simd_quatf(angle: yaw, axis: V3(0, 1, 0))))
                // Hinge barrel and pin cap.
                m.add(Prim.cylinder(radius: 0.0022, height: 0.0055, bevel: 0.0006, segments: 10, bevelSegments: 1, material: frameMaterial),
                      Xform(translation: V3(h.x * side, h.y + 0.0042, h.z)))
                m.add(Prim.cylinder(radius: 0.0022, height: 0.0055, bevel: 0.0006, segments: 10, bevelSegments: 1, material: frameMaterial),
                      Xform(translation: V3(h.x * side, h.y - 0.0097, h.z)))
                if l == 0 {
                    m.add(Prim.cylinder(radius: 0.0011, height: 0.0006, bevel: 0.0002, segments: 8, bevelSegments: 1, material: "metal.steel"),
                          Xform(translation: V3(h.x * side, h.y + 0.0096, h.z)))
                }
            }
            // Rubber nose pad following the cutout behind the lens.
            let np = (0...(l == 0 ? 16 : 8)).map { k -> V3 in
                let phi = -0.17 + 0.34 * Float(k) / Float(l == 0 ? 16 : 8)
                let f = front(phi), nn = normal(phi)
                let q = f - nn * (t + 0.0018)
                return V3(q.x, bottom(phi) + 0.0016, q.y)
            }
            m.add(Prim.sweep(Shape2D.circle(0.0028, ry: 0.0019, segments: l == 0 ? 10 : 6), along: np, up: V3(0, 1, 0),
                             scales: np.indices.map { i in 0.75 + 0.25 * sin(Float(i) / Float(np.count - 1) * .pi) }, material: noseMaterial))
            // Story detail: sawdust on the brow bar and hairline scratches on the shield front.
            if l == 0 {
                var d = rng.fork(9)
                var sc = Surface(material: lensEdge)
                for _ in 0..<7 {
                    let phi0 = d.float(-0.8...0.8), v0 = d.float(0.35...0.85), dphi = d.float(-0.12...0.12), dv = d.float(-0.15...0.15)
                    let base = UInt32(sc.positions.count)
                    for k in 0...4 {
                        let u = Float(k) / 4, phi = phi0 + dphi * u, v = v0 + dv * u
                        let q = p(phi, v, false), nn = normal(phi)
                        let o = V3(nn.x, 0, nn.y) * 0.00006
                        let w = V3(0, 0.00012, 0)
                        sc.add(q + o - w, V3(nn.x, 0, nn.y), V2(u, 0)); sc.add(q + o + w, V3(nn.x, 0, nn.y), V2(u, 1))
                    }
                    for k in 0..<UInt32(4) { let a = base + k * 2; sc.quad(a, a + 2, a + 3, a + 1) }
                }
                sc.computeTangents()
                m.add(sc)
                for _ in 0..<10 {
                    let phi = d.float(-0.55...0.15)
                    let f = front(phi), nn = normal(phi)
                    let q = f + nn * d.float(0.0006...0.0026)
                    m.add(Prim.superellipsoid(V3(d.float(0.0010...0.0024), 0.0006, d.float(0.0007...0.0014)), exponent: 2.5, subdivisions: 2, material: "wood.sawdust"),
                          Xform(translation: V3(q.x, top(phi) + 0.0009, q.y), rotation: simd_quatf(angle: d.float(0...3), axis: V3(0, 1, 0))))
                }
            }
            rig.base[l] = m
        }

        // MARK: temples
        let h = hinge
        for (name, side, off) in [("temple-right", Float(1), templeOffset.x), ("temple-left", Float(-1), templeOffset.y)] {
            let piv = V3(h.x * side, h.y, h.z)
            rig.part(name, pivot: piv, joint: .hinge(axis: V3(0, side, 0), 0...95, duration: 0.5))
            for l in 0..<2 {
                // Path: from the hinge back, slight inward splay and drop, then the ear bend down to the bench.
                let L = templeLength
                let x0 = piv.x + side * off
                let ctrl: [V3] = [V3(x0, h.y - 0.0025, h.z + 0.002), V3(x0 - side * 0.0015, h.y - 0.003, h.z - 0.04), V3(x0 - side * 0.0045, h.y - 0.006, h.z - L * 0.62),
                                  V3(x0 - side * 0.0065, h.y - 0.010, h.z - L * 0.80), V3(x0 - side * 0.0075, h.y - 0.019, h.z - L * 0.92), V3(x0 - side * 0.0078, 0.0045, h.z - L * 0.975)]
                let path = catmull(ctrl, per: l == 0 ? 5 : 3)
                let sc = path.indices.map { i -> Float in 1 - 0.38 * Float(i) / Float(path.count - 1) }
                let prof = Shape2D.roundedRect(0.0105, 0.0032, radius: 0.0013, segments: l == 0 ? 2 : 1)
                rig.add(Prim.sweep(prof, along: path, up: V3(0, 1, 0), scales: sc, material: frameMaterial), to: name, lods: l...l)
                // Hinge knuckle on the temple.
                rig.add(Prim.cylinder(radius: 0.0021, height: 0.0066, bevel: 0.0005, segments: 10, bevelSegments: 1, material: frameMaterial),
                        Xform(translation: V3(piv.x, h.y - 0.0035, piv.z)), to: name, lods: l...l)
                rig.add(Prim.roundedBox(V3(0.0032, 0.0062, 0.0048), radius: 0.0009, bevelSegments: 1, material: frameMaterial),
                        Xform(translation: V3((piv.x + x0) / 2, h.y - 0.0004, piv.z + 0.0004)), to: name, lods: l...l)
                // Grip ribs before the ear bend (outer face).
                if l == 0 {
                    for k in 0..<6 {
                        let z = h.z - L * 0.66 - Float(k) * 0.0055
                        let u = (h.z - z) / L
                        let y = h.y - 0.006 - (u - 0.62) / 0.18 * 0.004
                        let x = x0 - side * (0.0045 + (u - 0.62) / 0.18 * 0.002) + side * 0.0016
                        rig.add(Prim.roundedBox(V3(0.0012, 0.0062 * (1 - 0.3 * u), 0.0016), radius: 0.0005, bevelSegments: 1, material: noseMaterial),
                                Xform(translation: V3(x, y, z)), to: name, lods: 0...0)
                    }
                }
            }
        }
        groundAO(&rig, height: 0.02, floor: 0.65)
        rig.states = [RigState("folded", ["temple-right": foldAngles.x, "temple-left": foldAngles.y]), RigState("open")]
        return rig
    }
}
