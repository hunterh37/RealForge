import simd
import Foundation

/// Builders shared by grass and ground-cover plants: bent blade strips, flower discs, crossed cards and
/// grass tufts. All set `extra.x` (wind weight, 0 at the root) and baked occlusion.
public enum PlantKit {

    /// Atlas cell `i` in a `cols` x `rows` grid, row-major from the bottom-left, inset to keep mips clean.
    public static func cell(_ i: Int, cols: Int, rows: Int, inset: Float = 0.006) -> (origin: V2, size: V2) {
        let w = 1 / Float(cols), h = 1 / Float(rows)
        let o = V2(Float(i % cols) * w, Float(i / cols) * h)
        return (o + V2(inset, inset), V2(w - 2 * inset, h - 2 * inset))
    }

    /// Strip of one blade, leaf or frond along a curve in a vertical plane.
    public struct Blade {
        public var root: V3 = .zero
        /// Heading of the lean in radians (0 = +X, pi/2 = +Z).
        public var yaw: Float = 0
        public var length: Float = 0.2
        public var width: Float = 0.005
        /// Radians from vertical at the root, and extra bend reached at the tip.
        public var lean: Float = 0.2
        public var curl: Float = 0.5
        /// Rotation of the strip about its own axis at the tip (radians).
        public var twist: Float = 0
        public var segments = 4
        /// Tip width as a fraction of `width`; 0 closes the tip to a point.
        public var tipWidth: Float = 0
        /// Constant width (texture carries the outline) instead of the grass taper.
        public var constantWidth = false
        /// Midline raised along the normal by `fold * width` (V-fold or curl; negative cups the strip).
        public var fold: Float = 0
        /// Leaf outline: 0 keeps the grass taper; above 0 the width swells to a belly at t = 0.5^(1/belly) and closes at the tip.
        public var belly: Float = 0
        public var u: V2 = V2(0, 1)
        public var v: V2 = V2(0, 1)
        /// Wind weight at root and tip; grows with t^1.5.
        public var weight: V2 = V2(0, 1)
        public var phase: Float = 0
        /// Baked occlusion at root and tip.
        public var ao: V2 = V2(0.45, 1)
        /// Blend of the shading normal toward +Y (0 = geometric, 1 = straight up).
        public var upNormal: Float = 0.45
        public init() {}
    }

    public static func blade(_ b: Blade, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let up = V3(0, 1, 0)
        let d = V3(cos(b.yaw), 0, sin(b.yaw))
        let side0 = V3(d.z, 0, -d.x)
        let n = max(1, b.segments)
        let ds = b.length / Float(n)
        var p = b.root
        let pointed = b.tipWidth <= 0 && b.fold == 0 && b.belly == 0
        let cols = b.fold != 0 ? 3 : 2
        var rows: [[UInt32]] = []
        for i in 0...n {
            let t = Float(i) / Float(n)
            let th = b.lean + b.curl * pow(t, 1.6)
            let tan = simd_normalize(d * sin(th) + up * cos(th))
            if i > 0 {
                let tm = Float(i) - 0.5
                let thm = b.lean + b.curl * pow(tm / Float(n), 1.6)
                p += (d * sin(thm) + up * cos(thm)) * ds
            }
            let side = b.twist == 0 ? side0 : simd_quatf(angle: b.twist * t, axis: tan).act(side0)
            var nrm = simd_normalize(simd_cross(tan, side))
            if nrm.y < 0 { nrm = -nrm }
            let shade = simd_normalize(nrm * (1 - b.upNormal) + up * b.upNormal)
            let taper: Float = b.constantWidth ? 1 : pow(max(0, 1 - t), 0.55)
            let w = b.belly > 0 ? b.width * max(pow(sin(.pi * pow(t, b.belly)), 0.6), 0.1 * (1 - t) + 0.02)
                                : b.width * (b.tipWidth + (1 - b.tipWidth) * taper)
            let wt = b.weight.x + (b.weight.y - b.weight.x) * pow(t, 1.5)
            let occ = b.ao.x + (b.ao.y - b.ao.x) * smoothstep(0, 0.7, t)
            let vv = b.v.x + (b.v.y - b.v.x) * t
            let e = V2(wt, b.phase)
            if i == n && pointed {
                let k = s.add(p, shade, V2((b.u.x + b.u.y) / 2, vv), extra: e)
                s.occlusion[Int(k)] = occ
                rows.append([k])
                continue
            }
            var row: [UInt32] = []
            for c in 0..<cols {
                let f = cols == 2 ? Float(c) : Float(c) / 2           // 0, (0.5), 1 across
                var q = p + side * (f - 0.5) * w
                if cols == 3 && c == 1 { q += nrm * b.fold * w }
                let k = s.add(q, shade, V2(b.u.x + (b.u.y - b.u.x) * f, vv), extra: e)
                s.occlusion[Int(k)] = occ
                row.append(k)
            }
            rows.append(row)
        }
        for i in 0..<n {
            let a = rows[i], c = rows[i + 1]
            if c.count == 1 { s.tri(a[0], a[1], c[0]); continue }
            for k in 0..<(cols - 1) { s.quad(a[k], a[k + 1], c[k + 1], c[k]) }
        }
        return s
    }

