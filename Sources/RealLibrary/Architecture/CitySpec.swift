import simd
import Foundation

public enum CityCell: String, Codable, Sendable { case empty, road, sidewalk, lot, park, plaza }
public enum CityFacing: String, Codable, Sendable {
    /// Direction the lot's front facade faces (+Z is south).
    case south, north, east, west
    var yaw: Float { switch self { case .south: 0; case .north: 180; case .east: 90; case .west: -90 } }
}

/// A lot on the grid; `building` indexes `CitySpec.buildings`.
public struct CityLot: Codable, Hashable, Sendable {
    public var column: Int
    public var row: Int
    public var width: Int
    public var depth: Int
    public var building: Int?
    public var facing: CityFacing
    /// Front setback (m) from the lot edge to the facade line.
    public var setback: Float
    public init(column: Int, row: Int, width: Int, depth: Int, building: Int?, facing: CityFacing = .south, setback: Float = 0) {
        self.column = column; self.row = row; self.width = width; self.depth = depth; self.building = building; self.facing = facing; self.setback = setback
    }
}

/// District blueprint: a grid of road, sidewalk, lot and park cells plus building specs on lots.
/// Codable, so apps save and load districts as JSON.
public struct CitySpec: Codable, Hashable, Sendable {
    public var cellSize: Float = 3
    public var columns: Int
    public var rows: Int
    /// Row-major cells (row * columns + column); row 0 is the -Z edge.
    public var cells: [CityCell]
    public var lots: [CityLot] = []
    public var buildings: [BuildingSpec] = []
    /// Street trees on sidewalk cells every `treeSpacing` cells (0: none).
    public var treeSpacing: Int = 3
    public var seed: UInt64 = 1

    public init(columns: Int, rows: Int, cellSize: Float = 3, fill: CityCell = .empty) {
        self.columns = columns; self.rows = rows; self.cellSize = cellSize
        cells = Array(repeating: fill, count: columns * rows)
    }
    public subscript(c: Int, r: Int) -> CityCell {
        get { c >= 0 && r >= 0 && c < columns && r < rows ? cells[r * columns + c] : .empty }
        set { if c >= 0 && r >= 0 && c < columns && r < rows { cells[r * columns + c] = newValue } }
    }
    public mutating func fill(rows rs: ClosedRange<Int>, columns cs: ClosedRange<Int>? = nil, _ v: CityCell) {
        for r in rs { for c in (cs ?? 0...(columns - 1)) { self[c, r] = v } }
    }
    /// Places a building on a lot, marks its cells and returns the lot index.
    @discardableResult
    public mutating func addLot(_ lot: CityLot, spec: BuildingSpec?) -> Int {
        var l = lot
        if let spec { buildings.append(spec); l.building = buildings.count - 1 }
        for r in l.row..<(l.row + l.depth) { for c in l.column..<(l.column + l.width) { self[c, r] = .lot } }
        lots.append(l)
        return lots.count - 1
    }

    /// One straight street: lots `lotDepth` cells deep on the north side facing a road `roadCells`
    /// wide with sidewalks, and a sidewalk strip on the far side.
    public static func street(columns: Int, lotDepth: Int = 5, roadCells: Int = 3, cellSize: Float = 3) -> CitySpec {
        var s = CitySpec(columns: columns, rows: lotDepth + roadCells + 3, cellSize: cellSize)
        s.fill(rows: 0...(lotDepth - 1), .lot)
        s.fill(rows: lotDepth...lotDepth, .sidewalk)
        s.fill(rows: (lotDepth + 1)...(lotDepth + roadCells), .road)
        s.fill(rows: (lotDepth + roadCells + 1)...(lotDepth + roadCells + 1), .sidewalk)
        s.fill(rows: (lotDepth + roadCells + 2)...(lotDepth + roadCells + 2), .park)
        return s
    }

    public func json() throws -> Data { let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; return try e.encode(self) }
    public static func from(json: Data) throws -> CitySpec { try JSONDecoder().decode(CitySpec.self, from: json) }
}

/// Resolved layout in meters (grid centered on the origin) and scene composition.
public struct CityLayout: Sendable {
    public var spec: CitySpec
    public init(_ spec: CitySpec) { self.spec = spec }

    public var size: V2 { V2(Float(spec.columns), Float(spec.rows)) * spec.cellSize }
    public func cellRect(_ c: Int, _ r: Int) -> PlanRect {
        let o = -size / 2, s = spec.cellSize
        return PlanRect(o.x + Float(c) * s, o.y + Float(r) * s, o.x + Float(c + 1) * s, o.y + Float(r + 1) * s)
    }
    public func lotRect(_ l: CityLot) -> PlanRect {
        let a = cellRect(l.column, l.row), b = cellRect(l.column + l.width - 1, l.row + l.depth - 1)
        return PlanRect(min: a.min, max: b.max)
    }

