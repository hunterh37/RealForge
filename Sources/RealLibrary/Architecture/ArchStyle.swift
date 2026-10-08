import Foundation

/// A facade style as data: palette, material per slot, trim vocabulary and opening proportions.
/// Presets cover eight American and European street styles; apps author more as JSON.
public struct ArchStyle: Codable, Hashable, Sendable {
    public enum Surround: String, Codable, Sendable { case none, lintel, lintelKeystone, architrave, pediment, hood }
    public enum DoorSurround: String, Codable, Sendable { case none, architrave, pilasters, portico }
    public enum Corner: String, Codable, Sendable { case none, quoins, pilaster }
    public enum Cornice: String, Codable, Sendable { case classical, bracketed, deco, slab, simple }
    /// Repeated blocks under the cornice.
    public enum CorniceBlocks: String, Codable, Sendable { case none, dentils, modillions, brackets }

    public var id: String
    public var name: String
    /// Named colors (hex RRGGBB) the materials below were tinted from; UI swatches read it.
    public var palette: [String: String]
    public var materials: [MaterialSlot: MaterialKey]
    public var roof: RoofType
    public var groundWindow: WindowType
    public var typicalWindow: WindowType
    /// Window width as a fraction of the bay, height as a fraction of the floor-to-floor height.
    public var windowWidthRatio: Float
    public var windowHeightRatio: Float
    /// Glazing bars per sash (columns x rows), 0 for plain glass.
    public var muntins: SIMD2<Int32> = .zero
    /// Projection of surrounds, quoins and belt courses from the wall face (m).
    public var trimDepth: Float
    public var surround: Surround
    public var doorSurround: DoorSurround
    public var corner: Corner
    public var cornice: Cornice
    public var corniceBlocks: CorniceBlocks
    /// Cornice height (projection is about equal, per classical practice).
    public var corniceHeight: Float
    /// Belt course above these floor indices (string course at the slab line).
    public var beltFloors: [Int]
    /// Balcony floors (continuous rail, Haussmann 2nd and 5th).
    public var balconyFloors: [Int] = []
    /// Height of the water table / base course (m).
    public var baseHeight: Float
    public var groundRaise: Float
    public var doubleDoor: Bool
    /// Glass transom above the exterior door.
    public var transom: Bool
    /// Glazing ratio target band (facade area fraction), from the research defaults.
    public var glazingTarget: ClosedRange<Float>

    public func material(_ slot: MaterialSlot) -> MaterialKey {
        if let m = materials[slot] { return m }
        switch slot {
        case .groundFloor: return material(.wall)
        case .baseCourse, .corner, .cornice: return material(.trim)
        case .floor: return "floor.oak-plank"
        case .corridorFloor: return "stone.terrazzo"
        case .interiorWall: return "paint.wall:EEEAE0"
        case .ceiling: return "paint.wall:F4F2EC"
        case .stair: return "concrete.smooth"
        case .slab: return "concrete.smooth"
        case .glass: return "glass.pane"
        case .door: return "wood.painted-shaker:2A2622"
        case .windowFrame: return "paint.wall:F2EEE6"
        case .roof: return "rock.slate"
        case .trim: return "rock.limestone"
        case .wall: return "brick.red"
        }
    }

    public static let georgian = ArchStyle(
        id: "georgian", name: "Georgian",
        palette: ["brick": "9B4A36", "trim": "F2EEE4", "door": "1E2A24"],
        materials: [.wall: "brick.red:9B4A36", .trim: "rock.limestone:E6E0D2", .windowFrame: "paint.wall:F4F1EA",
                    .door: "wood.painted-shaker:1E2A24", .roof: "rock.slate"],
        roof: .hip, groundWindow: .doubleHung, typicalWindow: .doubleHung,
        windowWidthRatio: 0.36, windowHeightRatio: 0.52, muntins: SIMD2(3, 2), trimDepth: 0.06,
        surround: .lintelKeystone, doorSurround: .pilasters, corner: .quoins, cornice: .classical, corniceBlocks: .modillions,
        corniceHeight: 0.6, beltFloors: [0], baseHeight: 0.6, groundRaise: 0.45, doubleDoor: false, transom: true,
        glazingTarget: 0.18...0.28)

