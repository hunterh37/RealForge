import simd
import Foundation

public enum RoomKind: String, Codable, CaseIterable, Sendable { case room, corridor, stair, lobby, shop }

/// An editable room: name, kind and an axis-aligned rectangle on the plan. Rooms tile the footprint;
/// walls and doors are derived from the shared edges (`FloorPlan.derive`).
public struct PlanRoom: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var name: String
    public var kind: RoomKind
    public var rect: PlanRect
    public init(id: Int, name: String, kind: RoomKind, rect: PlanRect) { self.id = id; self.name = name; self.kind = kind; self.rect = rect }
    /// Gross rectangle area (m2).
    public var grossArea: Float { rect.area }
}

/// A hole in a wall. `center` is measured along the wall from `a`; `sill` and `head` from the floor level.
public struct WallOpening: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case door, passage, window }
    public var kind: Kind
    public var center: Float
    public var width: Float
    public var sill: Float
    public var head: Float
    public var window: WindowType?
    /// Room ids on either side (-1 exterior, -2 void).
    public var rooms: [Int]
    /// Facade bay index for exterior openings.
    public var bay: Int?
    public init(kind: Kind, center: Float, width: Float, sill: Float, head: Float, window: WindowType? = nil, rooms: [Int] = [], bay: Int? = nil) {
        self.kind = kind; self.center = center; self.width = width; self.sill = sill; self.head = head; self.window = window; self.rooms = rooms; self.bay = bay
    }
    public var span: ClosedRange<Float> { (center - width / 2)...(center + width / 2) }
}

/// A straight wall on one floor. Exterior walls have their outer face on the footprint line and grow
/// inward (left of a -> b); interior walls are centered on the line.
public struct WallSegment: Codable, Hashable, Sendable {
    public var a: V2
    public var b: V2
    public var thickness: Float
    public var exterior: Bool
    public var facade: Int?
    public var rooms: [Int]
    public var openings: [WallOpening]
    public init(a: V2, b: V2, thickness: Float, exterior: Bool, facade: Int? = nil, rooms: [Int] = [], openings: [WallOpening] = []) {
        self.a = a; self.b = b; self.thickness = thickness; self.exterior = exterior; self.facade = facade; self.rooms = rooms; self.openings = openings
    }
    public var length: Float { simd_distance(a, b) }
    public var tangent: V2 { simd_normalize(b - a) }
    public var normal: V2 { let t = tangent; return V2(-t.y, t.x) }
    public func point(_ s: Float) -> V2 { a + tangent * s }
}

public struct PlanDoor: Codable, Hashable, Sendable {
    public var position: V2
    public var width: Float
    public var height: Float
    public var rooms: [Int]
    public var exterior: Bool
    public var passage: Bool
    public var wall: Int
}

/// Switchback stair: floor landing at the start end (`landing` deep), two flights side by side, a
/// half landing at the far end.
public struct StairCore: Codable, Hashable, Sendable {
    public var rect: PlanRect
    public var alongX: Bool
    public var landing: Float = 1.45
    public var halfLanding: Float = 1.2
    public init(rect: PlanRect, alongX: Bool) { self.rect = rect; self.alongX = alongX }
}

/// One floor: rooms plus derived walls (exterior and interior, with openings) and doors.
public struct FloorPlan: Codable, Hashable, Sendable {
    public var floor: Int
    public var level: Float
    public var height: Float
    public var rooms: [PlanRoom]
    public var walls: [WallSegment] = []
    public var stair: StairCore?

    public var doors: [PlanDoor] {
        var out: [PlanDoor] = []
        for (wi, w) in walls.enumerated() {
            for o in w.openings where o.kind != .window {
                out.append(PlanDoor(position: w.point(o.center), width: o.width, height: o.head - o.sill, rooms: o.rooms, exterior: w.exterior, passage: o.kind == .passage, wall: wi))
            }
        }
        return out
    }
    public var windows: [(wall: Int, opening: WallOpening)] {
        walls.enumerated().flatMap { wi, w in w.openings.filter { $0.kind == .window }.map { (wi, $0) } }
    }
    public func room(_ id: Int) -> PlanRoom? { rooms.first { $0.id == id } }
    public func room(at p: V2) -> PlanRoom? { rooms.first { $0.rect.contains(p, eps: 0) } }

