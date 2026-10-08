import simd
import Foundation

/// Building outline on the ground plane (meters, X right, Z toward the street/front). Footprints are
/// centered on the origin; the front facade (facade 0) is the +Z edge for the named shapes.
public enum Footprint: Codable, Hashable, Sendable {
    case rect(width: Float, depth: Float)
    /// Front bar `barDepth` deep across the full width, plus a leg `legWidth` wide down the -X side.
    case l(width: Float, depth: Float, legWidth: Float, barDepth: Float)
    /// Front bar `barDepth` deep, two legs `legWidth` wide running back; the court opens to -Z.
    case u(width: Float, depth: Float, legWidth: Float, barDepth: Float)
    /// Closed ring of wings `ring` deep around a central courtyard.
    case courtyard(width: Float, depth: Float, ring: Float)
    /// Custom outline (x, z). Orientation is normalized; facade i is edge i -> i+1. Floor plans subdivide
    /// the rectilinear cells of the outline (vertex-coordinate grid).
    case polygon([V2])
}

public enum RoofType: String, Codable, CaseIterable, Sendable {
    case flat, gable, hip, mansard, gambrel
}

public enum WindowType: String, Codable, CaseIterable, Sendable, Comparable {
    /// Two sashes with a meeting rail (residential 0.9 x 1.5 m).
    case doubleHung
    /// Side-hung pair with a center mullion (French window when tall).
    case casement
    /// Single fixed light.
    case fixed
    /// Shop glazing on a 0.45 m bulkhead with a transom bar.
    case storefront
    /// Curtain-wall unit: thin black frame, glass near the outer face.
    case curtain
    public static func < (a: WindowType, b: WindowType) -> Bool { a.rawValue < b.rawValue }
}

/// Material slots a style fills and a spec can override.
public enum MaterialSlot: String, Codable, CaseIterable, Sendable {
    case wall, groundFloor, baseCourse, trim, cornice, corner, windowFrame, glass, door, roof
    case floor, corridorFloor, interiorWall, ceiling, stair, slab
}

/// Facade slots a `FacadePieceProvider` fills. Opening slots (window, door and their surrounds) are
/// placed per opening; run slots (base course, belt, cornice, attic) follow the facade edges; the floor
/// slots are hooks placed once per facade per floor band.
public enum FacadeSlot: String, Codable, CaseIterable, Sendable {
    case baseCourse, groundFloor, typicalFloor, attic, cornice, corner, windowSurround, doorSurround
    case window, door, beltCourse
}

/// Per-facade overrides. `facade` indexes the footprint edges (outer ring first, then courtyard rings).
public struct FacadeOverride: Codable, Hashable, Sendable {
    public var facade: Int
    /// Bay count along the facade (nil: length / bay width, rounded to an odd count).
    public var bays: Int?
    /// Ground-floor bays that hold an exterior door (nil: the center bay of facade 0, none elsewhere).
    public var doorBays: [Int]?
    /// Window type per floor index; missing floors use the style.
    public var windowTypes: [Int: WindowType] = [:]
    /// Bays left blank (no window) on every floor.
    public var blankBays: [Int] = []
    public init(facade: Int, bays: Int? = nil, doorBays: [Int]? = nil, windowTypes: [Int: WindowType] = [:], blankBays: [Int] = []) {
        self.facade = facade; self.bays = bays; self.doorBays = doorBays; self.windowTypes = windowTypes; self.blankBays = blankBays
    }
}

/// Everything the generator needs. Same spec (seed included) builds identical geometry.
public struct BuildingSpec: Codable, Hashable, Sendable {
    public var name: String = "building"
    public var footprint: Footprint = .rect(width: 14, depth: 10)
    public var floors: Int = 3
    /// Floor-to-floor heights (m). Commercial ground floors run 4.0 to 4.5 m, residential 3.0 m.
    public var groundFloorHeight: Float = 3.6
    public var typicalFloorHeight: Float = 3.1
    /// Target bay width (m); each facade rounds it to fit.
    public var bayWidth: Float = 3.0
    /// Roof form (nil: the style default).
    public var roof: RoofType?
    /// Roof pitch in degrees for gable, hip and gambrel (lower slope); mansard uses its own 72 degrees.
    public var roofPitch: Float = 32
    /// `ArchStyle.id` of a preset, or the id of `customStyle`.
    public var style: String = "georgian"
    /// Inline style (wins over the preset lookup when its id matches `style`).
    public var customStyle: ArchStyle?
    public var facades: [FacadeOverride] = []
    public var materials: [MaterialSlot: MaterialKey] = [:]
    /// Asset or registered piece ids per facade slot (e.g. `.window: "double-hung-window"`). Unknown ids
    /// fall back to the procedural pieces.
    public var pieces: [FacadeSlot: String] = [:]
    /// Hand-edited room lists per floor index; the generator derives walls and doors from them.
    public var roomOverrides: [Int: [PlanRoom]] = [:]
    /// Ground-floor level above grade (nil: the style default). Exterior doors get steps up to it.
    public var groundRaise: Float?
    /// Generate floor plans and interior geometry.
    public var interiors = true
    /// Exterior door leaves swung open 80 degrees (walk mode).
    public var openDoors = false
    public var seed: UInt64 = 1

    public init() {}
    public init(footprint: Footprint, floors: Int, style: String, seed: UInt64 = 1) {
        self.footprint = footprint; self.floors = floors; self.style = style; self.seed = seed
    }
    public func with(_ edit: (inout BuildingSpec) -> Void) -> BuildingSpec { var c = self; edit(&c); return c }

    public var resolvedStyle: ArchStyle {
        if let s = customStyle, s.id == style { return s }
        return ArchStyle.named(style) ?? .georgian
    }
    public var resolvedRoof: RoofType { roof ?? resolvedStyle.roof }
    public func material(_ slot: MaterialSlot) -> MaterialKey { materials[slot] ?? resolvedStyle.material(slot) }
    public func override(_ facade: Int) -> FacadeOverride? { facades.first { $0.facade == facade } }

    /// Floor level (top of slab) of each floor plus the roof level at index `floors`.
    public var levels: [Float] {
        let r = groundRaise ?? resolvedStyle.groundRaise
        var out: [Float] = [r]
        for i in 0..<max(1, floors) { out.append(out[i] + floorHeight(i)) }
        return out
    }
    public func floorHeight(_ i: Int) -> Float { i == 0 ? groundFloorHeight : typicalFloorHeight }

    /// JSON blueprint.
    public func json() throws -> Data {
        let e = JSONEncoder(); e.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try e.encode(self)
    }
    public static func from(json: Data) throws -> BuildingSpec { try JSONDecoder().decode(BuildingSpec.self, from: json) }
}
