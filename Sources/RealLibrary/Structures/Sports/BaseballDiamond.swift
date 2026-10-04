import simd
import Foundation

/// Regulation baseball field surface. Origin at the point of home plate, center field along -Z, first
/// base toward +X. 90 ft base paths, 60 ft 6 in to the rubber on a 10 in, 18 ft mound, 95 ft infield arc,
/// 13 ft home circle with clay batter's boxes, chalked boxes and foul lines, checkerboard-mowed turf,
/// 15 ft red warning track along the wall line. Walls, bases and plate are separate assets placed with
/// `wallLine()`, `bases` and `foulPoles`.
public struct BaseballDiamond: RealAsset {
    public static let id = "baseball-diamond"
    public static let summary = "Regulation ball field: striped turf, clay infield skin, 10 in mound with rubber, chalked boxes and foul lines, warning track."
    public static let tags = ["structure", "sports", "ground", "outdoor", "park"]
    public static let budget = 24_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 180, elevation: 38, distance: 0.62, ground: false)

    /// Base path length (90 ft).
    public var basePath: Float = 27.432
    /// Home plate point to the front of the pitching rubber (60 ft 6 in).
    public var rubberDistance: Float = 18.44
    /// Grass-line arc radius about the front of the rubber (95 ft).
    public var infieldArc: Float = 28.96
    /// Wall distance down the lines (330 ft) and to straightaway center (400 ft).
    public var lineDistance: Float = 100.6
    public var centerDistance: Float = 121.9
    /// Foul ground: distance from each foul line out to the side wall, and home plate to the backstop (60 ft).
    public var foulWidth: Float = 16
    public var backstopDistance: Float = 18.3
    /// Warning track width (15 ft).
    public var trackWidth: Float = 4.6
    public var turf: MaterialKey = "turf.ballpark"
    public var clay: MaterialKey = "ground.infield"
    public var moundClay: MaterialKey = "ground.mound-clay"
    public var track: MaterialKey = "ground.warning-track"
    public var chalk: MaterialKey = "paint.field-white"
    public init() {}

    static let d1 = V2(0.70710678, -0.70710678)   // toward first base (x, z)
    static let d3 = V2(-0.70710678, -0.70710678)  // toward third base

    /// Base centers (x, z): first, second, third. Home plate point is the origin.
    public var bases: [V2] { [Self.d1 * basePath, (Self.d1 + Self.d3) * basePath, Self.d3 * basePath] }
    /// Foul pole positions (left, right) on the wall line.
    public var foulPoles: [V2] { [Self.d3 * lineDistance, Self.d1 * lineDistance] }
    /// Front of the rubber (x, z).
    public var rubber: V2 { V2(0, -rubberDistance) }

    /// Wall distance from home plate at an angle from straightaway center (degrees, |a| <= 45).
    public func wallDistance(degrees a: Float) -> Float {
        let t = min(1, abs(a) / 45)
        return centerDistance + (lineDistance - centerDistance) * (0.55 * t + 0.45 * t * t)
    }

    /// Inside the playing surface, `shrink` meters in from the wall line.
    public func inside(_ p: V2, shrink s: Float = 0) -> Bool {
        let u = simd_dot(p, Self.d1), v = simd_dot(p, Self.d3)
        if u < -(foulWidth - s) || v < -(foulWidth - s) || p.y > backstopDistance - s { return false }
        let a = atan2(p.x, -p.y) * 180 / .pi
        if abs(a) <= 45 { return simd_length(p) < wallDistance(degrees: a) - s }
        return (a > 0 ? u : v) < lineDistance - s
    }

    static let rayCenter = V2(0, -32)
    /// Wall line (x, z) as a closed outline, 720 samples clockwise from straightaway center.
    public func wallLine(samples: Int = 720, shrink: Float = 0) -> [V2] {
        BallKit.rayOutline(center: Self.rayCenter, count: samples, maxRadius: 200, step: 0.5) { inside($0, shrink: shrink) }
    }

    /// Mesh in design coordinates (origin as documented above, before centering).
    func model(seed: UInt64) -> Model {
        var m = Model(name: Self.id)
        let d1 = Self.d1, d3 = Self.d3
        let yClay: Float = 0.006, yGrass: Float = 0.03, lineW: Float = 0.1016

        // Turf out to the track, track out to the wall line.
        let outer = wallLine(), inner = wallLine(shrink: trackWidth)
        m.add(BallKit.fan(inner, center: Self.rayCenter, y: 0, material: turf, rotatedUV: true))
        m.add(BallKit.band(outer: outer, inner: inner, y: 0, material: track))

        // Infield skin: fair-territory wedge of the arc, base path strips, home circle, foul cutouts.
        let c = rubber
        func arcHit(_ d: V2) -> Float {
            let b = simd_dot(d, c), q = simd_length_squared(c) - infieldArc * infieldArc
            return b + (b * b - q).squareRoot()
        }
        let t1 = arcHit(d1), t3 = arcHit(d3)
        let p1 = d1 * t1, p3 = d3 * t3
        let a1 = atan2(p1.y - c.y, p1.x - c.x), a3 = atan2(p3.y - c.y, p3.x - c.x)
        var wedge: [V2] = [V2(0, 0)]
        let arcN = 64
        var span = a3 - a1; if span > 0 { span -= 2 * .pi }
        for k in 0...arcN {
            let a = a1 + span * Float(k) / Float(arcN)
            wedge.append(c + V2(cos(a), sin(a)) * infieldArc)
        }
        let wc = wedge.reduce(V2.zero, +) / Float(wedge.count)
        m.add(BallKit.fan(wedge, center: wc, y: yClay, material: clay))
        let pathW: Float = 1.83
        for (d, t) in [(d1, t1), (d3, t3)] {
            m.add(BallKit.strip(V2(0, 0), d * (t + 0.6), width: pathW, y: yClay, material: clay))
            // Rounded foul-side cutout where the arc crosses the line.
            m.add(BallKit.disk(center: d * t, radius: 1.6, y: yClay, rings: 1, sectors: 24, material: clay))
        }
        let homeC = V2(0, -0.22)
        m.add(BallKit.disk(center: homeC, radius: 3.96, y: yClay, rings: 2, sectors: 64, material: clay))
        // On-deck circles in foul ground.
        for sx: Float in [-1, 1] {
            m.add(BallKit.disk(center: V2(sx * 11.5, 0.5), radius: 0.76, y: yClay, rings: 1, sectors: 28, material: clay))
        }

        // Infield grass: inside the base paths, cut back around home and the bags; raised lip.
        let inset = pathW / 2
        let bs = bases
        let grassC = V2(0, -basePath * 0.70710678)
        let grass = BallKit.rayOutline(center: grassC, count: 256, maxRadius: 30, step: 0.2) { p in
            let u = simd_dot(p, d1), v = simd_dot(p, d3)
            guard u > inset, v > inset, u < basePath - inset, v < basePath - inset else { return false }
            if simd_distance(p, homeC) < 3.96 + 0.05 { return false }
            for b in bs where simd_distance(p, b) < 3.2 { return false }
            return true
        }
        m.add(BallKit.fan(grass, center: grassC, y: yGrass, material: turf, rotatedUV: true))
        m.add(BallKit.skirt(grass, top: yGrass, bottom: 0, material: turf))

        // Mound: 18 ft circle rising 10 in to a 5 x 3 ft table, falling 1 in per ft toward home.
        let moundC = V2(0, -(rubberDistance - 0.46))
        let rise: Float = 0.254, R: Float = 2.74
        m.add(BallKit.disk(center: moundC, radius: R, y: yGrass - 0.004, rings: 14, sectors: 56, material: moundClay) { r in
            if r < 0.6 { return rise }
            let t = min(1, (r - 0.6) / (R - 0.6))
            let lin = rise * (1 - t)
            return lin * (1 - 0.25 * t) + 0.004 * (1 - t)
        })
        let mTop = yGrass - 0.004 + rise
        // Pitching rubber: 24 x 6 in slab, 6 mm proud, front edge on the 60 ft 6 in mark.
        m.add(Prim.roundedBox(V3(0.61, 0.05, 0.152), radius: 0.006, bevelSegments: 2, material: "rubber.plate"),
              Xform(translation: V3(c.x, mTop - 0.019, c.y - 0.076)))
        // Batter's boxes and catcher's area in packed clay, then chalk.
        let boxIn: Float = 0.216 + 0.152, boxOut = boxIn + 1.22
        let boxFront: Float = -0.22 - 0.915, boxBack: Float = -0.22 + 0.915
        for sx: Float in [-1, 1] {
            let xs = [sx * (boxIn - 0.12), sx * (boxOut + 0.15)]
            m.add(BallKit.quad([V2(xs[0], boxFront - 0.2), V2(xs[1], boxFront - 0.2), V2(xs[1], boxBack + 0.2), V2(xs[0], boxBack + 0.2)],
                               y: yClay + 0.002, material: moundClay))
        }
        m.add(BallKit.quad([V2(-0.55, 0.2), V2(0.55, 0.2), V2(0.55, 2.6), V2(-0.55, 2.6)], y: yClay + 0.002, material: moundClay))
        let yChalkClay = yClay + 0.005
        var lines = Surface(material: chalk)
        for sx: Float in [-1, 1] {
            lines.append(BallKit.outline([V2(sx * boxIn, boxFront), V2(sx * boxOut, boxFront), V2(sx * boxOut, boxBack), V2(sx * boxIn, boxBack)],
                                         width: 0.076, y: yChalkClay, material: chalk))
            // Catcher's box: lines back from the boxes' rear inner corners, 8 ft, closed 43 in wide.
            lines.append(BallKit.strip(V2(sx * boxIn, boxBack), V2(sx * 0.546, boxBack + 2.44), width: 0.076, y: yChalkClay, material: chalk))
        }
        lines.append(BallKit.strip(V2(-0.546, boxBack + 2.44), V2(0.546, boxBack + 2.44), width: 0.076, y: yChalkClay, material: chalk))
        // Foul lines: from the box corners over the clay, then the turf, to the track.
        for (d, t) in [(d1, t1), (d3, t3)] {
            let start = d * 2.25, clayEnd = d * (t + 0.5)
            lines.append(BallKit.strip(start, clayEnd, width: lineW, y: yChalkClay, material: chalk))
            let end = d * (lineDistance - trackWidth)
            lines.append(BallKit.strip(clayEnd, end, width: lineW, y: 0.004, material: chalk))
        }
        // Runner's lane: last 45 ft to first base, 3 ft outside the line.
        let n1 = V2(d1.y, -d1.x) * -0.914
        lines.append(BallKit.strip(d1 * (basePath - 13.7) + n1, d1 * basePath + n1, width: 0.076, y: yChalkClay, material: chalk))
        lines.append(BallKit.strip(d1 * (basePath - 13.7), d1 * (basePath - 13.7) + n1, width: 0.076, y: yChalkClay, material: chalk))
        // Coach's boxes: 20 x 10 ft, 15 ft from the lines, open toward the field.
        for (d, sgn) in [(d1, Float(-1)), (d3, Float(1))] {
            let nrm = V2(d.y, -d.x) * sgn
            let a = d * (basePath - 1.5) + nrm * 4.57, b = d * (basePath + 4.6) + nrm * 4.57
            lines.append(BallKit.strip(a, a + nrm * 3.05, width: 0.076, y: 0.004, material: chalk))
            lines.append(BallKit.strip(a + nrm * 3.05, b + nrm * 3.05, width: 0.076, y: 0.004, material: chalk))
        }
        lines.computeTangents()
        m.add(lines)
        return m
    }

    /// The mesh is re-centered on X/Z; `anchor` is where the design origin landed in mesh coordinates.
    /// Place the asset at `designPoint - anchor` (rotated with it) to put the design origin on `designPoint`.
    public func anchor(seed: UInt64 = 1) -> V2 { -BallKit.centerXZ(model(seed: seed)) }

    public func build(seed: UInt64) -> LODModel {
        let m = model(seed: seed), c = BallKit.centerXZ(m)
        return LODModel(m.transformed(Xform(translation: V3(-c.x, 0, -c.y))))
    }
}
