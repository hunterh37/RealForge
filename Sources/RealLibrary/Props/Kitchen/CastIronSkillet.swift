import simd
import Foundation

/// Seasoned cast-iron skillet, 12 in: sloped walls 4.5 mm thick with two pour spouts, a long tapered
/// handle along +X ending in a teardrop hang hole, a helper loop on the far side, a glossier cooking floor
/// and a carbon-crusted, sand-cast exterior.
///
/// Asset space: base at y = 0, footprint centered on X/Z, pan axis at `floorCenter.x`. The inner floor is
/// its own `Surface` (material `floor`).
public struct CastIronSkillet: RealAsset {
    public static let id = "cast-iron-skillet"
    public static let summary = "Seasoned 12 in cast-iron skillet: sloped walls, pour spouts, long handle with hang hole and helper handle."
    public static let tags = ["prop", "kitchen", "cookware", "metal", "handheld"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 32, distance: 0.8, studio: true)

    /// Top of the inner cooking surface above the base (m).
    public var floorY: Float = 0.0055
    /// Radius of the usable flat floor (m).
    public var innerRadius: Float = 0.122
    /// Height of the rim top (m).
    public var rimY: Float = 0.054
    /// Inner radius at the rim (m).
    public var rimRadius: Float = 0.1455
    /// Wall thickness (m).
    public var wall: Float = 0.0045
    /// Outward reach of each pour spout at the rim (m).
    public var spout: Float = 0.009
    /// Handle length beyond the wall (m).
    public var handleLength: Float = 0.13
    /// Walls, base and handle.
    public var iron: MaterialKey = "metal.cast-iron-seasoned"
    /// Cooking floor (its own surface).
    public var floor: MaterialKey = "metal.cast-iron-floor"
    /// Rubbed rim and handle grip.
    public var worn: MaterialKey = "metal.cast-iron-worn"
    public init() {}

    /// Pan axis on the floor top, in asset space.
    public var floorCenter: V3 { V3(layout().shift, floorY, 0) }
    /// A point on the handle top where a hand closes (asset space).
    public var gripPoint: V3 { let l = layout(); return l.grip + V3(l.shift, 0, 0) }

    struct Layout { var vessel: Vessel; var handle: [V3]; var loopCenter: V3; var t: V3; var shift: Float; var grip: V3; var helperOut: Float }

    func layout() -> Layout {
        let f = floorY, R = innerRadius, dr = rimRadius - innerRadius, top = rimY - wall * 0.5, dh = top - f
        let curve = Profile.smooth([V2(R - 0.012, f), V2(R, f), V2(R + 0.32 * dr, f + 0.08 * dh), V2(R + 0.52 * dr, f + 0.25 * dh),
                                    V2(R + 0.72 * dr, f + 0.55 * dh), V2(R + 0.88 * dr, f + 0.8 * dh), V2(rimRadius, top)], per: 3)
        let v = Vessel(inner: [V2(0, f)] + curve, wall: wall, floorRadius: R, rim: .cut)
        let hy: Float = 0.043
        let ro = v.outerRadius(at: hy)
        let L = handleLength
        let s = V3(ro - 0.004, hy, 0)
        let path = catmull([s, s + V3(0.03 * L / 0.13, 0.003, 0), s + V3(0.07 * L / 0.13, 0.007, 0), s + V3(0.1 * L / 0.13, 0.0095, 0)], per: 5)
        let e = path[path.count - 1], t = simd_normalize(e - path[path.count - 2])
        let lc = e + t * 0.017
        let maxX = lc.x + t.x * (0.02 + 0.0055)
        let helperOut: Float = 0.026
        let minX = -(v.outerRadius(at: 0.046) + helperOut + 0.006)
        return Layout(vessel: v, handle: path, loopCenter: lc, t: t, shift: -(minX + maxX) / 2, grip: path[path.count / 2] + V3(0, 0.007, 0), helperOut: helperOut)
    }

