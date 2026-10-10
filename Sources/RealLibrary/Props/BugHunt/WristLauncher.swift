import simd
import Foundation

/// Watch-style net launcher: a 44 mm brass case with a domed crystal over an ivory dial, a short
/// knurled brass barrel (`muzzle`) across the top, a side push button (`button`) and a stitched tan
/// leather strap with a brass buckle, closed around an invisible wrist.
public struct WristLauncher: RealArticulated {
    public static let id = "wrist-launcher"
    public static let summary = "Wrist net launcher: brass watch case, dial, knurled barrel (muzzle), push button (button), leather strap; articulated."
    public static let tags = ["prop", "tool", "metal", "leather", "antique", "handheld", "articulated"]
    public static let budget = 9_000
    public static let preview = PreviewHint(azimuth: 35, elevation: 30, distance: 1.0, studio: true)

    public var caseDiameter: Float = 0.044
    public var wrist: Float = 0.058
    public var brass: MaterialKey = "metal.brass-aged"
    public var strap: MaterialKey = "leather.tan"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3])
        let rw = wrist / 2, sw: Float = 0.022, st: Float = 0.0035
        let cy = rw + st                          // strap loop centre height (loop axis along X)
        let top = cy + rw + st                    // strap outer top
        let rc = caseDiameter / 2, ch: Float = 0.011
        let caseY = top - 0.001
        rig.part("muzzle", pivot: V3(0, caseY + ch + 0.006, 0), joint: .hinge(axis: V3(0, 0, 1), 0...25, duration: 0.3))
        rig.part("button", pivot: V3(0, caseY + ch * 0.5, rc + 0.003), joint: .slide(axis: V3(0, 0, -1), 0...0.002, duration: 0.1))
        for lod in 0..<2 {
            let L = lod...lod, seg = lod == 0 ? 48 : 20
            // Strap: rectangular section swept around the wrist loop (in the YZ plane, axis X).
            var path: [V3] = []
            for i in 0..<seg { let a = Float(i) / Float(seg) * 2 * .pi; path.append(V3(0, cy + sin(a) * (rw + st / 2), cos(a) * (rw + st / 2))) }
            let section = Shape2D.roundedRect(sw, st, radius: 0.001, segments: 2)
            rig.base[lod].add(Prim.sweep(section, along: path, up: V3(1, 0, 0), closedPath: true, caps: false, material: strap))
            if lod == 0 {
                for side: Float in [1, -1] {
                    var sp: [V3] = []
                    for i in 0..<seg { let a = Float(i) / Float(seg) * 2 * .pi; sp.append(V3(side * (sw / 2 - 0.0022), cy + sin(a) * (rw + st + 0.0002), cos(a) * (rw + st + 0.0002))) }
                    rig.base[lod].add(stitches(along: sp, normal: { p in simd_normalize(V3(0, p.y - cy, p.z)) }, pitch: 0.003, material: "thread.white:D8CCAA"))
                }
            }
            // Buckle under the wrist.
            rig.base[lod].add(Prim.roundedBox(V3(sw + 0.006, 0.003, 0.016), radius: 0.001, bevelSegments: 2, material: brass), Xform(translation: V3(0, 0.0015, 0)))
            // Case: lathe with bezel, crystal and dial.
            let caseProf: [V2] = [V2(0, 0), V2(rc * 0.92, 0), V2(rc, 0.002), V2(rc, ch - 0.002), V2(rc * 0.96, ch), V2(rc * 0.82, ch + 0.0008), V2(rc * 0.80, ch - 0.001), V2(0, ch - 0.001)]
            rig.base[lod].add(Prim.lathe(caseProf, segments: seg, seamTile: 0.02, material: brass), Xform(translation: V3(0, caseY, 0)))
            rig.base[lod].add(Prim.cylinder(radius: rc * 0.8, height: 0.0006, bevel: 0.0001, segments: seg, material: "paper.sheet:EFE4C8"), Xform(translation: V3(0, caseY + ch - 0.0018, 0)))
            let dome: [V2] = (0...8).map { i in let a = Float(i) / 8 * .pi / 2; return V2(rc * 0.81 * cos(a), ch - 0.0012 + 0.0025 * sin(a)) }
            rig.base[lod].add(Prim.lathe(dome, segments: seg, seamTile: 0.02, material: "glass.gauge-lens"), Xform(translation: V3(0, caseY, 0)))
            if lod == 0 {
                // Hour ticks and hands.
                for k in 0..<12 {
                    let a = Float(k) / 12 * 2 * .pi
                    rig.base[0].add(cuboid(V3(0.0008, 0.0002, 0.003), material: "metal.painted:1A1A1A"),
                                    Xform(translation: V3(sin(a) * rc * 0.66, caseY + ch - 0.0011, cos(a) * rc * 0.66), rotation: simd_quatf(angle: a, axis: .up)))
                }
                rig.base[0].add(cuboid(V3(0.0012, 0.0002, rc * 0.5), material: "metal.painted:1A1A1A"), Xform(translation: V3(0.002, caseY + ch - 0.0009, rc * 0.2), rotation: simd_quatf(degrees: 20, axis: .up)))
                rig.base[0].add(cuboid(V3(0.0009, 0.0002, rc * 0.7), material: "metal.painted:8A1A12"), Xform(translation: V3(-0.004, caseY + ch - 0.0008, -0.004), rotation: simd_quatf(degrees: -50, axis: .up)))
            }
            // Lugs to the strap.
            for z: Float in [-1, 1] {
                rig.base[lod].add(Prim.roundedBox(V3(sw + 0.002, 0.004, 0.008), radius: 0.0012, bevelSegments: 2, material: brass), Xform(translation: V3(0, caseY + 0.002, z * (rc + 0.002))))
            }
            // Muzzle: knurled barrel on a saddle across the case top (along X).
            let barrelY = caseY + ch + 0.006
            rig.add(Prim.roundedBox(V3(0.012, 0.005, 0.010), radius: 0.0015, bevelSegments: 2, material: brass), Xform(translation: V3(0, caseY + ch + 0.003, 0)), to: "muzzle", lods: L)
            let bprof: [(Float, Float)] = [(0, 0), (0.0062, 0), (0.0062, 0.004), (0.0055, 0.0045), (0.0055, 0.030), (0.0065, 0.031), (0.0065, 0.036), (0.0045, 0.036), (0.0045, 0.030), (0, 0.030)]
            rig.add(turned(bprof, segments: lod == 0 ? 24 : 12, material: lod == 0 ? "metal.knurl-chrome:B8954E" : brass), Xform(translation: V3(-0.018, barrelY, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "muzzle", lods: L)
            rig.add(Prim.cylinder(radius: 0.0044, height: 0.001, bevel: 0.0002, segments: 16, material: "metal.painted:141210"), Xform(translation: V3(0.0175, barrelY, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "muzzle", lods: L)
            // Push button on the side (+Z), with crown stem.
            let btn: [(Float, Float)] = [(0, 0), (0.0018, 0), (0.0018, 0.003), (0.0032, 0.0032), (0.0034, 0.0052), (0.0028, 0.006), (0, 0.006)]
            rig.add(turned(btn, segments: lod == 0 ? 20 : 10, material: "metal.brass"), Xform(translation: V3(0, caseY + ch * 0.5, rc - 0.0005), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "button", lods: L)
        }
        rig.states = [RigState("rest"), RigState("pressed", ["button": 0.002]), RigState("aimed", ["muzzle": 15])]
        groundAO(&rig, height: 0.05, floor: 0.6)
        return rig
    }
}
