import RealCore

public extension MaterialLibrary {
    /// RealityHD 5 medical materials added with the Patient batch.
    static let medicalPatient: [MaterialSpec] = [
        // High-pressure laminate in a hard-maple print (overbed tables, casework tops): pale, fine rings,
        // few cathedrals, no open pores, satin gloss. Grain along U.
        MaterialSpec(key: "laminate.patient-maple", program: .woodVeneer).with {
            $0.colorA = linear(0xDDBE94); $0.colorB = linear(0xC49E72); $0.colorC = linear(0x96714E, 0.08)
            $0.knobs = V4(46, 5, 0.25, 6); $0.seed = 5301; $0.tileSize = 0.9; $0.resolution = 2048; $0.normalStrength = 0.25; $0.roughness = 0.36; $0.clearcoat = 0.3
        },
        // realityhd:material.medicalPatient
    ]
}
