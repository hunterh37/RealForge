import simd
import Foundation

/// Naturalist's sweep net lying on the ground: 1.0 m turned oak handle with a brass ferrule and end
/// cap, a 30 cm brass hoop standing on its edge, and a fine cotton-mesh bag (articulated `bag`,
/// hinged at the hoop) trailing behind it.
public struct BugNet: RealArticulated {
    public static let id = "bug-net"
    public static let summary = "Insect sweep net, 1.3 m: turned oak handle, brass ferrule, 30 cm brass hoop, fine mesh bag (articulated bag)."
    public static let tags = ["prop", "tool", "wood", "metal", "outdoor", "handheld", "articulated"]
    public static let budget = 9_000
    public static let preview = PreviewHint(azimuth: 55, elevation: 28, distance: 1.0)

    public var handleLength: Float = 1.0
    public var hoopDiameter: Float = 0.30
    public var bagDepth: Float = 0.45
    public var handle: MaterialKey = "wood.hammer-hickory-grimy"
    public var brass: MaterialKey = "metal.brass-aged"
    public var mesh: MaterialKey = "insect.netting"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [6])
        let R = hoopDiameter / 2, wire: Float = 0.0035
        let hoopZ: Float = 0.29                         // hoop plane z; handle runs to -z
        let hc = V3(0, R + wire, hoopZ)                // hoop centre
        rig.part("bag", pivot: hc, joint: .hinge(axis: V3(1, 0, 0), -40...40, duration: 0.4))
        for lod in 0..<2 {
            let L = lod...lod
            // Handle along -Z resting on the ground, ferrule end lifted onto the hoop rim.
            let r0: Float = 0.0135
            var prof: [(Float, Float)] = [(0, 0), (r0 * 0.95, 0.002), (r0 * 1.05, 0.03), (r0, 0.06)]
            prof += [(r0 * 0.92, handleLength * 0.5), (r0 * 0.85, handleLength - 0.02), (r0 * 0.6, handleLength), (0, handleLength)]
            let lift = Xform(translation: V3(0, r0, hoopZ - 0.02 - handleLength), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)) )
            var h = turned(prof, segments: lod == 0 ? 24 : 12, material: handle, grainVertical: true)
            h = h.transformed(lift)
            rig.base[lod].add(h)
            // Brass ferrule and butt cap.
            let ferr = Prim.cylinder(radius: r0 * 1.12, height: 0.07, bevel: 0.0015, segments: lod == 0 ? 24 : 12, material: brass)
            rig.base[lod].add(ferr, Xform(translation: V3(0, r0, hoopZ - 0.09), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            let cap = Prim.cylinder(radius: r0 * 1.08, height: 0.02, bevel: 0.002, segments: lod == 0 ? 24 : 12, material: brass)
            rig.base[lod].add(cap, Xform(translation: V3(0, r0, hoopZ - 0.02 - handleLength), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            // Hoop standing on edge in the XY plane, its wire tail entering the ferrule.
            let hoop = Prim.torus(major: R, minor: wire, segments: lod == 0 ? 64 : 28, sides: lod == 0 ? 10 : 6, material: brass)
            rig.base[lod].add(hoop, Xform(translation: hc, rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            rig.base[lod].add(Prim.tube([V3(0, wire, hoopZ), V3(0, r0, hoopZ - 0.03), V3(0, r0, hoopZ - 0.06)], radii: [wire, wire, wire],
                                        sides: 8, seamTile: 0.02, material: brass, capEnd: true))
            // Bag: cone of mesh from the hoop, sagging to the ground behind it (+Z).
            let nr = lod == 0 ? 32 : 16, nl = lod == 0 ? 14 : 6
            var bag = Surface(material: mesh)
            var canvas = Surface(material: "fabric.canvas:D8D0B8")
            for j in 0...nl {
                let t = Float(j) / Float(nl)
                let tipRound = t > 0.8 ? sqrt(max(0, 1 - pow((t - 0.8) / 0.2, 2))) : 1
                let rr = R * (1 - 0.55 * t) * 0.985 * tipRound + 0.0005
                let zc = hoopZ + t * bagDepth
                let yc = hc.y * pow(1 - t, 1.6) + (rr * 0.35 + 0.006) * (1 - pow(1 - t, 1.6))
                let squash = 1 - 0.55 * smoothstep(0, 0.6, t)
                for i in 0...nr {
                    let a = Float(i) / Float(nr) * 2 * .pi
                    let wr = 1 + 0.05 * sin(a * 7 + t * 9) * smoothstep(0.05, 0.4, t)
                    var p = V3(cos(a) * rr * wr * (1 + 0.2 * smoothstep(0, 0.6, t)), yc + sin(a) * rr * wr * squash, zc + 0.01 * sin(a * 3) * t)
                    p.y = max(p.y, 0.002 + 0.002 * t)
                    _ = bag.add(p, .up, V2(Float(i) / Float(nr) * 2 * .pi * R, t * bagDepth))
                    if j <= 1 && lod == 0 || (lod == 1 && j == 0) {}
                }
            }
            let row = UInt32(nr + 1)
            for j in 0..<UInt32(nl) { for i in 0..<UInt32(nr) { let a = j * row + i; bag.quad(a, a + 1, a + row + 1, a + row) } }
            bag.recomputeNormals(weldSeams: false); bag.computeTangents()
            rig.add(bag, to: "bag", lods: L)
            // Canvas collar sewn over the hoop.
            canvas = Prim.torus(major: R, minor: wire * 2.2, segments: lod == 0 ? 64 : 28, sides: 8, material: "fabric.canvas:D8D0B8")
            rig.add(canvas, Xform(translation: hc + V3(0, 0, 0.004), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "bag", lods: L)
        }
        rig.states = [RigState("rest"), RigState("swing", ["bag": -35])]
        groundAO(&rig, height: 0.15, floor: 0.55)
        return rig
    }
}
