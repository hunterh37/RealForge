import Foundation
import RealKit
import RealMaterials
import AnimalCore

/// Registers animal material specs with RealityHD's material cache.
@MainActor
public enum AnimalMaterials {
    private static var registered: Set<String> = []

    /// Idempotent per species; call before building the species' entity.
    public static func register(_ p: BirdProfile) {
        guard registered.insert(p.species.rawValue).inserted else { return }
        for s in FaunaMaterials.specs(for: p) { RealMaterialCache.shared.overrides[s.key] = s }
    }

    public static func register(_ p: GroundProfile) {
        guard registered.insert(p.species.rawValue).inserted else { return }
        for s in FaunaMaterials.specs(for: p) { RealMaterialCache.shared.overrides[s.key] = s }
    }

    public static func registerAll() {
        for s in BirdSpecies.allCases { register(s.profile) }
        for s in GroundSpecies.allCases { register(s.profile) }
    }

    /// Drops the registration so edited specs are picked up (previews).
    public static func reset() { registered.removeAll() }
}
