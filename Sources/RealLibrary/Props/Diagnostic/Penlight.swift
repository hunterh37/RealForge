import simd
import Foundation

/// Reusable aluminium medical penlight (hospital-issue diagnostic penlight class), 132 mm long, 12 mm
/// barrel: anodized barrel with a printed pupil gauge, chrome tail cap with a black push button, chrome
/// clip ring and steel pocket clip, chrome bezel with a reflector, bulb and domed lens. Lies on the
/// table along X, clip up. The clip hinges a few degrees about its ring; the tail button slides in and
/// switches the bulb, which carries a narrow spot light.
public struct Penlight: RealArticulated {
    public static let id = "penlight"
    public static let summary = "Aluminium medical penlight, 13 cm: anodized barrel, pocket clip, push-button tail cap and a lensed bulb end."
    public static let tags = ["prop", "medical", "handheld", "articulated", "tool", "light", "metal"]
    public static let budget = 3_450
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 30, distance: 0.34, studio: true)

    /// Overall length (m).
    public var length: Float = 0.132
    /// Barrel radius (m).
    public var radius: Float = 0.006
    /// Barrel anodizing tint (sRGB hex).
    public var barrelColor: UInt32 = 0x1F2D57
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [2.5])
        let L = length, R = radius
        let x0 = -L / 2, x1 = L / 2
        let yc: Float = R + 0.0004                       // clip ring and bezel are the widest, resting on the table
        let alu: MaterialKey = "metal.anodized:" + String(format: "%06X", barrelColor)
        let chrome: MaterialKey = "metal.chrome"
        let toX = simd_quatf(degrees: -90, axis: V3(0, 0, 1))   // lathe +Y -> +X
        func axial(_ prof: [V2], _ segs: Int, _ mat: MaterialKey, seam: Float = 0.02) -> Surface {
            Prim.lathe(prof, segments: segs, seamTile: seam, material: mat).transformed(Xform(translation: V3(0, yc, 0), rotation: toX))
        }
        let segs = [22, 10]

        for l in 0..<2 {
            var m = Model(name: Self.id)
            let sg = segs[l]
            // Tail cap: chrome, rounded shoulder, recess for the button.
            let tc0 = x0 + 0.0015
            m.add(axial([V2(0, tc0 + 0.0008), V2(0.0033, tc0 + 0.0008), V2(0.0035, tc0), V2(0.0051, tc0), V2(0.0058, tc0 + 0.0005),
                         V2(R + 0.0001, tc0 + 0.0014), V2(R + 0.0001, x0 + 0.0135), V2(R - 0.0002, x0 + 0.014)], sg, chrome))
            // Clip ring: proud band the clip is pressed into.
            let cr = x0 + 0.014
            m.add(axial([V2(R - 0.0002, cr), V2(R + 0.0003, cr + 0.0003), V2(R + 0.0004, cr + 0.0007), V2(R + 0.0004, cr + 0.0028),
                         V2(R + 0.0003, cr + 0.0032), V2(R - 0.0002, cr + 0.0035)], sg, chrome))
            // Barrel with two rolled grip grooves near the head.
            let b0 = cr + 0.0035, b1 = x1 - 0.017
            var bar: [V2] = [V2(R - 0.0003, b0 - 0.0002), V2(R, b0 + 0.0004)]
            if l == 0 {
                for g: Float in [0.012, 0.0085] {
                    let gx = b1 - g
                    bar += [V2(R, gx - 0.0006), V2(R - 0.00035, gx - 0.0002), V2(R - 0.00035, gx + 0.0002), V2(R, gx + 0.0006)]
                }
            }
            bar += [V2(R, b1 - 0.0004), V2(R - 0.0003, b1 + 0.0002)]
            m.add(axial(bar, sg, alu, seam: 0.0376))
            // Head bezel: chrome, slight flare, front lip, then the reflector cone inside.
            m.add(axial([V2(R - 0.0003, b1), V2(R + 0.0002, b1 + 0.0012), V2(R + 0.0004, b1 + 0.003), V2(R + 0.0004, x1 - 0.0022),
                         V2(R + 0.0001, x1 - 0.0009), V2(R - 0.0006, x1 - 0.0002), V2(0.0043, x1 - 0.0004), V2(0.0039, x1 - 0.0012),
                         V2(0.0017, x1 - 0.0052), V2(0, x1 - 0.0053)], sg, chrome))
            // Lens: shallow clear dome in the bezel.
            m.add(axial([V2(0, x1 + 0.0004), V2(0.0022, x1 + 0.0001), V2(0.0036, x1 - 0.0004), V2(0.0042, x1 - 0.0009)], sg, "glass.clear"))
            rig.base[l] = m
        }
        // Ellipse wrapped onto the barrel at angle th0 (from +Z toward +Y), centred at x = cx.
        func wrapped(_ s: inout Surface, cx: Float, th0: Float, rx: Float, ry: Float, lift: Float = 0.00009, n: Int = 12) {
            let rr = R + lift
            func at(_ u: Float, _ v: Float) -> (V3, V3) {
                let th = th0 + v / R
                return (V3(cx + u, yc + rr * sin(th), rr * cos(th)), V3(0, sin(th), cos(th)))
            }
            let (pc, nc) = at(0, 0)
            let c0 = s.add(pc, nc, V2(cx, 0))
            for ring in 1...2 {
                let k = Float(ring) / 2
                for i in 0...n {
                    let a = Float(i) / Float(n) * 2 * .pi
                    let (p, nn) = at(k * rx * cos(a), k * ry * sin(a))
                    _ = s.add(p, nn, V2(cx + k * rx * cos(a), k * ry * sin(a)))
                }
            }
            let row = UInt32(n + 1)
            for i in 0..<UInt32(n) {
                s.tri(c0, c0 + 1 + i, c0 + 2 + i)
                let a = c0 + 1 + i
                s.quad(a, a + row, a + row + 1, a + 1)
            }
        }
        // Pupil gauge: 1 to 6 mm printed dots on the barrel side.
        var dots = Surface(material: "plastic.matte:C9CAC6")
        var dx = x0 + 0.03
        for k in 1...6 {
            let r = Float(k) * 0.0005
            wrapped(&dots, cx: dx + r, th0: 0.6, rx: r, ry: r)
            dx += 2 * r + 0.0026
        }
        // Story: anodizing rubbed through to bare aluminium where the clip tip rides.
        var worn = Surface(material: "metal.aluminum-brushed")
        wrapped(&worn, cx: x0 + 0.0628, th0: 1.25, rx: 0.0042, ry: 0.0021, lift: 0.00004)
        // Thumb wear by the head and at the tail end of the barrel, seeded.
        for k in 0..<3 {
            let th = rng.float(0.2...1.1), x = k == 0 ? x0 + 0.0195 : x1 - 0.019 - rng.float(0...0.006)
            wrapped(&worn, cx: x, th0: th, rx: rng.float(0.0012...0.0022), ry: rng.float(0.0006...0.0012), lift: 0.00004)
        }
        // Printed maker line beside the gauge: short strokes read as lettering.
        var px = x0 + 0.064
        for _ in 0..<7 {
            let w = rng.float(0.0012...0.0034)
            wrapped(&dots, cx: px + w / 2, th0: 0.6, rx: w / 2, ry: 0.00042, n: 8)
            px += w + rng.float(0.0005...0.0012)
        }

        // Tail button: slides +X (into the cap) when pressed.
        rig.part("button", pivot: V3(x0, yc, 0), joint: .slide(axis: V3(1, 0, 0), 0...0.0012, duration: 0.15))
        for l in 0..<2 {
            rig.add(axial([V2(0, x0), V2(0.0022, x0 + 0.0001), V2(0.0029, x0 + 0.0006), V2(0.003, x0 + 0.0026)], segs[l], "rubber"), to: "button", lods: l...l)
        }
        // Bulb behind the lens: frosted off, glowing on.
        rig.part("bulb", pivot: V3(x1 - 0.004, yc, 0), joint: .fixed, options: 2)
        let bulbS = Prim.superellipsoid(V3(0.0038, 0.0032, 0.0032), exponent: 2, subdivisions: 4, material: "plastic.frosted")
        let bx = Xform(translation: V3(x1 - 0.0042, yc, 0))
        rig.add(bulbS, bx, to: "bulb")
        rig.add(Prim.superellipsoid(V3(0.0038, 0.0032, 0.0032), exponent: 2, subdivisions: 4, material: "emissive.bulb"), bx, to: "bulb", option: 1)
        rig.lights = [RigLight(name: "beam", kind: .spot(inner: 8, outer: 22), part: "bulb", option: 1, position: V3(x1 + 0.002, yc, 0),
                               direction: V3(1, 0, 0), color: V3(1, 0.9, 0.75), intensity: 60, attenuationRadius: 2)]

        // Pocket clip: steel strip from the clip ring along the top, ball tip resting on the barrel.
        let crx = x0 + 0.0155
        rig.part("clip", pivot: V3(crx, yc + R + 0.0008, 0), joint: .hinge(axis: V3(0, 0, 1), 0...7, duration: 0.25))
        let topY = yc + R
        let clipPath = catmull([V3(crx - 0.001, topY + 0.0006, 0), V3(crx + 0.002, topY + 0.0016, 0), V3(crx + 0.008, topY + 0.0019, 0),
                                V3(crx + 0.03, topY + 0.0013, 0), V3(crx + 0.044, topY + 0.0009, 0)], per: 4)
        let strip = Shape2D.roundedRect(0.0009, 0.0042, radius: 0.0004, segments: 2)
        for l in 0..<2 {
            rig.add(Prim.sweep(strip, along: l == 0 ? clipPath : [clipPath.first!, clipPath[clipPath.count / 2], clipPath.last!], up: V3(0, 1, 0),
                               material: "metal.surgical"), Xform.identity.jittered(&rng, deg: 0.2, offset: 0), to: "clip", lods: l...l)
        }
        rig.add(Prim.superellipsoid(V3(0.0042, 0.0022, 0.0046), exponent: 2.6, subdivisions: 4, material: "metal.surgical"),
                Xform(translation: V3(crx + 0.0445, topY + 0.0008, 0)), to: "clip")

        groundAO(&rig, height: 0.006, floor: 0.6)
        rig.base[0].add(dots)   // after the AO bake: printed ink has no cavities
        rig.base[0].add(worn)
        rig.states = [RigState("off"), RigState("on", ["button": 0.0012], options: ["bulb": 1])]
        return rig
    }
}
