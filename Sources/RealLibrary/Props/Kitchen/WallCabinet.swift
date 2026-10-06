import simd
import Foundation

/// Shaker wall cabinet (frameless, full overlay) matching `base-cabinet`: two five-piece doors on cup
/// hinges (solid or glass panels), bar pulls at the lower corners, plywood box with two adjustable
/// shelves holding stacked plates, bowls and tumblers, and a light-rail moulding under the front.
/// Hung: base at y = 0 of its own frame, back against the wall at `backZ`.
public struct WallCabinet: RealArticulated {
    public static let id = "wall-cabinet"
    public static let summary = "Shaker wall cabinet, 76 cm: two doors with optional glass panels, two shelves with plates and glasses inside."
    public static let tags = ["prop", "kitchen", "wood", "furniture", "container", "articulated"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 6, distance: 1.5, studio: true)

    /// Width in meters (0.3...1.2); under 0.5 m it gets one door.
    public var width: Float = 0.76
    public var height: Float = 0.76
    /// Box depth behind the doors.
    public var carcassDepth: Float = 0.31
    /// Glass center panels (shows the dishes).
    public var glassDoors = false
    /// Single door hinged on the left (false: right).
    public var hingeLeft = true
    /// Fill the shelves with plates, bowls and glasses.
    public var dishes = true
    /// Paint tint (sRGB hex), nil = factory white.
    public var color: UInt32? = nil
    public var paint: MaterialKey = "wood.painted-shaker"
    public var hardware: MaterialKey = "metal.brushed-nickel"
    public init() {}