    /// Flower head or leaf disc: a fan of `rim` triangles mapped to an atlas cell circle. `cup` raises
    /// the rim by `cup * radius` along `normal` (negative domes it).
    public static func disc(center: V3, normal: V3, radius: Float, cup: Float, rim: Int, cell: (origin: V2, size: V2),
                            spin: Float, weight: Float, phase: Float, ao: Float = 1, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let nn = simd_normalize(normal)
        let e1 = simd_normalize(nn.anyPerpendicular), e2 = simd_cross(nn, e1)
        let shade = simd_normalize(nn * 0.7 + V3(0, 0.3, 0))
        let cuv = cell.origin + cell.size / 2
        let c = s.add(center, shade, cuv, extra: V2(weight, phase))
        s.occlusion[Int(c)] = ao
        for k in 0..<rim {
            let a = Float(k) / Float(rim) * 2 * .pi + spin
            let dir = e1 * cos(a) + e2 * sin(a)
            let p = center + dir * radius + nn * cup * radius
            let i = s.add(p, simd_normalize(shade + dir * 0.15), cuv + V2(cos(a - spin), sin(a - spin)) * cell.size / 2, extra: V2(weight, phase))
            s.occlusion[Int(i)] = ao
        }
        for k in 0..<UInt32(rim) { s.tri(c, c + 1 + k, c + 1 + (k + 1) % UInt32(rim)) }
        return s
    }

    /// `count` vertical cards crossed about a point (seed heads, clover heads, seed clocks).
    public static func crossedCards(at base: V3, width: Float, height: Float, count: Int, yaw: Float, cell: (origin: V2, size: V2),
                                    weight: V2, phase: Float, axis: V3 = V3(0, 1, 0), material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let tilt = simd_quatf(from: V3(0, 1, 0), to: simd_normalize(axis))
        for k in 0..<count {
            let a = yaw + Float(k) * .pi / Float(count)
            var c = Prim.card(width: width, height: height, cell: cell, material: material, normal: V3(0, 1, 0))
            c.extra = [V2(weight.x, phase), V2(weight.x, phase), V2(weight.y, phase), V2(weight.y, phase)]
            c.occlusion = [0.85, 0.85, 1, 1]
            s.append(c, Xform(translation: base, rotation: tilt * simd_quatf(angle: a, axis: V3(0, 1, 0))))
        }
        return s
    }

    /// Grass tuft parameters. Heights and widths in meters.
    public struct Tuft {
        public var count = 40
        public var height: Float = 0.25
        /// Blade height range as fractions of `height`.
        public var heightRange: ClosedRange<Float> = 0.45...1
        /// Root disc radius.
        public var radius: Float = 0.04
        public var width: ClosedRange<Float> = 0.003...0.006
        /// Lean at the root (radians) and extra lean for blades at the edge of the root disc.
        public var lean: ClosedRange<Float> = 0.05...0.3
        public var splay: Float = 0.35
        public var curl: ClosedRange<Float> = 0.2...1.1
        public var twist: Float = 0.7
        public var segments = 4
        public var columns = 8
        /// Blunt cut tips (mown lawn).
        public var mown = false
        public init() {}
    }

