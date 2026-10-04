import simd

/// Muscles, tendons, retinacula, veins, arteries, nerves and the soft-tissue envelope of the hand,
/// attached to the tracked bone frames and rebuilt each frame. Origins, insertions and courses follow
/// standard descriptions (Gray's Anatomy, hand chapter): thenar and hypothenar groups, adductor
/// pollicis, four dorsal and three palmar interossei, four lumbricals, extrinsic flexor and extensor
/// tendons through the carpal tunnel and the six dorsal compartments, the dorsal venous network
/// draining to the cephalic and basilic veins, the superficial and deep palmar arches, and the median
/// and ulnar nerves.
///
/// Coordinates in the helpers are radial-positive x and dorsal z, meters at reference hand size.
public struct HandSoftTissue {
    public struct Layers: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let muscles = Layers(rawValue: 1)
        public static let tendons = Layers(rawValue: 2)
        public static let veins = Layers(rawValue: 4)
        public static let arteries = Layers(rawValue: 8)
        public static let nerves = Layers(rawValue: 16)
        public static let envelope = Layers(rawValue: 32)
        public static let anatomy: Layers = [.muscles, .tendons, .veins, .arteries, .nerves]
    }

    public struct Keys: Sendable {
        public var muscle: MaterialKey = "anatomy.muscle"
        public var tendon: MaterialKey = "anatomy.tendon"
        public var vein: MaterialKey = "anatomy.vein"
        public var artery: MaterialKey = "anatomy.artery"
        public var nerve: MaterialKey = "anatomy.nerve"
        public var envelope: MaterialKey = "anatomy.envelope"
        public init() {}
        /// See-through variants for layered views.
        public static var glass: Keys {
            var k = Keys()
            k.muscle += "-glass"; k.tendon += "-glass"; k.vein += "-glass"; k.artery += "-glass"; k.nerve += "-glass"
            return k
        }
    }

    public var keys: Keys
    /// 1 = full detail; lower values cut sides and samples (performance tiers).
    public var detail: Float = 1

    public init(keys: Keys = Keys(), detail: Float = 1) { self.keys = keys; self.detail = detail }

    public func strands(_ f: HandFrames, layers: Layers) -> [Strand] {
        var out: [Strand] = []
        let ctx = Ctx(f: f, detail: detail)
        if layers.contains(.tendons) { out += ctx.tendons(keys.tendon) }
        if layers.contains(.muscles) { out += ctx.muscles(keys.muscle) }
        if layers.contains(.veins) { out += ctx.veins(keys.vein) }
        if layers.contains(.arteries) { out += ctx.arteries(keys.artery) }
        if layers.contains(.nerves) { out += ctx.nerves(keys.nerve) }
        if layers.contains(.envelope) { out += ctx.envelope(keys.envelope) }
        return out
    }

    /// One model, one surface per material.
    public func build(_ f: HandFrames, layers: Layers) -> Model {
        var bySurface: [MaterialKey: Surface] = [:]
        var order: [MaterialKey] = []
        for st in strands(f, layers: layers) {
            if bySurface[st.material] == nil { bySurface[st.material] = Surface(material: st.material); order.append(st.material) }
            bySurface[st.material]!.append(strand: st, scale: f.scale)
        }
        return Model(name: "hand-soft-tissue", surfaces: order.compactMap { bySurface[$0] })
    }
}

private struct Ctx {
    let f: HandFrames
    let detail: Float

    func n(_ v: Int) -> Int { max(4, Int(Float(v) * detail)) }

    // Bone-relative point: digit, segment, t along the tracked length, x radial, z dorsal.
    func P(_ d: Digit, _ s: Int, _ t: Float, _ x: Float = 0, _ z: Float = 0) -> V3 { f.point(d, s, t: t, x: x, z: z) }
    func W(_ x: Float, _ y: Float, _ z: Float) -> V3 { f.palmPoint(V3(x, y, z)) }
    func A(_ x: Float, _ y: Float, _ z: Float) -> V3 { f.forearmPoint(V3(x, y, z)) }
    // Frame axes in pose space, radial-positive x.
    func X(_ d: Digit, _ s: Int) -> V3 { f.bone(d, s).x * f.radialSign }
    func Z(_ d: Digit, _ s: Int) -> V3 { f.bone(d, s).z }
    var palmX: V3 { f.palm.x * f.radialSign }
    var palmY: V3 { f.palm.y }
    var palmZ: V3 { f.palm.z }
    var forearmZ: V3 { f.forearm.z }

    static let fingers: [Digit] = [.index, .middle, .ring, .little]

    func headD(_ d: Digit, _ s: Int) -> Float { HandMorphometry.dims[d.rawValue][s].head.d }
    func shaftD(_ d: Digit, _ s: Int) -> Float { HandMorphometry.dims[d.rawValue][s].shaft.d }
    func shaftW(_ d: Digit, _ s: Int) -> Float { HandMorphometry.dims[d.rawValue][s].shaft.w }

