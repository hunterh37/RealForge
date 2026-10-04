import simd
import Foundation

/// Interior shell for building scenes: floor, four walls with door and window openings, a suspended
/// lay-in ceiling (or flat plaster), columns, skirting and a roof slab so sunlight only enters through
/// the openings. Inner faces are tessellated (`cell`) so the scene AO bake can darken corners and the
/// floor under furniture. Centered on X/Z, floor at y = 0, north wall at -Z.
public struct Room: Sendable {
    public enum Wall: Sendable { case north, south, east, west }
    public enum Ceiling: Sendable {
        /// Lay-in acoustic tiles in a T-bar grid; `pitch` tile size (0.6 m).
        case grid(pitch: Float)
        /// Smooth plastered ceiling.
        case flat
        case none
    }
    /// A hole in a wall. `offset` is along the wall from its center (toward +X on north/south, +Z on
    /// east/west), `sill` and `head` heights from the floor.
    public struct Opening: Sendable {
        public var wall: Wall; public var offset: Float; public var width: Float; public var sill: Float; public var head: Float
        public init(_ wall: Wall, offset: Float, width: Float, sill: Float, head: Float) {
            self.wall = wall; self.offset = offset; self.width = width; self.sill = sill; self.head = head
        }
    }

    /// Interior size (x width, y floor-to-ceiling, z depth).
    public var size: V3
    public var wallThickness: Float = 0.2
    public var floor: MaterialKey = "carpet.tile"
    public var wall: MaterialKey = "paint.wall"
    public var ceilingMaterial: MaterialKey = "ceiling.acoustic"
    public var gridMaterial: MaterialKey = "metal.powdercoat:ECECE8"
    public var skirting: MaterialKey? = "laminate.white:5A5B5E"
    public var skirtingHeight: Float = 0.08
    public var ceiling: Ceiling = .grid(pitch: 0.6)
    public var openings: [Opening] = []
    /// Square structural columns (centers on the floor plan) and their side.
    public var columns: [V2] = []
    public var columnSize: Float = 0.5
    /// Grid cells (ceiling tile indices from the room center) left open for light fixtures.
    public var fixtureCells: Set<SIMD2<Int32>> = []
    /// Tessellation of inner faces for the AO bake (meters).
    public var cell: Float = 0.25

    public init(size: V3) { self.size = size }
    public func with(_ edit: (inout Room) -> Void) -> Room { var c = self; edit(&c); return c }

    /// Center of a ceiling grid cell at the ceiling plane.
    public func cellCenter(_ c: SIMD2<Int32>) -> V3 {
        guard case .grid(let p) = ceiling else { return V3(0, size.y, 0) }
        return V3((Float(c.x) + 0.5) * p, size.y, (Float(c.y) + 0.5) * p)
    }

    /// Ceiling cells on a regular pattern (every `every` tiles, inset from the walls) for luminaires.
    public func fixturePattern(every: SIMD2<Int32>, inset: Float = 1.0) -> Set<SIMD2<Int32>> {
        guard case .grid(let p) = ceiling else { return [] }
        let nx = Int32(((size.x / 2 - inset) / p).rounded(.down)), nz = Int32(((size.z / 2 - inset) / p).rounded(.down))
        var out: Set<SIMD2<Int32>> = []
        var x = -nx
        while x < nx { var z = -nz; while z < nz { out.insert(SIMD2(x, z)); z += every.y }; x += every.x }
        return out
    }

    /// Height of the ceiling void up to the structural slab.
    public var plenum: Float = 0.6

    /// The shell as one model (merged by material).
    public func model() -> Model {
        var m = shell()
        m.add(ceilingModel())
        return m
    }

