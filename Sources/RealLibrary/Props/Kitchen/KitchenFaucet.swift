import simd
import Foundation

/// Single-hole pull-down kitchen faucet: deck escutcheon, round body with a side lever, high-arc
/// gooseneck spout that swivels, magnetic pull-down spray head with a pause button and aerator, and a
/// water column that runs while the lever is open. Deck (counter top) at y = 0, spout reaching +Z.
public struct KitchenFaucet: RealArticulated {
    public static let id = "kitchen-faucet"
    public static let summary = "Pull-down kitchen faucet: high-arc gooseneck spout, spray head, side lever, deck plate; lever opens a water stream."
    public static let tags = ["prop", "kitchen", "metal", "articulated"]
    public static let budget = 5000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 60, elevation: 12, distance: 0.9, studio: true)

    public var finish: MaterialKey = "metal.stainless"
    /// Handled surfaces (spray head, escutcheon, lever): fingerprints and water film.
    public var handled: MaterialKey = "metal.stainless-smudged"
    /// Length of the water column below the deck (reaches the sink floor).
    public var streamDrop: Float = 0.2
    public init() {}

    /// The model is centered on its footprint; the deck hole (body axis) sits at `deckHole`.
    public static let deckHole = V3(-0.009, 0, -0.08)
    /// Aerator center at rest (asset space).
    public var spoutTip: V3 { V3(0, 0.255, 0.19) + Self.deckHole }
    var tipLocal: V3 { V3(0, 0.255, 0.19) }

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [4])
        let f = finish
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let seg = l == 0 ? 28 : 14
            // Escutcheon and body.
            m.add(Prim.lathe([V2(0.001, 0), V2(0.034, 0), V2(0.034, 0.002), V2(0.03, 0.006), V2(0.022, 0.008), V2(0.001, 0.008)], segments: seg, seamTile: 0.05, material: handled))
            m.add(Prim.lathe([V2(0.001, 0.008), V2(0.0235, 0.008), V2(0.0235, 0.012), V2(0.022, 0.03), V2(0.0205, 0.19), V2(0.0215, 0.195), V2(0.0215, 0.2), V2(0.001, 0.2)],
                             segments: seg, seamTile: 0.05, material: f))
            // Lever hub boss on the right side.
            m.add(Prim.cylinder(radius: 0.012, height: 0.012, bevel: 0.002, segments: seg / 2, material: f),
                  Xform(translation: V3(0.019, 0.155, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
            rig.base[l] = m
        }
        // Lever: swings forward-up about X.
        rig.part("lever", pivot: V3(0.03, 0.155, 0), joint: .hinge(axis: V3(1, 0, 0), 0...60, duration: 0.3))
        let leverPath = catmull([V3(0.033, 0.155, 0), V3(0.04, 0.17, -0.01), V3(0.045, 0.215, -0.03), V3(0.046, 0.25, -0.045)], per: 4)
        let leverR = leverPath.indices.map { i in 0.008 - 0.003 * Float(i) / Float(leverPath.count - 1) }
        for l in 0..<2 {
            rig.add(Prim.tube(leverPath, radii: leverR, sides: l == 0 ? 14 : 8, seamTile: 0.03, material: handled), to: "lever", lods: l...l)
            rig.add(Prim.cylinder(radius: 0.011, height: 0.006, bevel: 0.002, segments: 16, material: f),
                    Xform(translation: V3(0.031, 0.155, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "lever", lods: l...l)
        }
        // Spout: swivels on the body.
        rig.part("spout", pivot: V3(0, 0.2, 0), joint: .hinge(axis: .up, -90...90, duration: 0.6))
        let arc = catmull([V3(0, 0.195, 0), V3(0, 0.3, 0), V3(0, 0.375, 0.012), V3(0, 0.405, 0.065), V3(0, 0.39, 0.135), V3(0, 0.35, 0.183), V3(0, 0.322, 0.19)], per: 5)
        for l in 0..<2 {
            rig.add(Prim.tube(arc, radii: Array(repeating: 0.0125, count: arc.count), sides: l == 0 ? 18 : 10, seamTile: 0.04, material: f), to: "spout", lods: l...l)
            rig.add(Prim.lathe([V2(0.0135, 0), V2(0.0145, 0.003), V2(0.0145, 0.012), V2(0.0125, 0.014)], segments: 18, material: f),
                    Xform(translation: V3(0, 0.195, 0)), to: "spout", lods: l...l)
        }
        // Spray head: docks at the spout end, pulls straight down.
        let tip = tipLocal
        rig.part("head", parent: "spout", pivot: tip + V3(0, 0.065, 0), joint: .slide(axis: V3(0, -1, 0), 0...0.2, duration: 0.5))
        for l in 0..<2 {
            let seg = l == 0 ? 22 : 12
            rig.add(Prim.lathe([V2(0.001, 0), V2(0.017, 0), V2(0.0195, 0.004), V2(0.02, 0.02), V2(0.017, 0.05), V2(0.0135, 0.062), V2(0.0135, 0.066), V2(0.001, 0.066)],
                               segments: seg, seamTile: 0.04, material: handled), Xform(translation: tip), to: "head", lods: l...l)
            // Aerator face: black rubber nozzles ring and chrome center.
            rig.add(Prim.lathe([V2(0.015, 0.0), V2(0.009, -0.0008), V2(0.001, -0.0008)], segments: seg, material: "rubber.silicone:2A2A2A"), Xform(translation: tip), to: "head", lods: l...l)
            rig.add(Prim.lathe([V2(0.007, -0.0006), V2(0.001, -0.0012)], segments: 12, material: "metal.chrome"), Xform(translation: tip), to: "head", lods: l...l)
        }
        rig.add(Prim.roundedBox(V3(0.012, 0.018, 0.006), radius: 0.003, bevelSegments: 2, material: "plastic.black"),
                Xform(translation: tip + V3(0, 0.03, 0.019)), to: "head", lods: 0...0)
        // Water stream from the aerator down into the sink, linked to the lever.
        rig.part("stream", parent: "head", pivot: tip, joint: .fixed, options: 2)
        let drop = streamDrop + tip.y
        let streamPath = (0...6).map { i in tip + V3(0, -0.001 - drop * Float(i) / 6, 0) }
        let streamR = (0...6).map { i in 0.0085 - 0.0025 * Float(i) / 6 }
        rig.add(Prim.tube(streamPath, radii: streamR, sides: 14, seamTile: 0.03, material: "water.stream"), to: "stream", option: 1)
        // Hose above the pulled head: lengths step with the pull (each option hides inside the spout end).
        let hoseSteps: [Float] = [0.02, 0.07, 0.12, 0.17]
        rig.part("hose", parent: "head", pivot: tip + V3(0, 0.066, 0), joint: .fixed, options: hoseSteps.count + 1)
        for (k, t) in hoseSteps.enumerated() {
            let top = tip + V3(0, 0.066 + t + 0.03, 0)
            rig.add(Prim.tube([tip + V3(0, 0.06, 0), top], radii: [0.0055, 0.0055], sides: 10, seamTile: 0.02, material: "rubber.silicone:262626", capEnd: false),
                    to: "hose", option: k + 1)
        }
        rig.optionLinks = [RigOptionLink(part: "stream", joint: "lever", thresholds: [10]),
                           RigOptionLink(part: "hose", joint: "head", thresholds: hoseSteps)]
        KitchenFit.shift(&rig, by: Self.deckHole)
        groundAO(&rig, height: 0.02, floor: 0.7)
        rig.states = [RigState("off"), RigState("on", ["lever": 45], options: ["stream": 1]), RigState("swung-left", ["spout": 60]),
                      RigState("pulled-out", ["head": 0.15], options: ["hose": 3])]
        return rig
    }
}
