import simd
import Foundation

/// Modernist curtain-wall bay, one 1.5 m x 3.6 m floor module: black steel I-section mullions
/// projecting outside the glass (Mies-style), pressure plates and snap caps, head and sill transoms,
/// tinted vision glass, an opaque spandrel glass panel over the slab edge and a concrete slab nose
/// behind it. Tile modules side by side with `endMullion = false` on all but the last, and stack
/// them every `height`. Exterior faces +Z, base y = 0 is the top of the slab.
public struct CurtainWallPanel: RealAsset {
    public static let id = "curtain-wall-panel"
    public static let summary = "Modernist curtain-wall bay, 1.5 m x 3.6 m floor module: steel I-section mullions, vision glass, spandrel panel at slab, pressure plates and caps."
    public static let tags = ["structure", "architecture", "facade", "window", "metal", "glass", "building"]
    public static let budget = 8_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 8, distance: 1.0, studio: true)

    /// Module width, mullion centre to centre (m).
    public var width: Float = 1.5
    /// Floor-to-floor height (m).
    public var height: Float = 3.6
    /// Spandrel height at the slab (m).
    public var spandrel: Float = 0.9
    /// Intermediate horizontal transoms in the vision zone.
    public var transoms: Int = 0
    /// Projecting I-section depth outside the glass (m).
    public var finDepth: Float = 0.22
    /// Add the right-hand mullion (true for a single module or the last of a run).
    public var endMullion = true
    public var steel: MaterialKey = "metal.anodized-black"
    public var visionGlass: MaterialKey = "glass.curtain"
    public var spandrelGlass: MaterialKey = "glass.curtain"
    /// Back pan behind the spandrel glass.
    public var spandrelBack: MaterialKey = "metal.painted:1E2226"
    public var slabMaterial: MaterialKey = "concrete.smooth"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, H = height, S = spandrel
        let mw: Float = 0.064                 // mullion face width
        let zg: Float = -0.02                  // glass plane
        func both(_ s: Surface) { m.add(s) }

        // I-section: web along Z, flanges at the glass line and at the outer tip.
        let fd = finDepth, fw: Float = 0.1, tf: Float = 0.01, tw: Float = 0.008
        let ipro: [V2] = [V2(-fw / 2, 0), V2(fw / 2, 0), V2(fw / 2, tf), V2(tw / 2, tf), V2(tw / 2, fd - tf), V2(fw / 2, fd - tf),
                          V2(fw / 2, fd), V2(-fw / 2, fd), V2(-fw / 2, fd - tf), V2(-tw / 2, fd - tf), V2(-tw / 2, tf), V2(-fw / 2, tf)]
        let iSection = Prim.extrude(Shape2D.rounded(ipro, radius: 0.0015, segments: 1), depth: H - 0.002, bevel: 0.001, bevelSegments: 1, material: steel)
        let xs: [Float] = endMullion ? [-W / 2, W / 2] : [-W / 2]
        for x in xs {
            // Box mullion behind the glass, pressure plate and cap, then the I fin welded to the cap.
            both(HK.box(V3(mw, H, 0.15), V3(x, H / 2, zg - 0.075 - 0.006), steel, r: 0.003))
            both(HK.box(V3(mw, H, 0.012), V3(x, H / 2, zg + 0.012), steel, r: 0.002))
            both(HK.box(V3(mw - 0.004, H, 0.02), V3(x, H / 2, zg + 0.028), steel, r: 0.005))
            both(iSection.transformed(Xform(translation: V3(x, H / 2, zg + 0.038), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)))))
        }
        // Transoms: sill (slab), spandrel head, intermediates, head.
        var ys: [Float] = [0.03, S]
        for i in 0..<transoms { ys.append(S + (H - S) * Float(i + 1) / Float(transoms + 1)) }
        ys.append(H - 0.03)
        for y in ys {
            both(HK.box(V3(W - mw, mw, 0.15), V3(0, y, zg - 0.081), steel, r: 0.003))
            both(HK.box(V3(W - mw, mw, 0.012), V3(0, y, zg + 0.012), steel, r: 0.002))
            both(HK.box(V3(W - mw - 0.004, mw - 0.004, 0.02), V3(0, y, zg + 0.028), steel, r: 0.005))
        }
        // Glass: spandrel (opaque, with an insulated shadow box behind) and vision lites.
        let gw = W - mw - 0.01
        both(HK.box(V3(gw, S - 0.03 - mw, 0.012), V3(0, (S + 0.03) / 2, zg), spandrelGlass, r: 0.001, seg: 1))
        both(HK.box(V3(gw, S - 0.03 - mw, 0.004), V3(0, (S + 0.03) / 2, zg - 0.012), spandrelBack, r: 0.001, seg: 1))
        for i in 0..<(ys.count - 2) {
            let y0 = ys[i + 1] + mw / 2, y1 = ys[i + 2] - mw / 2
            both(HK.box(V3(gw, y1 - y0 + 0.01, 0.006), V3(0, (y0 + y1) / 2, zg + 0.003), visionGlass, r: 0.001, seg: 1))
            both(HK.box(V3(gw, y1 - y0 + 0.01, 0.006), V3(0, (y0 + y1) / 2, zg - 0.019), visionGlass, r: 0.001, seg: 1))
        }
        // Slab nose with a firestop line behind the spandrel.
        both(HK.box(V3(W, 0.25, 0.2), V3(0, -0.0 + 0.125, zg - 0.26), slabMaterial, r: 0.006))
        both(HK.box(V3(W, 0.03, 0.12), V3(0, 0.25, zg - 0.14), "rubber", r: 0.004))

        groundAO(&m, height: 0.1, floor: 0.8)
        return LODModel(m.transformed(Xform(translation: V3(0, 0, 0.07))))
    }
}
