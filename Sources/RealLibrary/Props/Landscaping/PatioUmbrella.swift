import simd
import Foundation

/// Market patio umbrella, 2.45 m tall with a 2.6 m octagonal canopy when open: square weighted base,
/// two-piece aluminum pole with a crank, sliding runner, eight ribs hinged at the top hub, struts,
/// canvas canopy with a wind vent and finial. The runner slides up the pole and the ribs follow it
/// (mimic); the canopy swaps between furled and spread fabric. States: closed, open.
public struct PatioUmbrella: RealArticulated {
    public static let id = "patio-umbrella"
    public static let summary = "Market patio umbrella, 2.6 m canopy: aluminum pole, weighted base, eight ribs and struts on a sliding runner, vented canvas canopy; closed and open."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "furniture", "fabric", "articulated"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 14, distance: 1.2)

    /// Canopy fabric.
    public var canvas: MaterialKey = "fabric.canvas:C8B996"
    /// Frame finish.
    public var frame: MaterialKey = "metal.aluminum-brushed"
    /// Hub height (m).
    public var hubHeight: Float = 2.38
    /// Rib length (m).
    public var ribLength: Float = 1.36
    /// Opening angle of the ribs from vertical (degrees).
    public var openAngle: Float = 72
    public init() {}

    private let ribs = 8
    private let restTilt: Float = 4

    private func phi(_ i: Int) -> Float { Float(i) / 8 * 2 * .pi + .pi / 8 }
    /// Rib direction at `deg` degrees from straight down, swung outward toward rib i.
    private func ribDir(_ i: Int, _ deg: Float) -> V3 {
        let a = deg * .pi / 180, p = phi(i)
        return V3(cos(p) * sin(a), -cos(a), sin(p) * sin(a))
    }

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 1)
        var m = Model(name: Self.id)
        let hub = V3(0, hubHeight, 0)
        let poleR: Float = 0.019
        // Weighted base: beveled concrete square with a steel collar.
        m.add(Prim.roundedBox(V3(0.5, 0.075, 0.5), radius: 0.02, bevelSegments: 3, material: "concrete.smooth:5A5853"), Xform(translation: V3(0, 0.0375, 0)))
        m.add(turned([(0, 0.07), (0.07, 0.07), (0.065, 0.1), (0.035, 0.13), (0.03, 0.2), (0, 0.2)], segments: 28, material: "plastic.black"))
        m.add(Prim.cylinder(radius: 0.006, height: 0.06, bevel: 0.002, segments: 8, material: "plastic.black"),
              Xform(translation: V3(0.034, 0.16, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        // Pole (two sections with a joint sleeve) up to the finial.
        m.add(Prim.cylinder(radius: poleR, height: hubHeight + 0.06 - 0.12, bevel: 0.002, segments: 20, material: frame), Xform(translation: V3(0, 0.12, 0)))
        m.add(Prim.cylinder(radius: poleR + 0.003, height: 0.08, bevel: 0.002, segments: 20, material: frame), Xform(translation: V3(0, 1.15, 0)))
        // Crank housing and handle.
        m.add(Prim.roundedBox(V3(0.05, 0.09, 0.05), radius: 0.012, bevelSegments: 2, material: "plastic.black"), Xform(translation: V3(0, 1.45, 0.012)))
        let crank = [V3(0, 1.45, 0.04), V3(0, 1.45, 0.07), V3(0.08, 1.43, 0.07)]
        m.add(Prim.tube(crank, radii: [0.005, 0.005, 0.005], sides: 8, seamTile: 0.05, material: frame))
        m.add(Prim.cylinder(radius: 0.009, height: 0.045, bevel: 0.002, segments: 10, material: "plastic.black"), Xform(translation: V3(0.08, 1.43, 0.07)))
        // Top hub.
        m.add(turned([(0, -0.03), (0.035, -0.03), (0.04, -0.01), (0.04, 0.02), (0.02, 0.03), (0, 0.03)], segments: 24, material: "plastic.black"), Xform(translation: hub))
        rig.base[0] = m

        // Runner slides up; ribs follow it.
        let slide: Float = 0.25
        let ratio = (openAngle - restTilt) / slide
        rig.part("runner", pivot: V3(0, hubHeight - 0.5, 0), joint: .slide(axis: V3(0, 1, 0), 0...slide, duration: 1.4))
        rig.add(turned([(0, -0.05), (0.03, -0.05), (0.034, -0.03), (0.034, 0.03), (0.03, 0.05), (0, 0.05)], segments: 24, material: "plastic.black"),
                Xform(translation: V3(0, hubHeight - 0.5, 0)), to: "runner")
        for i in 0..<ribs {
            let p = phi(i), axis = V3(-sin(p), 0, cos(p))
            let name = "rib\(i)"
            rig.part(name, pivot: hub, joint: Joint(.revolute, axis: axis, range: 0...(openAngle - restTilt), mimic: .init("runner", ratio: ratio)))
            let d = ribDir(i, restTilt)
            let pts = [hub + d * 0.03, hub + d * ribLength]
            rig.add(Prim.tube(pts, radii: [0.006, 0.005], sides: 6, seamTile: 0.1, material: frame), to: name)
            rig.add(Prim.cylinder(radius: 0.007, height: 0.025, bevel: 0.002, segments: 8, material: "plastic.black"),
                    Xform(translation: hub + d * ribLength, rotation: simd_quatf(from: V3(0, 1, 0), to: d)), to: name)
        }
        // Canopy and struts: furled (0) or spread (1), linked to the runner.
        rig.part("canopy", pivot: hub, joint: .fixed, options: 2)
        rig.optionLinks = [RigOptionLink(part: "canopy", joint: "runner", thresholds: [slide * 0.5])]
        // Furled: pleated cone around the closed ribs, a tie strap, struts folded along the pole.
        let L = ribLength
        var furl = Prim.lathe([V2(0.03, hubHeight - L - 0.07), V2(0.09, hubHeight - L - 0.02), V2(0.125, hubHeight - L * 0.85), V2(0.13, hubHeight - L * 0.55),
                               V2(0.1, hubHeight - 0.3), V2(0.05, hubHeight), V2(0.0, hubHeight + 0.06)], segments: 48, seamTile: 0.6, material: canvas)
        furl.displace { p, n in
            let a = atan2(p.z, p.x)
            return 0.018 * pow(abs(cos(a * 4 + p.y * 1.2)), 3) * simd_length(V2(n.x, n.z))
        }
        rig.add(furl, to: "canopy", option: 0)
        rig.add(Prim.torus(major: 0.15, minor: 0.009, segments: 32, sides: 6, material: canvas), Xform(translation: V3(0, hubHeight - L * 0.55, 0)), to: "canopy", option: 0)
        // Spread: octagon cone with sag between ribs, double-sided, vent and finial.
        let spread = openAngle
        let tips = (0..<ribs).map { hub + ribDir($0, spread) * ribLength }
        let drop = hubHeight - tips[0].y, R = simd_length(V2(tips[0].x, tips[0].z))
        func octagon(_ s: Float) -> [V2] {
            var out: [V2] = []
            for i in 0..<ribs {
                let a = V2(tips[i].x, tips[i].z) * s, b = V2(tips[(i + 1) % ribs].x, tips[(i + 1) % ribs].z) * s
                for k in 0..<6 { out.append(a + (b - a) * Float(k) / 6) }
            }
            return out
        }
        let K = 8
        var rings: [[V3]] = []
        for k in 1...K {
            let s = 0.03 + 0.97 * Float(k) / Float(K)
            rings.append(Prim.ring(octagon(s), y: hubHeight + 0.02 - drop * s))
        }
        var cone = Prim.loft(rings, material: canvas)
        cone.deform { p in
            let r = simd_length(V2(p.x, p.z)), s = r / R
            let a = atan2(p.z, p.x) - .pi / 8
            let between = 1 - abs(cos(a * 4))
            let bow = s * (1 - s) * 0.12 + 0.0
            return V3(p.x, p.y - between * 0.05 * s - bow * 0.3, p.z)
        }
        rig.add(cone, to: "canopy", option: 1)
        rig.add(cone.flipped(), Xform(translation: V3(0, -0.003, 0)), to: "canopy", option: 1)
        // Valance flaps below each panel edge.
        for i in 0..<ribs {
            let a = tips[i], b = tips[(i + 1) % ribs], mid = (a + b) / 2 - V3(0, 0.05, 0)
            let edge = catmull([a, mid, b], per: 6).map { $0 - V3(0, 0.004, 0) }
            rig.add(Prim.sweep(Shape2D.rect(0.09, 0.002), along: edge, up: .up, material: canvas), Xform(translation: V3(0, -0.045, 0)), to: "canopy", option: 1)
        }
        // Vent: raised small canopy over the hub with a gap.
        rig.add(Prim.lathe([V2(0.3, hubHeight + 0.0), V2(0.2, hubHeight + 0.07), V2(0.02, hubHeight + 0.13), V2(0, hubHeight + 0.135)], segments: 32, seamTile: 0.5, material: canvas),
                to: "canopy", option: 1)
        rig.add(turned([(0, hubHeight + 0.13), (0.015, hubHeight + 0.13), (0.02, hubHeight + 0.16), (0.012, hubHeight + 0.19), (0, hubHeight + 0.2)], segments: 16, material: "plastic.black"),
                to: "canopy", option: 1)
        // Struts.
        for i in 0..<ribs {
            let p = phi(i), r0 = V3(cos(p), 0, sin(p)) * 0.034
            let closedA = V3(0, hubHeight - 0.5, 0) + r0, closedB = hub + ribDir(i, restTilt) * (L * 0.42)
            rig.add(Prim.tube([closedA, closedB], radii: [0.004, 0.004], sides: 5, seamTile: 0.1, material: frame), to: "canopy", option: 0)
            let openA = V3(0, hubHeight - 0.5 + slide, 0) + r0, openB = hub + ribDir(i, spread) * (L * 0.42)
            rig.add(Prim.tube([openA, openB], radii: [0.004, 0.004], sides: 5, seamTile: 0.1, material: frame), to: "canopy", option: 1)
        }
        _ = rng.float(0...1)
        groundAO(&rig, height: 0.15)
        rig.states = [RigState("closed"), RigState("open", ["runner": slide], options: ["canopy": 1])]
        rig.defaultState = "open"
        return rig
    }
}
