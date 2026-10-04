import RealCore

public extension MaterialLibrary {
    /// Hand anatomy overlay: cortical bone, articular cartilage, skeletal muscle, tendon, veins,
    /// arteries and nerves, plus `-glass` see-through variants for layered views. Colors follow
    /// fresh-tissue references (wet muscle and tendon, not embalmed specimens). UVs are meters with u
    /// around and v along each structure.
    static let anatomy: [MaterialSpec] = {
        let bone = MaterialSpec(key: "anatomy.bone", program: .boneCortical).with {
            $0.colorA = linear(0xDCCBA8); $0.colorB = linear(0xC29E62); $0.colorC = linear(0x7A6A55)
            $0.knobs = V4(70, 0.8, 0.55, 0.35); $0.seed = 901; $0.tileSize = 0.04; $0.resolution = 1024
            $0.normalStrength = 1.4; $0.roughness = 0.55; $0.baseColor = V3(0.78, 0.7, 0.55)
        }
        let cartilage = MaterialSpec(key: "anatomy.cartilage", program: .cartilageHyaline).with {
            $0.colorA = linear(0xC8D3D8); $0.colorB = linear(0xA3B4C2); $0.knobs = V4(4, 0, 0.16, 0)
            $0.seed = 902; $0.tileSize = 0.03; $0.resolution = 512; $0.normalStrength = 0.4; $0.roughness = 0.16; $0.clearcoat = 0.7
            $0.baseColor = V3(0.72, 0.78, 0.82)
        }
        let muscle = MaterialSpec(key: "anatomy.muscle", program: .muscleFiber).with {
            $0.colorA = linear(0x9A2420); $0.colorB = linear(0x4C0D10); $0.colorC = linear(0xEAD9D0, 0.55)
            $0.knobs = V4(14, 0, 0.36, 0.5); $0.seed = 903; $0.tileSize = 0.03; $0.resolution = 1024
            $0.normalStrength = 1.6; $0.roughness = 0.36; $0.clearcoat = 0.5; $0.baseColor = V3(0.33, 0.03, 0.03)
        }
        let tendon = MaterialSpec(key: "anatomy.tendon", program: .tendonFiber).with {
            $0.colorA = linear(0xE0D8C8); $0.colorB = linear(0xA39782); $0.knobs = V4(18, 0.7, 0.34, 0)
            $0.seed = 904; $0.tileSize = 0.02; $0.resolution = 1024; $0.normalStrength = 1.3; $0.roughness = 0.34; $0.clearcoat = 0.5
            $0.baseColor = V3(0.72, 0.68, 0.6)
        }
        let vein = MaterialSpec(key: "anatomy.vein", program: .vesselWall).with {
            $0.colorA = linear(0x343660); $0.colorB = linear(0x5E2236); $0.colorC = linear(0xB8BCD6)
            $0.knobs = V4(5, 0.6, 0.28, 0); $0.seed = 905; $0.tileSize = 0.02; $0.resolution = 512
            $0.normalStrength = 0.7; $0.roughness = 0.28; $0.clearcoat = 0.5; $0.baseColor = V3(0.05, 0.06, 0.2)
        }
        let artery = MaterialSpec(key: "anatomy.artery", program: .vesselWall).with {
            $0.colorA = linear(0xB3282B); $0.colorB = linear(0x6E1218); $0.colorC = linear(0xF2DCDC)
            $0.knobs = V4(5, 0.5, 0.3, 0); $0.seed = 906; $0.tileSize = 0.02; $0.resolution = 512
            $0.normalStrength = 0.7; $0.roughness = 0.3; $0.clearcoat = 0.5; $0.baseColor = V3(0.45, 0.03, 0.03)
        }
        let nerve = MaterialSpec(key: "anatomy.nerve", program: .nerveFascicle).with {
            $0.colorA = linear(0xEADBA8); $0.colorB = linear(0xC6AE72); $0.knobs = V4(5, 0.6, 0.4, 0)
            $0.seed = 907; $0.tileSize = 0.02; $0.resolution = 512; $0.normalStrength = 0.8; $0.roughness = 0.4
            $0.baseColor = V3(0.82, 0.72, 0.4)
        }
        func glass(_ s: MaterialSpec, _ opacity: Float) -> MaterialSpec {
            s.with { $0.key += "-glass"; $0.mode = .transparent; $0.opacity = opacity; $0.clearcoat = 0 }
        }
        return [bone, cartilage, muscle, tendon, vein, artery, nerve,
                glass(muscle, 0.5), glass(tendon, 0.55), glass(vein, 0.8), glass(artery, 0.8), glass(nerve, 0.7)]
    }()
}