    /// Placement of a lot's building: centered across the frontage, facade on the front setback line.
    public func placement(_ l: CityLot, building: BuildingSpec) -> Xform {
        let r = lotRect(l), b = FootprintShape(building.footprint).bounds
        let depth = b.size.y
        let c: V2
        switch l.facing {
        case .south: c = V2(r.center.x, r.max.y - l.setback - depth / 2)
        case .north: c = V2(r.center.x, r.min.y + l.setback + depth / 2)
        case .east: c = V2(r.max.x - l.setback - depth / 2, r.center.y)
        case .west: c = V2(r.min.x + l.setback + depth / 2, r.center.y)
        }
        return place(c.x, c.y, yaw: l.facing.yaw)
    }

    /// Ground model: asphalt roads with dashed center lines, raised sidewalks with curbs, park lawn, lot paving.
    public func groundModel() -> Model {
        var m = MeshBucket()
        let s = spec.cellSize
        for r in 0..<spec.rows { for c in 0..<spec.columns {
            let rc = cellRect(c, r), cell = spec[c, r]
            func top(_ y: Float, _ mat: MaterialKey) {
                m.quad(V3(rc.min.x, y, rc.max.y), V3(rc.max.x, y, rc.max.y), V3(rc.max.x, y, rc.min.y), V3(rc.min.x, y, rc.min.y), mat)
            }
            switch cell {
            case .road:
                top(0, "concrete.rough:3A3A3C")
                let horiz = spec[c, r - 1] == .road && spec[c, r + 1] == .road
                if horiz && (spec[c, r - 2] != .road) == (spec[c, r + 2] != .road) && c % 2 == 0 {
                    m.aabb(center: V3(rc.center.x, 0.004, rc.center.y), size: V3(s * 0.5, 0.008, 0.12), "paint.field-white:E8C547")
                }
            case .sidewalk, .plaza:
                m.box(V3(rc.min.x, 0, rc.min.y), V3(s, 0, 0), V3(0, 0.15, 0), V3(0, 0, s), cell == .plaza ? "paver.herringbone" : "paving.slab")
                // Curb on road edges.
                for (dc, dr) in [(0, -1), (0, 1), (-1, 0), (1, 0)] where spec[c + dc, r + dr] == .road {
                    let w: Float = 0.18
                    let o: V3 = dr != 0 ? V3(rc.min.x, 0, dr < 0 ? rc.min.y : rc.max.y - w) : V3(dc < 0 ? rc.min.x : rc.max.x - w, 0, rc.min.y)
                    m.box(o - V3(0, 0.02, 0), dr != 0 ? V3(s, 0, 0) : V3(w, 0, 0), V3(0, 0.18, 0), dr != 0 ? V3(0, 0, w) : V3(0, 0, s), "stone.cast-grey")
                }
            case .park: m.box(V3(rc.min.x, 0, rc.min.y), V3(s, 0, 0), V3(0, 0.12, 0), V3(0, 0, s), "ground.meadow")
            case .lot: top(0.02, "paving.slab:B9B4AA")
            case .empty: break
            }
        }}
        return m.model("city-ground")
    }

    /// Sidewalk points for street trees and lamps (cell centers along road-facing sidewalks).
    public func streetPoints(every n: Int) -> [V2] {
        guard n > 0 else { return [] }
        var out: [V2] = []
        for r in 0..<spec.rows { for c in 0..<spec.columns where spec[c, r] == .sidewalk && c % n == 1 {
            let rc = cellRect(c, r)
            if spec[c, r + 1] == .road { out.append(V2(rc.center.x, rc.max.y - 0.9)) }
            else if spec[c, r - 1] == .road { out.append(V2(rc.center.x, rc.min.y + 0.9)) }
        }}
        return out
    }

    /// Adds ground, buildings, street trees and lamps to `scene`.
    public func compose(into scene: inout RealScene, generator: BuildingGenerator = BuildingGenerator()) {
        scene.add(groundModel())
        for (i, l) in spec.lots.enumerated() {
            guard let bi = l.building, bi < spec.buildings.count else { continue }
            var b = spec.buildings[bi]
            b.seed = b.seed &+ spec.seed &* 31 &+ UInt64(i)
            scene.singles.append(.init(asset: generator.build(b).combined(), at: placement(l, building: b)))
        }
        var rng = SeededRNG(seed: spec.seed &+ 77)
        let pts = streetPoints(every: spec.treeSpacing)
        for (i, p) in pts.enumerated() {
            if i % 2 == 0 {
                scene.add(MapleTree().with { $0.autumn = 0.15 }, at: place(p.x, p.y, y: 0.1, yaw: rng.float(0...360), scale: 0.6), seed: spec.seed &+ UInt64(100 + i % 3))
            } else {
                scene.add(StreetLamp(), at: place(p.x, p.y, y: 0.15, yaw: 0), seed: spec.seed &+ 7)
            }
        }
    }

    public static func scene(_ spec: CitySpec, name: String) -> RealScene {
        var s = RealScene(name: name)
        CityLayout(spec).compose(into: &s)
        return s
    }
}