    static let doorT: Float = 0.019, rail: Float = 0.022
    public var depth: Float { carcassDepth + Self.doorT }
    public var backZ: Float { -depth / 2 }
    public var doorFrontZ: Float { depth / 2 }
    public var hasTwoDoors: Bool { width >= 0.5 }

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [6])
        let W = min(max(width, 0.3), 1.2), H = height
        let paintKey: MaterialKey = color.map { paint + ":" + String(format: "%06X", $0) } ?? paint
        let wornKey: MaterialKey = color.map { paint + "-worn:" + String(format: "%06X", $0) } ?? paint + "-worn"
        let ply: MaterialKey = "wood.plywood"
        let side: Float = 0.018, back: Float = 0.006
        let bz = backZ, cf = bz + carcassDepth, df = depth / 2
        let y0 = Self.rail, inW = W - 2 * side
        let reveal: Float = 0.0015

        func rbox(_ size: V3, _ c: V3, _ mat: MaterialKey, r: Float = 0.0015, seg: Int = 1) -> (Surface, Xform) {
            (Prim.roundedBox(size, radius: r, bevelSegments: seg, material: mat), Xform(translation: c))
        }
        let shelfYs: [Float] = [y0 + side + (H - y0 - 2 * side) / 3, y0 + side + 2 * (H - y0 - 2 * side) / 3]

        for l in 0..<2 {
            var m = Model(name: Self.id)
            func add(_ b: (Surface, Xform)) { m.add(b.0, b.1) }
            for sx: Float in [-1, 1] {
                add(rbox(V3(side, H - y0, carcassDepth), V3(sx * (W / 2 - side / 2), y0 + (H - y0) / 2, bz + carcassDepth / 2), paintKey, r: 0.0025, seg: 2))
                add(rbox(V3(0.002, H - y0 - 2 * side, carcassDepth - back - 0.002), V3(sx * (inW / 2 - 0.001), y0 + (H - y0) / 2, bz + back + (carcassDepth - back) / 2), ply, r: 0.0005))
            }
            // Top and bottom (bottom painted: it is seen from below), back.
            add(rbox(V3(inW - 0.001, side, carcassDepth), V3(0, H - side / 2, bz + carcassDepth / 2), paintKey, r: 0.0015))
            add(rbox(V3(inW - 0.001, side, carcassDepth), V3(0, y0 + side / 2, bz + carcassDepth / 2), paintKey, r: 0.0015))
            add(rbox(V3(inW - 0.001, 0.0016, carcassDepth - back - 0.01), V3(0, y0 + side + 0.0008, bz + back + (carcassDepth - back) / 2), ply, r: 0.0003))
            add(rbox(V3(inW - 0.001, 0.0016, carcassDepth - back - 0.01), V3(0, H - side - 0.0008, bz + back + (carcassDepth - back) / 2), ply, r: 0.0003))
            add(rbox(V3(inW - 0.001, H - y0 - 2 * side, back), V3(0, y0 + (H - y0) / 2, bz + back / 2), "laminate.white:A58C6C", r: 0.0005))
            add(rbox(V3(inW - 0.003, H - y0 - 2 * side - 0.002, 0.001), V3(0, y0 + (H - y0) / 2, bz + back + 0.0005), ply, r: 0.0003))
            // Light rail: small ogee-ish moulding under the front, returned on the sides.
            add(rbox(V3(W + 0.008, Self.rail - 0.001, 0.019), V3(0, (Self.rail - 0.001) / 2, df + 0.002 - 0.0095), paintKey, r: 0.004, seg: 2))
            for sx: Float in [-1, 1] {
                add(rbox(V3(0.019, Self.rail - 0.001, depth - 0.06), V3(sx * (W / 2 + 0.004 - 0.0095), (Self.rail - 0.001) / 2, df - (depth - 0.06) / 2), paintKey, r: 0.004, seg: 2))
            }
            // Shelves on pins.
            for sy in shelfYs {
                add(rbox(V3(inW - 0.004, side, carcassDepth - back - 0.02), V3(0, sy, bz + back + (carcassDepth - back - 0.02) / 2 + 0.001), ply, r: 0.0015, seg: 2))
            }
            // Dishes.
            if dishes && l == 0 {
                let floors = [y0 + side + 0.0016] + shelfYs.map { $0 + side / 2 }
                let zc = bz + back + (carcassDepth - back) * 0.48
                // Stacks as one lathe each: plate rims ring the outside, the top plate's well on top.
                func plateStack(_ n: Int) -> Surface {
                    var p: [V2] = [V2(0.001, 0), V2(0.06, 0), V2(0.07, 0.003)]
                    for i in 0..<n {
                        let b = Float(i) * 0.0125
                        p += [V2(0.104, b + 0.0115), V2(0.108, b + 0.0155)]
                    }
                    let t = Float(n - 1) * 0.0125
                    p += [V2(0.1, t + 0.0165), V2(0.068, t + 0.009), V2(0.001, t + 0.0075)]
                    return Prim.lathe(p, segments: 18, seamTile: 0.1, material: "ceramic.vitreous")
                }
                func bowlStack(_ n: Int) -> Surface {
                    var p: [V2] = [V2(0.001, 0), V2(0.035, 0), V2(0.042, 0.006)]
                    for i in 0..<n { let b = Float(i) * 0.028; p += [V2(0.07, b + 0.036), V2(0.075, b + 0.058), V2(0.0715, b + 0.0605)] }
                    let t = Float(n - 1) * 0.028
                    p += [V2(0.064, t + 0.038), V2(0.035, t + 0.012), V2(0.001, t + 0.011)]
                    return Prim.lathe(p, segments: 16, seamTile: 0.1, material: "ceramic.vitreous")
                }
                let glassS = Prim.lathe([V2(0.001, 0), V2(0.03, 0), V2(0.037, 0.12), V2(0.0345, 0.12), V2(0.031, 0.009), V2(0.001, 0.01)],
                                        segments: 12, seamTile: 0.1, material: "glass.clear")
                for (k, fy) in floors.enumerated() {
                    var x = -inW / 2 + 0.03
                    while x < inW / 2 - 0.03 {
                        let roll = (k + Int(rng.float(0...2.99))) % 3
                        if roll == 0 && x + 0.22 < inW / 2 {
                            m.add(plateStack(rng.int(4...8)), Xform(translation: V3(x + 0.11, fy, zc), rotation: simd_quatf(degrees: rng.float(0...30), axis: .up)))
                            x += 0.235
                        } else if roll == 1 && x + 0.16 < inW / 2 {
                            m.add(bowlStack(rng.int(2...4)), Xform(translation: V3(x + 0.077, fy, zc)))
                            x += 0.17
                        } else if x + 0.08 < inW / 2 {
                            for j in 0..<2 { m.add(glassS, Xform(translation: V3(x + 0.04, fy, zc + (j == 0 ? -0.05 : 0.05)))) }
                            x += 0.085
                        } else { break }
                    }
                }
            }
            rig.base[l] = m
        }

        // Doors from the top of the light rail to the top.
        let dBot = y0 + 0.0, dTop = H - 0.002, dh = dTop - dBot, dcy = (dTop + dBot) / 2
        var doors: [(String, Float, Float, Float)] = []
        if hasTwoDoors {
            doors = [("left", -W / 2 + reveal, -reveal, -1), ("right", reveal, W / 2 - reveal, 1)]
        } else {
            doors = [(hingeLeft ? "left" : "right", -W / 2 + reveal, W / 2 - reveal, hingeLeft ? -1 : 1)]
        }
        for (name, x0, x1, hs) in doors {
            let hx = hs < 0 ? x0 : x1
            rig.part(name, pivot: V3(hx, dcy, cf), joint: .hinge(axis: .up, hs < 0 ? -110...0 : 0...110, duration: 0.8))
            for l in 0..<2 {
                var m = Model(name: name)
                let cx = (x0 + x1) / 2
                KitchenFit.shakerFront(&m, width: x1 - x0, height: dh, frame: 0.065, at: V3(cx, dcy, df), material: paintKey, bottomRail: wornKey,
                                       panel: glassDoors ? "glass.clear" : nil, lite: l > 0 && !glassDoors)
                let px = hs < 0 ? x1 - 0.04 : x0 + 0.04, pl: Float = 0.096
                m.add(barHandle(length: pl, standoff: 0.03, radius: 0.0055, overhang: 0.018, material: hardware),
                      Xform(translation: V3(px, dBot + 0.06 + pl / 2, df), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
                if l == 0 {
                    for y in [dBot + 0.08, dTop - 0.08] { KitchenFit.cupHinge(&m, at: V3(hx, y, cf - 0.0015), side: hs, material: "metal.galvanized") }
                }
                rig.set(m, part: name, lod: l)
            }
        }

        groundAO(&rig, height: 0.05, floor: 0.7)
        if hasTwoDoors {
            rig.states = [RigState("closed"), RigState("left-open", ["left": -105]), RigState("open", ["left": -105, "right": 105])]
        } else {
            let n = hingeLeft ? "left" : "right"
            rig.states = [RigState("closed"), RigState("left-open", [n: hingeLeft ? -60 : 60]), RigState("open", [n: hingeLeft ? -105 : 105])]
        }
        return rig
    }
}
