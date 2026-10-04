import simd
import Foundation

/// Modern batting helmet lying on the ground: glossy ABS shell with a short brim, a single ear flap on
/// the wearer's left (+X; right-handed batter, flap toward the pitcher) with a ringed ear hole, vent
/// holes on the crown, rubber trim around the opening and a black foam liner visible inside. The front
/// faces +Z. It rests where it would settle: on the flap, the back rim and the opposite rim.
public struct BattingHelmet: RealAsset {
    public static let id = "batting-helmet"
    public static let summary = "Modern batting helmet: glossy navy shell with a single left ear flap, vent holes, black foam liner showing at the rim."
    public static let tags = ["prop", "sports", "plastic"]
    public static let budget = 10000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 55, elevation: 22, distance: 0.9, studio: true)

    /// Shell half-width at the ears (m).
    public var halfWidth: Float = 0.104
    /// Shell half-length front to back (m).
    public var halfLength: Float = 0.128
    /// Dome height above the ear line (m).
    public var crown: Float = 0.116
    /// Shell material key (tint with `plastic.helmet:RRGGBB` for team colors).
    public var shell: MaterialKey = "plastic.helmet"
    /// Liner material key.
    public var liner: MaterialKey = "foam.liner"
    /// Edge trim material key.
    public var trim: MaterialKey = "rubber"
    /// true: flap on the left (right-handed batter); false: flap on the right.
    public var leftFlap: Bool = true
    public init() {}

    /// Rim depth below the ear line by azimuth (degrees, 0 = front, 90 = +X). Negative is above it.
    static let rimKeys: [(Float, Float)] = [
        (0, -0.03), (28, -0.026), (45, -0.004), (60, 0.06), (78, 0.112), (108, 0.116), (132, 0.066),
        (158, 0.044), (180, 0.05), (202, 0.044), (228, 0.034), (252, 0.014), (282, 0.012), (310, -0.002),
        (334, -0.026), (360, -0.03),
    ]

    static func rimDepth(_ deg: Float) -> Float {
        let d = deg.truncatingRemainder(dividingBy: 360) + (deg < 0 ? 360 : 0)
        for i in 1..<rimKeys.count where rimKeys[i].0 >= d {
            let (a0, v0) = rimKeys[i - 1], (a1, v1) = rimKeys[i]
            let t = (d - a0) / (a1 - a0), s = t * t * (3 - 2 * t)
            return v0 + (v1 - v0) * s
        }
        return rimKeys[0].1
    }

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, lod: 0), model(seed: seed, lod: 1)], switchDistances: [4])
    }

    func model(seed: UInt64, lod: Int) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let ax = halfWidth, az = halfLength, ay = crown, cy: Float = 0
        let flapSideSign: Float = leftFlap ? 1 : -1
        let cols = lod == 0 ? 64 : 32, rows = lod == 0 ? 22 : 12
        func equator(_ phi: Float) -> Float { 1 / ((sin(phi) / ax) * (sin(phi) / ax) + (cos(phi) / az) * (cos(phi) / az)).squareRoot() }
        // q in 0...1 runs the dome from the crown to the ear line; q > 1 runs down the flap / skirt.
        func point(_ phi: Float, _ q: Float) -> V3 {
            let dir = V3(sin(phi), 0, cos(phi)), r = equator(phi)
            // Slightly fuller at the back, flatter on top.
            let back = 1 + 0.06 * max(0, -cos(phi))
            if q <= 1 {
                let th = q * .pi / 2
                return dir * (r * back * sin(th)) + V3(0, cy + ay * pow(cos(th), 0.92), 0)
            }
            let d = (q - 1) * ay
            let inward = 1 - 0.1 * pow(d / 0.12, 1.6)
            return dir * (r * back * inward) + V3(0, cy - d, 0)
        }
        func qRim(_ phi: Float) -> Float {
            let flapSide: Float = leftFlap ? 1 : -1
            let deg = atan2(sin(phi) * flapSide, cos(phi)) * 180 / .pi
            let d = Self.rimDepth(deg < 0 ? deg + 360 : deg)
            return d >= 0 ? 1 + d / ay : acos(min(1, -d / ay)) / (.pi / 2)
        }
        // Outer shell grid.
        var outer = Surface(material: shell)
        for j in 0...rows { for i in 0...cols {
            let phi = Float(i) / Float(cols) * 2 * .pi, q = qRim(phi) * Float(j) / Float(rows)
            outer.add(point(phi, q), .up, V2(Float(i) / Float(cols) * 0.75, q * 0.2))
        }}
        let row = UInt32(cols + 1)
        for j in 0..<UInt32(rows) { for i in 0..<UInt32(cols) {
            let a = j * row + i
            outer.quad(a, a + row, a + row + 1, a + 1)
        }}
        outer.recomputeNormals(weldSeams: true)
        outer.computeTangents()
        // Pine-tar smears where the batter grabs the shell: the shell material's splat layer.
        // Each smear is a short streak down the shell (thumb drag), strongest at its start.
        let smears = (0..<2).map { k -> (V3, V3) in
            let phi = flapSideSign * rng.float(0.4...0.9) + (k == 1 ? .pi * 0.85 : 0), q = rng.float(0.4...0.6)
            return (point(phi, q), point(phi + rng.float(-0.15...0.15), q + 0.18))
        }
        outer.paintSplat { p in
            smears.reduce(Float(0)) { acc, s in
                let ab = s.1 - s.0, t = max(0, min(1, simd_dot(p - s.0, ab) / simd_length_squared(ab)))
                let d = simd_length(p - (s.0 + ab * t))
                return max(acc, exp(-d * d / (0.015 * 0.015)) * (0.8 - 0.4 * t))
            }
        }
        // Liner: the shell pushed 11 mm inward, faces flipped.
        var inner = outer
        inner.material = liner
        inner.positions = zip(outer.positions, outer.normals).map { $0 - $1 * 0.011 }
        inner = inner.flipped()
        // Rim trim: rubber bead over the cut edge between shell and liner.
        let rimIdx = (0..<cols).map { Int(rows) * (cols + 1) + $0 }
        let rimPath = rimIdx.map { outer.positions[$0] - outer.normals[$0] * 0.0055 }
        m.add(outer); m.add(inner)
        // Foam comfort band just inside the opening.
        let band = stride(from: 0, to: rimIdx.count, by: 2).map { rimIdx[$0] }.map { outer.positions[$0] - outer.normals[$0] * 0.016 + V3(0, 0.006, 0) }
        m.add(Prim.sweep(Shape2D.roundedRect(0.012, 0.014, radius: 0.004, segments: 1), along: band, closedPath: true, material: liner))
        m.add(Prim.sweep(Shape2D.circle(0.007, ry: 0.0058, segments: lod == 0 ? 8 : 5), along: rimPath, closedPath: true, material: trim))
        // Brim: a rounded slab wrapped around the front of the shell, widest at centre, drooping a little;
        // its inner edge is buried in the shell.
        let brimSpan: Float = 1.05, reach: Float = 0.05, th: Float = 0.011
        let brimY = cy - Self.rimDepth(0) - 0.005
        var brim = Prim.superellipsoid(V3(2, th, 1), exponent: 4, subdivisions: lod == 0 ? 10 : 6, material: shell)
        brim.deform { p in
            let phi = p.x * brimSpan, t = p.z + 0.5                     // t: 0 buried edge, 1 front edge
            let taper = pow(max(0, cos(phi / brimSpan * .pi / 2)), 1.1)
            let out = -0.012 + (reach + 0.012) * t * taper
            let r = equator(phi) + out, o = max(0, out)
            return V3(sin(phi) * r, brimY + p.y * (1 - 0.35 * t) - o * 0.3 - o * o * 4, cos(phi) * r)
        }
        m.add(brim)
        // Ear flap: ear hole (dark disc inside a rubber grommet) over the ear.
        let flapSide: Float = leftFlap ? 1 : -1
        let earPhi = flapSide * 96 * .pi / 180, earQ: Float = 1 + 0.055 / ay
        let ep = point(earPhi, earQ)
        let earN = simd_normalize(V3(sin(earPhi), -0.08, cos(earPhi)))
        m.add(Prim.cylinder(radius: 0.013, height: 0.002, bevel: 0.0005, segments: lod == 0 ? 20 : 10, material: liner),
              Xform(translation: ep - earN * 0.0005, rotation: facing(earN)))
        if lod == 0 {
            m.add(Prim.torus(major: 0.0145, minor: 0.0028, segments: 24, sides: 6, material: trim),
                  Xform(translation: ep + earN * 0.001, rotation: facing(earN)))
            // Vent holes: dark ovals set into the crown, front pair, top pair, rear pair.
            let vents: [(Float, Float)] = [(-22, 0.42), (22, 0.42), (-58, 0.5), (58, 0.5), (-160, 0.52), (160, 0.52), (180, 0.36)]
            for (deg, q) in vents {
                let phi = deg * .pi / 180
                let p = point(phi, q)
                let n = simd_normalize(simd_cross(point(phi, q + 0.02) - p, point(phi + 0.02, q) - p))
                let nn = simd_dot(n, p - V3(0, cy, 0)) > 0 ? n : -n
                // Long axis of the oval follows the meridian.
                let along = simd_normalize(point(phi, q + 0.02) - p)
                let rot = facing(nn)
                let local = rot.inverse.act(along)
                let yaw = atan2(-local.z, local.x)
                m.add(Prim.superellipsoid(V3(0.024, 0.003, 0.01), exponent: 2.4, subdivisions: 3, material: liner),
                      Xform(translation: p - nn * 0.0011, rotation: rot * simd_quatf(angle: yaw, axis: .up)))
            }
        }
        // Settle on the ground: pick the roll/pitch with the lowest centre of mass.
        let probe = outer.positions + brim.positions
        let com = V3(0, cy + ay * 0.25, -0.01)
        var best = (Float.infinity, simd_quatf(angle: 0, axis: .up))
        for a in stride(from: Float(0), through: 40, by: 1) { for b in stride(from: Float(-20), through: 20, by: 1) {
            let q = simd_quatf(degrees: b, axis: V3(1, 0, 0)) * simd_quatf(degrees: a * flapSide, axis: V3(0, 0, 1))
            let minY = probe.reduce(Float.infinity) { min($0, q.act($1).y) }
            let h = q.act(com).y - minY
            if h < best.0 { best = (h, q) }
        }}
        m = m.transformed(Xform(rotation: simd_quatf(degrees: rng.float(-10...10), axis: .up) * best.1))
        let bb = m.bounds
        m = m.transformed(Xform(translation: V3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2)))
        groundAO(&m, height: 0.06, floor: 0.5)
        return m
    }
}
