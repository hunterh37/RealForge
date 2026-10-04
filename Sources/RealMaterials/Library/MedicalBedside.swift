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
        // realityhd:material.medicalBedside
    ]
}
