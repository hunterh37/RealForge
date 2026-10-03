import Foundation

/// A composed scene generator. Rules (enforced by tests): unique kebab-case `id`, deterministic,
/// only catalog assets or `MaterialLibrary` keys, a camera hint, a thumbnail at `docs/scenes/<id>.png`.
public protocol RealSceneBuilder: Sendable {
    static var id: String { get }
    static var summary: String { get }
    static var tags: [String] { get }
    static var author: String { get }
    init()
    func build(seed: UInt64) -> RealScene
}

public extension RealSceneBuilder {
    static var author: String { "realforge" }
    func with(_ edit: (inout Self) -> Void) -> Self { var c = self; edit(&c); return c }
}

public enum SceneCatalog {
    public static let all: [any RealSceneBuilder.Type] = [
        ForestGlade.self, ParkPath.self, PropYard.self,
        ConstructionLot.self,
        Farmyard.self,
        LakesideCamp.self,
        AutumnWoods.self,
        // realforge:scene
    ]

    public static var ids: [String] { all.map { $0.id } }

    public static func type(_ id: String) -> (any RealSceneBuilder.Type)? { all.first { $0.id == id } }

    public static func build(_ id: String, seed: UInt64 = 1) -> RealScene? { type(id).map { $0.init().build(seed: seed) } }
}
