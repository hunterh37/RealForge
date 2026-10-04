import simd
import Foundation

/// Lobby elevator entrance, 2.5 m wall section: brushed-stainless center-opening bi-parting doors
/// (1.1 m clear x 2.2 m) behind a stainless portal (jamb faces, returns, head), extruded-aluminum
/// landing and car sills with guide grooves, a two-button hall call station, a floor indicator above
/// the head, and a dimly lit car behind (walls, terrazzo floor, stainless handrail, ceiling panel).
/// Base y = 0 at the finished floor; centered on Z, so the lobby wall face sits at z = `wallFaceZ`.
public struct ElevatorDoors: RealArticulated {
    public static let id = "elevator-doors"
    public static let summary = "Elevator entrance: bi-parting brushed stainless doors in a stainless portal, sills, call buttons, floor indicator and car interior."
    public static let tags = ["structure", "interior", "door", "metal", "articulated"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 6, distance: 1.0, studio: true)

    /// Lobby wall face position after centering (the car reaches 1.62 m behind it).
    public var wallFaceZ: Float = 0.8
    public var clearWidth: Float = 1.1
    public var clearHeight: Float = 2.2
    public var wallWidth: Float = 2.5
    public var wallHeight: Float = 2.75
    public var wallMaterial: MaterialKey = "paint.wall:D9D5CC"
    public var steel: MaterialKey = "metal.stainless"
    public var carWall: MaterialKey = "metal.powdercoat:3A3B3D"
    public var carFloor: MaterialKey = "stone.terrazzo"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [9])
        let cw = clearWidth, ch = clearHeight, ox = cw / 2
        let WW = wallWidth / 2, WH = wallHeight
        let wallT: Float = 0.12, face: Float = 0.012, jamb: Float = 0.1, head: Float = 0.15
        let doorT: Float = 0.03, doorZ: Float = -wallT - 0.005 - doorT / 2
        let carZ0: Float = -0.18, carD: Float = 1.32, carW: Float = 1.6, carH: Float = 2.35
        let alu: MaterialKey = "metal.aluminum-brushed", dark: MaterialKey = "plastic.black"

        func box(_ size: V3, _ c: V3, _ mat: MaterialKey, r: Float = 0.002, seg: Int = 2) -> (Surface, Xform) {
            (Prim.roundedBox(size, radius: r, bevelSegments: seg, material: mat), Xform(translation: c))
        }
        /// Vertical brushing / grain (U along Y on the ±Z faces).
        func vbox(_ size: V3, _ c: V3, _ mat: MaterialKey, r: Float) -> (Surface, Xform) {
            (Prim.roundedBox(V3(size.y, size.x, size.z), radius: r, bevelSegments: 2, material: mat),
             Xform(translation: c, rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        }

        for l in 0..<2 {
            var m = Model(name: Self.id)
            func add(_ b: (Surface, Xform)) { m.add(b.0, b.1) }
            // Lobby wall around the opening (the doors pocket behind it).
            let sideW = WW - ox
            for sx: Float in [-1, 1] {
                add(box(V3(sideW, WH, wallT), V3(sx * (ox + sideW / 2), WH / 2, -wallT / 2), wallMaterial, r: 0.003))
            }
            add(box(V3(2 * ox + 0.004, WH - ch, wallT), V3(0, ch + (WH - ch) / 2, -wallT / 2), wallMaterial, r: 0.002, seg: 1))
            // Portal: jamb faces, head face, returns lining the opening.
            for sx: Float in [-1, 1] {
                add(vbox(V3(jamb, ch + head, face), V3(sx * (ox + jamb / 2), (ch + head) / 2, face / 2), steel, r: 0.003))
                add(vbox(V3(face, ch, wallT + face), V3(sx * (ox + face / 2 - 0.002), ch / 2, (face - wallT) / 2), steel, r: 0.002))
            }
            add(box(V3(2 * ox + 0.004, head, face), V3(0, ch + head / 2, face / 2), steel, r: 0.003))
            add(box(V3(2 * ox, face, wallT + face), V3(0, ch - face / 2 + 0.002, (face - wallT) / 2), steel, r: 0.002))
            // Landing sill (extruded aluminum, 3 mm proud) with the door guide groove and anti-slip ribs.
            let sillW = 2 * ox + 0.16
            let sillZ0: Float = 0.02, sillZ1: Float = doorZ - 0.03
            add(box(V3(sillW, 0.004, sillZ0 - sillZ1), V3(0, 0.002, (sillZ0 + sillZ1) / 2), alu, r: 0.0012, seg: 1))
            add(box(V3(sillW - 0.01, 0.0012, 0.012), V3(0, 0.0038, doorZ), dark, r: 0.0004, seg: 1))
            // Running clearance and car sill.
            add(box(V3(sillW, 0.002, 0.03), V3(0, 0.0005, carZ0 + 0.005), dark, r: 0.0005, seg: 1))
            add(box(V3(2 * ox + 0.1, 0.004, 0.09), V3(0, 0.002, carZ0 - 0.055), alu, r: 0.0012, seg: 1))
            add(box(V3(2 * ox + 0.09, 0.0012, 0.01), V3(0, 0.0038, carZ0 - 0.04), dark, r: 0.0004, seg: 1))
            if l == 0 {
                for k in 0..<5 {
                    let z = sillZ0 - 0.012 - Float(k) * 0.016
                    add(box(V3(sillW - 0.01, 0.001, 0.003), V3(0, 0.0039, z), dark, r: 0.0003, seg: 1))
                }
            }
            // Car: dark lined box, terrazzo floor, stainless handrail, ceiling light panel.
            let carC = V3(0, carH / 2, carZ0 - carD / 2 - 0.1)
            var car = Prim.roundedBox(V3(carW, carH, carD), radius: 0.01, bevelSegments: 1, material: carWall).flipped()
            car = car.transformed(Xform(translation: carC))
            m.add(car)
            // Outer shell (roof, sides, back) so the car shades its interior and reads solid from behind.
            let shell = carWall, st: Float = 0.02
            add(box(V3(carW + 2 * st, st, carD + st), V3(0, carH + st / 2 + 0.002, carC.z - st / 2), shell, r: 0.002, seg: 1))
            for sx: Float in [-1, 1] {
                add(box(V3(st, carH, carD + st), V3(sx * (carW / 2 + st / 2 + 0.002), carH / 2, carC.z - st / 2), shell, r: 0.002, seg: 1))
            }
            add(box(V3(carW, carH, st), V3(0, carH / 2, carC.z - carD / 2 - st / 2 - 0.002), shell, r: 0.002, seg: 1))
            // Hoistway header hiding the gap between the wall and the car roof.
            add(box(V3(carW + 0.6, WH - carH, 0.16), V3(0, carH + (WH - carH) / 2, -wallT - 0.08), shell, r: 0.002, seg: 1))
            add(box(V3(carW - 0.01, 0.006, carD - 0.02), V3(0, 0.003, carC.z + 0.005), carFloor, r: 0.001, seg: 1))
            let railY: Float = 0.9, backZ = carC.z - carD / 2
            m.add(Prim.cylinder(radius: 0.019, height: carW - 0.3, bevel: 0.008, segments: l == 0 ? 20 : 12, bevelSegments: 2, material: steel),
                  Xform(translation: V3(-(carW - 0.3) / 2, railY, backZ + 0.07), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
            for dx: Float in [-0.45, 0.45] {
                m.add(Prim.cylinder(radius: 0.008, height: 0.07, bevel: 0.001, segments: 12, bevelSegments: 1, material: steel),
                      Xform(translation: V3(dx, railY, backZ), rotation: facing(V3(0, 0, 1))))
            }
            add(box(V3(carW * 0.6, 0.01, carD * 0.55), V3(0, carH - 0.004, carC.z), "emissive.panel", r: 0.003, seg: 1))
            // Stainless car back wall panel band (reads through the opening).
            add(vbox(V3(1.0, 2.1, 0.008), V3(0, 1.1, backZ + 0.004), steel, r: 0.002))
            // Hall call station: stainless faceplate on the wall.
            let cx = ox + jamb + 0.22, cy: Float = 1.05
            add(vbox(V3(0.085, 0.22, 0.004), V3(cx, cy, 0.002), steel, r: 0.0015))
            if l == 0 {
                for dy: Float in [-0.09, 0.09] {
                    m.add(Prim.cylinder(radius: 0.0022, height: 0.0012, bevel: 0.0004, segments: 10, bevelSegments: 1, material: steel),
                          Xform(translation: V3(cx, cy + dy, 0.004), rotation: facing(V3(0, 0, 1))))
                }
            }
            // Floor indicator: stainless bezel above the head, dark screen.
            let iy = ch + head + 0.15
            add(box(V3(0.3, 0.11, 0.008), V3(0, iy, 0.004), steel, r: 0.003))
            add(box(V3(0.25, 0.07, 0.003), V3(0, iy, 0.0085), "screen.off", r: 0.001, seg: 1))
            rig.base[l] = m
        }

        // MARK: doors
        let panelW = ox + 0.012
        rig.part("left", pivot: V3(0, ch / 2, doorZ), joint: .slide(axis: V3(-1, 0, 0), 0...ox, duration: 2.2))
        rig.part("right", pivot: V3(0, ch / 2, doorZ), joint: Joint(.prismatic, axis: V3(-1, 0, 0), range: -ox...0, duration: 2.2, mimic: .init("left", ratio: -1)))
        for (name, sx) in [("left", Float(-1)), ("right", 1)] {
            let p = vbox(V3(panelW - 0.002, ch + 0.02, doorT), V3(sx * (panelW / 2 + 0.002), ch / 2 + 0.006, doorZ), steel, r: 0.003)
            rig.add(p.0, p.1, to: name)
            // Rubber nosing on the leading edge.
            rig.add(Prim.roundedBox(V3(0.006, ch - 0.01, doorT - 0.008), radius: 0.002, bevelSegments: 1, material: dark),
                    Xform(translation: V3(sx * 0.003, ch / 2 + 0.006, doorZ)), to: name)
            // Bottom guide shoe in the sill groove.
            rig.add(cuboid(V3(0.12, 0.008, 0.008), material: dark), Xform(translation: V3(sx * panelW * 0.5, 0.004, doorZ)), to: name, lods: 0...0)
        }

        // MARK: call button and indicator (option 0 unlit, 1 lit)
        let cx = ox + jamb + 0.22, cy: Float = 1.05
        rig.part("button", pivot: V3(cx, cy, 0.004), joint: .fixed, options: 2)
        for (o, lens) in [(0, MaterialKey("plastic.white")), (1, MaterialKey("emissive.indicator"))] {
            for dy: Float in [-0.028, 0.028] {
                rig.add(Prim.cylinder(radius: 0.017, height: 0.004, bevel: 0.0012, segments: 24, bevelSegments: 1, material: steel),
                        Xform(translation: V3(cx, cy + dy, 0.004), rotation: facing(V3(0, 0, 1))), to: "button", option: o)
                rig.add(Prim.cylinder(radius: 0.0125, height: 0.0035, bevel: 0.0012, segments: 24, bevelSegments: 1, material: lens),
                        Xform(translation: V3(cx, cy + dy, 0.0065), rotation: facing(V3(0, 0, 1))), to: "button", option: o)
                // Raised direction arrow.
                let up = dy > 0
                let tri = Shape2D.rounded(up ? [V2(-0.005, -0.003), V2(0.005, -0.003), V2(0, 0.004)] : [V2(-0.005, 0.003), V2(0, -0.004), V2(0.005, 0.003)], radius: 0.0008, segments: 1)
                rig.add(Prim.extrude(tri, depth: 0.0015, bevel: 0.0004, bevelSegments: 1, material: o == 1 ? "plastic.white" : steel),
                        Xform(translation: V3(cx, cy + dy, 0.0105)), to: "button", option: o, lods: 0...0)
            }
        }
        let iy = ch + head + 0.15
        rig.part("display", pivot: V3(0, iy, 0.01), joint: .fixed, options: 2)
        for (o, mat) in [(0, MaterialKey("screen.off")), (1, MaterialKey("emissive.indicator"))] {
            // Seven-segment "3" and an up arrow.
            let seg: Float = 0.0045, dw: Float = 0.024, dh: Float = 0.022, dx: Float = 0.03
            let bars: [(V3, V3)] = [
                (V3(dw, seg, 0.001), V3(dx, dh, 0)), (V3(dw, seg, 0.001), V3(dx, 0, 0)), (V3(dw, seg, 0.001), V3(dx, -dh, 0)),
                (V3(seg, dh, 0.001), V3(dx + dw / 2, dh / 2, 0)), (V3(seg, dh, 0.001), V3(dx + dw / 2, -dh / 2, 0))]
            for (s, c) in bars {
                rig.add(cuboid(s, material: mat), Xform(translation: V3(0, iy, 0.0105) + c), to: "display", option: o)
            }
            let arrow = [V2(-0.014, -0.006), V2(-0.006, -0.006), V2(-0.006, -0.022), V2(0.006, -0.022), V2(0.006, -0.006), V2(0.014, -0.006), V2(0, 0.02)]
            rig.add(Prim.extrude(arrow, depth: 0.001, bevel: 0, bevelSegments: 0, material: mat),
                    Xform(translation: V3(-0.04, iy, 0.0105)), to: "display", option: o)
        }

        groundAO(&rig, height: 0.12, floor: 0.6)
        // Center the assembly on Z (the car reaches 1.6 m behind the wall face).
        shiftRig(&rig, by: V3(0, 0, wallFaceZ))
        rig.states = [RigState("closed"), RigState("open", ["left": ox]), RigState("called", options: ["button": 1, "display": 1]),
                      RigState("arriving", ["left": ox / 2], options: ["button": 1, "display": 1])]
        return rig
    }
}

/// Moves every piece of a rig (base, parts, pivots, lights) by `d`.
fileprivate func shiftRig(_ rig: inout Rig, by d: V3) {
    let x = Xform(translation: d)
    for l in rig.base.indices { rig.base[l] = rig.base[l].transformed(x) }
    for i in rig.parts.indices {
        rig.parts[i].pivot.translation += d
        rig.parts[i].levels = rig.parts[i].levels.map { $0.transformed(x) }
        rig.parts[i].alternates = rig.parts[i].alternates.map { $0.map { $0.transformed(x) } }
    }
    for i in rig.lights.indices { rig.lights[i].position += d }
}
