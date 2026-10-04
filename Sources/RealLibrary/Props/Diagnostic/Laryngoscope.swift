import simd
import Foundation

/// Reusable fiber-optic laryngoscope (Macintosh #3 "green system" class, ISO 7376): knurled chrome
/// C-cell handle 29 mm x 128 mm with a screw end cap and a hook-on hinge block, and a stainless
/// Macintosh #3 blade (about 115 mm along the tongue, 20 mm wide) with the reverse-Z section (tongue,
/// left web, top flange), a bulbous tip and a fiber light guide under the flange. Stands on its end cap.
/// The blade hinges on the hook-on pin from folded (hanging along the handle, resting on it near the
/// tip) to locked at 90 degrees; locked, the fiber tip lights (option) with a small spot light.
public struct Laryngoscope: RealArticulated {
    public static let id = "laryngoscope"
    public static let summary = "Macintosh #3 fiber-optic laryngoscope standing on a knurled chrome C-cell handle, blade folded on the hinge bar or locked open and lit."
    public static let tags = ["prop", "medical", "handheld", "articulated", "surgical", "tool", "metal", "light"]
    public static let budget = 5_600
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18, distance: 0.42, studio: true)

    /// Handle radius (m).
    public var radius: Float = 0.0145
    /// Handle height to the top of the hinge block (m).
    public var handleHeight: Float = 0.128
    /// Blade tongue length from the heel to the tip (m).
    public var bladeLength: Float = 0.115
    /// ISO 7376 green-system marking colour (sRGB hex).
    public var greenRing: UInt32 = 0x2A8048
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        let rng = SeededRNG(seed: seed); _ = rng
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3])
        let R = radius, H = handleHeight
        let chrome: MaterialKey = "metal.chrome", knurl: MaterialKey = "metal.knurl-chrome", blade: MaterialKey = "metal.surgical-autoclaved"
        let green: MaterialKey = "plastic.matte:" + String(format: "%06X", greenRing)
        let segs = [32, 14]

        // MARK: handle
        let capTop: Float = 0.011, knurl0: Float = 0.019, knurl1 = H - 0.012
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let sg = segs[l]
            // End cap: flat foot, rounded rim, three grip grooves.
            var cap: [V2] = [V2(0, 0), V2(R - 0.0025, 0), V2(R - 0.0006, 0.0005), V2(R, 0.0018)]
            if l == 0 {
                for g: Float in [0.0045, 0.0065, 0.0085] { cap += [V2(R, g - 0.0007), V2(R - 0.0005, g - 0.0002), V2(R - 0.0005, g + 0.0002), V2(R, g + 0.0007)] }
            }
            cap += [V2(R, capTop - 0.0006), V2(R - 0.0006, capTop)]
            m.add(Prim.lathe(cap, segments: sg, seamTile: 0.02, material: chrome))
            // Smooth band, knurled body, smooth collar.
            m.add(Prim.lathe([V2(R - 0.0006, capTop + 0.0002), V2(R - 0.0001, capTop + 0.0007), V2(R - 0.0001, knurl0)], segments: sg, seamTile: 0.02, material: chrome))
            m.add(Prim.lathe([V2(R - 0.0001, knurl0), V2(R + 0.0002, knurl0 + 0.0004), V2(R + 0.0002, knurl1 - 0.0004), V2(R - 0.0001, knurl1)],
                             segments: sg, seamTile: 0.003 * 30, material: l == 0 ? knurl : chrome))
            m.add(Prim.lathe([V2(R - 0.0001, knurl1), V2(R - 0.0001, H - 0.004), V2(R - 0.0012, H - 0.0006), V2(R - 0.0035, H), V2(0.0098, H)],
                             segments: sg, seamTile: 0.02, material: chrome))
            // Hook-on hinge block on top, with the groove the blade hook drops into.
            m.add(Prim.roundedBox(V3(0.017, 0.012, 0.022), radius: 0.0025, bevelSegments: l == 0 ? 2 : 1, material: chrome),
                  Xform(translation: V3(0, H + 0.0055, 0)))
            m.add(Prim.roundedBox(V3(0.0058, 0.0012, 0.017), radius: 0.0005, bevelSegments: 1, material: "plastic.matte:121212"),
                  Xform(translation: V3(0, H + 0.0113, -0.001)))
            rig.base[l] = m
        }
        // Green-system ring under the collar and the hinge pin ends (detail).
        rig.base[0].add(Prim.lathe([V2(R - 0.0001, H - 0.0105), V2(R + 0.00005, H - 0.0103), V2(R + 0.00005, H - 0.0077), V2(R - 0.0001, H - 0.0075)],
                                   segments: segs[0], seamTile: 0.02, material: green))
        let pinY = H + 0.008, pinZ: Float = 0.0075
        rig.base[0].add(Prim.cylinder(radius: 0.0016, height: 0.0186, bevel: 0.0004, segments: 10, bevelSegments: 1, material: chrome),
                        Xform(translation: V3(-0.0093, pinY, pinZ), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        // Contact pad (the bulb's electrical contact at the back of the block).
        rig.base[0].add(Prim.cylinder(radius: 0.0022, height: 0.0008, bevel: 0.0003, segments: 10, bevelSegments: 1, material: "metal.brass"),
                        Xform(translation: V3(0, H + 0.0113, -0.0065)))

        // MARK: blade, authored open (pointing +Z), then folded onto the handle for the rest pose.
        let pivot = V3(0, pinY, pinZ)
        let L = bladeLength
        let heelZ: Float = 0.016, a0: Float = 0.0045     // tongue starts at the heel front, just above the pin
        let Rc: Float = 0.22                              // Macintosh curve radius
        let t: Float = 0.0015                             // plate thickness
        // Centre line of the tongue underside: straight 30 % then a constant curve down.
        func station(_ s: Float) -> (c: V3, tan: V3, up: V3) {
            let straight = L * 0.3
            if s <= straight {
                return (V3(0, pinY + a0, heelZ + s), V3(0, 0, 1), V3(0, 1, 0))
            }
            let th = (s - straight) / Rc
            let c = V3(0, pinY + a0 - Rc * (1 - cos(th)), heelZ + straight + Rc * sin(th))
            return (c, V3(0, -sin(th), cos(th)), V3(0, cos(th), sin(th)))
        }
        func section(_ u: Float) -> [V2] {
            // u: 0 heel ... 1 tip. Tongue width, web height, flange width.
            let W = 0.0205 - 0.0045 * u
            let Hf = max(0.0036, 0.0165 * (1 - u / 0.82) + 0.0036 * (u / 0.82))
            let Fw = max(t + 0.0006, 0.0085 * (1 - u) + 0.002 * u)
            let xl = -W / 2
            let poly = [V2(W / 2, 0), V2(W / 2, t), V2(xl + t, t), V2(xl + t, Hf - t), V2(xl + Fw, Hf - t), V2(xl + Fw, Hf), V2(xl, Hf), V2(xl, 0)]
            return Shape2D.rounded(poly, radius: 0.0005, segments: 2)
        }
        let nst = [26, 12]
        var openBlade: [Surface] = []
        for l in 0..<2 {
            var rings: [[V3]] = []
            for k in 0...nst[l] {
                let u = Float(k) / Float(nst[l])
                let f = station(u * L)
                rings.append(section(u).map { f.c + V3($0.x, 0, 0) + f.up * $0.y })
            }
            openBlade.append(Prim.loft(rings, capStart: true, capEnd: true, material: blade))
        }
        // Thickened, rounded tip bead.
        let tipF = station(L)
        let bead = Prim.superellipsoid(V3(0.0166, 0.004, 0.0062), exponent: 2.4, subdivisions: 4, material: blade)
        let beadX = Xform(translation: tipF.c + tipF.up * 0.0012 + tipF.tan * 0.0002, rotation: simd_quatf(from: V3(0, 0, 1), to: tipF.tan))
        // Heel: the base block sitting on the hinge block, with its hook around the pin.
        let heel = Prim.roundedBox(V3(0.0125, 0.0125, 0.022), radius: 0.0022, bevelSegments: 2, material: blade)
        let heelX = Xform(translation: V3(-0.0015, pinY + 0.0058, heelZ - 0.0115))
        let hook = Prim.torus(major: 0.0024, minor: 0.0011, segments: 10, sides: 6, arc: .pi * 1.3, material: blade)
        let hookX = Xform(translation: pivot, rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1)) * simd_quatf(degrees: 120, axis: V3(0, 1, 0)))
        // Fiber light guide under the flange, right of the web, ending in a polished glass tip.
        let gStart: Float = 0.004, gEnd = L * 0.62
        let guideU: Float = -0.0205 / 2 + t + 0.0024
        var guidePts: [V3] = [], guideR: [Float] = []
        for k in 0...10 {
            let s = gStart + (gEnd - gStart) * Float(k) / 10
            let f = station(s)
            let hf = max(0.0036, 0.0165 * (1 - s / L / 0.82))
            guidePts.append(f.c + V3(guideU, 0, 0) + f.up * min(hf * 0.5, 0.0065))
            guideR.append(0.0021)
        }
        let guide = Prim.tube(guidePts, radii: guideR, sides: 10, seamTile: 0.014, material: blade, capEnd: false)
        let gTip = station(gEnd), gTan = gTip.tan
        let lensX = Xform(translation: guidePts.last!, rotation: simd_quatf(from: V3(0, 1, 0), to: gTan))
        // Etched size marking plate on the flange (detail).
        let markF = station(L * 0.22)
        let mark = Prim.roundedBox(V3(0.0003, 0.004, 0.012), radius: 0.0001, bevelSegments: 1, material: "metal.stainless:6E7073")

        // Fold: rotate the open blade about the pin until it rests against the handle.
        func folded(_ phi: Float) -> Xform {
            let q = simd_quatf(degrees: phi, axis: V3(1, 0, 0))
            return Xform(translation: pivot - q.act(pivot), rotation: q)
        }
        var phi: Float = 90
        let probe = openBlade[1].positions
        while phi > 60 {
            let x = folded(phi)
            let clear = probe.allSatisfy { p in
                let q = x.point(p)
                return q.y > H - 0.002 || simd_length(V2(q.x, q.z)) > R + 0.0018
            }
            if clear { break }
            phi -= 1
        }
        let fold = folded(phi)
        func f(_ x: Xform) -> Xform { x.then(fold) }

        rig.part("blade", pivot: pivot, joint: .hinge(axis: V3(1, 0, 0), -phi...0, duration: 0.5))
        rig.part("lamp", parent: "blade", pivot: pivot, joint: .fixed, options: 2)
        for l in 0..<2 {
            var m = Model(name: "blade")
            m.add(openBlade[l], fold)
            m.add(heel, f(heelX))
            m.add(guide, fold)
            if l == 0 {
                m.add(bead, f(beadX))
                m.add(hook, f(hookX))
                m.add(mark, f(Xform(translation: markF.c + V3(-0.0205 / 2 - 0.0002, 0, 0) + markF.up * 0.0085)))
                m.add(Prim.cylinder(radius: 0.0017, height: 0.0003, bevel: 0.0001, segments: 10, bevelSegments: 1, material: green),
                      f(Xform(translation: V3(0.0028, pinY + 0.0119, heelZ - 0.016))))
            } else {
                m.add(bead, f(beadX))
            }
            rig.set(m, part: "blade", lod: l)
        }
        // Lens at the end of the light guide: polished glass off, cold white on.
        let lens = Prim.cylinder(radius: 0.0019, height: 0.0006, bevel: 0.0002, segments: 10, bevelSegments: 1, material: "glass.clear")
        let lensOn = Prim.cylinder(radius: 0.0019, height: 0.0006, bevel: 0.0002, segments: 10, bevelSegments: 1, material: "emissive.surgical")
        rig.add(lens, f(lensX), to: "lamp")
        rig.add(lensOn, f(lensX), to: "lamp", option: 1)
        let lp = fold.point(guidePts.last! + gTan * 0.001), ld = fold.direction(gTan - V3(0, 0.25, 0))
        rig.lights = [RigLight(name: "fiber", kind: .spot(inner: 10, outer: 30), part: "lamp", option: 1, position: lp, direction: ld,
                               color: V3(0.92, 0.96, 1), intensity: 120, attenuationRadius: 1.2)]

        groundAO(&rig, height: 0.02, floor: 0.6)
        rig.states = [RigState("folded"), RigState("open-lit", ["blade": -phi], options: ["lamp": 1])]
        return rig
    }
}
