import RealCore

public extension MaterialLibrary {
    /// Concrete and road surfaces.
    static let mineral: [MaterialSpec] = [
        MaterialSpec(key: "concrete.smooth", program: .concrete).with {
            $0.colorA = linear(0x9A9790); $0.colorB = linear(0x7E7A72); $0.knobs = V4(0.72, 0.4, 0, 0); $0.tileSize = 1.5; $0.normalStrength = 2
        },
        MaterialSpec(key: "concrete.rough", program: .concrete).with {
            $0.colorA = linear(0x8A867E); $0.colorB = linear(0x6E6A62); $0.knobs = V4(0.88, 0.7, 0, 0); $0.seed = 6; $0.tileSize = 1.5; $0.normalStrength = 2
            $0.antiTile = true
        },
        MaterialSpec(key: "asphalt", program: .asphalt).with {
            $0.colorA = linear(0x1E1E1F); $0.colorB = linear(0x5A5853); $0.knobs = V4(0.5, 0, 0, 0); $0.tileSize = 2; $0.normalStrength = 4; $0.resolution = 2048
            $0.antiTile = true
        },
        // realforge:material.mineral
    ]
}
