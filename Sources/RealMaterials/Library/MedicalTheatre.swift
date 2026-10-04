import RealCore

public extension MaterialLibrary {
    /// RealityHD 5 medical materials added with the Theatre batch.
    static let medicalTheatre: [MaterialSpec] = [
        // Molded red resin of medical waste cans: fine stipple, scuffs and floor dirt low on the body. Tint for color.
        MaterialSpec(key: "plastic.resin-red", program: .plastic).with {
            $0.colorA = linear(0xB01E1A); $0.knobs = V4(0.8, 0.35, 0.5, 0); $0.seed = 901; $0.tileSize = 0.35; $0.resolution = 512; $0.normalStrength = 0.9
        },
        // Stainless wire-mesh basket panel (sterilization baskets): bright wires, dark open cells, 4 mm pitch.
        MaterialSpec(key: "metal.basket-mesh", program: .chairMesh).with {
            $0.colorA = linear(0xC9CBCD); $0.colorB = linear(0xA6A8AA); $0.colorC = linear(0x232527)
            $0.knobs = V4(14, 0.75, 0.3, 1); $0.seed = 902; $0.tileSize = 0.056; $0.normalStrength = 2.0; $0.roughness = 0.3; $0.metallic = 0.85
        },
        // Handled anodized aluminium (sterilization container tubs): satin, fingerprints, fine scratches. Tint for color.
        MaterialSpec(key: "metal.anodized-worn", program: .brushedMetal).with {
            $0.colorA = linear(0xB4B6B9); $0.colorB = linear(0x7E7E7C)
            $0.knobs = V4(0.45, 0.42, 0.5, 0.65); $0.seed = 903; $0.tileSize = 0.3; $0.normalStrength = 0.3
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.42
        },
        // Colored anodized lid (blue default): deeper smudges and scratches from stacking. Tint for color.
        MaterialSpec(key: "metal.anodized-lid", program: .brushedMetal).with {
            $0.colorA = linear(0x2E5C9E); $0.colorB = linear(0x1A2E4E)
            $0.knobs = V4(0.4, 0.46, 0.55, 0.8); $0.seed = 904; $0.tileSize = 0.25; $0.normalStrength = 0.3
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.46
        },
        // Device housing plastic after years in theatre: wipe marks, fine scratches, grime in low spots. Tint for color.
        MaterialSpec(key: "plastic.medical-worn", program: .plastic).with {
            $0.colorA = linear(0xECEAE3); $0.knobs = V4(0.6, 0.3, 0.34, 0); $0.seed = 905; $0.tileSize = 0.35; $0.resolution = 512; $0.normalStrength = 0.45
        },
        // Grey bumper / work-surface plastic, scuffed by trolleys and shoes. Tint for color.
        MaterialSpec(key: "plastic.medical-grey-worn", program: .plastic).with {
            $0.colorA = linear(0xA4A9AD); $0.knobs = V4(0.9, 0.55, 0.4, 0); $0.seed = 906; $0.tileSize = 0.3; $0.resolution = 512; $0.normalStrength = 0.5
        },
        // realityhd:material.medicalTheatre
    ]
}
