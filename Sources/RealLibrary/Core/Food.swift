import simd

/// How a food behaves on heat. Picks the thermal and browning model in `RealCook` (RealKit).
public enum FoodKind: String, Sendable, CaseIterable {
    /// Lean muscle: chicken, pork, fish. Protein sets at 60-74 C core, browns above 140 C surface.
    case protein
    /// Watery vegetables: onion, pepper, tomato, mushroom. Soften, then caramelize.
    case vegetable
    /// Dense roots and tubers: carrot, potato. Slow to soften.
    case root
    /// Shell egg or beaten egg: sets at 63-80 C.
    case egg
    /// Butter, cheese: melts, then browns and burns fast.
    case dairy
    /// Batter and dough: sets, rises, crusts.
    case batter
    /// Leaves and herbs: wilt fast, crisp and burn fast.
    case leaf
}

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
