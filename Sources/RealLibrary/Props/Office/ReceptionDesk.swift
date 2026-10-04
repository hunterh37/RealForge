import simd
import Foundation

/// Reception counter, 260 x 85 x 110 cm. Visitor side (+Z): vertical walnut slats (40 x 22 mm, 12 mm
/// shadow gaps on a black backer) between walnut end panels, a 30 mm dark marble transaction ledge
/// overhanging the front, a recessed black plinth with a warm LED line, and a lowered accessible section
/// (top at 76 cm) on the right end. Staff side: 25 mm white laminate work surface at 74 cm.
public struct ReceptionDesk: RealAsset {
    public static let id = "reception-desk"
    public static let summary = "Reception counter: walnut slat fascia, dark marble ledge, lowered accessible end, laminate work surface and LED plinth."
    public static let tags = ["prop", "office", "furniture", "stone", "wood"]
    public static let budget = 8_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 14, distance: 1.05, studio: true)

    public var width: Float = 2.6
    public var depth: Float = 0.85
    public var height: Float = 1.1
    /// Width of the lowered accessible section at the right end (0 removes it).
    public var lowWidth: Float = 0.85
    public var wood: MaterialKey = "wood.veneer-walnut"
    public var stone: MaterialKey = "stone.marble-dark"
    public var work: MaterialKey = "laminate.white:EEEDE9"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [8])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, D = depth, H = height
        let black: MaterialKey = "plastic.black"
        let endT: Float = 0.025, plinthH: Float = 0.08, ledgeT: Float = 0.03, workT: Float = 0.025
        let lowTop: Float = 0.76, workTop: Float = 0.74
        let bodyD: Float = 0.25, zFront = D / 2, zBody = D / 2 - bodyD
        let split = W / 2 - lowWidth
        let seg = detail ? 2 : 1
        func box(_ size: V3, _ c: V3, _ mat: MaterialKey, r: Float = 0.002) {
            m.add(Prim.roundedBox(size, radius: r, bevelSegments: seg, material: mat), Xform(translation: c).jittered(&rng, deg: 0.02, offset: 0.0002))
        }
        func span(_ x0: Float, _ x1: Float) -> (Float, Float) { ((x0 + x1) / 2, x1 - x0) }

        // End panels: front body part up to the ledge / low top, rear part up to the work surface.
        let leftX = -W / 2 + endT / 2, rightX = W / 2 - endT / 2
        let highTop = H - ledgeT
        box(V3(endT, highTop, bodyD), V3(leftX, highTop / 2, zBody + bodyD / 2), wood)
        box(V3(endT, workTop - workT, D - bodyD), V3(leftX, (workTop - workT) / 2, -D / 2 + (D - bodyD) / 2), wood)
        box(V3(endT, lowTop - ledgeT, D), V3(rightX, (lowTop - ledgeT) / 2, 0), wood)
        // Gable at the step: carries the work surface end, the low top and the end of the high ledge.
        box(V3(endT, lowTop - ledgeT, D), V3(split, (lowTop - ledgeT) / 2, 0), wood)
        box(V3(endT, highTop - lowTop, bodyD), V3(split, lowTop + (highTop - lowTop) / 2, zBody + bodyD / 2), wood)

        // Plinth (recessed 50 mm) and black slat backer.
        let (px, pw) = span(-W / 2 + endT, W / 2 - endT)
        box(V3(pw, plinthH, bodyD - 0.06), V3(px, plinthH / 2, zBody + (bodyD - 0.06) / 2), black, r: 0.001)
        for (x0, x1, top) in [(-W / 2 + endT, split - endT / 2, highTop), (split + endT / 2, W / 2 - endT, lowTop - ledgeT)] {
            let (cx, w) = span(x0, x1)
            box(V3(w, top - plinthH, 0.018), V3(cx, plinthH + (top - plinthH) / 2, zFront - 0.04), black, r: 0.001)
            // Bottom rail closing the plinth recess.
            box(V3(w, 0.018, bodyD - 0.02), V3(cx, plinthH + 0.009, zBody + bodyD / 2), wood)
        }
        // Warm LED line along the top of the plinth recess.
        m.add(cuboid(V3(pw - 0.02, 0.006, 0.004), material: "emissive.panel"), Xform(translation: V3(px, plinthH - 0.006, zFront - 0.06 + 0.002)))

        // Slats: 40 x 22 mm, 52 mm pitch, grain vertical.
        let slat = Shape2D.roundedRect(0.04, 0.022, radius: 0.003, segments: detail ? 2 : 1)
        let x0 = -W / 2 + endT + 0.006, x1 = W / 2 - endT - 0.006
        let count = Int(((x1 - x0) / 0.052).rounded(.down))
        let pitch = (x1 - x0) / Float(count)
        for i in 0..<count {
            let x = x0 + (Float(i) + 0.5) * pitch
            if abs(x - split) < 0.032 { continue }
            let top = x < split ? highTop : lowTop - ledgeT
            let s = Prim.sweep(slat, along: [V3(0, plinthH + 0.018, 0), V3(0, top - 0.001, 0)], up: V3(0, 0, 1), grainAlongPath: true, material: wood)
            m.add(s, Xform(translation: V3(x, 0, zFront - 0.02)).jittered(&rng, deg: 0.04, offset: 0.0003))
        }

        // Marble: high transaction ledge (35 mm front overhang) and the low accessible top.
        let (hx, hw) = span(-W / 2, split + endT / 2)
        let ledgeD = bodyD + 0.07
        box(V3(hw, ledgeT, ledgeD), V3(hx, H - ledgeT / 2, zFront + 0.035 - ledgeD / 2), stone, r: 0.003)
        let (lx, lw) = span(split - endT / 2, W / 2)
        box(V3(lw, ledgeT, D + 0.035), V3(lx, lowTop - ledgeT / 2, 0.0175), stone, r: 0.003)

        // Staff side: work surface and the laminate inner face of the high body.
        let (wx, ww) = span(-W / 2 + endT, split - endT / 2)
        box(V3(ww, workT, D - bodyD), V3(wx, workTop - workT / 2, -D / 2 + (D - bodyD) / 2), work)
        box(V3(ww, highTop - workTop, 0.018), V3(wx, workTop + (highTop - workTop) / 2, zBody + 0.009), work)
        // Inner body face below the work surface (modesty) and a hidden rail.
        box(V3(ww, workTop - workT - plinthH, 0.018), V3(wx, plinthH + (workTop - workT - plinthH) / 2, zBody + 0.009), work)
        if detail {
            // Cable grommet in the work surface.
            m.add(Prim.lathe([V2(0.03, -0.02), V2(0.03, 0), V2(0.04, 0.0005), V2(0.04, 0.0015), V2(0.0385, 0.0025), V2(0.03, 0.0025), V2(0, 0.0015)],
                             segments: 24, seamTile: 0.1, material: black),
                  Xform(translation: V3(wx - ww / 2 + 0.35, workTop, zBody - 0.08)))
        }
        groundAO(&m, height: 0.12, floor: 0.55)
        return m
    }
}
