import simd
import Foundation

/// 3/4 in (19 mm) sanded plywood panel, default a 2 x 4 ft project panel (1220 x 610 mm): rotary-cut
/// veneer faces with the face grain along the length, seven-ply edges with glue lines and the odd core
/// void, crisp factory-cut arrises.
///
/// Frame: length along X, width along Z, both centered; thickness along Y with the base at y = 0. Faces map
/// U = x + `grainOffset.x`, V = z + `grainOffset.y`; edges map the plies across V (one ply-set per
/// thickness). `crosscut` and `rip` return `CutPiece` values the same way `Lumber` does: each piece's new
/// sheet and its origin in this sheet's frame, with `grainOffset` carried so the veneer figure continues.
public struct PlywoodSheet: RealAsset {
    public static let id = "plywood-sheet"
    public static let summary = "3/4 in sanded plywood panel, 2 x 4 ft: veneer faces, seven-ply edges, grain-continuous crosscut and rip helpers."
    public static let tags = ["prop", "workshop", "wood"]
    public static let budget = 400
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 28, distance: 1.0, studio: true)

    /// A cut piece: `board` is the new `PlywoodSheet`, `center` its local origin in the parent's frame.
    public typealias Piece = CutPiece<PlywoodSheet>

    /// Length along X (face grain direction), meters.
    public var length: Float = 1.22
    /// Width along Z, meters.
    public var width: Float = 0.61
    /// Thickness along Y, meters (23/32 in nominal 3/4).
    public var thickness: Float = 0.019
    /// Face veneer material (top and bottom).
    public var faceMaterial: MaterialKey = "wood.plywood"
    /// Edge material (plies across V; mapped so one repeat spans the thickness).
    public var edgeMaterial: MaterialKey = "wood.plywood-edge"
    /// Meters added to the face UVs so cut pieces continue the parent's veneer figure.
    public var grainOffset: V2 = .zero
    /// Arris radius of the factory edges, meters (lightly broken by handling).
    public var arris: Float = 0.0008
    /// Inked mill grade stamp on the top face (anchored to the mill sheet through `grainOffset`; a piece
    /// shows it only if the whole stamp lies on that piece).
    public var stamp = true
    /// Pencil layout: a square cut line across the width with an X on the waste side (x anchored to the
    /// mill sheet; drawn on a piece only if the line falls on it).
    public var marks = true

    public init() {}

    var shape: StockShape {
        var s = StockShape(length: length, width: width, thickness: thickness)
        s.radius = arris; s.segments = 1
        return s
    }

    /// Square crosscut across the width at x (kerf centered on it, default 1/8 in). nil outside the sheet.
    public func crosscut(atX x: Float, kerf: Float = 0.0032) -> (left: Piece, right: Piece)? {
        guard let (l, r) = shape.crosscut(atX: x, kerf: kerf, miter: 0, bevel: 0) else { return nil }
        return (piece(l.0, l.1), piece(r.0, r.1))
    }

    /// Rip along the length at z (kerf centered on it). `front` is the +Z piece. nil outside the sheet.
    public func rip(atZ z: Float, kerf: Float = 0.0032) -> (front: Piece, back: Piece)? {
        guard let (f, b) = shape.rip(atZ: z, kerf: kerf) else { return nil }
        return (piece(f.0, f.1), piece(b.0, b.1))
    }

    func piece(_ s: StockShape, _ c: V3) -> Piece {
        var p = self
        p.length = s.length; p.width = s.width
        p.grainOffset = grainOffset + V2(c.x, c.z)
        return Piece(board: p, center: c)
    }

    /// Panel volume in cubic meters.
    public var volume: Float { shape.volume }

    public func build(seed: UInt64) -> LODModel {
        var m = model(seed: seed)
        groundAO(&m, height: 0.02, floor: 0.85)
        return LODModel(m)
    }

    /// The panel as a model (no ground AO). `lite` drops the stamp and pencil marks.
    func model(seed: UInt64 = 1, lite: Bool = false) -> Model {
        let g = grainOffset
        let tile = MaterialLibrary.spec(for: edgeMaterial).tileSize
        let vs = tile / max(thickness, 0.001)
        var m = Model(name: Self.id)
        for s in shape.surfaces(face: faceMaterial, side: edgeMaterial, end: edgeMaterial,
                                faceUV: { x, z in V2(x + g.x, z + g.y) },
                                sideUV: { x, y in V2(x + g.x, y * vs) },
                                endUV: { z, y in V2(z + g.y, y * vs) }) {
            m.add(s)
        }
        if lite { return m }
        var rng = SeededRNG(seed: seed).fork(5150)
        let sx = rng.float(-0.25...0.25), sz = rng.float(-0.12...0.12), ang = rng.float(-3...3) * .pi / 180
        let lineX = rng.float(-0.48 ... -0.3)
        let y = thickness + 0.0002
        let x0 = -length / 2, x1 = length / 2, hw = width / 2
        if stamp {
            let lines = ["23/32 CAT", "C-D EXP 1"], px: Float = 0.0032
            let size = InkStamp.size(lines, px: px)
            let c = V2(sx - grainOffset.x, sz - grainOffset.y)
            let r = simd_length(size) / 2
            if c.x - r > x0 + 0.01, c.x + r < x1 - 0.01, c.y - r > -hw + 0.01, c.y + r < hw - 0.01 {
                m.add(InkStamp.surface(lines, px: px, center: c, angle: ang, y: y, dropout: 0.1, rng: &rng))
            }
        }
        if marks {
            var pen = Surface(material: "wood.plywood-pencil")
            func stroke(_ a: V2, _ b: V2, _ w: Float) {
                let d = simd_normalize(b - a), n = V2(-d.y, d.x) * w / 2
                let base = UInt32(pen.positions.count)
                for p in [a - n, b - n, b + n, a + n] { pen.add(V3(p.x, y + 0.00005, p.y), .up, p) }
                pen.quad(base, base + 3, base + 2, base + 1)
            }
            let lx = lineX - grainOffset.x
            if lx > x0 + 0.02, lx < x1 - 0.02, width > 0.06 {
                // Cut line drawn along a square: slight overshoot gaps at the edges, a short wobble at the start.
                stroke(V2(lx, -hw + 0.012), V2(lx + 0.0004, hw - 0.018), 0.0007)
                stroke(V2(lx - 0.006, -hw + 0.03), V2(lx + 0.006, -hw + 0.03), 0.0006)
                let xc = lx - 0.05, zc: Float = 0
                if xc - 0.025 > x0 + 0.005 {
                    stroke(V2(xc - 0.018, zc - 0.02), V2(xc + 0.018, zc + 0.02), 0.0008)
                    stroke(V2(xc - 0.018, zc + 0.02), V2(xc + 0.018, zc - 0.02), 0.0008)
                }
            }
            if !pen.isEmpty { pen.computeTangents(); m.add(pen) }
        }
        return m
    }
}