    /// Geometric blades for close range. Each blade picks one column of a `grassBlade` strip atlas.
    public static func tuft(_ t: Tuft, at center: V3 = .zero, rng: inout SeededRNG, material: MaterialKey, phase: Float = 0) -> Surface {
        var s = Surface(material: material)
        for _ in 0..<t.count {
            let r = t.radius * sqrt(rng.float()), a = rng.float(0...(2 * .pi))
            let off = V2(cos(a), sin(a)) * r
            var b = Blade()
            b.root = center + V3(off.x, 0, off.y)
            b.yaw = a + rng.float(-0.6...0.6)
            let hf = rng.float(t.heightRange)
            b.length = t.height * hf * rng.float(1.0...1.1)
            b.width = rng.float(t.width)
            b.lean = rng.float(t.lean) + t.splay * r / max(t.radius, 1e-4)
            b.curl = rng.float(t.curl) * (0.6 + 0.6 * hf)
            b.twist = rng.float(-t.twist...t.twist)
            b.segments = t.segments
            b.tipWidth = t.mown ? 0.8 : 0
            let col = Float(rng.int(0...(t.columns - 1)))
            b.u = V2((col + 0.12) / Float(t.columns), (col + 0.88) / Float(t.columns))
            b.v = V2(0.01, t.mown ? 0.99 : 0.99)
            b.phase = phase + rng.float(0...0.5)
            b.ao = V2(rng.float(0.3...0.5), rng.float(0.85...1))
            s.append(blade(b, material: material))
        }
        return s
    }

    /// Bent alpha cards for distance LODs: `count` cards crossed about the center, each one strip of
    /// `segments` rows mapped to `cell`.
    public static func cardTuft(count: Int, height: Float, width: Float, segments: Int, cells: [(origin: V2, size: V2)],
                                rng: inout SeededRNG, material: MaterialKey, phase: Float = 0, lean: Float = 0.12) -> Surface {
        var s = Surface(material: material)
        let start = rng.float(0...(.pi))
        for k in 0..<count {
            var b = Blade()
            let cell = cells[k % cells.count]
            b.yaw = start + Float(k) * .pi / Float(count) + rng.float(-0.2...0.2) + .pi / 2
            b.length = height * rng.vary(1, 0.15)
            b.width = width * rng.vary(1, 0.15)
            b.lean = (k % 2 == 0 ? 1 : -1) * lean * rng.float(0.5...1)
            b.curl = b.lean * 1.5
            b.segments = segments
            b.tipWidth = 1; b.constantWidth = true
            b.u = V2(cell.origin.x, cell.origin.x + cell.size.x)
            b.v = V2(cell.origin.y, cell.origin.y + cell.size.y)
            b.phase = phase
            b.ao = V2(0.55, 1)
            b.upNormal = 0.75
            s.append(blade(b, material: material))
        }
        return s
    }

    /// Thin herbaceous stem along `points` (3-sided tube, no caps), wind weight rising root to tip.
    public static func stem(_ points: [V3], radius: Float, tipRadius: Float? = nil, sides: Int = 3, weight: V2, phase: Float,
                            material: MaterialKey = "plant.stem") -> Surface {
        let n = points.count
        let radii = (0..<n).map { i in radius + ((tipRadius ?? radius * 0.6) - radius) * Float(i) / Float(max(1, n - 1)) }
        let w = (0..<n).map { i in weight.x + (weight.y - weight.x) * pow(Float(i) / Float(max(1, n - 1)), 1.5) }
        var s = Prim.tube(points, radii: radii, sides: sides, seamTile: 0.02, material: material, weights: w, phase: phase, capEnd: false)
        s.occlusion = (0..<s.positions.count).map { i in 0.55 + 0.45 * min(1, s.positions[i].y / max(points.last!.y, 0.01) * 3) }
        return s
    }

    /// Points along an arching stem: rises `height`, leaning `lean` radians toward `yaw`, `bend` more at the top.
    public static func arc(from base: V3, height: Float, yaw: Float, lean: Float, bend: Float, count: Int) -> [V3] {
        let d = V3(cos(yaw), 0, sin(yaw))
        var p = base, out = [base]
        let ds = height / Float(count - 1)
        for i in 1..<count {
            let t = (Float(i) - 0.5) / Float(count - 1)
            let th = lean + bend * t * t
            p += (d * sin(th) + V3(0, cos(th), 0)) * ds
            out.append(p)
        }
        return out
    }

    /// Tangents for every surface (blades are built without them).
    public static func finish(_ m: inout Model) {
        for i in m.surfaces.indices { m.surfaces[i].computeTangents() }
    }
}
