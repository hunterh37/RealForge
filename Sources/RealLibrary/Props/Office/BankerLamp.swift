import simd
import Foundation

/// Classic banker's desk lamp after the Emeralite (1909): stepped weighted brass base, brass post that
/// curves forward to a pivot knuckle over the shade, cased emerald glass shade (green outside, opal
/// white inside, open at the bottom) with a rolled rim, tubular bulb on a brass socket, ball pull chain
/// with a brass bead, cloth cord. The shade tilts about X on the knuckle; the bulb is a fixed child of
/// the shade with off and on options and a downward spot when on.
public struct BankerLamp: RealArticulated {
    public static let id = "banker-lamp"
    public static let summary = "Brass banker's desk lamp: stepped weighted base, curved post, tilting emerald cased-glass shade, tubular bulb, ball pull chain."
    public static let tags = ["prop", "office", "light", "metal", "glass", "articulated"]
    public static let budget = 6_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 14, distance: 0.95, studio: true)

    /// Shade length (X), depth (Z) and height (m); rim height above the desk.
    public var shade = V3(0.265, 0.085, 0.13)
    public var rimHeight: Float = 0.3
    public var brass: MaterialKey = "metal.brass"
    public init() {}

    /// Plan outline of the hood at half-depth `r`: two superelliptic end arcs `straight` apart joined by straight
    /// sides, counter-clockwise in (x, z-up) outline space.
    private func plan(_ r: Float, straight: Float, exponent n: Float, arc m: Int, sides q: Int) -> [V2] {
        func f(_ v: Float) -> Float { (v < 0 ? -1 : 1) * pow(abs(v), 2 / n) }
        let S = straight / 2
        var pts: [V2] = []
        for k in 0...m { let a = -Float.pi / 2 + .pi * Float(k) / Float(m); pts.append(V2(S + f(cos(a)) * r, f(sin(a)) * r)) }
        for j in 1..<q { pts.append(V2(S - 2 * S * Float(j) / Float(q), r)) }
        for k in 0...m { let a = Float.pi / 2 + .pi * Float(k) / Float(m); pts.append(V2(-S + f(cos(a)) * r, f(sin(a)) * r)) }
        for j in 1..<q { pts.append(V2(-S + 2 * S * Float(j) / Float(q), -r)) }
        return pts
    }

    /// Hood shell open at y = 0: superelliptic section (half-depth `depth / 2`, height `height`) with round ends,
    /// lofted from horizontal plan rings.
    private func hood(length: Float, height: Float, depth: Float, exponent n: Float, lod: Int, material: MaterialKey) -> Surface {
        let K = lod == 0 ? 9 : 5
        let rings = (0...K).map { k -> [V3] in
            let t = Float(k) / Float(K) * (Float.pi / 2) * 0.97
            let y = height * pow(sin(t), 2 / n), r = depth / 2 * pow(cos(t), 2 / n)
            return Prim.ring(plan(r, straight: length - depth, exponent: n, arc: lod == 0 ? 12 : 6, sides: lod == 0 ? 4 : 2), y: y)
        }
        return Prim.loft(rings, capEnd: true, material: material)
    }

    public func rig(seed: UInt64) -> Rig {
        _ = seed
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [7])
        let flat = simd_quatf(degrees: -90, axis: V3(1, 0, 0))
        let L = shade.x, H = shade.y, D = shade.z, n: Float = 2.3
        let shadeZ: Float = 0.036, postZ: Float = -0.06
        let pivot = V3(0, rimHeight + H + 0.011, shadeZ - 0.038)

        // MARK: base and post (static)
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let cs = l == 0 ? 6 : 3
            m.add(Prim.extrude(Shape2D.roundedRect(0.235, 0.15, radius: 0.034, segments: cs), depth: 0.013, bevel: l == 0 ? 0.0045 : 0.003,
                               bevelSegments: l == 0 ? 3 : 1, material: brass), Xform(translation: V3(0, 0.0065, 0.002), rotation: flat))
            m.add(Prim.extrude(Shape2D.roundedRect(0.196, 0.112, radius: 0.026, segments: cs), depth: 0.012, bevel: l == 0 ? 0.0045 : 0.003,
                               bevelSegments: l == 0 ? 3 : 1, material: brass), Xform(translation: V3(0, 0.0175, 0.002), rotation: flat))
            // Post boss, post and the forward curve to the knuckle.
            m.add(turned([(0, 0.022), (0.016, 0.022), (0.0165, 0.026), (0.012, 0.03), (0.0105, 0.036), (0.0085, 0.04), (0, 0.04)], segments: l == 0 ? 24 : 12,
                         material: brass), Xform(translation: V3(0, 0.0, postZ)))
            let path = catmull([V3(0, 0.036, postZ), V3(0, 0.2, postZ), V3(0, pivot.y - 0.03, postZ), V3(0, pivot.y - 0.004, postZ + 0.018),
                                V3(0, pivot.y, pivot.z - 0.004)], per: l == 0 ? 6 : 2)
            m.add(Prim.tube(path, radii: path.map { _ in 0.0062 }, sides: l == 0 ? 14 : 8, seamTile: 0.05, material: brass, capEnd: false))
            // Knuckle: barrel along X with end caps.
            m.add(Prim.cylinder(radius: 0.0085, height: 0.03, bevel: 0.002, segments: l == 0 ? 16 : 8, bevelSegments: 1, material: brass),
                  Xform(translation: pivot + V3(-0.015, 0, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
            if l == 0 {
                for sx: Float in [-1, 1] {
                    m.add(Prim.cylinder(radius: 0.006, height: 0.004, bevel: 0.0015, segments: 12, bevelSegments: 1, material: brass),
                          Xform(translation: pivot + V3(sx * 0.015, 0, 0), rotation: simd_quatf(degrees: sx > 0 ? -90 : 90, axis: V3(0, 0, 1))))
                }
                // Felt pad and cloth cord leaving the back of the base.
                m.add(Prim.extrude(Shape2D.roundedRect(0.228, 0.143, radius: 0.032, segments: 4), depth: 0.0012, bevel: 0.0003, bevelSegments: 1,
                                   material: "fabric.canvas:1E3A26"), Xform(translation: V3(0, 0.0004, 0.002), rotation: flat))
                let cord = catmull([V3(0.03, 0.006, -0.07), V3(0.04, 0.0035, -0.088), V3(0.07, 0.0035, -0.1), V3(0.1, 0.0035, -0.098)], per: 4)
                m.add(Prim.tube(cord, radii: cord.map { _ in 0.0032 }, sides: 6, seamTile: 0.02, material: "fabric.canvas:2A2826"))
            }
            rig.base[l] = m
        }

        // MARK: shade (tilts on the knuckle)
        rig.part("shade", pivot: pivot, joint: .hinge(axis: V3(1, 0, 0), -12...20, duration: 0.7))
        rig.part("bulb", parent: "shade", pivot: pivot, joint: .fixed, options: 2)
        let center = V3(0, rimHeight, shadeZ)
        for l in 0..<2 {
            let lod = l...l
            let wall: Float = 0.0035
            rig.add(hood(length: L, height: H, depth: D, exponent: n, lod: l, material: "glass.emerald"), Xform(translation: center), to: "shade", lods: lod)
            rig.add(hood(length: L - 2 * wall, height: H - wall, depth: D - 2 * wall, exponent: n, lod: l, material: "plastic.diffuser").flipped(),
                    Xform(translation: center), to: "shade", lods: lod)
            // Rolled rim bead joining outer glass and inner opal layer.
            let rim = Prim.ring(plan(D / 2 - wall / 2, straight: L - D, exponent: n, arc: l == 0 ? 12 : 6, sides: l == 0 ? 4 : 2), y: 0)
            rig.add(Prim.sweep(Shape2D.circle(wall * 0.62, segments: l == 0 ? 8 : 5), along: rim, up: .up, closedPath: true, caps: false, material: "plastic.diffuser"),
                    Xform(translation: center), to: "shade", lods: lod)
        }
        // Strap from the knuckle onto the shade crown, with a brass crown plate.
        rig.add(Prim.roundedBox(V3(0.018, 0.006, 0.04), radius: 0.002, bevelSegments: 1, material: brass),
                Xform(translation: V3(0, pivot.y - 0.006, (pivot.z + shadeZ) / 2 - 0.002), rotation: simd_quatf(degrees: -8, axis: V3(1, 0, 0))), to: "shade")
        rig.add(Prim.extrude(Shape2D.roundedRect(0.05, 0.034, radius: 0.012, segments: 3), depth: 0.0025, bevel: 0.001, bevelSegments: 1, material: brass),
                Xform(translation: V3(0, rimHeight + H + 0.0006, shadeZ - 0.004), rotation: flat), to: "shade")
        // Socket inside the shade (brass, hung from the crown) and the pull chain hanging from it.
        let socket = V3(-0.05, rimHeight + H - 0.036, shadeZ)
        rig.add(Prim.cylinder(radius: 0.012, height: 0.034, bevel: 0.002, segments: 14, bevelSegments: 1, material: brass),
                Xform(translation: socket + V3(-0.017, 0, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "shade")
        rig.add(Prim.cylinder(radius: 0.003, height: 0.02, bevel: 0.001, segments: 8, bevelSegments: 1, material: brass),
                Xform(translation: socket + V3(0, 0.01, 0)), to: "shade", lods: 0...0)
        var beads = Surface(material: "metal.brass-aged")
        let ball = Prim.superellipsoid(V3(repeating: 0.0024), exponent: 2, subdivisions: 1, material: "metal.brass-aged")
        let chainTop = socket + V3(0.006, -0.012, 0.006), chainLen: Float = 0.105
        var y: Float = 0
        while y < chainLen { beads.append(ball, Xform(translation: chainTop - V3(0, y, 0))); y += 0.0034 }
        rig.add(beads, to: "shade", lods: 0...0)
        rig.add(Prim.tube([chainTop, chainTop - V3(0, chainLen, 0)], radii: [0.0004, 0.0004], sides: 3, seamTile: 0.01, material: "metal.brass-aged"), to: "shade", lods: 1...1)
        rig.add(turned([(0, -0.012), (0.003, -0.011), (0.0045, -0.007), (0.0042, -0.003), (0.0016, 0), (0, 0.0005)], segments: 12, material: brass),
                Xform(translation: chainTop - V3(0, chainLen, 0)), to: "shade")
        // Bulb: tubular lamp along X off the socket; option 1 lit.
        let bulbProfile: [V2] = [V2(0, 0), V2(0.009, 0.002), V2(0.0145, 0.012), V2(0.0155, 0.06), V2(0.0135, 0.085), V2(0.007, 0.094), V2(0, 0.096)]
        let bulbX = Xform(translation: socket + V3(0.0, 0, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1)))
        rig.add(Prim.lathe(bulbProfile, segments: 14, seamTile: 0.1, material: "plastic.diffuser"), bulbX, to: "bulb")
        rig.add(Prim.lathe(bulbProfile, segments: 14, seamTile: 0.1, material: "emissive.bulb"), bulbX, to: "bulb", option: 1)
        rig.lights = [RigLight(name: "lamp", kind: .spot(inner: 40, outer: 70), part: "bulb", option: 1, position: socket + V3(0.05, -0.01, 0),
                               direction: V3(0, -1, 0.05), intensity: 450, attenuationRadius: 3, castsShadow: true)]
        groundAO(&rig, height: 0.03, floor: 0.6)
        rig.states = [RigState("off"), RigState("on", options: ["bulb": 1]), RigState("tilted-on", ["shade": 15], options: ["bulb": 1])]
        return rig
    }
}
