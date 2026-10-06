import simd
import Foundation

/// Wall-mount chimney range hood, 30 in: brushed stainless visor with a push-button fan control and
/// LED, sloped pyramid canopy, telescoping chimney cover, three stainless baffle filters underneath
/// and two round LED task lamps that light the cooktop. Hung: visor bottom at y = 0, back against
/// the wall at `backZ`; mount it about 0.75 m above the cooktop.
public struct RangeHood: RealArticulated {
    public static let id = "range-hood"
    public static let summary = "Wall-mount chimney range hood, 76 cm: stainless pyramid canopy and chimney, baffle filters, two LED lamps, fan control."
    public static let tags = ["prop", "kitchen", "metal", "appliance", "articulated"]
    public static let budget = 8000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: -8, distance: 1.9, studio: true)

    public var width: Float = 0.76
    public var depth: Float = 0.5
    /// Chimney cover height above the canopy (to the ceiling or soffit).
    public var chimneyHeight: Float = 0.6
    public var stainless: MaterialKey = "metal.stainless"
    public var visorMaterial: MaterialKey = "metal.stainless-smudged"
    public init() {}

    static let visorH: Float = 0.055, canopyH: Float = 0.26, chimneyW: Float = 0.3, chimneyD: Float = 0.25
    public var backZ: Float { -depth / 2 }
    public var height: Float { Self.visorH + Self.canopyH + chimneyHeight }

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [8])
        let W = width, D = depth, vh = Self.visorH, bz = backZ
        let cw = Self.chimneyW, cd = Self.chimneyD
        let topY = vh + Self.canopyH
        let lampXs: [Float] = [-W / 2 + 0.17, W / 2 - 0.17], lampZ = D / 2 - 0.036
        for l in 0..<2 {
            var m = Model(name: Self.id)
            func add(_ s: Surface, _ c: V3) { m.add(s, Xform(translation: c)) }
            // Visor: front, back and side strips around the filter bay; sheet edges rounded.
            add(Prim.roundedBox(V3(W, vh, 0.07), radius: 0.004, bevelSegments: 2, material: visorMaterial), V3(0, vh / 2, D / 2 - 0.035))
            add(Prim.roundedBox(V3(W, vh, 0.04), radius: 0.003, bevelSegments: 1, material: stainless), V3(0, vh / 2, bz + 0.02))
            for sx: Float in [-1, 1] {
                add(Prim.roundedBox(V3(0.04, vh, D - 0.11), radius: 0.003, bevelSegments: 1, material: stainless), V3(sx * (W / 2 - 0.02), vh / 2, (bz + 0.04 + D / 2 - 0.07) / 2))
            }
            // Canopy: lofted from the visor top to the chimney footprint at the back.
            let n = 4
            let bottom = Shape2D.roundedRect(W - 0.002, D - 0.002, radius: 0.018, segments: n)
            let top = Shape2D.roundedRect(cw, cd, radius: 0.012, segments: n)
            m.add(Prim.loft([Prim.ring(bottom, y: vh - 0.001), Prim.ring(bottom, y: vh + 0.012), Prim.ring(top, y: topY, offset: V3(0, 0, bz + cd / 2))],
                            capStart: false, capEnd: false, material: stainless))
            // Chimney cover: lower sleeve and the slightly narrower upper sleeve with a seam lip.
            let lowerH = chimneyHeight * 0.5
            add(Prim.roundedBox(V3(cw, lowerH, cd), radius: 0.004, bevelSegments: 2, material: stainless), V3(0, topY + lowerH / 2, bz + cd / 2))
            add(Prim.roundedBox(V3(cw - 0.006, chimneyHeight - lowerH + 0.02, cd - 0.003), radius: 0.003, bevelSegments: 1, material: stainless),
                V3(0, topY + lowerH + (chimneyHeight - lowerH) / 2 - 0.01, bz + (cd - 0.003) / 2))
            // Filter bay ceiling and three baffle filters (V slats running front to back).
            add(cuboid(V3(W - 0.08, 0.002, D - 0.11), material: "metal.powdercoat:3A3A3A"), V3(0, vh - 0.004, (bz + 0.04 + D / 2 - 0.07) / 2))
            let bayX0 = -W / 2 + 0.04, bayX1 = W / 2 - 0.04, fz0 = bz + 0.04, fz1 = D / 2 - 0.07
            let fw = (bayX1 - bayX0) / 3
            for k in 0..<3 {
                let x0 = bayX0 + Float(k) * fw
                // Frame rim.
                for (sz, zc) in [(Float(0.016), fz0 + 0.01), (Float(0.016), fz1 - 0.01)] {
                    add(Prim.roundedBox(V3(fw - 0.006, 0.012, sz), radius: 0.002, bevelSegments: 1, material: stainless), V3(x0 + fw / 2, 0.012, zc))
                }
                for xe in [x0 + 0.01, x0 + fw - 0.01] {
                    add(Prim.roundedBox(V3(0.016, 0.012, fz1 - fz0 - 0.02), radius: 0.002, bevelSegments: 1, material: stainless), V3(xe, 0.012, (fz0 + fz1) / 2))
                }
                if l == 0 {
                    var x = x0 + 0.03
                    var flip: Float = 1
                    while x < x0 + fw - 0.025 {
                        m.add(cuboid(V3(0.0012, 0.03, fz1 - fz0 - 0.03), material: stainless),
                              Xform(translation: V3(x, 0.024, (fz0 + fz1) / 2), rotation: simd_quatf(degrees: 35 * flip, axis: V3(0, 0, 1))))
                        x += 0.016; flip = -flip
                    }
                    // Pull tab.
                    add(Prim.roundedBox(V3(0.04, 0.008, 0.012), radius: 0.003, bevelSegments: 1, material: stainless), V3(x0 + fw / 2, 0.004, fz1 - 0.02))
                }
            }
            // Lamp bezels (the lenses are the "lamps" part).
            for x in lampXs {
                m.add(Prim.lathe([V2(0.029, 0), V2(0.03, 0.002), V2(0.022, 0.002)], segments: 24, material: stainless), Xform(translation: V3(x, -0.002, lampZ)))
            }
            // Control buttons on the visor front.
            for (i, bx) in [Float(0.12), 0.16, 0.2, 0.24].enumerated() where l == 0 || i < 4 {
                m.add(Prim.lathe([V2(0.0075, 0), V2(0.0075, 0.002), V2(0.006, 0.0035), V2(0.001, 0.004)], segments: 14, material: "plastic.black"),
                      Xform(translation: V3(bx, vh / 2, D / 2), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            }
            rig.base[l] = m
        }
        // Lamps: frosted lenses, lit option + spots onto the cooktop.
        rig.part("lamps", pivot: V3(0, 0, lampZ), joint: .fixed, options: 2)
        for x in lampXs {
            let lens = Prim.lathe([V2(0.001, -0.004), V2(0.019, -0.003), V2(0.022, 0.0)], segments: 20, material: "glass.frosted")
            let lit = Prim.lathe([V2(0.001, -0.004), V2(0.019, -0.003), V2(0.022, 0.0)], segments: 20, material: "emissive.bulb")
            rig.add(lens, Xform(translation: V3(x, 0, lampZ)), to: "lamps")
            rig.add(lit, Xform(translation: V3(x, 0, lampZ)), to: "lamps", option: 1)
        }
        rig.lights = lampXs.enumerated().map { i, x in
            RigLight(name: "hood-lamp-\(i + 1)", kind: .spot(inner: 35, outer: 75), part: "lamps", option: 1, position: V3(x, -0.01, lampZ),
                     direction: V3(0, -1, -0.15), color: V3(1, 0.9, 0.78), intensity: 900, attenuationRadius: 2.5, castsShadow: i == 0)
        }
        // Fan: LED next to the buttons.
        let ledP = V3(0.08, Self.visorH / 2, D / 2 + 0.001)
        rig.part("fan", pivot: ledP, joint: .fixed, options: 2)
        rig.add(Prim.lathe([V2(0.0025, 0), V2(0.002, 0.001), V2(0.001, 0.0012)], segments: 10, material: "plastic.black"),
                Xform(translation: ledP, rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "fan")
        rig.add(Prim.lathe([V2(0.0025, 0), V2(0.002, 0.001), V2(0.001, 0.0012)], segments: 10, material: "emissive.led-green"),
                Xform(translation: ledP, rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "fan", option: 1)
        groundAO(&rig, height: 0.02, floor: 0.75)
        rig.states = [RigState("off"), RigState("lights-on", options: ["lamps": 1]), RigState("fan-on", options: ["fan": 1]),
                      RigState("all-on", options: ["lamps": 1, "fan": 1])]
        return rig
    }
}
