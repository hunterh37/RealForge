import simd
import Foundation

/// Stadium light tower, 30 m: tapered galvanized steel pole on a concrete pier, cage ladder with rest
/// platforms, a lattice crossarm frame carrying 4 x 3 floodlight fixtures (cast housings, glass fronts,
/// visors) aimed down toward -Z (the field), and a control cabinet at the base. Origin at the pole base.
public struct LightTower: RealAsset {
    public static let id = "light-tower"
    public static let summary = "Stadium light tower, 30 m: tapered galvanized pole, cage ladder, crossarm frame with 12 aimed floodlights, base cabinet."
    public static let tags = ["structure", "sports", "light", "metal", "outdoor"]
    public static let budget = 22_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 150, elevation: 8, distance: 1.0)

    public var height: Float = 30
    public var columns: Int = 4
    public var rowsOfLights: Int = 3
    /// Downward aim of the fixtures (degrees below horizontal).
    public var aim: Float = 28
    public var steel: MaterialKey = "metal.galvanized"
    public var housing: MaterialKey = "metal.painted:3A3D40"
    /// Lamp face: `glass.lamp` (lit) or `glass.pane` (off).
    public var lens: MaterialKey = "glass.pane"
    public init() {}

    func fixture(_ m: inout Model, at p: V3, detail: Bool) {
        var f = Model(name: "fixture")
        // Square cast housing 0.6 m with a rounded back, lens on the front (-Z), visor above the lens.
        f.add(Prim.superellipsoid(V3(0.62, 0.62, 0.32), exponent: 5, subdivisions: detail ? 6 : 3, material: housing), Xform(translation: V3(0, 0, 0.1)))
        f.add(Prim.roundedBox(V3(0.56, 0.56, 0.02), radius: 0.01, bevelSegments: 1, material: lens), Xform(translation: V3(0, 0, -0.06)))
        if detail {
            f.add(Prim.roundedBox(V3(0.66, 0.012, 0.3), radius: 0.004, bevelSegments: 1, material: housing), Xform(translation: V3(0, 0.33, -0.18)))
            for sx: Float in [-1, 1] {
                f.add(Prim.roundedBox(V3(0.012, 0.66, 0.28), radius: 0.004, bevelSegments: 1, material: housing), Xform(translation: V3(sx * 0.33, 0, -0.17)))
            }
            // Yoke bracket.
            f.add(BallKit.pipe(V3(-0.38, 0, 0.12), V3(0.38, 0, 0.12), radius: 0.02, sides: 6, material: steel))
        }
        m.add(f, Xform(translation: p, rotation: simd_quatf(degrees: -aim, axis: V3(1, 0, 0))))
    }

    func model(detail: Bool) -> Model {
        var m = Model(name: Self.id)
        let r0: Float = 0.38, r1: Float = 0.17
        // Pier and anchor collar.
        m.add(Prim.cylinder(radius: 0.6, height: 0.5, bevel: 0.02, segments: 24, material: "concrete.rough"))
        m.add(Prim.cylinder(radius: r0 + 0.09, height: 0.04, bevel: 0.005, segments: 24, material: steel), Xform(translation: V3(0, 0.5, 0)))
        // Tapered pole: lathe with slip joints every 10 m.
        var prof: [V2] = [V2(r0, 0.5)]
        for k in 1...3 {
            let yk = 0.5 + (height - 0.5) * Float(k) / 3
            let rk = r0 + (r1 - r0) * Float(k) / 3
            prof.append(V2(rk + 0.012, yk - 0.4)); prof.append(V2(rk, yk - 0.38))
            if k < 3 { prof.append(V2(rk, yk)) } else { prof.append(V2(rk, height)); prof.append(V2(0, height)) }
        }
        m.add(Prim.lathe(prof, segments: detail ? 24 : 12, seamTile: 1, material: steel))
        // Ladder with cage on the back (+Z) side.
        if detail {
            let lz: Float = 0.45
            for sx: Float in [-0.2, 0.2] { m.add(BallKit.pipe(V3(sx, 2.5, lz), V3(sx, height - 0.5, lz), radius: 0.015, sides: 6, material: steel)) }
            var y: Float = 2.6
            while y < height - 0.6 { m.add(BallKit.pipe(V3(-0.2, y, lz), V3(0.2, y, lz), radius: 0.01, sides: 5, material: steel)); y += 0.3 }
            var cy: Float = 3.0
            while cy < height - 1 {
                m.add(Prim.torus(major: 0.38, minor: 0.012, segments: 16, sides: 5, arc: .pi, material: steel),
                      Xform(translation: V3(0, cy, lz), rotation: simd_quatf(degrees: 180, axis: .up)))
                cy += 1.2
            }
            for a: Float in [-0.35, 0, 0.35] { m.add(BallKit.pipe(V3(a, 3.0, lz + 0.38 - abs(a) * 0.5), V3(a, height - 1.2, lz + 0.38 - abs(a) * 0.5), radius: 0.01, sides: 5, material: steel)) }
            // Base cabinet.
            m.add(Prim.roundedBox(V3(0.6, 0.9, 0.3), radius: 0.02, bevelSegments: 2, material: "metal.painted:6E7468"), Xform(translation: V3(0, 1.4, 0.5)))
            m.add(BallKit.pipe(V3(0, 0.95, 0.5), V3(0, 0.5, 0.42), radius: 0.03, sides: 8, material: steel))
        }
        // Crossarm frame: horizontal arms per light row on the field side, vertical ties, catwalk.
        let w = Float(columns) * 0.75, top = height + 0.4
        let fz: Float = -0.75
        for r in 0..<rowsOfLights {
            let yy = top + Float(r) * 0.8
            m.add(Prim.roundedBox(V3(w + 0.3, 0.1, 0.1), radius: 0.006, bevelSegments: 1, material: steel), Xform(translation: V3(0, yy - 0.42, fz + 0.32)))
            for c in 0..<columns {
                let x = (Float(c) - Float(columns - 1) / 2) * 0.75
                fixture(&m, at: V3(x, yy, fz), detail: detail)
            }
        }
        for sx: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.1, Float(rowsOfLights) * 0.8 + 0.2, 0.1), radius: 0.006, bevelSegments: 1, material: steel),
                  Xform(translation: V3(sx * (w / 2 + 0.1), top - 0.42 + Float(rowsOfLights - 1) * 0.4, fz + 0.32)))
        }
        // Mount: two arms from the pole top to the frame.
        for yy in [top - 0.42, top - 0.42 + Float(rowsOfLights - 1) * 0.8] {
            m.add(Prim.roundedBox(V3(0.12, 0.12, 0.6), radius: 0.006, bevelSegments: 1, material: steel), Xform(translation: V3(0, yy, fz + 0.32 + 0.3)))
        }
        m.add(Prim.roundedBox(V3(0.14, Float(rowsOfLights - 1) * 0.8 + 0.4, 0.14), radius: 0.006, bevelSegments: 1, material: steel),
              Xform(translation: V3(0, top - 0.42 + Float(rowsOfLights - 1) * 0.4 - 0.2, 0)))
        if detail {
            // Catwalk grating under the lowest row.
            m.add(Prim.roundedBox(V3(w + 0.3, 0.03, 0.6), radius: 0.004, bevelSegments: 1, material: "metal.painted:4A4C4E"), Xform(translation: V3(0, top - 0.75, fz + 0.62)))
            m.add(BallKit.pipe(V3(-w / 2 - 0.15, top + 0.25, fz + 0.9), V3(w / 2 + 0.15, top + 0.25, fz + 0.9), radius: 0.02, sides: 6, material: steel))
        }
        groundAO(&m, height: 0.6, floor: 0.6)
        return m
    }

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(detail: true), model(detail: false)], switchDistances: [45])
    }
}
