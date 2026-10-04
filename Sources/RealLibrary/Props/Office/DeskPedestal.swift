import simd
import Foundation

/// Mobile under-desk pedestal (Bisley / Steelcase class), 42 x 58 x 55 cm: folded powder-coated steel
/// carcass on four hidden casters behind a recessed dark plinth, three overlay drawer fronts with 3 mm
/// reveals (two box drawers, the top one with a black pencil tray, and a file drawer with hanging
/// files), full-width aluminum lip pulls, a lock cylinder and an optional upholstered cushion top.
public struct DeskPedestal: RealArticulated {
    public static let id = "desk-pedestal"
    public static let summary = "Mobile steel desk pedestal: powder-coated carcass on hidden casters, two box drawers with pencil tray, file drawer, lip pulls and lock."
    public static let tags = ["prop", "office", "furniture", "metal", "container", "articulated"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 34, elevation: 16, distance: 1.0, studio: true)

    /// Powder coat (sRGB hex): white 0xE4E3DE, silver 0xB9BBBD, anthracite 0x3B3D40.
    public var color: UInt32 = 0xE4E3DE
    public var width: Float = 0.42
    public var height: Float = 0.58
    public var depth: Float = 0.55
    /// Fabric cushion on top (seat pedestal).
    public var cushion = false
    public var cushionColor: UInt32 = 0x4A5560
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [6])
        let paint: MaterialKey = "metal.powdercoat:" + String(format: "%06X", color)
        let liner: MaterialKey = "metal.powdercoat:2E2F31"
        let alu: MaterialKey = "metal.aluminum-brushed", dark: MaterialKey = "plastic.black"
        let W = width, H = height, D = depth
        let sheet: Float = 0.01, front: Float = 0.02, plinth: Float = 0.032, topT: Float = 0.022
        let zFace = D / 2 - front
        let stackLo = plinth, stackHi = H - topT
        let reveal: Float = 0.003
        // Drawer heights as fractions of the stack: box, box, file (top to bottom).
        let fractions: [Float] = [0.235, 0.235, 0.53]
        let stack = stackHi - stackLo

        func rbox(_ size: V3, _ c: V3, _ mat: MaterialKey, r: Float = 0.003, seg: Int = 2) -> (Surface, Xform) {
            (Prim.roundedBox(size, radius: r, bevelSegments: seg, material: mat), Xform(translation: c))
        }

        for l in 0..<2 {
            var m = Model(name: Self.id)
            func add(_ b: (Surface, Xform)) { m.add(b.0, b.1) }
            // Carcass: sides run full depth to the front plane, top overhangs the fronts by 2 mm.
            for sx: Float in [-1, 1] {
                add(rbox(V3(sheet, H - plinth - topT + 0.004, D - front), V3(sx * (W / 2 - sheet / 2), plinth + (H - plinth - topT) / 2, -front / 2), paint, r: 0.003))
                // Side skirt down to the floor gap.
                add(rbox(V3(sheet, plinth - 0.012, D - front - 0.01), V3(sx * (W / 2 - sheet / 2), plinth / 2 + 0.006, -front / 2 - 0.005), paint, r: 0.002, seg: 1))
            }
            add(rbox(V3(W, topT, D + 0.002), V3(0, H - topT / 2, 0.001), paint, r: 0.005))
            add(rbox(V3(W - 2 * sheet, H - plinth, sheet), V3(0, plinth + (H - plinth) / 2, -D / 2 + sheet / 2), paint, r: 0.002, seg: 1))
            // Recessed black plinth hiding the casters.
            add(rbox(V3(W - 2 * sheet - 0.004, plinth - 0.01, D - front - 0.06), V3(0, plinth / 2 + 0.006, -front / 2 - 0.02), dark, r: 0.002, seg: 1))
            add(rbox(V3(W - 0.002, 0.01, D - front - 0.004), V3(0, plinth - 0.005, -front / 2 - 0.002), paint, r: 0.002, seg: 1))
            // Dark interior.
            var cav = Prim.roundedBox(V3(W - 2 * sheet - 0.002, stack - 0.004, D - front - 0.02), radius: 0.004, bevelSegments: 1, material: liner).flipped()
            cav = cav.transformed(Xform(translation: V3(0, (stackLo + stackHi) / 2, -front / 2 - 0.01)))
            m.add(cav)
            // Hidden twin-wheel casters, visible only low down.
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                let p = V3(sx * (W / 2 - 0.06), 0, sz * (D / 2 - 0.08))
                if l == 0 {
                    for side: Float in [-1, 1] {
                        m.add(Prim.cylinder(radius: 0.0125, height: 0.009, bevel: 0.003, segments: 14, bevelSegments: 2, material: dark),
                              Xform(translation: p + V3(side * 0.0055 + 0.0045 * side, 0.0125, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
                    }
                    m.add(Prim.roundedBox(V3(0.012, 0.022, 0.026), radius: 0.003, bevelSegments: 1, material: dark), Xform(translation: p + V3(0, 0.022, -0.004)))
                } else {
                    m.add(cuboid(V3(0.024, 0.03, 0.026), material: dark), Xform(translation: p + V3(0, 0.015, 0)))
                }
            }}
            if cushion {
                let c = Prim.superellipsoid(V3(W - 0.01, 0.05, D - 0.03), exponent: 5, subdivisions: l == 0 ? 8 : 4,
                                            material: "fabric.upholstery:" + String(format: "%06X", cushionColor))
                m.add(c, Xform(translation: V3(0, H + 0.022, 0)))
            }
            rig.base[l] = m
        }

        // Full-width lip pull: an aluminum channel along the front's top edge (profile in YZ, along X).
        let lip = Shape2D.rounded([V2(0, 0.004), V2(0.024, 0.004), V2(0.024, -0.0), V2(0.004, -0.0), V2(0.004, -0.018), V2(0.0, -0.018)],
                                  radius: 0.0012, segments: 2)
        let fw = W - 2 * reveal
        var yTop = stackHi
        let names = ["top", "box", "file"]
        let travel: [Float] = [0.4, 0.4, 0.44]
        for (k, frac) in fractions.enumerated() {
            let name = names[k]
            let ph = stack * frac
            let y0 = yTop - ph
            yTop = y0
            let fh = ph - reveal
            let cy = y0 + ph / 2 - reveal / 2
            let zc = D / 2 - front / 2
            rig.part(name, pivot: V3(0, cy, zc), joint: .slide(axis: V3(0, 0, 1), 0...travel[k], duration: 0.6))
            // Front panel: lower part steel, with the aluminum lip forming the top 22 mm.
            rig.add(Prim.roundedBox(V3(fw, fh - 0.022, front), radius: 0.004, bevelSegments: 2, material: paint),
                    Xform(translation: V3(0, cy - 0.011, zc)).jittered(&rng, deg: 0.03, offset: 0.0002), to: name)
            let lipX = Xform(translation: V3(0, cy + fh / 2 - 0.004, D / 2 - 0.024), rotation: simd_quatf(degrees: -90, axis: .up))
            rig.add(Prim.extrude(lip, depth: fw - 0.002, bevel: 0.0008, bevelSegments: 1, material: alu), lipX, to: name)
            // Dark grip recess behind the lip.
            rig.add(cuboid(V3(fw - 0.006, 0.018, 0.004), material: dark), Xform(translation: V3(0, cy + fh / 2 - 0.013, D / 2 - 0.022)), to: name)
            // Drawer box.
            let bw = W - 2 * sheet - 0.03, bh = ph - (k == 2 ? 0.05 : 0.035), depthIn = D - front - 0.05
            let zb = zc - front / 2 - depthIn / 2, yb = y0 + 0.012
            for sx: Float in [-1, 1] {
                rig.add(Prim.roundedBox(V3(0.006, bh, depthIn), radius: 0.002, bevelSegments: 1, material: liner),
                        Xform(translation: V3(sx * bw / 2, yb + bh / 2, zb)), to: name)
                rig.add(Prim.roundedBox(V3(0.006, 0.026, depthIn * 0.96), radius: 0.001, bevelSegments: 1, material: "metal.galvanized"),
                        Xform(translation: V3(sx * (bw / 2 + 0.006), yb + bh * 0.5, zb)), to: name, lods: 0...0)
            }
            rig.add(Prim.roundedBox(V3(bw, 0.006, depthIn), radius: 0.002, bevelSegments: 1, material: liner),
                    Xform(translation: V3(0, yb + 0.003, zb)), to: name)
            rig.add(Prim.roundedBox(V3(bw, bh, 0.006), radius: 0.002, bevelSegments: 1, material: liner),
                    Xform(translation: V3(0, yb + bh / 2, zc - front / 2 - depthIn + 0.003)), to: name)
            let zIn = zc - front / 2 - 0.004
            switch k {
            case 0:
                // Lock cylinder at the top right of the top drawer.
                rig.add(Prim.cylinder(radius: 0.01, height: 0.006, bevel: 0.0015, segments: 20, material: "metal.chrome"),
                        Xform(translation: V3(W / 2 - 0.045, cy - 0.01, D / 2 - 0.001), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: name)
                rig.add(cuboid(V3(0.0018, 0.009, 0.002), material: dark), Xform(translation: V3(W / 2 - 0.045, cy - 0.01, D / 2 + 0.0055)), to: name, lods: 0...0)
                // Molded pencil tray: floor, rim and dividers.
                let tw = bw - 0.012, td = depthIn - 0.01, ty = yb + 0.008, tz = zb
                rig.add(Prim.roundedBox(V3(tw, 0.004, td), radius: 0.0015, bevelSegments: 1, material: dark), Xform(translation: V3(0, ty, tz)), to: name)
                for sx: Float in [-1, 1] {
                    rig.add(Prim.roundedBox(V3(0.004, 0.035, td), radius: 0.0015, bevelSegments: 1, material: dark), Xform(translation: V3(sx * (tw / 2 - 0.002), ty + 0.0175, tz)), to: name, lods: 0...0)
                }
                for z in [tz + td / 2 - 0.002, tz - td / 2 + 0.002, tz + td / 2 - 0.09] {
                    rig.add(Prim.roundedBox(V3(tw, 0.035, 0.004), radius: 0.0015, bevelSegments: 1, material: dark), Xform(translation: V3(0, ty + 0.0175, z)), to: name, lods: 0...0)
                }
                for x in [-tw / 6, tw / 6] {
                    rig.add(Prim.roundedBox(V3(0.004, 0.03, td - 0.09), radius: 0.0015, bevelSegments: 1, material: dark), Xform(translation: V3(x, ty + 0.015, tz - 0.045)), to: name, lods: 0...0)
                }
                // Pens and a sticky-note pad in the tray.
                for i in 0..<3 {
                    let x = -tw / 3 + rng.float(-0.02...0.02) + Float(i) * 0.012
                    rig.add(Prim.cylinder(radius: 0.0045, height: 0.14, bevel: 0.002, segments: 8, bevelSegments: 1,
                                          material: i == 1 ? "plastic.gloss:1F3E8C" : "plastic.matte:202020"),
                            Xform(translation: V3(x, ty + 0.0065, tz - 0.12), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)) * simd_quatf(degrees: rng.float(-4...4), axis: V3(0, 0, 1))), to: name, lods: 0...0)
                }
                rig.add(cuboid(V3(0.076, 0.012, 0.076), material: "paper.sheet:F2E27A"), Xform(translation: V3(tw / 4, ty + 0.008, tz - 0.06), rotation: simd_quatf(degrees: rng.float(-8...8), axis: .up)), to: name, lods: 0...0)
                rig.add(cuboid(V3(0.08, 0.004, 0.05), material: "paper.sheet:F2F0EA"), Xform(translation: V3(0, ty + 0.004, zIn - 0.045)), to: name, lods: 0...0)
            case 1:
                // A ream of paper and a stapler box.
                rig.add(cuboid(V3(0.21, 0.05, 0.297), material: "paper.sheet:F4F3EE"), Xform(translation: V3(-0.06, yb + 0.031, zb + 0.05), rotation: simd_quatf(degrees: rng.float(-5...5), axis: .up)), to: name, lods: 0...0)
                rig.add(Prim.roundedBox(V3(0.07, 0.045, 0.16), radius: 0.008, bevelSegments: 2, material: "plastic.matte:2A2C30"), Xform(translation: V3(0.12, yb + 0.029, zb + 0.08), rotation: simd_quatf(degrees: rng.float(-10...10), axis: .up)), to: name, lods: 0...0)
            default:
                // Hanging file rails and suspension files.
                for sx: Float in [-1, 1] {
                    rig.add(Prim.roundedBox(V3(0.012, 0.01, depthIn), radius: 0.002, bevelSegments: 1, material: "metal.galvanized"),
                            Xform(translation: V3(sx * (bw / 2 - 0.004), yb + bh + 0.005, zb)), to: name)
                }
                var z = zIn - 0.04, f = 0
                while z > zc - front / 2 - depthIn + 0.05 && f < 12 {
                    let tint: UInt32 = rng.chance(0.8) ? 0x5E7A3E : 0xC2A86A
                    let fh2 = bh - 0.03 - rng.float(0...0.02)
                    let lean = rng.float(-5...5)
                    rig.add(cuboid(V3(bw - 0.03, fh2, 0.006 + rng.float(0...0.01)), material: "paper.sheet:" + String(format: "%06X", tint)),
                            Xform(translation: V3(0, yb + 0.01 + fh2 / 2, z), rotation: simd_quatf(degrees: lean, axis: V3(1, 0, 0))), to: name, lods: 0...0)
                    rig.add(cuboid(V3(bw + 0.004, 0.006, 0.003), material: "metal.galvanized"), Xform(translation: V3(0, yb + bh + 0.012, z)), to: name, lods: 0...0)
                    if rng.chance(0.6) {
                        rig.add(cuboid(V3(0.05, 0.02, 0.002), material: "plastic.white"),
                                Xform(translation: V3(rng.float(-bw / 2 + 0.05...bw / 2 - 0.05), yb + 0.01 + fh2 + 0.01, z), rotation: simd_quatf(degrees: lean, axis: V3(1, 0, 0))), to: name, lods: 0...0)
                    }
                    z -= rng.float(0.025...0.045); f += 1
                }
            }
        }
        groundAO(&rig, height: 0.08, floor: 0.55)
        rig.states = [RigState("closed"), RigState("top-open", ["top": 0.32]), RigState("box-open", ["box": 0.34]),
                      RigState("file-open", ["file": 0.4])]
        return rig
    }
}