    public static let federal = ArchStyle(
        id: "federal", name: "Federal",
        palette: ["brick": "A2553D", "trim": "F5F2EA", "door": "2B3A55"],
        materials: [.wall: "brick.red:A85A40", .trim: "paint.wall:F3EFE6", .baseCourse: "rock.granite-bare", .windowFrame: "paint.wall:F6F3EC",
                    .door: "wood.painted-shaker:2B3A55", .roof: "rock.slate"],
        roof: .gable, groundWindow: .doubleHung, typicalWindow: .doubleHung,
        windowWidthRatio: 0.34, windowHeightRatio: 0.5, muntins: SIMD2(3, 2), trimDepth: 0.04,
        surround: .lintel, doorSurround: .architrave, corner: .none, cornice: .simple, corniceBlocks: .dentils,
        corniceHeight: 0.45, beltFloors: [], baseHeight: 0.5, groundRaise: 0.6, doubleDoor: false, transom: true,
        glazingTarget: 0.16...0.26)

    public static let italianate = ArchStyle(
        id: "italianate", name: "Victorian Italianate",
        palette: ["stucco": "D8C7A3", "trim": "EFE6D2", "door": "4A2E1E"],
        materials: [.wall: "paint.wall:D3BE96", .trim: "paint.wall:EDE3CC", .cornice: "paint.wall:E8DDC4", .baseCourse: "rock.sandstone",
                    .windowFrame: "paint.wall:EFE8D8", .door: "wood.walnut", .roof: "metal.galvanized-aged"],
        roof: .flat, groundWindow: .doubleHung, typicalWindow: .doubleHung,
        windowWidthRatio: 0.32, windowHeightRatio: 0.6, trimDepth: 0.08,
        surround: .hood, doorSurround: .architrave, corner: .quoins, cornice: .bracketed, corniceBlocks: .brackets,
        corniceHeight: 0.8, beltFloors: [0], baseHeight: 0.5, groundRaise: 0.6, doubleDoor: true, transom: true,
        glazingTarget: 0.2...0.3)

    public static let beauxArts = ArchStyle(
        id: "beaux-arts", name: "Beaux-Arts",
        palette: ["stone": "DCD3C0", "base": "B8B2A6", "door": "2E2A26"],
        materials: [.wall: "rock.limestone:DED6C4", .groundFloor: "stone.cast-grey:C9C2B4", .trim: "rock.limestone:E9E3D6",
                    .baseCourse: "rock.granite-bare", .windowFrame: "metal.painted:3A3631", .door: "metal.painted:2E2A26", .roof: "metal.copper-patina"],
        roof: .flat, groundWindow: .casement, typicalWindow: .casement,
        windowWidthRatio: 0.4, windowHeightRatio: 0.56, muntins: SIMD2(1, 3), trimDepth: 0.1,
        surround: .pediment, doorSurround: .portico, corner: .pilaster, cornice: .classical, corniceBlocks: .modillions,
        corniceHeight: 1.0, beltFloors: [0, 1], baseHeight: 0.7, groundRaise: 0.45, doubleDoor: true, transom: true,
        glazingTarget: 0.22...0.32)

    public static let artDeco = ArchStyle(
        id: "art-deco", name: "Art Deco",
        palette: ["stone": "D2C9B4", "spandrel": "4B5348", "frame": "222222"],
        materials: [.wall: "stone.cast-grey:D6CCB6", .groundFloor: "stone.marble-dark", .trim: "stone.cast-grey:E4DCC8",
                    .baseCourse: "stone.marble-dark", .windowFrame: "metal.anodized-black", .door: "metal.brass-aged", .roof: "concrete.smooth"],
        roof: .flat, groundWindow: .storefront, typicalWindow: .casement,
        windowWidthRatio: 0.5, windowHeightRatio: 0.55, muntins: SIMD2(1, 3), trimDepth: 0.12,
        surround: .none, doorSurround: .architrave, corner: .pilaster, cornice: .deco, corniceBlocks: .none,
        corniceHeight: 1.2, beltFloors: [0], baseHeight: 0.9, groundRaise: 0.15, doubleDoor: true, transom: true,
        glazingTarget: 0.3...0.45)

