import simd
import Foundation

/// 8 qt stainless stock pot: straight walls with a rolled rim, an encapsulated base disc with a light heat
/// tint, cast loop handles riveted on both sides (along X), tempered glass lid with a steel rim, steel
/// knob and a vent grommet.
///
/// Rig: `lid-lift` slides +Y (0...0.12), its child `lid` tilts about X at the +Z edge (0...30 degrees).
/// States: `covered`, `ajar`, `open`. The pot axis is at the asset origin; the inner floor is its own
/// surface.
public struct StockPot: RealArticulated {
    public static let id = "stock-pot"
    public static let summary = "8 qt stainless stock pot: encapsulated base, riveted loop handles, glass lid with steel rim and knob."
    public static let tags = ["prop", "kitchen", "cookware", "metal", "container", "handheld", "articulated"]
    public static let budget = 15000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 26, distance: 0.9, studio: true)

    /// Top of the inner floor above the base (m).
    public var floorY: Float = 0.0075
    /// Radius of the flat floor (m).
    public var innerRadius: Float = 0.11
    /// Height of the rim top (m).
    public var rimY: Float = 0.178
    /// Inner radius at the rim (m).
    public var rimRadius: Float = 0.121
    /// Wall thickness (m).
    public var wall: Float = 0.0015
    /// Lid lift in the `open` state (m).
    public var lidLift: Float = 0.12
    public var interior: MaterialKey = "metal.pan-interior"
    public var floor: MaterialKey = "metal.pan-floor"
    public var exterior: MaterialKey = "metal.mirror-polish"
    public var baseDisc: MaterialKey = "metal.heat-tint-light"
    public var glass: MaterialKey = "glass.clear"
    public var hardware: MaterialKey = "metal.stainless"
    public init() {}

    /// Pot axis on the floor top (asset space).
    public var floorCenter: V3 { V3(0, floorY, 0) }

    func vessel() -> Vessel {
        let f = floorY, R = innerRadius, rr = rimRadius, top = rimY - 0.0052
        let curve = Profile.smooth([V2(R - 0.01, f), V2(R, f), V2(R + 0.6 * (rr - R), f + 0.003), V2(rr, f + 0.012),
                                    V2(rr, top - 0.03), V2(rr, top)], per: 3)
        return Vessel(inner: [V2(0, f)] + curve, wall: wall, floorRadius: R, rim: .rolled(0.0026))
    }

    public func rig(seed: UInt64) -> Rig {
        let v = vessel()
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3])
        let ro = v.outerRadius(at: rimY - 0.04)
        let lidR = v.rimOuterRadius - 0.001, seatY = v.rimTop - 0.0015, dome: Float = 0.02
        rig.part("lid-lift", pivot: V3(0, seatY, 0), joint: .slide(axis: .up, 0...lidLift, duration: 0.6))
        rig.part("lid", parent: "lid-lift", pivot: V3(0, seatY, lidR), joint: .hinge(axis: V3(1, 0, 0), 0...30, duration: 0.5))
        for (lod, segs, detail) in [(0, 60, true), (1, 30, false)] {
            var m = Model(name: Self.id)
            var floorSurface: Surface?
            for (role, s) in v.surfaces(segments: segs, interior: interior, exterior: exterior, base: baseDisc, baseUpTo: 0.02, floorMaterial: floor, seamTile: 0.25) {
                if role == .floor { floorSurface = s } else { m.add(s) }
            }
            // Encapsulated base disc under the body.
            let dR = v.outerRadius(at: 0.012) - 0.006
            m.add(Prim.lathe([V2(0, 0), V2(dR - 0.003, 0), V2(dR, 0.0025), V2(dR - 0.0005, 0.0062), V2(dR - 0.004, 0.0072)],
                             segments: segs, seamTile: 0.35, material: baseDisc))
            // Loop handles on both sides.
            let hy = rimY - 0.04
            for s: Float in [-1, 1] {
                let ctrl = [V3(ro + 0.002, hy, -0.034), V3(ro + 0.03, hy + 0.006, -0.03), V3(ro + 0.046, hy + 0.011, -0.012),
                            V3(ro + 0.046, hy + 0.011, 0.012), V3(ro + 0.03, hy + 0.006, 0.03), V3(ro + 0.002, hy, 0.034)]
                let path = catmull(ctrl, per: detail ? 5 : 3).map { V3(s * $0.x, $0.y, $0.z) }
                m.add(Prim.sweep(Shape2D.superellipse(0.0095, 0.017, exponent: 3, segments: detail ? 16 : 8), along: path, up: .up,
                                 grainAlongPath: true, material: hardware))
                for z: Float in [-0.034, 0.034] {
                    m.add(Prim.superellipsoid(V3(0.022, 0.006, 0.02), exponent: 3, subdivisions: detail ? 5 : 3, material: hardware),
                          Xform(translation: V3(s * (ro + 0.002), hy, z), rotation: facing(V3(s, 0, 0))))
                    if detail {
                        let ri = v.innerRadius(at: hy)
                        let x = sqrt(ri * ri - z * z)
                        panRivet(&m, at: V3(s * x, hy, z), normal: simd_normalize(V3(-s * x, 0, -z)), radius: 0.0035, material: hardware)
                    }
                }
            }
            if let fs = floorSurface { m.surfaces.append(fs) }
            rig.base[lod] = m
            // Lid: tempered glass dome, steel rim over the edge, vent grommet, knob.
            var lid = Model(name: "lid")
            lid.add(Prim.lathe(domedLidProfile(radius: lidR - 0.002, seatY: seatY + 0.001, dome: dome, shell: 0.004, bead: 0.0018),
                               segments: segs, seamTile: 0.3, material: glass))
            var rim: [V2] = []
            for k in 0...10 { let a = -Float.pi * 0.62 + Float(k) / 10 * Float.pi * 1.3; rim.append(V2(lidR - 0.003 + cos(a) * 0.0042, seatY + 0.0035 + sin(a) * 0.0042)) }
            lid.add(Prim.lathe(rim.reversed(), segments: segs, seamTile: 0.3, material: hardware))
            func topY(_ r: Float) -> Float { seatY + 0.001 + 0.0036 + dome * (1 - pow(r / (lidR - 0.0038), 2)) }
            lid.add(Prim.torus(major: 0.0035, minor: 0.0012, segments: 12, sides: 6, material: hardware),
                    Xform(translation: V3(-0.07, topY(0.07) + 0.0006, 0.07 * 0.0)))
            let k0 = topY(0)
            lid.add(turned([(0, k0 - 0.001), (0.016, k0 - 0.001), (0.016, k0 + 0.001), (0.009, k0 + 0.004), (0.0075, k0 + 0.014),
                            (0.012, k0 + 0.02), (0.0175, k0 + 0.024), (0.018, k0 + 0.028), (0.012, k0 + 0.031), (0, k0 + 0.032)],
                           segments: detail ? 32 : 16, material: hardware))
            rig.add(lid, to: "lid", lod: lod)
        }
        groundAO(&rig, height: 0.04, floor: 0.55)
        rig.states = [RigState("covered"), RigState("ajar", ["lid-lift": 0.012, "lid": 14]), RigState("open", ["lid-lift": lidLift, "lid": 30])]
        return rig
    }
}
