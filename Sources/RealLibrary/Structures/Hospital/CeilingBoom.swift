import simd
import Foundation

/// Anesthesia / ICU ceiling pendant boom (Draeger Ponta / Hillrom Latitude / Amico class): ceiling plate
/// and canopy, a two-segment boom arm (0.9 m and 0.75 m, each turning about a vertical axis on braked
/// bearings) and a 320 x 260 mm service head column 1.35 m long. Left face: medical gas outlets per the US
/// color code (two oxygen green, medical air yellow, two vacuum white) with an oxygen flowmeter plugged in;
/// right face: hospital-grade duplex receptacles (red emergency, white normal); front: two accessory rails
/// with two shelves and a tilting patient monitor on a VESA bracket. Authored in place for a 3.0 m
/// ceiling (plate top at `mountHeight`, y = 0 is the floor). The axle sits off the origin so the stowed
/// pose is centered. Options: monitor screen off / vitals.
public struct CeilingBoom: RealArticulated {
    public static let id = "ceiling-boom"
    public static let summary = "Anesthesia ceiling pendant boom: two-segment arm, service head with color-coded gas outlets, power receptacles, two shelves and a tilting vitals monitor."
    public static let tags = ["structure", "medical", "hospital", "interior", "ceiling", "metal", "electronics", "articulated"]
    public static let budget = 13_600
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 10, distance: 1.05, studio: true)

    public var mountHeight: Float = 3.0
    public var arm1Length: Float = 0.9
    public var arm2Length: Float = 0.75
    /// Service head column (x width, y length, z depth) (m).
    public var column = V3(0.32, 1.35, 0.26)
    public var housing: MaterialKey = "metal.powder-white"
    public var trim: MaterialKey = "plastic.medical-grey:9FA6AC"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [10])
        let top = mountHeight, L1 = arm1Length, L2 = arm2Length
        let ax = -(L1 - 0.22) / 2                    // axle x: centers the stowed pose
        let y1: Float = top - 0.2, y2: Float = top - 0.38  // arm centerlines
        let armH: Float = 0.14, armW: Float = 0.13
        let cx = ax + L1 - L2                        // column axis at rest (arm 2 folded back)
        let colTop = y2 - armH / 2 - 0.03, colBot = colTop - column.y
        let hw = column.x / 2, hd = column.z / 2
        let flat = simd_quatf(degrees: -90, axis: V3(1, 0, 0))

        // MARK: ceiling plate, canopy, axle (static)
        for l in 0..<2 {
            var m = Model(name: Self.id)
            m.add(Prim.extrude(Shape2D.roundedRect(0.5, 0.5, radius: 0.04, segments: l == 0 ? 4 : 2), depth: 0.012, bevel: 0.003, bevelSegments: 1, material: housing),
                  Xform(translation: V3(ax, top - 0.006, 0), rotation: flat))
            m.add(Prim.extrude(Shape2D.roundedRect(0.36, 0.36, radius: 0.06, segments: l == 0 ? 5 : 2), depth: 0.1, bevel: 0.012, bevelSegments: l == 0 ? 2 : 1, material: housing),
                  Xform(translation: V3(ax, top - 0.012 - 0.05, 0), rotation: flat))
            m.add(Prim.cylinder(radius: 0.07, height: 0.04, bevel: 0.006, segments: l == 0 ? 32 : 16, bevelSegments: 1, material: trim),
                  Xform(translation: V3(ax, y1 + armH / 2 + 0.005, 0)))
            if l == 0 {
                for (sx, sz) in [(-1, -1), (1, -1), (1, 1), (-1, 1)] as [(Float, Float)] {
                    m.add(HK.cyl(r: 0.005, len: 0.002, at: V3(ax + sx * 0.215, top - 0.0125, sz * 0.215), axis: V3(0, -1, 0), mat: housing, seg: 8, bevel: 0.0005))
                }
            }
            rig.base[l] = m
        }

        // MARK: arm 1 (about the axle) and arm 2 (about arm 1's elbow, folded back over arm 1 at rest)
        rig.part("arm1", pivot: V3(ax, y1, 0), joint: .hinge(axis: .up, -170...170, duration: 3.0))
        rig.part("arm2", parent: "arm1", pivot: V3(ax + L1, y2, 0), joint: .hinge(axis: .up, -340...0, duration: 3.0))
        rig.part("monitor", parent: "arm2", pivot: V3(cx, colTop - 0.2, hd + 0.11), joint: .hinge(axis: V3(1, 0, 0), -10...25, duration: 0.8), options: 2)
        for l in 0..<2 {
            let lo = l...l, seg = l == 0 ? 32 : 16
            let armOutline = Shape2D.roundedRect(L1, armW, radius: armW / 2 - 0.001, segments: l == 0 ? 8 : 4)
            rig.add(Prim.extrude(armOutline, depth: armH, bevel: l == 0 ? 0.012 : 0.006, bevelSegments: l == 0 ? 2 : 1, material: housing),
                    Xform(translation: V3(ax + L1 / 2, y1, 0), rotation: flat), to: "arm1", lods: lo)
            for dy: Float in [-1, 1] {
                rig.add(Prim.extrude(Shape2D.roundedRect(L1 - 0.12, 0.05, radius: 0.024, segments: 3), depth: 0.004, bevel: 0.0015, bevelSegments: 1, material: trim),
                        Xform(translation: V3(ax + L1 / 2, y1, dy * (armW / 2 + 0.0015)), rotation: .identity) , to: "arm1", lods: 0...0)
            }
            // Arm 2 runs back toward -X from the elbow; elbow bearing housing joins the two.
            rig.add(Prim.extrude(Shape2D.roundedRect(L2 + armW, armW, radius: armW / 2 - 0.001, segments: l == 0 ? 8 : 4), depth: armH, bevel: l == 0 ? 0.012 : 0.006,
                                 bevelSegments: l == 0 ? 2 : 1, material: housing),
                    Xform(translation: V3(ax + L1 - L2 / 2, y2, 0), rotation: flat), to: "arm2", lods: lo)
            rig.add(Prim.cylinder(radius: 0.058, height: y1 - y2 - armH + 0.012, bevel: 0.003, segments: seg, bevelSegments: 1, material: trim),
                    Xform(translation: V3(ax + L1, y2 + armH / 2 - 0.006, 0)), to: "arm2", lods: lo)
            // Column cap collar below arm 2.
            rig.add(Prim.cylinder(radius: 0.075, height: 0.034, bevel: 0.005, segments: seg, bevelSegments: 1, material: trim),
                    Xform(translation: V3(cx, colTop - 0.002, 0)), to: "arm2", lods: lo)
            // Service head column with grey end caps.
            rig.add(Prim.extrude(Shape2D.roundedRect(column.x, column.z, radius: 0.035, segments: l == 0 ? 5 : 2), depth: column.y - 0.06, bevel: 0.004, bevelSegments: 1, material: housing),
                    Xform(translation: V3(cx, (colTop + colBot) / 2, 0), rotation: flat), to: "arm2", lods: lo)
            for (yy, sgn) in [(colTop, Float(-1)), (colBot, Float(1))] {
                rig.add(Prim.extrude(Shape2D.roundedRect(column.x + 0.008, column.z + 0.008, radius: 0.039, segments: l == 0 ? 5 : 2), depth: 0.03, bevel: 0.008, bevelSegments: l == 0 ? 2 : 1, material: trim),
                        Xform(translation: V3(cx, yy + sgn * 0.015, 0), rotation: flat), to: "arm2", lods: lo)
            }
            // Front accessory rails (aluminum channel) carrying the shelves and the monitor bracket.
            for sx: Float in [-1, 1] {
                rig.add(HK.box(V3(0.032, column.y - 0.14, 0.016), V3(cx + sx * (hw - 0.05), (colTop + colBot) / 2, hd + 0.007), "metal.anodized", r: 0.003, seg: 1), to: "arm2", lods: lo)
            }
            // Two shelves: 520 x 360 mm with a raised rim, on clamp brackets.
            for sy in [colBot + 0.2, colBot + 0.56] {
                let shelf = Prim.extrude(Shape2D.roundedRect(0.52, 0.36, radius: 0.03, segments: l == 0 ? 4 : 2), depth: 0.022, bevel: 0.004, bevelSegments: 1, material: housing)
                rig.add(shelf, Xform(translation: V3(cx, sy, hd + 0.016 + 0.18), rotation: flat), to: "arm2", lods: lo)
                let lip = HK.box(V3(0.5, 0.025, 0.012), V3(cx, sy + 0.022, hd + 0.016 + 0.354), trim, r: 0.004, seg: 1)
                rig.add(lip, to: "arm2", lods: lo)
                for sx: Float in [-1, 1] {
                    rig.add(HK.box(V3(0.016, 0.012, 0.3), V3(cx + sx * 0.236, sy + 0.017, hd + 0.016 + 0.19), trim, r: 0.004, seg: 1), to: "arm2", lods: lo)
                    rig.add(HK.box(V3(0.05, 0.06, 0.03), V3(cx + sx * (hw - 0.05), sy - 0.012, hd + 0.03), "metal.anodized", r: 0.004, seg: 1), to: "arm2", lods: lo)
                }
            }
            // Monitor bracket: clamp on the rails, horizontal tube to the VESA hub.
            let my = colTop - 0.2
            rig.add(HK.box(V3(column.x - 0.04, 0.07, 0.03), V3(cx, my, hd + 0.03), "metal.anodized", r: 0.005, seg: 1), to: "arm2", lods: lo)
            rig.add(HK.cyl(r: 0.018, len: 0.07, at: V3(cx, my, hd + 0.075), axis: V3(0, 0, 1), mat: trim, seg: l == 0 ? 16 : 8, bevel: 0.003), to: "arm2", lods: lo)
            // Monitor (15 in, 16:10): housing, bezel, screen with off / vitals options.
            let mz = hd + 0.11 + 0.03, mw: Float = 0.38, mh: Float = 0.27
            rig.add(Prim.extrude(Shape2D.roundedRect(mw, mh, radius: 0.012, segments: l == 0 ? 3 : 1), depth: 0.05, bevel: 0.006, bevelSegments: l == 0 ? 2 : 1, material: "plastic.medical-grey"),
                    Xform(translation: V3(cx, my, mz)), to: "monitor", lods: lo)
            rig.add(HK.box(V3(0.1, 0.1, 0.02), V3(cx, my, mz - 0.032), "plastic.medical-grey:6E757B", r: 0.004, seg: 1), to: "monitor", lods: lo)
            rig.add(HK.box(V3(mw - 0.024, mh - 0.036, 0.002), V3(cx, my + 0.008, mz + 0.0255), "plastic.black", r: 0.0008, seg: 1), to: "monitor", lods: lo)
            let sw: Float = 0.336, sh: Float = 0.21
            rig.add(HK.rect("plastic.gloss:0B0C0E", center: V3(cx, my + 0.008, mz + 0.0268), right: V3(1, 0, 0), up: .up, w: sw, h: sh), to: "monitor", lods: lo)
            rig.add(HK.rect("screen.vitals", center: V3(cx, my + 0.008, mz + 0.0268), right: V3(1, 0, 0), up: .up, w: sw, h: sh, unit: true, flipV: true), to: "monitor", option: 1, lods: lo)
            rig.add(HK.box(V3(0.006, 0.006, 0.003), V3(cx + mw / 2 - 0.03, my - mh / 2 + 0.01, mz + 0.026), "plastic.medical-grey:2B4A30", r: 0.001, seg: 1), to: "monitor", lods: lo)
            rig.add(HK.box(V3(0.006, 0.006, 0.003), V3(cx + mw / 2 - 0.03, my - mh / 2 + 0.01, mz + 0.026), "emissive.led-green", r: 0.001, seg: 1), to: "monitor", option: 1, lods: lo)
        }

        // MARK: gas outlets (left face, -X) and power receptacles (right face, +X), LOD0 detail + LOD1 plates
        let gases: [(MaterialKey, String)] = [("plastic.medical:2E8B3E", "O2"), ("plastic.medical:2E8B3E", "O2"), ("plastic.medical:E2BE1C", "AIR"),
                                              ("plastic.medical:F2F2EE", "VAC"), ("plastic.medical:F2F2EE", "VAC")]
        let gx = cx - hw - 0.001
        for (i, g) in gases.enumerated() {
            let gy = colTop - 0.22 - Float(i) * 0.105
            let plate = HK.box(V3(0.012, 0.085, 0.07), V3(gx - 0.006, gy, 0), g.0, r: 0.004, seg: 1)
            rig.add(plate, to: "arm2")
            rig.add(HK.cyl(r: 0.019, len: 0.016, at: V3(gx - 0.018, gy - 0.008, 0), axis: V3(-1, 0, 0), mat: "metal.chrome", seg: 18, bevel: 0.003), to: "arm2", lods: 0...0)
            rig.add(HK.cyl(r: 0.009, len: 0.004, at: V3(gx - 0.026, gy - 0.008, 0), axis: V3(-1, 0, 0), mat: "plastic.black", seg: 12, bevel: 0.001), to: "arm2", lods: 0...0)
            // Gas ID strip above the socket in the outlet color.
            rig.add(HK.box(V3(0.003, 0.014, 0.05), V3(gx - 0.0125, gy + 0.03, 0), g.1 == "VAC" ? "plastic.black" : "plastic.medical:F4F4F0", r: 0.001, seg: 1), to: "arm2", lods: 0...0)
        }
        // Story: oxygen flowmeter plugged into the top O2 outlet (green body, clear tube with the float ball).
        let fy = colTop - 0.22 - 0.008, fx = gx - 0.034
        rig.add(HK.box(V3(0.03, 0.05, 0.045), V3(fx - 0.01, fy, 0), "plastic.medical:2E8B3E", r: 0.006, seg: 1), to: "arm2")
        rig.add(HK.box(V3(0.026, 0.17, 0.034), V3(fx - 0.03, fy + 0.07, 0), "plastic.medical:2E8B3E", r: 0.006, seg: 1), to: "arm2")
        rig.add(HK.cyl(r: 0.011, len: 0.13, at: V3(fx - 0.048, fy + 0.08, 0), axis: .up, mat: "plastic.clear", seg: 14, bevel: 0.002), to: "arm2", lods: 0...0)
        rig.add(Prim.cubeSphere(subdivisions: 2, material: "metal.chrome") { $0 * 0.0045 }, Xform(translation: V3(fx - 0.048, fy + 0.07, 0)), to: "arm2", lods: 0...0)
        rig.add(HK.cyl(r: 0.012, len: 0.022, at: V3(fx - 0.03, fy + 0.165, 0), axis: .up, mat: "plastic.medical:F4F4F0", seg: 14, bevel: 0.003), to: "arm2", lods: 0...0)
        rig.add(HK.pipe([V3(fx - 0.03, fy - 0.03, 0), V3(fx - 0.03, fy - 0.05, 0.01), V3(fx - 0.04, fy - 0.09, 0.02)], r: 0.004, sides: 8, mat: "plastic.medical:6FB4C8"), to: "arm2", lods: 0...0)
        // Folded sterile drape pack and a wrapped instrument tray on the lower shelf.
        let ls = colBot + 0.2 + 0.011
        rig.add(HK.box(V3(0.26, 0.05, 0.2), V3(cx - 0.1, ls + 0.025, hd + 0.2), "drape.surgical", r: 0.012, seg: 2), to: "arm2", lods: 0...1)
        rig.add(HK.box(V3(0.17, 0.035, 0.12), V3(cx + 0.14, ls + 0.0175, hd + 0.22), "paper.exam", r: 0.008, seg: 1), to: "arm2", lods: 0...1)
        rig.add(HK.box(V3(0.172, 0.006, 0.02), V3(cx + 0.14, ls + 0.03, hd + 0.22), "label.hazard", r: 0.002, seg: 1), to: "arm2", lods: 0...0)
        let px = cx + hw + 0.001
        for i in 0..<4 {
            let py = colTop - 0.24 - Float(i) * 0.15
            let emergency = i < 2
            let plateMat: MaterialKey = emergency ? "plastic.medical:B8241C" : "plastic.medical:F2F1EC"
            rig.add(HK.box(V3(0.008, 0.115, 0.07), V3(px + 0.004, py, 0), plateMat, r: 0.003, seg: 1), to: "arm2")
            for dy: Float in [-0.023, 0.023] {
                rig.add(HK.box(V3(0.006, 0.036, 0.034), V3(px + 0.009, py + dy, 0), plateMat, r: 0.005, seg: 1), to: "arm2", lods: 0...0)
                for dz: Float in [-0.0065, 0.0065] {
                    rig.add(cuboid(V3(0.002, 0.009, 0.0022), material: "plastic.black"), Xform(translation: V3(px + 0.0118, py + dy + 0.004, dz)), to: "arm2", lods: 0...0)
                }
                rig.add(cuboid(V3(0.002, 0.005, 0.005), material: "plastic.black"), Xform(translation: V3(px + 0.0118, py + dy - 0.009, 0)), to: "arm2", lods: 0...0)
            }
            // Green-dot hospital-grade mark and breaker label.
            rig.add(HK.cyl(r: 0.0025, len: 0.001, at: V3(px + 0.0122, py + 0.05, 0.026), axis: V3(1, 0, 0), mat: "plastic.medical:2E8B3E", seg: 8, bevel: 0.0003), to: "arm2", lods: 0...0)
        }

        rig.lights = [RigLight(name: "screen-glow", kind: .point, part: "monitor", option: 1, position: V3(cx, colTop - 0.2, hd + 0.5),
                               color: V3(0.7, 0.85, 1.0), intensity: 50, attenuationRadius: 1.2)]
        groundAO(&rig, height: 0.01, floor: 1)
        rig.states = [
            RigState("stowed"),
            RigState("deployed", ["arm1": 55, "arm2": -150, "monitor": 10]),
            RigState("deployed-on", ["arm1": 55, "arm2": -150, "monitor": 10], options: ["monitor": 1]),
        ]
        return rig
    }
}
