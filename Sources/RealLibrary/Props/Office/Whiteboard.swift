import simd
import Foundation

/// Mobile double-sided whiteboard: 150 x 100 cm enamel steel board in a satin anodized aluminum frame
/// with black corner caps, pivoting at mid-height between two steel A-frame stands (25 mm round tube,
/// 40 x 20 mm foot bars, lower stretcher) on four braked casters. Aluminum marker tray with three
/// markers and a felt eraser; a meeting's worth of marker writing on the front face.
public struct Whiteboard: RealAsset {
    public static let id = "whiteboard"
    public static let summary = "Mobile double-sided whiteboard on a steel A-frame stand with casters, aluminum frame, marker tray, markers, eraser and notes."
    public static let tags = ["prop", "office", "furniture", "metal"]
    public static let budget = 9_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 22, elevation: 8, distance: 1.05, studio: true)

    public var boardWidth: Float = 1.5
    public var boardHeight: Float = 1.0
    /// Height of the board center (pivot).
    public var pivotHeight: Float = 1.2
    public var surface: MaterialKey = "plastic.gloss:F6F6F3"
    public var frame: MaterialKey = "metal.anodized"
    public var stand: MaterialKey = "metal.powdercoat:D8D8D4"
    /// Marker writing on the front face.
    public var writing = true
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [6])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let bw = boardWidth, bh = boardHeight, py = pivotHeight
        let black: MaterialKey = "plastic.black"
        let inks: [MaterialKey] = [black, "plastic.matte:1E4BA6", "plastic.matte:BF252B"]
        let frameW: Float = 0.02, frameD: Float = 0.028

        // Board: enamel faces both sides, aluminum frame swept around, corner caps.
        m.add(Prim.roundedBox(V3(bw - 0.02, bh - 0.02, 0.022), radius: 0.002, bevelSegments: 1, material: surface), Xform(translation: V3(0, py, 0)))
        let ring = Shape2D.roundedRect(bw - frameW, bh - frameW, radius: 0.006, segments: 1).map { V3($0.x, py + $0.y, 0) }
        let prof = Shape2D.roundedRect(frameD, frameW, radius: 0.004, segments: detail ? 2 : 1)
        m.add(Prim.sweep(prof, along: ring, up: V3(0, 0, 1), closedPath: true, caps: false, material: frame))
        for sx: Float in [-1, 1] { for sy: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.032, 0.032, frameD + 0.004), radius: 0.006, bevelSegments: 1, material: black),
                  Xform(translation: V3(sx * (bw / 2 - 0.012), py + sy * (bh / 2 - 0.012), 0)))
        }}

        // A-frame stands at both ends.
        let sx = bw / 2 + 0.045, footY: Float = 0.11, apexY = py + bh / 2 + 0.15, spread: Float = 0.3
        let tube = Shape2D.circle(0.0125, segments: detail ? 14 : 8)
        for s: Float in [-1, 1] {
            let x = s * sx
            for z: Float in [-1, 1] {
                m.add(Prim.sweep(tube, along: [V3(x, footY + 0.01, z * spread), V3(x, apexY - 0.02, z * 0.012)], material: stand))
            }
            m.add(Prim.roundedBox(V3(0.04, 0.05, 0.06), radius: 0.01, bevelSegments: 1, material: black), Xform(translation: V3(x, apexY - 0.02, 0)))
            // Foot bar with end caps, casters under both ends.
            m.add(Prim.roundedBox(V3(0.04, 0.02, 2 * spread + 0.08), radius: 0.004, bevelSegments: 1, material: stand),
                  Xform(translation: V3(x, footY, 0)))
            // Pivot crossbar between the legs, pivot pin into the frame and the clamp knob outside.
            let zl = spread * (apexY - py) / (apexY - footY)
            m.add(Prim.sweep(Shape2D.circle(0.009, segments: detail ? 12 : 6), along: [V3(x, py, -zl), V3(x, py, zl)], material: stand))
            m.add(Prim.cylinder(radius: 0.008, height: sx - bw / 2 + 0.01, bevel: 0.001, segments: 12, bevelSegments: 1, material: frame),
                  Xform(translation: V3(s * (bw / 2 - 0.005), py, 0), rotation: simd_quatf(degrees: -s * 90, axis: V3(0, 0, 1))))
            m.add(Prim.cylinder(radius: 0.024, height: 0.022, bevel: 0.005, segments: detail ? 14 : 8, bevelSegments: 1, material: black),
                  Xform(translation: V3(x + s * 0.012, py, 0), rotation: simd_quatf(degrees: -s * 90, axis: V3(0, 0, 1))))
            for z: Float in [-1, 1] {
                // Twin-wheel style caster: stem, swivel housing, two 50 mm wheels, brake pedal.
                let p = V3(x, 0, z * (spread + 0.01))
                let yaw = simd_quatf(degrees: rng.float(-30...30), axis: .up)
                m.add(Prim.cylinder(radius: 0.008, height: footY - 0.05, bevel: 0.001, segments: 10, bevelSegments: 1, material: frame),
                      Xform(translation: p + V3(0, 0.048, 0)))
                m.add(Prim.roundedBox(V3(0.026, 0.03, 0.05), radius: 0.008, bevelSegments: 1, material: black),
                      Xform(translation: p + V3(0, 0.035, 0), rotation: yaw))
                for w: Float in [-1, 1] {
                    m.add(Prim.cylinder(radius: 0.025, height: 0.014, bevel: 0.004, segments: detail ? 14 : 8, bevelSegments: 1, material: black),
                          Xform(translation: p + yaw.act(V3(w * 0.02, 0.025, 0.006)), rotation: yaw * simd_quatf(degrees: -w * 90, axis: V3(0, 0, 1))))
                }
                if detail {
                    m.add(Prim.roundedBox(V3(0.02, 0.005, 0.022), radius: 0.002, bevelSegments: 1, material: frame),
                          Xform(translation: p + yaw.act(V3(0, 0.045, -0.03))))
                }
            }
        }
        // Lower stretcher between the foot bars.
        m.add(Prim.sweep(Shape2D.roundedRect(0.02, 0.03, radius: 0.004, segments: 1), along: [V3(-sx, footY + 0.005, 0), V3(sx, footY + 0.005, 0)],
                         up: V3(0, 0, 1), material: stand))

        // Marker tray: extruded J-profile under the board front, 60 cm, end caps.
        let ty = py - bh / 2, front: Float = 0.014
        let trayProfile: [V2] = [V2(front, ty + 0.02), V2(front, ty - 0.026), V2(front + 0.06, ty - 0.026), V2(front + 0.063, ty - 0.023),
                                 V2(front + 0.063, ty - 0.008), V2(front + 0.06, ty - 0.008), V2(front + 0.06, ty - 0.023), V2(front + 0.003, ty - 0.023),
                                 V2(front + 0.003, ty + 0.02)].map { V2(-$0.x, $0.y) }
        let trayL: Float = 0.6
        m.add(Prim.extrude(trayProfile, depth: trayL, bevel: 0.0008, bevelSegments: 1, material: frame),
              Xform(rotation: simd_quatf(degrees: 90, axis: .up)))
        for e: Float in [-1, 1] {
            m.add(cuboid(V3(0.004, 0.02, 0.063), material: black), Xform(translation: V3(e * (trayL / 2 + 0.002), ty - 0.016, front + 0.0315)))
        }
        // Markers lying in the tray (body, colored cap) and the eraser.
        let floorY = ty - 0.023
        for (i, ink) in inks.enumerated() {
            let r: Float = 0.0085
            let z = front + 0.012 + Float(i) * 0.016 + rng.float(-0.002...0.002)
            let x0 = -0.2 + Float(i) * 0.04 + rng.float(-0.02...0.02)
            m.add(Prim.cylinder(radius: r, height: 0.1, bevel: 0.002, segments: detail ? 12 : 6, bevelSegments: 1, material: "plastic.white"),
                  Xform(translation: V3(x0, floorY + r, z), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
            m.add(Prim.cylinder(radius: r + 0.0006, height: 0.042, bevel: 0.003, segments: detail ? 12 : 6, bevelSegments: 1, material: ink),
                  Xform(translation: V3(x0 + 0.098, floorY + r, z), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
            if detail {
                m.add(Prim.cylinder(radius: r * 0.7, height: 0.006, bevel: 0.002, segments: 10, bevelSegments: 1, material: ink),
                      Xform(translation: V3(x0 - 0.004, floorY + r, z), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
                // Pocket clip on the cap.
                m.add(cuboid(V3(0.03, 0.0015, 0.004), material: ink), Xform(translation: V3(x0 + 0.118, floorY + 2 * r + 0.0005, z)))
            }
        }
        let ex: Float = 0.2
        m.add(Prim.roundedBox(V3(0.14, 0.012, 0.05), radius: 0.003, bevelSegments: 1, material: "fabric.upholstery:4A4A4C"),
              Xform(translation: V3(ex, floorY + 0.006, front + 0.032)))
        m.add(Prim.roundedBox(V3(0.14, 0.022, 0.048), radius: 0.008, bevelSegments: 1, material: black),
              Xform(translation: V3(ex, floorY + 0.023, front + 0.032)))

        if writing && detail { notes(&m, seed: seed, z: 0.0112, inks: inks) }
        groundAO(&m, height: 0.12, floor: 0.55)
        return m
    }

    /// Marker writing: lines of looped cursive (prolate cycloids), a boxed diagram with an arrow and a
    /// red underline. Each stroke is a flat 2.4 mm ribbon 0.3 mm proud of the board.
    func notes(_ m: inout Model, seed: UInt64, z: Float, inks: [MaterialKey]) {
        var rng = SeededRNG(seed: seed &+ 7)
        let py = pivotHeight, bw = boardWidth, bh = boardHeight
        let ribbon: [V2] = [V2(0.0003, 0), V2(-0.0001, 0.0015), V2(-0.0001, -0.0015)]
        func stroke(_ pts: [V3], _ ink: MaterialKey) {
            guard pts.count > 1 else { return }
            m.add(Prim.sweep(ribbon, along: pts, up: V3(0, 0, 1), material: ink))
        }
        let left = -bw / 2 + 0.09, top = py + bh / 2 - 0.1
        // Heading and three lines of text, left half.
        for line in 0..<3 {
            var x = left + (line == 0 ? 0 : 0.03)
            let y = top - Float(line) * 0.1 - (line == 0 ? 0 : 0.02)
            let ink = line == 0 ? inks[1] : inks[0]
            let end = left + (line == 0 ? 0.36 : rng.float(0.42...0.56))
            while x < end - 0.04 {
                let letters = rng.int(2...5)
                let a: Float = line == 0 ? 0.036 : 0.028
                var pts: [V3] = []
                let per = 6
                for k in 0...(letters * per) {
                    let t = Float(k) / Float(per)
                    let li = min(letters - 1, Int(t))
                    var lr = SeededRNG(seed: UInt64(li * 7 + line * 101) &+ seed)
                    let tall: Float = lr.chance(0.25) ? 1.9 : lr.float(0.8...1.15)
                    let c: Float = (line == 0 ? 0.03 : 0.022) * tall
                    pts.append(V3(x + a * t - a * 0.3 * sin(2 * .pi * t), y + c * 0.5 * (1 - cos(2 * .pi * t)) + 0.002 * t, z))
                }
                stroke(pts, ink)
                x += a * Float(letters) + 0.03
            }
        }
        // Red underline under the heading.
        stroke(stride(from: Float(0), through: 1, by: 0.1).map { t in V3(left - 0.01 + t * 0.38, top - 0.014 + 0.003 * sin(t * 5), z) }, inks[2])
        // Diagram on the right: two boxes and an arrow.
        let bx = 0.25 as Float, by = py + 0.08
        func box(_ c: V2, _ w: Float, _ h: Float, _ ink: MaterialKey) {
            var pts: [V3] = []
            let corners = [V2(-w, -h), V2(w, -h), V2(w, h), V2(-w, h), V2(-w, -h + 0.006)]
            for i in 0..<(corners.count - 1) {
                for k in 0..<4 {
                    let t = Float(k) / 4
                    let p = c + corners[i] * 0.5 + (corners[i + 1] - corners[i]) * 0.5 * t
                    pts.append(V3(p.x + rng.float(-0.001...0.001), p.y + rng.float(-0.001...0.001), z))
                }
            }
            stroke(pts, ink)
        }
        box(V2(bx, by + 0.12), 0.2, 0.09, inks[1])
        box(V2(bx + 0.02, by - 0.16), 0.24, 0.09, inks[1])
        stroke([V3(bx, by + 0.075, z), V3(bx + 0.002, by - 0.04, z), V3(bx + 0.004, by - 0.105, z)], inks[2])
        stroke([V3(bx - 0.015, by - 0.085, z), V3(bx + 0.004, by - 0.107, z), V3(bx + 0.02, by - 0.083, z)], inks[2])
        // Scribbled labels inside the boxes.
        for (c, w) in [(V2(bx - 0.06, by + 0.115), Float(0.12)), (V2(bx - 0.07, by - 0.165), Float(0.15))] {
            var pts: [V3] = []
            for k in 0...Int(w / 0.004) {
                let t = Float(k) * 0.004 / 0.024
                pts.append(V3(c.x + 0.024 * t - 0.007 * sin(2 * .pi * t), c.y + 0.009 * (1 - cos(2 * .pi * t)), z))
            }
            stroke(pts, inks[0])
        }
    }
}