    /// Net area of a room: the rectangle less half the interior walls and the full exterior wall depth.
    public func netArea(_ r: PlanRoom, shape: FootprintShape, exterior: Float, interior: Float) -> Float {
        let c = r.rect.center, h = r.rect.size / 2
        func cut(_ mid: V2) -> Float { shape.onBoundary(mid, eps: 0.05) ? exterior : interior / 2 }
        let w = r.rect.size.x - cut(V2(c.x - h.x, c.y)) - cut(V2(c.x + h.x, c.y))
        let d = r.rect.size.y - cut(V2(c.x, c.y - h.y)) - cut(V2(c.x, c.y + h.y))
        return Swift.max(0, w) * Swift.max(0, d)
    }
}

public extension FloorPlan {
    /// Interior walls and doors from the room list. Shared room edges become walls (one per room pair);
    /// rooms get a door to an adjacent corridor, corridors meet through passages, and any room still
    /// unreachable from the stair gets a door to a reachable neighbor.
    mutating func deriveInterior(shape: FootprintShape, thickness t: Float, exteriorThickness et: Float,
                                 doorWidth: Float = 0.81, doorHead: Float = 2.03) {
        walls.removeAll { !$0.exterior }
        struct Edge { var horizontal: Bool; var c: Float; var s0: Float; var s1: Float; var room: Int; var positive: Bool }
        var lines: [String: [Edge]] = [:]
        func key(_ h: Bool, _ c: Float) -> String { "\(h ? "h" : "v")\(Int((c * 1000).rounded()))" }
        for r in rooms {
            let mn = r.rect.min, mx = r.rect.max
            // horizontal lines (const z): room above (positive side) at min.y, below at max.y
            for (h, c, s0, s1, pos) in [(true, mn.y, mn.x, mx.x, true), (true, mx.y, mn.x, mx.x, false),
                                        (false, mn.x, mn.y, mx.y, true), (false, mx.x, mn.y, mx.y, false)] {
                lines[key(h, c), default: []].append(Edge(horizontal: h, c: c, s0: s0, s1: s1, room: r.id, positive: pos))
            }
        }
        var segs: [WallSegment] = []
        var meta: [(s0: Float, s1: Float, horizontal: Bool, c: Float)] = []
        for k in lines.keys.sorted() {
            let es = lines[k]!
            let h = es[0].horizontal, c = es[0].c
            let pts = Array(Set(es.flatMap { [($0.s0 * 1000).rounded() / 1000, ($0.s1 * 1000).rounded() / 1000] })).sorted()
            var runs: [(Float, Float, Int, Int)] = []   // s0, s1, negRoom, posRoom
            for i in 0..<(pts.count - 1) {
                let m = (pts[i] + pts[i + 1]) / 2
                let cov = es.filter { $0.s0 < m && $0.s1 > m }
                let neg = cov.first { !$0.positive }?.room ?? -2, pos = cov.first { $0.positive }?.room ?? -2
                if neg == -2 && pos == -2 { continue }
                let mid = h ? V2(m, c) : V2(c, m)
                if (neg == -2 || pos == -2) && shape.onBoundary(mid, eps: 0.03) { continue }   // exterior wall
                if let last = runs.last, abs(last.1 - pts[i]) < 1e-4, last.2 == neg, last.3 == pos { runs[runs.count - 1].1 = pts[i + 1] }
                else { runs.append((pts[i], pts[i + 1], neg, pos)) }
            }
            for (s0, s1, neg, pos) in runs {
                func end(_ s: Float, _ dir: Float) -> Float {
                    let p = h ? V2(s, c) : V2(c, s)
                    return shape.boundaryDistance(p) < et + 0.02 ? s + dir * (et - 0.02) : s - dir * t / 2
                }
                let a0 = end(s0, 1), b0 = end(s1, -1)
                guard b0 - a0 > 0.05 else { continue }
                segs.append(WallSegment(a: h ? V2(a0, c) : V2(c, a0), b: h ? V2(b0, c) : V2(c, b0), thickness: t, exterior: false, rooms: [neg, pos]))
                meta.append((a0, b0, h, c))
            }
        }
        let kinds = Dictionary(rooms.map { ($0.id, $0.kind) }, uniquingKeysWith: { a, _ in a })
        func kind(_ id: Int) -> RoomKind? { kinds[id] }
        func other(_ s: WallSegment, _ id: Int) -> Int { s.rooms[0] == id ? s.rooms[1] : s.rooms[0] }
        @discardableResult
        func addDoor(_ si: Int, width: Float, head: Float, kind k: WallOpening.Kind, near: V2? = nil) -> Bool {
            let L = segs[si].length
            guard L >= width + 0.2 else { return false }
            var c = L / 2
            if let near { c = simd_dot(near - segs[si].a, segs[si].tangent) }
            c = Swift.min(Swift.max(c, width / 2 + 0.1), L - width / 2 - 0.1)
            let span = (c - width / 2 - 0.1)...(c + width / 2 + 0.1)
            if segs[si].openings.contains(where: { $0.span.overlaps(span) }) { return false }
            segs[si].openings.append(WallOpening(kind: k, center: c, width: width, sill: 0, head: Swift.min(head, height - 0.15), rooms: segs[si].rooms))
            return true
        }
        func isCorr(_ id: Int) -> Bool { kinds[id] == .corridor }
        // Rooms to corridors.
        for r in rooms where r.kind != .corridor {
            let cand = segs.indices.filter { segs[$0].rooms.contains(r.id) && isCorr(other(segs[$0], r.id)) }.sorted { segs[$0].length > segs[$1].length }
            for si in cand {
                var near: V2? = nil
                if r.kind == .stair, let st = stair {
                    near = st.alongX ? V2(st.rect.min.x + st.landing / 2, st.rect.center.y) : V2(st.rect.center.x, st.rect.min.y + st.landing / 2)
                }
                let lobby = r.kind == .lobby || r.kind == .shop
                if addDoor(si, width: lobby ? 1.4 : (r.kind == .stair ? 0.91 : doorWidth), head: lobby ? 2.4 : doorHead,
                           kind: lobby ? .passage : .door, near: near) { break }
            }
        }
        // Corridor to corridor.
        for si in segs.indices where isCorr(segs[si].rooms[0]) && isCorr(segs[si].rooms[1]) {
            addDoor(si, width: Swift.min(1.8, segs[si].length - 0.2), head: 2.4, kind: .passage)
        }
        // Reachability from the stair (or the first corridor).
        let root = rooms.first { $0.kind == .stair }?.id ?? rooms.first { $0.kind == .corridor }?.id ?? rooms.first?.id
        if let root {
            var changed = true
            while changed {
                changed = false
                var reach: Set<Int> = [root], queue = [root]
                while let x = queue.popLast() {
                    for s in segs where s.rooms.contains(x) && !s.openings.isEmpty {
                        let y = other(s, x)
                        if y >= 0, !reach.contains(y) { reach.insert(y); queue.append(y) }
                    }
                }
                for r in rooms where !reach.contains(r.id) {
                    let cand = segs.indices.filter { segs[$0].rooms.contains(r.id) && reach.contains(other(segs[$0], r.id)) }.sorted { segs[$0].length > segs[$1].length }
                    var near: V2? = nil
                    if r.kind == .stair, let st = stair {
                        near = st.alongX ? V2(st.rect.min.x + st.landing / 2, st.rect.center.y) : V2(st.rect.center.x, st.rect.min.y + st.landing / 2)
                    }
                    if let si = cand.first(where: { segs[$0].length >= doorWidth + 0.3 }), addDoor(si, width: r.kind == .stair ? 0.91 : doorWidth, head: doorHead, kind: .door, near: near) {
                        changed = true; break
                    }
                }
            }
        }
        _ = meta
        walls += segs
    }
}

