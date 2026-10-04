import RealCore

public extension MaterialLibrary {
    /// RealityHD 5 medical materials added with the Surgical batch.
    static let medicalSurgical: [MaterialSpec] = [
        // Gold-plated stainless (finger rings of tungsten-carbide insert instruments): satin gold, fine grind.
        MaterialSpec(key: "metal.surgical-gold", program: .brushedMetal).with {
            $0.colorA = linear(0xD9B45E); $0.colorB = linear(0x9C7A34)
            $0.knobs = V4(0.45, 0.28, 0.12, 0.15); $0.seed = 531; $0.tileSize = 0.08; $0.normalStrength = 0.2
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.28
        },
        // Tungsten-carbide jaw inserts: darker, cooler grey than stainless, matte from the crosshatch.
        MaterialSpec(key: "metal.tungsten-carbide", program: .brushedMetal).with {
            $0.colorA = linear(0x77797C); $0.colorB = linear(0x4E4F52)
            $0.knobs = V4(0.3, 0.42, 0.1, 0.1); $0.seed = 532; $0.tileSize = 0.05; $0.normalStrength = 0.3
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.42
        },
        // Translucent blue polycarbonate safety-scalpel shield: glossy, fairly saturated.
        MaterialSpec(key: "plastic.scalpel-shield", program: nil).with {
            $0.baseColor = V3(0.05, 0.25, 0.7); $0.roughness = 0.1; $0.specular = 0.5; $0.mode = .transparent; $0.opacity = 0.62; $0.twoSided = true
        },
        // realityhd:material.medicalSurgical
    ]
}
