import simd
import Foundation

/// What a facade piece is asked to fill. Opening pieces are built in the opening frame: origin at the
/// bottom center of the opening on the outer wall face, x along the facade, y up, z out of the wall.
/// Run pieces (base course, belt course, cornice, attic) are built along x from 0 to `width`.
public struct FacadePieceContext: Sendable {
    public var slot: FacadeSlot
    public var style: ArchStyle
    /// Resolved materials (style plus spec overrides).
    public var materials: [MaterialSlot: MaterialKey]
    public var width: Float
    public var height: Float
    /// Wall thickness behind the face.
    public var depth: Float
    public var window: WindowType?
    public var floor: Int
    public var facade: Int
    public var bay: Int
    public var lod: Int
    public var seed: UInt64
    /// Exterior door leaves swung open (walk mode).
    public var open: Bool = false
    public func material(_ s: MaterialSlot) -> MaterialKey { materials[s] ?? style.material(s) }
}

/// Cross-section swept along facade edges: x out from the wall face, y up from the run base. Points run
/// from the wall at the bottom, out, up and back to the wall.
public struct FacadeProfile: Codable, Hashable, Sendable {
    public var points: [V2]
    public var material: MaterialKey
    public init(points: [V2], material: MaterialKey) { self.points = points; self.material = material }
    public var height: Float { points.map(\.y).max() ?? 0 }
    public var projection: Float { points.map(\.x).max() ?? 0 }
}

/// Supplies facade geometry by slot. Return nil to fall back (the generator skips the piece).
public protocol FacadePieceProvider: Sendable {
    func piece(_ ctx: FacadePieceContext) -> Model?
    func profile(_ ctx: FacadePieceContext) -> FacadeProfile?
}
public extension FacadePieceProvider {
    func profile(_ ctx: FacadePieceContext) -> FacadeProfile? { nil }
}

/// Resolves pieces by id: registered builders first, then catalog assets (fitted to the opening or
/// tiled along a run), then the procedural pieces. `BuildingSpec.pieces` assigns ids to slots.
public struct FacadePieceRegistry: FacadePieceProvider {
    public typealias Builder = @Sendable (FacadePieceContext) -> Model?
    public var builders: [String: Builder] = [:]
    public var assignments: [FacadeSlot: String] = [:]
    public var fallback: any FacadePieceProvider = ProceduralFacade()
    public init() {}

    public mutating func register(_ id: String, _ builder: @escaping Builder) { builders[id] = builder }

    public func piece(_ ctx: FacadePieceContext) -> Model? {
        if let id = assignments[ctx.slot] {
            if let b = builders[id], let m = b(ctx) { return m }
            if let m = Self.catalogPiece(id, ctx) { return m }
        }
        return fallback.piece(ctx)
    }
    public func profile(_ ctx: FacadePieceContext) -> FacadeProfile? {
        if let id = assignments[ctx.slot], builders[id] != nil || Catalog.type(id) != nil { return nil }
        return fallback.profile(ctx)
    }

    static let runSlots: Set<FacadeSlot> = [.baseCourse, .beltCourse, .cornice, .attic, .groundFloor, .typicalFloor]

    /// A catalog asset scaled into the opening box (front assumed +Z), or tiled along a run.
    public static func catalogPiece(_ id: String, _ ctx: FacadePieceContext) -> Model? {
        guard let t = Catalog.type(id) else { return nil }
        let lod = t.init().build(seed: ctx.seed)
        let m = lod.levels[Swift.min(ctx.lod, lod.levels.count - 1)]
        let bb = m.bounds, e = simd_max(bb.max - bb.min, V3(repeating: 1e-3))
        if runSlots.contains(ctx.slot) {
            let count = Swift.max(1, Int((ctx.width / e.x).rounded()))
            let sx = ctx.width / Float(count) / e.x
            var out = Model(name: id)
            for i in 0..<count {
                let x0 = Float(i) * e.x * sx
                out.add(m, Xform(translation: V3(x0 - bb.min.x * sx, -bb.min.y, -bb.min.z), scale: V3(sx, 1, 1)))
            }
            return out
        }
        let s = V3(ctx.width / e.x, ctx.height / e.y, Swift.min(ctx.width / e.x, ctx.height / e.y))
        let c = (bb.min + bb.max) / 2
        return m.transformed(Xform(translation: V3(-c.x * s.x, -bb.min.y * s.y, -c.z * s.z - ctx.depth / 2), scale: s))
    }
}

