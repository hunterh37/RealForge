import RealCore

public extension MaterialLibrary {
    /// Brick and block bonds.
    static let masonry: [MaterialSpec] = [
        MaterialSpec(key: "brick.red", program: .brick).with {
            $0.colorA = linear(0x8A3E2A); $0.colorB = linear(0x6A2E22); $0.colorC = linear(0xA59E92); $0.tileSize = 0.6; $0.normalStrength = 4
        },
        // realityhd:material.masonry
    ]
}
