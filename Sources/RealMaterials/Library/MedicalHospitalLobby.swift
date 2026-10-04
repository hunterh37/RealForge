import RealCore

public extension MaterialLibrary {
    /// RealityHD 5 medical materials added with the HospitalLobby batch.
    static let medicalHospitalLobby: [MaterialSpec] = [
        // Acrylic solid surface (Corian Glacier White class): warm white with a fine low-contrast fleck.
        MaterialSpec(key: "stone.solid-surface", program: .terrazzo).with {
            $0.colorA = linear(0xE9E6DF); $0.colorB = linear(0xD9D5CC); $0.colorC = linear(0xB9B4AA, 0.25)
            $0.knobs = V4(140, 0.12, 0.3, 0.5); $0.seed = 560; $0.tileSize = 0.6; $0.resolution = 1024; $0.normalStrength = 0.15
            $0.roughness = 0.3; $0.clearcoat = 0.2
        },
        // Radiograph on an unlit viewer: blue-black film base with faint branching lung markings (marble veins),
        // grey soft tissue (heart, diaphragm, chest wall), pale bone. Film-space UVs in meters.
        MaterialSpec(key: "film.xray-chest", program: .marble).with {
            $0.colorA = linear(0x0B0C0E); $0.colorB = linear(0x34383E); $0.colorC = linear(0x1A1C20, 0.5)
            $0.knobs = V4(3, 0.7, 0.012, 0.25); $0.seed = 561; $0.tileSize = 0.35; $0.resolution = 1024; $0.normalStrength = 0.05
            $0.roughness = 0.25; $0.specular = 0.25
        },
        MaterialSpec(key: "film.xray-soft", program: .marble).with {
            $0.colorA = linear(0x34373C); $0.colorB = linear(0x45494F); $0.colorC = linear(0x2A2C30, 0.5)
            $0.knobs = V4(2, 0.8, 0.02, 0.25); $0.seed = 562; $0.tileSize = 0.35; $0.resolution = 512; $0.normalStrength = 0.05
            $0.roughness = 0.25; $0.specular = 0.25
        },
        MaterialSpec(key: "film.xray-bone", program: nil).with { $0.baseColor = V3(0.12, 0.13, 0.14); $0.roughness = 0.25; $0.specular = 0.25 },
        // The same film transilluminated on a lit viewer (unlit: what the film transmits).
        MaterialSpec(key: "film.xray-chest-lit", program: .marble).with {
            $0.colorA = linear(0x101215); $0.colorB = linear(0x5C626A); $0.colorC = linear(0x262A2F, 0.5)
            $0.knobs = V4(3, 0.7, 0.012, 0.25); $0.seed = 561; $0.tileSize = 0.35; $0.resolution = 1024
            $0.mode = .emissive; $0.emissive = V3(1, 1, 1); $0.emissiveIntensity = 1
        },
        MaterialSpec(key: "film.xray-soft-lit", program: .marble).with {
            $0.colorA = linear(0x50555C); $0.colorB = linear(0x646A72); $0.colorC = linear(0x42464C, 0.5)
            $0.knobs = V4(2, 0.8, 0.02, 0.25); $0.seed = 562; $0.tileSize = 0.35; $0.resolution = 512
            $0.mode = .emissive; $0.emissive = V3(1, 1, 1); $0.emissiveIntensity = 1
        },
        MaterialSpec(key: "film.xray-bone-lit", program: nil).with {
            $0.baseColor = V3(0.4, 0.42, 0.45); $0.mode = .emissive; $0.emissive = V3(0.36, 0.39, 0.42); $0.emissiveIntensity = 1; $0.roughness = 0.25
        },
        // Printed patient ID flash card on a film and a biomed inspection sticker: label.rx artwork, UVs 0...1 across the label.
        MaterialSpec(key: "label.film-id", program: .medLabel).with {
            $0.colorA = linear(0xF2F1EC); $0.colorB = linear(0x3A3A3C); $0.colorC = linear(0x1A1A1C)
            $0.knobs = V4(0.22, 1, 4, 0.2); $0.seed = 563; $0.tileSize = 0; $0.resolution = 256; $0.normalStrength = 0.1
        },
        MaterialSpec(key: "label.inspection", program: .medLabel).with {
            $0.colorA = linear(0xF4F2E8); $0.colorB = linear(0x2E8A4A); $0.colorC = linear(0x1A1A1C)
            $0.knobs = V4(0.3, 1, 3, 0.25); $0.seed = 564; $0.tileSize = 0; $0.resolution = 256; $0.normalStrength = 0.1
        },
        // Self check-in kiosk welcome screen: white page, blue header band, greeked prompt lines (unlit, UVs 0...1).
        MaterialSpec(key: "screen.kiosk", program: .medLabel).with {
            $0.colorA = linear(0xF4F7FA); $0.colorB = linear(0x1F64B4); $0.colorC = linear(0x2A3440)
            $0.knobs = V4(0.16, 0, 5, 0); $0.seed = 565; $0.tileSize = 0; $0.resolution = 1024
            $0.mode = .emissive; $0.emissive = V3(1, 1, 1); $0.emissiveIntensity = 0.95
        },
        // "Oxygen in use" hang tag (green band) and a suction canister graduation label; UVs 0...1 across the label.
        MaterialSpec(key: "label.o2-tag", program: .medLabel).with {
            $0.colorA = linear(0xF4F2EA); $0.colorB = linear(0x2E8B3E); $0.colorC = linear(0x1A1A1C)
            $0.knobs = V4(0.38, 0, 2, 0.5); $0.seed = 566; $0.tileSize = 0; $0.resolution = 256; $0.normalStrength = 0.1
        },
        MaterialSpec(key: "label.canister", program: .medLabel).with {
            $0.colorA = linear(0xEEF2F4); $0.colorB = linear(0x2A5FA8); $0.colorC = linear(0x223040)
            $0.knobs = V4(0.1, 0, 8, 0.9); $0.seed = 567; $0.tileSize = 0; $0.resolution = 256; $0.normalStrength = 0.1
        },
        // Patient chart binder spine insert (room number band); UVs 0...1 across the insert.
        MaterialSpec(key: "label.binder", program: .medLabel).with {
            $0.colorA = linear(0xF6F5F0); $0.colorB = linear(0x2A2C30); $0.colorC = linear(0x1A1A1C)
            $0.knobs = V4(0.3, 0, 3, 0.3); $0.seed = 568; $0.tileSize = 0; $0.resolution = 256; $0.normalStrength = 0.1
        },
        // realityhd:material.medicalHospitalLobby
    ]
}