/// Procedural facade vocabulary: framed windows by type (sashes, meeting rails, muntins, sills), door
/// frames with panelled leaves and transoms, surrounds by style (lintel, keystone, architrave,
/// pediment, hood), door surrounds (pilasters, portico), quoins and pilasters, and run profiles.
public struct ProceduralFacade: FacadePieceProvider {
    public init() {}

    public func piece(_ ctx: FacadePieceContext) -> Model? {
        var m = MeshBucket()
        switch ctx.slot {
        case .window: window(&m, ctx)
        case .door: door(&m, ctx)
        case .windowSurround: surround(&m, ctx)
        case .doorSurround: doorSurround(&m, ctx)
        case .corner: corner(&m, ctx)
        default: return nil
        }
        return m.triangleCount > 0 ? m.model(ctx.slot.rawValue) : nil
    }

    public func profile(_ ctx: FacadePieceContext) -> FacadeProfile? {
        let st = ctx.style, d = st.trimDepth
        switch ctx.slot {
        case .baseCourse:
            let h = ctx.height
            return FacadeProfile(points: [V2(0, 0), V2(d * 0.8, 0), V2(d * 0.8, h - 0.06), V2(0, h)], material: ctx.material(.baseCourse))
        case .beltCourse:
            return FacadeProfile(points: [V2(0, 0), V2(d * 0.5, 0), V2(d, 0.04), V2(d, 0.16), V2(d * 0.6, 0.2), V2(0, 0.2)], material: ctx.material(.trim))
        case .attic:
            // Parapet coping.
            return FacadeProfile(points: [V2(0, 0), V2(0.05, 0), V2(0.05, 0.06), V2(0, 0.07)], material: ctx.material(.trim))
        case .cornice:
            let h = st.corniceHeight, p = h * (ctx.lod >= 2 ? 0.7 : 0.9)
            let mat = ctx.material(.cornice)
            switch st.cornice {
            case .classical:
                // Bed moulding, corona with drip, cyma recta crown.
                return FacadeProfile(points: [V2(0, 0), V2(0.08 * p, 0), V2(0.12 * p, 0.12 * h), V2(0.3 * p, 0.22 * h), V2(0.32 * p, 0.38 * h),
                                              V2(0.85 * p, 0.42 * h), V2(0.88 * p, 0.62 * h), V2(0.92 * p, 0.66 * h), V2(p, 0.86 * h),
                                              V2(p, h), V2(0, h)], material: mat)
            case .bracketed:
                return FacadeProfile(points: [V2(0, 0), V2(0.1 * p, 0), V2(0.12 * p, 0.12 * h), V2(0.95 * p, 0.62 * h), V2(p, 0.66 * h),
                                              V2(p, 0.9 * h), V2(0.94 * p, h), V2(0, h)], material: mat)
            case .deco:
                // Stepped setback bands.
                return FacadeProfile(points: [V2(0, 0), V2(0.06, 0), V2(0.06, 0.3 * h), V2(0.14, 0.3 * h), V2(0.14, 0.62 * h),
                                              V2(0.22, 0.62 * h), V2(0.22, h), V2(0, h)], material: mat)
            case .slab:
                return FacadeProfile(points: [V2(0, 0), V2(0.45, 0), V2(0.45, h), V2(0, h)], material: mat)
            case .simple:
                return FacadeProfile(points: [V2(0, 0), V2(0.1 * p, 0), V2(0.15 * p, 0.25 * h), V2(0.8 * p, 0.5 * h), V2(p, 0.7 * h),
                                              V2(p, h), V2(0, h)], material: mat)
            }
        default: return nil
        }
    }

