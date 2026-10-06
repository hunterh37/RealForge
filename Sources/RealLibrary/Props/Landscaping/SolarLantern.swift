import simd
import Foundation

/// Solar garden lantern, 0.32 m to the top of the hanging loop: square stepped base, four corner posts,
/// glass panes, a pyramid roof carrying a solar cell, a wire hanging loop, and a warm LED bulb inside.
public struct SolarLantern: RealAsset {
    public static let id = "solar-lantern"
    public static let summary = "Solar garden lantern, 0.32 m: square metal cage, glass panes, solar panel lid, hanging loop, warm LED inside."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "light", "glass"]
    public static let budget = 4000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 20, distance: 0.8)

    /// Body width (m).
    public var width: Float = 0.15
    /// Frame finish.
    public var finish: MaterialKey = "metal.powdercoat:1E1E1E"
    /// LED material; emissive.warm reads as lit at dusk.
    public var led: MaterialKey = "emissive.warm"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let w = width, bodyH: Float = 0.17, baseH: Float = 0.025
        m.add(Prim.roundedBox(V3(w, baseH * 0.6, w), radius: 0.004, bevelSegments: 2, material: finish), Xform(translation: V3(0, baseH * 0.3, 0)))
        m.add(Prim.roundedBox(V3(w - 0.016, baseH * 0.5, w - 0.016), radius: 0.003, bevelSegments: 2, material: finish), Xform(translation: V3(0, baseH * 0.75, 0)))
        let top = baseH + bodyH
        // Posts.
        let pi = w / 2 - 0.012
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.01, bodyH, 0.01), radius: 0.002, bevelSegments: 1, material: finish), Xform(translation: V3(sx * pi, baseH + bodyH / 2, sz * pi)))
        } }
        // Glass panes and mid bars.
        for i in 0..<4 {
            let rot = simd_quatf(degrees: Float(i) * 90, axis: .up)
            m.add(Prim.roundedBox(V3(2 * pi - 0.008, bodyH - 0.006, 0.003), radius: 0.001, bevelSegments: 1, material: "glass.clear"),
                  Xform(translation: rot.act(V3(0, baseH + bodyH / 2, pi)), rotation: rot))
            m.add(Prim.roundedBox(V3(2 * pi, 0.006, 0.006), radius: 0.0015, bevelSegments: 1, material: finish),
                  Xform(translation: rot.act(V3(0, top - 0.004, pi)), rotation: rot))
        }
        // Roof: pyramid frustum with the solar cell on top.
        let roof = Prim.loft([Prim.ring(Shape2D.roundedRect(w + 0.02, w + 0.02, radius: 0.006), y: top),
                              Prim.ring(Shape2D.roundedRect(w * 0.6, w * 0.6, radius: 0.005), y: top + 0.045)], capStart: true, capEnd: true, material: finish)
        m.add(roof)
        m.add(Prim.roundedBox(V3(w + 0.022, 0.008, w + 0.022), radius: 0.003, bevelSegments: 2, material: finish), Xform(translation: V3(0, top + 0.002, 0)))
        m.add(Prim.roundedBox(V3(w * 0.5, 0.004, w * 0.5), radius: 0.001, bevelSegments: 1, material: "screen.off"), Xform(translation: V3(0, top + 0.046, 0)))
        // Solar cell grid lines.
        for k in 1..<4 {
            let o = -w * 0.25 + Float(k) * w * 0.5 / 4
            m.add(Prim.roundedBox(V3(0.0015, 0.001, w * 0.48), radius: 0.0004, bevelSegments: 1, material: "metal.aluminum-brushed"), Xform(translation: V3(o, top + 0.0485, 0)))
            m.add(Prim.roundedBox(V3(w * 0.48, 0.001, 0.0015), radius: 0.0004, bevelSegments: 1, material: "metal.aluminum-brushed"), Xform(translation: V3(0, top + 0.0485, o)))
        }
        // Hanging loop.
        m.add(Prim.torus(major: 0.035, minor: 0.0025, segments: 24, sides: 6, arc: .pi, material: finish),
              Xform(translation: V3(0, top + 0.05, 0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // LED bulb on a socket.
        m.add(Prim.cylinder(radius: 0.012, height: 0.03, bevel: 0.002, segments: 12, material: finish), Xform(translation: V3(0, top - 0.03, 0)))
        m.add(turned([(0, 0), (0.012, 0.004), (0.016, 0.02), (0.012, 0.036), (0, 0.04)], segments: 16, material: led), Xform(translation: V3(0, top - 0.072, 0)))
        _ = rng.float(0...1)
        groundAO(&m, height: 0.05)
        return LODModel(m)
    }
}