/// Generates room layouts: per wing a double-loaded corridor (wings 9 m deep or more), a single-loaded
/// one (5.5 to 9 m) or an enfilade of rooms, a stair core at the start of the largest wing, corridor
/// connectors where wings meet, and a BSP split of each room strip on the bay grid.
public struct FloorPlanner: Sendable {
    public var shape: FootprintShape
    public var spec: BuildingSpec
    public init(spec: BuildingSpec) { self.spec = spec; self.shape = FootprintShape(spec.footprint) }

    struct WingLayout { var rect: PlanRect; var alongX: Bool; var corridor: PlanRect?; var strips: [PlanRect] }

    func u(_ p: V2, _ ax: Bool) -> Float { ax ? p.x : p.y }
    func v(_ p: V2, _ ax: Bool) -> Float { ax ? p.y : p.x }
    func rect(_ u0: Float, _ u1: Float, _ v0: Float, _ v1: Float, _ ax: Bool) -> PlanRect {
        ax ? PlanRect(u0, v0, u1, v1) : PlanRect(v0, u0, v1, u1)
    }

    func layouts() -> [WingLayout] {
        shape.wings.map { w in
            let ax = w.size.x >= w.size.y
            let u0 = u(w.min, ax), u1 = u(w.max, ax), v0 = v(w.min, ax), v1 = v(w.max, ax), s = v1 - v0
            if s >= 9 {
                let m = (v0 + v1) / 2
                return WingLayout(rect: w, alongX: ax, corridor: rect(u0, u1, m - 0.9, m + 0.9, ax),
                                  strips: [rect(u0, u1, v0, m - 0.9, ax), rect(u0, u1, m + 0.9, v1, ax)])
            } else if s >= 5.5 {
                // Corridor on the side toward the footprint center.
                let toward = (v0 + v1) / 2 > 0 ? v0 : v1
                if toward == v0 { return WingLayout(rect: w, alongX: ax, corridor: rect(u0, u1, v0, v0 + 1.5, ax), strips: [rect(u0, u1, v0 + 1.5, v1, ax)]) }
                return WingLayout(rect: w, alongX: ax, corridor: rect(u0, u1, v1 - 1.5, v1, ax), strips: [rect(u0, u1, v0, v1 - 1.5, ax)])
            }
            return WingLayout(rect: w, alongX: ax, corridor: nil, strips: [w])
        }
    }

