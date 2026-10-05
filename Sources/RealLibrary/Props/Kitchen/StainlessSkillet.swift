import simd
import Foundation

/// Tri-ply stainless skillet, 10 in: flat floor with a satin spin finish, flared walls 2.6 mm thick, cut
/// pouring rim showing the aluminum core, riveted stay-cool channel handle along +X with a hang loop,
/// blue-gold heat tint on the base and lower wall.
///
/// Asset space: base at y = 0, the footprint centered on X/Z, so the pan axis sits at `floorCenter.x`.
/// The inner floor is the last surface of LOD0 (its own `Surface`).
public struct StainlessSkillet: RealAsset {
    public static let id = "stainless-skillet"
    public static let summary = "10 in tri-ply stainless fry pan: flared walls, cut rim, riveted stay-cool handle, heat-tinted base."
    public static let tags = ["prop", "kitchen", "cookware", "metal", "handheld"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 32, distance: 0.75, studio: true)

    /// Top of the inner cooking surface above the base (m). Equals the base thickness.
    public var floorY: Float = 0.0032
    /// Radius of the usable flat floor (m).
    public var innerRadius: Float = 0.097
    /// Height of the rim top (m).
    public var rimY: Float = 0.05
    /// Inner radius at the rim (m); 10 in pans measure about 0.127.
    public var rimRadius: Float = 0.1275
    /// Wall thickness (m), tri-ply 2.6 mm.
    public var wall: Float = 0.0026
    /// Handle length from the wall to the end of the hang loop (m).
    public var handleLength: Float = 0.19
    /// Interior finish.
    public var interior: MaterialKey = "metal.pan-interior"
    /// Inner floor finish (its own surface).
    public var floor: MaterialKey = "metal.pan-floor"
    /// Exterior finish above the tint line.
    public var exterior: MaterialKey = "metal.tri-ply"
    /// Base and lower-wall finish (heat tint).
    public var base: MaterialKey = "metal.heat-tint"
    /// Handle, bracket and rivets.
    public var hardware: MaterialKey = "metal.stainless"
    public init() {}

    /// Pan axis on the floor top, in asset space (after centering).
    public var floorCenter: V3 { V3(layout().shift, floorY, 0) }
    /// A point on the handle top about two thirds along, where a hand closes (asset space).
    public var gripPoint: V3 { let l = layout(); return l.grip + V3(l.shift, 0, 0) }

    struct Layout { var vessel: Vessel; var handle: [V3]; var loopCenter: V3; var t: V3; var shift: Float; var grip: V3 }

    func layout() -> Layout {
        let f = floorY, R = innerRadius, dr = rimRadius - innerRadius, top = rimY - wall * 0.5
        let dh = top - f
        let curve = Profile.smooth([V2(R - 0.012, f), V2(R, f), V2(R + 0.22 * dr, f + 0.07 * dh), V2(R + 0.4 * dr, f + 0.24 * dh),
                                    V2(R + 0.56 * dr, f + 0.48 * dh), V2(R + 0.72 * dr, f + 0.72 * dh), V2(R + 0.86 * dr, f + 0.9 * dh),
                                    V2(rimRadius, top)], per: 3)
        let v = Vessel(inner: [V2(0, f)] + curve, wall: wall, floorRadius: R, rim: .cut)
        let hy: Float = 0.027
        let ro = v.outerRadius(at: hy)
        let L = handleLength
        let s = V3(ro + 0.003, hy, 0)
        let ctrl = [s, s + V3(0.02 * L / 0.19, 0.011, 0), s + V3(0.06 * L / 0.19, 0.025, 0), s + V3(0.105 * L / 0.19, 0.036, 0), s + V3(0.15 * L / 0.19, 0.043, 0)]
        let path = catmull(ctrl, per: 4)
        let e = path[path.count - 1], t = simd_normalize(e - path[path.count - 2])
        let lc = e + t * 0.016 + V3(0, 0.0045, 0)
        let maxX = lc.x + t.x * (0.017 + 0.0045)
        let minX = -v.rimOuterRadius
        let grip = path[path.count * 2 / 3] + V3(0, 0.011, 0)
        return Layout(vessel: v, handle: path, loopCenter: lc, t: t, shift: -(minX + maxX) / 2, grip: grip)
    }

