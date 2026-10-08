import simd
import RealCore

/// GPU texture program ids (match `evaluate()` in the Metal source).
public enum TextureProgram: Int32, Sendable, CaseIterable {
    case barkOak = 0, barkBirch, barkPine, leafBroad, leafNeedle, grassBlades, rockGranite, forestFloor
    case woodPlank, paintedMetal, rustMetal, concrete, asphalt, plastic, brick
    case grassBlade, grassCard, flowers, fernFrond, leafLitter, moss, fungus, plantStem
    case barkSmooth, barkAspen, barkDead, leafPalmate, leafLanceolate
    case plywood, galvanized, straw, paintedWood, jute
    case gravel, sand, mud, snow, cobblestone, dirtPath
    case barkScotsPine, leafPine, leafFir, leafCypress, barkPalm, leafPalm, cactusRibs, leafAgave
    case strataRock, rockSlate, rockRiver
    case fabricWeave, woodEndGrain, charcoal
    case water
    case leather, brushedMetal, polishedMetal, ceramicGlaze, caneWeave
    case carpetTile, carpetPile, acousticTile, paintedWall, woodVeneer, screenUI, pageEdge
    case marble, terrazzo, pavers, sansevieria, laminate, chairMesh, pottingSoil
    case turf, infieldClay, chainLink
    case sheetVinyl, nonwoven, wallTile, vitalsUI, medLabel
    case boneCortical, cartilageHyaline, muscleFiber, tendonFiber, vesselWall, nerveFascicle
    case pegboard
    case tapeRule
    case pantryFill
    case subwayTile, plankFloor, gasFlame, quartzSlab
    case fruitSkin, papery, rootSkin, radialFlesh, poultryFlesh, foodSmooth, foodCrumb
    case butcherBlock, seasonedIron, heatTint, bakedPatina
    case paverHerringbone, barkMulch
    case foodTissue
}

/// A fully specified PBR material: which texture program, its colors/knobs, and how RealityKit should
/// render it. Colors are linear RGB.
public struct MaterialSpec: Sendable, Hashable {
    public enum Mode: Sendable, Hashable {
        case opaque, cutout, emissive
        /// Alpha-blended: `opacity` at normal incidence, rising to 1 at grazing angles (Fresnel) on the
        /// ShaderGraph path. Glass and water.
        case transparent
    }

    public var key: MaterialKey
    public var program: TextureProgram?
    public var colorA: V4 = V4(0.5, 0.5, 0.5, 1)
    public var colorB: V4 = V4(0.3, 0.3, 0.3, 1)
    public var colorC: V4 = V4(0.2, 0.2, 0.2, 0)
    public var knobs: V4 = .zero
    public var seed: UInt32 = 1
    /// Meters covered by one texture repeat (UVs from RealCore are in meters). 0 = UVs are atlas space.
    public var tileSize: Float = 1
    /// Resolution class. Actual pixels = resolution * RealQuality.textureScale (clamped 128...4096).
    public var resolution: Int = 1024
    public var normalStrength: Float = 2
    public var mode: Mode = .opaque
    public var twoSided = false
    public var hasMetallicMap = false
    public var hasAOMap = true
    /// Untextured fallbacks / scalar overrides.
    public var baseColor: V3 = V3(0.5, 0.5, 0.5)
    public var roughness: Float = 0.8
    public var metallic: Float = 0
    public var emissive: V3 = .zero
    public var emissiveIntensity: Float = 0
    public var clearcoat: Float = 0
    public var specular: Float = 0.5
    public var opacity: Float = 1
    /// Vertex wind amplitude in meters at weight 1 (0 = static, PhysicallyBasedMaterial path).
    public var wind: Float = 0
    /// Back-lit transmission strength for leaves (ShaderGraph path).
    public var translucency: Float = 0
    /// Large-surface anti-tiling (ShaderGraph path): ground, asphalt, big rock faces.
    public var antiTile = false
    /// Object-space triplanar color/roughness/AO (ShaderGraph path).
    public var triplanar = false
    /// World-up layer (moss/snow/dust): linear color, amount 0...1, and threshold on normal.y.
    public var topColor: V4 = linear(0x2F4A16)
    public var topAmount: Float = 0
    public var topLow: Float = 0.55
    /// Second layer blended in by the mesh's per-vertex `Surface.splat` weights (ShaderGraph path;
    /// the PhysicallyBasedMaterial fallback shows the base layer only). Its own spec supplies textures
    /// and tile size: path wear, mud or moss over a ground material.
    public var splat: MaterialKey? = nil
    /// Width of the splat transition in weight units (0.05 crisp, 0.4 soft).
    public var splatSoftness: Float = 0.2
    /// Water (ShaderGraph, transparent mode): scroll speed of the two normal-map layers in tiles per
    /// second. 0 = still surface.
    public var flow: Float = 0
    /// How much the layers' texture brightness pushes the boundary (stones poke through mud).
    public var splatHeight: Float = 1.5
    /// Cooked look of this material (food). The cook shader blends base -> `cooked` by the
    /// `Doneness` parameter, then layers Maillard browning and char by `BrownTop`/`BrownBottom`
    /// (RealKit `RealCookMaterial`). nil = not cookable.
    public var cooked: MaterialKey? = nil

    public init(key: MaterialKey, program: TextureProgram?) { self.key = key; self.program = program }

    public func with(_ edit: (inout MaterialSpec) -> Void) -> MaterialSpec { var c = self; edit(&c); return c }
}

/// sRGB hex -> linear color.
public func linear(_ hex: UInt32, _ a: Float = 1) -> V4 {
    func ch(_ v: UInt32) -> Float { let c = Float(v) / 255; return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    return V4(ch((hex >> 16) & 0xFF), ch((hex >> 8) & 0xFF), ch(hex & 0xFF), a)
}

/// Built-in material library. Keys may carry a hex color suffix: "metal.painted:2E5E3A".
/// Specs live in `Library/<Family>.swift`; add a family array to `all` when creating a new file.
public enum MaterialLibrary {
    /// Every built-in spec, in catalog order. Keys are unique (tested).
    public static let all: [MaterialSpec] = bark + foliage + stone + wood + metal + mineral + plastic + masonry + emissive + plants + industrial + ground + conifer + rock + fabric + woodExtra + water + groundBlend + groundBlends + wild + craft + office + sports + sportsGear + medical + medicalSurgical + medicalDiagnostic + medicalBedside + medicalPatient + medicalTheatre + medicalClinic + medicalHospitalStructures + medicalHospitalLobby + anatomy + woodshop + pantry + kitchen + cookware + food + landscaping + recipeFood + city

    public static let keys: [MaterialKey] = all.map { $0.key }

    static let byKey: [String: MaterialSpec] = Dictionary(all.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })

    public static func spec(for key: MaterialKey) -> MaterialSpec {
        let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
        let base = parts[0]
        let tint: V4? = parts.count > 1 ? UInt32(parts[1], radix: 16).map { linear($0) } : nil
        var s = builtIn(base) ?? MaterialSpec(key: base, program: nil)
        s.key = key
        if let tint {
            s.colorA = tint
            s.baseColor = V3(tint.x, tint.y, tint.z)
            s.seed = s.seed &+ UInt32(truncatingIfNeeded: tint.x.bitPattern &+ tint.y.bitPattern)
        }
        return s
    }

    static func builtIn(_ k: String) -> MaterialSpec? { byKey[k] }
}