    // MARK: tendons and retinacula

    func tendons(_ key: MaterialKey) -> [Strand] {
        var out: [Strand] = []
        let wristX: [Digit: Float] = [.index: 0.0055, .middle: 0.0012, .ring: -0.0035, .little: -0.0085]
        let palmarX: [Digit: Float] = [.index: 0.0055, .middle: 0.0018, .ring: -0.003, .little: -0.0075]
        for d in Ctx.fingers {
            let hd = headD(d, 0)
            // Extensor digitorum: fourth compartment, fanning over the metacarpals, the hood over the
            // knuckle, central slip and lateral bands to the distal phalanx.
            let ed = [A(wristX[d]! * 0.7, -0.075, 0.0105), W(wristX[d]!, -0.014, 0.0118), P(d, 0, 0.3, 0, 0.0074), P(d, 0, 0.72, 0, 0.0071),
                      P(d, 0, 1.0, 0, hd / 2 + 0.0014), P(d, 1, 0.5, 0, shaftD(d, 1) / 2 + 0.0011), P(d, 1, 1.0, 0, 0.0052),
                      P(d, 2, 0.5, 0, shaftD(d, 2) / 2 + 0.0009), P(d, 2, 1.0, 0, 0.0042), P(d, 3, 0.14, 0, 0.0033)]
            let edSide = [forearmX, palmX, X(d, 0), X(d, 0), X(d, 0), X(d, 1), X(d, 1), X(d, 2), X(d, 2), X(d, 3)]
            var s = Strand(key, ed, sideHints: edSide, sides: n(10), samples: n(40), profile: Strand.stations([
                (0, 0.0017, 0.0011), (0.25, 0.0018, 0.0009), (0.42, 0.0019, 0.0008), (0.5, 0.0042, 0.0006), (0.6, 0.0034, 0.0006),
                (0.8, 0.0028, 0.0005), (1, 0.0021, 0.0005),
            ]))
            s.seed = UInt32(d.rawValue)
            out.append(s)
            // Flexor digitorum profundus: carpal tunnel, deep in the palm, through the sheath to the
            // distal phalanx base.
            let fdp = [A(palmarX[d]! * 0.6, -0.08, -0.0115), W(palmarX[d]! * 0.8, 0.002, -0.0128), P(d, 0, 0.55, 0, -0.0088),
                       P(d, 0, 0.92, 0, -hd / 2 - 0.0021), P(d, 1, 0.5, 0, -shaftD(d, 1) / 2 - 0.0019), P(d, 1, 1.0, 0, -0.0058),
                       P(d, 2, 0.5, 0, -shaftD(d, 2) / 2 - 0.0015), P(d, 2, 1.0, 0, -0.0048), P(d, 3, 0.16, 0, -0.0031)]
            out.append(Strand(key, fdp, sides: n(10), samples: n(36), profile: Strand.stations([(0, 0.0024, 0.0022), (0.5, 0.0021, 0.0019), (0.8, 0.0017, 0.0015), (1, 0.0014, 0.0012)])))
            // Flexor digitorum superficialis: palmar to FDP, splits over the proximal phalanx (Camper's
            // chiasm) and inserts on the sides of the middle phalanx.
            let fds = [A(palmarX[d]! * 0.6 + 0.001, -0.08, -0.0145), W(palmarX[d]! * 0.8, 0.002, -0.0152), P(d, 0, 0.55, 0, -0.0112),
                       P(d, 0, 0.92, 0, -hd / 2 - 0.0042), P(d, 1, 0.45, 0, -shaftD(d, 1) / 2 - 0.0036)]
            out.append(Strand(key, fds, sides: n(10), samples: n(24), profile: Strand.stations([(0, 0.0026, 0.0022), (0.7, 0.0024, 0.0018), (1, 0.0026, 0.0012)])))
            for sx: Float in [-1, 1] {
                let slip = [P(d, 1, 0.42, 0, -shaftD(d, 1) / 2 - 0.0036), P(d, 1, 0.75, sx * 0.0032, -shaftD(d, 1) / 2 - 0.0022),
                            P(d, 2, 0.08, sx * 0.0036, -0.0042), P(d, 2, 0.4, sx * 0.0034, -0.0031)]
                out.append(Strand(key, slip, sides: n(8), samples: n(12), profile: Strand.constant(0.0012, 0.0008)))
            }
            // Annular pulleys A2 (proximal phalanx) and A4 (middle phalanx) over the flexors.
            for (seg, t, w) in [(1, 0.45, 0.0075), (2, 0.5, 0.0055)] as [(Int, Float, Float)] {
                let sd = shaftD(d, seg), sw = shaftW(d, seg)
                let arc = (0...6).map { i -> V3 in
                    let a = Float.pi * (1.05 + 0.9 * Float(i) / 6)
                    return P(d, seg, t, cos(a) * (sw / 2 + 0.0016), sin(a) * (sd / 2 + 0.0034) - 0.0012)
                }
                var pul = Strand(key, arc, sideHints: Array(repeating: f.bone(d, seg).y, count: arc.count), sides: n(8), samples: n(14),
                                 profile: Strand.constant(w / 2, 0.0005))
                pul.capStart = true
                out.append(pul)
            }
        }
        // Extensor indicis and extensor digiti minimi beside their ED tendons.
        out.append(Strand(key, [A(0.002, -0.07, 0.0098), W(0.0045, -0.014, 0.0112), P(.index, 0, 0.35, -0.0022, 0.0071), P(.index, 0, 0.9, -0.0018, 0.0082)],
                          sideHints: [forearmX, palmX, X(.index, 0), X(.index, 0)], sides: n(8), samples: n(20), profile: Strand.constant(0.0019, 0.0009)))
        out.append(Strand(key, [A(-0.012, -0.07, 0.0085), W(-0.0115, -0.015, 0.0108), P(.little, 0, 0.35, -0.0024, 0.0068), P(.little, 0, 0.9, -0.0018, 0.0078)],
                          sideHints: [forearmX, palmX, X(.little, 0), X(.little, 0)], sides: n(8), samples: n(20), profile: Strand.constant(0.0018, 0.0009)))
        // Juncturae tendinum between the ED tendons distally.
        for (a, b) in [(Digit.ring, Digit.middle), (.ring, .little)] {
            out.append(Strand(key, [P(a, 0, 0.7, 0, 0.0074), lerp(P(a, 0, 0.78, 0, 0.0076), P(b, 0, 0.85, 0, 0.0076), 0.5), P(b, 0, 0.88, 0, 0.0075)],
                              sideHints: [palmY, palmY, palmY], sides: n(6), samples: n(10), profile: Strand.constant(0.0016, 0.0005)))
        }
        // Thumb: EPL around Lister's tubercle, EPB and APL along the radial border (anatomical
        // snuffbox between them), FPL through the carpal tunnel.
        let t0 = HandMorphometry.dims[0]
        out.append(Strand(key, [A(0.004, -0.075, 0.0108), W(0.0085, -0.022, 0.0128), W(0.014, -0.004, 0.0105), P(.thumb, 0, 0.35, -0.002, t0[0].shaft.d / 2 + 0.0014),
                                P(.thumb, 0, 1.0, 0, t0[0].head.d / 2 + 0.0013), P(.thumb, 1, 0.5, 0, t0[1].shaft.d / 2 + 0.001), P(.thumb, 2, 0.14, 0, 0.0034)],
                          sideHints: [forearmX, palmX, palmX, X(.thumb, 0), X(.thumb, 0), X(.thumb, 1), X(.thumb, 2)],
                          sides: n(10), samples: n(32), profile: Strand.stations([(0, 0.0021, 0.0013), (0.6, 0.0022, 0.0009), (0.8, 0.0034, 0.0007), (1, 0.0026, 0.0006)])))
        out.append(Strand(key, [A(0.017, -0.065, 0.0055), W(0.0255, -0.012, 0.0032), P(.thumb, 0, 0.45, 0.0032, 0.0052), P(.thumb, 1, 0.1, 0, 0.0042)],
                          sideHints: [forearmZ, palmZ, Z(.thumb, 0), Z(.thumb, 1)], sides: n(8), samples: n(20), profile: Strand.constant(0.0017, 0.0011)))
        out.append(Strand(key, [A(0.0195, -0.065, 0.0012), W(0.0285, -0.014, 0.0002), P(.thumb, 0, 0.04, 0.0078, 0.0004)],
                          sideHints: [forearmZ, palmZ, Z(.thumb, 0)], sides: n(8), samples: n(16), profile: Strand.constant(0.0021, 0.0014)))
        out.append(Strand(key, [A(0.011, -0.08, -0.0105), W(0.0095, 0.002, -0.0128), P(.thumb, 0, 0.5, -0.0005, -0.0066), P(.thumb, 0, 1.0, 0, -t0[0].head.d / 2 - 0.0026),
                                P(.thumb, 1, 0.5, 0, -t0[1].shaft.d / 2 - 0.0019), P(.thumb, 2, 0.15, 0, -0.0031)],
                          sides: n(10), samples: n(28), profile: Strand.stations([(0, 0.0025, 0.0022), (0.7, 0.0019, 0.0016), (1, 0.0015, 0.0012)])))
        // Wrist movers: ECRL, ECRB, ECU dorsally; FCR, FCU, palmaris longus palmarly.
        out.append(Strand(key, [A(0.0125, -0.075, 0.0095), W(0.0135, -0.012, 0.0102), P(.index, 0, 0.05, 0.002, 0.0074)],
                          sideHints: [forearmX, palmX, X(.index, 0)], sides: n(8), samples: n(16), profile: Strand.constant(0.0026, 0.0011)))
        out.append(Strand(key, [A(0.008, -0.075, 0.0105), W(0.0075, -0.012, 0.0112), P(.middle, 0, 0.05, 0.003, 0.0086)],
                          sideHints: [forearmX, palmX, X(.middle, 0)], sides: n(8), samples: n(16), profile: Strand.constant(0.0027, 0.0011)))
        out.append(Strand(key, [A(-0.0175, -0.075, 0.0068), W(-0.0205, -0.017, 0.0055), P(.little, 0, 0.03, -0.0068, 0.0018)],
                          sideHints: [forearmZ, palmZ, Z(.little, 0)], sides: n(8), samples: n(16), profile: Strand.constant(0.0024, 0.0016)))
        out.append(Strand(key, [A(0.0125, -0.075, -0.0108), W(0.0165, 0.005, -0.0102), P(.index, 0, 0.04, 0.0005, -0.0062)],
                          sides: n(8), samples: n(16), profile: Strand.constant(0.0022, 0.0018)))
        out.append(Strand(key, [A(-0.0165, -0.075, -0.0098), W(-0.0142, -0.004, -0.0142)],
                          sides: n(8), samples: n(10), profile: Strand.constant(0.0028, 0.0022)))
        out.append(Strand(key, [A(0.002, -0.08, -0.0142), W(0.001, -0.004, -0.0178), W(0.001, 0.006, -0.0176)],
                          sideHints: [forearmX, palmX, palmX], sides: n(8), samples: n(12), profile: Strand.constant(0.0028, 0.0006)))
        // Palmaris longus fanning into the palmar aponeurosis slips.
        for d in Ctx.fingers {
            out.append(Strand(key, [W(0.001, 0.006, -0.0176), P(d, 0, 0.55, 0, -0.0138), P(d, 0, 0.9, 0, -hdOffset(d))],
                              sideHints: [palmX, X(d, 0), X(d, 0)], sides: n(6), samples: n(12), profile: Strand.stations([(0, 0.0016, 0.0004), (1, 0.0032, 0.0004)])))
        }
        // Flexor retinaculum (transverse carpal ligament) roofing the carpal tunnel, and the extensor
        // retinaculum across the dorsal compartments.
        let flexRet = [W(0.0215, 0.006, -0.0105), W(0.012, 0.007, -0.0168), W(0.0, 0.008, -0.019), W(-0.011, 0.009, -0.0172), W(-0.0175, 0.01, -0.0135)]
        out.append(Strand(key, flexRet, sideHints: Array(repeating: palmY, count: flexRet.count), sides: n(10), samples: n(16), profile: Strand.constant(0.0105, 0.0011)))
        let extRet = [A(0.0215, -0.03, 0.0052), A(0.012, -0.03, 0.0128), A(0.0, -0.03, 0.0145), A(-0.012, -0.03, 0.0128), A(-0.021, -0.03, 0.0068)]
        out.append(Strand(key, extRet, sideHints: Array(repeating: f.forearm.y, count: extRet.count), sides: n(10), samples: n(16), profile: Strand.constant(0.0068, 0.0005)))
        return out
    }

