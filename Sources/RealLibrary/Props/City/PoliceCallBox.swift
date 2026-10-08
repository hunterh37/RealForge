import simd
import Foundation

/// Gamewell-style police call box: a cast-iron fluted post on a stepped base, a box with a hinged
/// door (POLICE cast into it, brass handle and key escutcheon) under a peaked cap, and a glass lamp
/// globe on top. Repainted many times; the brass is dark and the base is chipped.
public struct PoliceCallBox: RealAsset {
    public static let id = "police-call-box"
    public static let summary = "Cast-iron police call box on a fluted post with a hinged door and a lamp on top."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "metal", "antique"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 10, distance: 1.1)

    /// Overall height (m).
    public var height: Float = 2.2
    /// Paint color key.
    public var paint: MaterialKey = "metal.painted:1E3566"
    public var brass: MaterialKey = "metal.brass-aged"
    public var globe: MaterialKey = "glass.frosted"
    public var lettering = "POLICE"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let boxY: Float = 1.32, boxH: Float = 0.46, bw: Float = 0.3, bd: Float = 0.24
        // Stepped base and fluted column (flutes as a 16-lobe lathe ripple).
        m.add(turned([(0, 0), (0.2, 0), (0.2, 0.05), (0.17, 0.07), (0.16, 0.16), (0.12, 0.2), (0.11, 0.3), (0.085, 0.36), (0, 0.36)], segments: 32, material: paint))
        var col = Prim.lathe([V2(0.075, 0.36), V2(0.068, 0.6), V2(0.062, boxY - 0.12), V2(0.08, boxY - 0.08), V2(0.11, boxY - 0.03), V2(0.11, boxY), V2(0, boxY)], segments: 64, seamTile: 0.2, material: paint)
        col = col.displacedFlutes(count: 16, depth: 0.011, y0: 0.38, y1: boxY - 0.13)
        m.add(col)
        // Box body with a peaked cap.
        m.add(Prim.roundedBox(V3(bw, boxH, bd), radius: 0.015, bevelSegments: 2, material: paint), Xform(translation: V3(0, boxY + boxH / 2, 0)))
        m.add(Prim.roundedBox(V3(bw + 0.04, 0.03, bd + 0.04), radius: 0.01, bevelSegments: 2, material: paint), Xform(translation: V3(0, boxY + boxH + 0.015, 0)))
        let cap = Prim.loft([Prim.ring(Shape2D.roundedRect(bw + 0.03, bd + 0.03, radius: 0.01, segments: 2), y: 0),
                             Prim.ring(Shape2D.roundedRect(0.08, 0.06, radius: 0.01, segments: 2), y: 0.1)], capStart: true, capEnd: true, material: paint)
        m.add(cap, Xform(translation: V3(0, boxY + boxH + 0.03, 0)))
        // Lamp: collar, globe, crown and finial.
        let ly = boxY + boxH + 0.13
        m.add(turned([(0, ly), (0.06, ly), (0.06, ly + 0.03), (0.045, ly + 0.04), (0, ly + 0.04)], segments: 20, material: paint))
        m.add(turned((0...10).map { i -> (Float, Float) in let a = Float(i) / 10 * .pi; return (0.085 * sin(a) + 0.02, ly + 0.04 + 0.17 * (1 - cos(a)) / 2) }, segments: 24, material: globe))
        m.add(turned([(0, height - 0.05), (0.06, height - 0.05), (0.03, height - 0.02), (0.012, height - 0.01), (0, height)], segments: 20, material: paint))
        // Door on the front: raised panel with bead, cast lettering, hinge knuckles, handle, keyhole.
        let fz = bd / 2
        m.add(Prim.roundedBox(V3(bw - 0.05, boxH - 0.06, 0.012), radius: 0.008, bevelSegments: 2, material: paint), Xform(translation: V3(0, boxY + boxH / 2, fz + 0.004)))
        var t = strokeText(lettering, height: 0.035, stroke: 0.007, depth: 0.003, material: brass)
        t = t.transformed(Xform(scale: V3(0.7, 1, 1)))
        m.add(t, Xform(translation: V3(0, boxY + boxH - 0.08, fz + 0.01)))
        for hy in [boxY + 0.08, boxY + boxH - 0.08] {
            m.add(Prim.cylinder(radius: 0.009, height: 0.05, bevel: 0.002, segments: 10, material: paint), Xform(translation: V3(-bw / 2 + 0.02, hy - 0.025, fz + 0.012)))
        }
        m.add(barHandle(length: 0.06, standoff: 0.018, radius: 0.006, material: brass), Xform(translation: V3(bw / 2 - 0.06, boxY + boxH / 2, fz + 0.01), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        m.add(Prim.cylinder(radius: 0.012, height: 0.004, bevel: 0.001, segments: 12, material: brass), Xform(translation: V3(bw / 2 - 0.06, boxY + boxH / 2 - 0.07, fz + 0.01), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        m.add(cuboid(V3(0.003, 0.012, 0.002), material: "metal.steel:0A0A0A"), Xform(translation: V3(bw / 2 - 0.06, boxY + boxH / 2 - 0.07, fz + 0.0125)))
        // Chips on the base where bins and boots hit.
        for _ in 0..<10 {
            let a = rng.float(0...6.28), y = rng.float(0.02...0.15)
            m.add(cuboid(V3(rng.float(0.008...0.025), rng.float(0.005...0.015), 0.001), material: "metal.rust"),
                  Xform(translation: V3(sin(a) * 0.168, y, cos(a) * 0.168), rotation: simd_quatf(angle: a, axis: .up)))
        }
        groundAO(&m, height: 0.3, floor: 0.6)
        return LODModel(m)
    }
}

extension Surface {
    /// Vertical flutes on a lathe about +Y: push vertices in by `depth` at `count` lobes between y0 and y1.
    func displacedFlutes(count: Int, depth: Float, y0: Float, y1: Float) -> Surface {
        var s = self
        for i in s.positions.indices {
            let p = s.positions[i]
            guard p.y > y0, p.y < y1 else { continue }
            let r = simd_length(V2(p.x, p.z)); guard r > 1e-4 else { continue }
            let a = atan2(p.z, p.x), f = 0.5 - 0.5 * cos(a * Float(count))
            let fade = min(1, min(p.y - y0, y1 - p.y) / 0.04)
            let nr = r - depth * f * fade
            s.positions[i] = V3(p.x / r * nr, p.y, p.z / r * nr)
        }
        s.recomputeNormals(); s.computeTangents()
        return s
    }
}
