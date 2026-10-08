import simd
import Foundation

/// Bay grid of one facade edge.
public struct FacadeLayout: Codable, Hashable, Sendable {
    public var facade: Int
    public var length: Float
    public var bays: Int
    public var doorBays: [Int]
    public var blankBays: [Int]
    public var step: Float { bays > 0 ? length / Float(bays) : length }
    public func center(_ bay: Int) -> Float { (Float(bay) + 0.5) * step }
}

/// Generator output: exterior shell (three LODs), interior geometry per floor, plans and schedule.
public struct BuildingModel: Sendable {
    public var spec: BuildingSpec
    public var shape: FootprintShape
    /// Facade, roof, slab edges and trim. LOD0 and LOD1 have real openings; LOD2 is a solid shell.
    public var exterior: LODModel
    /// Floor slabs, interior walls with door holes, thresholds, casings and stairs, one model per floor.
    public var interiors: [Model]
    /// Floor slabs only (blocks the view through LOD1 windows).
    public var slabs: Model
    public var plans: [FloorPlan]
    public var layouts: [FacadeLayout]
    public var schedule: BuildingSchedule
    /// Roof eave level and overall height (m).
    public var roofLevel: Float
    public var height: Float

    /// One LODModel for scenes: LOD0 exterior plus every interior, LOD1 exterior plus slabs, LOD2 shell.
    public func combined() -> LODModel {
        var l0 = MeshBucket()
        l0.add(exterior.levels[0])
        for m in interiors { l0.add(m) }
        var l1 = MeshBucket()
        l1.add(exterior.levels[1]); l1.add(slabs)
        return LODModel(levels: [l0.model(spec.name), l1.model(spec.name), exterior.levels[2]], switchDistances: exterior.switchDistances)
    }
}

/// Builds a `BuildingSpec` into geometry. Facade pieces come from `provider` (the registry resolves
/// `spec.pieces` ids, then catalog assets, then `ProceduralFacade`).
public struct BuildingGenerator: Sendable {
    public var provider: any FacadePieceProvider
    public var exteriorWall: Float = 0.3
    public var interiorWall: Float = 0.12
    public var slab: Float = 0.25
    public var parapet: Float = 1.07
    public var switchDistances: [Float] = [45, 140]

    public init(provider: (any FacadePieceProvider)? = nil) { self.provider = provider ?? FacadePieceRegistry() }

    public static func build(_ spec: BuildingSpec) -> BuildingModel { BuildingGenerator().build(spec) }

    // MARK: layout

    public func layouts(_ spec: BuildingSpec, shape: FootprintShape) -> [FacadeLayout] {
        shape.edges.map { e in
            let L = e.length
            let o = spec.override(e.index)
            var n: Int
            if let b = o?.bays { n = Swift.max(0, b) }
            else if L < 1.6 { n = 0 }
            else {
                n = Swift.max(1, Int((L / spec.bayWidth).rounded()))
                if n % 2 == 0 { n = L / Float(n + 1) >= 2.0 ? n + 1 : n - 1 }
            }
            let doors = o?.doorBays ?? (e.index == 0 && n > 0 ? [n / 2] : [])
            return FacadeLayout(facade: e.index, length: L, bays: n, doorBays: doors.filter { $0 >= 0 && $0 < n }, blankBays: o?.blankBays ?? [])
        }
    }

    struct Opening { var width: Float; var sill: Float; var head: Float }
    func windowSize(_ spec: BuildingSpec, _ style: ArchStyle, type: WindowType, floor f: Int, step: Float, facade: Int) -> Opening {
        let fh = spec.floorHeight(f), clear = fh - slab
        switch type {
        case .storefront:
            return Opening(width: Swift.max(1.0, step - 0.6), sill: 0.45, head: Swift.min(clear - 0.35, 3.3))
        case .curtain:
            let w = Swift.min(step - 0.12, Swift.max(0.8, step * style.windowWidthRatio))
            let h = Swift.min(clear - 0.25, fh * style.windowHeightRatio)
            return Opening(width: w, sill: Swift.max(0.1, clear - h - 0.25), head: Swift.max(0.1, clear - h - 0.25) + h)
        default:
            let w = Swift.min(step - 0.45, Swift.max(0.6, step * style.windowWidthRatio))
            let h = Swift.min(clear - 0.7, fh * style.windowHeightRatio)
            let balcony = facade == 0 && style.balconyFloors.contains(f)
            var sill = Swift.min(0.9, Swift.max(0.45, clear - h - 0.35))
            if balcony { sill = 0.05 }
            return Opening(width: w, sill: sill, head: balcony ? Swift.min(clear - 0.25, sill + h + 0.85) : sill + h)
        }
    }

    func doorSize(_ spec: BuildingSpec, _ style: ArchStyle) -> Opening {
        let w: Float = style.doubleDoor ? 1.6 : 0.95
        let h: Float = style.transom ? 2.75 : 2.2
        return Opening(width: w, sill: 0, head: Swift.min(h, spec.groundFloorHeight - slab - 0.3))
    }

