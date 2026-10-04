import RealCore

public extension MaterialLibrary {
    /// RealityHD 5 medical materials added with the HospitalStructures batch.
    static let medicalHospitalStructures: [MaterialSpec] = [
        // Pale maple woodgrain high-pressure laminate (door faces): flat cut, satin, fine pores. Grain along U.
        MaterialSpec(key: "laminate.door-maple", program: .woodVeneer).with {
            $0.colorA = linear(0xD9BF98); $0.colorB = linear(0xCDAF86); $0.colorC = linear(0xA0805A, 0.06)
            $0.knobs = V4(34, 12, 0.3, 8); $0.seed = 1101; $0.tileSize = 0.9; $0.resolution = 2048; $0.normalStrength = 0.25; $0.roughness = 0.5
        },
        // Stainless kick and armor plate: #4 brush with heavy cart scratches and hand smudges.
        MaterialSpec(key: "metal.kickplate", program: .brushedMetal).with {
            $0.colorA = linear(0xA6A8AA); $0.colorB = linear(0x6E6A64)
            $0.knobs = V4(0.9, 0.3, 0.75, 1.0); $0.seed = 1102; $0.tileSize = 0.35; $0.normalStrength = 0.4
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.3
        },
        // Black rubber transfer left by bed and cart bumpers (thin decal over plates and laminate).
        MaterialSpec(key: "decal.rubber-scuff", program: nil).with {
            $0.baseColor = V3(0.035, 0.035, 0.04); $0.roughness = 0.75; $0.mode = .transparent; $0.opacity = 0.72
        },
        // Wire mesh inside polished wired glass: 12 mm diamond of 0.6 mm steel wire (cutout plane in the pane).
        MaterialSpec(key: "glass.wire-mesh", program: .chainLink).with {
            $0.colorA = linear(0x9A9EA2); $0.colorB = linear(0x4E5256)
            $0.knobs = V4(0.8, 0.02, 0.4, 0.3); $0.seed = 1103; $0.tileSize = 0.035; $0.resolution = 512
            $0.normalStrength = 1; $0.mode = .cutout; $0.twoSided = true; $0.hasMetallicMap = true; $0.metallic = 0.8; $0.roughness = 0.4
        },
        // Running tap water: clear column with a bright specular sheen.
        MaterialSpec(key: "fluid.tap-water", program: nil).with {
            $0.baseColor = V3(0.86, 0.92, 0.96); $0.roughness = 0.02; $0.specular = 0.9; $0.mode = .transparent; $0.opacity = 0.34; $0.twoSided = true
        },
        // LED lens array cells, unlit: clear PMMA optics over metallized reflector cups.
        MaterialSpec(key: "glass.led-lens", program: nil).with {
            $0.baseColor = V3(0.6, 0.63, 0.66); $0.metallic = 0.75; $0.roughness = 0.1; $0.clearcoat = 1
        },
        // realityhd:material.medicalHospitalStructures
    ]
}