    var forearmX: V3 { f.forearm.x * f.radialSign }
    func hdOffset(_ d: Digit) -> Float { headD(d, 0) / 2 + 0.0058 }

    // MARK: muscles

    func muscles(_ key: MaterialKey) -> [Strand] {
        var out: [Strand] = []
        func belly(_ pts: [V3], _ rx: Float, _ ry: Float, side: [V3]? = nil, tendon: Float = 0.0009, a: Float = 0.04, b: Float = 0.92, power: Float = 0.7, seed: UInt32 = 0) {
            var s = Strand(key, pts, sideHints: side, sides: n(16), samples: n(22), profile: Strand.belly(rx, ry, tendon: tendon, a: a, b: b, power: power))
            s.seed = seed
            out.append(s)
        }
        let th = HandMorphometry.dims[0]
        // Thenar eminence: abductor pollicis brevis (superficial, radial), flexor pollicis brevis (medial),
        // opponens pollicis (deep, along the first metacarpal).
        belly([W(0.0175, 0.003, -0.0172), lerp(W(0.022, 0.016, -0.019), P(.thumb, 0, 0.55, 0.004, -0.009), 0.5),
               P(.thumb, 0, 0.92, 0.0062, -0.0042), P(.thumb, 1, 0.08, 0.0062, -0.0006)], 0.0078, 0.0058,
              side: [palmX, X(.thumb, 0), X(.thumb, 0), X(.thumb, 1)], tendon: 0.0012, b: 0.88, seed: 1)
        belly([W(0.0105, 0.009, -0.0178), lerp(W(0.015, 0.02, -0.019), P(.thumb, 0, 0.6, -0.001, -0.0098), 0.5),
               P(.thumb, 0, 0.95, 0.0005, -th[0].head.d / 2 - 0.0028), P(.thumb, 1, 0.06, 0.0018, -0.0042)], 0.0068, 0.0052, tendon: 0.0011, seed: 2)
        belly([W(0.0165, 0.0095, -0.0128), P(.thumb, 0, 0.35, 0.0046, -0.0052), P(.thumb, 0, 0.88, 0.0052, -0.0036)], 0.0058, 0.0044,
              side: [palmX, X(.thumb, 0), X(.thumb, 0)], tendon: 0.0022, a: 0, b: 1.05, seed: 3)
        // Adductor pollicis: oblique head from the capitate and MC2-3 bases, transverse head fanning from
        // the third metacarpal shaft, converging on the ulnar base of the thumb proximal phalanx.
        let addIns = P(.thumb, 1, 0.06, -0.006, -0.0028)
        belly([W(0.003, 0.021, -0.0118), lerp(W(0.006, 0.04, -0.0135), addIns, 0.45), addIns], 0.0068, 0.0042, side: [palmY, palmY, palmY], tendon: 0.0012, seed: 4)
        for t: Float in [0.5, 0.68, 0.86] {
            let o = P(.middle, 0, t, 0, -0.0078)
            belly([o, lerp(o, addIns, 0.5) - palmZ * 0.002, addIns], 0.0052, 0.0028, side: [palmY, palmY, palmY], tendon: 0.001, a: 0, b: 0.95, power: 0.55, seed: 5)
        }
        // Hypothenar eminence: abductor digiti minimi (ulnar border), flexor digiti minimi brevis, opponens.
        let lt = HandMorphometry.dims[4]
        belly([W(-0.0158, 0.003, -0.0118), lerp(W(-0.0245, 0.03, -0.0118), P(.little, 0, 0.6, -0.008, -0.004), 0.5),
               P(.little, 0, 0.95, -0.0065, -0.0022), P(.little, 1, 0.06, -0.0062, -0.0006)], 0.0072, 0.0058,
              side: [palmZ, Z(.little, 0), Z(.little, 0), Z(.little, 1)], tendon: 0.0011, seed: 6)
        belly([W(-0.0148, 0.0172, -0.0172), P(.little, 0, 0.55, -0.0035, -0.0092), P(.little, 0, 0.95, -0.003, -lt[0].head.d / 2 - 0.0022),
               P(.little, 1, 0.05, -0.003, -0.0038)], 0.0052, 0.0042, tendon: 0.001, seed: 7)
        belly([W(-0.0132, 0.0162, -0.0138), P(.little, 0, 0.4, -0.005, -0.0045), P(.little, 0, 0.85, -0.0048, -0.0028)], 0.0048, 0.0036,
              side: [palmZ, Z(.little, 0), Z(.little, 0)], tendon: 0.002, a: 0, b: 1.05, seed: 8)
        // Dorsal interossei: bipennate between the metacarpals. First dorsal interosseous fills the web.
        let di1o = lerp(P(.thumb, 0, 0.3, -0.0042, 0.0005), P(.index, 0, 0.22, 0.0046, 0.0005), 0.5)
        let di1m = lerp(P(.thumb, 0, 0.88, -0.005, 0.0005), P(.index, 0, 0.62, 0.0055, 0.0005), 0.5)
        belly([di1o, di1m, P(.index, 0, 0.92, 0.0068, 0.0012), P(.index, 1, 0.06, 0.0064, 0.0006)], 0.0095, 0.0058,
              side: [palmZ, palmZ, X(.index, 0), X(.index, 1)], tendon: 0.0011, a: 0, b: 0.86, power: 0.6, seed: 9)
        let diPairs: [(Digit, Digit, Digit, Float)] = [(.index, .middle, .middle, 1), (.middle, .ring, .middle, -1), (.ring, .little, .ring, -1)]
        for (k, (a, b, ins, sx)) in diPairs.enumerated() {
            func mid(_ t: Float, _ z: Float) -> V3 { lerp(P(a, 0, t, -0.0045, z), P(b, 0, t, 0.0045, z), 0.5) }
            belly([mid(0.1, 0.001), mid(0.45, 0.0012), mid(0.8, 0.0012), P(ins, 0, 0.98, sx * 0.0064, 0.0014), P(ins, 1, 0.06, sx * 0.006, 0.0006)],
                  0.0034, 0.0052, side: [palmX, palmX, palmX, X(ins, 0), X(ins, 1)], tendon: 0.001, a: 0, b: 0.78, seed: UInt32(10 + k))
        }
        // Palmar interossei: unipennate from the palmar side of MC2, MC4, MC5 to the same digit.
        let pi: [(Digit, Float)] = [(.index, -1), (.ring, 1), (.little, 1)]
        for (k, (d, sx)) in pi.enumerated() {
            belly([P(d, 0, 0.2, sx * 0.0044, -0.0034), P(d, 0, 0.6, sx * 0.0052, -0.0036), P(d, 0, 0.98, sx * 0.0062, -0.0018), P(d, 1, 0.06, sx * 0.0058, 0.0002)],
                  0.0027, 0.0036, side: [X(d, 0), X(d, 0), X(d, 0), X(d, 1)], tendon: 0.0009, a: 0, b: 0.8, seed: UInt32(20 + k))
        }
        // Lumbricals: from the FDP tendons in the palm to the radial lateral bands.
        for (k, d) in Ctx.fingers.enumerated() {
            belly([P(d, 0, 0.42, 0.0016, -0.0098), P(d, 0, 0.75, 0.0042, -0.0092), P(d, 0, 1.02, 0.0064, -0.0046), P(d, 1, 0.22, 0.0058, 0.0012)],
                  0.0026, 0.0022, tendon: 0.0007, a: 0, b: 0.78, seed: UInt32(30 + k))
        }
        // Pronator quadratus over the distal radius and ulna.
        out.append(Strand(key, [A(0.0165, -0.045, -0.0072), A(0.0, -0.046, -0.0105), A(-0.0185, -0.045, -0.0062)],
                          sideHints: [f.forearm.y, f.forearm.y, f.forearm.y], sides: n(14), samples: n(14), profile: Strand.constant(0.0175, 0.0028)))
        return out
    }