    // MARK: windows

    func window(_ m: inout MeshBucket, _ ctx: FacadePieceContext) {
        let w = ctx.width, h = ctx.height, type = ctx.window ?? .doubleHung
        let frame = ctx.material(.windowFrame), glass = ctx.material(.glass), sillMat = ctx.material(.trim)
        let recess: Float = type == .curtain ? 0.04 : (type == .storefront ? 0.08 : Swift.min(0.12, ctx.depth * 0.45))
        let fw: Float = type == .curtain || type == .storefront ? 0.05 : 0.07   // frame member width
        let fd: Float = 0.08
        let z0 = -recess - fd
        if ctx.lod >= 2 {
            m.quad(V3(-w / 2, 0, 0.005), V3(w / 2, 0, 0.005), V3(w / 2, h, 0.005), V3(-w / 2, h, 0.005), glass)
            return
        }
        func bar(_ x0: Float, _ x1: Float, _ y0: Float, _ y1: Float, _ zb: Float = z0, _ d: Float = fd, _ mat: MaterialKey? = nil) {
            m.box(V3(x0, y0, zb), V3(x1 - x0, 0, 0), V3(0, y1 - y0, 0), V3(0, 0, d), mat ?? frame)
        }
        // Outer frame.
        bar(-w / 2, -w / 2 + fw, 0, h); bar(w / 2 - fw, w / 2, 0, h)
        bar(-w / 2 + fw, w / 2 - fw, 0, fw); bar(-w / 2 + fw, w / 2 - fw, h - fw, h)
        let gz = z0 + fd * 0.45
        func pane(_ x0: Float, _ x1: Float, _ y0: Float, _ y1: Float, _ z: Float = gz) {
            m.quad(V3(x0, y0, z), V3(x1, y0, z), V3(x1, y1, z), V3(x0, y1, z), glass)
        }
        let ix0 = -w / 2 + fw, ix1 = w / 2 - fw, iy0 = fw, iy1 = h - fw
        switch type {
        case .doubleHung:
            let mid = h * 0.52
            // Lower sash inside, upper sash outside, meeting rail.
            let sw: Float = 0.05
            bar(ix0, ix1, mid - 0.025, mid + 0.025, z0 + 0.01, 0.06)
            for (y0, y1, zz) in [(iy0, mid - 0.025, z0 - 0.01), (mid + 0.025, iy1, z0 + 0.03)] {
                bar(ix0, ix0 + sw, y0, y1, zz, 0.045); bar(ix1 - sw, ix1, y0, y1, zz, 0.045)
                pane(ix0 + sw, ix1 - sw, y0, y1, zz + 0.02)
                if ctx.lod == 0 { muntins(&m, ctx, ix0 + sw, ix1 - sw, y0, y1, zz + 0.012, frame) }
            }
        case .casement:
            let cx: Float = 0
            bar(cx - 0.03, cx + 0.03, iy0, iy1, z0, fd)
            let tr = h > 2.0 ? h - 0.5 : -1
            if tr > 0 { bar(ix0, ix1, tr - 0.03, tr + 0.03, z0, fd) }
            let top = tr > 0 ? tr - 0.03 : iy1
            pane(ix0, cx - 0.03, iy0, top); pane(cx + 0.03, ix1, iy0, top)
            if tr > 0 { pane(ix0, ix1, tr + 0.03, iy1) }
            if ctx.lod == 0 {
                muntins(&m, ctx, ix0, cx - 0.03, iy0, top, gz + 0.012, frame)
                muntins(&m, ctx, cx + 0.03, ix1, iy0, top, gz + 0.012, frame)
            }
        case .fixed:
            pane(ix0, ix1, iy0, iy1)
        case .storefront:
            let tr = Swift.min(h - 0.35, 2.3)
            bar(ix0, ix1, tr - 0.025, tr + 0.025)
            pane(ix0, ix1, iy0, tr - 0.025); pane(ix0, ix1, tr + 0.025, iy1)
            var x = ix0 + 1.5
            while x < ix1 - 0.6 { bar(x - 0.025, x + 0.025, iy0, iy1); x += 1.5 }
        case .curtain:
            let tr = h * 0.72
            bar(ix0, ix1, tr - 0.025, tr + 0.025)
            pane(ix0, ix1, iy0, tr - 0.025); pane(ix0, ix1, tr + 0.025, iy1)
        }
        // Sill (stone, projecting, wider than the opening) for masonry styles.
        if type != .curtain && type != .storefront {
            m.box(V3(-w / 2 - 0.06, -0.07, -recess - 0.02), V3(w + 0.12, 0, 0), V3(0, 0.07, 0), V3(0, 0, recess + 0.02 + 0.07), sillMat)
        } else if type == .storefront {
            m.box(V3(-w / 2, -0.02, -recess), V3(w, 0, 0), V3(0, 0.04, 0), V3(0, 0, recess + 0.02), frame)
        }
    }