    /// Main wing index (largest area) that holds the stair.
    var mainWing: Int { shape.wings.indices.max { shape.wings[$0].area < shape.wings[$1].area } ?? 0 }

    public func stairCore() -> StairCore? {
        let ls = layouts()
        guard !ls.isEmpty, spec.floors > 1 else { return nil }
        let w = ls[mainWing]
        let strip = w.strips[0], ax = w.alongX
        let len = u(w.rect.max, ax) - u(w.rect.min, ax)
        let step = len / Float(Swift.max(1, Int((len / spec.bayWidth).rounded())))
        var ls0 = (4.9 / step).rounded(.up) * step
        if ls0 > len * 0.6 { ls0 = Swift.max(4.9, len * 0.6) }
        let u0 = u(strip.min, ax)
        return StairCore(rect: rect(u0, u0 + ls0, v(strip.min, ax), v(strip.max, ax), ax), alongX: ax)
    }

    /// Room list for a floor (or the spec's override for it).
    public func rooms(floor: Int) -> [PlanRoom] {
        if let o = spec.roomOverrides[floor] { return o }
        var rng = SeededRNG(seed: spec.seed &+ 0x51A7).fork(floor == 0 ? 0 : 1)
        let ls = layouts(), stair = stairCore()
        let style = spec.resolvedStyle
        let commercial = floor == 0 && style.groundWindow == .storefront
        var out: [PlanRoom] = []
        func add(_ kind: RoomKind, _ r: PlanRect) {
            let n = out.filter { $0.kind == kind }.count + 1
            let name: String
            switch kind {
            case .corridor: name = "Corridor"
            case .stair: name = "Stair"
            case .lobby: name = "Lobby"
            case .shop: name = "Shop \(floor)\(String(format: "%02d", n))"
            case .room: name = "Room \(floor + 1)\(String(format: "%02d", n))"
            }
            out.append(PlanRoom(id: out.count, name: name, kind: kind, rect: r))
        }
        for (wi, w) in ls.enumerated() {
            let ax = w.alongX
            let wu0 = u(w.rect.min, ax), wu1 = u(w.rect.max, ax), len = wu1 - wu0
            let step = len / Float(Swift.max(1, Int((len / spec.bayWidth).rounded())))
            if let c = w.corridor { add(.corridor, c) }
            for (si, s) in w.strips.enumerated() {
                let sv0 = v(s.min, ax), sv1 = v(s.max, ax)
                var cuts: [(Float, Float, RoomKind)] = []   // fixed pieces
                if wi == mainWing, si == 0, let st = stair { cuts.append((u(st.rect.min, ax), u(st.rect.max, ax), .stair)) }
                // Connectors: another wing's corridor ending on this strip's outer edge.
                for (wj, o) in ls.enumerated() where wj != wi && o.alongX != ax {
                    guard let oc = o.corridor else { continue }
                    let ou0 = u(oc.min, ax), ou1 = u(oc.max, ax)
                    let ov0 = v(oc.min, ax), ov1 = v(oc.max, ax)
                    let touches = abs(ov1 - sv0) < 0.01 || abs(ov0 - sv1) < 0.01
                    if touches, ou0 >= wu0 - 0.01, ou1 <= wu1 + 0.01, !cuts.contains(where: { $0.0 < ou1 && $0.1 > ou0 }) {
                        cuts.append((ou0, ou1, .corridor))
                    }
                }
                cuts.sort { $0.0 < $1.0 }
                var free: [(Float, Float)] = []
                var cur = wu0
                for c in cuts { if c.0 > cur + 0.01 { free.append((cur, c.0)) }; cur = Swift.max(cur, c.1) }
                if wu1 > cur + 0.01 { free.append((cur, wu1)) }
                for c in cuts { add(c.2, rect(c.0, c.1, sv0, sv1, ax)) }
                let maxLen: Float = commercial ? Swift.max(7, 2.6 * step) : Swift.max(4.2, 1.7 * step)
                func split(_ a: Float, _ b: Float) {
                    if b - a <= maxLen { add(commercial ? .shop : .room, rect(a, b, sv0, sv1, ax)); return }
                    let target = a + (b - a) * rng.float(0.38...0.62)
                    let grid = stride(from: wu0, through: wu1 + 1e-3, by: step).map { $0 }.filter { $0 > a + 2.2 && $0 < b - 2.2 }
                    let at = grid.min { abs($0 - target) < abs($1 - target) } ?? ((target * 10).rounded() / 10)
                    split(a, at); split(at, b)
                }
                for (a, b) in free { split(a, b) }
            }
        }
        return out
    }

    /// Plans for every floor with interior walls and doors (exterior walls are added by the generator).
    public func plans() -> [FloorPlan] {
        let lv = spec.levels
        let stair = stairCore()
        return (0..<spec.floors).map { f in
            var p = FloorPlan(floor: f, level: lv[f], height: spec.floorHeight(f) - 0.25, rooms: rooms(floor: f))
            if let st = p.rooms.first(where: { $0.kind == .stair }) {
                p.stair = stair.map { s in var c = s; c.rect = st.rect; return c } ?? StairCore(rect: st.rect, alongX: st.rect.size.x >= st.rect.size.y)
            }
            return p
        }
    }
}
