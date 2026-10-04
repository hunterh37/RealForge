import simd
import Foundation

/// Walnut executive double-pedestal desk, 180 x 90 x 75 cm: 40 mm top with a solid walnut edge band and
/// a tooled leather writing inlay, two veneered pedestals on recessed dark plinths (left: three box
/// drawers; right: a box drawer over a file drawer with hanging files), solid brass bar pulls and a
/// full-width modesty panel. Drawers face +Z (the sitting side) and run on concealed slides.
public struct ExecutiveDesk: RealArticulated {
    public static let id = "executive-desk"
    public static let summary = "Walnut executive desk: edge-banded top with leather inlay, twin pedestals with brass-pulled drawers and a file drawer, modesty panel."
    public static let tags = ["prop", "office", "furniture", "wood", "articulated"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20, distance: 1.1, studio: true)

    public var width: Float = 1.8
    public var depth: Float = 0.9
    public var height: Float = 0.75
    public var veneer: MaterialKey = "wood.veneer-walnut"
    public var edge: MaterialKey = "wood.walnut"
    public var leather: MaterialKey = "leather.black"
    public var pulls: MaterialKey = "metal.brass"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [8])
        let W = width, D = depth, H = height
        let topT: Float = 0.04, side: Float = 0.019, front: Float = 0.02, plinth: Float = 0.06
        let pedW: Float = 0.45, overhang: Float = 0.025
        let liner: MaterialKey = "wood.veneer-oak"
        let shadow: MaterialKey = "metal.powdercoat:1A1715"
        let underTop = H - topT
        let pedD = D - 2 * overhang
        let zFront = D / 2 - overhang               // pedestal front plane (drawer fronts' face)
        let zCase = zFront - front                  // carcass front edge behind the fronts
        let caseD = pedD - front
        let caseZ = zCase - caseD / 2
        let stackLo = plinth + 0.012, stackHi = underTop - 0.02   // under-top rail
        let reveal: Float = 0.003
        let pedX: [Float] = [-W / 2 + overhang + pedW / 2, W / 2 - overhang - pedW / 2]

        func rbox(_ size: V3, _ c: V3, _ mat: MaterialKey, r: Float = 0.003, seg: Int = 1) -> (Surface, Xform) {
            (Prim.roundedBox(size, radius: r, bevelSegments: seg, material: mat), Xform(translation: c))
        }

        for l in 0..<2 {
            var m = Model(name: Self.id)
            func add(_ b: (Surface, Xform)) { m.add(b.0, b.1) }
            // Top: solid walnut band all round, veneered field, leather inlay set flush.
            add(rbox(V3(W, topT, D), V3(0, H - topT / 2, 0), edge, r: 0.008, seg: l == 0 ? 2 : 1))
            add(rbox(V3(W - 0.06, 0.002, D - 0.06), V3(0, H - 0.0006, 0), veneer, r: 0.0008, seg: 1))
            let inlay = V3(0.95, 0.002, 0.52)
            add(rbox(inlay, V3(0, H + 0.0002, D / 2 - 0.06 - inlay.z / 2), leather, r: 0.0008, seg: 1))
            if l == 0 {
                // Tooled border on the leather: a thin brass-gilt line.
                let ix = inlay.x / 2 - 0.018, iz = inlay.z / 2 - 0.018, cz = D / 2 - 0.06 - inlay.z / 2
                for (sz, len, along) in [(V3(0, 0, iz), ix * 2, true), (V3(0, 0, -iz), ix * 2, true), (V3(ix, 0, 0), iz * 2, false), (V3(-ix, 0, 0), iz * 2, false)] {
                    m.add(cuboid(along ? V3(len, 0.0006, 0.0015) : V3(0.0015, 0.0006, len), material: "metal.brass-aged"),
                          Xform(translation: V3(0, H + 0.0012, cz) + sz))
                }
            }
            for (pi, px) in pedX.enumerated() {
                // Carcass: two sides, back, under-top rail, bottom; dark plinth set back 30 mm.
                for sx: Float in [-1, 1] {
                    add(rbox(V3(side, underTop - plinth, caseD), V3(px + sx * (pedW / 2 - side / 2), plinth + (underTop - plinth) / 2, caseZ), veneer, r: 0.003))
                    // Exposed front edge band of the side between the drawer fronts.
                    add(rbox(V3(side, underTop - plinth, front), V3(px + sx * (pedW / 2 - side / 2), plinth + (underTop - plinth) / 2, zCase + front / 2 - 0.004), edge, r: 0.003))
                }
                add(rbox(V3(pedW - 2 * side, underTop - plinth, 0.012), V3(px, plinth + (underTop - plinth) / 2, -pedD / 2 + 0.006), veneer, r: 0.002, seg: 1))
                add(rbox(V3(pedW - 2 * side, 0.02, pedD), V3(px, underTop - 0.01, 0), veneer, r: 0.002, seg: 1))
                add(rbox(V3(pedW - 2 * side, 0.018, caseD), V3(px, plinth + 0.009, caseZ), veneer, r: 0.002, seg: 1))
                add(rbox(V3(pedW - 0.03, plinth, pedD - 0.04), V3(px, plinth / 2, -0.02), shadow, r: 0.003))
                for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                    add(rbox(V3(0.03, 0.004, 0.03), V3(px + sx * (pedW / 2 - 0.04), 0.002, sz * (pedD / 2 - 0.06)), "rubber", r: 0.0015, seg: 1))
                }}
                // Dark cavity behind the drawers.
                var cav = Prim.roundedBox(V3(pedW - 2 * side - 0.002, stackHi - stackLo, caseD - 0.014), radius: 0.003, bevelSegments: 1, material: shadow).flipped()
                cav = cav.transformed(Xform(translation: V3(px, (stackLo + stackHi) / 2, caseZ + 0.007)))
                m.add(cav)
                _ = pi
            }
            // Modesty panel between the pedestals, set back from the front, with a walnut edge band.
            let mw = pedX[1] - pedX[0] - pedW + 0.01, mh: Float = 0.42
            add(rbox(V3(mw, mh, 0.02), V3(0, underTop - mh / 2, -D / 2 + 0.09), veneer, r: 0.003))
            add(rbox(V3(mw, 0.02, 0.022), V3(0, underTop - mh + 0.01, -D / 2 + 0.09), edge, r: 0.004))
            // Kneehole apron rail under the top front.
            add(rbox(V3(mw, 0.05, 0.02), V3(0, underTop - 0.025, zFront - 0.03), veneer, r: 0.003))
            rig.base[l] = m
        }

        // Drawers: (pedestal, height fraction, name, travel). Fronts top to bottom.
        let stack = stackHi - stackLo
        let layout: [(Int, [Float], [String])] = [(0, [1 / 3, 1 / 3, 1 / 3], ["left-top", "left-middle", "left-bottom"]),
                                                   (1, [1 / 3, 2 / 3], ["right-top", "file"])]
        let travel: Float = 0.42
        for (pi, fracs, names) in layout {
            let px = pedX[pi]
            var yTop = stackHi
            for (k, frac) in fracs.enumerated() {
                let name = names[k]
                let ph = stack * frac
                let y0 = yTop - ph
                yTop = y0
                let fh = ph - reveal, fw = pedW - 2 * side - 2 * reveal + 2 * side * 0   // fronts inset between the side bands
                let cy = y0 + ph / 2 - reveal / 2
                let zc = zFront - front / 2
                rig.part(name, pivot: V3(px, cy, zc), joint: .slide(axis: V3(0, 0, 1), 0...travel, duration: 0.6))
                rig.add(Prim.roundedBox(V3(fw, fh, front), radius: 0.0035, bevelSegments: 2, material: veneer),
                        Xform(translation: V3(px, cy, zc)).jittered(&rng, deg: 0.03, offset: 0.0002), to: name)
                // Raised field moulding line: a slim inset panel edge.
                rig.add(Prim.roundedBox(V3(fw - 0.05, fh - 0.05, 0.003), radius: 0.0012, bevelSegments: 1, material: veneer),
                        Xform(translation: V3(px, cy, zFront + 0.001)), to: name, lods: 0...0)
                // Brass bar pull centered in the upper part (file drawer: upper third).
                let py = name == "file" ? cy + fh * 0.3 : cy
                rig.add(barHandle(length: 0.128, standoff: 0.03, radius: 0.0055, overhang: 0.022, material: pulls),
                        Xform(translation: V3(px, py, zFront)), to: name)
                for x in [-0.064, 0.064] as [Float] {
                    rig.add(Prim.cylinder(radius: 0.009, height: 0.003, bevel: 0.001, segments: 10, bevelSegments: 1, material: pulls),
                            Xform(translation: V3(px + x, py, zFront), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: name, lods: 0...0)
                }
                // Drawer box: oak sides, back, bottom.
                let bw = pedW - 2 * side - 0.03, bh = ph - 0.045, depthIn = caseD - 0.04
                let zb = zc - front / 2 - depthIn / 2, yb = y0 + 0.012
                for sx: Float in [-1, 1] {
                    rig.add(Prim.roundedBox(V3(0.012, bh, depthIn), radius: 0.002, bevelSegments: 1, material: liner),
                            Xform(translation: V3(px + sx * bw / 2, yb + bh / 2, zb)), to: name)
                }
                rig.add(Prim.roundedBox(V3(bw, 0.008, depthIn), radius: 0.002, bevelSegments: 1, material: liner), Xform(translation: V3(px, yb + 0.004, zb)), to: name)
                rig.add(Prim.roundedBox(V3(bw, bh, 0.012), radius: 0.002, bevelSegments: 1, material: liner),
                        Xform(translation: V3(px, yb + bh / 2, zc - front / 2 - depthIn + 0.006)), to: name)
                rig.add(Prim.roundedBox(V3(bw, bh, 0.01), radius: 0.002, bevelSegments: 1, material: liner),
                        Xform(translation: V3(px, yb + bh / 2, zc - front / 2 - 0.005)), to: name, lods: 0...0)
                if name == "file" {
                    var z = zc - front / 2 - 0.05, f = 0
                    while z > zc - front / 2 - depthIn + 0.05 && f < 14 {
                        let tint: UInt32 = rng.chance(0.75) ? 0x5E7A3E : 0xC2A86A
                        let fh2 = bh - 0.03 - rng.float(0...0.02), lean = rng.float(-5...5)
                        rig.add(cuboid(V3(bw - 0.03, fh2, 0.006 + rng.float(0...0.01)), material: "paper.sheet:" + String(format: "%06X", tint)),
                                Xform(translation: V3(px, yb + 0.012 + fh2 / 2, z), rotation: simd_quatf(degrees: lean, axis: V3(1, 0, 0))), to: name, lods: 0...0)
                        rig.add(cuboid(V3(bw + 0.004, 0.006, 0.003), material: "metal.galvanized"), Xform(translation: V3(px, yb + bh + 0.006, z)), to: name, lods: 0...0)
                        z -= rng.float(0.025...0.045); f += 1
                    }
                } else if name == "left-top" {
                    // Notepad and a fountain pen.
                    rig.add(cuboid(V3(0.15, 0.012, 0.21), material: "paper.sheet:F1EFE6"), Xform(translation: V3(px - 0.05, yb + 0.014, zb + 0.08), rotation: simd_quatf(degrees: rng.float(-6...6), axis: .up)), to: name, lods: 0...0)
                    rig.add(Prim.cylinder(radius: 0.0065, height: 0.14, bevel: 0.003, segments: 10, bevelSegments: 1, material: "plastic.gloss:121212"),
                            Xform(translation: V3(px + 0.08, yb + 0.015, zb + 0.15), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)) * simd_quatf(degrees: 8, axis: V3(0, 0, 1))), to: name, lods: 0...0)
                }
            }
        }

        groundAO(&rig, height: 0.1, floor: 0.55)
        rig.states = [RigState("closed"), RigState("drawer-open", ["left-top": 0.3]), RigState("file-open", ["file": 0.38]),
                      RigState("all-open", ["left-top": 0.32, "left-middle": 0.22, "left-bottom": 0.12, "right-top": 0.26, "file": 0.36])]
        return rig
    }
}