    func muntins(_ m: inout MeshBucket, _ ctx: FacadePieceContext, _ x0: Float, _ x1: Float, _ y0: Float, _ y1: Float, _ z: Float, _ mat: MaterialKey) {
        let cols = Int(ctx.style.muntins.x), rows = Int(ctx.style.muntins.y)
        guard cols > 0 || rows > 0 else { return }
        let b: Float = 0.022
        if cols > 1 { for i in 1..<cols { let x = x0 + (x1 - x0) * Float(i) / Float(cols); m.box(V3(x - b / 2, y0, z), V3(b, 0, 0), V3(0, y1 - y0, 0), V3(0, 0, 0.02), mat) } }
        if rows > 1 { for j in 1..<rows { let y = y0 + (y1 - y0) * Float(j) / Float(rows); m.box(V3(x0, y - b / 2, z), V3(x1 - x0, 0, 0), V3(0, b, 0), V3(0, 0, 0.02), mat) } }
    }

    // MARK: doors

    func door(_ m: inout MeshBucket, _ ctx: FacadePieceContext) {
        let w = ctx.width, h = ctx.height
        let frame = ctx.material(.windowFrame), leafMat = ctx.material(.door), glass = ctx.material(.glass)
        let recess: Float = Swift.min(0.15, ctx.depth * 0.5)
        let fw: Float = 0.08, fd: Float = 0.1, z0 = -recess - fd
        if ctx.lod >= 2 {
            m.quad(V3(-w / 2, 0, 0.005), V3(w / 2, 0, 0.005), V3(w / 2, h, 0.005), V3(-w / 2, h, 0.005), leafMat)
            return
        }
        func bar(_ x0: Float, _ x1: Float, _ y0: Float, _ y1: Float, _ zb: Float, _ d: Float, _ mat: MaterialKey) {
            m.box(V3(x0, y0, zb), V3(x1 - x0, 0, 0), V3(0, y1 - y0, 0), V3(0, 0, d), mat)
        }
        bar(-w / 2, -w / 2 + fw, 0, h, z0, fd, frame); bar(w / 2 - fw, w / 2, 0, h, z0, fd, frame)
        bar(-w / 2 + fw, w / 2 - fw, h - fw, h, z0, fd, frame)
        let hasTransom = ctx.style.transom && h > 2.55
        let leafTop = hasTransom ? h - fw - 0.45 : h - fw
        if hasTransom {
            bar(-w / 2 + fw, w / 2 - fw, leafTop, leafTop + 0.07, z0, fd, frame)
            m.quad(V3(-w / 2 + fw, leafTop + 0.07, z0 + 0.04), V3(w / 2 - fw, leafTop + 0.07, z0 + 0.04),
                   V3(w / 2 - fw, h - fw, z0 + 0.04), V3(-w / 2 + fw, h - fw, z0 + 0.04), glass)
            if ctx.lod == 0, ctx.style.muntins.x > 0 {
                for i in 1..<4 { let x = -w / 2 + fw + (w - 2 * fw) * Float(i) / 4; bar(x - 0.012, x + 0.012, leafTop + 0.07, h - fw, z0 + 0.05, 0.02, frame) }
            }
        }
        let leaves = w > 1.3 ? 2 : 1
        let lw = (w - 2 * fw) / Float(leaves), lt: Float = 0.05
        let metalLeaf = leafMat.hasPrefix("metal.")
        for i in 0..<leaves {
            let x0 = -w / 2 + fw + Float(i) * lw
            // Hinge on the outer jamb; open swings inward 80 degrees.
            let hingeLeft = i == 0
            let hingeX = hingeLeft ? x0 : x0 + lw
            let ang: Float = ctx.open ? radians(hingeLeft ? 80 : -80) : 0
            let rot = simd_quatf(angle: ang, axis: V3(0, 1, 0))
            let pivot = V3(hingeX, 0, z0 + 0.02)
            func L(_ p: V3) -> V3 { pivot + rot.act(p - pivot) }
            func leafBox(_ a: V3, _ size: V3, _ mat: MaterialKey) {
                let o = L(a)
                m.box(o, rot.act(V3(size.x, 0, 0)), V3(0, size.y, 0), rot.act(V3(0, 0, size.z)), mat)
            }
            leafBox(V3(x0 + 0.002, 0.01, z0 + 0.02), V3(lw - 0.004, leafTop - 0.012, lt), leafMat)
            if ctx.lod == 0 {
                if metalLeaf {
                    // Glazed leaf: glass light in a metal stile frame.
                    let gx0 = x0 + 0.1, gx1 = x0 + lw - 0.1
                    let a = L(V3(gx0, 0.35, z0 + 0.075)), b = L(V3(gx1, 0.35, z0 + 0.075)), c = L(V3(gx1, leafTop - 0.12, z0 + 0.075)), d = L(V3(gx0, leafTop - 0.12, z0 + 0.075))
                    m.quad(a, b, c, d, glass)
                } else {
                    // Raised panels: two tall over one short.
                    let px0 = x0 + 0.1, pw = lw - 0.2
                    for (y0, y1) in [(Float(0.15), Float(0.75)), (0.9, leafTop - 0.15)] where y1 > y0 + 0.2 {
                        leafBox(V3(px0, y0, z0 + 0.02 + lt), V3(pw, y1 - y0, 0.012), leafMat)
                    }
                }
                // Knob or pull.
                let kx = hingeLeft ? x0 + lw - 0.08 : x0 + 0.08
                leafBox(V3(kx - 0.02, 1.0, z0 + 0.02 + lt), V3(0.04, 0.04, 0.05), "metal.brass-aged")
            }
        }
    }