    func model(_ l: Layout, segments: Int, detail: Bool) -> Model {
        let v = l.vessel
        let rimTop = v.rimTop, k = spout
        // Pour spouts at +-Z: the upper wall bulges outward and the rim dips slightly.
        func spouted(_ p: V3) -> V3 {
            let r = simd_length(V2(p.x, p.z))
            guard r > 0.05 else { return p }
            let a = atan2(p.z, p.x)
            let d = min(abs(a - .pi / 2), abs(a + .pi / 2))
            let w = exp(-(d * d) / (2 * 0.16 * 0.16))
            let h = max(0, (p.y - 0.02) / (rimTop - 0.02))
            let push = k * w * h * h
            let s = (r + push) / r
            return V3(p.x * s, p.y - 0.0025 * w * h * h * h, p.z * s)
        }
        var m = Model(name: Self.id)
        var floorSurface: Surface?
        for (role, var s) in v.surfaces(segments: segments, interior: iron, exterior: iron, edge: worn, floorMaterial: floor, seamTile: 0.2, planarFloor: true) {
            if role == .floor { floorSurface = s; continue }
            s.deform(spouted)
            m.add(s)
        }
        // Handle: tapered D-section bar, top rubbed, rising slightly, into a teardrop hang loop.
        let path = l.handle
        let n = path.count
        let scales = path.indices.map { i -> Float in 1.12 - 0.22 * Float(i) / Float(n - 1) }
        let section = Shape2D.superellipse(0.0135, 0.026, exponent: 2.6, segments: detail ? 24 : 12).map { V2($0.x + 0.0005, $0.y) }
        m.add(Prim.sweep(section, along: path, up: .up, scales: scales, grainAlongPath: true, material: iron))
        let t = l.t, z = V3(0, 0, 1), up = simd_normalize(simd_cross(z, t))
        let lp = detail ? 30 : 14
        let loopPts = (0..<lp).map { kk -> V3 in
            let a = Float(kk) / Float(lp) * 2 * .pi
            let w: Float = 0.0105 * (1 + 0.28 * cos(a))
            return l.loopCenter + t * (0.02 * cos(a)) + z * (w * sin(a))
        }
        m.add(Prim.sweep(Shape2D.superellipse(0.0115, 0.011, exponent: 2.6, segments: detail ? 14 : 8), along: loopPts, up: up,
                         closedPath: true, grainAlongPath: true, material: worn))
        // Helper handle: a cast loop on the far side, just under the rim.
        let hy: Float = 0.046, ro = v.outerRadius(at: hy)
        let arc = catmull([V3(-(ro + 0.003) * cos(0.42), hy, (ro + 0.003) * sin(0.42)),
                           V3(-(ro + l.helperOut * 0.55), hy + 0.001, 0.03), V3(-(ro + l.helperOut), hy + 0.002, 0),
                           V3(-(ro + l.helperOut * 0.55), hy + 0.001, -0.03), V3(-(ro + 0.003) * cos(0.42), hy, -(ro + 0.003) * sin(0.42))], per: detail ? 6 : 3)
        m.add(Prim.sweep(Shape2D.superellipse(0.0105, 0.015, exponent: 2.6, segments: detail ? 14 : 8), along: arc, up: .up, material: iron))
        // Center the footprint; the floor goes last as its own surface.
        let shift = Xform(translation: V3(l.shift, 0, 0))
        var out = Model(name: Self.id)
        for s in m.surfaces { out.surfaces.append(s.transformed(shift)) }
        if let fs = floorSurface { out.surfaces.append(fs.transformed(shift)) }
        groundAO(&out, height: 0.03, floor: 0.5)
        return out
    }

    public func build(seed: UInt64) -> LODModel {
        let l = layout()
        return LODModel(levels: [model(l, segments: 96, detail: true), model(l, segments: 40, detail: false)], switchDistances: [3])
    }
}