    // MARK: vessels and nerves

    func veins(_ key: MaterialKey) -> [Strand] {
        var out: [Strand] = []
        func vein(_ pts: [V3], _ r0: Float, _ r1: Float, seed: UInt32) {
            var s = Strand(key, pts, sides: n(8), samples: n(max(14, pts.count * 6)), profile: Strand.stations([(0, r0 * 0.85, r0 * 0.75), (1, r1 * 0.85, r1 * 0.75)]))
            s.meander = 0.0008; s.meanderWave = 0.01; s.bulge = 0.18; s.bulgeSpacing = 0.011; s.seed = seed
            out.append(s)
        }
        let skin: Float = 0.0105
        // Dorsal digital veins along the dorsolateral finger margins, joining at the webs.
        for (k, d) in Ctx.fingers.enumerated() {
            for sx: Float in [-1, 1] {
                vein([P(d, 2, 0.55, sx * 0.0034, 0.0042), P(d, 1, 0.55, sx * 0.0041, 0.0052), P(d, 1, 0.05, sx * 0.0058, 0.0072), P(d, 0, 0.92, sx * 0.0078, 0.0088)],
                     0.0006, 0.0009, seed: UInt32(40 + k * 2 + (sx > 0 ? 1 : 0)))
            }
        }
        // Dorsal metacarpal veins in the intermetacarpal spaces up to the arch.
        var junctions: [V3] = []
        let pairs: [(Digit, Digit)] = [(.index, .middle), (.middle, .ring), (.ring, .little)]
        for (k, (a, b)) in pairs.enumerated() {
            let web = lerp(P(a, 0, 0.95, -0.006, 0.0092), P(b, 0, 0.95, 0.006, 0.0092), 0.5)
            let j = lerp(P(a, 0, 0.42, -0.004, skin), P(b, 0, 0.42, 0.004, skin), 0.5)
            junctions.append(j)
            vein([web, lerp(P(a, 0, 0.7, -0.005, skin), P(b, 0, 0.7, 0.005, skin), 0.5), j], 0.0011, 0.0015, seed: UInt32(50 + k))
        }
        // Dorsal venous arch, radial end feeding the cephalic vein, ulnar end the basilic vein.
        let radialEnd = lerp(P(.thumb, 0, 0.45, -0.002, 0.007), P(.index, 0, 0.3, 0.004, skin), 0.5)
        let ulnarEnd = P(.little, 0, 0.3, -0.0075, 0.0078)
        vein([radialEnd, junctions[0], junctions[1], junctions[2], ulnarEnd], 0.0019, 0.0019, seed: 60)
        vein([radialEnd, W(0.022, -0.004, 0.0088), W(0.025, -0.022, 0.0072), A(0.022, -0.06, 0.0062), A(0.021, -0.1, 0.0052)], 0.002, 0.0027, seed: 61)
        vein([ulnarEnd, W(-0.021, 0.002, 0.0068), W(-0.023, -0.02, 0.0052), A(-0.021, -0.06, 0.0042), A(-0.02, -0.1, 0.0032)], 0.0019, 0.0025, seed: 62)
        // Thumb dorsal veins into the cephalic origin, little-finger ulnar vein into the basilic.
        let tt = HandMorphometry.dims[0]
        vein([P(.thumb, 1, 0.6, 0.0036, tt[1].shaft.d / 2 + 0.002), P(.thumb, 0, 0.9, 0.003, tt[0].head.d / 2 + 0.003), radialEnd], 0.0007, 0.0012, seed: 63)
        vein([P(.thumb, 1, 0.6, -0.0036, tt[1].shaft.d / 2 + 0.002), P(.thumb, 0, 0.8, -0.0035, tt[0].shaft.d / 2 + 0.0035), radialEnd], 0.0007, 0.0011, seed: 64)
        vein([P(.little, 0, 0.92, -0.0075, 0.0082), P(.little, 0, 0.6, -0.0082, 0.008), ulnarEnd], 0.0009, 0.0013, seed: 65)
        // Connection from the index web to the radial end.
        vein([lerp(P(.thumb, 0, 0.98, -0.006, 0.006), P(.index, 0, 0.95, 0.006, 0.009), 0.5), P(.index, 0, 0.6, 0.0055, skin), radialEnd], 0.001, 0.0014, seed: 66)
        return out
    }