    // MARK: surrounds

    func surround(_ m: inout MeshBucket, _ ctx: FacadePieceContext) {
        let w = ctx.width, h = ctx.height, d = ctx.style.trimDepth, mat = ctx.material(.trim)
        guard ctx.lod < 2 else {
            if ctx.style.surround != .none { m.box(V3(-w / 2 - 0.12, h, 0), V3(w + 0.24, 0, 0), V3(0, 0.2, 0), V3(0, 0, d), mat) }
            return
        }
        func blk(_ x0: Float, _ x1: Float, _ y0: Float, _ y1: Float, _ dd: Float) {
            m.box(V3(x0, y0, 0), V3(x1 - x0, 0, 0), V3(0, y1 - y0, 0), V3(0, 0, dd), mat)
        }
        let ab: Float = 0.12   // architrave band
        switch ctx.style.surround {
        case .none: return
        case .lintel:
            blk(-w / 2 - 0.15, w / 2 + 0.15, h, h + 0.25, d)
        case .lintelKeystone:
            // Flat jack arch with splayed voussoir ends and a proud keystone.
            m.poly([V3(-w / 2, h, d), V3(w / 2, h, d), V3(w / 2 + 0.15, h + 0.28, d), V3(-w / 2 - 0.15, h + 0.28, d)], mat, facing: V3(0, 0, 1))
            m.box(V3(-w / 2, h, 0), V3(w, 0, 0), V3(0, 0.001, 0), V3(0, 0, d), mat)
            m.poly([V3(-w / 2 - 0.15, h + 0.28, 0), V3(-w / 2 - 0.15, h + 0.28, d), V3(-w / 2, h, d), V3(-w / 2, h, 0)], mat, facing: V3(-1, -0.5, 0))
            m.poly([V3(w / 2, h, 0), V3(w / 2, h, d), V3(w / 2 + 0.15, h + 0.28, d), V3(w / 2 + 0.15, h + 0.28, 0)], mat, facing: V3(1, -0.5, 0))
            m.box(V3(-w / 2 - 0.15, h + 0.28, 0), V3(w + 0.3, 0, 0), V3(0, 0.001, 0), V3(0, 0, d), mat)
            m.poly([V3(-0.1, h - 0.04, d + 0.025), V3(0.1, h - 0.04, d + 0.025), V3(0.13, h + 0.31, d + 0.025), V3(-0.13, h + 0.31, d + 0.025)], mat, facing: V3(0, 0, 1))
            m.box(V3(-0.1, h - 0.04, d), V3(0.2, 0, 0), V3(0, 0.35, 0), V3(0, 0, 0.025), mat)
        case .architrave, .pediment:
            blk(-w / 2 - ab, -w / 2, -0.02, h + ab, d); blk(w / 2, w / 2 + ab, -0.02, h + ab, d)
            blk(-w / 2, w / 2, h, h + ab, d)
            if ctx.style.surround == .pediment {
                // Frieze, cornice shelf and triangular pediment.
                blk(-w / 2 - ab, w / 2 + ab, h + ab, h + ab + 0.16, d * 0.7)
                blk(-w / 2 - ab - 0.06, w / 2 + ab + 0.06, h + ab + 0.16, h + ab + 0.24, d * 1.6)
                let y = h + ab + 0.24, half = w / 2 + ab + 0.06, rise: Float = 0.32
                let z1 = d * 1.4
                m.poly([V3(-half, y, z1), V3(half, y, z1), V3(0, y + rise, z1)], mat, facing: V3(0, 0, 1))
                m.poly([V3(half, y, 0), V3(half, y, z1), V3(0, y + rise, z1), V3(0, y + rise, 0)], mat, facing: V3(rise, half, 0))
                m.poly([V3(-half, y, z1), V3(-half, y, 0), V3(0, y + rise, 0), V3(0, y + rise, z1)], mat, facing: V3(-rise, half, 0))
            } else {
                blk(-w / 2 - ab - 0.04, w / 2 + ab + 0.04, h + ab, h + ab + 0.08, d * 1.5)
            }
        case .hood:
            // Projecting hood on two consoles.
            blk(-w / 2 - 0.18, w / 2 + 0.18, h + 0.1, h + 0.26, d * 2.2)
            blk(-w / 2 - 0.12, w / 2 + 0.12, h, h + 0.1, d)
            for sx: Float in [-1, 1] {
                let x = sx * (w / 2 + 0.07)
                m.box(V3(x - 0.06, h - 0.32, 0), V3(0.12, 0, 0), V3(0, 0.42, 0), V3(0, 0, d * 1.8), mat)
            }
        }
        // Apron under the sill for the classical styles.
        if ctx.style.surround == .pediment || ctx.style.surround == .architrave {
            blk(-w / 2, w / 2, -0.32, -0.08, d * 0.4)
        }
    }

