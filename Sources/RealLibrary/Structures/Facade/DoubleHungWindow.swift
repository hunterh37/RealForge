import simd
import Foundation

/// Double-hung sash window, 0.9 x 1.5 m sash opening: painted pine frame (jambs, head, blind stops,
/// parting beads, sloped sill with drip kerf), two 35 mm sashes with six-over-six muntins in separate
/// channels, meeting rails with a brass cam lock, sash lifts, exterior flat casing with drip cap and an
/// interior stool. Base y = 0 is the underside of the sill, exterior faces +Z. The lower sash slides up
/// and the upper sash slides down.
public struct DoubleHungWindow: RealArticulated {
    public static let id = "double-hung-window"
    public static let summary = "Double-hung sash window, 0.9 x 1.5 m: painted frame, two sliding sashes with six-over-six muntins, casing, sill and sash lock."
    public static let tags = ["structure", "architecture", "facade", "window", "wood", "glass", "articulated"]
    public static let budget = 16_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 8, distance: 1.1, studio: true)

    /// Sash opening width (m).
    public var width: Float = 0.9
    /// Sash opening height (m).
    public var height: Float = 1.5
    /// Lites per sash (columns, rows): six-over-six is (3, 2).
    public var lites: (Int, Int) = (3, 2)
    /// Frame depth through the wall (m).
    public var depth: Float = 0.14
    /// Casing face width (m).
    public var casingWidth: Float = 0.09
    public var sashMaterial: MaterialKey = "wood.painted-exterior:F4F1E8"
    public var frameMaterial: MaterialKey = "wood.painted-exterior"
    public var glass: MaterialKey = "glass.pane"
    /// Sill paint: weathered more than the rest (sun and standing water).
    public var sillMaterial: MaterialKey = "wood.barn-white"
    public var hardware: MaterialKey = "metal.brass-aged"
    public var cordMaterial: MaterialKey = "fabric.linen"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [9])
        let W = width, H = height, D = depth
        let sillH: Float = 0.045, jamb: Float = 0.02, st: Float = 0.035
        let y0 = sillH, y1 = sillH + H
        let zUp: Float = 0.022, zLo: Float = -0.022           // sash channels (centers)
        let sashH = H / 2 + 0.019                               // overlap at the meeting rails

        var frame: [Surface] = []
        for sx: Float in [-1, 1] {
            frame.append(FK.vbox(V3(jamb, H + 0.03, D), V3(sx * (W / 2 + jamb / 2), y0 + (H + 0.03) / 2, 0), frameMaterial))
            // Blind stop (exterior), parting bead (between channels), interior stop.
            frame.append(FK.vbox(V3(0.012, H, 0.02), V3(sx * (W / 2 - 0.006), y0 + H / 2, zUp + st / 2 + 0.011), frameMaterial, r: 0.002))
            frame.append(FK.vbox(V3(0.012, H, 0.008), V3(sx * (W / 2 - 0.006), y0 + H / 2, 0), frameMaterial, r: 0.002))
            frame.append(FK.vbox(V3(0.012, H, 0.018), V3(sx * (W / 2 - 0.006), y0 + H / 2, zLo - st / 2 - 0.01), frameMaterial, r: 0.002))
        }
        frame.append(HK.box(V3(W + 2 * jamb, jamb, D), V3(0, y1 + jamb / 2, 0), frameMaterial, r: 0.002))
        frame.append(HK.box(V3(W, 0.012, 0.02), V3(0, y1 - 0.006, zUp + st / 2 + 0.011), frameMaterial, r: 0.002))
        // Sloped sill: horns past the casing, drip nose outside.
        let sillShape: [V2] = [V2(-D / 2 - 0.02, sillH * 0.55), V2(-D / 2 - 0.02, sillH), V2(zLo, sillH), V2(D / 2 + 0.045, sillH * 0.55),
                               V2(D / 2 + 0.045, 0.006), V2(D / 2 + 0.03, 0), V2(-D / 2, 0)]
        let sillLen = W + 2 * (jamb + casingWidth) + 0.05
        frame.append(Prim.extrude(Shape2D.rounded(sillShape, radius: 0.004), depth: sillLen, bevel: 0.003, bevelSegments: 1, material: sillMaterial)
            .transformed(Xform(rotation: simd_quatf(degrees: -90, axis: V3(0, 1, 0)))))
        frame += FK.casing(openW: W + 2 * jamb, openH: H + jamb, width: casingWidth, thick: 0.02, z: D / 2, y0: sillH, mat: frameMaterial, headHeight: casingWidth * 1.15)
        // Interior stool.
        frame.append(HK.box(V3(W + 2 * jamb + 0.16, 0.022, 0.06), V3(0, sillH - 0.011 + 0.005, -D / 2 - 0.03), frameMaterial, r: 0.004))
        rig.addBase(frame)

        // Upper sash: slides down in the outer channel.
        rig.part("upper", pivot: V3(0, y1, zUp), joint: .slide(axis: V3(0, 1, 0), -0.6...0, duration: 1.0))
        for s in FK.sash(w: W - 0.004, h: sashH, t: st, top: 0.05, bottom: 0.03, mat: sashMaterial, glass: glass, muntins: lites, meetingRail: nil) {
            rig.add(s, Xform(translation: V3(0, y1 - sashH - 0.002, zUp)).jittered(&rng, deg: 0, offset: 0.0002), to: "upper")
        }
        // Lower sash: slides up in the inner channel.
        rig.part("lower", pivot: V3(0, y0, zLo), joint: .slide(axis: V3(0, 1, 0), 0...0.7, duration: 1.0))
        for s in FK.sash(w: W - 0.004, h: sashH, t: st, top: 0.03, bottom: 0.07, mat: sashMaterial, glass: glass, muntins: lites) {
            rig.add(s, Xform(translation: V3(0, y0 + 0.002, zLo)), to: "lower")
        }
        // Cam lock on the meeting rails, sash lifts on the bottom rail.
        let my = y0 + 0.002 + sashH - 0.015
        rig.add(HK.box(V3(0.06, 0.006, 0.03), V3(0, my + 0.018, zLo), hardware, r: 0.002), .identity, to: "lower")
        rig.add(Prim.lathe([V2(0, 0), V2(0.012, 0), V2(0.011, 0.006), V2(0.004, 0.012), V2(0, 0.013)], segments: 16, seamTile: 0.05, material: hardware),
                Xform(translation: V3(0.012, my + 0.021, zLo)), to: "lower", lods: 0...0)
        rig.addBase([HK.box(V3(0.05, 0.006, 0.026), V3(0, my + 0.018, zUp - 0.004), hardware, r: 0.002)], lods: 0...0)
        for sx: Float in [-1, 1] {
            let lift = HK.pipe(catmull([V3(-0.02, 0, 0), V3(-0.018, 0, -0.016), V3(0.018, 0, -0.016), V3(0.02, 0, 0)], per: 3), r: 0.004, sides: 8, mat: hardware)
            rig.add(lift, Xform(translation: V3(sx * W * 0.28, y0 + 0.04, zLo - st / 2)), to: "lower", lods: 0...0)
        }

        // Sash cords over brass pulleys near the head (counterweights hide in the jamb pockets).
        for sx: Float in [-1, 1] {
            let px = sx * (W / 2 - 0.004)
            rig.addBase([HK.cyl(r: 0.02, len: 0.004, at: V3(px + sx * 0.003, y1 - 0.07, zLo), axis: V3(1, 0, 0), mat: hardware, seg: 20)], lods: 0...0)
            rig.addBase([HK.pipe([V3(px, y1 - 0.06, zLo), V3(px, y1 - 0.3, zLo)], r: 0.0028, sides: 6, mat: cordMaterial)], lods: 0...0)
        }

        groundAO(&rig, height: 0.1, floor: 0.75)
        rig.states = [RigState("closed"), RigState("lower-open", ["lower": 0.6]), RigState("both-open", ["lower": 0.35, "upper": -0.35])]
        return rig
    }
}