    /// Floor plans with interior and exterior walls (openings included). Pure data, no geometry.
    public func plans(_ spec: BuildingSpec, shape: FootprintShape, layouts: [FacadeLayout]) -> [FloorPlan] {
        let style = spec.resolvedStyle
        var plans = FloorPlanner(spec: spec).plans()
        let door = doorSize(spec, style)
        for pi in plans.indices {
            let f = plans[pi].floor
            // Ground-floor rooms behind an exterior door become the lobby.
            if f == 0 {
                for (e, lay) in zip(shape.edges, layouts) {
                    for b in lay.doorBays {
                        let p = e.point(lay.center(b)) - e.normal * (exteriorWall + 0.4)
                        if let r = plans[pi].room(at: p), let k = plans[pi].rooms.firstIndex(of: r), r.kind == .room {
                            plans[pi].rooms[k].kind = .lobby; plans[pi].rooms[k].name = "Lobby"
                        }
                    }
                }
            }
            plans[pi].deriveInterior(shape: shape, thickness: interiorWall, exteriorThickness: exteriorWall)
            let interior = plans[pi].walls.filter { !$0.exterior }
            for (e, lay) in zip(shape.edges, layouts) {
                var seg = WallSegment(a: e.a, b: e.b, thickness: exteriorWall, exterior: true, facade: e.index, rooms: [-1])
                // Interior walls meeting this facade (windows keep clear of them).
                var junctions: [Float] = []
                for w in interior { for p in [w.a, w.b] {
                    let s = simd_dot(p - e.a, e.tangent), d = abs(simd_dot(p - e.a, e.normal))
                    if d < exteriorWall + 0.05, s > -0.1, s < e.length + 0.1 { junctions.append(s) }
                }}
                for b in 0..<lay.bays where !lay.blankBays.contains(b) {
                    let c = lay.center(b)
                    let inside = e.point(c) - e.normal * (exteriorWall + 0.4)
                    let room = plans[pi].room(at: inside)?.id ?? -2
                    if f == 0 && lay.doorBays.contains(b) {
                        seg.openings.append(WallOpening(kind: .door, center: c, width: door.width, sill: 0, head: door.head, rooms: [-1, room], bay: b))
                        continue
                    }
                    let type = spec.override(e.index)?.windowTypes[f] ?? (f == 0 ? style.groundWindow : style.typicalWindow)
                    let o = windowSize(spec, style, type: type, floor: f, step: lay.step, facade: e.index)
                    guard o.width > 0.3, c - o.width / 2 > 0.25, c + o.width / 2 < e.length - 0.25 else { continue }
                    if junctions.contains(where: { abs($0 - c) < o.width / 2 + interiorWall / 2 + 0.08 }) { continue }
                    seg.openings.append(WallOpening(kind: .window, center: c, width: o.width, sill: o.sill, head: o.head, window: type, rooms: [-1, room], bay: b))
                }
                plans[pi].walls.insert(seg, at: e.index)
            }
        }
        return plans
    }

    // MARK: build

