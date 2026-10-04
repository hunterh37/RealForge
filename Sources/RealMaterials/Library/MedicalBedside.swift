import RealCore

public extension MaterialLibrary {
    /// RealityHD 5 medical materials added with the Bedside batch. Label and screen variants use
    /// tileSize 0 (UVs 0...1 across the panel, same image as tileSize 1) so small panels lint clean.
    static let medicalBedside: [MaterialSpec] = [
        // Navy BP-cuff nylon: dense twill, satin sheen, light handling grime. (fabric.nylon resolves to the
        // green tent ripstop in Fabric.swift, which is registered first.)
        MaterialSpec(key: "fabric.cuff-navy", program: .fabricWeave).with {
            $0.colorA = linear(0x1F3560); $0.colorB = linear(0x172A4C, 0.45); $0.colorC = linear(0x3A342A, 0.05)
            $0.knobs = V4(120, 0.15, 0.62, 0); $0.seed = 801; $0.tileSize = 0.03; $0.normalStrength = 1.4; $0.roughness = 0.62
        },
        // Gauge / instrument lens: thin clear polycarbonate dome, weak reflection so the dial reads through it.
        MaterialSpec(key: "glass.gauge-lens", program: nil).with {
            $0.baseColor = V3(0.86, 0.9, 0.9); $0.roughness = 0.04; $0.specular = 0.22; $0.mode = .transparent; $0.opacity = 0.06; $0.twoSided = false
        },
        // Printed white cuff index/range label (white film, navy band, black print).
        MaterialSpec(key: "label.bedside-cuff", program: .medLabel).with {
            $0.colorA = linear(0xEDEEEA); $0.colorB = linear(0x2A4C8C); $0.colorC = linear(0x16181C)
            $0.knobs = V4(0.3, 0, 3, 0.5); $0.seed = 802; $0.tileSize = 0; $0.resolution = 256; $0.normalStrength = 0.1
        },
        // Syringe barrel polypropylene: water-clear, glossy, thinner haze than plastic.clear so the stopper reads black.
        MaterialSpec(key: "plastic.syringe-barrel", program: nil).with {
            $0.baseColor = V3(0.9, 0.93, 0.95); $0.roughness = 0.06; $0.specular = 0.5; $0.mode = .transparent; $0.opacity = 0.12; $0.twoSided = true
        },
        // Drawn saline / drug inside a syringe or line: nearly invisible, a faint meniscus sheen.
        MaterialSpec(key: "fluid.drawn", program: nil).with {
            $0.baseColor = V3(0.86, 0.92, 0.96); $0.roughness = 0.02; $0.specular = 0.55; $0.mode = .transparent; $0.opacity = 0.045
        },
        // Syringe drug label (white with a colored drug-class band, black text), wrapped on a barrel.
        MaterialSpec(key: "label.bedside-drug", program: .medLabel).with {
            $0.colorA = linear(0xF4F3EE); $0.colorB = linear(0xE0C21C); $0.colorC = linear(0x16181C)
            $0.knobs = V4(0.32, 0, 2, 0.3); $0.seed = 803; $0.tileSize = 0; $0.resolution = 256; $0.normalStrength = 0.1
        },
        // IV bag printed film label (green band, lot block, barcode), UVs 0...1 across the print, v down.
        MaterialSpec(key: "label.bedside-iv", program: .medLabel).with {
            $0.colorA = linear(0xE9EEF0); $0.colorB = linear(0x2F7A4A); $0.colorC = linear(0x223040)
            $0.knobs = V4(0.14, 1, 6, 0.9); $0.seed = 804; $0.tileSize = 0; $0.resolution = 512; $0.normalStrength = 0.1
        },
        // Infusion pump color LCD background: backlit deep blue (digits are emissive geometry on top).
        MaterialSpec(key: "screen.bedside-pump", program: nil).with {
            $0.baseColor = V3(0.04, 0.12, 0.3); $0.mode = .emissive; $0.emissive = V3(0.06, 0.2, 0.55); $0.emissiveIntensity = 0.9; $0.roughness = 0.15; $0.specular = 0.4
        },
        // White display numerals and text (pump, monitor and AED screens).
        MaterialSpec(key: "emissive.bedside-white", program: nil).with {
            $0.baseColor = V3(0.95, 0.97, 1); $0.mode = .emissive; $0.emissive = V3(0.95, 0.97, 1); $0.emissiveIntensity = 1.6
        },
        // Biomed asset / inspection label: white with a blue band and barcode.
        MaterialSpec(key: "label.bedside-asset", program: .medLabel).with {
            $0.colorA = linear(0xF2F2EE); $0.colorB = linear(0x2A5DA8); $0.colorC = linear(0x1A1A1C)
            $0.knobs = V4(0.22, 1, 3, 0.4); $0.seed = 805; $0.tileSize = 0; $0.resolution = 256; $0.normalStrength = 0.1
        },
        // Bedside monitor display (same program and look as screen.vitals, tileSize 0 for a 0.32 m panel).
        MaterialSpec(key: "screen.bedside-vitals", program: .vitalsUI).with {
            $0.colorA = linear(0x030405); $0.knobs = V4(72, 98, 0.62, 0); $0.seed = 806; $0.tileSize = 0; $0.resolution = 2048
            $0.mode = .emissive; $0.emissive = V3(1, 1, 1); $0.emissiveIntensity = 0.95; $0.roughness = 0.3; $0.specular = 0.15
        },
        // Same display in alarm: tachycardia, low SpO2, yellow banner.
        MaterialSpec(key: "screen.bedside-vitals-alarm", program: .vitalsUI).with {
            $0.colorA = linear(0x030405); $0.knobs = V4(128, 89, 0.35, 1); $0.seed = 807; $0.tileSize = 0; $0.resolution = 2048
            $0.mode = .emissive; $0.emissive = V3(1, 1, 1); $0.emissiveIntensity = 0.95; $0.roughness = 0.3; $0.specular = 0.15
        },
        // Strip of white cloth tape with a handwritten bed number (greeked as print), matte.
        MaterialSpec(key: "label.bedside-bedtape", program: .medLabel).with {
            $0.colorA = linear(0xEFEDE4); $0.colorB = linear(0xEFEDE4); $0.colorC = linear(0x1E2A5A)
            $0.knobs = V4(0, 0, 1, 0); $0.seed = 808; $0.tileSize = 0; $0.resolution = 256; $0.normalStrength = 0.3
        },
        // AED deck instruction strip: white with a red band, black text.
        MaterialSpec(key: "label.bedside-aed", program: .medLabel).with {
            $0.colorA = linear(0xF1F0EA); $0.colorB = linear(0xC8281E); $0.colorC = linear(0x1A1A1C)
            $0.knobs = V4(0.4, 0, 1, 0.5); $0.seed = 809; $0.tileSize = 0; $0.resolution = 256; $0.normalStrength = 0.1
        },
        // CPR instruction panel on the AED lid underside: white, green band, step text.
        MaterialSpec(key: "label.bedside-aed-cpr", program: .medLabel).with {
            $0.colorA = linear(0xF3F3EE); $0.colorB = linear(0x2F7A4A); $0.colorC = linear(0x1A1A1C)
            $0.knobs = V4(0.16, 0, 7, 0.4); $0.seed = 810; $0.tileSize = 0; $0.resolution = 512; $0.normalStrength = 0.1
        },
        // Electrode pad backing print: white foam, blue band, placement text.
        MaterialSpec(key: "label.bedside-pads", program: .medLabel).with {
            $0.colorA = linear(0xEEF0F0); $0.colorB = linear(0x2A5DA8); $0.colorC = linear(0x223040)
            $0.knobs = V4(0.25, 0, 4, 0.2); $0.seed = 811; $0.tileSize = 0; $0.resolution = 256; $0.normalStrength = 0.1
        },
        // Lit AED shock button: saturated orange lamp behind a translucent cap.
        MaterialSpec(key: "emissive.bedside-shock", program: nil).with {
            $0.baseColor = V3(1, 0.42, 0.08); $0.mode = .emissive; $0.emissive = V3(1, 0.32, 0.04); $0.emissiveIntensity = 2.2
        },
        // Equipment inspection tag: buff card, red band, check-off grid text.
        MaterialSpec(key: "label.bedside-tag", program: .medLabel).with {
            $0.colorA = linear(0xF1EEDC); $0.colorB = linear(0xB8352A); $0.colorC = linear(0x1E2A5A)
            $0.knobs = V4(0.15, 0, 8, 0); $0.seed = 812; $0.tileSize = 0; $0.resolution = 256; $0.normalStrength = 0.2
        },
        // Unlit reflective segment LCD (glucometers, thermometers): grey-green, matte polarizer.
        MaterialSpec(key: "screen.bedside-lcd-off", program: nil).with {
            $0.baseColor = V3(0.36, 0.4, 0.37); $0.roughness = 0.35; $0.specular = 0.4
        },
        // Fresh capillary blood drop: deep red, glossy.
        MaterialSpec(key: "fluid.bedside-blood", program: nil).with {
            $0.baseColor = V3(0.32, 0.01, 0.02); $0.roughness = 0.08; $0.specular = 0.6; $0.clearcoat = 1
        },
        // Backlit segment LCD: pale grey-green, soft glow (darker than screen.lcd so black segments read).
        MaterialSpec(key: "screen.bedside-lcd-on", program: nil).with {
            $0.baseColor = V3(0.52, 0.62, 0.55); $0.mode = .emissive; $0.emissive = V3(0.42, 0.62, 0.5); $0.emissiveIntensity = 0.32; $0.roughness = 0.3
        },
        // Test strip vial label: white, blue band, lot/expiry lines.
        MaterialSpec(key: "label.bedside-strips", program: .medLabel).with {
            $0.colorA = linear(0xF3F4F2); $0.colorB = linear(0x2A6CC0); $0.colorC = linear(0x1A1A1C)
            $0.knobs = V4(0.35, 0, 2, 0.6); $0.seed = 813; $0.tileSize = 0; $0.resolution = 256; $0.normalStrength = 0.1
        },
        // realityhd:material.medicalBedside
    ]
}
