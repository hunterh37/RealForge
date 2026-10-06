import simd
import Foundation

/// One piece of a cut: the new stock value and where its local origin (base center) sits in the parent's
/// local frame. Place a piece exactly where the parent was with `parentTransform * Xform(translation: center)`
/// (no rotation: pieces keep the parent's axes).
public struct CutPiece<Stock: Sendable>: Sendable {
    /// The piece as its own stock value (build it with the same seed as the parent).
    public var board: Stock
    /// The piece's local origin in the parent's local frame (meters).
    public var center: V3
    public init(board: Stock, center: V3) { self.board = board; self.center = center }
}

/// Straight sawn stock with planar ends: the shared geometry and cut math behind `Lumber` and
/// `PlywoodSheet`. Local frame: length along X centered on the centerline (y = thickness / 2, z = 0),
/// width along Z centered, base at y = 0. End angles in degrees; see `Lumber` for the sign convention.
struct StockShape: Sendable {
    var length: Float
    var width: Float
    var thickness: Float
    var miterLeft: Float = 0
    var miterRight: Float = 0
    var bevelLeft: Float = 0
    var bevelRight: Float = 0
    /// Round-over radius of the four long arrises (0 = sharp).
    var radius: Float = 0
    var segments: Int = 3
    /// Long sides that are fresh rip cuts: their arrises stay sharp.
    var sharpFront = false
    var sharpBack = false

    /// End angles are clamped to this magnitude (degrees) in geometry and cut math.
    static let maxAngle: Float = 60

    static func tangent(_ deg: Float) -> Float { tan(max(-maxAngle, min(maxAngle, deg)) * .pi / 180) }

    var yc: Float { thickness / 2 }

    /// X of the end surface at section point (y, z).
    func endX(right: Bool, y: Float, z: Float) -> Float {
        if right { return length / 2 - z * Self.tangent(miterRight) + (yc - y) * Self.tangent(bevelRight) }
        return -length / 2 + z * Self.tangent(miterLeft) - (yc - y) * Self.tangent(bevelLeft)
    }

    /// Outward unit normal of an end face.
    func endNormal(right: Bool) -> V3 {
        right ? simd_normalize(V3(1, Self.tangent(bevelRight), Self.tangent(miterRight)))
              : simd_normalize(V3(-1, Self.tangent(bevelLeft), Self.tangent(miterLeft)))
    }

    /// Closed section loop in (z, y) with per-point normals (sharp corners appear twice).
    func profile() -> [(p: V2, n: V2)] {
        let w = width / 2, t = thickness
        let r = min(radius, w * 0.99, t / 2 * 0.99)
        let corners: [(V2, Float, Bool)] = [   // corner point, start angle (deg), sharp
            (V2(w, 0), -90, sharpFront), (V2(w, t), 0, sharpFront), (V2(-w, t), 90, sharpBack), (V2(-w, 0), 180, sharpBack)]
        var out: [(p: V2, n: V2)] = []
        for (c, a0, sharp) in corners {
            if sharp || r < 1e-5 {
                for a in [a0, a0 + 90] { let ar = a * .pi / 180; out.append((c, V2(cos(ar), sin(ar)))) }
            } else {
                let center = c - V2(c.x > 0 ? r : -r, c.y > 0 ? r : -r)
                let seg = max(1, segments)
                for k in 0...seg {
                    let ar = (a0 + 90 * Float(k) / Float(seg)) * .pi / 180
                    let n = V2(cos(ar), sin(ar))
                    out.append((center + n * r, n))
                }
            }
        }
        return out
    }

    /// Distinct section points in loop order (for caps, area and moments).
    func outline() -> [V2] {
        var pts: [V2] = []
        for e in profile() where pts.last.map({ simd_distance($0, e.p) > 1e-6 }) ?? true { pts.append(e.p) }
        if let f = pts.first, let l = pts.last, simd_distance(f, l) < 1e-6 { pts.removeLast() }
        return pts
    }

    /// Volume in cubic meters (exact for the faceted section).
    var volume: Float {
        let pts = outline()
        var a: Float = 0, sz: Float = 0, sy: Float = 0
        for i in pts.indices {
            let p = pts[i], q = pts[(i + 1) % pts.count]
            let c = p.x * q.y - q.x * p.y
            a += c; sz += (p.x + q.x) * c; sy += (p.y + q.y) * c
        }
        a *= 0.5; sz /= 6; sy /= 6
        if a < 0 { a = -a; sz = -sz; sy = -sy }
        let tm = Self.tangent(miterRight) + Self.tangent(miterLeft)
        let tb = Self.tangent(bevelRight) + Self.tangent(bevelLeft)
        return max(0, a * length - tm * sz + tb * (a * yc - sy))
    }