    public func build(_ spec0: BuildingSpec) -> BuildingModel {
        var spec = spec0
        spec.floors = Swift.max(1, spec.floors)
        let shape = FootprintShape(spec.footprint)
        let style = spec.resolvedStyle
        let roof = spec.resolvedRoof
        var mats: [MaterialSlot: MaterialKey] = [:]
        for s in MaterialSlot.allCases { mats[s] = spec.material(s) }
        var prov = provider
        if var r = prov as? FacadePieceRegistry { r.assignments = r.assignments.merging(spec.pieces) { $1 }; prov = r }
        let lays = layouts(spec, shape: shape)
        let plans = plans(spec, shape: shape, layouts: lays)
        let lv = spec.levels
        let roofY = lv[spec.floors]
        let wallTop = roof == .flat ? roofY + parapet : roofY
        var cache: [String: Model] = [:]

        func ctx(_ slot: FacadeSlot, w: Float, h: Float, type: WindowType? = nil, floor: Int = 0, facade: Int = 0, bay: Int = 0, lod: Int) -> FacadePieceContext {
            FacadePieceContext(slot: slot, style: style, materials: mats, width: w, height: h, depth: exteriorWall, window: type,
                               floor: floor, facade: facade, bay: bay, lod: lod, seed: spec.seed, open: spec.openDoors)
        }
        func piece(_ c: FacadePieceContext) -> Model? {
            let key = "\(c.slot.rawValue)|\(c.window?.rawValue ?? "")|\(c.width)|\(c.height)|\(c.lod)|\(c.open)"
            if let m = cache[key] { return m.surfaces.isEmpty ? nil : m }
            let m = prov.piece(c)
            cache[key] = m ?? Model(name: "none")
            return m
        }
        func frame(_ e: FacadeEdge, _ s: Float, _ y: Float) -> Xform {
            WallFrame(origin: V3(e.a.x, 0, e.a.y) + V3(e.tangent.x, 0, e.tangent.y) * s + V3(0, y, 0),
                      t: V3(e.tangent.x, 0, e.tangent.y), n: V3(e.normal.x, 0, e.normal.y)).xform
        }

        var ext = [MeshBucket(), MeshBucket(), MeshBucket()]
        // Exterior walls and opening pieces, per floor.
        for (f, plan) in plans.enumerated() {
            let y0: Float = f == 0 ? 0 : lv[f] - slab
            let y1: Float = f == spec.floors - 1 ? wallTop : lv[f + 1] - slab
            let outer = f == 0 ? mats[.groundFloor]! : mats[.wall]!
            for seg in plan.walls where seg.exterior {
                guard let fi = seg.facade else { continue }
                let e = shape.edges[fi]
                for l in 0..<3 {
                    ArchMesh.wall(&ext[l], seg: seg, s0: 0, s1: seg.length, y0: y0, y1: y1, floorY: lv[f], openings: seg.openings,
                                  outer: outer, inner: mats[.interiorWall]!, reveal: outer, solid: l == 2)
                }
                for o in seg.openings {
                    let x = frame(e, o.center, lv[f] + o.sill)
                    for l in 0..<3 {
                        if o.kind == .window {
                            if let m = piece(ctx(.window, w: o.width, h: o.head - o.sill, type: o.window, floor: f, facade: fi, bay: o.bay ?? 0, lod: l)) { ext[l].add(m, x) }
                            if let m = piece(ctx(.windowSurround, w: o.width, h: o.head - o.sill, type: o.window, floor: f, facade: fi, bay: o.bay ?? 0, lod: l)) { ext[l].add(m, x) }
                        } else {
                            if let m = piece(ctx(.door, w: o.width, h: o.head - o.sill, floor: f, facade: fi, bay: o.bay ?? 0, lod: l)) { ext[l].add(m, x) }
                            if let m = piece(ctx(.doorSurround, w: o.width, h: o.head - o.sill, floor: f, facade: fi, bay: o.bay ?? 0, lod: l)) { ext[l].add(m, x) }
                            if l < 2 { stoop(&ext[l], e: e, at: o.center, width: o.width, raise: lv[0], style: style, mats: mats, frame: frame) }
                            else { stoop(&ext[l], e: e, at: o.center, width: o.width, raise: lv[0], style: style, mats: mats, frame: frame, simple: true) }
                        }
                    }
                }
            }
        }
        // Floor-band hooks (nil from the procedural provider; apps can inject storefront or bay pieces).
        for e in shape.edges {
            for f in 0..<spec.floors {
                let slot: FacadeSlot = f == 0 ? .groundFloor : (f == spec.floors - 1 ? .attic : .typicalFloor)
                if slot == .attic { continue }
                for l in 0..<3 {
                    if let m = piece(ctx(slot, w: e.length, h: spec.floorHeight(f), floor: f, facade: e.index, lod: l)) { ext[l].add(m, frame(e, 0, f == 0 ? 0 : lv[f])) }
                }
            }
        }
        // Runs: base course, belt courses, cornice, parapet coping.
        let corniceH = style.corniceHeight
        let corniceY = roof == .flat ? roofY + 0.2 - corniceH : roofY - corniceH
        let baseH = Swift.max(style.baseHeight, lv[0] + 0.12)
        var runs: [(FacadeSlot, Float, Float)] = [(.baseCourse, 0, baseH), (.cornice, corniceY, corniceH)]
        for f in style.beltFloors where f < spec.floors - 1 { runs.append((.beltCourse, lv[f + 1] - 0.24, 0.2)) }
        if roof == .flat { runs.append((.attic, wallTop, 0.08)) }
        for (slot, y, h) in runs {
            for l in 0..<3 {
                if l == 2 && slot == .beltCourse { continue }
                var c = ctx(slot, w: 0, h: h, lod: l)
                if let p = prov.profile(c) {
                    var pts = p.points
                    if slot == .attic { pts = [V2(-exteriorWall - 0.03, 0), V2(0.05, 0), V2(0.05, 0.06), V2(-exteriorWall - 0.03, 0.08), V2(-exteriorWall - 0.03, 0)] }
                    for (ri, ring) in shape.rings.enumerated() {
                        if slot == .cornice && ri > 0 && l == 2 { continue }
                        ArchMesh.run(&ext[l], ring: ring, closed: true, y: y, profile: pts, material: p.material)
                    }
                    if slot == .cornice && l < 2 { corniceBlocks(&ext[l], shape: shape, y: y, profile: p, style: style, lod: l, mat: p.material) }
                } else {
                    for e in shape.edges {
                        c.width = e.length; c.facade = e.index
                        if let m = piece(c) { ext[l].add(m, frame(e, 0, y)) }
                    }
                }
            }
        }
        // Corners (quoins, pilasters) at convex vertices.
        let cornerTop = corniceY, cornerBase = baseH
        for ring in shape.edges.map(\.ring).uniqued() {
            let es = shape.edges.filter { $0.ring == ring }
            for (i, e) in es.enumerated() {
                let nx = es[(i + 1) % es.count]
                let t1 = e.tangent, t2 = nx.tangent
                guard t1.x * t2.y - t1.y * t2.x < -1e-3 else { continue }
                for l in 0..<3 {
                    guard let m = piece(ctx(.corner, w: 0.6, h: cornerTop - cornerBase, facade: e.index, lod: l)) else { continue }
                    ext[l].add(m, frame(e, e.length, cornerBase))
                    ext[l].add(mirrorX(m), frame(nx, 0, cornerBase))
                }
            }
        }
        // Balconies on the street facade.
        for f in style.balconyFloors where f < spec.floors {
            guard let e = shape.edges.first else { break }
            for l in 0..<2 { balcony(&ext[l], e: e, y: lv[f], lod: l, frame: frame, mats: mats) }
        }
        // Roof and the roof slab (top-floor ceiling).
        for l in 0..<3 {
            buildRoof(&ext[l], spec: spec, shape: shape, style: style, roof: roof, roofY: roofY, mats: mats, lod: l, layouts: lays, plans: plans, piece: { piece($0) }, ctx: { s, w, h, t, f, l in ctx(s, w: w, h: h, type: t, floor: f, lod: l) })
        }

        // Interiors.
        var interiors: [Model] = []
        var slabs = MeshBucket()
        for (f, plan) in plans.enumerated() {
            var m = MeshBucket()
            interior(&m, &slabs, spec: spec, plan: plan, shape: shape, lv: lv, mats: mats, last: f == spec.floors - 1)
            interiors.append(m.model("\(spec.name)-floor\(f)"))
        }
        if !spec.interiors { interiors = interiors.map { _ in Model(name: "empty") } }

        let exterior = LODModel(levels: ext.map { $0.model(spec.name) }, switchDistances: switchDistances)
        let top = exterior.levels[0].bounds.max.y
        let schedule = BuildingSchedule(spec: spec, shape: shape, plans: plans, generator: self, roofLevel: roofY)
        return BuildingModel(spec: spec, shape: shape, exterior: exterior, interiors: interiors, slabs: slabs.model("\(spec.name)-slabs"),
                             plans: plans, layouts: lays, schedule: schedule, roofLevel: roofY, height: top)
    }

