import simd
import Foundation

/// 27-inch desktop monitor (Dell UltraSharp class): 611 x 366 mm panel with 3-sided 7 mm bezels and a
/// 21 mm chin, matte black back cover with a soft VESA bulge and vents, silver height-adjust column with a
/// cable hole and a flat rounded foot. Joints: "height" slides the carriage up the column (0...110 mm),
/// "tilt" swings the panel about the carriage hinge (-5...21 degrees, positive leans back); the screen
/// is a fixed child with off and on options, a white power LED and a faint fill light when on.
public struct DesktopMonitor: RealArticulated {
    public static let id = "desktop-monitor"
    public static let summary = "27-inch desktop monitor: thin-bezel panel with matte black VESA back, silver height-adjust column with cable hole, flat foot, tilt."
    public static let tags = ["prop", "office", "electronics", "plastic", "articulated"]
    public static let budget = 6_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 12, distance: 1.25, studio: true)

    /// Panel size (m) and the panel bottom above the desk at the lowest stand position.
    public var panel = V2(0.6113, 0.366)
    public var lowest: Float = 0.052
    public var travel: Float = 0.11
    public var housing: MaterialKey = "plastic.matte:1C1D1F"
    public var stand: MaterialKey = "metal.anodized"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        _ = seed
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [8])
        let PW = panel.x, PH = panel.y
        let black: MaterialKey = "plastic.black"
        let flat = simd_quatf(degrees: -90, axis: V3(1, 0, 0))
        let footD: Float = 0.185, footZ: Float = -0.01
        let colW: Float = 0.072, colD: Float = 0.034, colZ: Float = -0.058, colTop: Float = 0.34
        let zFront: Float = 0.024, slab: Float = 0.011
        let yBottom = lowest, yc = lowest + PH / 2
        let hinge = V3(0, yc - 0.03, colZ + colD / 2 + 0.009)

        // MARK: stand (static): foot plate and column.
        for l in 0..<2 {
            var m = Model(name: Self.id)
            m.add(Prim.extrude(Shape2D.roundedRect(0.245, footD, radius: 0.022, segments: l == 0 ? 4 : 2), depth: 0.013, bevel: l == 0 ? 0.005 : 0.003,
                               bevelSegments: l == 0 ? 2 : 1, material: stand), Xform(translation: V3(0, 0.0065, footZ), rotation: flat))
            // Column: rounded section, flared into the foot.
            m.add(Prim.extrude(Shape2D.roundedRect(colW, colD, radius: 0.012, segments: l == 0 ? 4 : 2), depth: colTop - 0.01, bevel: 0.003,
                               bevelSegments: 1, material: stand), Xform(translation: V3(0, 0.01 + (colTop - 0.01) / 2, colZ), rotation: flat))
            m.add(Prim.extrude(Shape2D.roundedRect(colW + 0.02, colD + 0.016, radius: 0.016, segments: l == 0 ? 4 : 2), depth: 0.012, bevel: 0.005,
                               bevelSegments: l == 0 ? 2 : 1, material: stand), Xform(translation: V3(0, 0.016, colZ), rotation: flat))
            // Cable hole: dark oval through the column, seen front and back.
            for s: Float in [-1, 1] {
                m.add(Prim.extrude(Shape2D.roundedRect(0.036, 0.05, radius: 0.017, segments: l == 0 ? 5 : 2), depth: 0.001, bevel: 0.0003, bevelSegments: 1,
                                   material: black), Xform(translation: V3(0, 0.095, colZ + s * (colD / 2 - 0.0002))))
            }
            // Slot the carriage runs in.
            m.add(Prim.roundedBox(V3(0.03, colTop - 0.16, 0.002), radius: 0.0008, bevelSegments: 1, material: black),
                  Xform(translation: V3(0, 0.15 + (colTop - 0.16) / 2, colZ + colD / 2 - 0.0004)))
            if l == 0 {
                // Rubber pads under the foot.
                for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                    m.add(Prim.cylinder(radius: 0.008, height: 0.0012, bevel: 0.0004, segments: 10, bevelSegments: 1, material: "rubber"),
                          Xform(translation: V3(sx * 0.1, -0.0002, footZ + sz * 0.07)))
                }}
            }
            rig.base[l] = m
        }

        // MARK: carriage (height slide) and tilt hinge.
        rig.part("height", pivot: V3(0, hinge.y, colZ), joint: .slide(axis: V3(0, 1, 0), 0...travel, duration: 0.8))
        rig.part("tilt", parent: "height", pivot: hinge, joint: .hinge(axis: V3(-1, 0, 0), -5...21, duration: 0.6))
        rig.part("screen", parent: "tilt", pivot: hinge, joint: .fixed, options: 2)
        rig.add(Prim.roundedBox(V3(0.05, 0.13, 0.012), radius: 0.003, bevelSegments: 2, material: stand),
                Xform(translation: V3(0, hinge.y - 0.035, colZ + colD / 2 + 0.006)), to: "height")
        rig.add(Prim.cylinder(radius: 0.009, height: 0.07, bevel: 0.002, segments: 16, bevelSegments: 1, material: stand),
                Xform(translation: hinge + V3(-0.035, 0, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "height")

        // MARK: panel (tilt).
        let backZ = zFront - slab
        for l in 0..<2 {
            let lod = l...l
            // Front frame: thin slab, bezel and edges matte black.
            rig.add(Prim.extrude(Shape2D.roundedRect(PW, PH, radius: 0.004, segments: l == 0 ? 3 : 1), depth: slab, bevel: l == 0 ? 0.0025 : 0.0015,
                                 bevelSegments: l == 0 ? 2 : 1, material: housing), Xform(translation: V3(0, yc, zFront - slab / 2)), to: "tilt", lods: lod)
            // Back cover: tapered shell from the panel edge to the bulge that houses the electronics and VESA mount.
            let seg = l == 0 ? 5 : 2
            let rings: [(V2, Float, Float, Float)] = [(V2(PW - 0.006, PH - 0.006), 0.004, 0, 0), (V2(PW - 0.05, PH - 0.05), 0.03, 0.006, -0.01),
                                                       (V2(0.47, 0.29), 0.06, 0.024, -0.02), (V2(0.45, 0.27), 0.06, 0.034, -0.02),
                                                       (V2(0.42, 0.24), 0.05, 0.0385, -0.02)]
            let loft = rings.map { r in Prim.ring(Shape2D.roundedRect(r.0.x, r.0.y, radius: r.1, segments: seg), y: r.2, offset: V3(0, 0, r.3)) }
            rig.add(Prim.loft(loft, capEnd: true, material: housing), Xform(translation: V3(0, yc, backZ + 0.001), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))),
                    to: "tilt", lods: lod)
            // VESA bracket plate between the bulge and the hinge.
            rig.add(Prim.roundedBox(V3(0.068, 0.1, 0.008), radius: 0.003, bevelSegments: 1, material: housing),
                    Xform(translation: V3(0, hinge.y + 0.005, backZ - 0.0395 - 0.003)), to: "tilt", lods: lod)
        }
        rig.add(Prim.roundedBox(V3(0.056, 0.03, 0.02), radius: 0.004, bevelSegments: 1, material: stand),
                Xform(translation: V3(0, hinge.y, hinge.z + 0.01)), to: "tilt")
        // Vent slots on the upper back and the port row on the lower back.
        for k in 0..<14 {
            let x = (Float(k) - 6.5) * 0.018
            rig.add(Prim.roundedBox(V3(0.006, 0.03, 0.0012), radius: 0.0005, bevelSegments: 1, material: black),
                    Xform(translation: V3(x, yc - 0.02 + 0.085, backZ - 0.0375)),
                    to: "tilt", lods: 0...0)
        }
        for k in 0..<6 {
            let x = (Float(k) - 2.5) * 0.024
            rig.add(Prim.roundedBox(V3(0.012, 0.006, 0.0012), radius: 0.0008, bevelSegments: 1, material: black),
                    Xform(translation: V3(x + 0.1, yc - 0.02 - 0.095, backZ - 0.0375)), to: "tilt", lods: 0...0)
        }
        // Active area 597 x 336 mm: 7 mm side and top bezels, chin below.
        let aw: Float = 0.5967, ah: Float = 0.3357
        let top = yBottom + PH - 0.0072, bottom = top - ah
        rig.add(Prim.roundedBox(V3(aw + 0.004, ah + 0.004, 0.0006), radius: 0.0002, bevelSegments: 1, material: black),
                Xform(translation: V3(0, (top + bottom) / 2, zFront)), to: "tilt")
        func screen(_ mat: MaterialKey) -> Surface {
            var s = Surface(material: mat)
            let z = zFront + 0.00045, n = V3(0, 0, 1)
            let a = s.add(V3(-aw / 2, bottom, z), n, V2(0, 0)), b = s.add(V3(aw / 2, bottom, z), n, V2(1, 0))
            let c = s.add(V3(aw / 2, top, z), n, V2(1, 1)), d = s.add(V3(-aw / 2, top, z), n, V2(0, 1))
            s.quad(a, b, c, d)
            s.computeTangents()
            return s
        }
        rig.add(screen("screen.off"), to: "screen")
        rig.add(screen("screen.ui"), to: "screen", option: 1)
        // Power LED under the chin's right end, lit only when on.
        let led = V3(PW / 2 - 0.045, yBottom + 0.0012, zFront - 0.004)
        rig.add(Prim.roundedBox(V3(0.004, 0.0012, 0.002), radius: 0.0004, bevelSegments: 1, material: "plastic.white"), Xform(translation: led), to: "screen", lods: 0...0)
        rig.add(Prim.roundedBox(V3(0.004, 0.0012, 0.002), radius: 0.0004, bevelSegments: 1, material: "emissive.panel"), Xform(translation: led), to: "screen", option: 1, lods: 0...0)
        rig.lights = [RigLight(name: "screen-glow", kind: .point, part: "screen", option: 1, position: V3(0, yc, zFront + 0.35),
                               color: V3(0.78, 0.85, 1.0), intensity: 120, attenuationRadius: 1.6)]
        groundAO(&rig, height: 0.03, floor: 0.6)
        rig.states = [RigState("off"), RigState("on", options: ["screen": 1]),
                      RigState("raised-on", ["height": 0.1, "tilt": 12], options: ["screen": 1])]
        return rig
    }
}
