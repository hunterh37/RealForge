import RealCore

public extension MaterialLibrary {
    /// RealityHD 5 medical materials added with the Clinic batch.
    static let medicalClinic: [MaterialSpec] = [
        // Sharps container body: opaque red polypropylene, satin with faint mould texture.
        MaterialSpec(key: "plastic.sharps-red", program: .plastic).with {
            $0.colorA = linear(0xB31E1A); $0.knobs = V4(0.18, 0.12, 0.34, 0); $0.seed = 801; $0.tileSize = 0.15; $0.resolution = 512; $0.normalStrength = 0.35
        },
        // Sharps container lid: translucent red PP, fill level visible through it.
        MaterialSpec(key: "plastic.sharps-lid", program: nil).with {
            $0.baseColor = V3(0.62, 0.07, 0.06); $0.roughness = 0.32; $0.specular = 0.45; $0.mode = .transparent; $0.opacity = 0.62; $0.twoSided = true
        },
        // Medical oxygen shoulder paint (US green, glossy enamel over aluminium, chips at the edges).
        MaterialSpec(key: "paint.cylinder-green", program: .paintedMetal).with {
            $0.colorA = linear(0x1F7A3A); $0.colorC = linear(0xA8AAAC, 0.8); $0.knobs = V4(0.18, 0.3, 0.26, 0)
            $0.seed = 802; $0.tileSize = 0.4; $0.hasMetallicMap = true; $0.normalStrength = 0.6; $0.roughness = 0.28
        },
        // Microscope stand enamel: warm ivory baked paint (Olympus CX class).
        MaterialSpec(key: "paint.microscope-ivory", program: .paintedMetal).with {
            $0.colorA = linear(0xE9E6DC); $0.colorC = linear(0x8E8C86, 0.5); $0.knobs = V4(0.08, 0.15, 0.3, 0)
            $0.seed = 803; $0.tileSize = 0.5; $0.hasMetallicMap = true; $0.normalStrength = 0.4; $0.roughness = 0.32
        },
        // Small-label variants: the medLabel layouts with tileSize 0.08, so a label whose UVs run 0...0.08
        // across it keeps meters-per-UV near 1 (labels 3-20 cm). Same look as label.rx / .hazard / .iv.
        MaterialSpec(key: "label.rx-small", program: .medLabel).with {
            $0.colorA = linear(0xF6F5F0); $0.colorB = linear(0x2A5DA8); $0.colorC = linear(0x1A1A1C)
            $0.knobs = V4(0.22, 1, 4, 0.2); $0.seed = 804; $0.tileSize = 0.08; $0.resolution = 512; $0.normalStrength = 0.1
        },
        MaterialSpec(key: "label.hazard-small", program: .medLabel).with {
            $0.colorA = linear(0xF4F1E8); $0.colorB = linear(0xD8381E); $0.colorC = linear(0x1A1A1C)
            $0.knobs = V4(0.35, 0, 3, 0.4); $0.seed = 805; $0.tileSize = 0.08; $0.resolution = 512; $0.normalStrength = 0.1
        },
        MaterialSpec(key: "label.supply-small", program: .medLabel).with {
            $0.colorA = linear(0xF2F3F4); $0.colorB = linear(0x2F7A4A); $0.colorC = linear(0x223040)
            $0.knobs = V4(0.18, 0, 3, 0.5); $0.seed = 806; $0.tileSize = 0.08; $0.resolution = 512; $0.normalStrength = 0.1
        },
        // Oxygen USP label: white with a green band.
        MaterialSpec(key: "label.oxygen-small", program: .medLabel).with {
            $0.colorA = linear(0xF5F5F1); $0.colorB = linear(0x1F7A3A); $0.colorC = linear(0x1A1A1C)
            $0.knobs = V4(0.3, 0, 4, 0.5); $0.seed = 807; $0.tileSize = 0.08; $0.resolution = 512; $0.normalStrength = 0.1
        },
        // realityhd:material.medicalClinic
    ]
}
