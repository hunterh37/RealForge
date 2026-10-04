import RealCore

public extension MaterialLibrary {
    /// RealityHD 5 medical materials added with the Diagnostic batch.
    static let medicalDiagnostic: [MaterialSpec] = [
        // Diamond knurl on chrome instrument handles (otoscope, laryngoscope): crossed V-grooves at about
        // 1.5 mm pitch, bright crowns, darker groove floors. Opaque use of the chain-link diamond pattern.
        MaterialSpec(key: "metal.knurl-chrome", program: .chainLink).with {
            $0.colorA = linear(0xE2E4E6); $0.colorB = linear(0xA2A5A8)
            $0.knobs = V4(1, 0.085, 0.2, 0.25); $0.seed = 541; $0.tileSize = 0.003; $0.resolution = 256
            $0.normalStrength = 0.8; $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.2
        },
        // Fingertip oximeter OLED: black panel, SpO2 in cyan and pulse rate in green (crop the numerics
        // column of the vitals layout onto the panel quads).
        MaterialSpec(key: "screen.oximeter-oled", program: .vitalsUI).with {
            $0.colorA = linear(0x010101); $0.knobs = V4(76, 98, 0.5, 0); $0.seed = 542; $0.tileSize = 1; $0.resolution = 1024
            $0.mode = .emissive; $0.emissive = V3(1, 1, 1); $0.emissiveIntensity = 1.3; $0.roughness = 0.2; $0.specular = 0.2
        },
        // Reprocessed stainless (laryngoscope blades, reusable instruments): autoclave-dulled satin with
        // water-spot smudges and fine scratches from cleaning.
        MaterialSpec(key: "metal.surgical-autoclaved", program: .brushedMetal).with {
            $0.colorA = linear(0xA9ABAC); $0.colorB = linear(0x8A8576)
            $0.knobs = V4(0.6, 0.34, 0.75, 0.55); $0.seed = 543; $0.tileSize = 0.07; $0.normalStrength = 0.3
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.36
        },
        // Small equipment sticker (biomed inspection / asset tag): green band, two text lines, barcode.
        // Sized for meters UVs on labels about 12 mm across (tileSize 0.012 = one label).
        MaterialSpec(key: "label.biomed", program: .medLabel).with {
            $0.colorA = linear(0xF4F3EE); $0.colorB = linear(0x2F8F4E); $0.colorC = linear(0x1A1A1C)
            $0.knobs = V4(0.26, 1, 2, 0.5); $0.seed = 544; $0.tileSize = 0.012; $0.resolution = 256; $0.normalStrength = 0.1
        },
        // realityhd:material.medicalDiagnostic
    ]
}