    // MARK: cuts

    /// Crosscut through (x, yc, 0) at `miter`/`bevel` (right-end convention for the left piece).
    func crosscut(atX x: Float, kerf: Float, miter: Float, bevel: Float) -> (left: (StockShape, V3), right: (StockShape, V3))? {
        let tm = Self.tangent(miter), tb = Self.tangent(bevel)
        let k = max(0, kerf) / 2 * simd_length(V3(1, tb, tm))
        let l0 = endX(right: false, y: yc, z: 0), r0 = endX(right: true, y: yc, z: 0)
        guard x > l0, x < r0 else { return nil }
        let xl = x - k, xr = x + k
        for y in [Float(0), thickness] { for z in [-width / 2, width / 2] {
            let off = -z * tm + (yc - y) * tb
            guard xl + off > endX(right: false, y: y, z: z) + 1e-4, xr + off < endX(right: true, y: y, z: z) - 1e-4 else { return nil }
        }}
        var a = self, b = self
        a.length = xl - l0; a.miterRight = miter; a.bevelRight = bevel
        b.length = r0 - xr; b.miterLeft = -miter; b.bevelLeft = -bevel
        return ((a, V3((l0 + xl) / 2, 0, 0)), (b, V3((xr + r0) / 2, 0, 0)))
    }

    /// Rip parallel to the length at z (kerf centered on z).
    func rip(atZ z: Float, kerf: Float) -> (front: (StockShape, V3), back: (StockShape, V3))? {
        let k = max(0, kerf) / 2, w = width / 2
        let wf = w - (z + k), wb = (z - k) + w
        guard z > -w, z < w, wf > 1e-3, wb > 1e-3 else { return nil }
        func piece(_ cz: Float, _ width: Float, front: Bool) -> (StockShape, V3) {
            var s = self
            let xl = endX(right: false, y: yc, z: cz), xr = endX(right: true, y: yc, z: cz)
            s.width = width; s.length = xr - xl
            if front { s.sharpBack = true } else { s.sharpFront = true }
            return (s, V3((xl + xr) / 2, 0, cz))
        }
        return (piece((w + z + k) / 2, wf, front: true), piece((z - k - w) / 2, wb, front: false))
    }

    // MARK: mesh

    /// Section surfaces. `faceUV(x, z)` maps the wide faces, `sideUV(x, y)` the narrow long faces,
    /// `endUV(z, y)` both end caps.
    func surfaces(face: MaterialKey, side: MaterialKey, end: MaterialKey,
                  faceUV: (Float, Float) -> V2, sideUV: (Float, Float) -> V2, endUV: (Float, Float) -> V2) -> [Surface] {
        var fs = Surface(material: face), ss = Surface(material: side), es = Surface(material: end)
        let prof = profile()
        let n = prof.count
        for i in 0..<n {
            let a = prof[i], b = prof[(i + 1) % n]
            guard simd_distance(a.p, b.p) > 1e-6 else { continue }
            let mid = a.n + b.n
            let wide = abs(mid.y) >= abs(mid.x)
            var verts: [UInt32] = []
            var s = wide ? fs : ss
            for e in [a, b] {
                for right in [false, true] {
                    let x = endX(right: right, y: e.p.y, z: e.p.x)
                    let uv = wide ? faceUV(x, e.p.x) : sideUV(x, e.p.y)
                    verts.append(s.add(V3(x, e.p.y, e.p.x), V3(0, e.n.y, e.n.x), uv))
                }
            }
            // verts: a-left, a-right, b-left, b-right
            let p0 = s.positions[Int(verts[0])], p1 = s.positions[Int(verts[1])], p3 = s.positions[Int(verts[3])]
            let out = V3(0, mid.y, mid.x)
            if simd_dot(simd_cross(p1 - p0, p3 - p0), out) >= 0 { s.quad(verts[0], verts[1], verts[3], verts[2]) }
            else { s.quad(verts[0], verts[2], verts[3], verts[1]) }
            if wide { fs = s } else { ss = s }
        }
        let pts = outline()
        for right in [false, true] {
            let nrm = endNormal(right: right)
            let c = pts.reduce(V2.zero, +) / Float(pts.count)
            let base = UInt32(es.positions.count)
            es.add(V3(endX(right: right, y: c.y, z: c.x), c.y, c.x), nrm, endUV(c.x, c.y))
            for p in pts { es.add(V3(endX(right: right, y: p.y, z: p.x), p.y, p.x), nrm, endUV(p.x, p.y)) }
            let m = UInt32(pts.count)
            for i in 0..<m {
                let a = base + 1 + i, b = base + 1 + (i + 1) % m
                let pa = es.positions[Int(a)], pb = es.positions[Int(b)], pc = es.positions[Int(base)]
                if simd_dot(simd_cross(pa - pc, pb - pc), nrm) >= 0 { es.tri(base, a, b) } else { es.tri(base, b, a) }
            }
        }
        var out = [fs, ss, es]
        for i in out.indices { out[i].computeTangents() }
        return out.filter { !$0.isEmpty }
    }
}

