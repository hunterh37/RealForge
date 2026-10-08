import simd
import Foundation

/// 8 ft shotgun hot stick lying on its side (Hastings 8100 class): 32 mm gloss yellow fiberglass tube with
/// a black molded butt cap, two black hand-guard sleeves, a black slide housing near the butt with its
/// thumb lever and an external operating rod running along the tube to the black shotgun head, where a
/// steel hook slides out of the jaw to grab eyes and rings. Part `slide` moves the housing, rod and hook
/// together 60 mm toward the head (`open`); `closed` pulls the hook home. The head is +X.
public struct HotStick: RealArticulated, RealHandTool {
    public static let id = "hot-stick"
    public static let summary = "8 ft fiberglass shotgun hot stick lying on the ground: yellow gloss tube, black head with a hook that slides shut from the handle."
    public static let tags = ["prop", "tool", "handheld", "utility", "electrical", "articulated", "plastic"]
    public static let budget = 5000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 28, distance: 0.75, studio: true)
    static let L: Float = 2.44, R: Float = 0.016, axisY: Float = 0.024
    /// Lineman's lower hand on the slide housing.
    public static let grip = SIMD3<Float>(-L / 2 + 0.36, axisY, 0)
    /// Hook throat at the head (closed).
    public static let tip = SIMD3<Float>(L / 2 + 0.01, axisY - 0.012, 0)

    /// Tube colour (sRGB hex).
    public var tubeColor: UInt32 = 0xD2A630
    /// Hook travel when opened (m).
    public var hookTravel: Float = 0.06
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [4])
        let L = Self.L, R = Self.R, y = Self.axisY
        let tube: MaterialKey = "plastic.fiberglass-yellow:" + String(format: "%06X", tubeColor)
        let black: MaterialKey = "plastic.black", rub: MaterialKey = "rubber", steel: MaterialKey = "metal.stainless"
        let alongX = simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))   // lathe +Y -> +X
        let x0 = -L / 2, x1 = L / 2
        for l in 0..<2 {
            let seg = l == 0 ? 24 : 10
            // Fiberglass tube, butt cap to head.
            rig.base[l].add(Prim.lathe([V2(R * 0.999, 0), V2(R, 0.01), V2(R, L - 0.42), V2(R * 0.999, L - 0.41)], segments: seg, seamTile: 0.1, material: tube),
                            Xform(translation: V3(x0 + 0.30, y, 0), rotation: alongX))
            // Telescoped black inner section below the slide housing.
            rig.base[l].add(Prim.lathe([V2(0.0125, 0), V2(0.0125, 0.30)], segments: seg, seamTile: 0.1, material: black),
                            Xform(translation: V3(x0 + 0.03, y, 0), rotation: alongX))
            // Butt cap: molded rubber with a domed end.
            rig.base[l].add(Prim.lathe([V2(0, 0), V2(0.009, 0.001), V2(0.0145, 0.006), V2(0.015, 0.03), V2(0.014, 0.045), V2(0.0126, 0.047)],
                                       segments: seg, seamTile: 0.1, material: rub), Xform(translation: V3(x0, y, 0), rotation: alongX))
            // Hand guard sleeves (black, 70 mm) along the working length.
            for gx: Float in [-0.40, 0.30] {
                rig.base[l].add(Prim.lathe([V2(R, 0), V2(R + 0.0028, 0.004), V2(R + 0.003, 0.126), V2(R, 0.13)], segments: seg, seamTile: 0.1, material: black),
                                Xform(translation: V3(gx, y, 0), rotation: alongX))
            }
            // Shotgun head body: black molded housing over the tube end, jaw slot toward +X.
            let hx = x1 - 0.17
            var head = Prim.roundedBox(V3(0.17, 0.048, 0.044), radius: 0.008, bevelSegments: l == 0 ? 3 : 1, material: black)
            head.deform { p in V3(p.x, p.y * (1 - 0.18 * max(0, (-p.x - 0.03) / 0.035)), p.z * (1 - 0.18 * max(0, (-p.x - 0.03) / 0.035))) }
            rig.base[l].add(head, Xform(translation: V3(hx + 0.085, y, 0)))
            // Jaw slot lips and the fixed jaw at the end.
            rig.base[l].add(Prim.roundedBox(V3(0.026, 0.016, 0.044), radius: 0.004, bevelSegments: 1, material: black), Xform(translation: V3(x1 - 0.012, y + 0.012, 0)))
            // Rod guide clips on the tube.
            for gx: Float in [-0.6, 0.0, 0.6] {
                rig.base[l].add(Prim.roundedBox(V3(0.02, 0.012, 0.03), radius: 0.003, bevelSegments: 1, material: black), Xform(translation: V3(gx, y, R + 0.002)))
            }
            // Label band near the head.
            rig.base[l].add(Prim.lathe([V2(R + 0.0004, 0), V2(R + 0.0004, 0.06)], segments: seg, seamTile: 0.1, material: "label.inspection"),
                            Xform(translation: V3(x1 - 0.32, y, 0), rotation: simd_quatf(angle: 0.6, axis: V3(1, 0, 0)) * alongX))
        }
        rig.part("slide", pivot: V3(x0 + 0.36, y, 0), joint: .slide(axis: V3(1, 0, 0), 0...hookTravel))
        // Slide housing with thumb lever.
        let sx = x0 + 0.30
        var housing = Prim.roundedBox(V3(0.15, 0.05, 0.048), radius: 0.009, bevelSegments: 3, material: black)
        housing.deform { p in V3(p.x, p.y, p.z + (p.z > 0 ? 0.004 : 0)) }
        rig.add(housing, Xform(translation: V3(sx + 0.075, y, 0.003)), to: "slide")
        rig.add(Prim.sweep(Shape2D.roundedRect(0.006, 0.012, radius: 0.0025), along: [V3(sx + 0.02, y + 0.024, 0.006), V3(sx + 0.045, y + 0.034, 0.006), V3(sx + 0.08, y + 0.036, 0.006)],
                           up: V3(0, 0, 1), material: steel), to: "slide")
        // External operating rod to the head (r 5 mm fiberglass, darker yellow).
        rig.add(Prim.tube([V3(sx + 0.15, y - 0.002, R + 0.0075), V3(x1 - 0.17, y - 0.002, R + 0.0075)], radii: [0.0045, 0.0045], sides: 10, seamTile: 0.03,
                          material: tube), to: "slide")
        // Hook: steel J out of the jaw, sliding with the rod.
        var hook: [V3] = []
        for i in 0...12 {
            let a = Float(i) / 12 * .pi * 1.15
            hook.append(V3(x1 - 0.004 + 0.024 * sin(a), y - 0.002, R + 0.008 + 0.024 * (1 - cos(a)) * 0.75))
        }
        rig.add(Prim.tube([V3(x1 - 0.08, y - 0.004, R + 0.008)] + hook, radii: Array(repeating: 0.005, count: hook.count + 1), sides: 10, seamTile: 0.03, material: steel), to: "slide")
        _ = rng.float()
        rig.states = [RigState("closed"), RigState("open", ["slide": hookTravel])]
        groundAO(&rig, height: 0.05)
        return rig
    }
}
