import simd
import Foundation

/// Single-man fiberglass aerial bucket (platform) as hung on the jib of an insulated aerial device, at 1:1.
/// Outer shell 0.6 x 0.6 m, 1.07 m deep, white gelcoat with a rolled lip, dark polyethylene liner, molded
/// step on +Z, galvanized boom mounting plate on -Z. The upper control console hangs on the -Z rim: a
/// single-handle `boomStick` (pitch, with child `boomStickSide` for the second axis), `rotateStick`,
/// `jibLever`, red push `estop`, `tool-power` toggle and `horn` button. Floor at y = 0 (inside floor 0.07).
public struct AerialBucket: RealArticulated {
    public static let id = "aerial-bucket"
    public static let summary = "Fiberglass one-man aerial bucket with liner, step, mount plate and upper console: boom stick, rotate stick, jib lever, e-stop, tool power."
    public static let tags = ["prop", "vehicle", "utility", "electrical", "plastic", "articulated"]
    public static let budget = 9_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 200, elevation: 22, distance: 1.0, studio: true)

    /// Floor of the bucket interior where the lineman stands (asset space, rest pose).
    public static let floorPoint = V3(0, 0.07, 0)
    /// Center of the upper control console top plate (asset space, rest pose).
    public static let consolePoint = V3(0, 1.2, -0.19)

    /// Shell gelcoat.
    public var shell: MaterialKey = "fiberglass.bucket"
    /// Liner plastic.
    public var liner: MaterialKey = "plastic.matte:3A3D40"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [4])
        for l in 0..<2 {
            for s in VK.bucket(.zero, lod: l, shell: shell, liner: liner) { rig.base[l].add(s) }
            for s in VK.consoleHousing(.zero, lod: l) { rig.base[l].add(s) }
        }
        let top: Float = 1.198
        let black: MaterialKey = "rubber.plate"
        // Boots for the sticks.
        for (x, z) in [(Float(-0.12), Float(-0.16)), (0.0, -0.16), (0.12, -0.21)] {
            rig.base[0].add(HK.cyl(r: 0.022, len: 0.02, at: V3(x, top + 0.01, z), axis: .up, mat: black, seg: 12, bevel: 0.006))
        }
        // Single-handle boom stick: two axes (pitch then side), black grip with a trigger interlock.
        rig.part("boomStick", pivot: V3(-0.12, top + 0.01, -0.16), joint: .hinge(axis: V3(1, 0, 0), -20...20, duration: 0.4))
        rig.part("boomStickSide", parent: "boomStick", pivot: V3(-0.12, top + 0.01, -0.16), joint: .hinge(axis: V3(0, 0, 1), -20...20, duration: 0.4))
        rig.add(HK.cyl(r: 0.007, len: 0.07, at: V3(-0.12, top + 0.045, -0.16), axis: .up, mat: "metal.chrome", seg: 8), to: "boomStickSide")
        rig.add(HK.cyl(r: 0.017, len: 0.09, at: V3(-0.12, top + 0.12, -0.16), axis: .up, mat: "rubber.plate", seg: 12, bevel: 0.008), to: "boomStickSide")
        rig.add(HK.box(V3(0.012, 0.03, 0.012), V3(-0.12, top + 0.11, -0.14), "plastic.yellow:D9A514", r: 0.003, seg: 1), to: "boomStickSide", lods: 0...0)
        // Rotation stick (left-right) and jib lever (fore-aft).
        rig.part("rotateStick", pivot: V3(0, top + 0.01, -0.16), joint: .hinge(axis: V3(0, 0, 1), -20...20, duration: 0.4))
        rig.add(HK.cyl(r: 0.006, len: 0.08, at: V3(0, top + 0.05, -0.16), axis: .up, mat: "metal.chrome", seg: 8), to: "rotateStick")
        rig.add(Prim.cubeSphere(subdivisions: 3, material: "plastic.black") { $0 * 0.016 }, Xform(translation: V3(0, top + 0.1, -0.16)), to: "rotateStick")
        rig.part("jibLever", pivot: V3(0.12, top + 0.01, -0.21), joint: .hinge(axis: V3(1, 0, 0), -25...25, duration: 0.4))
        rig.add(HK.box(V3(0.012, 0.09, 0.008), V3(0.12, top + 0.055, -0.21), "metal.chrome", r: 0.003, seg: 1), to: "jibLever")
        rig.add(HK.box(V3(0.03, 0.022, 0.022), V3(0.12, top + 0.105, -0.21), "plastic.black", r: 0.008, seg: 1), to: "jibLever")
        // Red mushroom e-stop on a yellow collar.
        rig.base[0].add(HK.cyl(r: 0.03, len: 0.012, at: V3(0.17, top + 0.006, -0.11), axis: .up, mat: "plastic.yellow:D9A514", seg: 16, bevel: 0.003))
        rig.base[1].add(HK.cyl(r: 0.03, len: 0.012, at: V3(0.17, top + 0.006, -0.11), axis: .up, mat: "plastic.yellow:D9A514", seg: 8, bevel: 0.003))
        rig.part("estop", pivot: V3(0.17, top + 0.03, -0.11), joint: .slide(axis: V3(0, -1, 0), 0...0.012, duration: 0.15))
        rig.add(HK.cyl(r: 0.01, len: 0.02, at: V3(0.17, top + 0.02, -0.11), axis: .up, mat: "plastic.black", seg: 10), to: "estop")
        rig.add(Prim.lathe([V2(0, 0), V2(0.024, 0), V2(0.026, 0.006), V2(0.022, 0.014), V2(0, 0.017)], segments: 18, material: "plastic.gloss:B81E18"),
                Xform(translation: V3(0.17, top + 0.028, -0.11)), to: "estop")
        // Tool power toggle and horn button.
        rig.part("tool-power", pivot: V3(0.07, top + 0.008, -0.10), joint: .hinge(axis: V3(1, 0, 0), -25...25, duration: 0.2))
        rig.add(HK.cyl(r: 0.004, len: 0.035, at: V3(0.07, top + 0.025, -0.10), axis: .up, mat: "metal.chrome", seg: 8), to: "tool-power")
        rig.base[0].add(HK.cyl(r: 0.011, len: 0.008, at: V3(0.07, top + 0.004, -0.10), axis: .up, mat: "metal.chrome", seg: 12))
        rig.part("horn", pivot: V3(-0.03, top + 0.01, -0.10), joint: .slide(axis: V3(0, -1, 0), 0...0.005, duration: 0.1))
        rig.add(HK.cyl(r: 0.012, len: 0.012, at: V3(-0.03, top + 0.006, -0.10), axis: .up, mat: "plastic.black", seg: 12, bevel: 0.003), to: "horn")
        groundAO(&rig, height: 0.1)
        rig.states = [
            RigState("idle"),
            RigState("operating", ["boomStick": 15, "boomStickSide": -8, "tool-power": 25]),
            RigState("estop", ["estop": 0.012, "tool-power": -25]),
        ]
        return rig
    }
}