    /// Ceiling tiles, grid and slab (kept out of the AO bake: tiles face down at the T-bars).
    public func ceilingModel() -> Model {
        var m = Model(name: "room-ceiling")
        let W = size.x, H = size.y, D = size.z, T = wallThickness
        switch ceiling {
        case .none: break
        case .flat:
            m.add(gridPanel(corner: V3(-W / 2, H, -D / 2), u: V3(W, 0, 0), v: V3(0, 0, D), material: wall, cell: 1))
        case .grid(let p):
            let nx = Int32((W / 2 / p).rounded(.up)), nz = Int32((D / 2 / p).rounded(.up))
            for i in -nx..<nx { for j in -nz..<nz where !fixtureCells.contains(SIMD2(i, j)) {
                let x0 = max(-W / 2, Float(i) * p), x1 = min(W / 2, Float(i + 1) * p)
                let z0 = max(-D / 2, Float(j) * p), z1 = min(D / 2, Float(j + 1) * p)
                guard x1 > x0 + 1e-3, z1 > z0 + 1e-3 else { continue }
                m.add(gridPanel(corner: V3(x0, H, z0), u: V3(x1 - x0, 0, 0), v: V3(0, 0, z1 - z0), material: ceilingMaterial, cell: p))
            }}
            // T-bar grid, 24 mm face, hanging 12 mm below the tiles.
            for i in -nx...nx {
                let x = Float(i) * p
                guard x > -W / 2, x < W / 2 else { continue }
                m.add(cuboid(V3(0.024, 0.012, D), material: gridMaterial), Xform(translation: V3(x, H - 0.006, 0)))
            }
            for j in -nz...nz {
                let z = Float(j) * p
                guard z > -D / 2, z < D / 2 else { continue }
                m.add(cuboid(V3(W, 0.012, 0.024), material: gridMaterial), Xform(translation: V3(0, H - 0.0065, z)))
            }
            // Wall angle trim.
            for (c, sz) in [(V3(0, H - 0.006, -D / 2 + 0.012), V3(W, 0.012, 0.024)), (V3(0, H - 0.006, D / 2 - 0.012), V3(W, 0.012, 0.024)),
                            (V3(-W / 2 + 0.012, H - 0.006, 0), V3(0.024, 0.012, D)), (V3(W / 2 - 0.012, H - 0.006, 0), V3(0.024, 0.012, D))] {
                m.add(cuboid(sz, material: gridMaterial), Xform(translation: c))
            }
        }
        // Structural slab above the ceiling void: closes the box for sun shadows.
        m.add(cuboid(V3(W + 2 * T, 0.25, D + 2 * T), material: "concrete.smooth"), Xform(translation: V3(0, H + plenum + 0.125, 0)))
        return m
    }

    /// Floor, walls, columns and skirting (AO bake receivers).
    public func shell() -> Model {
        var m = Model(name: "room")
        let W = size.x, H = size.y, D = size.z, T = wallThickness
        // Floor.
        m.add(gridPanel(corner: V3(-W / 2, 0, D / 2), u: V3(W, 0, 0), v: V3(0, 0, -D), material: floor))
        // Walls: (inner-face origin at floor center, along-wall tangent, inward normal, length incl. corners).
        let walls: [(Wall, V3, V3, V3, Float)] = [
            (.north, V3(0, 0, -D / 2), V3(1, 0, 0), V3(0, 0, 1), W + 2 * T),
            (.south, V3(0, 0, D / 2), V3(1, 0, 0), V3(0, 0, -1), W + 2 * T),
            (.west, V3(-W / 2, 0, 0), V3(0, 0, 1), V3(1, 0, 0), D),
            (.east, V3(W / 2, 0, 0), V3(0, 0, 1), V3(-1, 0, 0), D),
        ]
        for (side, o, t, n, len) in walls {
            let ops = openings.filter { $0.wall == side }.sorted { $0.offset < $1.offset }
            var rects: [(Float, Float, Float, Float)] = []   // s0, s1, y0, y1
            var s = -len / 2
            for op in ops {
                let a = op.offset - op.width / 2, b = op.offset + op.width / 2
                if a > s { rects.append((s, a, 0, H + plenum)) }
                if op.sill > 0 { rects.append((a, b, 0, op.sill)) }
                if op.head < H + plenum { rects.append((a, b, op.head, H + plenum)) }
                s = b
            }
            if s < len / 2 { rects.append((s, len / 2, 0, H + plenum)) }
            for (s0, s1, y0, y1) in rects where s1 - s0 > 1e-4 && y1 - y0 > 1e-4 {
                m.add(wallBlock(o: o, t: t, n: n, s0: s0, s1: s1, y0: y0, y1: y1, thick: T))
            }
            // Skirting along the inner face, broken at door openings.
            if let sk = skirting {
                let inset: Float = side == .north || side == .south ? T : 0
                var segs: [(Float, Float)] = [(-len / 2 + inset, len / 2 - inset)]
                for op in ops where op.sill < 0.01 {
                    let a = op.offset - op.width / 2, b = op.offset + op.width / 2
                    segs = segs.flatMap { seg -> [(Float, Float)] in
                        guard b > seg.0, a < seg.1 else { return [seg] }
                        return [(seg.0, a), (b, seg.1)].filter { $0.1 - $0.0 > 0.02 }
                    }
                }
                for (a, b) in segs {
                    let c = o + t * ((a + b) / 2) + n * 0.006 + V3(0, skirtingHeight / 2, 0)
                    let size3 = abs(t.x) > 0.5 ? V3(b - a, skirtingHeight, 0.012) : V3(0.012, skirtingHeight, b - a)
                    m.add(Prim.roundedBox(size3, radius: 0.002, bevelSegments: 1, material: sk), Xform(translation: c))
                }
            }
        }
        // Columns.
        for c in columns {
            let s = columnSize
            m.add(gridBox(V3(c.x, H / 2, c.y), V3(s, H, s), material: wall))
            if let sk = skirting {
                m.add(Prim.roundedBox(V3(s + 0.024, skirtingHeight, s + 0.024), radius: 0.002, bevelSegments: 1, material: sk),
                      Xform(translation: V3(c.x, skirtingHeight / 2, c.y)))
            }
        }
        return m
    }

