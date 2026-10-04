import simd
import Foundation
import RealKit

public extension RealScene {
    /// Adds every field, single, live rig and light of `other`, moved by `at` (rooms composed into a
    /// floor plan). Camera, lighting and far ground stay this scene's.
    mutating func merge(_ other: RealScene, at: Xform) {
        let m = at.matrix
        for f in other.fields { fields.append(.init(asset: f.asset, transforms: f.transforms.map { m * $0 }, options: f.options)) }
        for s in other.singles { var c = s; c.at = s.at.then(at); singles.append(c) }
        for r in other.rigs { var c = r; c.at = r.at.then(at); rigs.append(c) }
        for l in other.lights {
            var c = l
            c.position = at.point(l.position)
            c.direction = at.direction(l.direction)
            lights.append(c)
        }
    }
}

/// Shared casework and fit-out for the hospital scenes.
enum HospitalFit {
    /// Base cabinets with a solid-surface top, along +X, front +Z, base y = 0.
    static func counter(length: Float, depth: Float = 0.61, height: Float = 0.91, doors: Int = 4) -> Model {
        var m = Model(name: "counter")
        let carcass: MaterialKey = "laminate.white:E8E6E0", top: MaterialKey = "stone.solid-surface", kick: MaterialKey = "rubber"
        let topT: Float = 0.03, toe: Float = 0.1
        m.add(cuboid(V3(length - 0.02, height - topT - toe, depth - 0.06), material: carcass), Xform(translation: V3(0, toe + (height - topT - toe) / 2, -0.02)))
        m.add(cuboid(V3(length - 0.06, toe, depth - 0.12), material: kick), Xform(translation: V3(0, toe / 2, -0.05)))
        m.add(Prim.roundedBox(V3(length, topT, depth), radius: 0.006, bevelSegments: 2, material: top), Xform(translation: V3(0, height - topT / 2, 0)))
        m.add(Prim.roundedBox(V3(length, 0.1, 0.012), radius: 0.004, bevelSegments: 1, material: top), Xform(translation: V3(0, height + 0.05, -depth / 2 + 0.006)))
        let dw = (length - 0.02) / Float(doors)
        for i in 0..<doors {
            let x = -length / 2 + 0.01 + dw * (Float(i) + 0.5)
            m.add(Prim.roundedBox(V3(dw - 0.006, height - topT - toe - 0.2, 0.018), radius: 0.002, bevelSegments: 1, material: carcass),
                  Xform(translation: V3(x, toe + 0.003 + (height - topT - toe - 0.2) / 2, depth / 2 - 0.05)))
            m.add(Prim.roundedBox(V3(dw - 0.006, 0.16, 0.018), radius: 0.002, bevelSegments: 1, material: carcass),
                  Xform(translation: V3(x, height - topT - 0.09, depth / 2 - 0.05)))
            m.add(Prim.roundedBox(V3(0.12, 0.012, 0.022), radius: 0.004, bevelSegments: 1, material: "metal.stainless"),
                  Xform(translation: V3(x, height - topT - 0.09, depth / 2 - 0.03)))
            m.add(Prim.roundedBox(V3(0.012, 0.12, 0.022), radius: 0.004, bevelSegments: 1, material: "metal.stainless"),
                  Xform(translation: V3(x + (i % 2 == 0 ? 1 : -1) * (dw / 2 - 0.05), height - topT - 0.3, depth / 2 - 0.03)))
        }
        groundAO(&m, height: 0.15)
        return m
    }

    /// Stainless back table (instrument table) with a blue drape hanging over the sides.
    static func backTable(length: Float = 1.52, depth: Float = 0.76, height: Float = 0.86) -> Model {
        var m = Model(name: "back-table")
        let steel: MaterialKey = "metal.casework"
        m.add(Prim.roundedBox(V3(length, 0.03, depth), radius: 0.008, bevelSegments: 2, material: steel), Xform(translation: V3(0, height - 0.015, 0)))
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
            m.add(Prim.cylinder(radius: 0.016, height: height - 0.11, bevel: 0.002, segments: 12, bevelSegments: 1, material: steel),
                  Xform(translation: V3(sx * (length / 2 - 0.05), 0.08, sz * (depth / 2 - 0.05))))
            m.add(Prim.cylinder(radius: 0.035, height: 0.025, bevel: 0.006, segments: 14, bevelSegments: 1, material: "rubber"),
                  Xform(translation: V3(sx * (length / 2 - 0.05), 0.0, sz * (depth / 2 - 0.05))))
            m.add(Prim.roundedBox(V3(0.03, 0.05, 0.05), radius: 0.006, bevelSegments: 1, material: "metal.chrome"),
                  Xform(translation: V3(sx * (length / 2 - 0.05), 0.045, sz * (depth / 2 - 0.05))))
        }}
        m.add(cuboid(V3(length - 0.12, 0.02, depth - 0.12), material: steel), Xform(translation: V3(0, 0.25, 0)))
        // Drape: top sheet plus skirts hanging 35 cm on every side.
        let dr: MaterialKey = "drape.surgical", t: Float = 0.003, hang: Float = 0.35
        m.add(Prim.roundedBox(V3(length + 0.02, t, depth + 0.02), radius: 0.0012, bevelSegments: 1, material: dr), Xform(translation: V3(0, height + t / 2, 0)))
        for sz: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(length + 0.02, hang, t), radius: 0.0012, bevelSegments: 1, material: dr), Xform(translation: V3(0, height - hang / 2, sz * (depth / 2 + 0.01))))
        }
        for sx: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(t, hang, depth + 0.02), radius: 0.0012, bevelSegments: 1, material: dr), Xform(translation: V3(sx * (length / 2 + 0.01), height - hang / 2, 0)))
        }
        groundAO(&m, height: 0.1)
        return m
    }

    /// Wall sign: aluminium-edged panel with a printed label face, centered, back on z = 0, face +Z.
    static func sign(width: Float, height: Float, label: MaterialKey = "label.rx") -> Model {
        var m = Model(name: "sign")
        m.add(Prim.roundedBox(V3(width + 0.012, height + 0.012, 0.012), radius: 0.004, bevelSegments: 1, material: "metal.anodized"), Xform(translation: V3(0, 0, 0.006)))
        var s = Surface(material: label)
        let n = V3(0, 0, 1), z: Float = 0.0125
        let a = s.add(V3(-width / 2, height / 2, z), n, V2(0, 0)), b = s.add(V3(width / 2, height / 2, z), n, V2(1, 0))
        let c = s.add(V3(width / 2, -height / 2, z), n, V2(1, 1)), d = s.add(V3(-width / 2, -height / 2, z), n, V2(0, 1))
        s.quad(d, c, b, a)
        s.computeTangents()
        m.add(s)
        return m
    }

    /// Ceiling troffer field transforms over a room (2 x 4 ft panels on a grid).
    static func ceilingLights(_ W: Float, _ D: Float, _ H: Float, pitch: V2 = V2(2.4, 2.4)) -> [simd_float4x4] {
        var out: [simd_float4x4] = []
        let nx = max(1, Int((W / pitch.x).rounded(.down))), nz = max(1, Int((D / pitch.y).rounded(.down)))
        for i in 0..<nx { for k in 0..<nz {
            let x = -W / 2 + W / Float(nx) * (Float(i) + 0.5), z = -D / 2 + D / Float(nz) * (Float(k) + 0.5)
            out.append(place(x, z, y: H - 0.004).matrix)
        }}
        return out
    }
}
