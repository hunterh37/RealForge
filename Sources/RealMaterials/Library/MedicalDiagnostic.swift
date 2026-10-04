import RealCore

public extension MaterialLibrary {
    /// RealityHD 5 medical materials added with the Diagnostic batch.
    static let medicalDiagnostic: [MaterialSpec] = [
        // Diamond knurl on chrome instrument handles (otoscope, laryngoscope): crossed V-grooves at about
        // 1.5 mm pitch, bright crowns, darker groove floors. Opaque use of the chain-link diamond pattern.
        MaterialSpec(key: "metal.knurl-chrome", program: .chainLink).with {
            $0.colorA = linear(0xD2D4D6); $0.colorB = linear(0x55585C)
            $0.knobs = V4(1, 0.06, 0.22, 0.25); $0.seed = 541; $0.tileSize = 0.003; $0.resolution = 256
            $0.normalStrength = 1.4; $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.22
        },
        // Fingertip oximeter OLED: black panel, SpO2 in cyan and pulse rate in green (crop the numerics
        // column of the vitals layout onto the panel quads).
        MaterialSpec(key: "screen.oximeter-oled", program: .vitalsUI).with {
            $0.colorA = linear(0x010101); $0.knobs = V4(76, 98, 0.5, 0); $0.seed = 542; $0.tileSize = 1; $0.resolution = 1024
            $0.mode = .emissive; $0.emissive = V3(1, 1, 1); $0.emissiveIntensity = 1.3; $0.roughness = 0.2; $0.specular = 0.2
        },
        // realityhd:material.medicalDiagnostic
    ]
}
