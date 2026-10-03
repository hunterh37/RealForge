import RealCore

public extension MaterialLibrary {
    /// Woven fabric (`fabricWeave`). Tints replace the yarn color: `fabric.nylon:C8501E`.
    static let fabric: [MaterialSpec] = [
        // Jute hessian, about 4 threads per cm with open gaps and loose fibers.
        MaterialSpec(key: "fabric.burlap", program: .fabricWeave).with {
            $0.colorA = linear(0xA2875F); $0.colorB = linear(0x7C6442, 1); $0.colorC = linear(0x4A3A28, 0.25)
            $0.knobs = V4(24, 0.8, 0.93, 0); $0.seed = 21; $0.tileSize = 0.06; $0.normalStrength = 4
            $0.roughness = 0.93
        },
        // Cotton duck canvas, about 10 threads per cm, tight weave.
        MaterialSpec(key: "fabric.canvas", program: .fabricWeave).with {
            $0.colorA = linear(0xB9AD92); $0.colorB = linear(0xA3967A, 0.6); $0.colorC = linear(0x584836, 0.2)
            $0.knobs = V4(40, 0.3, 0.86, 0); $0.seed = 22; $0.tileSize = 0.04; $0.normalStrength = 2.5
            $0.roughness = 0.86
        },
        // Coated ripstop nylon (tent fly), 5 mm ripstop grid, low roughness sheen.
        MaterialSpec(key: "fabric.nylon", program: .fabricWeave).with {
            $0.colorA = linear(0x4A6B3E); $0.colorB = linear(0x4A6B3E, 0); $0.colorC = linear(0x5A5040, 0.12)
            $0.knobs = V4(80, 0, 0.42, 10); $0.seed = 23; $0.tileSize = 0.05; $0.normalStrength = 1
            $0.roughness = 0.45
        },
        // Felted wool blanket, thick fuzzy yarn.
        MaterialSpec(key: "fabric.wool", program: .fabricWeave).with {
            $0.colorA = linear(0x7A2A22); $0.colorB = linear(0x5C201A, 1); $0.colorC = linear(0x3A2A20, 0.1)
            $0.knobs = V4(16, 1, 0.96, 0); $0.seed = 24; $0.tileSize = 0.03; $0.normalStrength = 3
            $0.roughness = 0.96
        },
        // realforge:material.fabric
    ]
}