    func model(_ l: Layout, segments: Int, detail: Bool) -> Model {
        var m = Model(name: Self.id)
        let v = l.vessel
        var floorSurface: Surface?
        for (role, s) in v.surfaces(segments: segments, interior: interior, exterior: exterior, base: base, baseUpTo: 1,
                                    edge: "metal.satin-aluminum", floorMaterial: floor, seamTile: 0.2) {
            if role == .floor { floorSurface = s } else { m.add(s) }
        }
        // Bracket: a plate bent to the wall, two rivets through it with flat heads inside the pan.
        let hy = l.handle[0].y
        let ro = v.outerRadius(at: hy), wallR = (ro + v.innerRadius(at: hy)) / 2
        var plate = Prim.superellipsoid(V3(0.026, 0.0065, 0.034), exponent: 3.2, subdivisions: detail ? 8 : 4, material: hardware)
        plate.deform { p in V3(p.x, p.y - p.z * p.z / (2 * ro), p.z) }
        let n2 = -v.innerNormal(at: hy)                  // outward wall normal in the XY half-plane
        let nOut = simd_normalize(V3(n2.x, n2.y, 0))
        m.add(plate, Xform(translation: V3(ro + 0.0026, hy, 0), rotation: facing(nOut)))
        if detail {
            let ri = v.innerRadius(at: hy)
            for z: Float in [-0.0105, 0.0105] {
                let x = sqrt(ri * ri - z * z)
                let n = simd_normalize(V3(-n2.x * x / ri, -n2.y, -n2.x * z / ri))
                panRivet(&m, at: V3(x, hy, z) - n * 0.0002, normal: n, material: hardware)
                // Outer peened heads on the bracket.
                let xo = sqrt((ro + 0.0058) * (ro + 0.0058) - z * z)
                rivet(&m, at: V3(xo, hy, z), normal: simd_normalize(V3(xo, n2.y * ro, z)), radius: 0.0034, height: 0.0012, segments: 12, material: hardware)
            }
        }
        _ = wallR
        // Stay-cool channel, flaring toward the loop.
        let path = l.handle
        let scales = path.indices.map { i -> Float in 0.82 + 0.26 * Float(i) / Float(path.count - 1) }
        let section = channelSection(width: 0.024, height: 0.011, thickness: 0.0022, segments: detail ? 10 : 5)
        m.add(Prim.sweep(section, along: path, up: .up, scales: scales, grainAlongPath: true, material: hardware))
        // Hang loop: a flattened bar around a teardrop hole, in the plane of the handle end.
        let t = l.t, z = V3(0, 0, 1), up = simd_normalize(simd_cross(z, t))
        let loopPts = (0..<(detail ? 28 : 14)).map { k -> V3 in
            let a = Float(k) / Float(detail ? 28 : 14) * 2 * .pi
            let w: Float = 0.0098 * (1 + 0.22 * cos(a))
            return l.loopCenter + t * (0.0165 * cos(a)) + z * (w * sin(a))
        }
        m.add(Prim.sweep(Shape2D.roundedRect(0.0058, 0.009, radius: 0.0026, segments: detail ? 3 : 1), along: loopPts, up: up,
                         closedPath: true, grainAlongPath: true, material: hardware))
        // Center the footprint.
        let shift = Xform(translation: V3(l.shift, 0, 0))
        var out = Model(name: Self.id)
        for s in m.surfaces { out.surfaces.append(s.transformed(shift)) }
        if let fs = floorSurface { out.surfaces.append(fs.transformed(shift)) }
        groundAO(&out, height: 0.03, floor: 0.55)
        return out
    }

    public func build(seed: UInt64) -> LODModel {
        let l = layout()
        return LODModel(levels: [model(l, segments: 96, detail: true), model(l, segments: 40, detail: false)], switchDistances: [3])
    }
}
