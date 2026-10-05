import simd
import Foundation

/// End-grain cutting board, 45 x 30 x 4 cm: maple and walnut checkerboard blocks 3.75 cm square, rounded
/// corners and edges, a juice groove 1 cm wide around the top, finger grips routed into both short ends,
/// knife scoring in the end grain. Long axis along X; the top face sits at `topY`.
public struct CuttingBoard: RealAsset {
    public static let id = "cutting-board"
    public static let summary = "End-grain cutting board: maple and walnut checkerboard, juice groove, finger grips, knife scoring."
    public static let tags = ["prop", "kitchen", "cookware", "wood", "handheld"]
    public static let budget = 10_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 38, distance: 0.75, studio: true)

    /// Length along X (m).
    public var length: Float = 0.45
    /// Width along Z (m).
    public var width: Float = 0.3
    /// Thickness (m).
    public var thickness: Float = 0.04
    /// Plan corner radius (m).
    public var cornerRadius: Float = 0.035
    /// Edge round-over radius (m).
    public var edgeRadius: Float = 0.004
    /// Juice groove: inset from the edge, width and depth (m).
    public var grooveInset: Float = 0.02
    public var grooveWidth: Float = 0.011
    public var grooveDepth: Float = 0.0045
    /// Finger grip depth into each short end (m).
    public var gripDepth: Float = 0.012
    /// Top and bottom faces (end grain).
    public var top: MaterialKey = "wood.butcher-block"
    /// Edges (side grain).
    public var side: MaterialKey = "wood.butcher-block-side"
    public init() {}

    /// Height of the cutting surface (m).
    public var topY: Float { thickness }
    /// Usable flat top inside the groove (x, z half extents, m).
    public var workArea: V2 { V2(length / 2 - grooveInset - grooveWidth, width / 2 - grooveInset - grooveWidth) }

    /// Outline in plan (x, -z), counter-clockwise, dense where the finger grips are cut.
    func outline(dense: Float, coarse: Float) -> [V2] {
        let base = Shape2D.roundedRect(length, width, radius: cornerRadius, segments: 8)
        var out: [V2] = []
        for i in base.indices {
            let a = base[i], b = base[(i + 1) % base.count]
            let mid = (a + b) / 2
            let s = abs(mid.x) > length / 2 - 0.01 && abs(mid.y) < 0.075 ? dense : coarse
            let n = max(1, Int((simd_distance(a, b) / s).rounded(.up)))
            for k in 0..<n { out.append(a + (b - a) * (Float(k) / Float(n))) }
        }
        return Shape2D.deduped(out)
    }

    func model(dense: Float, coarse: Float, sideRings: Int) -> Model {
        let o = outline(dense: dense, coarse: coarse)
        let T = thickness, b = edgeRadius
        // Sides: bottom round-over, straight edge (rings for the grips), top round-over.
        var rings: [[V3]] = []
        for k in 0...3 { let t = Float(k) / 3 * .pi / 2; rings.append(Prim.ring(Shape2D.offset(o, -b * (1 - sin(t))), y: b * (1 - cos(t)))) }
        for k in 1..<sideRings { rings.append(Prim.ring(o, y: b + (T - 2 * b) * Float(k) / Float(sideRings))) }
        for k in 0...3 { let t = Float(k) / 3 * .pi / 2; rings.append(Prim.ring(Shape2D.offset(o, -b * (1 - cos(t))), y: T - b + b * sin(t))) }
        var sides = Prim.loft(rings, material: side)
        let L = length, gd = gripDepth
        sides.deform { p in
            guard abs(p.x) > L / 2 - 0.02 else { return p }
            let zf = 1 - smoothstep(0.045, 0.065, abs(p.z))
            let yy = (p.y - T * 0.5) / (T * 0.34)
            let yf = max(0, 1 - yy * yy)
            let d = gd * zf * sqrt(yf)
            return V3(p.x - (p.x > 0 ? d : -d), p.y, p.z)
        }
        // Top: flat band, juice groove (half-round), flat field closed with a fan.
        var top: [[V3]] = [Prim.ring(Shape2D.offset(o, -b), y: T), Prim.ring(Shape2D.offset(o, -grooveInset), y: T)]
        for k in 1...6 {
            let a = Float(k) / 6 * .pi
            top.append(Prim.ring(Shape2D.offset(o, -(grooveInset + grooveWidth * (1 - cos(a)) / 2)), y: T - grooveDepth * sin(a)))
        }
        var face = Prim.loft(top, capEnd: true, material: self.top)
        face.uvs = face.positions.map { V2($0.x + length / 2, $0.z + length / 2) }   // one 0.45 m tile, centered
        face.computeTangents()
        // Bottom: planar fan.
        var bottom = Surface(material: self.top)
        let ring = Shape2D.offset(o, -b)
        let c = bottom.add(V3(0, 0, 0), V3(0, -1, 0), V2(length / 2, length / 2))
        for p in ring { bottom.add(V3(p.x, 0, -p.y), V3(0, -1, 0), V2(p.x + length / 2, -p.y + length / 2)) }
        let n = UInt32(ring.count)
        for k in 0..<n { bottom.tri(c, 1 + (k + 1) % n, 1 + k) }
        bottom.computeTangents()
        var m = Model(name: Self.id)
        m.add(sides); m.add(face); m.add(bottom)
        groundAO(&m, height: 0.012, floor: 0.6)
        return m
    }

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(dense: 0.005, coarse: 0.03, sideRings: 12), model(dense: 0.012, coarse: 0.08, sideRings: 4)], switchDistances: [3])
    }
}
