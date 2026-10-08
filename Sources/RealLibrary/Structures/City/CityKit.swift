import simd
import Foundation

/// Shared pieces for the City tiles and street furniture: the snap grid, flat road layers
/// (paint, patches, crack sealant) and a stroke font for sign lettering.
public enum CityGrid {
    /// Road cell edge (m). Road tiles are one cell; sidewalk, plaza and cobble tiles are a quarter.
    public static let roadCell: Float = 12
    /// Sidewalk-type cell edge (m).
    public static let walkCell: Float = 3
    /// Road surface height above y = 0 (m).
    public static let roadTop: Float = 0.1
    /// Sidewalk surface height (m): road top plus a 15 cm curb reveal.
    public static let walkTop: Float = 0.25
}

/// Flat layer on a horizontal surface: an XZ outline lifted `lift` above `y`, `thick` thick.
public func cityLayer(_ m: inout Model, outline: [V2], y: Float, lift: Float = 0.0015, thick: Float = 0.003, bevel: Float? = nil, material: MaterialKey) {
    // extrude builds along Z from XY; rotate so XY -> XZ (outline y becomes -z, so flip).
    let flipped = outline.map { V2($0.x, -$0.y) }
    var s = Prim.extrude(flipped, depth: thick, bevel: bevel ?? min(0.001, thick * 0.3), bevelSegments: bevel == nil ? 1 : 2, material: material)
    s = s.transformed(Xform(rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
    s.uvs = s.positions.map { V2($0.x, $0.z) }
    s.computeTangents()
    m.add(s, Xform(translation: V3(0, y + lift, 0)))
}

/// Paint stripe from `a` to `b` (XZ) of `width`, worn: split into dashes when `dash` > 0.
public func cityStripe(_ m: inout Model, _ a: V2, _ b: V2, width: Float, y: Float, dash: Float = 0, gap: Float = 0,
                       material: MaterialKey, rng: inout SeededRNG) {
    let d = b - a, L = simd_length(d)
    guard L > 0.01 else { return }
    let t = d / L, n = V2(-t.y, t.x) * (width / 2)
    var segs: [(Float, Float)] = []
    if dash > 0 { var s: Float = 0; while s < L { segs.append((s, min(L, s + dash))); s += dash + gap } } else { segs = [(0, L)] }
    for (s0, s1) in segs where s1 - s0 > 0.05 {
        let p0 = a + t * s0, p1 = a + t * s1
        // Worn ends: a few mm of random shrink per end.
        let e0 = p0 + t * rng.float(0...0.02), e1 = p1 - t * rng.float(0...0.02)
        cityLayer(&m, outline: [e0 - n, e1 - n, e1 + n, e0 + n], y: y, lift: 0.0015 + rng.float(0...0.0004), material: material)
    }
}

/// Paint band along an arc (center, radius, angles in radians, CCW in XZ with angle 0 = +X, pi/2 = +Z).
public func cityArcStripe(_ m: inout Model, center c: V2, radius r: Float, from a0: Float, to a1: Float, width: Float, y: Float,
                          dash: Float = 0, gap: Float = 0, material: MaterialKey) {
    let L = abs(a1 - a0) * r
    var segs: [(Float, Float)] = []
    if dash > 0 { var s: Float = 0; while s < L { segs.append((s, min(L, s + dash))); s += dash + gap } } else { segs = [(0, L)] }
    for (s0, s1) in segs where s1 - s0 > 0.05 {
        let n = max(2, Int((s1 - s0) / 0.4))
        var inner: [V2] = [], outer: [V2] = []
        for i in 0...n {
            let s = s0 + (s1 - s0) * Float(i) / Float(n), a = a0 + (a1 - a0) * s / L
            let dir = V2(cos(a), sin(a))
            inner.append(c + dir * (r - width / 2)); outer.append(c + dir * (r + width / 2))
        }
        var outline = inner + outer.reversed()
        if Shape2D.area(outline) < 0 { outline.reverse() }
        cityLayer(&m, outline: outline, y: y, material: material)
    }
}

/// Sealed crack: a wandering tar band starting at `start`, heading `angle`, `length` long.
public func citySealedCrack(_ m: inout Model, start: V2, angle: Float, length: Float, y: Float, bounds: Float,
                            material: MaterialKey = "asphalt.sealant", rng: inout SeededRNG) {
    var p = start, a = angle, pts = [p]
    let steps = max(3, Int(length / 0.35))
    for _ in 0..<steps {
        a += rng.float(-0.35...0.35)
        p += V2(cos(a), sin(a)) * 0.35
        if abs(p.x) > bounds || abs(p.y) > bounds { break }
        pts.append(p)
    }
    guard pts.count > 2 else { return }
    for i in 0..<(pts.count - 1) {
        let w = rng.float(0.025...0.05)
        let d = simd_normalize(pts[i + 1] - pts[i]), n = V2(-d.y, d.x) * w / 2
        let a0 = pts[i] - d * 0.02, a1 = pts[i + 1] + d * 0.02
        cityLayer(&m, outline: [a0 - n, a1 - n, a1 + n, a0 + n], y: y, lift: 0.0008 + Float(i % 3) * 0.0002, thick: 0.0016, material: material)
    }
}

/// Utility-cut patch: a rough-edged rectangle of fresh asphalt, 2 mm proud.
public func cityPatch(_ m: inout Model, center: V2, size: V2, angle: Float, y: Float, material: MaterialKey = "asphalt.patch", rng: inout SeededRNG) {
    var pts: [V2] = []
    let corners = [V2(-1, -1), V2(1, -1), V2(1, 1), V2(-1, 1)]
    let ca = cos(angle), sa = sin(angle)
    for k in 0..<4 {
        let c0 = corners[k] * size / 2, c1 = corners[(k + 1) % 4] * size / 2
        for i in 0..<4 {
            let t = Float(i) / 4
            var q = c0 + (c1 - c0) * t
            q += V2(rng.float(-0.02...0.02), rng.float(-0.02...0.02))
            pts.append(center + V2(q.x * ca - q.y * sa, q.x * sa + q.y * ca))
        }
    }
    cityLayer(&m, outline: pts, y: y, lift: 0.001, thick: 0.004, material: material)
}

/// Road slab of `size` (x, z) and thickness `top`, base at y = 0.
public func citySlab(_ m: inout Model, x: Float, z: Float, top: Float, material: MaterialKey, at c: V2 = .zero) {
    var s = Prim.roundedBox(V3(x, top, z), radius: 0.006, bevelSegments: 1, material: material)
    for k in s.positions.indices where abs(s.normals[k].y) > 0.7 { s.uvs[k] = V2(s.positions[k].x + c.x, s.positions[k].z + c.y) }
    s.computeTangents()
    m.add(s, Xform(translation: V3(c.x, top / 2, c.y)))
}

// MARK: - Stroke font

/// Block capitals on a 4 x 6 grid (x 0...4, y 0...6), as polylines.
private let glyphs: [Character: [[(Float, Float)]]] = [
    "A": [[(0, 0), (0, 4.5), (1, 6), (3, 6), (4, 4.5), (4, 0)], [(0, 3), (4, 3)]],
    "B": [[(0, 0), (0, 6), (3, 6), (4, 5), (4, 4), (3, 3.1), (0, 3.1)], [(3, 3.1), (4, 2.1), (4, 1), (3, 0), (0, 0)]],
    "C": [[(4, 5), (3, 6), (1, 6), (0, 5), (0, 1), (1, 0), (3, 0), (4, 1)]],
    "D": [[(0, 0), (0, 6), (2.6, 6), (4, 4.6), (4, 1.4), (2.6, 0), (0, 0)]],
    "E": [[(4, 6), (0, 6), (0, 0), (4, 0)], [(0, 3.1), (3, 3.1)]],
    "F": [[(4, 6), (0, 6), (0, 0)], [(0, 3.1), (3, 3.1)]],
    "G": [[(4, 5), (3, 6), (1, 6), (0, 5), (0, 1), (1, 0), (3, 0), (4, 1), (4, 2.8), (2.2, 2.8)]],
    "H": [[(0, 0), (0, 6)], [(4, 0), (4, 6)], [(0, 3.1), (4, 3.1)]],
    "I": [[(2, 0), (2, 6)], [(1, 6), (3, 6)], [(1, 0), (3, 0)]],
    "J": [[(4, 6), (4, 1), (3, 0), (1, 0), (0, 1)]],
    "K": [[(0, 0), (0, 6)], [(4, 6), (0, 2.6)], [(1.3, 3.7), (4, 0)]],
    "L": [[(0, 6), (0, 0), (4, 0)]],
    "M": [[(0, 0), (0, 6), (2, 3), (4, 6), (4, 0)]],
    "N": [[(0, 0), (0, 6), (4, 0), (4, 6)]],
    "O": [[(1, 0), (0, 1), (0, 5), (1, 6), (3, 6), (4, 5), (4, 1), (3, 0), (1, 0)]],
    "P": [[(0, 0), (0, 6), (3, 6), (4, 5), (4, 3.8), (3, 2.8), (0, 2.8)]],
    "Q": [[(1, 0), (0, 1), (0, 5), (1, 6), (3, 6), (4, 5), (4, 1), (3, 0), (1, 0)], [(2.5, 1.5), (4, 0)]],
    "R": [[(0, 0), (0, 6), (3, 6), (4, 5), (4, 3.8), (3, 2.8), (0, 2.8)], [(2.2, 2.8), (4, 0)]],
    "S": [[(4, 5), (3, 6), (1, 6), (0, 5), (0, 4), (1, 3.1), (3, 3.1), (4, 2.1), (4, 1), (3, 0), (1, 0), (0, 1)]],
    "T": [[(0, 6), (4, 6)], [(2, 6), (2, 0)]],
    "U": [[(0, 6), (0, 1), (1, 0), (3, 0), (4, 1), (4, 6)]],
    "V": [[(0, 6), (2, 0), (4, 6)]],
    "W": [[(0, 6), (0.8, 0), (2, 3.5), (3.2, 0), (4, 6)]],
    "X": [[(0, 0), (4, 6)], [(0, 6), (4, 0)]],
    "Y": [[(0, 6), (2, 3), (4, 6)], [(2, 3), (2, 0)]],
    "Z": [[(0, 6), (4, 6), (0, 0), (4, 0)]],
    "0": [[(1, 0), (0, 1), (0, 5), (1, 6), (3, 6), (4, 5), (4, 1), (3, 0), (1, 0)]],
    "1": [[(1, 5), (2, 6), (2, 0)], [(1, 0), (3, 0)]],
    "2": [[(0, 5), (1, 6), (3, 6), (4, 5), (4, 4), (0, 0), (4, 0)]],
    "3": [[(0, 5), (1, 6), (3, 6), (4, 5), (4, 4), (3, 3.1), (1.5, 3.1)], [(3, 3.1), (4, 2.1), (4, 1), (3, 0), (1, 0), (0, 1)]],
    "4": [[(3, 0), (3, 6), (0, 2), (4, 2)]],
    "5": [[(4, 6), (0, 6), (0, 3.4), (3, 3.4), (4, 2.4), (4, 1), (3, 0), (0, 0)]],
    "6": [[(4, 5.2), (3, 6), (1, 6), (0, 5), (0, 1), (1, 0), (3, 0), (4, 1), (4, 2.4), (3, 3.4), (0, 3.4)]],
    "7": [[(0, 6), (4, 6), (1.5, 0)]],
    "8": [[(1, 3.1), (0, 4), (0, 5), (1, 6), (3, 6), (4, 5), (4, 4), (3, 3.1), (1, 3.1), (0, 2.1), (0, 1), (1, 0), (3, 0), (4, 1), (4, 2.1), (3, 3.1)]],
    "9": [[(4, 2.6), (1, 2.6), (0, 3.6), (0, 5), (1, 6), (3, 6), (4, 5), (4, 1), (3, 0), (0, 0)]],
    ".": [[(1.6, 0), (1.6, 0.6)]],
    "-": [[(0.8, 3), (3.2, 3)]],
]

/// Width of `text` in meters for cap `height` (letter 4 units + 1.4 spacing on a 6-unit cap).
public func strokeTextWidth(_ text: String, height: Float) -> Float {
    let u = height / 6
    return Float(text.count) * 5.4 * u - 1.4 * u
}

/// Raised block lettering in local XY, centered on the origin, `depth` proud along +Z from z = 0.
public func strokeText(_ text: String, height: Float, stroke: Float? = nil, depth: Float = 0.0015, material: MaterialKey) -> Surface {
    let u = height / 6, w = stroke ?? height * 0.15
    let total = strokeTextWidth(text, height: height)
    var out = Surface(material: material)
    for (i, ch) in text.uppercased().enumerated() {
        guard let lines = glyphs[ch] else { continue }
        let ox = -total / 2 + Float(i) * 5.4 * u
        for line in lines {
            for k in 0..<(line.count - 1) {
                let a = V2(ox + line[k].0 * u, line[k].1 * u - height / 2), b = V2(ox + line[k + 1].0 * u, line[k + 1].1 * u - height / 2)
                let d = b - a, L = simd_length(d)
                guard L > 1e-5 else { continue }
                let box = cuboid(V3(L + w * 0.9, w, depth), material: material)
                let ang = atan2(d.y, d.x)
                out.append(box, Xform(translation: V3((a.x + b.x) / 2, (a.y + b.y) / 2, depth / 2), rotation: simd_quatf(angle: ang, axis: V3(0, 0, 1))))
            }
        }
    }
    return out
}

// MARK: - Road markings

/// Rotate an XZ point by quarter turns about the origin (k = 1: +X -> +Z).
@inline(__always) func quarter(_ p: V2, _ k: Int) -> V2 {
    switch ((k % 4) + 4) % 4 { case 1: V2(-p.y, p.x); case 2: V2(-p.x, -p.y); case 3: V2(p.y, -p.x); default: p }
}

/// Markings for one approach leg entering a road cell from its -X edge, rotated by `k` quarter turns:
/// a continental crosswalk inset from the edge, a stop bar across the inbound lane and the centre
/// line stub between them.
public func cityLegMarkings(_ m: inout Model, k: Int, cell: Float, y: Float, laneWidth: Float = 3.6, barSpan: Float = 6,
                            white: MaterialKey, yellow: MaterialKey, rng: inout SeededRNG) {
    let h = cell / 2
    func rect(_ x0: Float, _ z0: Float, _ x1: Float, _ z1: Float, _ mat: MaterialKey) {
        let pts = [V2(x0, z0), V2(x1, z0), V2(x1, z1), V2(x0, z1)].map { quarter($0, k) }.reversedIfCW()
        cityLayer(&m, outline: pts, y: y, lift: 0.0015 + rng.float(0...0.0003), material: mat)
    }
    // Stop bar 45 cm across the inbound (right-hand, +Z side when heading +X) lane.
    let stop0 = -h + 0.05
    rect(stop0, 0.2, stop0 + 0.4, min(laneWidth, barSpan / 2), white)
    // Centre line stub from the edge to the stop bar.
    for s: Float in [-1, 1] { rect(-h, s * 0.1 - 0.05, stop0 + 0.4, s * 0.1 + 0.05, yellow) }
    // Continental crosswalk: 60 cm bars on 1.2 m centres, 2.4 m wide, 45 cm in from the stop bar,
    // bars spread over `barSpan` across the road.
    let cw0 = stop0 + 0.85, cw1 = cw0 + 2.4
    let bars = max(1, Int((barSpan + 0.6) / 1.2))
    var z = -Float(bars) * 1.2 / 2 + 0.3
    for _ in 0..<bars {
        // Wheel-worn bars: some lose a slice.
        let wear = rng.chance(0.3) ? rng.float(0.1...0.5) : 0
        rect(cw0, z, cw1 - wear, z + 0.6, white)
        z += 1.2
    }
}

/// Arc points around `c` at radius `r` from angle `a0` to `a1` (radians, 0 = +X, pi/2 = +Z).
public func cityArc(_ c: V2, _ r: Float, _ a0: Float, _ a1: Float, step: Float = 0.25) -> [V2] {
    let n = max(2, Int(abs(a1 - a0) * r / step))
    return (0...n).map { i in let a = a0 + (a1 - a0) * Float(i) / Float(n); return c + V2(cos(a), sin(a)) * r }
}

/// Straight granite curb run along X from `x0` to `x1`, road face at z = `z` facing -Z, cut into
/// stones of `stone` length with 6 mm joints. Height 0...`top`, 15 cm wide, rounded arris.
public func cityCurb(_ m: inout Model, x0: Float, x1: Float, z: Float, top: Float = CityGrid.walkTop, width: Float = 0.15,
                     stone: Float = 1.5, material: MaterialKey, rng: inout SeededRNG) {
    let prof = Shape2D.rounded([V2(0, 0), V2(width, 0), V2(width, top), V2(0, top)], radius: 0.012, segments: 3)
    var x = x0
    while x < x1 - 0.05 {
        let len = min(stone, x1 - x) - 0.006
        var s = Prim.extrude(prof, depth: len, bevel: 0.004, bevelSegments: 1, material: material)
        // extrude: profile in XY (x = across, y = up), length along Z -> rotate Z onto +X.
        s = s.transformed(Xform(rotation: simd_quatf(degrees: 90, axis: V3(0, 1, 0))))
        let settle = rng.float(-0.003...0.0015)
        m.add(s, Xform(translation: V3(x + 0.003 + len / 2, settle, z)))
        x += stone
    }
}

// MARK: - Street furniture parts

/// Square perforated steel sign post (telespar), `side` square, from y = 0 to `height`, with
/// 11 mm knockouts every 25 mm on all four faces and a 2 mm rounded arris.
public func citySquarePost(_ m: inout Model, at p: V3 = .zero, side: Float = 0.05, height: Float, holes: Bool = true,
                           material: MaterialKey = "metal.galvanized", hole: MaterialKey = "metal.steel:1A1A1A") {
    m.add(Prim.roundedBox(V3(side, height, side), radius: 0.003, bevelSegments: 1, material: material), Xform(translation: p + V3(0, height / 2, 0)))
    guard holes else { return }
    var y: Float = 0.08
    var dots = Surface(material: hole)
    let d = cuboid(V3(0.011, 0.011, 0.001), material: hole)
    while y < height - 0.03 {
        for k in 0..<4 {
            let a = Float(k) * .pi / 2
            let n = V3(sin(a), 0, cos(a))
            dots.append(d, Xform(translation: p + V3(0, y, 0) + n * (side / 2 + 0.0002), rotation: simd_quatf(angle: a, axis: .up)))
        }
        y += 0.025 * 4
    }
    m.add(dots)
}

/// Flat sign plate in local XY facing +Z: a white `border` plate with a colored inset `face` 1 mm proud
/// on both sides when `twoSided`, lettering on top. Outline is the plate shape (XY, centered).
public func citySignPlate(_ m: inout Model, outline: [V2], x: Xform, thickness: Float = 0.002, border: Float = 0.012,
                          borderMaterial: MaterialKey = "sign.white", face: MaterialKey, back: MaterialKey? = "metal.aluminum-brushed",
                          twoSided: Bool = false, text: [(String, V2, Float, Float)] = [], textMaterial: MaterialKey = "sign.white") {
    // Plate body (border color shows at the rim).
    m.add(Prim.extrude(outline, depth: thickness, bevel: 0.0008, bevelSegments: 1, material: borderMaterial), x)
    let inner = Shape2D.offset(outline, -border)
    let sides: [Float] = twoSided ? [1, -1] : [1]
    for s in sides {
        var f = Prim.extrude(inner, depth: 0.0008, bevel: 0.0002, bevelSegments: 1, material: face)
        f = f.transformed(Xform(translation: V3(0, 0, s * (thickness / 2 + 0.0004))))
        m.add(f, x)
        for (str, at, hgt, squeeze) in text {
            var t = strokeText(str, height: hgt, stroke: hgt * 0.16, depth: 0.0006, material: textMaterial)
            t = t.transformed(Xform(translation: V3(at.x, at.y, 0), scale: V3(squeeze, 1, 1)))
            if s < 0 { t = t.transformed(Xform(rotation: simd_quatf(angle: .pi, axis: .up))) }
            m.add(t, x.then(Xform(translation: V3(0, 0, s * (thickness / 2 + 0.0008)))))
        }
    }
    if let back, !twoSided {
        var b = Prim.extrude(Shape2D.offset(outline, -0.002), depth: 0.0006, bevel: 0.0002, bevelSegments: 1, material: back)
        b = b.transformed(Xform(translation: V3(0, 0, -(thickness / 2 + 0.0003))))
        m.add(b, x)
    }
}

extension Xform {
    /// Apply `local` first, then self (self * local).
    func then(_ local: Xform) -> Xform {
        Xform(translation: translation + rotation.act(local.translation * scale), rotation: rotation * local.rotation, scale: scale * local.scale)
    }
}