    func arteries(_ key: MaterialKey) -> [Strand] {
        var out: [Strand] = []
        func artery(_ pts: [V3], _ r0: Float, _ r1: Float, seed: UInt32) {
            var s = Strand(key, pts, sides: n(8), samples: n(max(14, pts.count * 6)), profile: Strand.stations([(0, r0, r0), (1, r1, r1)]))
            s.meander = 0.0004; s.meanderWave = 0.015; s.seed = seed
            out.append(s)
        }
        // Ulnar artery through Guyon's canal into the superficial palmar arch.
        let arch = [W(-0.0115, 0.004, -0.0158), P(.little, 0, 0.32, 0.003, -0.0128), P(.ring, 0, 0.45, 0, -0.0136),
                    P(.middle, 0, 0.5, 0, -0.0142), P(.index, 0, 0.42, -0.001, -0.0138), W(0.0145, 0.03, -0.0168)]
        artery([A(-0.012, -0.08, -0.0125), A(-0.012, -0.03, -0.0138)] + [arch[0]], 0.0015, 0.0013, seed: 70)
        artery(arch, 0.0012, 0.0008, seed: 71)
        // Radial artery: palmar at the wrist, through the anatomical snuffbox to the first web, deep arch.
        artery([A(0.0125, -0.08, -0.0118), A(0.015, -0.035, -0.0108), W(0.022, -0.008, -0.002), W(0.024, 0.0, 0.0045),
                P(.index, 0, 0.12, 0.0068, 0.0028), P(.index, 0, 0.2, 0.004, -0.0058)], 0.0015, 0.0012, seed: 72)
        artery([P(.index, 0, 0.2, 0.004, -0.0058), P(.middle, 0, 0.18, 0, -0.0066), P(.ring, 0, 0.2, 0, -0.0062), P(.little, 0, 0.25, 0.002, -0.0056)], 0.0011, 0.0008, seed: 73)
        // Common and proper palmar digital arteries.
        let archPts: [Digit: V3] = [.index: arch[4], .middle: arch[3], .ring: arch[2], .little: arch[1]]
        for (k, d) in Ctx.fingers.enumerated() {
            for sx: Float in [-1, 1] {
                artery([archPts[d]!, P(d, 0, 0.85, sx * 0.0055, -0.011), P(d, 1, 0.3, sx * 0.0045, -0.0042), P(d, 2, 0.5, sx * 0.0038, -0.003), P(d, 3, 0.5, sx * 0.0028, -0.0018)],
                       0.0007, 0.0004, seed: UInt32(74 + k * 2 + (sx > 0 ? 1 : 0)))
            }
        }
        for sx: Float in [-1, 1] {
            artery([arch[5], P(.thumb, 0, 0.85, sx * 0.005, -0.008), P(.thumb, 1, 0.5, sx * 0.0048, -0.0038), P(.thumb, 2, 0.5, sx * 0.0035, -0.002)], 0.0007, 0.0004, seed: 90 + (sx > 0 ? 1 : 0))
        }
        return out
    }

