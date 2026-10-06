import simd
import Foundation

/// 4 ft linkable LED shop light (1219 x 70 x 45 mm): white powder-coated steel channel housing (sawdust
/// settled on its top faces) with
/// pressed ribs, frosted lit diffuser lens below, white end caps (one with the linking outlet, one with
/// the cord grommet and pull-chain switch), two V hanger clips, two jack chains on S-hooks to ceiling screw
/// eyes, a brass bead pull chain with a knob, and the power cord running up beside one chain to its plug.
///
/// Frame: base at y = 0 is the bottom of the pull-chain knob (the lowest point); the diffuser bottom sits at
/// `housingY`. Centered on X/Z, long axis along X. Chains hang straight up; the ceiling attachment (top of
/// the screw-eye shanks) is at `ceilingY`. To hang it from a ceiling at height c, place the asset at
/// y = c - ceilingY.
public struct ShopLight: RealAsset {
    public static let id = "shop-light"
    public static let summary = "4 ft linkable LED shop light: white steel housing with frosted diffuser, hung from two chains with S-hooks, pull chain switch and power cord."
    public static let tags = ["prop", "workshop", "light", "metal", "plastic"]
    public static let budget = 10_500
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 25, elevation: 14, distance: 1.05, studio: true)

    /// Housing length, width and height (m).
    public var length: Float = 1.219
    public var width: Float = 0.07
    public var housingHeight: Float = 0.045
    /// Chain length between the S-hooks (m).
    public var chainLength: Float = 0.45
    /// Hanger positions from the centre (m, each side).
    public var hangerOffset: Float = 0.42
    /// Pull chain length below the switch (m).
    public var pullChainLength: Float = 0.16
    /// Diffuser lit (emissive) or off.
    public var lit = true
    /// Housing finish.
    public var housing: MaterialKey = "metal.shop-light-white"
    public init() {}

    /// Top of the lower S-hook seat on the hanger clip, above the diffuser bottom (m).
    var hangerTop: Float { housingHeight + 0.016 }
    /// Height of the diffuser bottom above the base (m).
    public var housingY: Float { pullChainLength + 0.013 }
    /// Height of the ceiling attachment points (top of the screw-eye shanks) above the base (m).
    public var ceilingY: Float { housingY + hangerTop + 0.037 + chainLength + 0.034 + 0.0301 }
    /// Ceiling height relative to the diffuser bottom (m).
    var ceilingLocal: Float { ceilingY - housingY }
    /// Ceiling attachment points (asset space).
    public var ceilingPoints: [V3] { [V3(-hangerOffset, ceilingY, 0), V3(hangerOffset, ceilingY, 0)] }

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [6])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length, W = width, H = housingHeight
        let capW: Float = 0.014
        let bodyL = L - 2 * capW
        let steel: MaterialKey = "metal.galvanized", white: MaterialKey = "plastic.white"
        let lens: MaterialKey = lit ? "emissive.panel" : "plastic.diffuser"
        let along = simd_quatf(degrees: 90, axis: .up)   // extrude depth (Z) -> X

        // MARK: housing: shallow channel with rounded shoulders, pressed rib on top
        let lensH: Float = 0.013
        let prof = Shape2D.rounded([V2(-W / 2, lensH - 0.001), V2(W / 2, lensH - 0.001), V2(W / 2, lensH + 0.012), V2(W * 0.38, H), V2(-W * 0.38, H), V2(-W / 2, lensH + 0.012)],
                                   radius: 0.006, segments: detail ? 3 : 1)
        m.add(Prim.extrude(prof, depth: bodyL, bevel: 0.0015, bevelSegments: 1, material: housing), Xform(translation: .zero, rotation: along))
        m.add(Prim.extrude(Shape2D.roundedRect(W * 0.32, 0.006, radius: 0.0028, segments: detail ? 2 : 1), depth: bodyL - 0.12, bevel: 0.002, bevelSegments: 1, material: housing),
              Xform(translation: V3(0, H + 0.0015, 0), rotation: along))
        // Frosted diffuser lens: flattened half-ellipse below the channel.
        var lensOutline: [V2] = []
        let ln = detail ? 14 : 6
        for k in 0...ln {
            let a = Float.pi + Float(k) / Float(ln) * .pi
            lensOutline.append(V2(cos(a) * (W / 2 - 0.004), lensH + sin(a) * lensH))
        }
        m.add(Prim.extrude(lensOutline, depth: bodyL - 0.002, bevel: 0.001, bevelSegments: 1, material: lens), Xform(translation: V3(0, 0.0005, 0), rotation: along))
        // Lens retaining lips along both edges.
        for sz: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(bodyL, 0.004, 0.004), radius: 0.0012, bevelSegments: 1, material: housing), Xform(translation: V3(0, lensH, sz * (W / 2 - 0.002))))
        }
        // End caps.
        for sx: Float in [-1, 1] {
            let cx = sx * (L / 2 - capW / 2)
            m.add(Prim.extrude(Shape2D.offset(prof, 0.0015), depth: capW, bevel: 0.003, bevelSegments: detail ? 2 : 1, material: white), Xform(translation: V3(cx, 0, 0), rotation: along))
            var capLens = lensOutline
            capLens = capLens.map { V2($0.x * 1.03, $0.y) }
            m.add(Prim.extrude(capLens, depth: capW, bevel: 0.002, bevelSegments: 1, material: white), Xform(translation: V3(cx, 0.0005, 0), rotation: along))
            if detail {
                if sx > 0 {
                    // Linking outlet: recessed receptacle with three contacts, captive dust plug beside it.
                    m.add(Prim.roundedBox(V3(0.002, 0.018, 0.026), radius: 0.002, bevelSegments: 1, material: "plastic.matte:2A2A2C"), Xform(translation: V3(L / 2 + 0.0008, H * 0.55, 0)))
                    for dz: Float in [-0.007, 0, 0.007] {
                        m.add(cuboid(V3(0.0012, 0.006, 0.0018), material: "metal.brass"), Xform(translation: V3(L / 2 + 0.0016, H * 0.55, dz)))
                    }
                } else {
                    m.add(Prim.cylinder(radius: 0.006, height: 0.006, bevel: 0.0015, segments: 12, bevelSegments: 1, material: "plastic.matte:2A2A2C"),
                          Xform(translation: V3(-L / 2, H * 0.6, 0.012), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
                }
            }
        }
        // Mounting screws on the top channel.
        if detail {
            for x: Float in [-0.55, -0.2, 0.2, 0.55] {
                rivet(&m, at: V3(x * L / 1.219, H + 0.0035, 0), normal: .up, radius: 0.0035, segments: 8, material: steel)
            }
        }

        // MARK: hangers, S-hooks, chains, screw eyes
        let wire: Float = 0.0016
        func sHook(at top: V3, size: Float, r: Float) {
            // Two opposed semicircles in the YZ plane (through the tab hole): upper bend opens one way, lower the other.
            var path: [V3] = []
            let n = detail ? 8 : 4
            for k in 0...n { let a = Float(k) / Float(n) * .pi * 1.15 - 0.08; path.append(top + V3(0, -size + cos(a) * size, -sin(a) * size)) }
            for k in 1...n { let a = Float(k) / Float(n) * .pi * 1.15 - 0.08; path.append(top + V3(0, -3 * size + cos(a) * size, sin(a) * size)) }
            m.add(Prim.tube(path, radii: path.map { _ in r }, sides: detail ? 6 : 4, seamTile: 0.02, material: steel))
        }
        func chainLinks(from a: V3, to b: V3) {
            let pitch: Float = 0.011
            let count = max(2, Int(simd_distance(a, b) / pitch))
            let link = Prim.torus(major: 0.0042, minor: 0.0009, segments: detail ? 7 : 5, sides: 3, material: steel)
            for k in 0..<count {
                let t = (Float(k) + 0.5) / Float(count)
                let p = a + (b - a) * t
                let twist = Float(k % 2) * 90 + rng.float(-8...8)
                m.add(link, Xform(translation: p, rotation: simd_quatf(degrees: twist, axis: .up) * simd_quatf(degrees: 90, axis: V3(1, 0, 0)), scale: V3(1, 1, 1.75)))
            }
        }
        for sx: Float in [-1, 1] {
            let x = sx * hangerOffset
            // V hanger clip: folded steel tab with a hole, standing on the channel top.
            let tab = Shape2D.rounded([V2(-0.012, 0), V2(0.012, 0), V2(0.006, 0.022), V2(-0.006, 0.022)], radius: 0.003, segments: 2)
            m.add(Prim.extrude(tab, depth: 0.0012, bevel: 0.0004, bevelSegments: 1, material: steel), Xform(translation: V3(x, H + 0.001, 0)))
            m.add(Prim.roundedBox(V3(0.03, 0.0012, 0.03), radius: 0.0005, bevelSegments: 1, material: steel), Xform(translation: V3(x, H + 0.0035, 0)))
            m.add(Prim.lathe([V2(0.0025, -0.0007), V2(0.0035, -0.0007), V2(0.0035, 0.0007), V2(0.0025, 0.0007)], segments: 10, seamTile: 0.02, material: "plastic.matte:1E1E1E"),
                  Xform(translation: V3(x, H + 0.016, 0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            // Lower S-hook through the tab hole, chain, upper S-hook, screw eye.
            let hookTop0 = V3(x, hangerTop + 0.034, 0)
            sHook(at: hookTop0, size: 0.0085, r: wire * 1.1)
            let c0 = hookTop0 + V3(0, 0.003, 0), c1 = c0 + V3(0, chainLength, 0)
            chainLinks(from: c0, to: c1)
            let hookTop1 = c1 + V3(0, 0.034, 0)
            sHook(at: hookTop1, size: 0.0085, r: wire * 1.1)
            // Screw eye: ring and threaded shank up to the ceiling plane.
            m.add(Prim.torus(major: 0.006, minor: 0.0014, segments: detail ? 12 : 6, sides: 5, material: steel),
                  Xform(translation: hookTop1 + V3(0, 0.006, 0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            m.add(Prim.lathe([V2(0, 0), V2(0.0018, 0.001), V2(0.002, 0.018), V2(0.0026, 0.018), V2(0.0026, 0.0185), V2(0, 0.0185)], segments: 8, seamTile: 0.02, material: steel),
                  Xform(translation: hookTop1 + V3(0, 0.0116, 0)))
        }

        // MARK: pull chain switch (brass bead chain and knob) at the -X end
        let pc = V3(-L / 2 + 0.06, lensH + 0.002, W / 2 - 0.004)
        m.add(Prim.cylinder(radius: 0.0045, height: 0.006, bevel: 0.0015, segments: 10, bevelSegments: 1, material: white), Xform(translation: pc + V3(0, -0.004, 0.002)))
        let chainLen: Float = pullChainLength
        let sway = rng.float(-0.01...0.01)
        let bead = catmull([pc + V3(0, -0.004, 0.002), pc + V3(sway * 0.4, -chainLen * 0.5, 0.004), pc + V3(sway, -chainLen, 0.004)], per: 3)
        let beadPath = resample(bead, spacing: detail ? 0.0018 : 0.02) + [bead.last!]
        let beadR = beadPath.indices.map { detail ? ($0 % 2 == 0 ? Float(0.0013) : 0.0005) : 0.0009 }
        m.add(Prim.tube(beadPath, radii: beadR, sides: detail ? 5 : 3, seamTile: 0.01, material: "metal.brass", capEnd: false))
        m.add(Prim.lathe([V2(0, 0), V2(0.004, 0.002), V2(0.0055, 0.01), V2(0.004, 0.02), V2(0.0015, 0.024), V2(0, 0.025)], segments: 12, seamTile: 0.03, material: "metal.brass"),
              Xform(translation: bead.last! + V3(0, -0.024, 0)))

        // MARK: power cord: grommet at the -X end cap, up beside the left chain to a plug at the ceiling
        let cordR: Float = 0.0032
        let x0 = -hangerOffset
        let cp = catmull([V3(-L / 2 - 0.002, H * 0.6, 0.012), V3(-L / 2 - 0.03, H * 0.7, 0.016), V3(-L / 2 + 0.02, H + 0.08, 0.02),
                          V3(x0 - 0.04, hangerTop + 0.1, 0.016), V3(x0 - 0.014, hangerTop + 0.22, 0.012), V3(x0 - 0.012, ceilingLocal - 0.12, 0.012),
                          V3(x0 - 0.03, ceilingLocal - 0.05, 0.02), V3(x0 - 0.07, ceilingLocal - 0.03, 0.022)], per: detail ? 6 : 3)
        m.add(Prim.tube(cp, radii: cp.map { _ in cordR }, sides: 6, seamTile: 0.02, material: "plastic.matte:F0F0EE", capEnd: false))
        let plugAt = cp.last!
        m.add(Prim.roundedBox(V3(0.03, 0.024, 0.02), radius: 0.005, bevelSegments: 1, material: "plastic.matte:F0F0EE"), Xform(translation: plugAt + V3(-0.014, 0, 0)))
        if detail {
            for dz: Float in [-0.0063, 0.0063] {
                m.add(cuboid(V3(0.016, 0.0064, 0.0016), material: "metal.brass"), Xform(translation: plugAt + V3(-0.036, 0.002, dz)))
            }
        }
        return m.transformed(Xform(translation: V3(0, housingY, 0)))
    }
}
