import RealCore

public extension MaterialLibrary {
    /// Rock (triplanar, moss top layer). Ground materials are in Ground.swift.
    static let stone: [MaterialSpec] = [
        MaterialSpec(key: "rock.granite", program: .rockGranite).with {
            $0.colorA = linear(0x5F5B56); $0.colorB = linear(0x86817A); $0.colorC = linear(0x9A7468)
            $0.knobs = V4(0.6, 0, 0, 0); $0.tileSize = 1.2; $0.normalStrength = 2.2; $0.triplanar = true
            $0.topAmount = 0.85
        },
        MaterialSpec(key: "rock.sandstone", program: .rockGranite).with {
            $0.colorA = linear(0xA98563); $0.colorB = linear(0xC4A27C); $0.colorC = linear(0x8E5A3A)
            $0.knobs = V4(0.2, 0, 0, 0); $0.seed = 9; $0.tileSize = 1.5; $0.normalStrength = 2; $0.triplanar = true
            $0.topAmount = 0.35
        },
        // realforge:material.stone
    ]
}
