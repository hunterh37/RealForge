import simd
import Foundation

// Small-part builders for photoreal props (RealityHD 3). Each returns a Surface in local space or adds
// directly to a Model. Real hardware sizes are the defaults.

/// Rotation taking +Y to `n`.
public func facing(_ n: V3) -> simd_quatf { simd_quatf(from: .up, to: simd_normalize(n)) }

/// Domed fastener head (rivet, nailhead, carriage bolt) at `p`, sitting on a surface with normal `n`.
/// Default 11 mm dome: upholstery nailhead. Sinks 0.5 mm into the surface so it never floats.
public func rivet(_ m: inout Model, at p: V3, normal n: V3, radius r: Float = 0.0055, height h: Float? = nil,
                  segments: Int = 8, material: MaterialKey) {
    let hh = h ?? r * 0.6
    var prof: [V2] = [V2(0, -0.0005), V2(r, -0.0005)]
    for k in 0...3 { let t = Float(k) / 3 * .pi / 2; prof.append(V2(r * cos(t), hh * sin(t))) }
    m.add(Prim.lathe(prof, segments: segments, seamTile: 0.05, material: material), Xform(translation: p, rotation: facing(n)))
}

/// Rivets every `spacing` meters along a polyline, on a surface with normal `normal(p)`.
public func rivetRow(_ m: inout Model, along path: [V3], spacing: Float, normal: (V3) -> V3, radius: Float = 0.0055,
                     material: MaterialKey) {
    for p in resample(path, spacing: spacing) { rivet(&m, at: p, normal: normal(p), radius: radius, material: material) }
}

