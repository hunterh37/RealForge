import RealCore

public extension MaterialLibrary {
    /// Molded plastic and rubber.
    static let plastic: [MaterialSpec] = [
        MaterialSpec(key: "plastic.orange", program: .plastic).with {
            $0.colorA = linear(0xF0581A); $0.knobs = V4(0.6, 0.35, 0.42, 0); $0.tileSize = 0.5; $0.resolution = 512; $0.normalStrength = 1
        },
        MaterialSpec(key: "plastic.white", program: .plastic).with {
            $0.colorA = linear(0xE8E6E0); $0.knobs = V4(0.4, 0.3, 0.35, 0); $0.tileSize = 0.5; $0.resolution = 512; $0.seed = 3
        },
        MaterialSpec(key: "plastic.black", program: .plastic).with {
            $0.colorA = linear(0x161616); $0.knobs = V4(0.3, 0.5, 0.45, 0); $0.tileSize = 0.5; $0.resolution = 512; $0.seed = 8
        },
        MaterialSpec(key: "rubber", program: .plastic).with {
            $0.colorA = linear(0x161616); $0.knobs = V4(0.3, 0.5, 0.85, 0); $0.tileSize = 0.5; $0.resolution = 512; $0.seed = 8
        },
        // realforge:material.plastic
    ]
}
