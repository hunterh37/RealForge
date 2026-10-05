import simd
import RealKit
import RealityKit

/// How a food behaves on heat: picks the thermal and browning profile (`Cook.profile`, RealCore).
public typealias FoodKind = Cook.Kind

/// A food asset that can be cut at runtime (`Model.sliced`, RealCore) and cooked (`RealCook`, RealKit).
/// Every surface of LOD 0 is a closed shell so cut faces can be capped.
public protocol RealFood: RealAsset {
    static var kind: FoodKind { get }
    /// Material for the cut face of a surface with material `key`; nil leaves that shell uncapped
    /// (thin skins, peels, stems that sit over flesh).
    func capMaterial(for key: MaterialKey) -> MaterialKey?
    /// Center of concentric structure (onion rings, carrot core, tomato locules) in asset space.
    /// Cut-face UVs are planar meters measured from it, offset by half the cap material's tile so a
    /// radial texture program centered at uv 0.5 lines up.
    var coreCenter: V3 { get }
}

public extension RealFood {
    var coreCenter: V3 { V3(0, 0, 0) }
}

public extension RealFood {
    /// Default density (kg/m^3) by kind, for physics mass.
    static var density: Float {
        switch kind {
        case .protein: return 1060
        case .vegetable: return 960
        case .root: return 1040
        case .egg: return 1030
        case .dairy: return 920
        case .batter: return 1100
        case .leaf: return 600
        }
    }
}

public extension RealityHD {
    /// A food asset (`RealFood`) as a cookable, sliceable, physical entity: cook-shader materials,
    /// convex collision, dynamic body with mass from its volume, and `RealFoodComponent` holding the heat
    /// state. Cut with `entity.realSlice(plane)`; push heat state to the shader with `realApplyCook()`.
    /// Resting position matches `entity(id)` (base at y = 0).
    @MainActor
    static func food(_ id: String, seed: UInt64 = 1, physics: Bool = true) async throws -> ModelEntity {
        guard let t = Catalog.type(id), let food = t.init() as? any RealFood else { throw RealityHDError.unknown(id) }
        let model = await Task.detached(priority: .userInitiated) { food.build(seed: seed).levels[0] }.value
        let caps = RealCook.caps(for: model, coreCenter: food.coreCenter) { food.capMaterial(for: $0) }
        let kind = type(of: food).kind
        let density = type(of: food).density
        let e = try await RealCook.food(model, kind: kind, caps: caps, source: id, density: density, physics: physics)
        return e
    }

    /// Every food asset id.
    static var foodIDs: [String] { Catalog.assets.filter { $0.init() is any RealFood }.map { $0.id } }
}

/// A pan, pot, bowl or sheet that holds food. Asset space: base at y = 0, centered, handle along +X.
public protocol RealVessel: RealAsset {
    /// Height of the inner cooking surface (top of the floor).
    var floorY: Float { get }
    /// Radius of the usable flat floor (half the short side for sheets).
    var innerRadius: Float { get }
    /// Height of the rim.
    var rimY: Float { get }
    /// Radius at the rim (inner).
    var rimRadius: Float { get }
    /// How it conducts heat on a burner.
    var metal: VesselThermal.Metal { get }
}

public extension RealVessel {
    var rimRadius: Float { innerRadius * 1.15 }
    var metal: VesselThermal.Metal { .stainless }
}

/// A cutting tool. Asset space: lying on its side (blade face normal +Y), blade along +X, edge toward -Z.
public protocol RealBlade: RealAsset {
    /// Blade length from heel to tip (m).
    var bladeLength: Float { get }
}