/// Hex bolt head with washer, axis along `n`. `size` is across-flats (M8 = 13 mm).
public func hexBolt(_ m: inout Model, at p: V3, normal n: V3, size: Float = 0.013, material: MaterialKey) {
    let q = facing(n)
    m.add(Prim.cylinder(radius: size * 0.85, height: 0.0015, bevel: 0.0004, segments: 16, material: material),
          Xform(translation: p, rotation: q))
    let hex = Shape2D.rounded(Shape2D.polygon(sides: 6, radius: size / sqrt(3)), radius: size * 0.06, segments: 1)
    let head = Prim.extrude(hex, depth: size * 0.55, bevel: size * 0.06, bevelSegments: 1, material: material)
    m.add(head, Xform(translation: p + simd_normalize(n) * (0.0015 + size * 0.275), rotation: q * simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
}

/// Saddle stitches along a path lying on a surface with normal `normal(p)`: short raised thread
/// capsules with gaps (leather goods, upholstery). 3.5 mm pitch, 0.6 mm thread by default.
public func stitches(along path: [V3], normal: (V3) -> V3, pitch: Float = 0.0035, thread: Float = 0.0006,
                     material: MaterialKey) -> Surface {
    var s = Surface(material: material)
    let pts = resample(path, spacing: pitch)
    guard pts.count > 1 else { return s }
    for i in 0..<(pts.count - 1) {
        let a = pts[i], b = pts[i + 1], n = simd_normalize(normal(a))
        let d = b - a, len = simd_length(d) * 0.7
        let mid = (a + b) / 2 + n * thread * 0.4
        let dir = d / max(simd_length(d), 1e-6)
        let tilt = simd_normalize(dir + simd_cross(n, dir) * 0.25)   // saddle stitches lean
        let st = Prim.tube([mid - tilt * len / 2, mid + tilt * len / 2], radii: [thread, thread], sides: 3, seamTile: 0.01,
                           material: material, capEnd: false)
        s.append(st)
    }
    return s
}

/// Resamples a polyline to points `spacing` meters apart (first point kept).
public func resample(_ path: [V3], spacing: Float) -> [V3] {
    guard path.count > 1, spacing > 0 else { return path }
    var out = [path[0]], carry: Float = 0
    for i in 1..<path.count {
        let a = path[i - 1], b = path[i], seg = simd_distance(a, b)
        var t = spacing - carry
        while t <= seg { out.append(a + (b - a) * (t / seg)); t += spacing }
        carry = seg - (t - spacing)
    }
    return out
}

/// Bar pull handle (drawer, cabinet): round bar on two standoff posts, along +X, posts toward -Z
/// from the bar to a mounting face at z = 0. Centered on X.
public func barHandle(length: Float = 0.128, standoff: Float = 0.032, radius: Float = 0.005, overhang: Float = 0.02,
                      material: MaterialKey) -> Surface {
    var s = Surface(material: material)
    let half = length / 2
    s.append(Prim.cylinder(radius: radius, height: length + 2 * overhang, bevel: radius * 0.6, segments: 16, material: material),
             Xform(translation: V3(-half - overhang, 0, standoff), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
    for x in [-half, half] {
        s.append(Prim.cylinder(radius: radius * 0.85, height: standoff, bevel: 0.0008, segments: 12, material: material),
                 Xform(translation: V3(x, 0, 0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
    }
    return s
}

/// Chain of oval links along a path; links alternate 90 degrees. `wire` = bar radius,
/// link inner length about 3.5x wire diameter (DIN 766 short link).
public func chain(along path: [V3], wire: Float = 0.006, material: MaterialKey, seed: UInt64 = 1) -> Surface {
    var s = Surface(material: material)
    let pitch = wire * 2 * 3.5
    let pts = resample(path, spacing: pitch)
    guard pts.count > 1 else { return s }
    let w = wire * 2 * 1.75
    let link = Prim.sweep(Shape2D.circle(wire, segments: 8),
                          along: Shape2D.roundedRect(pitch + wire * 2, w + wire * 2, radius: w / 2 + wire * 0.99, segments: 5).map { V3($0.x, $0.y, 0) },
                          up: V3(0, 0, 1), closedPath: true, caps: false, material: material)
    var rng = SeededRNG(seed: seed)
    for i in 0..<(pts.count - 1) {
        let a = pts[i], b = pts[i + 1], d = simd_normalize(b - a)
        let roll = Float(i % 2) * .pi / 2 + rng.float(-0.15...0.15)
        let q = simd_quatf(angle: roll, axis: d) * simd_quatf(from: V3(1, 0, 0), to: d)
        s.append(link, Xform(translation: (a + b) / 2, rotation: q))
    }
    return s
}

/// Swivel caster: plate, fork, rubber wheel. Wheel bottom at y = 0, plate top at `height`.
public func caster(_ m: inout Model, at p: V3, height: Float = 0.1, wheelRadius: Float = 0.036, yaw: Float = 0,
                   frame: MaterialKey, wheel: MaterialKey, hub: MaterialKey) {
    let q = simd_quatf(degrees: yaw, axis: .up)
    func X(_ t: V3, _ r: simd_quatf = .identity) -> Xform { Xform(translation: p + q.act(t), rotation: q * r) }
    let plate = Shape2D.roundedRect(0.064, 0.064, radius: 0.006, segments: 2)
    m.add(Prim.extrude(plate, depth: 0.003, bevel: 0.001, bevelSegments: 1, material: frame), X(V3(0, height - 0.0015, 0), simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
    m.add(Prim.cylinder(radius: 0.02, height: 0.01, bevel: 0.002, segments: 16, material: frame), X(V3(0, height - 0.013, 0)))
    let off: Float = wheelRadius * 0.35
    let forkH = height - 0.013 - wheelRadius
    for side: Float in [-1, 1] {
        let leg = Shape2D.roundedRect(0.026, 0.0025, radius: 0.001, segments: 1)
        let path = [V3(0, height - 0.013, side * 0.016), V3(off * 0.5, wheelRadius + forkH * 0.5, side * 0.016), V3(off, wheelRadius, side * 0.016)]
        m.add(Prim.sweep(leg, along: catmull(path, per: 3), up: V3(0, 0, 1), material: frame), X(.zero))
    }
    let tire = Prim.torus(major: wheelRadius - 0.008, minor: 0.008, segments: 18, sides: 6, minorY: 0.011, material: wheel)
    m.add(tire, X(V3(off, wheelRadius, 0), simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
    m.add(Prim.cylinder(radius: wheelRadius - 0.012, height: 0.02, bevel: 0.002, segments: 12, bevelSegments: 1, material: hub),
          X(V3(off, wheelRadius, -0.01), simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
    m.add(Prim.cylinder(radius: 0.004, height: 0.036, bevel: 0.001, segments: 8, material: frame),
          X(V3(off, wheelRadius, -0.018), simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
}

/// Woven-cane style lattice is a material (`cane.woven`); this lays a thin seat panel with a rolled
/// edge bead around a closed outline in the XZ plane at height y (chair seats, basket bottoms).
public func panelWithBead(_ m: inout Model, outline: [V2], y: Float, thickness: Float = 0.004, bead: Float = 0.006,
                          panel: MaterialKey, beadMaterial: MaterialKey) {
    let s = Prim.extrude(outline, depth: thickness, bevel: thickness * 0.3, bevelSegments: 1, material: panel)
    m.add(s, Xform(translation: V3(0, y, 0), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
    let ring = Shape2D.offset(outline, -bead * 0.6).map { V3($0.x, y + thickness * 0.5, -$0.y) }
    m.add(Prim.sweep(Shape2D.circle(bead, segments: 8), along: ring, closedPath: true, caps: false, material: beadMaterial))
}

/// Deep-buttoned (diamond tufted) upholstery panel in the local XY plane, centered, puffing toward +Z.
/// Buttons sit on a diamond lattice `spacing` apart (x, y); pleats run along the diamond edges.
/// `edgeTuck` pulls the border down so the panel tucks into the frame. Returns the panel and the
/// button positions (local) for `buttons(_:at:)`.
public func tuftedPanel(width: Float, height: Float, spacing: V2 = V2(0.16, 0.13), puff: Float = 0.028, edgeTuck: Float = 0.03,
                        cell: Float = 0.016, material: MaterialKey) -> (Surface, [V3]) {
    var s = Surface(material: material)
    let nx = max(4, Int(width / cell)), ny = max(4, Int(height / cell))
    func h(_ x: Float, _ y: Float) -> Float {
        let p = V2((x + width / 2) / spacing.x, (y + height / 2) / spacing.y)
        let a = (p.x + p.y) / 2, b = (p.x - p.y) / 2
        let fa = a - floor(a), fb = b - floor(b)
        let pillow = pow(max(0, sin(.pi * fa) * sin(.pi * fb)), 0.55)
        let ex = min(x + width / 2, width / 2 - x), ey = min(y + height / 2, height / 2 - y)
        let tuck = smoothstep(0, edgeTuck, min(ex, ey))
        return puff * pillow * tuck - (1 - tuck) * puff * 0.3
    }
    for j in 0...ny { for i in 0...nx {
        let x = (Float(i) / Float(nx) - 0.5) * width, y = (Float(j) / Float(ny) - 0.5) * height
        s.add(V3(x, y, h(x, y)), V3(0, 0, 1), V2(x, y))
    }}
    let row = UInt32(nx + 1)
    for j in 0..<UInt32(ny) { for i in 0..<UInt32(nx) {
        let a = j * row + i
        s.quad(a, a + 1, a + row + 1, a + row)
    }}
    s.recomputeNormals(weldSeams: false)
    s.computeTangents()
    // Bake pleat shadow: darker where the surface dips.
    s.occlusion = s.positions.map { 0.55 + 0.45 * saturate($0.z / max(puff, 1e-4) + 0.1) }
    var buttons: [V3] = []
    let ix = Int((width / spacing.x).rounded(.down)), iy = Int((height / spacing.y).rounded(.down))
    for j in 0...iy { for i in 0...ix where (i + j) % 2 == 0 {
        let x = Float(i) * spacing.x - width / 2, y = Float(j) * spacing.y - height / 2
        if min(x + width / 2, width / 2 - x) < edgeTuck * 1.2 || min(y + height / 2, height / 2 - y) < edgeTuck * 1.2 { continue }
        buttons.append(V3(x, y, 0.002))
    }}
    return (s, buttons)
}

/// Leather-covered buttons at local points (from `tuftedPanel`), transformed by `x`.
public func buttons(_ m: inout Model, _ pts: [V3], _ x: Xform, radius: Float = 0.009, material: MaterialKey) {
    let b = Prim.superellipsoid(V3(radius * 2, radius * 2, radius * 1.1), exponent: 2.2, subdivisions: 2, material: material)
    for p in pts { m.add(b, Xform(translation: x.point(p), rotation: x.rotation)) }
}
