import simd
import Foundation

/// Freestanding patient self check-in kiosk (Olea / KIOSK Information Systems healthcare pedestal class),
/// 56 x 46 cm oval base, 1.5 m tall: 14 mm powder-coated steel base on a rubber foot, 170 x 90 mm column
/// with a grey cable cover, a peripheral chin carrying a flatbed ID scanner under a hinged lid, an
/// EMV PIN pad with contactless field and card slot, a receipt printer slot and speaker grille, and a
/// head tilted back 30 degrees holding a 21.5-inch touchscreen behind a privacy visor. Screen off / on
/// with a glow light; the receipt slides out of the slot; the scanner bed lights while scanning.
public struct CheckInKiosk: RealArticulated {
    public static let id = "check-in-kiosk"
    public static let summary = "Freestanding patient check-in kiosk: oval base, slim column, angled 21.5-inch touchscreen, card reader, receipt printer and ID scanner."
    public static let tags = ["prop", "medical", "hospital", "interior", "electronics", "metal", "plastic", "articulated"]
    public static let budget = 6_600
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 14, distance: 1.0, studio: true)

    public var baseSize = V2(0.56, 0.46)
    /// Screen tilt back from vertical (degrees).
    public var tilt: Float = 30
    public var body: MaterialKey = "metal.powder-white"
    public var baseFinish: MaterialKey = "metal.powdercoat:3C3E42"
    /// Accent strip color (sRGB hex), the hospital brand color.
    public var accent: UInt32 = 0x1F5FAF
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [4])
        let grey: MaterialKey = "plastic.medical-grey", black: MaterialKey = "plastic.black"
        let flat = simd_quatf(degrees: -90, axis: V3(1, 0, 0))
        let accentKey: MaterialKey = "plastic.gloss:" + String(format: "%06X", accent)
        // Chin (peripheral module) and head frame.
        let chinTop: Float = 1.105, chinH: Float = 0.12, chinZ0: Float = -0.09, chinZ1: Float = 0.2
        let headC = V3(0, 1.33, -0.06), q = simd_quatf(degrees: -tilt, axis: V3(1, 0, 0))
        let hw: Float = 0.56, hh: Float = 0.37, hd: Float = 0.065
        func head(_ p: V3) -> V3 { headC + q.act(p) }

        for l in 0..<2 {
            var m = Model(name: Self.id)
            let seg = l == 0 ? 2 : 1
            // Base plate on a rubber foot.
            let outline = Shape2D.superellipse(baseSize.x, baseSize.y, exponent: 2.6, segments: l == 0 ? 48 : 24)
            m.add(Prim.extrude(Shape2D.offset(outline, -0.012), depth: 0.003, bevel: 0.0008, bevelSegments: 1, material: "rubber"),
                  Xform(translation: V3(0, 0.0015, 0), rotation: flat))
            m.add(Prim.extrude(outline, depth: 0.014, bevel: 0.004, bevelSegments: seg, material: baseFinish),
                  Xform(translation: V3(0, 0.003 + 0.007, 0), rotation: flat))
            // Column with a foot collar.
            let colZ: Float = -0.06, colTop = chinTop - chinH + 0.02
            m.add(Prim.extrude(Shape2D.roundedRect(0.2, 0.12, radius: 0.035, segments: seg + 1), depth: 0.04, bevel: 0.006, bevelSegments: seg, material: baseFinish),
                  Xform(translation: V3(0, 0.017 + 0.02, colZ), rotation: flat))
            m.add(Prim.extrude(Shape2D.roundedRect(0.17, 0.09, radius: 0.03, segments: seg + 1), depth: colTop - 0.05, bevel: 0.003, bevelSegments: 1, material: body),
                  Xform(translation: V3(0, 0.05 + (colTop - 0.05) / 2, colZ), rotation: flat))
            // Grey cable cover down the column front.
            m.add(Prim.roundedBox(V3(0.07, colTop - 0.16, 0.008), radius: 0.003, bevelSegments: 1, material: grey),
                  Xform(translation: V3(0, 0.1 + (colTop - 0.16) / 2, colZ + 0.045)))
            // Chin housing with the brand accent strip along its lower front edge.
            m.add(Prim.roundedBox(V3(0.47, chinH, chinZ1 - chinZ0), radius: 0.016, bevelSegments: seg + 1, material: body),
                  Xform(translation: V3(0, chinTop - chinH / 2, (chinZ0 + chinZ1) / 2)))
            m.add(Prim.roundedBox(V3(0.44, 0.012, 0.006), radius: 0.003, bevelSegments: 1, material: accentKey),
                  Xform(translation: V3(0, chinTop - chinH + 0.02, chinZ1 - 0.001)))
            // Neck from the chin to the head back.
            m.add(Prim.roundedBox(V3(0.14, 0.2, 0.06), radius: 0.012, bevelSegments: seg, material: body),
                  Xform(translation: V3(0, chinTop + 0.09, -0.1)))
            // VESA tilt bracket: grey plate on the head back, bolted to the neck.
            m.add(Prim.roundedBox(V3(0.2, 0.2, 0.02), radius: 0.006, bevelSegments: seg, material: grey),
                  Xform(translation: head(V3(0, -0.02, -hd / 2 - 0.008)), rotation: q))
            // Head housing and privacy visor (top and sides proud of the bezel).
            m.add(Prim.roundedBox(V3(hw, hh, hd), radius: 0.016, bevelSegments: seg + 1, material: body), Xform(translation: headC, rotation: q))
            for (size, c) in [(V3(hw, 0.014, 0.03), V3(0, hh / 2 - 0.007, hd / 2 + 0.012)),
                              (V3(0.014, hh - 0.02, 0.026), V3(-hw / 2 + 0.007, 0.01, hd / 2 + 0.01)),
                              (V3(0.014, hh - 0.02, 0.026), V3(hw / 2 - 0.007, 0.01, hd / 2 + 0.01))] {
                m.add(Prim.roundedBox(size, radius: 0.005, bevelSegments: seg, material: body), Xform(translation: head(c), rotation: q))
            }
            // Scanner bezel (raised frame) and card reader body on the chin top.
            m.add(Prim.roundedBox(V3(0.17, 0.008, 0.14), radius: 0.003, bevelSegments: 1, material: grey),
                  Xform(translation: V3(-0.12, chinTop + 0.003, 0.11)))
            rig.base[l] = m
        }
        // Screen surround: black glass border inside the bezel.
        let sw: Float = 0.476, sh: Float = 0.268, scy: Float = 0.012
        for l in 0..<2 {
            rig.base[l].add(quad(head(V3(0, scy, hd / 2 + 0.0004)), right: q.act(V3(1, 0, 0)), up: q.act(V3(0, 1, 0)), w: sw + 0.024, h: sh + 0.024, mat: "plastic.gloss:121316", meters: true))
        }

        // PIN pad / card reader: angled body, keypad, small display, contactless field, chip-card slot.
        let rq = simd_quatf(degrees: 12, axis: V3(1, 0, 0))
        let rc = V3(0.13, chinTop + 0.02, 0.1)
        func reader(_ p: V3) -> V3 { rc + rq.act(p) }
        for l in 0..<2 {
            rig.base[l].add(Prim.roundedBox(V3(0.085, 0.04, 0.15), radius: 0.008, bevelSegments: l == 0 ? 2 : 1, material: "plastic.matte:2C2E31"), Xform(translation: rc, rotation: rq))
        }
        // Worn bezel where fingers rest.
        rig.base[0].add(Prim.roundedBox(V3(0.075, 0.003, 0.098), radius: 0.0012, bevelSegments: 1, material: "plastic.matte:5C5F64"),
                        Xform(translation: reader(V3(0, 0.0205, 0.018)), rotation: rq))
        var keys = Surface(material: "plastic.matte:D8D8D4")
        for r in 0..<4 { for c in 0..<3 {
            keys.append(cuboid(V3(0.016, 0.003, 0.011), material: "plastic.matte:D8D8D4"),
                        Xform(translation: reader(V3(Float(c - 1) * 0.021, 0.0225, 0.05 - Float(r) * 0.015)), rotation: rq))
        }}
        rig.base[0].add(keys)
        rig.base[0].add(quad(reader(V3(0, 0.0222, -0.012)), right: rq.act(V3(1, 0, 0)), up: rq.act(V3(0, 0, -1)), w: 0.05, h: 0.03, mat: "screen.lcd"))
        rig.base[0].add(quad(reader(V3(0, 0.0215, -0.052)), right: rq.act(V3(1, 0, 0)), up: rq.act(V3(0, 0, -1)), w: 0.05, h: 0.034, mat: "plastic.gloss:17181A", meters: true))
        rig.base[0].add(cuboid(V3(0.062, 0.004, 0.003), material: black), Xform(translation: reader(V3(0, -0.01, 0.0752)), rotation: rq))

        // Receipt slot, speaker grille and status LED.
        rig.base[0].add(cuboid(V3(0.092, 0.005, 0.002), material: black), Xform(translation: V3(0, chinTop - 0.045, chinZ1 + 0.0032)))
        for l in 0..<2 {
            rig.base[l].add(Prim.roundedBox(V3(0.12, 0.026, 0.006), radius: 0.003, bevelSegments: 1, material: grey), Xform(translation: V3(0, chinTop - 0.045, chinZ1 + 0.0002)))
        }
        rig.base[0].add(quad(V3(-0.16, chinTop - 0.05, chinZ1 + 0.0004), right: V3(1, 0, 0), up: V3(0, 1, 0), w: 0.09, h: 0.035, mat: "fabric.mesh:3A3B3E", meters: true))
        rig.base[0].add(Prim.cylinder(radius: 0.0025, height: 0.0015, bevel: 0.0005, segments: 8, bevelSegments: 1, material: "emissive.led-green"),
                        Xform(translation: head(V3(hw / 2 - 0.05, -hh / 2 + 0.028, hd / 2)), rotation: q * simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        rig.base[0].add(Prim.cylinder(radius: 0.003, height: 0.0015, bevel: 0.0005, segments: 8, bevelSegments: 1, material: black),
                        Xform(translation: head(V3(0, hh / 2 - 0.022, hd / 2)), rotation: q * simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Asset tag on the column back (story detail: biomed sticker).
        rig.base[0].add(quad(V3(0, 0.62, -0.06 - 0.0452), right: V3(-1, 0, 0), up: V3(0, 1, 0), w: 0.05, h: 0.032, mat: "label.inspection"))

        // MARK: screen
        rig.part("screen", pivot: headC, joint: .fixed, options: 2)
        let n = q.act(V3(0, 0, 1))
        for (o, mat) in [(0, "screen.off"), (1, "screen.kiosk")] {
            rig.add(quad(head(V3(0, scy, hd / 2 + 0.0009)), right: q.act(V3(1, 0, 0)), up: q.act(V3(0, -1, 0)), w: sw, h: sh, mat: mat, flip: true), to: "screen", option: o)
        }

        // MARK: ID scanner (bed glows while scanning; lid hinges at the back edge)
        let bed = V3(-0.12, chinTop + 0.0072, 0.11)
        rig.part("scanner", pivot: bed, joint: .fixed, options: 2)
        rig.add(quad(bed, right: V3(1, 0, 0), up: V3(0, 0, -1), w: 0.15, h: 0.115, mat: "screen.off"), to: "scanner", option: 0)
        rig.add(quad(bed, right: V3(1, 0, 0), up: V3(0, 0, -1), w: 0.15, h: 0.115, mat: "emissive.led-green"), to: "scanner", option: 1)
        let lidPivot = V3(-0.12, chinTop + 0.009, 0.042)
        rig.part("scanner-lid", pivot: lidPivot, joint: .hinge(axis: V3(1, 0, 0), -72...0, duration: 0.5))
        rig.add(Prim.roundedBox(V3(0.168, 0.01, 0.138), radius: 0.004, bevelSegments: 2, material: grey), Xform(translation: V3(-0.12, chinTop + 0.0125, 0.11)), to: "scanner-lid")
        rig.add(Prim.roundedBox(V3(0.05, 0.004, 0.012), radius: 0.0018, bevelSegments: 1, material: black), Xform(translation: V3(-0.12, chinTop + 0.017, 0.172)), to: "scanner-lid", lods: 0...0)
        rig.add(Prim.roundedBox(V3(0.15, 0.002, 0.118), radius: 0.0008, bevelSegments: 1, material: "plastic.matte:F2F2F0"), Xform(translation: V3(-0.12, chinTop + 0.0075, 0.11)), to: "scanner-lid", lods: 0...0)

        // MARK: receipt (slides out of the slot along its own plane, angled 20 degrees down)
        let rdir = simd_normalize(V3(0, -0.342, 0.94))
        let slot = V3(0, chinTop - 0.045, chinZ1)
        rig.part("receipt", pivot: slot, joint: .slide(axis: rdir, 0...0.1, duration: 1.4))
        let rlen: Float = 0.12
        rig.add(Prim.roundedBox(V3(0.08, 0.0004, rlen), radius: 0.0001, bevelSegments: 1, material: "paper.sheet:F3EFE2"),
                Xform(translation: slot - rdir * (rlen / 2 + 0.006), rotation: simd_quatf(from: V3(0, 0, 1), to: rdir)), to: "receipt")

        rig.lights = [
            RigLight(name: "screen-glow", kind: .point, part: "screen", option: 1, position: head(V3(0, scy, hd / 2)) + n * 0.35,
                     color: V3(0.85, 0.9, 1.0), intensity: 90, attenuationRadius: 1.4),
            RigLight(name: "scan-glow", kind: .point, part: "scanner", option: 1, position: bed + V3(0, 0.08, 0.02),
                     color: V3(0.5, 1.0, 0.6), intensity: 12, attenuationRadius: 0.4),
        ]
        groundAO(&rig, height: 0.05, floor: 0.6)
        rig.states = [
            RigState("idle-off"),
            RigState("on", options: ["screen": 1]),
            RigState("printing", ["receipt": 0.1], options: ["screen": 1]),
            RigState("scanning", ["scanner-lid": -72], options: ["screen": 1, "scanner": 1]),
        ]
        return rig
    }
}

/// Quad with UVs 0...1 across it (labels, screens; `flip` puts v = 0 at the top edge), or meters.
private func quad(_ c: V3, right: V3, up: V3, w: Float, h: Float, mat: MaterialKey, meters: Bool = false, flip: Bool = false) -> Surface {
    var s = Surface(material: mat)
    var n = simd_normalize(simd_cross(right, up)), r = right * (w / 2), u = up * (h / 2)
    if flip { n = -n; r = -r }
    let su: Float = meters ? w : artSpan(mat), sv: Float = meters ? h : artSpan(mat)
    let v0: Float = flip ? sv : 0, v1: Float = flip ? 0 : sv
    let a = s.add(c - r - u, n, V2(flip ? su : 0, v0)), b = s.add(c + r - u, n, V2(flip ? 0 : su, v0))
    let cc = s.add(c + r + u, n, V2(flip ? 0 : su, v1)), d = s.add(c - r + u, n, V2(flip ? su : 0, v1))
    s.quad(a, b, cc, d)
    s.computeTangents()
    return s
}

/// UV span for one artwork across a label or screen: the material's tileSize (so texel density lints at ~1), else 1.
private func artSpan(_ mat: MaterialKey) -> Float {
    let s = MaterialLibrary.spec(for: String(mat.split(separator: ":")[0]))
    return s.program != nil && s.tileSize > 0 ? s.tileSize : 1
}
