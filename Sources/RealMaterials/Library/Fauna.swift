import RealCore

public extension MaterialLibrary {
    /// Fauna surface programs for animal builders: bird plumage (body, head, single feather), mammal fur, hedgehog quills.
    /// Atlas programs (tileSize 0): u wraps the body (0 dorsal midline, 0.5 ventral), v 0 rear to 1 front.
    static let fauna: [MaterialSpec] = [
        // Bluebird torso: blue upperparts, pale belly, rusty breast patch. knobs: rows, boundary, patch extent, streaks.
        MaterialSpec(key: "fauna.plumage-body", program: .plumageBody).with {
            $0.colorA = linear(0x2F5FB0); $0.colorB = linear(0xE6E0D4); $0.colorC = linear(0xB5603A)
            $0.knobs = V4(30, 0.5, 0.4, 0); $0.seed = 8101; $0.tileSize = 0; $0.resolution = 1024; $0.normalStrength = 2.5; $0.roughness = 0.6
        },
        // Bluebird head: blue crown, blue cheek, rusty throat patch.
        MaterialSpec(key: "fauna.plumage-head", program: .plumageHead).with {
            $0.colorA = linear(0x2A58A8); $0.colorB = linear(0x3A6AB8); $0.colorC = linear(0xB5603A)
            $0.knobs = V4(40, 0.55, 0.3, 0); $0.seed = 8102; $0.tileSize = 0; $0.resolution = 1024; $0.normalStrength = 2; $0.roughness = 0.6
        },
        // Single contour/wing feather card.
        MaterialSpec(key: "fauna.feather", program: .plumageFeather).with {
            $0.colorA = linear(0x2A56A6); $0.colorB = linear(0x4A3C30); $0.colorC = linear(0xD8CDB8)
            $0.knobs = V4(90, 0.4, 0.35, 0.5); $0.seed = 8103; $0.tileSize = 0; $0.resolution = 512; $0.normalStrength = 2
            $0.mode = .cutout; $0.twoSided = true; $0.roughness = 0.58
        },
        // Rabbit-like coat: agouti grey-brown back, pale belly, dark guard-hair tips.
        MaterialSpec(key: "fauna.fur", program: .furCoat).with {
            $0.colorA = linear(0x8A7458); $0.colorB = linear(0xD8CDB8); $0.colorC = linear(0x2A2018)
            $0.knobs = V4(120, 0.55, 0.3, 0.5); $0.seed = 8104; $0.tileSize = 0; $0.resolution = 1024; $0.normalStrength = 1.5; $0.roughness = 0.9
        },
        // Hedgehog spines, meters UV.
        MaterialSpec(key: "fauna.quill", program: .quillCoat).with {
            $0.colorA = linear(0xD8C9A0); $0.colorB = linear(0x2E2218); $0.colorC = linear(0x1A1410)
            $0.knobs = V4(48, 0.9, 0.35, 0); $0.seed = 8105; $0.tileSize = 0.15; $0.resolution = 1024; $0.normalStrength = 3.5; $0.roughness = 0.6
        },
    ]
}
