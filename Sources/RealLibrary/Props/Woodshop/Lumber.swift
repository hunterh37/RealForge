import simd
import Foundation

/// Dimensional lumber or a hardwood board, and every piece cut from one. Default: a 2 ft kiln-dried SPF
/// 2x4 (38 x 89 mm dressed) with 3 mm factory-eased arrises, fresh sawn ends and an inked grade stamp.
///
/// Frame: length along X centered on the centerline (y = thickness / 2, z = 0), width along Z centered,
/// thickness along Y with the base at y = 0. Face grain runs along U (U = x + `grainOffset.x`); the wide
/// faces map V = z + `grainOffset.y`, the narrow faces V = y. End caps carry `endMaterial` mapped like
/// `wood.endgrain` (one tile per disc) with the growth rings centered on the pith (`endGrainCenter`).
///
/// End angles (degrees, clamped to +-60):
/// - `miterLeft` / `miterRight` tilt an end in the XZ plane. Positive leans the end so the back (-Z) edge
///   is longer than the front (+Z) edge, at either end.
/// - `bevelLeft` / `bevelRight` tilt an end in the XY plane. Positive leans the end so the bottom (y = 0)
///   face is longer than the top face, at either end.
/// `length` is measured along the centerline, so angled ends add length to one edge and take it from the
/// other.
///
/// Cuts: `crosscut` and `rip` return the two pieces as new `Lumber` values plus their origins in this
/// board's frame. Build each piece with the parent's seed: the grain (`grainOffset`), the pith and the
/// grade stamp are all anchored to the original mill board, so faces and end caps continue across cuts.
public struct Lumber: RealAsset {
    public static let id = "lumber"
    public static let summary = "Dimensional lumber board, default 2 ft 2x4: eased arrises, sawn end grain, grade stamp, angled ends, grain-continuous crosscut and rip helpers."
    public static let tags = ["prop", "workshop", "wood", "handheld"]
    public static let budget = 1_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 28, elevation: 24, distance: 0.9, studio: true)

    /// A cut piece: `board` is the new `Lumber`, `center` its local origin in the parent's local frame.
    public typealias Piece = CutPiece<Lumber>

    /// Long sides of the board that are fresh rip cuts (their arrises stay sharp even with `easedEdges`).
    public struct SawnSides: OptionSet, Sendable, Hashable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }
        /// The +Z narrow face.
        public static let front = SawnSides(rawValue: 1)
        /// The -Z narrow face.
        public static let back = SawnSides(rawValue: 2)
    }

    /// Length along X at the centerline, meters (default 24 in).
    public var length: Float = 0.6096
    /// Width along Z, meters (default 3-1/2 in, a dressed 2x4).
    public var width: Float = 0.0889
    /// Thickness along Y, meters (default 1-1/2 in).
    public var thickness: Float = 0.0381
    /// Face and edge material (grain along U): `wood.lumber-pine`, `-oak`, `-maple`, `-walnut`.
    public var material: MaterialKey = "wood.lumber-pine"
    /// End-grain cap material (disc mapping; rings centered on `endGrainCenter`).
    public var endMaterial: MaterialKey = "wood.endgrain-fresh"
    /// Miter of the -X end in degrees (XZ plane). Positive: the back (-Z) edge is longer.
    public var miterLeft: Float = 0
    /// Miter of the +X end in degrees (XZ plane). Positive: the back (-Z) edge is longer.
    public var miterRight: Float = 0
    /// Bevel of the -X end in degrees (XY plane). Positive: the bottom face is longer.
    public var bevelLeft: Float = 0
    /// Bevel of the +X end in degrees (XY plane). Positive: the bottom face is longer.
    public var bevelRight: Float = 0
    /// Factory round-over on the four long arrises (dimensional softwood). Off for planed hardwood.
    public var easedEdges = true
    /// Round-over radius when `easedEdges` is on, meters (3 mm).
    public var easeRadius: Float = 0.003
    /// Meters added to the face UVs (x along the length, y across the width) so cut pieces continue the
    /// parent's grain. `crosscut` and `rip` maintain it; leave it at zero for mill stock.
    public var grainOffset: V2 = .zero
    /// Faint inked grade stamp on the top face of mill stock (anchored to the mill board; a piece shows it
    /// only if the stamp lies on that piece). Turn off for hardwood.
    public var stamp = true
    /// Pith position in the end section, meters: x = Z, y = Y measured from the section center
    /// (y = thickness / 2), in this board's frame. nil derives it from the build seed (anchored to the mill
    /// board through `grainOffset`, so pieces built with the parent's seed line up).
    public var endGrainCenter: V2? = nil
    /// Long sides that are fresh rip cuts (sharp arrises). `rip` sets them.
    public var sawnSides: SawnSides = []

    public init() {}

    /// A board of a nominal size (`"2x4"`, `"1x6"`, ...) and length in meters; nil for unknown sizes.
    public init?(nominal name: String, length: Float, material: MaterialKey = "wood.lumber-pine") {
        guard let n = Self.nominal(name) else { return nil }
        self.width = n.width; self.thickness = n.thickness; self.length = length; self.material = material
    }

    /// Actual dressed size in meters of a nominal US softwood size: 1x2, 1x3, 1x4, 1x6, 1x8, 1x10, 1x12,
    /// 2x2, 2x4, 2x6, 2x8, 2x10, 2x12, 4x4 (case and spaces ignored). nil for anything else.
    public static func nominal(_ name: String) -> (width: Float, thickness: Float)? {
        let key = name.lowercased().replacingOccurrences(of: " ", with: "")
        let inch: Float = 0.0254
        let table: [String: (Float, Float)] = [
            "1x2": (1.5, 0.75), "1x3": (2.5, 0.75), "1x4": (3.5, 0.75), "1x6": (5.5, 0.75), "1x8": (7.25, 0.75),
            "1x10": (9.25, 0.75), "1x12": (11.25, 0.75), "2x2": (1.5, 1.5), "2x4": (3.5, 1.5), "2x6": (5.5, 1.5),
            "2x8": (7.25, 1.5), "2x10": (9.25, 1.5), "2x12": (11.25, 1.5), "4x4": (3.5, 3.5)]
        guard let (w, t) = table[key] else { return nil }
        return (w * inch, t * inch)
    }

    var shape: StockShape {
        var s = StockShape(length: length, width: width, thickness: thickness)
        s.miterLeft = miterLeft; s.miterRight = miterRight; s.bevelLeft = bevelLeft; s.bevelRight = bevelRight
        s.radius = easedEdges ? easeRadius : 0
        s.segments = 3
        s.sharpFront = sawnSides.contains(.front); s.sharpBack = sawnSides.contains(.back)
        return s
    }

    func with(shape s: StockShape) -> Lumber {
        var b = self
        b.length = s.length; b.width = s.width
        b.miterLeft = s.miterLeft; b.miterRight = s.miterRight; b.bevelLeft = s.bevelLeft; b.bevelRight = s.bevelRight
        b.sawnSides = []
        if s.sharpFront { b.sawnSides.insert(.front) }
        if s.sharpBack { b.sawnSides.insert(.back) }
        return b
    }

    /// Crosscuts the board with a blade plane through (x, thickness / 2, 0), tilted by `miter` (XZ) and
    /// `bevel` (XY) with the right-end sign convention: the left piece gets `miterRight = miter`,
    /// `bevelRight = bevel`; the right piece gets `miterLeft = -miter`, `bevelLeft = -bevel`, so both new
    /// end faces lie on the cut plane offset by half the kerf along its normal. `kerf` (meters, default
    /// 1/8 in) is removed perpendicular to the cut plane, centered on it. Long arrises keep their easing;
    /// the new ends are sharp sawn end grain. nil when x is outside the board (at the centerline) or the
    /// cut plane would leave a piece with no material along an edge.
    public func crosscut(atX x: Float, kerf: Float = 0.0032, miter: Float = 0, bevel: Float = 0) -> (left: Piece, right: Piece)? {
        guard let (l, r) = shape.crosscut(atX: x, kerf: kerf, miter: miter, bevel: bevel) else { return nil }
        return (piece(l.0, l.1), piece(r.0, r.1))
    }

    /// Rips the board along its length with a vertical blade plane at z (kerf centered on it). `front` is
    /// the +Z piece, `back` the -Z piece; each gets a sharp sawn arris pair on the new face (`sawnSides`)
    /// and keeps the parent's end angles (lengths follow the miters at the piece's own centerline). nil
    /// when z is outside the board or a piece would be thinner than 1 mm.
    public func rip(atZ z: Float, kerf: Float = 0.0032) -> (front: Piece, back: Piece)? {
        guard let (f, b) = shape.rip(atZ: z, kerf: kerf) else { return nil }
        return (piece(f.0, f.1), piece(b.0, b.1))
    }

    func piece(_ s: StockShape, _ c: V3) -> Piece {
        var b = with(shape: s)
        b.grainOffset = grainOffset + V2(c.x, c.z)
        if let p = endGrainCenter { b.endGrainCenter = V2(p.x - c.z, p.y) }
        return Piece(board: b, center: c)
    }

    /// Solid wood volume in cubic meters (eased arrises and angled ends included).
    public var volume: Float { shape.volume }

    /// Board feet of the actual volume (1 bf = 144 cubic inches = 2.3597 L).
    public var boardFeet: Float { volume / 0.002359737 }

    /// A point on an end face (where it meets the centerline) and its outward unit normal, local frame.
    public func endPlane(right: Bool) -> (point: V3, normal: V3) {
        let s = shape
        return (V3(s.endX(right: right, y: s.yc, z: 0), s.yc, 0), s.endNormal(right: right))
    }

    /// Mill-board anchors derived from the seed: pith (root frame, x = Z, y from section center), stamp
    /// center x (root frame) and stamp rotation in degrees.
    static func anchors(seed: UInt64) -> (pith: V2, stampX: Float, stampAngle: Float) {
        var rng = SeededRNG(seed: seed).fork(4711)
        let pz = rng.float(-0.05...0.05)
        let py = (rng.chance(0.5) ? 1 : -1) * rng.float(0.03...0.07)
        return (V2(pz, py), rng.float(-0.15...0.15), rng.float(-4...4))
    }

    /// The pith used for a build with `seed` (this board's frame, x = Z, y from the section center).
    public func pith(seed: UInt64) -> V2 {
        endGrainCenter ?? (Self.anchors(seed: seed).pith - V2(grainOffset.y, 0))
    }

    public func build(seed: UInt64) -> LODModel {
        var m = model(seed: seed, lite: false)
        groundAO(&m, height: min(0.03, thickness), floor: 0.85)
        return LODModel(m)
    }

    /// The board as a model (no ground AO). `lite` drops the stamp and uses one-segment round-overs.
    func model(seed: UInt64, lite: Bool) -> Model {
        var s = shape
        if lite { s.segments = 1 }
        let g = grainOffset, yc = thickness / 2
        let pith = self.pith(seed: seed)
        let tile = max(0.01, MaterialLibrary.spec(for: endMaterial).tileSize)
        var m = Model(name: Self.id)
        for surf in s.surfaces(face: material, side: material, end: endMaterial,
                               faceUV: { x, z in V2(x + g.x, z + g.y) },
                               sideUV: { x, y in V2(x + g.x, y) },
                               endUV: { z, y in V2(z - pith.x + tile / 2, (y - yc) - pith.y + tile / 2) }) {
            m.add(surf)
        }
        if stamp && !lite, let st = stampSurface(seed: seed, shape: s) { m.add(st) }
        return m
    }

    /// Grade stamp glyphs (3x5 pixel font, run-merged quads) on the top face, or nil if it does not fit.
    func stampSurface(seed: UInt64, shape s: StockShape) -> Surface? {
        let a = Self.anchors(seed: seed)
        let cx = a.stampX - grainOffset.x, cz = -grainOffset.y
        let lines = ["SPF No.2", "S-DRY KD"]
        let px: Float = min(0.0011, (width - 2 * (easedEdges ? easeRadius : 0) - 0.008) / 17)
        guard px > 0.0005 else { return nil }
        let size = InkStamp.size(lines, px: px)
        let ang = a.stampAngle * .pi / 180
        let hw = (size.x * abs(cos(ang)) + size.y * abs(sin(ang))) / 2, hd = (size.x * abs(sin(ang)) + size.y * abs(cos(ang))) / 2
        let edge = width / 2 - (easedEdges && !sawnSides.contains(.front) ? easeRadius : 0) - 0.002
        let edgeB = width / 2 - (easedEdges && !sawnSides.contains(.back) ? easeRadius : 0) - 0.002
        guard cz + hd < edge, cz - hd > -edgeB else { return nil }
        for z in [cz - hd, cz + hd] {
            guard cx - hw > s.endX(right: false, y: thickness, z: z) + 0.004,
                  cx + hw < s.endX(right: true, y: thickness, z: z) - 0.004 else { return nil }
        }
        var rng = SeededRNG(seed: seed).fork(91)
        return InkStamp.surface(lines, px: px, center: V2(cx, cz), angle: ang, y: thickness + 0.0002, rng: &rng)
    }
}

