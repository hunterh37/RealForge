import RealCore

public extension MaterialLibrary {
    /// Rock: triplanar, with a world-up layer for moss or dust. Albedo sits in the 0x40 to 0xB5 sRGB range.
    static let rock: [MaterialSpec] = [
        MaterialSpec(key: "rock.granite", program: .rockGranite).with {
            $0.colorA = linear(0x67635D); $0.colorB = linear(0x8F8A82); $0.colorC = linear(0xA07B6C)
            $0.knobs = V4(0.6, 0.05, 0, 0.3); $0.tileSize = 1.0; $0.normalStrength = 2.4; $0.triplanar = true
            $0.topAmount = 0.7; $0.topLow = 0.68
        },
        MaterialSpec(key: "rock.granite-bare", program: .rockGranite).with {
            $0.colorA = linear(0x6B665F); $0.colorB = linear(0x928C83); $0.colorC = linear(0xA07B6C)
            $0.knobs = V4(0.15, 0.05, 0, 0.1); $0.seed = 5; $0.tileSize = 1.0; $0.normalStrength = 2.2; $0.triplanar = true
        },
        MaterialSpec(key: "rock.limestone", program: .rockGranite).with {
            $0.colorA = linear(0x9A9488); $0.colorB = linear(0xB3AD9F); $0.colorC = linear(0x8C7B62)
            $0.knobs = V4(0.45, 0.7, 0.9, 0.8); $0.seed = 13; $0.tileSize = 1.4; $0.normalStrength = 2.6; $0.triplanar = true
            $0.topAmount = 0.35; $0.topLow = 0.7
        },
        MaterialSpec(key: "rock.basalt", program: .rockGranite).with {
            $0.colorA = linear(0x42403D); $0.colorB = linear(0x575450); $0.colorC = linear(0x6A4A38)
            $0.knobs = V4(0.3, 0.45, 0.75, 0.2); $0.seed = 17; $0.tileSize = 1.0; $0.normalStrength = 2.6; $0.triplanar = true
            $0.topAmount = 0.3; $0.topLow = 0.7
        },
        MaterialSpec(key: "rock.mossy", program: .rockGranite).with {
            $0.colorA = linear(0x5E5B55); $0.colorB = linear(0x837E76); $0.colorC = linear(0x8F7A6A)
            $0.knobs = V4(1.0, 0.05, 0.2, 0.5); $0.seed = 21; $0.tileSize = 1.0; $0.normalStrength = 2.4; $0.triplanar = true
            $0.topColor = linear(0x35521A); $0.topAmount = 1; $0.topLow = 0.12
        },
        MaterialSpec(key: "rock.sandstone", program: .strataRock).with {
            $0.colorA = linear(0xA4805D); $0.colorB = linear(0xC6A47E); $0.colorC = linear(0xD6C19E)
            $0.knobs = V4(0.5, 10, 0.4, 0.6); $0.seed = 9; $0.tileSize = 2.0; $0.normalStrength = 2.4; $0.triplanar = true
            $0.topColor = linear(0x5A6A2A); $0.topAmount = 0.3; $0.topLow = 0.65
        },
        MaterialSpec(key: "rock.redstone", program: .strataRock).with {
            $0.colorA = linear(0x86472C); $0.colorB = linear(0xAD6840); $0.colorC = linear(0xC49C76)
            $0.knobs = V4(0.8, 12, 0.7, 0.4); $0.seed = 27; $0.tileSize = 3.0; $0.normalStrength = 2.6; $0.triplanar = true
            $0.topColor = linear(0xB48A62); $0.topAmount = 0.4; $0.topLow = 0.7
        },
        MaterialSpec(key: "rock.slate", program: .rockSlate).with {
            $0.colorA = linear(0x4A4F55); $0.colorB = linear(0x7A7E82); $0.colorC = linear(0x8A5A30)
            $0.knobs = V4(0.35, 14, 0, 0); $0.seed = 31; $0.tileSize = 1.0; $0.normalStrength = 2.6; $0.triplanar = true
            $0.topAmount = 0.5; $0.topLow = 0.65
        },
        MaterialSpec(key: "rock.river", program: .rockRiver).with {
            $0.colorA = linear(0x75716A); $0.colorB = linear(0x8C8474); $0.colorC = linear(0xCBC4B8)
            $0.knobs = V4(0, 0.6, 0, 0); $0.seed = 37; $0.tileSize = 0.5; $0.normalStrength = 1.2; $0.triplanar = true
        },
        MaterialSpec(key: "rock.river-wet", program: .rockRiver).with {
            $0.colorA = linear(0x75716A); $0.colorB = linear(0x8C8474); $0.colorC = linear(0xCBC4B8)
            $0.knobs = V4(1, 0.6, 0, 0); $0.seed = 37; $0.tileSize = 0.5; $0.normalStrength = 1.2; $0.triplanar = true
            $0.specular = 0.6
        },
        // realforge:material.rock
    ]
}