    // MARK: pieces built by the generator

    func mirrorX(_ m: Model) -> Model {
        var out = m
        for i in out.surfaces.indices {
            var s = out.surfaces[i]
            s.positions = s.positions.map { V3(-$0.x, $0.y, $0.z) }
            s.normals = s.normals.map { V3(-$0.x, $0.y, $0.z) }
            s.uvs = s.uvs.map { V2(-$0.x, $0.y) }
            for t in stride(from: 0, to: s.indices.count, by: 3) { s.indices.swapAt(t + 1, t + 2) }
            s.computeTangents()
            out.surfaces[i] = s
        }
        return out
    }

    /// Steps (a stoop with cheek walls when tall) from grade up to the ground-floor level.
    func stoop(_ m: inout MeshBucket, e: FacadeEdge, at c: Float, width w: Float, raise: Float, style: ArchStyle,
               mats: [MaterialSlot: MaterialKey], frame: (FacadeEdge, Float, Float) -> Xform, simple: Bool = false) {
        guard raise > 0.05 else { return }
        let n = Int((raise / 0.18).rounded(.up)), r = raise / Float(n), tread: Float = 0.3
        let landing: Float = n > 3 ? 1.2 : 0.35
        let sw = w + (n > 3 ? 0.6 : 0.5)
        let mat = mats[.baseCourse]!
        var b = MeshBucket()
        if simple {
            b.box(V3(-sw / 2, 0, 0), V3(sw, 0, 0), V3(0, raise, 0), V3(0, 0, landing + Float(n - 1) * tread), mat)
        } else {
            b.box(V3(-sw / 2, 0, 0), V3(sw, 0, 0), V3(0, raise, 0), V3(0, 0, landing), mat)
            for i in 1..<n {
                b.box(V3(-sw / 2, 0, landing + Float(i - 1) * tread), V3(sw, 0, 0), V3(0, raise - Float(i) * r, 0), V3(0, 0, tread), mat)
            }
            if n > 3 {
                // Cheek walls with a sloped coping.
                let L = landing + Float(n - 1) * tread
                for sx: Float in [-1, 1] {
                    let x0 = sx < 0 ? -sw / 2 - 0.22 : sw / 2, x1 = x0 + 0.22
                    let prof: [V2] = [V2(0, 0), V2(L + 0.1, 0), V2(L + 0.1, 0.85), V2(landing, raise + 0.85), V2(0, raise + 0.85)]
                    prismX(&b, prof, x0: x0, x1: x1, mat: mats[.trim]!)
                }
            }
        }
        m.add(b.model("stoop"), frame(e, c, 0))
    }

    /// Prism along x from a convex (z, y) outline.
    func prismX(_ b: inout MeshBucket, _ p: [V2], x0: Float, x1: Float, mat: MaterialKey) {
        b.poly(p.map { V3(x0, $0.y, $0.x) }, mat, facing: V3(-1, 0, 0))
        b.poly(p.map { V3(x1, $0.y, $0.x) }, mat, facing: V3(1, 0, 0))
        let c = p.reduce(V2.zero, +) / Float(p.count)
        for i in p.indices {
            let a = p[i], d = p[(i + 1) % p.count]
            let mid = (a + d) / 2 - c
            b.poly([V3(x0, a.y, a.x), V3(x1, a.y, a.x), V3(x1, d.y, d.x), V3(x0, d.y, d.x)], mat, facing: V3(0, mid.y, mid.x))
        }
    }

    func corniceBlocks(_ m: inout MeshBucket, shape: FootprintShape, y: Float, profile: FacadeProfile, style: ArchStyle, lod: Int, mat: MaterialKey) {
        let p = profile.projection, h = profile.height
        let (spacing, size): (Float, V3)
        switch style.corniceBlocks {
        case .none: return
        case .dentils: guard lod == 0 else { return }; spacing = 0.22; size = V3(0.1, 0.12, 0.12 + 0.1 * p)
        case .modillions: spacing = lod == 0 ? 0.6 : 1.2; size = V3(0.14, 0.12, 0.8 * p)
        case .brackets: spacing = lod == 0 ? 0.9 : 1.8; size = V3(0.16, 0.55 * h, 0.85 * p)
        }
        let by: Float = style.corniceBlocks == .brackets ? y + 0.1 * h : y + 0.24 * h
        for e in shape.edges where e.length > 1 {
            let n = Int((e.length - 0.4) / spacing)
            guard n > 0 else { continue }
            let start = (e.length - Float(n - 1) * spacing) / 2
            let t = V3(e.tangent.x, 0, e.tangent.y), nn = V3(e.normal.x, 0, e.normal.y)
            for i in 0..<n {
                let s = start + Float(i) * spacing
                let o = V3(e.a.x, by, e.a.y) + t * (s - size.x / 2)
                if style.corniceBlocks == .brackets {
                    // Scrolled console: deep at the top, tapering down the wall.
                    m.box(o, t * size.x, V3(0, size.y * 0.3, 0), nn * size.z, mat)
                    m.box(o - V3(0, size.y * 0.7, 0), t * size.x, V3(0, size.y * 0.7, 0), nn * (size.z * 0.4), mat)
                } else {
                    m.box(o, t * size.x, V3(0, size.y, 0), nn * size.z, mat)
                }
            }
        }
    }

