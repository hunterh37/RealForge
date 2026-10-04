import simd
import Foundation

/// Tall two-door steel storage cupboard (Bisley class), 90 x 195 x 45 cm: powder-coated carcass on a
/// recessed plinth, two overlay doors on concealed hinges at the outer edges, a locking swing handle
/// on the right door, dark interior with four adjustable shelves holding lever-arch binders, archive
/// boxes and paper reams.
public struct StorageCabinet: RealArticulated {
    public static let id = "storage-cabinet"
    public static let summary = "Tall two-door steel storage cupboard: hinged overlay doors, locking swing handle, four shelves of binders, archive boxes and reams."
    public static let tags = ["prop", "office", "furniture", "metal", "container", "articulated"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 10, distance: 1.25, studio: true)

    /// Powder coat (sRGB hex): chalk 0xE6E4DE, goose grey 0xBDBCB6, black 0x2B2C2E.
    public var color: UInt32 = 0xE6E4DE
    public var width: Float = 0.9
    public var height: Float = 1.95
    public var depth: Float = 0.45
    public var shelves = 4
    /// Binder spine tints (sRGB hex).
    public var binderColors: [UInt32] = [0x22375A, 0x2A2A2C]
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [8])
        let paint: MaterialKey = "metal.powdercoat:" + String(format: "%06X", color)
        let liner: MaterialKey = "metal.powdercoat:3C3D40"
        let shelfMat: MaterialKey = "metal.powdercoat:55575A"
        let dark: MaterialKey = "plastic.black"
        let W = width, H = height, D = depth
        let sheet: Float = 0.012, doorT: Float = 0.02, plinth: Float = 0.055, topT: Float = 0.022
        let reveal: Float = 0.003
        let zBody = D - doorT                       // carcass depth behind the doors
        let zc = -doorT / 2                         // carcass center z
        let inLo = plinth + 0.012, inHi = H - topT  // interior span
        let inW = W - 2 * sheet, inD = zBody - sheet

        func rbox(_ size: V3, _ c: V3, _ mat: MaterialKey, r: Float = 0.003, seg: Int = 2) -> (Surface, Xform) {
            (Prim.roundedBox(size, radius: r, bevelSegments: seg, material: mat), Xform(translation: c))
        }

        for l in 0..<2 {
            var m = Model(name: Self.id)
            func add(_ b: (Surface, Xform)) { m.add(b.0, b.1) }
            for sx: Float in [-1, 1] {
                add(rbox(V3(sheet, H - plinth + 0.004, zBody), V3(sx * (W / 2 - sheet / 2), plinth + (H - plinth) / 2 - 0.002, zc), paint, r: 0.004))
                // Front flange of the side, seen in the door gap.
                add(rbox(V3(0.02, inHi - inLo, 0.004), V3(sx * (W / 2 - 0.01), (inLo + inHi) / 2, D / 2 - doorT - 0.002), paint, r: 0.001, seg: 1))
            }
            add(rbox(V3(W, topT, zBody), V3(0, H - topT / 2, zc), paint, r: 0.004))
            add(rbox(V3(inW, H - plinth, sheet), V3(0, plinth + (H - plinth) / 2, -D / 2 + sheet / 2), paint, r: 0.002, seg: 1))
            add(rbox(V3(inW, 0.012, zBody), V3(0, plinth + 0.006, zc), paint, r: 0.002, seg: 1))
            // Recessed plinth with levelling feet.
            add(rbox(V3(W - 0.03, plinth - 0.004, zBody - 0.04), V3(0, (plinth - 0.004) / 2 + 0.004, zc - 0.01), dark, r: 0.002, seg: 1))
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                add(rbox(V3(0.04, 0.006, 0.04), V3(sx * (W / 2 - 0.05), 0.003, zc + sz * (zBody / 2 - 0.05)), "rubber", r: 0.002, seg: 1))
            }}
            // Dark interior liner (inside faces).
            var cav = Prim.roundedBox(V3(inW - 0.002, inHi - inLo - 0.002, inD), radius: 0.004, bevelSegments: 1, material: liner).flipped()
            cav = cav.transformed(Xform(translation: V3(0, (inLo + inHi) / 2, D / 2 - doorT - inD / 2)))
            m.add(cav)
            // Shelves: folded steel trays with a front lip, on side clips.
            let pitch = (inHi - inLo) / Float(shelves + 1)
            for s in 0...shelves {
                let y = inLo + Float(s) * pitch
                if s > 0 {
                    add(rbox(V3(inW - 0.006, 0.022, inD - 0.03), V3(0, y, D / 2 - doorT - 0.02 - (inD - 0.03) / 2), shelfMat, r: 0.003))
                    if l == 0 {
                        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                            m.add(cuboid(V3(0.004, 0.02, 0.012), material: "metal.galvanized"),
                                  Xform(translation: V3(sx * (inW / 2 - 0.004), y - 0.02, D / 2 - doorT - 0.04 + sz * 0 - (sz < 0 ? inD - 0.07 : 0))))
                        }}
                    }
                }
                // Contents of compartment s (shelf top at y + 0.011 for s > 0).
                guard l == 0 else { continue }
                let floorY = s == 0 ? inLo + 0.006 : y + 0.011
                let room = pitch - 0.03
                let front = D / 2 - doorT - 0.05
                var x = -inW / 2 + 0.012
                let kind = (s + Int(seed % 3)) % 4
                while x < inW / 2 - 0.02 {
                    let roll = rng.float(0...1)
                    if (kind == 1 && roll < 0.7) || (kind == 3 && roll < 0.25) {
                        // Archive box (kraft board) with a white label.
                        let bw: Float = 0.105, bh: Float = min(0.33, room), bd: Float = 0.29
                        guard x + bw < inW / 2 - 0.01 else { break }
                        m.add(Prim.roundedBox(V3(bw, bh, bd), radius: 0.003, bevelSegments: 1, material: "paper.sheet:B79A68"),
                              Xform(translation: V3(x + bw / 2, floorY + bh / 2, front - bd / 2)))
                        m.add(cuboid(V3(0.07, 0.09, 0.002), material: "paper.sheet"), Xform(translation: V3(x + bw / 2, floorY + bh * 0.62, front + 0.0005)))
                        m.add(cuboid(V3(0.03, 0.016, 0.003), material: dark), Xform(translation: V3(x + bw / 2, floorY + bh * 0.25, front)))
                        x += bw + 0.004
                    } else if kind == 2 && roll < 0.3 {
                        // Stack of paper reams lying flat.
                        let n = rng.int(2...5)
                        for i in 0..<n {
                            m.add(cuboid(V3(0.21, 0.05, 0.297), material: "paper.sheet"),
                                  Xform(translation: V3(x + 0.11, floorY + 0.026 + Float(i) * 0.052, front - 0.16), rotation: simd_quatf(degrees: rng.float(-3...3), axis: .up)))
                        }
                        x += 0.24
                    } else if roll < 0.92 {
                        // Lever-arch binder standing, spine out, with a label and a finger hole.
                        let bw: Float = rng.chance(0.7) ? 0.08 : 0.05, bh: Float = min(0.318, room), bd: Float = 0.285
                        guard x + bw < inW / 2 - 0.01 else { break }
                        let tint = binderColors[rng.chance(0.65) ? 0 : min(1, binderColors.count - 1)]
                        let lean = (x + bw > inW / 2 - 0.1 && rng.chance(0.5)) ? rng.float(0...0) : 0
                        let bx = Xform(translation: V3(x + bw / 2, floorY + bh / 2, front - bd / 2 + rng.float(-0.01...0.01)),
                                       rotation: simd_quatf(degrees: lean, axis: V3(0, 0, 1)))
                        m.add(Prim.roundedBox(V3(bw, bh, bd), radius: 0.003, bevelSegments: 1, material: "book.cloth:" + String(format: "%06X", tint)), bx)
                        m.add(cuboid(V3(bw * 0.6, 0.1, 0.002), material: "paper.sheet"), Xform(translation: bx.translation + V3(0, 0.05, bd / 2)))
                        m.add(Prim.cylinder(radius: 0.011, height: 0.004, bevel: 0.0015, segments: 10, bevelSegments: 1, material: dark),
                              Xform(translation: bx.translation + V3(0, -bh * 0.3, bd / 2 - 0.002), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
                        x += bw + 0.002
                    } else {
                        x += rng.float(0.04...0.12)   // gap
                    }
                }
            }
            rig.base[l] = m
        }

        // Doors: overlay steel pans hinged on concealed hinges at the outer back edge of each door.
        let dw = (W - 3 * reveal) / 2, dLo = plinth + reveal, dHi = H - reveal
        let dh = dHi - dLo, dcy = (dLo + dHi) / 2
        let zDoor = D / 2 - doorT / 2
        rig.part("left", pivot: V3(-W / 2 + reveal, dcy, D / 2 - doorT), joint: .hinge(axis: .up, -110...0, duration: 1.0))
        rig.part("right", pivot: V3(W / 2 - reveal, dcy, D / 2 - doorT), joint: .hinge(axis: .up, 0...110, duration: 1.0))
        for (name, sx) in [("left", Float(-1)), ("right", Float(1))] {
            let cx = sx * (reveal / 2 + dw / 2)
            rig.add(Prim.roundedBox(V3(dw, dh, doorT), radius: 0.005, bevelSegments: 2, material: paint),
                    Xform(translation: V3(cx, dcy, zDoor)).jittered(&rng, deg: 0.03, offset: 0.0002), to: name)
            // Inner stiffener pan, visible when open.
            rig.add(Prim.roundedBox(V3(dw - 0.06, dh - 0.08, 0.012), radius: 0.003, bevelSegments: 1, material: paint),
                    Xform(translation: V3(cx, dcy, D / 2 - doorT - 0.006)), to: name, lods: 0...0)
            // Concealed hinge cups on the inner face.
            for hy in [dLo + 0.12, dcy, dHi - 0.12] {
                rig.add(Prim.roundedBox(V3(0.05, 0.07, 0.014), radius: 0.003, bevelSegments: 1, material: "metal.galvanized"),
                        Xform(translation: V3(sx * (W / 2 - 0.04), hy, D / 2 - doorT - 0.007)), to: name, lods: 0...0)
            }
        }
        // Swing handle on the right door near the meeting edge: escutcheon plate, lock and lever.
        let hx = reveal / 2 + 0.035, hy: Float = 1.05, hz = D / 2
        rig.add(Prim.roundedBox(V3(0.034, 0.17, 0.008), radius: 0.004, bevelSegments: 2, material: dark),
                Xform(translation: V3(hx, hy - 0.05, hz + 0.003)), to: "right")
        rig.add(Prim.cylinder(radius: 0.009, height: 0.006, bevel: 0.0015, segments: 16, material: "metal.chrome"),
                Xform(translation: V3(hx, hy - 0.115, hz + 0.006), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "right")
        rig.add(cuboid(V3(0.0016, 0.008, 0.002), material: dark), Xform(translation: V3(hx, hy - 0.115, hz + 0.0125)), to: "right", lods: 0...0)
        rig.part("handle", parent: "right", pivot: V3(hx, hy, hz + 0.01), joint: .hinge(axis: V3(0, 0, 1), 0...90, duration: 0.35))
        rig.add(Prim.cylinder(radius: 0.012, height: 0.012, bevel: 0.003, segments: 16, material: "metal.chrome"),
                Xform(translation: V3(hx, hy, hz + 0.006), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "handle")
        let lever = Shape2D.rounded([V2(-0.011, 0.008), V2(0.011, 0.008), V2(0.008, -0.11), V2(-0.008, -0.11)], radius: 0.006, segments: 3)
        rig.add(Prim.extrude(lever, depth: 0.012, bevel: 0.003, bevelSegments: 2, material: "metal.chrome"),
                Xform(translation: V3(hx, hy, hz + 0.022)), to: "handle")

        groundAO(&rig, height: 0.1, floor: 0.55)
        rig.states = [RigState("closed"), RigState("open", ["left": -105, "right": 108, "handle": 90]),
                      RigState("left-open", ["left": -100])]
        return rig
    }
}
