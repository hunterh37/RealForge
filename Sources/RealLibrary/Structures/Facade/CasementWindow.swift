import simd
import Foundation

/// Pair of outswing casement windows, 1.0 x 1.2 m frame opening: painted frame with center mullion,
/// two 45 mm sashes with 2 x 3 divided lites, butt hinges on the outer jambs, brick-mould casing, a
/// sloped stone sill with drip and interior crank operators. Base y = 0 is the underside of the stone
/// sill, exterior faces +Z; each sash swings outward about its outer jamb.
public struct CasementWindow: RealArticulated {
    public static let id = "casement-window"
    public static let summary = "Pair of outswing casement windows: painted frame and mullion, two hinged sashes with divided lites, crank operators and stone sill."
    public static let tags = ["structure", "architecture", "facade", "window", "wood", "glass", "articulated"]
    public static let budget = 18_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 8, distance: 1.1, studio: true)

    /// Frame opening width (m), split between two sashes.
    public var width: Float = 1.0
    /// Frame opening height (m).
    public var height: Float = 1.2
    /// Lites per sash (columns, rows).
    public var lites: (Int, Int) = (2, 3)
    /// Frame depth through the wall (m).
    public var depth: Float = 0.14
    public var sashMaterial: MaterialKey = "wood.painted-exterior:34433D"
    public var frameMaterial: MaterialKey = "wood.painted-exterior:3A4A44"
    public var sillMaterial: MaterialKey = "stone.cast-grey"
    /// Bottom frame rail paint, weathered by standing water.
    public var weatheredMaterial: MaterialKey = "wood.barn-white:56625C"
    public var glass: MaterialKey = "glass.pane"
    public var hardware: MaterialKey = "metal.wrought-iron"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [9])
        let W = width, H = height, D = depth
        let sillH: Float = 0.07, fr: Float = 0.045, mul: Float = 0.06, st: Float = 0.045
        let y0 = sillH + fr, y1 = sillH + fr + H
        let zs = D / 2 - st / 2 - 0.004                 // sash plane, flush near the exterior face

        var frame: [Surface] = []
        for sx: Float in [-1, 1] {
            frame.append(FK.vbox(V3(fr, H + 2 * fr, D), V3(sx * (W / 2 + fr / 2), sillH + (H + 2 * fr) / 2, 0), frameMaterial))
            // Brick-mould casing: rounded half-round edge on the exterior.
            frame.append(FK.vbox(V3(0.06, H + 2 * fr + 0.06, 0.032), V3(sx * (W / 2 + fr + 0.03), sillH + (H + 2 * fr + 0.06) / 2, D / 2 + 0.016), frameMaterial, r: 0.012))
        }
        frame.append(HK.box(V3(W + 2 * fr + 0.12, 0.06, 0.032), V3(0, y1 + fr + 0.03, D / 2 + 0.016), frameMaterial, r: 0.012))
        frame.append(HK.box(V3(W, fr, D), V3(0, y1 + fr / 2, 0), frameMaterial, r: 0.002))
        // Bottom frame rail with a sloped weathering.
        frame.append(HK.box(V3(W, fr, D), V3(0, sillH + fr / 2, 0), weatheredMaterial, r: 0.003))
        frame.append(FK.vbox(V3(mul, H, D - 0.02), V3(0, y0 + H / 2, -0.01), frameMaterial))
        // Interior stops.
        for sx: Float in [-1, 1] {
            frame.append(FK.vbox(V3(0.012, H, 0.02), V3(sx * (W / 2 - 0.006), y0 + H / 2, zs - st / 2 - 0.012), frameMaterial, r: 0.002))
            frame.append(FK.vbox(V3(0.012, H, 0.02), V3(sx * (mul / 2 + 0.006), y0 + H / 2, zs - st / 2 - 0.012), frameMaterial, r: 0.002))
        }
        // Stone sill with drip groove, horns past the casing.
        let sl: [V2] = [V2(-D / 2, sillH), V2(D / 2 - 0.02, sillH), V2(D / 2 + 0.07, sillH - 0.022), V2(D / 2 + 0.07, 0.006), V2(D / 2 + 0.06, 0), V2(-D / 2, 0)]
        frame.append(Prim.extrude(Shape2D.rounded(sl, radius: 0.004), depth: W + 2 * fr + 0.2, bevel: 0.004, bevelSegments: 1, material: sillMaterial)
            .transformed(Xform(rotation: simd_quatf(degrees: -90, axis: V3(0, 1, 0)))))
        rig.addBase(frame)

        // Sashes: left hinged on the left jamb, right on the right jamb, both swing out (+Z).
        let sw = (W - mul) / 2 - 0.004, sh = H - 0.006
        for (name, sx, range) in [("left", Float(-1), Float(-95)...0), ("right", Float(1), Float(0)...95)] {
            let px = sx * (W / 2 - 0.001), pz = zs + st / 2 + 0.002
            rig.part(name, pivot: V3(px, 0, pz), joint: .hinge(axis: .up, range, duration: 1.2))
            let cx = sx * (W / 2 - 0.002 - sw / 2)
            for s in FK.sash(w: sw, h: sh, t: st, stile: 0.05, top: 0.05, bottom: 0.065, mat: sashMaterial, glass: glass, muntins: lites) {
                rig.add(s, Xform(translation: V3(cx, y0 + 0.003, zs)).jittered(&rng, deg: 0, offset: 0.0002), to: name)
            }
            for hy in [y0 + 0.15, y1 - 0.15] {
                let k = FK.hingeKnuckles(at: V3(px, hy, pz), length: 0.08, r: 0.0055, mat: hardware)
                rig.addBase(k.frame); rig.add(k.leaf, to: name, lods: 0...0)
            }
            // Cockspur handle on the meeting stile (interior face).
            let hx = sx * (mul / 2 + 0.03)
            rig.add(HK.box(V3(0.022, 0.06, 0.006), V3(hx, y0 + H / 2, zs - st / 2 - 0.003), hardware, r: 0.002), .identity, to: name)
            rig.add(HK.pipe(catmull([V3(hx, y0 + H / 2, zs - st / 2 - 0.006), V3(hx, y0 + H / 2 - 0.01, zs - st / 2 - 0.03), V3(hx, y0 + H / 2 - 0.09, zs - st / 2 - 0.036)], per: 3),
                            r: 0.0055, sides: 10, mat: hardware), .identity, to: name)
            // Crank operator housing on the bottom rail, interior side.
            let ox = sx * (W / 4 + 0.02)
            rig.addBase([HK.box(V3(0.11, 0.025, 0.05), V3(ox, y0 + 0.012, zs - st / 2 - 0.035), hardware, r: 0.006)])
            rig.addBase([HK.cyl(r: 0.009, len: 0.03, at: V3(ox, y0 + 0.02, zs - st / 2 - 0.065), axis: V3(0, 0, -1), mat: hardware)], lods: 0...0)
        }

        groundAO(&rig, height: 0.1, floor: 0.75)
        rig.states = [RigState("closed"), RigState("left-open", ["left": -70]), RigState("open", ["left": -80, "right": 80])]
        return rig
    }
}