/// Inked mill stamps: text in a 3x5 pixel font laid as run-merged quads just above a face (+Y), with a
/// 1 px border and random ink dropouts. Text reads along +X, lines stack toward +Z.
enum InkStamp {
    /// Stamp footprint (x along the text, y across the lines), meters.
    static func size(_ lines: [String], px: Float) -> V2 {
        let cols = (lines.map(\.count).max() ?? 0) * 4 - 1 + 5
        let rows = lines.count * 5 + (lines.count - 1) * 2 + 5
        return V2(Float(cols), Float(rows)) * px
    }

    static func surface(_ lines: [String], px: Float, center: V2, angle ang: Float, y: Float, dropout: Float = 0.07,
                        material: MaterialKey = "wood.lumber-stamp", rng: inout SeededRNG) -> Surface {
        let sz = size(lines, px: px), W = sz.x, D = sz.y
        var sf = Surface(material: material)
        let c = cos(ang), sn = sin(ang)
        func put(_ x0: Float, _ z0: Float, _ x1: Float, _ z1: Float) {
            let corners = [V2(x0, z0), V2(x1, z0), V2(x1, z1), V2(x0, z1)].map { p -> V3 in
                let q = V2(p.x - W / 2, p.y - D / 2)
                return V3(center.x + q.x * c - q.y * sn, y, center.y + q.x * sn + q.y * c)
            }
            let base = UInt32(sf.positions.count)
            for p in corners { sf.add(p, .up, V2(p.x, p.z)) }
            sf.quad(base, base + 3, base + 2, base + 1)
        }
        let Wp = W / px, Dp = D / px
        put(px, 0, (Wp - 1) * px, px); put(px, (Dp - 1) * px, (Wp - 1) * px, Dp * px)
        put(0, px, px, (Dp - 1) * px); put((Wp - 1) * px, px, Wp * px, (Dp - 1) * px)
        for (li, line) in lines.enumerated() {
            for (ci, ch) in line.enumerated() {
                guard let rowsBits = font[ch] else { continue }
                for (ry, bits) in rowsBits.enumerated() {
                    var run: Int? = nil
                    for (rx, b) in (Array(bits) + ["0"]).enumerated() {
                        if b == "1" { if run == nil { run = rx } }
                        else if let r0 = run {
                            run = nil
                            if rng.chance(dropout) { continue }
                            let x0 = Float(3 + ci * 4 + r0), z0 = Float(3 + li * 7 + ry)
                            put(x0 * px, z0 * px, Float(3 + ci * 4 + rx) * px, (z0 + 1) * px)
                        }
                    }
                }
            }
        }
        sf.computeTangents()
        return sf
    }

    static let font: [Character: [String]] = [
        "S": ["111", "100", "111", "001", "111"], "P": ["111", "101", "111", "100", "100"],
        "F": ["111", "100", "110", "100", "100"], "N": ["101", "111", "111", "101", "101"],
        "o": ["000", "000", "111", "101", "111"], ".": ["000", "000", "000", "000", "010"],
        "2": ["111", "001", "111", "100", "111"], "-": ["000", "000", "111", "000", "000"],
        "D": ["110", "101", "101", "101", "110"], "R": ["110", "101", "110", "101", "101"],
        "Y": ["101", "101", "010", "010", "010"], "K": ["101", "101", "110", "101", "101"],
        "C": ["111", "100", "100", "100", "111"], "E": ["111", "100", "110", "100", "111"],
        "X": ["101", "101", "010", "101", "101"], "1": ["010", "110", "010", "010", "111"],
        "3": ["111", "001", "011", "001", "111"], "/": ["001", "001", "010", "100", "100"],
        "A": ["010", "101", "111", "101", "101"], "T": ["111", "010", "010", "010", "010"],
        "B": ["110", "101", "110", "101", "110"], "0": ["111", "101", "101", "101", "111"],
        "9": ["111", "101", "111", "001", "111"], "4": ["101", "101", "111", "001", "001"]]
}