    func nerves(_ key: MaterialKey) -> [Strand] {
        var out: [Strand] = []
        func nerve(_ pts: [V3], _ r0: Float, _ r1: Float) {
            out.append(Strand(key, pts, sides: n(8), samples: n(max(12, pts.count * 6)), profile: Strand.stations([(0, r0, r0 * 0.8), (1, r1, r1)])))
        }
        // Median nerve: most superficial structure in the carpal tunnel, recurrent thenar branch, common
        // and proper digital nerves to the thumb, index, middle and radial ring finger.
        let median = W(0.003, 0.012, -0.0158)
        nerve([A(0.002, -0.08, -0.0135), A(0.0025, -0.03, -0.0142), W(0.003, -0.002, -0.0158), median], 0.0024, 0.0022)
        nerve([median, W(0.012, 0.016, -0.0175), W(0.0165, 0.012, -0.0182)], 0.0008, 0.0006)
        let medianTargets: [(Digit, Float)] = [(.thumb, 1), (.thumb, -1), (.index, 1), (.index, -1), (.middle, 1), (.middle, -1), (.ring, 1)]
        for (d, sx) in medianTargets {
            if d == .thumb {
                nerve([median, P(.thumb, 0, 0.6, sx * 0.0045, -0.0085), P(.thumb, 1, 0.5, sx * 0.0042, -0.0033), P(.thumb, 2, 0.55, sx * 0.003, -0.0016)], 0.0011, 0.0004)
            } else {
                nerve([median, P(d, 0, 0.6, sx * 0.0035, -0.0125), P(d, 0, 0.9, sx * 0.0052, -0.0098), P(d, 1, 0.3, sx * 0.0041, -0.0035),
                       P(d, 2, 0.5, sx * 0.0034, -0.0024), P(d, 3, 0.5, sx * 0.0025, -0.0013)], 0.001, 0.0004)
            }
        }
        // Ulnar nerve through Guyon's canal to the little finger and ulnar ring finger.
        let ulnar = W(-0.0122, 0.012, -0.0155)
        nerve([A(-0.0105, -0.08, -0.0128), A(-0.011, -0.03, -0.0138), W(-0.0125, 0.002, -0.0152), ulnar], 0.0019, 0.0017)
        for (d, sx) in [(Digit.little, Float(-1)), (.little, 1), (.ring, -1)] {
            nerve([ulnar, P(d, 0, 0.6, sx * 0.0035, -0.0118), P(d, 0, 0.9, sx * 0.005, -0.0095), P(d, 1, 0.3, sx * 0.004, -0.0034),
                   P(d, 2, 0.5, sx * 0.0032, -0.0023), P(d, 3, 0.5, sx * 0.0023, -0.0012)], 0.0009, 0.0004)
        }
        return out
    }

