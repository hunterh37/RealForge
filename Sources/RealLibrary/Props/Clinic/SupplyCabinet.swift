import simd
import Foundation

/// Wall-hung clinic supply cabinet (36 in modular casework class), 914 W x 900 H x 345 D mm:
/// 19 mm white laminate carcass with edge banding, two overlay glass doors in satin aluminium frames
/// on concealed hinges with wire pulls, two adjustable shelves on pins, a drawer with a bar pull below,
/// and stocked supplies: nitrile glove boxes (one opened, a glove pulled out), gauze pad stacks, tape
/// rolls, labelled bottles and dressing boxes. Hung on a wall in scenes; base at y = 0.
public struct SupplyCabinet: RealArticulated {
    public static let id = "supply-cabinet"
    public static let summary = "Wall-hung clinic supply cabinet: white laminate casework, two framed glass doors, two adjustable shelves of supplies and a drawer below."
    public static let tags = ["prop", "medical", "articulated", "furniture", "hospital", "interior", "glass", "container"]
    public static let budget = 11_400
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 10, distance: 2.4, studio: true)

    public var width: Float = 0.914
    public var height: Float = 0.9
    public var depth: Float = 0.3
    public var carcass: MaterialKey = "laminate.white"
    public var frame: MaterialKey = "metal.anodized"
    /// Shelf heights (m, top of shelf).
    public var shelves: [Float] = [0.44, 0.665]
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [8])
        let W = width, H = height, D = depth, t: Float = 0.019
        let zb: Float = -0.165, zf = zb + D, zc = zb + D / 2
        let deck: Float = 0.205                     // top of the drawer divider (interior floor)
        let chrome: MaterialKey = "metal.chrome"

        func panel(_ size: V3, _ c: V3, lods: ClosedRange<Int> = 0...1, mat: MaterialKey? = nil) {
            for l in lods { rig.base[l].add(Prim.roundedBox(size, radius: l == 0 ? 0.0025 : 0.0015, bevelSegments: 1, material: mat ?? carcass), Xform(translation: c)) }
        }
        // MARK: carcass
        panel(V3(t, H, D), V3(-W / 2 + t / 2, H / 2, zc))
        panel(V3(t, H, D), V3(W / 2 - t / 2, H / 2, zc))
        panel(V3(W - 2 * t, t, D), V3(0, H - t / 2, zc))
        panel(V3(W - 2 * t, t, D), V3(0, t / 2, zc))
        panel(V3(W - 2 * t, t, D - 0.006), V3(0, deck - t / 2, zc - 0.003))
        panel(V3(W - 2 * t, H - 2 * t, 0.006), V3(0, H / 2, zb + 0.003))
        // Shelves on pins.
        for sy in shelves {
            panel(V3(W - 2 * t - 0.004, t, D - 0.03), V3(0, sy - t / 2, zc - 0.01))
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                rig.base[0].add(Prim.cylinder(radius: 0.0025, height: 0.008, bevel: 0.0006, segments: 6, bevelSegments: 1, material: chrome),
                                Xform(translation: V3(sx * (W / 2 - t), sy - t - 0.0025, zc - 0.01 + sz * 0.1), rotation: simd_quatf(degrees: sx > 0 ? 90 : -90, axis: V3(0, 0, 1))))
            }}
        }
        // Pin holes: two columns of dark dots on each side wall (LOD0).
        var holes = Surface(material: "plastic.matte:3A3A3A")
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] { for k in 0..<14 {
            let y = deck + 0.06 + Float(k) * 0.032
            holes.append(cuboid(V3(0.0006, 0.004, 0.004), material: "plastic.matte:3A3A3A"),
                         Xform(translation: V3(sx * (W / 2 - t - 0.0002), y, zc - 0.01 + sz * 0.1)))
        }}}
        rig.base[0].add(holes)

        // MARK: supplies
        func labelQuad(_ c: V3, _ w: Float, _ h: Float, _ mat: MaterialKey) -> Surface {
            var s = Surface(material: mat)
            let T: Float = max(0.032, min(0.08, sqrt(w * h)))
            let n = V3(0, 0, 1)
            let a = s.add(c + V3(-w / 2, h / 2, 0), n, V2(0, 0)), b = s.add(c + V3(w / 2, h / 2, 0), n, V2(T, 0))
            let cc = s.add(c + V3(w / 2, -h / 2, 0), n, V2(T, T)), d = s.add(c + V3(-w / 2, -h / 2, 0), n, V2(0, T))
            s.quad(a, d, cc, b)
            s.computeTangents()
            return s
        }
        func box(_ size: V3, _ base: V3, _ tint: UInt32, label: MaterialKey? = "label.supply-small", yaw: Float = 0) {
            let mat: MaterialKey = "paper.sheet:" + String(format: "%06X", tint)
            let x = Xform(translation: base + V3(0, size.y / 2, 0), rotation: simd_quatf(degrees: yaw, axis: .up))
            rig.base[0].add(cuboid(size, material: mat), x)
            rig.base[1].add(cuboid(size, material: mat), x)
            if let label {
                rig.base[0].add(labelQuad(V3(0, 0, size.z / 2 + 0.0004), size.x * 0.86, size.y * 0.8, label), x)
            }
        }
        // Deck: glove boxes (two stacked, one beside), gauze stack, tape rolls.
        let frontZ = zf - 0.03
        box(V3(0.24, 0.065, 0.125), V3(-0.27, deck, frontZ - 0.07), 0xDCE6F2)
        box(V3(0.24, 0.065, 0.125), V3(-0.272, deck + 0.065, frontZ - 0.072), 0xE9DFF0, yaw: 1.5)
        box(V3(0.24, 0.065, 0.125), V3(0.0, deck, frontZ - 0.075), 0xDCE6F2, yaw: -2)
        for k in 0..<9 {
            let x = Xform(translation: V3(0.235 + rng.float(-0.003...0.003), deck + 0.006 + Float(k) * 0.012, frontZ - 0.08), rotation: simd_quatf(degrees: rng.float(-4...4), axis: .up))
            rig.base[0].add(Prim.roundedBox(V3(0.1, 0.011, 0.1), radius: 0.003, bevelSegments: 1, material: "paper.exam"), x)
            if k % 3 == 0 { rig.base[1].add(cuboid(V3(0.1, 0.033, 0.1), material: "paper.exam"), x.then(Xform(translation: V3(0, 0.011, 0)))) }
        }
        for k in 0..<3 {
            let c = V3(0.36, deck, frontZ - 0.05 - Float(k) * 0.08)
            rig.base[0].add(Prim.lathe([V2(0.012, 0), V2(0.026, 0), V2(0.026, 0.025), V2(0.012, 0.025), V2(0.012, 0)], segments: 16, seamTile: 0.05, material: "fabric.linen"),
                            Xform(translation: c))
        }
        // Shelf 1: bottles (antiseptic, saline) with caps and labels.
        let s1 = shelves[0]
        let caps: [UInt32] = [0x2F5FA8, 0xE2E2E2, 0xC8261E, 0x2F5FA8, 0x2E8B3A, 0xE2E2E2]
        for k in 0..<6 {
            let x = -0.36 + Float(k) * 0.085 + rng.float(-0.006...0.006), z = frontZ - 0.06 - Float(k % 2) * 0.09
            let r: Float = k % 3 == 0 ? 0.034 : 0.028, h: Float = k % 3 == 0 ? 0.18 : 0.15
            for l in 0..<2 {
                rig.base[l].add(Prim.lathe([V2(0, 0), V2(r - 0.004, 0), V2(r, 0.004), V2(r, h - 0.03), V2(r * 0.55, h - 0.01), V2(r * 0.42, h - 0.008), V2(r * 0.42, h), V2(0, h)],
                                           segments: l == 0 ? 18 : 10, seamTile: 0.1, material: "plastic.medical"), Xform(translation: V3(x, s1, z)))
                rig.base[l].add(Prim.cylinder(radius: r * 0.48, height: 0.022, bevel: 0.002, segments: l == 0 ? 14 : 6, bevelSegments: 1, material: "plastic.matte:" + String(format: "%06X", caps[k])),
                                Xform(translation: V3(x, s1 + h - 0.004, z)))
            }
            rig.base[0].add(labelQuad(V3(x, s1 + h * 0.45, z + r + 0.0006), r * 1.3, h * 0.45, k % 2 == 0 ? "label.rx-small" : "label.supply-small"))
        }
        // Shelf 2: dressing boxes and the opened glove box with a glove pulled out (story detail).
        let s2 = shelves[1]
        box(V3(0.16, 0.1, 0.11), V3(-0.33, s2, frontZ - 0.07), 0xF2F0EA)
        box(V3(0.16, 0.1, 0.11), V3(-0.165, s2, frontZ - 0.07), 0xF2F0EA, yaw: -3)
        box(V3(0.12, 0.14, 0.09), V3(0.0, s2, frontZ - 0.08), 0xE8EEF2)
        box(V3(0.24, 0.065, 0.125), V3(0.25, s2, frontZ - 0.07), 0xE9DFF0, yaw: 3)
        rig.base[0].add(Prim.superellipsoid(V3(0.07, 0.006, 0.032), exponent: 2.5, subdivisions: 3, material: "plastic.matte:2A2D33"),
                        Xform(translation: V3(0.25, s2 + 0.066, frontZ - 0.07)))
        var glove = Prim.superellipsoid(V3(0.055, 0.07, 0.006), exponent: 3, subdivisions: 5, material: "rubber.silicone:6F5BB5")
        // Limp cuff: flattened, folding over toward the front of the box.
        glove.deform { p in
            let t = max(0, p.y) / 0.035
            return V3(p.x * (1 - 0.25 * t), p.y * (1 - 0.35 * t), p.z + 0.03 * t * t)
        }
        rig.base[0].add(glove, Xform(translation: V3(0.25, s2 + 0.088, frontZ - 0.07), rotation: simd_quatf(degrees: 8, axis: V3(0, 0, 1))))

        // MARK: glass doors (outer-edge hinges; left opens with a negative angle, right positive)
        let doorY0: Float = deck - 0.012, doorY1 = H - 0.003, dh = doorY1 - doorY0, dw = W / 2 - 0.003
        let dz = zf + 0.011
        for (name, side) in [("left-door", Float(-1)), ("right-door", Float(1))] {
            let hingeX = side * W / 2
            rig.part(name, pivot: V3(hingeX, (doorY0 + doorY1) / 2, zf), joint: .hinge(axis: .up, side < 0 ? -110...0 : 0...110, duration: 0.9))
            let cx = side * (W / 2 - dw / 2)
            let fw: Float = 0.032
            let path = [V3(cx - dw / 2 + fw / 2, doorY0 + fw / 2, dz), V3(cx + dw / 2 - fw / 2, doorY0 + fw / 2, dz),
                        V3(cx + dw / 2 - fw / 2, doorY1 - fw / 2, dz), V3(cx - dw / 2 + fw / 2, doorY1 - fw / 2, dz)]
            for l in 0..<2 {
                rig.add(Prim.sweep(Shape2D.roundedRect(0.022, fw, radius: l == 0 ? 0.004 : 0.002, segments: l == 0 ? 2 : 1), along: path, up: V3(0, 0, 1), closedPath: true, material: frame),
                        to: name, lods: l...l)
            }
            rig.add(Prim.roundedBox(V3(dw - 2 * fw + 0.008, dh - 2 * fw + 0.008, 0.005), radius: 0.001, bevelSegments: 1, material: "glass.clear"),
                    Xform(translation: V3(cx, (doorY0 + doorY1) / 2, dz)), to: name)
            // Wire pull near the meeting edge, vertical.
            let px = cx - side * (dw / 2 - 0.045)
            rig.add(barHandle(length: 0.128, standoff: 0.028, radius: 0.0045, material: chrome),
                    Xform(translation: V3(px, (doorY0 + doorY1) / 2 - 0.06, dz + 0.011), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))), to: name, lods: 0...0)
            rig.add(cuboid(V3(0.009, 0.17, 0.009), material: chrome), Xform(translation: V3(px, (doorY0 + doorY1) / 2 - 0.06, dz + 0.035)), to: name, lods: 1...1)
            // Concealed hinge cups and arms (seen when open).
            for hy in [doorY0 + 0.1, doorY1 - 0.1] {
                rig.add(Prim.roundedBox(V3(0.045, 0.05, 0.012), radius: 0.003, bevelSegments: 1, material: "metal.stainless"),
                        Xform(translation: V3(hingeX - side * 0.04, hy, zf - 0.002)), to: name, lods: 0...0)
            }
        }

        // MARK: drawer (slides out on +Z)
        rig.part("drawer", pivot: V3(0, 0.1, zf), joint: .slide(axis: V3(0, 0, 1), 0...0.24, duration: 0.6))
        let fh = deck - 0.012 - 0.003 - 0.003
        rig.add(Prim.roundedBox(V3(W - 0.006, fh, 0.019), radius: 0.003, bevelSegments: 1, material: carcass),
                Xform(translation: V3(0, 0.003 + fh / 2, zf + 0.0095)), to: "drawer")
        rig.add(barHandle(length: 0.192, standoff: 0.03, radius: 0.005, material: chrome),
                Xform(translation: V3(0, 0.003 + fh / 2, zf + 0.019)), to: "drawer", lods: 0...0)
        rig.add(cuboid(V3(0.23, 0.01, 0.01), material: chrome), Xform(translation: V3(0, 0.003 + fh / 2, zf + 0.045)), to: "drawer", lods: 1...1)
        // Drawer box: sides, back, bottom (inside the carcass at rest).
        let bw = W - 2 * t - 0.03, bd = D - 0.04, by0 = t + 0.01, bh: Float = 0.12
        for sx: Float in [-1, 1] {
            rig.add(Prim.roundedBox(V3(0.012, bh, bd), radius: 0.002, bevelSegments: 1, material: carcass), Xform(translation: V3(sx * (bw / 2 - 0.006), by0 + bh / 2, zf - bd / 2)), to: "drawer", lods: 0...0)
            rig.add(cuboid(V3(0.012, bh, bd), material: carcass), Xform(translation: V3(sx * (bw / 2 - 0.006), by0 + bh / 2, zf - bd / 2)), to: "drawer", lods: 1...1)
            // Steel runners.
            rig.add(Prim.roundedBox(V3(0.012, 0.035, bd), radius: 0.002, bevelSegments: 1, material: "metal.stainless"),
                    Xform(translation: V3(sx * (bw / 2 + 0.007), by0 + 0.06, zf - bd / 2)), to: "drawer", lods: 0...0)
        }
        rig.add(cuboid(V3(bw, bh, 0.012), material: carcass), Xform(translation: V3(0, by0 + bh / 2, zf - bd + 0.006)), to: "drawer")
        rig.add(cuboid(V3(bw - 0.02, 0.006, bd - 0.01), material: carcass), Xform(translation: V3(0, by0 + 0.003, zf - bd / 2)), to: "drawer")
        // Drawer contents: syringe packs and gauze rolls.
        for k in 0..<6 {
            let x = -0.3 + Float(k) * 0.11
            rig.add(cuboid(V3(0.08, 0.02, 0.2), material: k % 2 == 0 ? "paper.exam" : "paper.sheet:DCE6F2"),
                    Xform(translation: V3(x, by0 + 0.016, zf - 0.13), rotation: simd_quatf(degrees: rng.float(-5...5), axis: .up)), to: "drawer", lods: 0...0)
        }

        groundAO(&rig, height: 0.05, floor: 0.75)
        rig.states = [
            RigState("closed"),
            RigState("left-open", ["left-door": -105]),
            RigState("both-open", ["left-door": -105, "right-door": 105]),
            RigState("drawer-open", ["drawer": 0.24]),
        ]
        return rig
    }
}
