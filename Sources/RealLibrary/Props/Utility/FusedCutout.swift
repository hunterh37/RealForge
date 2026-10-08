import simd
import Foundation

/// 15 kV, 100 A porcelain fused cutout (Type C class) on its NEMA B crossarm bracket: an ANSI 70 gray
/// glazed porcelain body with sheds set 20 degrees off vertical, galvanized mounting band and bracket,
/// bronze upper contact with a hood and latch, bronze lower hinge casting with the trunnion, eye-bolt
/// connectors top and bottom, and the fiberglass fuse tube (the door) with its brass cap, pull ring and
/// the fuse-link leader tail hanging out of the bottom. The door hinges on the trunnion: `open` is the
/// dropped-out position a lineman pulls with a shotgun stick; option `blown` chars the tube end and
/// leaves the burnt leader stub hanging.
public struct FusedCutout: RealArticulated {
    public static let id = "fused-cutout"
    public static let summary = "15 kV 100 A porcelain fused cutout on a NEMA B bracket: glazed body, fiberglass fuse door with pull ring, bronze contacts."
    public static let tags = ["prop", "utility", "electrical", "articulated", "ceramic", "metal"]
    public static let budget = 12000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 60, elevation: 10, distance: 1.1, studio: true)

    /// Lean of the body from vertical, top toward +Z (degrees).
    public var tilt: Float = 20
    /// Door swing when open (degrees).
    public var openAngle: Float = 120
    public var porcelain: MaterialKey = "ceramic.porcelain-gray"
    public var tube: MaterialKey = "plastic.fuse-tube"
    public var casting: MaterialKey = "metal.bronze-cast"
    public var steel: MaterialKey = "metal.galvanized"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 1)
        let T = Xform(translation: V3(0, -0.002, -0.02), rotation: simd_quatf(angle: tilt * .pi / 180, axis: V3(1, 0, 0)))
        func at(_ p: V3) -> V3 { T.rotation.act(p) + T.translation }
        func xf(_ x: Xform) -> Xform { Xform(translation: at(x.translation), rotation: T.rotation * x.rotation) }
        var m = Model(name: Self.id)
        // Porcelain body: core with six sheds, end caps.
        var prof: [V2] = [V2(0, 0.12), V2(0.026, 0.12), V2(0.03, 0.13)]
        for k in 0..<6 {
            let y = 0.15 + Float(k) * 0.052
            prof += [V2(0.028, y), V2(0.047, y + 0.012), V2(0.05, y + 0.018), V2(0.046, y + 0.022), V2(0.029, y + 0.03)]
        }
        prof += [V2(0.03, 0.47), V2(0.026, 0.48), V2(0, 0.48)]
        m.add(Prim.lathe(prof, segments: 32, seamTile: 0.25, material: porcelain), T)
        for y: Float in [0.105, 0.48] {
            m.add(Prim.cylinder(radius: 0.027, height: 0.018, bevel: 0.003, segments: 20, material: "metal.aluminum-cast"), xf(Xform(translation: V3(0, y, 0))))
        }
        // Mounting band at mid body, NEMA B bracket back to the crossarm face.
        m.add(Prim.lathe([V2(0.031, 0.275), V2(0.034, 0.278), V2(0.034, 0.302), V2(0.031, 0.305)], segments: 28, material: steel), T)
        let bandBack = at(V3(0, 0.29, -0.034))
        let armEnd = V3(0, bandBack.y - 0.03, -0.24)
        m.add(Prim.tube([bandBack, (bandBack + armEnd) / 2 + V3(0, 0.02, 0), armEnd], radii: [0.01, 0.01, 0.01], sides: 6, seamTile: 0.1, material: steel))
        m.add(Prim.roundedBox(V3(0.07, 0.16, 0.008), radius: 0.004, bevelSegments: 1, material: steel), Xform(translation: armEnd + V3(0, -0.02, -0.004)))
        m.add(Prim.roundedBox(V3(0.012, 0.05, 0.05), radius: 0.003, bevelSegments: 1, material: steel), Xform(translation: armEnd + V3(0, 0.03, 0.022)))
        for y: Float in [0.03, -0.07] { hexBolt(&m, at: armEnd + V3(0, y, -0.008), normal: V3(0, 0, -1), size: 0.016, material: steel) }
        // Upper contact: casting off the top cap, hood over the tube cap, latch.
        m.add(Prim.roundedBox(V3(0.03, 0.022, 0.12), radius: 0.006, bevelSegments: 2, material: casting), xf(Xform(translation: V3(0, 0.495, 0.055))))
        m.add(Prim.roundedBox(V3(0.05, 0.012, 0.06), radius: 0.004, bevelSegments: 2, material: steel), xf(Xform(translation: V3(0, 0.51, 0.1))))
        m.add(Prim.roundedBox(V3(0.034, 0.03, 0.01), radius: 0.003, bevelSegments: 1, material: casting), xf(Xform(translation: V3(0, 0.49, 0.125))))
        // Lower hinge casting with the trunnion saddle.
        m.add(Prim.roundedBox(V3(0.03, 0.024, 0.11), radius: 0.006, bevelSegments: 2, material: casting), xf(Xform(translation: V3(0, 0.1, 0.05))))
        for s: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.006, 0.04, 0.03), radius: 0.002, bevelSegments: 1, material: casting), xf(Xform(translation: V3(s * 0.024, 0.085, 0.095))))
        }
        // Eye-bolt line connectors on both caps, back side.
        for y: Float in [0.5, 0.095] {
            let c = at(V3(0, y, -0.03))
            m.add(Prim.roundedBox(V3(0.022, 0.026, 0.022), radius: 0.004, bevelSegments: 1, material: casting), Xform(translation: c))
            m.add(Prim.torus(major: 0.008, minor: 0.003, segments: 12, sides: 5, material: casting), Xform(translation: c + V3(0, 0, -0.016), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1))))
        }
        rig.base[0] = m

        // Door: fuse tube on the trunnion, swings forward and down.
        let pivot = at(V3(0, 0.085, 0.095))
        rig.part("door", pivot: pivot, joint: .hinge(axis: T.rotation.act(V3(-1, 0, 0)), -openAngle...0, duration: 0.9), options: 2)
        var door = Model(name: "door")
        door.add(Prim.lathe([V2(0.012, 0.11), V2(0.016, 0.11), V2(0.016, 0.47), V2(0.013, 0.472)], segments: 20, seamTile: 0.2, material: tube))
        door.add(Prim.lathe([V2(0, 0.465), V2(0.0185, 0.465), V2(0.0185, 0.49), V2(0.012, 0.497), V2(0, 0.497)], segments: 20, material: casting))
        door.add(Prim.lathe([V2(0.017, 0.09), V2(0.02, 0.09), V2(0.02, 0.125), V2(0.017, 0.128)], segments: 20, material: casting))
        door.add(Prim.cylinder(radius: 0.006, height: 0.056, bevel: 0.001, segments: 10, material: casting),
                 Xform(translation: V3(-0.028, 0.085, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))))
        door.add(Prim.torus(major: 0.017, minor: 0.0035, segments: 20, sides: 6, material: casting),
                 Xform(translation: V3(0, 0.47, 0.035), rotation: simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))))
        door.add(Prim.roundedBox(V3(0.008, 0.012, 0.022), radius: 0.002, bevelSegments: 1, material: casting), Xform(translation: V3(0, 0.47, 0.018)))
        let doorX = Xform(translation: V3(0, 0, 0.095))
        for s in door.surfaces { rig.add(s, xf(doorX), to: "door", option: 0) }
        // Leader tail out of the bottom (option 0); blown: charred end and short burnt stub (option 1).
        let tail = (0...6).map { i -> V3 in let t = Float(i) / 6; return V3(0.004 * sin(t * 5), 0.09 - t * 0.05, 0.095 + 0.006 * t) }
        rig.add(Prim.tube(tail.map(at), radii: tail.map { _ in 0.0018 }, sides: 5, seamTile: 0.02, material: "metal.tinned-copper"), to: "door", option: 0)
        for s in door.surfaces { rig.add(s, xf(doorX), to: "door", option: 1) }
        rig.add(Prim.lathe([V2(0.0162, 0.11), V2(0.0162, 0.17)], segments: 20, material: "plastic.matte:16120E"), xf(doorX), to: "door", option: 1)
        let stub = (0...3).map { i -> V3 in let t = Float(i) / 3; return V3(0.003 * t, 0.09 - t * 0.02, 0.095) }
        rig.add(Prim.tube(stub.map(at), radii: stub.map { _ in 0.0016 }, sides: 5, seamTile: 0.02, material: "metal.copper-patina"), to: "door", option: 1)
        rig.states = [RigState("closed"), RigState("open", ["door": -openAngle]), RigState("blown-open", ["door": -openAngle], options: ["door": 1])]
        groundAO(&rig, height: 0.05, floor: 0.6)
        return rig
    }
}
