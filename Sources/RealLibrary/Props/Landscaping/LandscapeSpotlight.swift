import simd
import Foundation

/// Low-voltage bullet uplight, 0.33 m: ground stake collar, knuckle swivel, cylindrical cast aluminum
/// body with cooling rings, angled glare hood, glass lens, cable. The body tilts on the knuckle
/// (rest 30 degrees forward, on aims 60 degrees up) and the lens lights with a spot beam when on.
public struct LandscapeSpotlight: RealArticulated {
    public static let id = "landscape-spotlight"
    public static let summary = "Bullet uplight on a ground stake, 0.33 m: cylindrical aluminum body with glare hood on a knuckle, tilts up when on with a spot beam."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "light", "metal", "articulated"]
    public static let budget = 4000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 60, elevation: 15, distance: 1.1)

    /// Body length (m).
    public var bodyLength: Float = 0.15
    /// Body radius (m).
    public var bodyRadius: Float = 0.032
    /// Housing finish.
    public var finish: MaterialKey = "metal.cast-iron:3A3630"
    /// Beam intensity when on.
    public var intensity: Float = 2500
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        _ = seed
        var rig = Rig(name: Self.id, lods: 1)
        var m = Model(name: Self.id)
        let knuckle = V3(0, 0.1, 0)
        // Stake collar at grade and a short riser to the knuckle.
        m.add(turned([(0, 0), (0.02, 0), (0.024, 0.01), (0.024, 0.024), (0.014, 0.03), (0, 0.03)], segments: 20, material: "plastic.black"))
        m.add(Prim.cylinder(radius: 0.012, height: knuckle.y - 0.03 - 0.012, bevel: 0.002, segments: 16, material: finish), Xform(translation: V3(0, 0.03, 0)))
        // Soil smudge on the stake collar.
        m.add(Prim.superellipsoid(V3(0.05, 0.012, 0.045), exponent: 2.2, subdivisions: 2, material: "ground.mud"), Xform(translation: V3(0.004, 0.003, 0.003)))
        // Knuckle yoke: two cheeks and a bolt.
        for s: Float in [-1, 1] {
            m.add(Prim.extrude(Shape2D.roundedRect(0.03, 0.04, radius: 0.012), depth: 0.006, bevel: 0.0015, material: finish),
                  Xform(translation: knuckle + V3(s * 0.017, -0.006, 0), rotation: simd_quatf(degrees: 90, axis: .up)))
        }
        m.add(Prim.cylinder(radius: 0.005, height: 0.046, bevel: 0.001, segments: 10, material: "metal.stainless"),
              Xform(translation: knuckle - V3(0.023, 0, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        // Cable out of the riser.
        let cable = catmull([V3(0, 0.045, -0.012), V3(0, 0.02, -0.03), V3(0.01, 0.005, -0.06), V3(0.03, 0.005, -0.09)], per: 5)
        m.add(Prim.tube(cable, radii: cable.map { _ in 0.0035 }, sides: 6, seamTile: 0.05, material: "rubber"))
        rig.base[0] = m

        // Head: built pointing +Y from the knuckle at rest, hinged about X.
        rig.part("head", pivot: knuckle, joint: .hinge(axis: V3(1, 0, 0), -30...10, duration: 0.8))
        rig.part("lens", parent: "head", pivot: knuckle, joint: .fixed, options: 2)
        let R = bodyRadius, L = bodyLength, y0 = knuckle.y + 0.012
        // Tilt the whole head forward 30 degrees at rest by building it rotated.
        let tilt = Xform(translation: knuckle, rotation: simd_quatf(degrees: 30, axis: V3(1, 0, 0)))
        func at(_ s: Surface, _ y: Float = 0) -> (Surface, Xform) { (s, Xform(translation: tilt.translation + tilt.rotation.act(V3(0, y - knuckle.y, 0)), rotation: tilt.rotation)) }
        let tab = Prim.roundedBox(V3(0.026, 0.03, 0.02), radius: 0.004, bevelSegments: 2, material: finish)
        var (s, x) = at(tab, knuckle.y + 0.006); rig.add(s, x, to: "head")
        var body: [V2] = [V2(0, 0), V2(R * 0.55, 0), V2(R * 0.9, 0.012), V2(R, 0.03)]
        for i in 0..<4 { let y = 0.045 + Float(i) * 0.014; body += [V2(R, y), V2(R + 0.003, y + 0.003), V2(R + 0.003, y + 0.007), V2(R, y + 0.01)] }
        body += [V2(R, L - 0.004), V2(R + 0.002, L), V2(R - 0.004, L + 0.001), V2(R - 0.006, L - 0.004)]
        (s, x) = at(Prim.lathe(body, segments: 32, seamTile: 0.2, material: finish), y0); rig.add(s, x, to: "head")
        // Glare hood: half sleeve extended past the lens on the top side.
        var hood: [V3] = []
        for k in 0...12 { let a = Float.pi * Float(k) / 12; hood.append(V3(cos(a) * (R + 0.002), 0, sin(a) * (R + 0.002))) }
        var hoodSurf = Prim.sweep(Shape2D.roundedRect(0.05, 0.003, radius: 0.001), along: hood, up: .up, material: finish)
        hoodSurf.deform { p in V3(p.x, p.y + (p.z > 0 ? p.z / R * 0.02 : 0), p.z) }
        (s, x) = at(hoodSurf, y0 + L - 0.008); rig.add(s, x, to: "head")
        // Lens.
        let lens = Prim.lathe([V2(R - 0.006, 0), V2(0, 0.003)], segments: 32, seamTile: 0.1, material: "glass.led-lens")
        let lit = Prim.lathe([V2(R - 0.006, 0), V2(0, 0.003)], segments: 32, seamTile: 0.1, material: "emissive.warm")
        (s, x) = at(lens, y0 + L - 0.006); rig.add(s, x, to: "lens", option: 0)
        (s, x) = at(lit, y0 + L - 0.006); rig.add(s, x, to: "lens", option: 1)
        let dir = tilt.rotation.act(V3(0, 1, 0))
        rig.lights = [RigLight(name: "beam", kind: .spot(inner: 15, outer: 35), part: "lens", option: 1,
                               position: knuckle + dir * (L + 0.02), direction: dir, intensity: intensity, attenuationRadius: 6, castsShadow: true)]
        groundAO(&rig, height: 0.06)
        rig.states = [RigState("off"), RigState("on", ["head": -30], options: ["lens": 1])]
        _ = Self.id
        return rig
    }
}
