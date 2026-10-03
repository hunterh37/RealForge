import RealCore

public extension MaterialLibrary {
    /// Untextured emissive materials (lamps, glowing glass).
    static let emissive: [MaterialSpec] = [
        MaterialSpec(key: "glass.lamp", program: nil).with {
            $0.baseColor = V3(1, 0.85, 0.6); $0.roughness = 0.25; $0.mode = .emissive
            $0.emissive = V3(1, 0.78, 0.5); $0.emissiveIntensity = 2.5
        },
        MaterialSpec(key: "emissive.warm", program: nil).with {
            $0.baseColor = V3(1, 0.7, 0.4); $0.mode = .emissive; $0.emissive = V3(1, 0.62, 0.32); $0.emissiveIntensity = 4
        },
        // realforge:material.emissive
    ]
}