    // MARK: envelope

    /// Skin and subcutaneous envelope for the radiograph soft-tissue shadow.
    func envelope(_ key: MaterialKey) -> [Strand] {
        var out: [Strand] = []
        let fingerR: [Digit: [Float]] = [.thumb: [0.0, 0.0108, 0.0098], .index: [0, 0.0098, 0.0088, 0.0080], .middle: [0, 0.0102, 0.0091, 0.0082],
                                         .ring: [0, 0.0096, 0.0086, 0.0078], .little: [0, 0.0086, 0.0077, 0.0070]]
        for d in Digit.allCases {
            let segs = d == .thumb ? 3 : 4
            var pts: [V3] = [P(d, 0, 0.82, 0, -0.001)], side: [V3] = [X(d, 0)]
            var radii: [(Float, Float, Float)] = []
            for s in 1..<segs {
                pts.append(P(d, s, 0.0, 0, -0.0012)); side.append(X(d, s))
                pts.append(P(d, s, 0.55, 0, -0.0015)); side.append(X(d, s))
            }
            pts.append(P(d, segs - 1, 0.92, 0, -0.0016)); side.append(X(d, segs - 1))
            let rs = fingerR[d]!
            let k = Float(pts.count - 1)
            radii.append((0, rs[1] * 1.15, rs[1] * 0.95))
            var i: Float = 1
            for s in 1..<segs {
                radii.append((i / k, rs[s] * 1.08, rs[s] * 0.9)); i += 1
                radii.append((i / k, rs[s], rs[s] * 0.84)); i += 1
            }
            radii.append((1, rs[segs - 1] * 0.82, rs[segs - 1] * 0.66))
            var st = Strand(key, pts, sideHints: side, sides: n(22), samples: n(30), profile: Strand.stations(radii))
            st.capStart = false
            out.append(st)
        }
        // Palm: wide elliptical section from the wrist to the knuckle line, a little palmar of the bones.
        let knuckleMid = lerp(P(.index, 0, 0.95, 0, 0), P(.little, 0, 0.95, 0, 0), 0.5)
        let palmPts = [A(0, -0.11, -0.001), A(0, -0.05, -0.001), W(0, -0.01, -0.0018), W(-0.001, 0.035, -0.0026), knuckleMid - palmZ * 0.0025 * f.scale]
        out.append(Strand(key, palmPts, sideHints: [forearmX, forearmX, palmX, palmX, palmX], sides: n(28), samples: n(24),
                          profile: Strand.stations([(0, 0.03, 0.021), (0.35, 0.028, 0.019), (0.55, 0.033, 0.0178), (0.8, 0.0415, 0.0168), (1, 0.0425, 0.0145)])))
        // Thenar and hypothenar bulk.
        out.append(Strand(key, [W(0.012, 0.004, -0.004), P(.thumb, 0, 0.5, 0, -0.003), P(.thumb, 0, 0.98, 0, -0.001)], sideHints: [palmX, X(.thumb, 0), X(.thumb, 0)],
                          sides: n(18), samples: n(14), profile: Strand.stations([(0, 0.013, 0.012), (0.6, 0.0145, 0.0125), (1, 0.0118, 0.0105)])))
        return out
    }
}