    /// Quad grid with corner `corner`, edges `u` and `v` (normal = u x v), UVs in meters.
    func gridPanel(corner: V3, u: V3, v: V3, material: MaterialKey, cell c: Float? = nil) -> Surface {
        let step = c ?? cell
        let nu = max(1, Int((simd_length(u) / step).rounded(.up))), nv = max(1, Int((simd_length(v) / step).rounded(.up)))
        var s = Surface(material: material)
        let n = simd_normalize(simd_cross(u, v)), ud = simd_normalize(u), vd = simd_normalize(v)
        for j in 0...nv { for i in 0...nu {
            let p = corner + u * (Float(i) / Float(nu)) + v * (Float(j) / Float(nv))
            s.add(p, n, V2(simd_dot(p, ud), simd_dot(p, vd)))
        }}
        let row = UInt32(nu + 1)
        for j in 0..<UInt32(nv) { for i in 0..<UInt32(nu) {
            let a = j * row + i
            s.quad(a, a + 1, a + row + 1, a + row)
        }}
        s.computeTangents()
        return s
    }

    /// Closed wall block; the face toward the room (`n`) is tessellated, the rest are single quads.
    func wallBlock(o: V3, t: V3, n: V3, s0: Float, s1: Float, y0: Float, y1: Float, thick: Float) -> Surface {
        let up = V3(0, 1, 0)
        let a = o + t * s0 + up * y0, b = o + t * s1 + up * y0
        var s = Surface(material: wall)
        let inner = a, outer = a - n * thick
        let len = t * (s1 - s0), h = up * (y1 - y0), d = -n * thick
        // Orient each face so u x v points outward.
        let half: V3 = (len + h + d) * 0.5
        let boxCenter: V3 = inner + half
        func face(_ c: V3, _ u: V3, _ v: V3, fine: Bool) {
            let nn = simd_cross(u, v)
            let mid: V3 = c + (u + v) * 0.5
            let centerOut: V3 = mid - boxCenter
            let flip = simd_dot(nn, centerOut) < 0
            s.append(gridPanel(corner: flip ? c + u : c, u: flip ? -u : u, v: v, material: wall, cell: fine ? cell : 100))
        }
        face(inner, len, h, fine: true)               // room side
        face(outer, len, h, fine: false)              // outside
        face(inner, d, h, fine: false)                // end at s0 (reveal)
        face(b, d, h, fine: false)                    // end at s1 (reveal)
        face(inner + h, len, d, fine: false)          // top (window head soffit)
        face(inner, len, d, fine: false)              // bottom (sill)
        return s
    }

    func gridBox(_ center: V3, _ size: V3, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let h = size / 2
        for (n, u, v) in [(V3(1, 0, 0), V3(0, 0, -1), V3(0, 1, 0)), (V3(-1, 0, 0), V3(0, 0, 1), V3(0, 1, 0)),
                          (V3(0, 0, 1), V3(1, 0, 0), V3(0, 1, 0)), (V3(0, 0, -1), V3(-1, 0, 0), V3(0, 1, 0))] {
            let c = center + n * h - u * h - v * h
            s.append(gridPanel(corner: c, u: u * size, v: v * size, material: material))
        }
        return s
    }
}