    func balcony(_ m: inout MeshBucket, e: FacadeEdge, y: Float, lod: Int, frame: (FacadeEdge, Float, Float) -> Xform, mats: [MaterialSlot: MaterialKey]) {
        var b = MeshBucket()
        let L = e.length, d: Float = 0.75, iron: MaterialKey = "metal.painted:1C1C1E"
        b.box(V3(0.2, -0.16, 0), V3(L - 0.4, 0, 0), V3(0, 0.16, 0), V3(0, 0, d), mats[.trim]!)
        b.box(V3(0.18, 0.95, d - 0.06), V3(L - 0.36, 0, 0), V3(0, 0.05, 0), V3(0, 0, 0.06), iron)
        b.box(V3(0.2, 0.08, d - 0.05), V3(L - 0.4, 0, 0), V3(0, 0.03, 0), V3(0, 0, 0.03), iron)
        for z in [Float(0.2), L - 0.2] {
            b.box(V3(z - 0.015, 0.05, 0.02), V3(0.03, 0, 0), V3(0, 0.03, 0), V3(0, 0, d - 0.04), iron)
            b.box(V3(z - 0.015, 0.95, 0.02), V3(0.03, 0, 0), V3(0, 0.05, 0), V3(0, 0, d - 0.04), iron)
        }
        if lod == 0 {
            var x: Float = 0.3
            while x < L - 0.25 { b.box(V3(x - 0.007, 0.11, d - 0.045), V3(0.014, 0, 0), V3(0, 0.84, 0), V3(0, 0, 0.014), iron); x += 0.12 }
            var c: Float = 0.6
            while c < L - 0.5 { b.box(V3(c - 0.08, -0.5, 0), V3(0.16, 0, 0), V3(0, 0.34, 0), V3(0, 0, 0.35), mats[.trim]!); c += 1.8 }
        } else {
            var x: Float = 0.6
            while x < L - 0.4 { b.box(V3(x - 0.012, 0.11, d - 0.05), V3(0.024, 0, 0), V3(0, 0.84, 0), V3(0, 0, 0.024), iron); x += 0.6 }
        }
        m.add(b.model("balcony"), frame(e, 0, y))
    }

    // MARK: roof

