import RealCore

public extension MaterialLibrary {
    /// RealityHD 5 medical materials added with the Theatre batch.
    static let medicalTheatre: [MaterialSpec] = [
        // Molded red resin of medical waste cans: fine stipple, scuffs and floor dirt low on the body. Tint for color.
        MaterialSpec(key: "plastic.resin-red", program: .plastic).with {
            $0.colorA = linear(0xB01E1A); $0.knobs = V4(0.8, 0.35, 0.5, 0); $0.seed = 901; $0.tileSize = 0.35; $0.resolution = 512; $0.normalStrength = 0.9
        },
        // realityhd:material.medicalTheatre
    ]
}