    public static let haussmann = ArchStyle(
        id: "haussmann", name: "Haussmann Parisian",
        palette: ["stone": "E2D6BC", "zinc": "7E8287", "iron": "1C1C1E"],
        materials: [.wall: "rock.limestone:E3D8C0", .groundFloor: "stone.wall-block:D9CDB2", .trim: "rock.limestone:EDE5D3",
                    .windowFrame: "paint.wall:F2EFEA", .door: "wood.painted-shaker:23302A", .roof: "metal.galvanized-aged"],
        roof: .mansard, groundWindow: .storefront, typicalWindow: .casement,
        windowWidthRatio: 0.44, windowHeightRatio: 0.62, muntins: SIMD2(1, 3), trimDepth: 0.07,
        surround: .architrave, doorSurround: .architrave, corner: .none, cornice: .classical, corniceBlocks: .modillions,
        corniceHeight: 0.7, beltFloors: [0, 1], balconyFloors: [2], baseHeight: 0.4, groundRaise: 0.15, doubleDoor: true, transom: true,
        glazingTarget: 0.25...0.38)

    public static let brownstone = ArchStyle(
        id: "brownstone", name: "Brooklyn brownstone",
        palette: ["stone": "6E4B3A", "cornice": "3B2E28", "door": "5A3A22"],
        materials: [.wall: "rock.sandstone:7A5040", .trim: "rock.sandstone:8A5E4A", .cornice: "metal.painted:3B2E28",
                    .baseCourse: "rock.sandstone:5E4032", .windowFrame: "paint.wall:EDE7DC", .door: "wood.walnut", .roof: "concrete.smooth"],
        roof: .flat, groundWindow: .doubleHung, typicalWindow: .doubleHung,
        windowWidthRatio: 0.36, windowHeightRatio: 0.56, trimDepth: 0.08,
        surround: .hood, doorSurround: .pilasters, corner: .none, cornice: .bracketed, corniceBlocks: .brackets,
        corniceHeight: 0.75, beltFloors: [], baseHeight: 0.4, groundRaise: 1.26, doubleDoor: true, transom: true,
        glazingTarget: 0.18...0.28)

    public static let modernist = ArchStyle(
        id: "modernist", name: "Modernist",
        palette: ["concrete": "D8D8D4", "frame": "1A1A1A", "glass": "5C6B70"],
        materials: [.wall: "concrete.smooth:D9D9D5", .groundFloor: "concrete.smooth:C8C8C4", .trim: "concrete.smooth:E2E2DE",
                    .baseCourse: "concrete.smooth:BDBDB8", .windowFrame: "metal.anodized-black", .glass: "glass.curtain",
                    .door: "metal.anodized-black", .roof: "concrete.smooth", .floor: "concrete.smooth:B8B6B0"],
        roof: .flat, groundWindow: .storefront, typicalWindow: .curtain,
        windowWidthRatio: 0.9, windowHeightRatio: 0.74, trimDepth: 0.03,
        surround: .none, doorSurround: .none, corner: .none, cornice: .slab, corniceBlocks: .none,
        corniceHeight: 0.35, beltFloors: [], baseHeight: 0.3, groundRaise: 0.15, doubleDoor: true, transom: false,
        glazingTarget: 0.6...0.9)

    public static let presets: [ArchStyle] = [.georgian, .federal, .italianate, .beauxArts, .artDeco, .haussmann, .brownstone, .modernist]
    public static var ids: [String] { presets.map(\.id) }
    public static func named(_ id: String) -> ArchStyle? { presets.first { $0.id == id } }
}
