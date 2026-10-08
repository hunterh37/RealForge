import RealCore

public extension MaterialLibrary {
    /// Lineman tools and PPE: insulating rubber, gloss fiberglass, dipped vinyl grips, clear PVC jacket,
    /// stranded copper, split leather, harness webbing.
    static let lineman: [MaterialSpec] = [
        // Class 2 insulating rubber, red outer layer (Salisbury style dipped natural rubber, satin bloom).
        MaterialSpec(key: "rubber.insulating-red", program: .plastic).with {
            $0.colorA = linear(0xB0261C); $0.knobs = V4(0.35, 0.25, 0.62, 0); $0.seed = 1201; $0.tileSize = 0.25; $0.resolution = 512; $0.normalStrength = 0.8
        },
        // Black inner layer of two-colour insulating rubber (shows at the rolled cuff).
        MaterialSpec(key: "rubber.insulating-black", program: .plastic).with {
            $0.colorA = linear(0x1B1A19); $0.knobs = V4(0.3, 0.3, 0.6, 0); $0.seed = 1202; $0.tileSize = 0.25; $0.resolution = 512; $0.normalStrength = 0.8
        },
        // Orange insulating blanket rubber with chalky bloom and dirt.
        MaterialSpec(key: "rubber.insulating-orange", program: .plastic).with {
            $0.colorA = linear(0xE0601E); $0.knobs = V4(0.5, 0.45, 0.7, 0); $0.seed = 1203; $0.tileSize = 0.6; $0.resolution = 512; $0.normalStrength = 1
        },
        // Gloss gelcoat fiberglass (hot stick tubes), safety yellow.
        MaterialSpec(key: "plastic.fiberglass-yellow", program: .plastic).with {
            $0.colorA = linear(0xE8B814); $0.knobs = V4(1, 0.9, 0.12, 0); $0.seed = 1204; $0.tileSize = 0.4; $0.resolution = 512; $0.normalStrength = 0.3; $0.clearcoat = 1
        },
        // Dipped vinyl plier and cutter grips, gloss red (tint for blue/yellow).
        MaterialSpec(key: "vinyl.dipped-red", program: .plastic).with {
            $0.colorA = linear(0xB8221A); $0.knobs = V4(1, 0.8, 0.32, 0); $0.seed = 1205; $0.tileSize = 0.12; $0.resolution = 512; $0.normalStrength = 0.4; $0.clearcoat = 0.5
        },
        // Clear PVC cable jacket over copper strand (grounding leads).
        MaterialSpec(key: "plastic.pvc-clear", program: nil).with {
            $0.baseColor = V3(0.9, 0.86, 0.72); $0.roughness = 0.1; $0.specular = 0.5; $0.mode = .transparent; $0.opacity = 0.14; $0.twoSided = false
        },
        // Fine-strand bare copper (strand lay along U).
        MaterialSpec(key: "metal.copper-strand", program: .brushedMetal).with {
            $0.colorA = linear(0xC8754A); $0.colorB = linear(0x5A2E1C); $0.knobs = V4(1, 0.3, 0.3, 0.2); $0.seed = 1206; $0.tileSize = 0.02
            $0.normalStrength = 2.5; $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.3
        },
        // Split cowhide leather (glove protectors), sueded tan with work grime.
        MaterialSpec(key: "leather.split-tan", program: .leather).with {
            $0.colorA = linear(0xB08A5A); $0.colorB = linear(0x5E4428); $0.colorC = linear(0xD2B48A)
            $0.knobs = V4(40, 0.7, 0.9, 0.5); $0.seed = 1207; $0.tileSize = 0.12; $0.normalStrength = 1.8; $0.roughness = 0.9
        },
        // Polyester harness webbing, 45 mm, black (tint for the yellow dorsal straps).
        MaterialSpec(key: "fabric.webbing", program: .fabricWeave).with {
            $0.colorA = linear(0x1C1C1E); $0.colorB = linear(0x1C1C1E, 0); $0.colorC = linear(0x5A5040, 0.1)
            $0.knobs = V4(120, 0, 0.5, 10); $0.seed = 1208; $0.tileSize = 0.03; $0.normalStrength = 1.4; $0.roughness = 0.55
        },
        // HDPE hard hat shell: gloss with scuffs and site grime.
        MaterialSpec(key: "plastic.hardhat", program: .plastic).with {
            $0.colorA = linear(0xE6E4DE); $0.knobs = V4(1, 0.7, 0.2, 0); $0.seed = 1209; $0.tileSize = 0.18; $0.resolution = 512; $0.normalStrength = 0.5; $0.clearcoat = 0.6
        },
        // realityhd:material.lineman
    ]
}
