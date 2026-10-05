import simd
import Foundation

/// Tri-ply saucepan, 2 qt, with lid: straight walls 2.6 mm thick with a flared cut rim, satin interior
/// and a separate floor surface, riveted stay-cool channel handle along +X with a hang loop, heat tint on
/// the lower wall, domed stainless lid with a rolled edge and a riveted loop handle.
///
/// Rig: part `lid` slides up +Y (0...`lidLift`). States: `covered`, `open`. Asset space: base at y = 0,
/// footprint centered, pan axis at `floorCenter.x`.
public struct Saucepan: RealArticulated {
    public static let id = "saucepan"
    public static let summary = "2 qt tri-ply saucepan: straight walls, flared rim, riveted stay-cool handle, domed stainless lid with loop handle."
    public static let tags = ["prop", "kitchen", "cookware", "metal", "container", "handheld", "articulated"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 28, distance: 0.7, studio: true)

    /// Top of the inner floor above the base (m).
    public var floorY: Float = 0.0032
    /// Radius of the flat floor (m).
    public var innerRadius: Float = 0.068
    /// Height of the rim top (m).
    public var rimY: Float = 0.096
    /// Inner radius at the rim (m), before the flare.
    public var rimRadius: Float = 0.081
    /// Wall thickness (m).
    public var wall: Float = 0.0026
    /// Handle length beyond the wall (m) and its rise (m).
    public var handleLength: Float = 0.19
    public var handleRise: Float = 0.03
    /// How far the lid lifts in the `open` state (m).
    public var lidLift: Float = 0.15
    /// Interior wall, floor, exterior and hardware finishes.
    public var interior: MaterialKey = "metal.pan-interior"
    public var floor: MaterialKey = "metal.pan-floor"
    public var exterior: MaterialKey = "metal.heat-tint-light"
    public var hardware: MaterialKey = "metal.stainless"
    public init() {}

    /// Pan axis on the floor top (asset space).
    public var floorCenter: V3 { V3(layout().shift, floorY, 0) }
    /// A point on the handle top where a hand closes (asset space).
    public var gripPoint: V3 { let l = layout(); return l.handle.grip + V3(l.shift, 0, 0) }

    struct Layout { var vessel: Vessel; var handle: HandleLayout; var shift: Float; var lidR: Float; var seatY: Float }

    func layout() -> Layout {
        let f = floorY, R = innerRadius, top = rimY - wall * 0.5
        let rr = rimRadius
        let curve = Profile.smooth([V2(R - 0.01, f), V2(R, f), V2(R + 0.55 * (rr - R), f + 0.0035), V2(rr - 0.0015, f + 0.011),
                                    V2(rr, f + 0.022), V2(rr, top - 0.012), V2(rr + 0.0012, top - 0.005), V2(rr + 0.0036, top)], per: 3)
        let v = Vessel(inner: [V2(0, f)] + curve, wall: wall, floorRadius: R, rim: .cut)
        let h = stayCoolHandleLayout(vessel: v, mountY: rimY - 0.03, length: handleLength, rise: handleRise)
        let minX = -v.rimOuterRadius
        return Layout(vessel: v, handle: h, shift: -(minX + h.maxX) / 2, lidR: rr + 0.0022, seatY: top - 0.0055)
    }

    public func rig(seed: UInt64) -> Rig {
        let l = layout(), v = l.vessel
        let shift = Xform(translation: V3(l.shift, 0, 0))
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3])
        let dome: Float = 0.016
        rig.part("lid", pivot: V3(l.shift, l.seatY, 0), joint: .slide(axis: .up, 0...lidLift, duration: 0.6))
        let lidProfile = domedLidProfile(radius: l.lidR, seatY: l.seatY, dome: dome)
        let beadTop = l.seatY + 0.0044
        func lidSurfaceY(_ r: Float) -> Float { beadTop + dome * (1 - pow(r / (l.lidR - 0.0022), 2)) }
        for (lod, segs, detail) in [(0, 64, true), (1, 32, false)] {
            var m = Model(name: Self.id)
            var floorSurface: Surface?
            for (role, s) in v.surfaces(segments: segs, interior: interior, exterior: exterior, base: nil,
                                        edge: "metal.satin-aluminum", floorMaterial: floor, seamTile: 0.2) {
                if role == .floor { floorSurface = s } else { m.add(s) }
            }
            stayCoolHandle(&m, vessel: v, layout: l.handle, material: hardware, detail: detail)
            var out = Model(name: Self.id)
            for s in m.surfaces { out.surfaces.append(s.transformed(shift)) }
            if let fs = floorSurface { out.surfaces.append(fs.transformed(shift)) }
            rig.base[lod] = out
            // Lid.
            var lid = Model(name: "lid")
            lid.add(Prim.lathe(lidProfile, segments: segs, seamTile: 0.2, material: "metal.tri-ply"))
            lidLoopHandle(&lid, surfaceY: lidSurfaceY, material: hardware, detail: detail)
            rig.add(lid.transformed(shift), to: "lid", lod: lod)
        }
        groundAO(&rig, height: 0.03, floor: 0.55)
        rig.states = [RigState("covered"), RigState("open", ["lid": lidLift])]
        return rig
    }
}
