import RealCore

public extension MaterialLibrary {
    /// Two-layer terrain for scenes: a base ground with a second ground painted in through `Surface.splat`.
    static let groundBlend: [MaterialSpec] = [
        // Farmyard: meadow soil, worn to bare dirt where the splat weight is 1.
        ground.first { $0.key == "ground.meadow" }!.with {
            $0.key = "ground.yard"; $0.splat = "ground.dirt"; $0.splatSoftness = 0.25; $0.splatHeight = 1.5
        },
        // Building site: bare dirt, crushed-gravel pad where the splat weight is 1.
        ground.first { $0.key == "ground.dirt" }!.with {
            $0.key = "ground.site"; $0.splat = "ground.gravel"; $0.splatSoftness = 0.2; $0.splatHeight = 1.8
        },
    ]
}
