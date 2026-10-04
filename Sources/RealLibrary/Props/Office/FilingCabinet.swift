import simd
import Foundation

/// Four-drawer vertical letter filing cabinet, 46 x 133 x 71 cm: folded steel shell with front stiles and
/// rails, dark interior, toe-kick plinth, overlay drawer fronts with 3 mm reveals, cast pulls and label
/// holders, lock cylinder. Each drawer runs on a full-extension slide (the middle member follows at half
/// travel) and holds hanging files on rails.
public struct FilingCabinet: RealArticulated {
    public static let id = "filing-cabinet"
    public static let summary = "Four-drawer steel filing cabinet: powder-coated shell, overlay fronts with pulls and label holders, hanging files on full-extension slides."
    public static let tags = ["prop", "office", "metal", "furniture", "container"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 12, distance: 1.15, studio: true)

    /// Powder coat (sRGB hex): putty 0xC8C2B4, black 0x2C2D2F, white 0xE2E1DC, grey 0x8E9094.
    public var color: UInt32 = 0xC8C2B4
    public var width: Float = 0.46
    public var height: Float = 1.33
    public var depth: Float = 0.71
    public var drawers = 4
    /// Full-extension travel (m).
    public var travel: Float = 0.56
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [7])
        let paint: MaterialKey = "metal.powdercoat:" + String(format: "%06X", color)
        let liner: MaterialKey = "metal.powdercoat:3A3A3C"
        let alu: MaterialKey = "metal.aluminum-brushed", chrome: MaterialKey = "metal.chrome", dark: MaterialKey = "plastic.black"
        let W = width, H = height, D = depth
        let sheet: Float = 0.012, front: Float = 0.022, stile: Float = 0.02, plinth: Float = 0.07, topT: Float = 0.026
        let zFace = D / 2 - front                 // front plane of the shell
        let stackLo = plinth, stackHi = H - topT
        let pitch = (stackHi - stackLo) / Float(drawers), reveal: Float = 0.003

        func box(_ size: V3, _ c: V3, _ mat: MaterialKey, r: Float = 0.003, seg: Int = 2) -> (Surface, Xform) {
            (Prim.roundedBox(size, radius: r, bevelSegments: seg, material: mat), Xform(translation: c))
        }

        // Shell: sides, top, back, plinth, front stiles and rails; dark liner inside.
        for l in 0..<2 {
            var m = Model(name: Self.id)
            func add(_ b: (Surface, Xform)) { m.add(b.0, b.1) }
            for sx: Float in [-1, 1] {
                add(box(V3(sheet, H - 0.004, D - front), V3(sx * (W / 2 - sheet / 2), H / 2, -front / 2), paint, r: 0.004))
                add(box(V3(stile, stackHi - stackLo, 0.016), V3(sx * (W / 2 - stile / 2), (stackLo + stackHi) / 2, zFace - 0.008), paint, r: 0.003))
            }
            add(box(V3(W, topT, D - front + 0.004), V3(0, H - topT / 2, -front / 2 + 0.002), paint, r: 0.006))
            add(box(V3(W - 2 * sheet, H - plinth, sheet), V3(0, plinth + (H - plinth) / 2, -D / 2 + sheet / 2), paint, r: 0.002, seg: 1))
            // Toe kick: recessed dark plinth with a painted base rail.
            add(box(V3(W - 0.004, plinth - 0.012, D - front - 0.05), V3(0, (plinth - 0.012) / 2 + 0.006, -front / 2 - 0.025), dark, r: 0.002, seg: 1))
            add(box(V3(W, 0.012, D - front), V3(0, plinth - 0.006, -front / 2), paint, r: 0.002, seg: 1))
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                add(box(V3(0.03, 0.008, 0.03), V3(sx * (W / 2 - 0.03), 0.004, sz * (D / 2 - 0.06)), "rubber", r: 0.003, seg: 1))
            }}
            for k in 1..<drawers {
                add(box(V3(W - 2 * stile, 0.012, 0.016), V3(0, stackLo + Float(k) * pitch, zFace - 0.008), paint, r: 0.002, seg: 1))
            }
            // Dark interior so open drawers show a cavity, not a painted wall.
            var cav = Prim.roundedBox(V3(W - 2 * sheet - 0.002, stackHi - stackLo - 0.004, D - front - 0.02), radius: 0.004, bevelSegments: 1, material: liner).flipped()
            cav = cav.transformed(Xform(translation: V3(0, (stackLo + stackHi) / 2, -front / 2 - 0.01)))
            m.add(cav)
            // Lock cylinder on the top rail.
            if l == 0 {
                m.add(Prim.cylinder(radius: 0.011, height: 0.008, bevel: 0.002, segments: 20, material: chrome),
                      Xform(translation: V3(W / 2 - 0.06, H - topT / 2, D / 2 - front + 0.002), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
                m.add(Prim.roundedBox(V3(0.0018, 0.009, 0.002), radius: 0.0006, bevelSegments: 1, material: dark),
                      Xform(translation: V3(W / 2 - 0.06, H - topT / 2, D / 2 - front + 0.0105)))
            }
            rig.base[l] = m
        }

        // Pull: cast aluminum scoop under a lip, with end bosses (along X, face toward +Z).
        let lip = Shape2D.rounded([V2(0, 0), V2(0.0035, 0), V2(0.0035, -0.022), V2(0.024, -0.026), V2(0.026, -0.03), V2(0.0, -0.032)], radius: 0.0012, segments: 2)
        let fw = W - 2 * reveal, depthIn = D - front - 0.06
        for k in 0..<drawers {
            let name = "drawer\(k + 1)"
            let y0 = stackHi - Float(k + 1) * pitch      // drawer 1 is the top one
            let cy = y0 + pitch / 2
            let zc = D / 2 - front / 2
            rig.part(name, pivot: V3(0, cy, zc), joint: .slide(axis: V3(0, 0, 1), 0...travel, duration: 0.7))
            rig.part(name + "-slide", pivot: V3(0, cy, zc), joint: Joint(.prismatic, axis: V3(0, 0, 1), range: 0...travel / 2,
                                                                         mimic: .init(name, ratio: 0.5)))
            let fh = pitch - reveal
            rig.add(Prim.roundedBox(V3(fw, fh, front), radius: 0.004, bevelSegments: 2, material: paint),
                    Xform(translation: V3(0, cy, zc)).jittered(&rng, deg: 0.04, offset: 0.0002), to: name)
            // Pull and label holder centered in the upper third.
            let py = cy + fh * 0.14
            rig.add(Prim.extrude(lip, depth: 0.16, bevel: 0.001, bevelSegments: 1, material: alu),
                    Xform(translation: V3(0, py, D / 2 - 0.001), rotation: simd_quatf(degrees: -90, axis: .up)), to: name)
            for sx: Float in [-1, 1] {
                rig.add(Prim.roundedBox(V3(0.012, 0.034, 0.028), radius: 0.004, bevelSegments: 2, material: alu),
                        Xform(translation: V3(sx * 0.086, py - 0.016, D / 2 + 0.012)), to: name)
            }
            rig.add(Prim.roundedBox(V3(0.15, 0.03, 0.004), radius: 0.0015, bevelSegments: 1, material: dark),
                    Xform(translation: V3(0, py - 0.018, D / 2 + 0.001)), to: name, lods: 0...0)
            let ly = py + 0.05
            rig.add(Prim.roundedBox(V3(0.082, 0.04, 0.003), radius: 0.001, bevelSegments: 1, material: chrome),
                    Xform(translation: V3(0, ly, D / 2 + 0.0015)), to: name)
            rig.add(Prim.roundedBox(V3(0.072, 0.03, 0.002), radius: 0.0008, bevelSegments: 1, material: "paper.sheet"),
                    Xform(translation: V3(0, ly, D / 2 + 0.0028)), to: name, lods: 0...0)
            // Drawer box behind the front: sides, back, bottom; hanging rails on the sides.
            let bw = W - 2 * sheet - 0.034, bh = pitch - 0.07, zb = zc - front / 2 - depthIn / 2
            for sx: Float in [-1, 1] {
                rig.add(Prim.roundedBox(V3(0.008, bh, depthIn), radius: 0.002, bevelSegments: 1, material: paint),
                        Xform(translation: V3(sx * bw / 2, y0 + 0.02 + bh / 2, zb)), to: name)
                rig.add(Prim.roundedBox(V3(0.012, 0.01, depthIn), radius: 0.002, bevelSegments: 1, material: "metal.galvanized"),
                        Xform(translation: V3(sx * (bw / 2 - 0.002), y0 + 0.02 + bh + 0.005, zb)), to: name)
                // Slide members: drawer member on the box, intermediate member following at half travel.
                rig.add(Prim.roundedBox(V3(0.006, 0.03, depthIn * 0.96), radius: 0.001, bevelSegments: 1, material: "metal.galvanized"),
                        Xform(translation: V3(sx * (bw / 2 + 0.006), y0 + 0.05, zb)), to: name, lods: 0...0)
                rig.add(Prim.roundedBox(V3(0.004, 0.036, depthIn * 0.96), radius: 0.001, bevelSegments: 1, material: "metal.galvanized"),
                        Xform(translation: V3(sx * (bw / 2 + 0.011), y0 + 0.05, zb)), to: name + "-slide", lods: 0...0)
            }
            rig.add(Prim.roundedBox(V3(bw, 0.008, depthIn), radius: 0.002, bevelSegments: 1, material: paint),
                    Xform(translation: V3(0, y0 + 0.024, zb)), to: name)
            rig.add(Prim.roundedBox(V3(bw, bh, 0.008), radius: 0.002, bevelSegments: 1, material: paint),
                    Xform(translation: V3(0, y0 + 0.02 + bh / 2, zc - front / 2 - depthIn + 0.004)), to: name)
            // Hanging files: folder bodies with hooks on the rails, colored index tabs.
            var z = zc - front / 2 - 0.05
            var f = 0
            let fileColors: [UInt32] = [0x5E7A3E, 0x6E8A4A, 0x5A7038, 0xC2A86A, 0x4A6A8A]
            while z > zc - front / 2 - depthIn + 0.06 && f < 14 {
                let tint = rng.chance(0.8) ? fileColors[0] : fileColors[3]
                let mat: MaterialKey = "paper.sheet:" + String(format: "%06X", tint)
                let fh2 = bh - 0.03 - rng.float(0...0.02)
                let lean = rng.float(-5...5)
                let x = Xform(translation: V3(0, y0 + 0.03 + fh2 / 2, z), rotation: simd_quatf(degrees: lean, axis: V3(1, 0, 0)))
                rig.add(cuboid(V3(bw - 0.03, fh2, 0.006 + rng.float(0...0.012)), material: mat), x, to: name, lods: 0...0)
                rig.add(cuboid(V3(bw + 0.004, 0.006, 0.003), material: "metal.galvanized"),
                        Xform(translation: V3(0, y0 + 0.02 + bh + 0.012, z)), to: name, lods: 0...0)
                if rng.chance(0.6) {
                    let tx = rng.float(-bw / 2 + 0.05...bw / 2 - 0.05)
                    rig.add(cuboid(V3(0.05, 0.02, 0.002), material: "plastic.white"),
                            Xform(translation: V3(tx, y0 + 0.03 + fh2 + 0.01, z), rotation: simd_quatf(degrees: lean, axis: V3(1, 0, 0))), to: name, lods: 0...0)
                }
                z -= rng.float(0.025...0.05); f += 1
            }
        }
        groundAO(&rig, height: 0.12, floor: 0.55)
        rig.states = [RigState("closed")]
            + (1...drawers).map { RigState("drawer\($0)-open", ["drawer\($0)": travel * 0.92]) }
            + [RigState("ajar", ["drawer2": 0.08])]
        return rig
    }
}