    func buildRoof(_ m: inout MeshBucket, spec: BuildingSpec, shape: FootprintShape, style: ArchStyle, roof: RoofType, roofY: Float,
                   mats: [MaterialSlot: MaterialKey], lod: Int, layouts: [FacadeLayout], plans: [FloorPlan],
                   piece: (FacadePieceContext) -> Model?, ctx: (FacadeSlot, Float, Float, WindowType?, Int, Int) -> FacadePieceContext) {
        let roofMat = mats[.roof]!, wallMat = mats[.wall]!, trim = mats[.trim]!
        // Roof slab per wing (ceiling below, membrane or attic floor above).
        for w in shape.wings {
            let r = w.inset(0.01)
            m.box(V3(r.min.x, roofY - slab, r.min.y), V3(r.size.x, 0, 0), V3(0, slab, 0), V3(0, 0, r.size.y)) { n in
                n.y > 0.7 ? (roof == .flat ? roofMat : "concrete.smooth") : (n.y < -0.7 ? mats[.ceiling]! : mats[.slab]!)
            }
        }
        if roof == .flat {
            // Stair bulkhead and a plant box on the roof.
            if lod < 2, let st = plans.first?.stair {
                let r = st.rect
                m.box(V3(r.min.x + 0.1, roofY, r.min.y + 0.1), V3(r.size.x - 0.2, 0, 0), V3(0, 2.5, 0), V3(0, 0, r.size.y - 0.2), wallMat)
                m.box(V3(r.min.x, roofY + 2.5, r.min.y), V3(r.size.x, 0, 0), V3(0, 0.12, 0), V3(0, 0, r.size.y), trim)
            }
            return
        }
        let pitch = radians(Swift.min(Swift.max(spec.roofPitch, 10), 60))
        let oh: Float = roof == .mansard ? 0.12 : 0.35
        for w in shape.wings {
            let ax = w.size.x >= w.size.y
            // Local frame: u along the long axis, v across.
            let u0 = (ax ? w.min.x : w.min.y) - oh, u1 = (ax ? w.max.x : w.max.y) + oh
            let v0 = (ax ? w.min.y : w.min.x) - oh, v1 = (ax ? w.max.y : w.max.x) + oh
            let S = v1 - v0, vm = (v0 + v1) / 2
            func P(_ u: Float, _ v: Float, _ y: Float) -> V3 { ax ? V3(u, y, v) : V3(v, y, u) }
            let ey = roofY - oh * tan(pitch)   // eave line lowered by the overhang
            func face(_ pts: [V3], _ mat: MaterialKey, up: Bool = true) {
                let c = pts.reduce(V3.zero, +) / Float(pts.count)
                let cen = P((u0 + u1) / 2, vm, c.y - 5)
                m.poly(pts, mat, facing: c - cen)
                if lod < 2 { m.poly(pts.map { $0 - V3(0, 0.1, 0) }, trim, facing: cen - c) }   // soffit
            }
            func gableEnd(_ u: Float, _ prof: [(Float, Float)], out: Float) {
                let wu = ax ? (out < 0 ? w.min.x : w.max.x) : (out < 0 ? w.min.y : w.max.y)
                _ = u
                m.poly(prof.map { P(wu, $0.0, $0.1) }, wallMat, facing: ax ? V3(out, 0, 0) : V3(0, 0, out))
            }
            switch roof {
            case .gable:
                let ry = roofY + (S / 2 - oh) * tan(pitch)
                face([P(u0, v0, ey), P(u1, v0, ey), P(u1, vm, ry), P(u0, vm, ry)], roofMat)
                face([P(u1, v1, ey), P(u0, v1, ey), P(u0, vm, ry), P(u1, vm, ry)], roofMat)
                let wv0 = v0 + oh, wv1 = v1 - oh
                gableEnd(u0, [(wv0, roofY), (wv1, roofY), (vm, ry - 0.05)], out: -1)
                gableEnd(u1, [(wv0, roofY), (wv1, roofY), (vm, ry - 0.05)], out: 1)
                if lod < 2 { chimneys(&m, P: P, us: [u0 + oh + 0.5, u1 - oh - 0.5], v: vm, top: ry + 0.9, base: roofY) }
            case .gambrel:
                let low = radians(62), up = radians(24), k = S * 0.2
                let ky = ey + k * tan(low), ry = ky + (S / 2 - k) * tan(up)
                face([P(u0, v0, ey), P(u1, v0, ey), P(u1, v0 + k, ky), P(u0, v0 + k, ky)], roofMat)
                face([P(u0, v0 + k, ky), P(u1, v0 + k, ky), P(u1, vm, ry), P(u0, vm, ry)], roofMat)
                face([P(u1, v1, ey), P(u0, v1, ey), P(u0, v1 - k, ky), P(u1, v1 - k, ky)], roofMat)
                face([P(u1, v1 - k, ky), P(u0, v1 - k, ky), P(u0, vm, ry), P(u1, vm, ry)], roofMat)
                let wv0 = v0 + oh, wv1 = v1 - oh
                let prof: [(Float, Float)] = [(wv0, roofY), (wv1, roofY), (v1 - k, ky - 0.05), (vm, ry - 0.05), (v0 + k, ky - 0.05)]
                gableEnd(u0, prof, out: -1); gableEnd(u1, prof, out: 1)
            case .hip:
                let ry = ey + (S / 2) * tan(pitch)
                let r0 = Swift.min(u0 + S / 2, (u0 + u1) / 2), r1 = Swift.max(u1 - S / 2, (u0 + u1) / 2)
                face([P(u0, v0, ey), P(u1, v0, ey), P(r1, vm, ry), P(r0, vm, ry)], roofMat)
                face([P(u1, v1, ey), P(u0, v1, ey), P(r0, vm, ry), P(r1, vm, ry)], roofMat)
                face([P(u1, v0, ey), P(u1, v1, ey), P(r1, vm, ry)], roofMat)
                face([P(u0, v1, ey), P(u0, v0, ey), P(r0, vm, ry)], roofMat)
                if lod < 2 { chimneys(&m, P: P, us: [r0 + 0.6, r1 - 0.6], v: vm, top: ry + 0.8, base: roofY) }
            case .mansard:
                let hm: Float = 2.7, k = hm / tan(radians(72))
                let ty = roofY + hm
                let a0 = u0 + k, a1 = u1 - k, b0 = v0 + k, b1 = v1 - k
                face([P(u0, v0, roofY), P(u1, v0, roofY), P(a1, b0, ty), P(a0, b0, ty)], roofMat)
                face([P(u1, v1, roofY), P(u0, v1, roofY), P(a0, b1, ty), P(a1, b1, ty)], roofMat)
                face([P(u1, v0, roofY), P(u1, v1, roofY), P(a1, b1, ty), P(a1, b0, ty)], roofMat)
                face([P(u0, v1, roofY), P(u0, v0, roofY), P(a0, b0, ty), P(a0, b1, ty)], roofMat)
                // Shallow top with a zinc roll at the break.
                let tr = roofY + hm + 0.35
                face([P(a0, b0, ty), P(a1, b0, ty), P(a1 - 0.6, b0 + 0.6, tr), P(a0 + 0.6, b0 + 0.6, tr)], roofMat)
                face([P(a1, b1, ty), P(a0, b1, ty), P(a0 + 0.6, b1 - 0.6, tr), P(a1 - 0.6, b1 - 0.6, tr)], roofMat)
                face([P(a1, b0, ty), P(a1, b1, ty), P(a1 - 0.6, b1 - 0.6, tr), P(a1 - 0.6, b0 + 0.6, tr)], roofMat)
                face([P(a0, b1, ty), P(a0, b0, ty), P(a0 + 0.6, b0 + 0.6, tr), P(a0 + 0.6, b1 - 0.6, tr)], roofMat)
                m.poly([P(a0 + 0.6, b0 + 0.6, tr), P(a1 - 0.6, b0 + 0.6, tr), P(a1 - 0.6, b1 - 0.6, tr), P(a0 + 0.6, b1 - 0.6, tr)], roofMat, facing: V3(0, 1, 0))
                if lod < 2 { chimneys(&m, P: P, us: [a0 + 0.8, a1 - 0.8], v: vm, top: tr + 1.4, base: ty - 0.2) }
            case .flat: break
            }
        }
        // Mansard dormers over the window bays of every outer edge.
        if roof == .mansard && lod < 2 {
            let k = 2.7 / tan(radians(72))
            for (e, lay) in zip(shape.edges, layouts) where e.ring == 0 && lay.bays > 0 {
                let t = V3(e.tangent.x, 0, e.tangent.y), n = V3(e.normal.x, 0, e.normal.y)
                for b in 0..<lay.bays where !lay.blankBays.contains(b) {
                    let c = lay.center(b)
                    let dw = Swift.min(lay.step - 0.6, 1.2)
                    guard c - dw / 2 > k + 0.3, c + dw / 2 < e.length - k - 0.3 else { continue }
                    let inset: Float = 0.25, base = roofY + 0.25, dh: Float = 1.75
                    let fo = V3(e.a.x, 0, e.a.y) + t * c - n * inset
                    var d = MeshBucket()
                    let back: Float = 1.1
                    // Cheeks and face (local: x along facade, z out).
                    d.box(V3(-dw / 2 - 0.12, 0, -back), V3(0.12, 0, 0), V3(0, dh, 0), V3(0, 0, back), trim)
                    d.box(V3(dw / 2, 0, -back), V3(0.12, 0, 0), V3(0, dh, 0), V3(0, 0, back), trim)
                    d.box(V3(-dw / 2, 0, -back), V3(dw, 0, 0), V3(0, 0.12, 0), V3(0, 0, back), trim)
                    // Segmental cap.
                    d.box(V3(-dw / 2 - 0.2, dh, -back), V3(dw + 0.4, 0, 0), V3(0, 0.14, 0), V3(0, 0, back + 0.12), trim)
                    d.poly([V3(-dw / 2 - 0.2, dh + 0.14, 0.12), V3(dw / 2 + 0.2, dh + 0.14, 0.12), V3(0, dh + 0.5, 0.12)], trim, facing: V3(0, 0, 1))
                    d.poly([V3(dw / 2 + 0.2, dh + 0.14, 0.12), V3(dw / 2 + 0.2, dh + 0.14, -back), V3(0, dh + 0.5, -back), V3(0, dh + 0.5, 0.12)], roofMat, facing: V3(0.4, 1, 0))
                    d.poly([V3(-dw / 2 - 0.2, dh + 0.14, -back), V3(-dw / 2 - 0.2, dh + 0.14, 0.12), V3(0, dh + 0.5, 0.12), V3(0, dh + 0.5, -back)], roofMat, facing: V3(-0.4, 1, 0))
                    if let w = piece(ctx(.window, dw, dh - 0.12, .casement, spec.floors, lod)) { d.add(w, Xform(translation: V3(0, 0.12, 0))) }
                    let yaw = atan2(-t.z, t.x)
                    m.add(d.model("dormer"), Xform(translation: fo + V3(0, base, 0), rotation: simd_quatf(angle: yaw, axis: V3(0, 1, 0))))
                }
            }
        }
    }

