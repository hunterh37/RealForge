import simd
import Foundation

/// Ballfield backstop: 12 m center section and two 7 m wings angled 40 degrees toward the field, black
/// vinyl chain link to 6 m over a 1.2 m padded concrete knee wall, galvanized posts every ~3 m with top,
/// middle and bottom rails, and a 2 m sloped hood at the top. The field is toward -Z; origin at the base
/// center of the center section's field face.
public struct Backstop: RealAsset {
    public static let id = "backstop"
    public static let summary = "Backstop: black chain link to 6 m over a padded knee wall, angled wings, galvanized posts and rails, sloped hood."
    public static let tags = ["structure", "sports", "fence", "metal", "outdoor"]
    public static let budget = 12_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 160, elevation: 10, distance: 1.0)

    public var centerWidth: Float = 12
    public var wingWidth: Float = 7
    public var wingAngle: Float = 40
    public var height: Float = 6
    public var kneeWall: Float = 1.2
    public var hood: Float = 2
    public var mesh: MaterialKey = "fence.chainlink-vinyl"
    public var pad: MaterialKey = "padding.vinyl"
    public var post: MaterialKey = "metal.painted:1C1D1E"
    public init() {}

    /// Corner points of the fence line (x, z), left wing end to right wing end.
    public var corners: [V2] {
        let c = centerWidth / 2, a = wingAngle * .pi / 180
        return [V2(-c - wingWidth * cos(a), -wingWidth * sin(a)), V2(-c, 0), V2(c, 0), V2(c + wingWidth * cos(a), -wingWidth * sin(a))]
    }

    /// Mesh in design coordinates (origin as documented above, before centering).
    func model(seed: UInt64) -> Model {
        var m = Model(name: Self.id)
        let pr: Float = 0.045, rr: Float = 0.021
        let pts = corners
        var postXZ: [V2] = []
        for i in 0..<(pts.count - 1) {
            let a = pts[i], b = pts[i + 1], len = simd_length(b - a), d = (b - a) / len
            let n = V2(d.y, -d.x)   // toward the field (-Z for the center section)
            let a3 = V3(a.x, 0, a.y), b3 = V3(b.x, 0, b.y)
            // Knee wall: concrete core with pad on the field face.
            let mid = (a + b) / 2, yaw = atan2(-d.y, d.x) * 180 / .pi
            m.add(Prim.roundedBox(V3(len, kneeWall, 0.2), radius: 0.01, bevelSegments: 1, material: "concrete.rough"),
                  Xform(translation: V3(mid.x, kneeWall / 2, mid.y), rotation: simd_quatf(degrees: yaw, axis: .up)))
            let panels = max(1, Int((len / 1.2).rounded()))
            for k in 0..<panels {
                let t = (Float(k) + 0.5) / Float(panels)
                let p = a + (b - a) * t + n * 0.15
                var s = Prim.superellipsoid(V3(len / Float(panels) - 0.01, kneeWall - 0.06, 0.1), exponent: 8, subdivisions: 5, material: pad)
                s.uvs = s.uvs.map { $0 + V2(Float(k) * 0.41 + Float(i), 0) }
                m.add(s, Xform(translation: V3(p.x, kneeWall / 2, p.y), rotation: simd_quatf(degrees: yaw, axis: .up)))
            }
            // Mesh from the wall top to the top rail.
            m.add(BallKit.fence(a3 + V3(0, kneeWall, 0), b3 + V3(0, kneeWall, 0), height: height - kneeWall, material: mesh))
            // Rails.
            for y in [kneeWall + 0.05, kneeWall + (height - kneeWall) * 0.5, height] {
                m.add(BallKit.pipe(a3 + V3(0, y, 0) + V3(n.x, 0, n.y) * 0.05, b3 + V3(0, y, 0) + V3(n.x, 0, n.y) * 0.05, radius: rr, material: post))
            }
            // Hood: sloped mesh toward the field with rafters.
            let hn = V3(n.x, 0, n.y) * hood
            let top = V3(0, height, 0), hoodRise = V3(0, hood * 0.35, 0)
            var hm = Surface(material: mesh)
            let q0 = a3 + top, q1 = b3 + top, q2 = b3 + top + hn + hoodRise, q3 = a3 + top + hn + hoodRise
            let nrm = simd_normalize(simd_cross(q1 - q0, q3 - q0))
            _ = hm.add(q0, nrm, V2(0, 0)); _ = hm.add(q1, nrm, V2(len, 0)); _ = hm.add(q2, nrm, V2(len, hood)); _ = hm.add(q3, nrm, V2(0, hood))
            hm.quad(0, 1, 2, 3); hm.computeTangents()
            m.add(hm)
            var veil = hm; veil.material = "fence.chainlink-veil"
            m.add(veil, Xform(translation: V3(0, -0.003, 0)))
            m.add(BallKit.pipe(q3, q2, radius: rr, material: post))
            let posts = max(1, Int((len / 3).rounded()))
            for k in 0...posts {
                let p = a + (b - a) * (Float(k) / Float(posts))
                if postXZ.contains(where: { simd_distance($0, p) < 0.1 }) { continue }
                postXZ.append(p)
            }
            for k in 0...posts {
                let p = a + (b - a) * (Float(k) / Float(posts))
                let p3 = V3(p.x, height, p.y)
                m.add(BallKit.pipe(p3, p3 + hn + hoodRise, radius: rr, material: post))
            }
        }
        for p in postXZ {
            m.add(Prim.cylinder(radius: pr, height: height + 0.08, bevel: 0.01, segments: 12, material: post), Xform(translation: V3(p.x, 0, p.y)))
            m.add(turned([(0, height + 0.08), (pr + 0.008, height + 0.08), (pr + 0.008, height + 0.11), (0.02, height + 0.14), (0, height + 0.14)], segments: 12, material: post),
                  Xform(translation: V3(p.x, 0, p.y)))
        }
        groundAO(&m, height: 0.5, floor: 0.6)
        return m
    }

    /// The mesh is re-centered on X/Z; `anchor` is where the design origin landed in mesh coordinates.
    /// Place the asset at `designPoint - anchor` (rotated with it) to put the design origin on `designPoint`.
    public func anchor(seed: UInt64 = 1) -> V2 { -BallKit.centerXZ(model(seed: seed)) }

    public func build(seed: UInt64) -> LODModel {
        let m = model(seed: seed), c = BallKit.centerXZ(m)
        return LODModel(m.transformed(Xform(translation: V3(-c.x, 0, -c.y))))
    }
}
