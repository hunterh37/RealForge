import simd
import Foundation

/// Open-plan bench desk, 160 x 80 x 74 cm: 25 mm melamine top with 2 mm ABS edge banding, powder-coated
/// steel frame (two closed-loop 50 x 30 mm tube legs, 80 x 30 mm cross beam, top rails), a perforated
/// steel cable tray and a steel modesty panel hung under the back edge, an 80 mm black cable grommet
/// and screw-in levelling glides.
public struct OfficeDesk: RealAsset {
    public static let id = "office-desk"
    public static let summary = "Open-plan bench desk: 25 mm laminate top with ABS edging, powder-coated loop-leg steel frame, cable tray, modesty panel and grommet."
    public static let tags = ["prop", "office", "furniture", "metal"]
    public static let budget = 6_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20, distance: 1.1, studio: true)

    public var width: Float = 1.6
    public var depth: Float = 0.8
    public var height: Float = 0.74
    /// Melamine top tint.
    public var topColor = "F1F0EC"
    /// Powder-coat tint of the frame (F2F2F0 white, 1E1E1F black).
    public var frameColor = "F2F2F0"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [6])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, D = depth, H = height
        let top: MaterialKey = "laminate.white:\(topColor)"
        let edge: MaterialKey = "plastic.matte:\(topColor)"
        let steel: MaterialKey = "metal.powdercoat:\(frameColor)"
        let black: MaterialKey = "plastic.black"
        let t: Float = 0.025, under = H - t

        // Top: particleboard core read through the ABS band, melamine skin over it.
        m.add(Prim.roundedBox(V3(W, t - 0.001, D), radius: 0.002, bevelSegments: detail ? 2 : 1, material: edge),
              Xform(translation: V3(0, under + (t - 0.001) / 2, 0)))
        m.add(cuboid(V3(W - 0.003, 0.001, D - 0.003), material: top), Xform(translation: V3(0, H - 0.0006, 0)))

        // Loop legs: 50 x 30 mm tube bent into a closed rectangle in the YZ plane.
        let legX = W / 2 - 0.075, glide: Float = 0.012
        let loopH = under - 0.004 - glide - 0.05, loopD = D - 0.1
        let loop = Shape2D.roundedRect(loopD, loopH, radius: 0.045, segments: detail ? 4 : 2).map { V3(0, glide + 0.025 + loopH / 2 + $0.y, $0.x) }
        let tube = Shape2D.roundedRect(0.03, 0.05, radius: 0.004, segments: detail ? 2 : 1)
        for s: Float in [-1, 1] {
            let leg = Prim.sweep(tube, along: loop, up: V3(1, 0, 0), closedPath: true, caps: false, material: steel)
            m.add(leg, Xform(translation: V3(s * legX, 0, 0)).jittered(&rng, deg: 0.05, offset: 0.0002))
            // Levelling glides under both foot ends.
            for z: Float in [-1, 1] {
                let p = V3(s * legX, 0, z * (loopD / 2 - 0.05))
                m.add(Prim.cylinder(radius: 0.016, height: 0.006, bevel: 0.002, segments: 14, bevelSegments: 1, material: black), Xform(translation: p))
                if detail {
                    m.add(Prim.cylinder(radius: 0.005, height: glide + 0.002, bevel: 0.0005, segments: 8, bevelSegments: 1, material: steel),
                          Xform(translation: p + V3(0, 0.005, 0)))
                }
            }
        }
        // Top rails along Z on the legs, carrying the top (screw plates), and the cross beam along X.
        for s: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.06, 0.02, D - 0.08), radius: 0.003, bevelSegments: 1, material: steel),
                  Xform(translation: V3(s * legX, under - 0.01, 0)))
        }
        let beamLen = 2 * legX - 0.03
        m.add(Prim.roundedBox(V3(beamLen, 0.08, 0.03), radius: 0.003, bevelSegments: detail ? 2 : 1, material: steel),
              Xform(translation: V3(0, under - 0.06, -0.04)).jittered(&rng, deg: 0.03, offset: 0.0002))
        // Mid rails under the top (anti-sag), 40 x 20 mm.
        for z: Float in [-0.25, 0.25] {
            m.add(Prim.roundedBox(V3(beamLen, 0.02, 0.04), radius: 0.003, bevelSegments: 1, material: steel),
                  Xform(translation: V3(0, under - 0.01, z)))
        }

        // Cable tray: folded steel trough hung from the beam, slotted front wall.
        let trayL: Float = 1.1, trayW: Float = 0.16, trayH: Float = 0.11, trayY = under - 0.03 - trayH, trayZ: Float = -0.16
        let sheet: Float = 0.0015
        m.add(Prim.roundedBox(V3(trayL, sheet, trayW), radius: 0.0006, bevelSegments: 1, material: steel), Xform(translation: V3(0, trayY, trayZ)))
        for (dz, hh) in [(trayW / 2, trayH), (-trayW / 2, trayH * 0.7)] {
            m.add(Prim.roundedBox(V3(trayL, hh, sheet), radius: 0.0006, bevelSegments: 1, material: steel),
                  Xform(translation: V3(0, trayY + hh / 2, trayZ + dz)))
        }
        // Return lip on the front wall.
        m.add(Prim.roundedBox(V3(trayL, sheet, 0.012), radius: 0.0006, bevelSegments: 1, material: steel),
              Xform(translation: V3(0, trayY + trayH, trayZ + trayW / 2 - 0.006)))
        // Hangers to the beam.
        for x: Float in [-0.45, 0.45] {
            m.add(cuboid(V3(0.03, 0.04, 0.002), material: steel), Xform(translation: V3(x, under - 0.03 - 0.015, -0.056)))
            m.add(cuboid(V3(0.03, 0.002, 0.11), material: steel), Xform(translation: V3(x, trayY + trayH * 0.7 + 0.03, -0.11)))
            m.add(cuboid(V3(0.03, 0.03, 0.002), material: steel), Xform(translation: V3(x, trayY + trayH * 0.7 + 0.015, trayZ - trayW / 2 - 0.001)))
        }
        if detail {
            // Perforation: staggered slots on the front wall and the floor (dark shadowed openings).
            var slots = Surface(material: black)
            let slot = cuboid(V3(0.018, 0.005, 0.0005), material: black)
            for row in 0..<3 {
                for k in 0..<28 {
                    let x = -trayL / 2 + 0.03 + (Float(k) + (row % 2 == 0 ? 0 : 0.5)) * 0.037
                    guard x < trayL / 2 - 0.03 else { continue }
                    slots.append(slot, Xform(translation: V3(x, trayY + 0.025 + Float(row) * 0.028, trayZ + trayW / 2 + 0.0006)))
                }
            }
            m.add(slots)
        }

        // Modesty panel: 1.5 mm steel with folded top and bottom hems, on two brackets at the back.
        let mpL = 2 * legX - 0.06, mpH: Float = 0.32, mpZ = -D / 2 + 0.035
        m.add(Prim.roundedBox(V3(mpL, mpH, 0.012), radius: 0.003, bevelSegments: detail ? 2 : 1, material: steel),
              Xform(translation: V3(0, under - 0.02 - mpH / 2, mpZ)))
        for x in [-mpL / 2 + 0.1, mpL / 2 - 0.1] {
            m.add(cuboid(V3(0.04, 0.03, 0.03), material: steel), Xform(translation: V3(x, under - 0.015, mpZ + 0.01)))
        }

        // Cable grommet, 80 mm, back right of the top: flanged ring and slotted cap.
        let gp = V3(W / 2 - 0.3, H, -D / 2 + 0.12)
        m.add(Prim.lathe([V2(0.03, -t + 0.002), V2(0.031, -t + 0.002), V2(0.031, -0.001), V2(0.04, -0.0005), V2(0.04, 0.0012), V2(0.0385, 0.0025),
                          V2(0.03, 0.0025), V2(0.03, -0.004)], segments: detail ? 28 : 16, seamTile: 0.1, material: black),
              Xform(translation: gp))
        m.add(Prim.cylinder(radius: 0.0296, height: 0.002, bevel: 0.0006, segments: detail ? 28 : 16, bevelSegments: 1, material: black),
              Xform(translation: gp + V3(0, 0.0005, 0)))

        groundAO(&m, height: 0.12, floor: 0.55)
        return m
    }
}