    func doorSurround(_ m: inout MeshBucket, _ ctx: FacadePieceContext) {
        let w = ctx.width, h = ctx.height, d = ctx.style.trimDepth, mat = ctx.material(.trim)
        func blk(_ x0: Float, _ x1: Float, _ y0: Float, _ y1: Float, _ z0: Float, _ z1: Float) {
            m.box(V3(x0, y0, z0), V3(x1 - x0, 0, 0), V3(0, y1 - y0, 0), V3(0, 0, z1 - z0), mat)
        }
        switch ctx.style.doorSurround {
        case .none: return
        case .architrave:
            let b: Float = 0.16
            blk(-w / 2 - b, -w / 2, 0, h + b, 0, d); blk(w / 2, w / 2 + b, 0, h + b, 0, d); blk(-w / 2, w / 2, h, h + b, 0, d)
            blk(-w / 2 - b - 0.06, w / 2 + b + 0.06, h + b, h + b + 0.1, 0, d * 2)
        case .pilasters, .portico:
            let pw: Float = ctx.style.doorSurround == .portico ? 0.36 : 0.26
            let pd = ctx.style.doorSurround == .portico ? d * 3 : d * 1.5
            let x0 = w / 2 + 0.06
            for sx: Float in [-1, 1] {
                let a = sx < 0 ? -x0 - pw : x0
                blk(a - 0.03, a + pw + 0.03, 0, 0.3, 0, pd + 0.03)        // plinth
                if ctx.style.doorSurround == .portico && ctx.lod == 0 {
                    // Engaged column.
                    let col = Prim.cylinder(radius: pw * 0.42, height: h - 0.5, bevel: 0.01, segments: 14, material: mat)
                    m.add(Model(name: "col", surfaces: [col]), Xform(translation: V3(a + pw / 2, 0.3 + (h - 0.5) / 2, pd * 0.6)))
                } else {
                    blk(a, a + pw, 0.3, h - 0.2, 0, pd)
                }
                blk(a - 0.03, a + pw + 0.03, h - 0.2, h, 0, pd + 0.03)     // capital
            }
            // Entablature and cornice, pediment on a portico.
            blk(-x0 - pw - 0.05, x0 + pw + 0.05, h, h + 0.3, 0, pd)
            blk(-x0 - pw - 0.12, x0 + pw + 0.12, h + 0.3, h + 0.42, 0, pd + 0.1)
            if ctx.style.doorSurround == .portico {
                let half = x0 + pw + 0.12, y = h + 0.42, rise: Float = 0.55, z1 = pd + 0.1
                m.poly([V3(-half, y, z1), V3(half, y, z1), V3(0, y + rise, z1)], mat, facing: V3(0, 0, 1))
                m.poly([V3(half, y, 0), V3(half, y, z1), V3(0, y + rise, z1), V3(0, y + rise, 0)], mat, facing: V3(rise, half, 0))
                m.poly([V3(-half, y, z1), V3(-half, y, 0), V3(0, y + rise, 0), V3(0, y + rise, z1)], mat, facing: V3(-rise, half, 0))
            }
        }
    }