    func chimneys(_ m: inout MeshBucket, P: (Float, Float, Float) -> V3, us: [Float], v: Float, top: Float, base: Float) {
        for u in us {
            let c = P(u, v, base)
            m.aabb(center: V3(c.x, (base + top) / 2, c.z), size: V3(0.8, top - base, 0.8), "brick.red:8E4434")
            m.aabb(center: V3(c.x, top + 0.05, c.z), size: V3(0.92, 0.1, 0.92), "rock.limestone")
        }
    }

    // MARK: interior

    func interior(_ m: inout MeshBucket, _ slabs: inout MeshBucket, spec: BuildingSpec, plan: FloorPlan, shape: FootprintShape, lv: [Float],
                  mats: [MaterialSlot: MaterialKey], last: Bool) {
        let f = plan.floor, y = lv[f]
        let ceilY = lv[f + 1] - slab
        // Slabs per room; boundary sides stop inside the exterior wall; the stair keeps only its landing above floor 0.
        for r in plan.rooms {
            var rect = r.rect
            if r.kind == .stair, f > 0, let st = plan.stair {
                rect = st.alongX ? PlanRect(rect.min.x, rect.min.y, rect.min.x + st.landing, rect.max.y)
                                 : PlanRect(rect.min.x, rect.min.y, rect.max.x, rect.min.y + st.landing)
            }
            let c = rect.center, h = rect.size / 2
            var mn = rect.min, mx = rect.max
            let cut = exteriorWall - 0.02
            if shape.onBoundary(V2(c.x - h.x, c.y), eps: 0.05) { mn.x += cut }
            if shape.onBoundary(V2(c.x + h.x, c.y), eps: 0.05) { mx.x -= cut }
            if shape.onBoundary(V2(c.x, c.y - h.y), eps: 0.05) { mn.y += cut }
            if shape.onBoundary(V2(c.x, c.y + h.y), eps: 0.05) { mx.y -= cut }
            let top = r.kind == .room ? mats[.floor]! : mats[.corridorFloor]!
            let y0: Float = f == 0 ? 0 : y - slab
            for bucket in [0, 1] {
                let sz = mx - mn
                let fn: (V3) -> MaterialKey = { n in n.y > 0.7 ? top : (n.y < -0.7 ? mats[.ceiling]! : mats[.slab]!) }
                if bucket == 0 { m.box(V3(mn.x, y0, mn.y), V3(sz.x, 0, 0), V3(0, y - y0, 0), V3(0, 0, sz.y), fn) }
                else { slabs.box(V3(mn.x, y0, mn.y), V3(sz.x, 0, 0), V3(0, y - y0, 0), V3(0, 0, sz.y), fn) }
            }
        }
        guard spec.interiors else { return }
        let wallMat = mats[.interiorWall]!, casing: MaterialKey = "paint.wall:F7F5F0"
        for w in plan.walls where !w.exterior {
            ArchMesh.wall(&m, seg: w, s0: 0, s1: w.length, y0: y, y1: ceilY, floorY: y, openings: w.openings, outer: wallMat, inner: wallMat, reveal: wallMat)
        }
        // Thresholds and casings at every doorway.
        for w in plan.walls {
            let t = V3(w.tangent.x, 0, w.tangent.y), n = V3(w.normal.x, 0, w.normal.y)
            let a = V3(w.a.x, 0, w.a.y)
            for o in w.openings where o.kind != .window {
                let zc: Float = w.exterior ? -w.thickness / 2 : 0
                let c = a + t * o.center + n * zc
                let depth = w.thickness + 0.04
                let thr: MaterialKey = w.exterior ? mats[.trim]! : "wood.oak"
                m.box(c - t * (o.width / 2) - n * (depth / 2) + V3(0, y, 0), t * o.width, V3(0, 0.012, 0), n * depth, thr)
                if !w.exterior {
                    for side: Float in [-1, 1] {
                        let face = c + n * (side * w.thickness / 2)
                        let hy = y + o.head
                        m.box(face - t * (o.width / 2 + 0.07) + V3(0, y, 0), t * 0.07, V3(0, o.head + 0.07, 0), n * (side * 0.015), casing)
                        m.box(face + t * (o.width / 2) + V3(0, y, 0), t * 0.07, V3(0, o.head + 0.07, 0), n * (side * 0.015), casing)
                        m.box(face - t * (o.width / 2) + V3(0, hy, 0), t * o.width, V3(0, 0.07, 0), n * (side * 0.015), casing)
                    }
                }
            }
        }
        // Stairs to the next floor; a guard across the stairwell on the top floor.
        guard let st = plan.stair else { return }
        let r = st.rect, ax = st.alongX
        let su0 = ax ? r.min.x : r.min.y, su1 = ax ? r.max.x : r.max.y
        let sv0 = (ax ? r.min.y : r.min.x) + interiorWall / 2, sv1 = (ax ? r.max.y : r.max.x) - interiorWall / 2
        func P(_ u: Float, _ v: Float, _ yy: Float) -> V3 { ax ? V3(u, yy, v) : V3(v, yy, u) }
        func box(_ ua: Float, _ ub: Float, _ va: Float, _ vb: Float, _ ya: Float, _ yb: Float, _ mat: MaterialKey) {
            m.box(P(ua, va, ya), P(ub - ua, 0, 0) - P(0, 0, 0), V3(0, yb - ya, 0), P(0, vb - va, 0) - P(0, 0, 0), mat)
        }
        let vm = (sv0 + sv1) / 2, cw: Float = 0.1
        let fu0 = su0 + st.landing, fu1 = su1 - st.halfLanding
        let stairMat = mats[.stair]!
        if last {
            box(fu0, su1, vm - cw / 2, vm + cw / 2, y, y + 1.07, wallMat)
            box(fu0 - 0.05, fu0, sv0, vm - cw / 2, y, y + 1.07, wallMat)
            return
        }
        let fh = lv[f + 1] - y
        let risers = Swift.max(2, Int((fh / 0.18).rounded(.up)))
        let rh = fh / Float(risers)
        let n1 = risers / 2, n2 = risers - n1
        let run = fu1 - fu0
        let g1 = run / Float(n1), g2 = run / Float(Swift.max(1, n2 - 1))
        // Flight 1 on side A rises along +u to the half landing.
        for i in 0..<n1 {
            let top = y + Float(i + 1) * rh
            box(fu0 + Float(i) * g1, fu0 + Float(i + 1) * g1, sv0, vm - cw / 2, Swift.max(y, top - 0.45), top, stairMat)
        }
        let mid = y + Float(n1) * rh
        box(fu1, su1, sv0, sv1, mid - 0.2, mid, stairMat)
        // Flight 2 on side B rises back along -u to the floor landing above.
        for i in 0..<(n2 - 1) {
            let top = mid + Float(i + 1) * rh
            let ua = fu1 - Float(i + 1) * g2, ub = fu1 - Float(i) * g2
            box(ua, ub, vm + cw / 2, sv1, Swift.max(mid - 0.2, top - 0.45), top, stairMat)
        }
        // Center wall between flights.
        box(fu0, fu1, vm - cw / 2, vm + cw / 2, y, lv[f + 1] - slab, wallMat)
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] { var seen: Set<Element> = []; return filter { seen.insert($0).inserted } }
}
