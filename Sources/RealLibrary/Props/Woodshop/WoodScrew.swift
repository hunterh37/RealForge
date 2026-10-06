import simd
import Foundation

/// #8 x 1-1/4 in flat-head wood screw lying on its side. #8 gauge: 4.17 mm major diameter, 2.9 mm root,
/// 11 threads per inch (2.31 mm pitch), 8.1 mm 82-degree countersunk head with a #2 Phillips (or #2
/// square) recess. Rolled single-start helical thread over the lower 62 percent, running out onto a
/// gimlet point; plain shank above. The thread surface is one helical grid, so every crest is a true
/// helix. Lies on the head rim and the thread crests near the point, axis tilted about 4 degrees.
/// Frame: head at -X, point at +X, centered on X/Z, lowest point on y = 0.
public struct WoodScrew: RealAsset {
    public static let id = "wood-screw"
    public static let summary = "#8 x 1-1/4 in flat-head wood screw: countersunk Phillips head, partial helical thread, gimlet point, zinc plate."
    public static let tags = ["prop", "workshop", "handheld", "metal"]
    public static let budget = 3400
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: -50, elevation: 30, distance: 0.13, studio: true)

    public enum Drive: Sendable { case phillips, square }

    /// Overall length, head top to point (m); 1-1/4 in. Clamped to 0.019...0.076 (3/4 in to 3 in).
    public var length: Float = 0.03175
    /// Thread major diameter (m); #8 = 0.164 in.
    public var majorDiameter: Float = 0.00417
    /// Thread root diameter (m).
    public var rootDiameter: Float = 0.0029
    /// Plain shank diameter (m); rolled threads leave it near the pitch diameter.
    public var shankDiameter: Float = 0.0039
    /// Head diameter (m).
    public var headDiameter: Float = 0.0081
    /// Thread pitch (m); 11 TPI.
    public var pitch: Float = 0.00231
    /// Threaded fraction of the length below the head.
    public var threadFraction: Float = 0.62
    /// Drive recess.
    public var drive: Drive = .phillips
    /// Plating: `metal.screw-zinc` (bright zinc) or `metal.screw-zinc-yellow`.
    public var plate: MaterialKey = "metal.screw-zinc"
    /// Pine fibres packed in the thread root near the point (a used screw).
    public var packedFibres = true
    public init() {}

    // MARK: public frame

    /// Length clamped to the supported range.
    public var clampedLength: Float { min(max(length, 0.019), 0.076) }
    /// Center of the head's top face (asset space).
    public var headCenter: V3 { placement.point(V3(0, clampedLength, 0)) }
    /// The gimlet point (asset space).
    public var tip: V3 { placement.point(.zero) }
    /// Unit screw axis from the head toward the point (asset space).
    public var axis: V3 { placement.rotation.act(V3(0, -1, 0)) }
    /// Pinch point on the plain shank, a third of the way down from the head.
    public var grip: V3 { placement.point(V3(0, clampedLength * 0.68, 0)) }

    var tipLength: Float { majorDiameter * 1.1 }
    var countersink: Float { (headDiameter - shankDiameter) / 2 / tan(41 * .pi / 180) }
    var rimHeight: Float { 0.00035 }
    var threadTop: Float { (clampedLength - countersink - rimHeight) * threadFraction }

    /// Local frame (axis +Y, point at y = 0, head top at y = length) to asset space: lying on the head
    /// rim and the first full crest, centered on X/Z, lowest point on y = 0.
    public var placement: Xform {
        let L = clampedLength, rH = headDiameter / 2, rM = majorDiameter / 2
        let alpha = atan((rH - rM) / (L - rimHeight - tipLength))
        let q = simd_quatf(angle: .pi / 2 - alpha, axis: V3(0, 0, 1))
        var pts: [V3] = []
        for k in 0..<16 {
            let a = Float(k) / 16 * 2 * .pi
            for (r, y) in [(rH, L), (rH, L - rimHeight), (rM, tipLength), (rM, threadTop)] { pts.append(q.act(V3(r * cos(a), y, r * sin(a)))) }
        }
        pts.append(.zero)
        let lo = pts.reduce(pts[0]) { simd_min($0, $1) }, hi = pts.reduce(pts[0]) { simd_max($0, $1) }
        return Xform(translation: V3(-(lo.x + hi.x) / 2, -lo.y, -(lo.z + hi.z) / 2), rotation: q)
    }

    // MARK: geometry

    /// Screw in its local frame (axis +Y, point at y = 0, head up). `sides` must be a multiple of 8;
    /// `rowsPerPitch` samples the thread profile (2 = zigzag for instanced copies, 6 = hero).
    public func screwModel(sides n: Int = 16, headSides: Int? = nil, rowsPerPitch J: Int = 8, recess: Bool = true) -> Model {
        let nh = headSides ?? n
        let L = clampedLength, p = pitch
        let rM = majorDiameter / 2, rR = rootDiameter / 2, rS = shankDiameter / 2, rH = headDiameter / 2
        let yHigh = threadTop, tl = tipLength
        var m = Model(name: Self.id)

        // Thread: helical grid. Row m, column k sits at y = p (m / J + a / 2 pi), so the profile phase
        // depends on the row only and each crest is an exact helix. Clamped to the point and thread run-out.
        func envelope(_ y: Float) -> (Float, Float) {
            let t = min(1, max(0, y / tl))
            var root = rR * pow(t, 0.8), h = (rM - rR) * pow(min(1, max(0, y / (tl * 0.75))), 0.7)
            let f = smoothstep(yHigh - 1.4 * p, yHigh, y)
            root += (rS - root) * f; h *= 1 - f
            return (root, h)
        }
        func tooth(_ u: Float) -> Float { max(0, 1 - abs(u - 0.5) / 0.3) }
        var th = Surface(material: plate)
        let m0 = -J, m1 = Int(ceil(yHigh / p * Float(J))) + 1
        let row = UInt32(n + 1)
        for r in m0...m1 {
            let u = Float(((r % J) + J) % J) / Float(J)
            for k in 0...n {
                let a = Float(k) / Float(n) * 2 * .pi
                let y = p * (Float(r) / Float(J) + a / (2 * .pi))
                let yc = min(max(y, 0), yHigh)
                let (root, h) = envelope(yc)
                let rad = y >= yHigh ? rS : (y <= 0 ? 0 : root + h * tooth(u))
                th.add(V3(rad * cos(a), yc, -rad * sin(a)), .up, V2(a * rM, y))
            }
        }
        for r in 0..<UInt32(m1 - m0) { for k in 0..<UInt32(n) {
            let a = r * row + k
            th.quad(a, a + 1, a + row + 1, a + row)
        }}
        th.recomputeNormals()
        th.computeTangents()
        m.add(th)

        // Shank and countersunk head.
        let yCs = L - rimHeight - countersink
        let e: Float = 0.00012
        let headProfile: [V2] = J <= 2
            ? [V2(rS, yHigh), V2(rS, yCs), V2(rH, L - rimHeight), V2(rH - e, L)]
            : [V2(rS, yHigh), V2(rS, yCs - 0.0004), V2(rS + 0.00015, yCs), V2(rH - 0.0002, L - rimHeight - 0.0001),
               V2(rH, L - rimHeight + 0.00005), V2(rH, L - e), V2(rH - e, L)]
        m.add(Prim.lathe(headProfile, segments: nh, seamTile: 0.02, material: plate))

        let rT = rH - e
        guard recess else {
            var cap = Surface(material: plate)
            let c = cap.add(V3(0, L, 0), .up, .zero)
            for k in 0...nh { let a = Float(k) / Float(nh) * 2 * .pi; cap.add(V3(rT * cos(a), L, -rT * sin(a)), .up, V2(cos(a), sin(a)) * rT) }
            for k in 0..<UInt32(nh) { cap.tri(c, c + 1 + k, c + 2 + k) }
            cap.computeTangents()
            m.add(cap)
            return m
        }
        // Head top: four sectors between the drive recess and the rim; recess walls lofted down.
        var outline: [V2] = [], chains: [[V2]] = []
        var rings: [[V2]] = []
        switch drive {
        case .phillips:
            let ra = headDiameter * 0.27, w = headDiameter * 0.065
            func cross(_ ra: Float, _ w: Float) -> [V2] {
                var o: [V2] = []
                for k in 0..<4 {
                    let a = Float(k) * .pi / 2, d = V2(cos(a), sin(a)), nn = V2(-sin(a), cos(a))
                    o += [d * ra - nn * w, d * ra, d * ra + nn * w, d * w + nn * w]
                }
                return o
            }
            outline = cross(ra, w)
            rings = [outline, cross(ra * 0.55, w * 0.72), cross(0.00035, 0.00016)]
            for k in 0..<4 { chains.append([outline[k * 4 + 1], outline[k * 4 + 2], outline[k * 4 + 3], outline[(k * 4 + 4) % 16], outline[(k * 4 + 5) % 16]]) }
        case .square:
            let s = headDiameter * 0.13
            func sq(_ s: Float) -> [V2] {
                let c = (0..<4).map { k -> V2 in let a = Float(k) * .pi / 2 + .pi / 4; return V2(cos(a), sin(a)) * s * sqrt(2) }
                var o: [V2] = []
                for k in 0..<4 { let a: V2 = c[k], b: V2 = c[(k + 1) % 4]; o.append(a); o.append((a + b) * 0.5) }
                return o
            }
            outline = sq(s)
            rings = [outline, sq(s * 0.88), sq(s * 0.55)]
            for k in 0..<4 { chains.append([outline[k * 2], outline[k * 2 + 1], outline[(k * 2 + 2) % 8]]) }
        }
        var top = Surface(material: plate)
        let quarter = n / 4
        for (k, chain) in chains.enumerated() {
            let a0 = atan2(chain[0].y, chain[0].x), a1raw = atan2(chain.last!.y, chain.last!.x)
            let a1 = a1raw <= a0 ? a1raw + 2 * .pi : a1raw
            var poly: [V2] = []
            // Rim samples on the lathe's angles between the chain ends (inclusive of both ends).
            let steps = max(1, Int(((a1 - a0) / (2 * .pi) * Float(nh)).rounded()))
            _ = quarter; _ = k
            for i in 0...steps { let a = a0 + (a1 - a0) * Float(i) / Float(steps); poly.append(V2(cos(a), sin(a)) * rT) }
            poly += chain.reversed()
            let idx = Shape2D.triangulate(poly.map { $0 * 1000 })
            let base = UInt32(top.positions.count)
            for q in poly { top.add(V3(q.x, L, -q.y), .up, V2(q.x, q.y)) }
            for t in stride(from: 0, to: idx.count, by: 3) { top.tri(base + idx[t], base + idx[t + 1], base + idx[t + 2]) }
        }
        top.computeTangents()
        m.add(top)
        if recess {
            let depths: [Float] = drive == .phillips ? [0, 0.0011, 0.0021] : [0, 0.0016, 0.0027]
            let r3 = zip(rings, depths).map { Prim.ring($0.0, y: L - $0.1) }
            m.add(Prim.loft(r3, capEnd: true, material: plate))
        }
        return m
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var local = screwModel()
        // Story detail: pine fibres packed in the thread root near the point (a screw backed out of a board).
        if packedFibres {
            let p = pitch, rR = rootDiameter / 2, tl = tipLength
            for k in 0..<4 {
                let a0 = rng.float(0...6.28), span = rng.float(0.9...2.2)
                var path: [V3] = [], radii: [Float] = []
                for i in 0...18 {
                    let a = a0 + span * Float(i) / 18
                    let y = p * (a / (2 * .pi) + Float(k / 2 + 1))
                    let r = rR * min(1, y / tl) + 0.00005
                    path.append(V3(r * cos(a), y, -r * sin(a)))
                    radii.append(0.00018 * sin(Float(i) / 18 * .pi) + 0.00003)
                }
                local.add(Prim.tube(path, radii: radii, sides: 5, seamTile: 0.01, material: "wood.sawdust", capEnd: false))
            }
        }
        var m = local.transformed(placement)
        groundAO(&m, height: 0.003, floor: 0.6)
        return LODModel(m)
    }
}