    /// Quoins or pilaster at the end of a facade edge: built from x = 0 (corner) back along -x, from
    /// y = 0 to `height`, wrapping past the corner by the projection so neighbors close the arris.
    func corner(_ m: inout MeshBucket, _ ctx: FacadePieceContext) {
        let d = ctx.style.trimDepth, mat = ctx.material(.corner), h = ctx.height
        switch ctx.style.corner {
        case .none: return
        case .pilaster:
            m.box(V3(-0.5, 0, 0), V3(0.5 + d, 0, 0), V3(0, h, 0), V3(0, 0, d), mat)
            if ctx.lod == 0 { m.box(V3(-0.56, h - 0.3, 0), V3(0.56 + d + 0.06, 0, 0), V3(0, 0.3, 0), V3(0, 0, d + 0.06), mat) }
        case .quoins:
            guard ctx.lod < 2 else { m.box(V3(-0.45, 0, 0), V3(0.45 + d, 0, 0), V3(0, h, 0), V3(0, 0, d), mat); return }
            let course: Float = 0.3
            var y: Float = 0, i = 0
            while y + course <= h + 1e-3 {
                let len: Float = i % 2 == 0 ? 0.6 : 0.3
                m.box(V3(-len, y + 0.01, 0), V3(len + d, 0, 0), V3(0, course - 0.02, 0), V3(0, 0, d), mat)
                y += course; i += 1
            }
        }
    }
}
