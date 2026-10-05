import simd
import Foundation

/// Half sheet pan, 18 x 13 in: 0.9 mm aluminum floor, walls flared 12 degrees with rounded folded corners,
/// a rim rolled around a steel wire, and amber baked-on patina that is heaviest on the floor. Long side
/// along X, centered at the origin; the inner floor is its own surface.
public struct BakingSheet: RealAsset {
    public static let id = "baking-sheet"
    public static let summary = "Half sheet pan, 18 x 13 in: aluminum floor, flared walls, rolled wire rim, baked-on amber patina."
    public static let tags = ["prop", "kitchen", "cookware", "metal", "container", "handheld"]
    public static let budget = 8000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 35, distance: 0.9, studio: true)

    /// Inner floor size (m), x by z.
    public var floorSize = V2(0.427, 0.3)
    /// Floor corner radius (m).
    public var cornerRadius: Float = 0.02
    /// Sheet thickness (m), 18 gauge.
    public var thickness: Float = 0.0009
    /// Height of the rim top (m).
    public var rimY: Float = 0.0255
    /// Wall flare from vertical (degrees).
    public var flare: Float = 12
    /// Rolled rim bead radius (m).
    public var bead: Float = 0.0034
    public var floorMaterial: MaterialKey = "metal.sheet-pan"
    public var wallMaterial: MaterialKey = "metal.sheet-pan-light"
    public init() {}

    /// Top of the inner floor (m).
    public var floorY: Float { thickness }
    /// Half the short side of the flat floor (m).
    public var innerRadius: Float { floorSize.y / 2 }
    /// Half the short inner side at the rim (m).
    public var rimRadius: Float { innerRadius + profile().wallTopOffset }

    struct Profile2 { var inner: [V2]; var outer: [V2]; var bead: [V2]; var wallTopOffset: Float }

    /// (outward offset from the floor outline, y) for the inner wall, bead and outer wall.
    func profile(arc: Int = 4) -> Profile2 {
        let t = thickness, b = bead, r: Float = 0.004, a = flare * .pi / 180
        let fy = t
        let d = V2(sin(a), cos(a)), n = V2(cos(a), -sin(a))
        let c = V2(0, fy + r)
        var inner: [V2] = (0...arc).map { k in let th = Float(k) / Float(arc) * (.pi / 2 - a); return c + V2(sin(th), -cos(th)) * r }
        let topInnerY = rimY - b + b * sin(a)
        let start = inner.last!
        let top = start + d * ((topInnerY - start.y) / d.y)
        inner.append(top)
        let C = top + n * b
        let tuck = acos(max(-1, min(1, 1 - t / b)))
        let steps = 14
        let beadPts = (0...steps).map { k -> V2 in
            let phi = Float(k) / Float(steps) * (2 * .pi - tuck)
            return C + (-n * cos(phi) + d * sin(phi)) * b
        }
        let join = beadPts.last!
        var outer: [V2] = [join]
        outer.append(start + n * t + d * ((join.y - (start + n * t).y) / d.y) * 0.98)
        outer.append(contentsOf: (0...arc).reversed().map { k -> V2 in let th = Float(k) / Float(arc) * (.pi / 2 - a); return c + V2(sin(th), -cos(th)) * (r + t) })
        return Profile2(inner: inner, outer: outer, bead: beadPts, wallTopOffset: top.x)
    }

    func outline(corner: Int, spacing: Float) -> [V2] {
        let base = Shape2D.roundedRect(floorSize.x, floorSize.y, radius: cornerRadius, segments: corner)
        var out: [V2] = []
        for i in base.indices {
            let a = base[i], b = base[(i + 1) % base.count]
            let k = max(1, Int((simd_distance(a, b) / spacing).rounded(.up)))
            for j in 0..<k { out.append(a + (b - a) * (Float(j) / Float(k))) }
        }
        return Shape2D.deduped(out)
    }

    func model(corner: Int, spacing: Float, arc: Int) -> Model {
        let o = outline(corner: corner, spacing: spacing)
        let p = profile(arc: arc)
        let rings = (p.inner + p.bead.dropFirst() + p.outer.dropFirst()).map { q in Prim.ring(Shape2D.offset(o, q.x), y: q.y) }
        var wall = Prim.loft(rings, capEnd: true, material: wallMaterial)
        if let i = wall.positions.indices.max(by: { wall.positions[$0].y < wall.positions[$1].y }), wall.normals[i].y < 0 { wall = wall.flipped() }
        // Floor: planar fan over the floor outline, facing up.
        var floor = Surface(material: floorMaterial)
        let c = floor.add(V3(0, floorY, 0), .up, V2(0.5, 0.5))
        for q in o { floor.add(V3(q.x, floorY, -q.y), .up, V2(q.x + 0.5, -q.y + 0.5)) }
        let n = UInt32(o.count)
        for k in 0..<n {
            let a = 1 + k, b = 1 + (k + 1) % n
            let fn = simd_cross(floor.positions[Int(a)] - floor.positions[Int(c)], floor.positions[Int(b)] - floor.positions[Int(c)])
            if fn.y >= 0 { floor.tri(c, a, b) } else { floor.tri(c, b, a) }
        }
        floor.computeTangents()
        var m = Model(name: Self.id)
        m.add(wall)
        m.surfaces.append(floor)
        groundAO(&m, height: 0.01, floor: 0.6)
        return m
    }

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(corner: 8, spacing: 0.03, arc: 4), model(corner: 4, spacing: 0.1, arc: 2)], switchDistances: [3])
    }
}
