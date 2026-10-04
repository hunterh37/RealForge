import simd
import Foundation

/// Fingertip pulse oximeter (clinic / home fingertip SpO2 meter class), 58 x 34 x 32 mm, lying on its
/// base: grey bottom shell, gloss blue top shell carrying a 26 x 12 mm OLED window and a power button,
/// a rear spring hinge (two knuckles, coil spring, pin), grey silicone finger pads in both halves, a
/// lot sticker on the side and a black lanyard loop from the rear lug. The top shell opens up to 28
/// degrees about the hinge; the display shows SpO2 and pulse rate when on.
public struct PulseOximeter: RealArticulated {
    public static let id = "pulse-oximeter"
    public static let summary = "Fingertip pulse oximeter, 58 x 32 x 34 mm: spring clamshell with silicone finger pads, OLED SpO2 display, power button and lanyard."
    public static let tags = ["prop", "medical", "handheld", "articulated", "electronics", "plastic", "rubber"]
    public static let budget = 5_150
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 32, distance: 0.3, studio: true)

    /// Top shell colour (sRGB hex).
    public var topColor: UInt32 = 0x2E5FA6
    /// Bottom shell colour (sRGB hex).
    public var baseColor: UInt32 = 0x8E9398
    /// Opening of the clamshell in the "open" state (degrees).
    public var openAngle: Float = 26
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [2.5])
        let L: Float = 0.056, W: Float = 0.032, hB: Float = 0.0168, hT: Float = 0.0168, gap: Float = 0.0004
        let top: MaterialKey = "plastic.gloss:" + String(format: "%06X", topColor)
        let base: MaterialKey = "plastic.matte:" + String(format: "%06X", baseColor)
        let pad: MaterialKey = "rubber.silicone:8E979E"
        let yT0 = hB + gap
        let hx = -L / 2 + 0.002, hy = hB + gap / 2      // hinge pin axis (Z) at the back

        // MARK: bottom shell
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let bs = l == 0 ? 3 : 1
            m.add(Prim.roundedBox(V3(L, hB, W), radius: 0.0062, bevelSegments: bs, material: base), Xform(translation: V3(0.001, hB / 2, 0)))
            // Finger pad, proud 0.4 mm of the shell top, with the finger trough.
            var p = Prim.superellipsoid(V3(0.04, 0.004, 0.021), exponent: 4, subdivisions: l == 0 ? 6 : 3, material: pad)
            p.deform { q in V3(q.x, q.y - 0.0011 * (1 - min(1, (q.z / 0.0075) * (q.z / 0.0075))) * (q.y > 0 ? 1 : 0), q.z) }
            m.add(p, Xform(translation: V3(0.006, hB - 0.0016, 0)))
            // Finger entry: lower lip of the silicone opening at the front.
            var lip = Prim.superellipsoid(V3(0.007, 0.013, 0.02), exponent: 2.4, subdivisions: l == 0 ? 5 : 3, material: "rubber.silicone:4A4F55")
            lip.deform { q in V3(q.x, min(q.y, 0), q.z) }
            m.add(lip, Xform(translation: V3(L / 2 - 0.001, hB, 0)))
            // Hinge knuckles on the bottom shell (outer pair).
            for sz: Float in [-1, 1] {
                m.add(Prim.cylinder(radius: 0.0032, height: 0.007, bevel: 0.0008, segments: l == 0 ? 14 : 8, bevelSegments: 1, material: base),
                      Xform(translation: V3(hx - 0.0012, hy, sz * 0.0125 - 0.0035), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            }
            rig.base[l] = m
        }
        // Rear lanyard lug and cord loop lying on the table.
        rig.base[0].add(Prim.torus(major: 0.0024, minor: 0.0009, segments: 12, sides: 6, material: base),
                        Xform(translation: V3(-L / 2 - 0.0012, 0.0045, 0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        var loop: [V3] = []
        let cx = -L / 2 - 0.022
        for k in 0...20 {
            let a = Float(k) / 20 * 2 * .pi
            let wob = 1 + 0.08 * sin(a * 3 + rng.float(0...1))
            loop.append(V3(cx + 0.019 * cos(a) * wob, 0.0011 + 0.0028 * max(0, cos(a)) * max(0, cos(a)) * max(0, cos(a)), 0.011 * sin(a) * wob))
        }
        let cord = catmull(loop, per: 2)
        rig.base[0].add(Prim.tube(cord, radii: cord.map { _ in 0.0011 }, sides: 6, seamTile: 0.007, material: "fabric.nylon:1C1C1E", capEnd: false))
        rig.base[1].add(Prim.tube(loop, radii: loop.map { _ in 0.0011 }, sides: 4, seamTile: 0.007, material: "fabric.nylon:1C1C1E", capEnd: false))
        // Lot sticker on the +Z side of the bottom shell (one label tile).
        var sticker = Surface(material: "label.biomed")
        let sx0: Float = -0.006, sw: Float = 0.016, sy0: Float = 0.0035, sh: Float = 0.0085, sz = W / 2 + 0.00008
        let a = sticker.add(V3(sx0, sy0 + sh, sz), V3(0, 0, 1), V2(0, 0)), b = sticker.add(V3(sx0 + sw, sy0 + sh, sz), V3(0, 0, 1), V2(0.012, 0))
        let c = sticker.add(V3(sx0 + sw, sy0, sz), V3(0, 0, 1), V2(0.012, 0.012)), d = sticker.add(V3(sx0, sy0, sz), V3(0, 0, 1), V2(0, 0.012))
        sticker.quad(d, c, b, a)
        sticker.computeTangents()

        // MARK: top shell (lid), hinged about Z at the back; positive raises the front.
        rig.part("lid", pivot: V3(hx, hy, 0), joint: .hinge(axis: V3(0, 0, 1), 0...28, duration: 0.35))
        for l in 0..<2 {
            let bs = l == 0 ? 3 : 1
            rig.add(Prim.roundedBox(V3(L + 0.002, hT, W), radius: 0.0072, bevelSegments: bs, material: top), Xform(translation: V3(0, yT0 + hT / 2, 0)), to: "lid", lods: l...l)
            var p = Prim.superellipsoid(V3(0.04, 0.004, 0.021), exponent: 4, subdivisions: l == 0 ? 6 : 3, material: pad)
            p.deform { q in V3(q.x, q.y + 0.0011 * (1 - min(1, (q.z / 0.0075) * (q.z / 0.0075))) * (q.y < 0 ? 1 : 0), q.z) }
            rig.add(p, Xform(translation: V3(0.006, yT0 + 0.0016, 0)), to: "lid", lods: l...l)
            var lip = Prim.superellipsoid(V3(0.007, 0.013, 0.02), exponent: 2.4, subdivisions: l == 0 ? 5 : 3, material: "rubber.silicone:4A4F55")
            lip.deform { q in V3(q.x, max(q.y, 0), q.z) }
            rig.add(lip, Xform(translation: V3(L / 2 - 0.001, yT0, 0)), to: "lid", lods: l...l)
            rig.add(Prim.cylinder(radius: 0.0032, height: 0.0168, bevel: 0.0008, segments: l == 0 ? 14 : 8, bevelSegments: 1, material: top),
                    Xform(translation: V3(hx - 0.0012, hy, -0.0084 - 0.0035 + 0.0035), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "lid", lods: l...l)
        }
        // Coil spring round the pin, pin ends (detail).
        rig.add(Prim.helix(radius: 0.0036, pitch: 0.0011, turns: 5, wire: 0.00045, perTurn: 12, sides: 4, material: "metal.stainless"),
                Xform(translation: V3(hx - 0.0012, hy, -0.0028), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "lid", lods: 0...0)
        // Display window bezel (black glass) and power button well.
        let yTop = yT0 + hT
        let dw: Float = 0.026, dh: Float = 0.0125, dxc: Float = 0.004
        rig.add(Prim.extrude(Shape2D.roundedRect(dw + 0.004, dh + 0.004, radius: 0.0018, segments: 3), depth: 0.0005, bevel: 0.0002, bevelSegments: 1,
                             material: "plastic.gloss:0C0C0E"),
                Xform(translation: V3(dxc, yTop - 0.0001, 0), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))), to: "lid")
        rig.part("button", parent: "lid", pivot: V3(-0.019, yTop, 0), joint: .slide(axis: V3(0, -1, 0), 0...0.0007, duration: 0.12))
        rig.add(Prim.cylinder(radius: 0.0034, height: 0.0011, bevel: 0.0004, segments: 16, bevelSegments: 1, material: "rubber.silicone:C9CDD1"),
                Xform(translation: V3(-0.019, yTop - 0.0004, 0)), to: "button")

        // MARK: screen: off glass or OLED (SpO2 left, pulse rate right; crops of the numerics column).
        rig.part("screen", parent: "lid", pivot: V3(dxc, yTop, 0), joint: .fixed, options: 2)
        func panel(_ mat: MaterialKey, crop: Bool) -> Surface {
            var s = Surface(material: mat)
            let y = yTop + 0.00022, n = V3(0, 1, 0)
            // Text up = -Z, right = +X (read from the +Z side).
            let halves: [(Float, Float, V2, V2)] = crop
                ? [(dxc - dw / 2, dxc, V2(0.835, 0.53), V2(0.985, 0.74)), (dxc, dxc + dw / 2, V2(0.835, 0.08), V2(0.985, 0.29))]
                : [(dxc - dw / 2, dxc + dw / 2, V2(0, 0), V2(1, 1))]
            for (x0, x1, uv0, uv1) in halves {
                // The panel samples v up (row 0 at the bottom), so layout y maps to v = 1 - y.
                let tl = s.add(V3(x0, y, -dh / 2), n, V2(uv0.x, 1 - uv0.y)), tr = s.add(V3(x1, y, -dh / 2), n, V2(uv1.x, 1 - uv0.y))
                let br = s.add(V3(x1, y, dh / 2), n, V2(uv1.x, 1 - uv1.y)), bl = s.add(V3(x0, y, dh / 2), n, V2(uv0.x, 1 - uv1.y))
                s.quad(tl, bl, br, tr)
            }
            s.computeTangents()
            return s
        }
        rig.add(panel("screen.off", crop: false), to: "screen")
        rig.add(panel("screen.oximeter-oled", crop: true), to: "screen", option: 1)
        rig.lights = [RigLight(name: "oled", kind: .point, part: "screen", option: 1, position: V3(dxc, yTop + 0.02, 0),
                               color: V3(0.5, 0.85, 1), intensity: 4, attenuationRadius: 0.15)]

        groundAO(&rig, height: 0.006, floor: 0.6)
        rig.base[0].add(sticker)
        rig.states = [RigState("closed"), RigState("open", ["lid": openAngle]), RigState("on", ["lid": 4], options: ["screen": 1])]
        return rig
    }
}
