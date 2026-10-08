import simd
import Foundation

/// Quantities from a generated building (Revit-style schedule): doors, windows by type, rooms with
/// net areas, gross floor area, facade area and glazing ratio.
public struct BuildingSchedule: Codable, Hashable, Sendable {
    public struct RoomEntry: Codable, Hashable, Sendable {
        public var floor: Int
        public var id: Int
        public var name: String
        public var kind: RoomKind
        /// Net floor area (m2), inside the wall faces.
        public var area: Float
    }
    public var floors: Int
    public var exteriorDoors: Int
    public var interiorDoors: Int
    /// Open passages (lobby and corridor openings without a leaf).
    public var passages: Int
    public var windowsByType: [WindowType: Int]
    public var rooms: [RoomEntry]
    /// Footprint area x floors (m2).
    public var grossFloorArea: Float
    /// Exterior wall area from grade to the eave (m2).
    public var facadeArea: Float
    public var glazingArea: Float

    public var doorCount: Int { exteriorDoors + interiorDoors }
    public var windowCount: Int { windowsByType.values.reduce(0, +) }
    /// Rooms excluding corridors and stairs.
    public var roomCount: Int { rooms.filter { $0.kind != .corridor && $0.kind != .stair }.count }
    public var netFloorArea: Float { rooms.reduce(0) { $0 + $1.area } }
    public var glazingRatio: Float { facadeArea > 0 ? glazingArea / facadeArea : 0 }

    init(spec: BuildingSpec, shape: FootprintShape, plans: [FloorPlan], generator g: BuildingGenerator, roofLevel: Float) {
        floors = plans.count
        var ext = 0, int = 0, pas = 0, glass: Float = 0
        var byType: [WindowType: Int] = [:]
        var rooms: [RoomEntry] = []
        for p in plans {
            for w in p.walls {
                for o in w.openings {
                    switch o.kind {
                    case .window:
                        byType[o.window ?? .fixed, default: 0] += 1
                        glass += o.width * (o.head - o.sill)
                    case .door: if w.exterior { ext += 1 } else { int += 1 }
                    case .passage: pas += 1
                    }
                }
            }
            for r in p.rooms {
                rooms.append(RoomEntry(floor: p.floor, id: r.id, name: r.name, kind: r.kind,
                                       area: p.netArea(r, shape: shape, exterior: g.exteriorWall, interior: g.interiorWall)))
            }
        }
        exteriorDoors = ext; interiorDoors = int; passages = pas; windowsByType = byType; self.rooms = rooms
        grossFloorArea = shape.area * Float(plans.count)
        facadeArea = shape.edges.reduce(0) { $0 + $1.length } * roofLevel
        glazingArea = glass
    }

    /// Plain-text table for logs and the schedule panel.
    public var summary: String {
        var s = "floors \(floors)  rooms \(roomCount)  doors \(doorCount) (ext \(exteriorDoors), int \(interiorDoors))  passages \(passages)\n"
        s += "windows \(windowCount): " + windowsByType.keys.sorted().map { "\($0.rawValue) \(windowsByType[$0]!)" }.joined(separator: ", ") + "\n"
        s += String(format: "GFA %.1f m2  NFA %.1f m2  facade %.1f m2  glazing %.1f m2 (%.0f%%)", grossFloorArea, netFloorArea, facadeArea, glazingArea, glazingRatio * 100)
        return s
    }
}
