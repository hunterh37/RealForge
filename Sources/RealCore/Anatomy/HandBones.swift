import simd

/// Rigid bone meshes of the hand and distal forearm, built once at reference size.
///
/// - `digits[d][s]`: each long bone in its bone frame (y from the proximal joint toward the distal
///   joint, z dorsal, x radial for the right hand). The runtime scales y by tracked length / reference
///   length and x, z by the hand scale.
/// - `carpus`: the eight carpal bones in the palm frame (origin at the wrist joint).
/// - `forearm`: distal radius and ulna in the forearm frame (origin at the forearm-wrist joint).
///
/// The left hand uses `mirrored()`.
public struct HandBones: Sendable {
    public var digits: [[Model]]
    public var carpus: Model
    public var forearm: Model
    /// Reference (untracked) length of every long bone, matching `digits`.
    public var referenceLengths: [[Float]]

    public static let boneKey: MaterialKey = "anatomy.bone"
    public static let cartilageKey: MaterialKey = "anatomy.cartilage"

    public init(bone: MaterialKey = HandBones.boneKey, cartilage: MaterialKey? = HandBones.cartilageKey, detail: Float = 1) {
        var digits: [[Model]] = [], lengths: [[Float]] = []
        for d in Digit.allCases {
            var row: [Model] = [], lrow: [Float] = []
            let segs = d == .thumb ? 3 : 4
            for s in 0..<segs {
                let loft = HandBones.loft(d, s, detail: detail)
                var m = Model(name: "\(d)-\(s)")
                for surf in loft.build(bone: bone, cartilage: cartilage) { m.add(surf) }
                if d == .thumb && s == 0 { m.add(HandBones.thumbSesamoids(material: bone)) }
                row.append(m); lrow.append(HandMorphometry.length(d, s))
            }
            digits.append(row); lengths.append(lrow)
        }
        self.digits = digits; self.referenceLengths = lengths
        carpus = HandBones.carpals(material: bone, cartilage: cartilage, detail: detail)
        forearm = HandBones.radiusUlna(material: bone, cartilage: cartilage, detail: detail)
    }

    /// Meshes for one hand. Authored meshes have x radial; runtime frames have x = y x z, which is
    /// radial on the left hand and ulnar on the right, so the right hand takes the mirror.
    public func forHand(_ c: Chirality) -> HandBones { c == .right ? mirrored() : self }

    public func mirrored() -> HandBones {
        var m = self
        m.digits = digits.map { $0.map { $0.mirroredX() } }
        m.carpus = carpus.mirroredX(); m.forearm = forearm.mirroredX()
        return m
    }

    /// Whole skeleton posed by `frames`, one model (offline previews, tests). Bones scale like the runtime.
    /// Call on `forHand(frames.chirality)`.
    public func posed(_ frames: HandFrames) -> Model {
        var out = Model(name: "hand-skeleton")
        func put(_ m: Model, _ f: BoneFrame, _ k: V3) {
            for s in m.surfaces {
                var t = s
                t.positions = s.positions.map { f.point($0 * k) }
                t.normals = s.normals.map { simd_normalize(f.direction($0 / k)) }
                t.tangents = s.tangents.map { V4(simd_normalize(f.direction(V3($0.x, $0.y, $0.z) * k)), $0.w) }
                out.add(t)
            }
        }
        let k = frames.scale
        for d in Digit.allCases {
            for s in 0..<digits[d.rawValue].count {
                let along = frames.length(d, s) / referenceLengths[d.rawValue][s]
                put(digits[d.rawValue][s], frames.bone(d, s), V3(k, along, k))
            }
        }
        put(carpus, frames.palm, V3(repeating: k))
        put(forearm, frames.forearm, V3(repeating: k))
        return out
    }

    // MARK: long bones

    static func loft(_ d: Digit, _ s: Int, detail: Float) -> BoneLoft {
        let dm = HandMorphometry.dims[d.rawValue][s]
        let L = HandMorphometry.length(d, s)
        let b = dm.base, sh = dm.shaft, h = dm.head
        typealias St = BoneLoft.Station
        func mix(_ a: HandMorphometry.Section, _ c: HandMorphometry.Section, _ t: Float) -> (Float, Float) { (lerp(a.w, c.w, t), lerp(a.d, c.d, t)) }
        let isThumb = d == .thumb
        let last = isThumb ? 2 : 3
        // Distal surface of the proximal neighbor, relative to this bone's proximal joint.
        func prevHeadReach() -> Float {
            guard s > 0 else { return 0 }
            let p = HandMorphometry.dims[d.rawValue][s - 1].head
            return s == 1 ? 0.42 * p.d : 0.1 * p.d
        }
        let gap: Float = 0.0013
        var loft: BoneLoft
        let seed = UInt32(d.rawValue * 10 + s + 1)

        if s == 0 && !isThumb {
            // Metacarpal: boxy base with carpal facets, triangular shaft with a palmar ridge and a dorsal
            // bow, neck, then a head that is wider palmarly and rolls onto the palmar side.
            let n1 = mix(b, sh, 0.72), neck = (sh.w * 1.14, sh.d * 1.18)
            loft = BoneLoft(y0: 0.002, y1: L, stations: [
                St(0, w: b.w, d: b.d, nDorsal: 2.9, nPalmar: 2.5),
                St(0.09, w: b.w * 0.96, d: b.d * 0.95, dz: 0.0002, nDorsal: 2.7, nPalmar: 2.3),
                St(0.26, w: n1.0, d: n1.1, dz: 0.0008, nDorsal: 2.4, nPalmar: 1.8),
                St(0.48, w: sh.w, d: sh.d, dz: 0.0014, nDorsal: 2.5, nPalmar: 1.55),
                St(0.70, w: sh.w * 1.04, d: sh.d * 1.02, dz: 0.0012, nDorsal: 2.5, nPalmar: 1.7),
                St(0.86, w: neck.0, d: neck.1, dz: 0.0002, nDorsal: 2.3, nPalmar: 2.0),
                St(1, w: h.w, d: h.d, dz: -0.08 * h.d, nDorsal: 2.15, nPalmar: 2.05),
            ], base: .init(depth: -0.04 * b.d), head: .init(depth: 0.42 * h.d, palmarReach: 0.22 * h.d))
            loft.bumps = [
                // Collateral ligament recesses and the dorsal tubercles beside them.
                .init(V3(0.47 * h.w, L - 0.1 * h.d, 0.12 * h.d), radius: V3(0.0018, 0.0022, 0.0022), amount: -0.0008),
                .init(V3(-0.47 * h.w, L - 0.1 * h.d, 0.12 * h.d), radius: V3(0.0018, 0.0022, 0.0022), amount: -0.0008),
                .init(V3(0.36 * h.w, L - 0.3 * h.d, 0.34 * h.d), radius: V3(0.0016, 0.002, 0.0016), amount: 0.0005),
                .init(V3(-0.36 * h.w, L - 0.3 * h.d, 0.34 * h.d), radius: V3(0.0016, 0.002, 0.0016), amount: 0.0005),
                // Interosseous attachment flats along the shaft sides.
                .init(V3(0.5 * sh.w, L * 0.5, -0.1 * sh.d), radius: V3(0.002, L * 0.25, 0.003), amount: -0.0005),
                .init(V3(-0.5 * sh.w, L * 0.5, -0.1 * sh.d), radius: V3(0.002, L * 0.25, 0.003), amount: -0.0005),
            ]
            switch d {
            case .middle: loft.bumps.append(.init(V3(0.3 * b.w, 0.003, 0.48 * b.d), radius: V3(0.003, 0.004, 0.0028), amount: 0.0028)) // styloid process
            case .index: loft.bumps.append(.init(V3(0.42 * b.w, 0.005, 0.1 * b.d), radius: V3(0.0025, 0.004, 0.004), amount: 0.0012))  // ECRL insertion
            case .little: loft.bumps.append(.init(V3(-0.5 * b.w, 0.004, 0.05 * b.d), radius: V3(0.0028, 0.004, 0.0035), amount: 0.0018)) // ECU tubercle
            default: break
            }
        } else if s == 0 {
            // First metacarpal: saddle base on the trapezium, short round shaft, broad flattened head.
            loft = BoneLoft(y0: 0.002, y1: L, stations: [
                St(0, w: b.w, d: b.d, nDorsal: 2.5, nPalmar: 2.4),
                St(0.12, w: b.w * 0.94, d: b.d * 0.95, nDorsal: 2.4, nPalmar: 2.2),
                St(0.32, w: lerp(b.w, sh.w, 0.75), d: lerp(b.d, sh.d, 0.75), dz: 0.0006, nDorsal: 2.3, nPalmar: 2.0),
                St(0.55, w: sh.w, d: sh.d, dz: 0.001, nDorsal: 2.4, nPalmar: 1.9),
                St(0.82, w: sh.w * 1.18, d: sh.d * 1.08, dz: 0.0004, nDorsal: 2.5, nPalmar: 2.1),
                St(1, w: h.w, d: h.d, dz: -0.05 * h.d, nDorsal: 2.7, nPalmar: 2.3),
            ], base: .init(depth: 0.0006, saddle: 0.0026), head: .init(depth: 0.36 * h.d, groove: 0.0006, grooveWidth: 0.2, palmarReach: 0.18 * h.d))
            loft.bumps = [
                .init(V3(0.5 * b.w, 0.004, -0.1 * b.d), radius: V3(0.003, 0.004, 0.004), amount: 0.0014),   // APL tubercle
                .init(V3(0.22 * h.w, L, -0.48 * h.d), radius: V3(0.0022, 0.003, 0.0016), amount: -0.0006),  // sesamoid grooves
                .init(V3(-0.22 * h.w, L, -0.48 * h.d), radius: V3(0.0022, 0.003, 0.0016), amount: -0.0006),
            ]
        } else if s < last {
            // Proximal and middle phalanges: concave base (MCP: one fossa; PIP/DIP: two fossae on a median
            // ridge), D-shaped shaft flat on the palmar side with flexor sheath crests, bicondylar trochlea.
            let fossa: Float = (s == 1 ? 0.2 : 0.16) * b.d
            let y0 = prevHeadReach() + gap - fossa
            let y1 = L - 0.3 * h.d
            let neck = (h.w * 0.9, h.d * 0.84)
            loft = BoneLoft(y0: y0, y1: y1, stations: [
                St(0, w: b.w * 0.9, d: b.d * 0.92, nDorsal: 2.3, nPalmar: 2.9),
                St(0.12, w: b.w * 0.88, d: b.d * 0.9, nDorsal: 2.2, nPalmar: 3.0),
                St(0.3, w: lerp(b.w, sh.w, 0.72), d: lerp(b.d, sh.d, 0.72), dz: 0.0002, nDorsal: 2.0, nPalmar: 3.4),
                St(0.52, w: sh.w, d: sh.d, dz: 0.0004, nDorsal: 1.95, nPalmar: 3.8),
                St(0.76, w: sh.w * 1.02, d: sh.d * 1.02, dz: 0.0003, nDorsal: 2.0, nPalmar: 3.4),
                St(0.9, w: neck.0, d: neck.1, nDorsal: 2.1, nPalmar: 2.8),
                St(1, w: h.w, d: h.d, dz: -0.04 * h.d, nDorsal: 2.2, nPalmar: 2.4),
            ], base: .init(depth: -fossa, groove: s == 1 ? 0 : -0.0007, grooveWidth: 0.14),
               head: .init(depth: 0.4 * h.d, groove: 0.0011 * (h.w / 0.011), grooveWidth: 0.16, palmarReach: 0.2 * h.d))
            let len = y1 - y0
            loft.bumps = [
                // Lateral base tubercles (collateral ligaments).
                .init(V3(0.5 * b.w, y0 + 0.003, -0.15 * b.d), radius: V3(0.0022, 0.003, 0.003), amount: 0.0009),
                .init(V3(-0.5 * b.w, y0 + 0.003, -0.15 * b.d), radius: V3(0.0022, 0.003, 0.003), amount: 0.0009),
                // Collateral pits on the head.
                .init(V3(0.5 * h.w, y1 - 0.0005, 0.05 * h.d), radius: V3(0.0016, 0.0018, 0.0018), amount: -0.0005),
                .init(V3(-0.5 * h.w, y1 - 0.0005, 0.05 * h.d), radius: V3(0.0016, 0.0018, 0.0018), amount: -0.0005),
            ]
            // Flexor sheath crests along the palmar borders.
            for k in 0..<5 {
                let y = y0 + len * (0.25 + 0.12 * Float(k))
                for sx: Float in [-1, 1] {
                    loft.bumps.append(.init(V3(sx * 0.44 * sh.w, y, -0.48 * sh.d), radius: V3(0.0008, len * 0.09, 0.0008), amount: 0.00035))
                }
            }
        } else {
            // Distal phalanx: two-fossa base, narrow waist, spade-shaped ungual tuft with lateral spines.
            let fossa: Float = 0.14 * b.d
            let y0 = prevHeadReach() + gap - fossa
            let tip = L * (isThumb ? 0.78 : 0.8)
            let y1 = tip - 0.25 * h.d
            loft = BoneLoft(y0: y0, y1: y1, stations: [
                St(0, w: b.w * 0.9, d: b.d * 0.92, nDorsal: 2.3, nPalmar: 2.8),
                St(0.15, w: b.w * 0.85, d: b.d * 0.88, nDorsal: 2.2, nPalmar: 3.0),
                St(0.42, w: sh.w, d: sh.d, dz: 0.0002, nDorsal: 2.0, nPalmar: 3.2),
                St(0.7, w: sh.w * 1.1, d: sh.d * 0.95, dz: 0.0003, nDorsal: 2.1, nPalmar: 3.2),
                St(0.9, w: h.w, d: h.d, dz: 0.0004, nDorsal: 2.5, nPalmar: 3.4),
                St(1, w: h.w * 0.94, d: h.d * 0.95, dz: 0.0004, nDorsal: 2.6, nPalmar: 3.4),
            ], base: .init(depth: -fossa, groove: -0.0006, grooveWidth: 0.14),
               head: .init(depth: 0.3 * h.w, articular: false))
            loft.bumps = [
                .init(V3(0.5 * b.w, y0 + 0.0025, -0.2 * b.d), radius: V3(0.0018, 0.0025, 0.0025), amount: 0.0007),
                .init(V3(-0.5 * b.w, y0 + 0.0025, -0.2 * b.d), radius: V3(0.0018, 0.0025, 0.0025), amount: 0.0007),
                .init(V3(0, y0 + 0.002, -0.5 * b.d), radius: V3(0.003, 0.0025, 0.0015), amount: 0.0007),   // FDP insertion
                .init(V3(0.5 * h.w, y1 - 0.0015, -0.2 * h.d), radius: V3(0.0012, 0.0025, 0.0012), amount: 0.0009),  // ungual spines
                .init(V3(-0.5 * h.w, y1 - 0.0015, -0.2 * h.d), radius: V3(0.0012, 0.0025, 0.0012), amount: 0.0009),
            ]
            loft.roughness = 0.0002
        }
        loft.seed = seed
        loft.sides = max(16, Int(40 * detail)); loft.rings = max(16, Int(46 * detail)); loft.capRings = max(5, Int(9 * detail))
        return loft
    }

    static func thumbSesamoids(material: MaterialKey) -> Model {
        var m = Model(name: "sesamoids")
        let L = HandMorphometry.length(.thumb, 0), h = HandMorphometry.dims[0][0].head
        for sx: Float in [-1, 1] {
            let c = V3(sx * 0.2 * h.w, L + 0.0005, -0.5 * h.d)
            m.add(Prim.cubeSphere(subdivisions: 5, material: material) { d in c + d * V3(0.0024, 0.003, 0.0021) })
        }
        return m
    }

    // MARK: carpus

    /// A carpal bone: superellipsoid with articular facets, bend, and processes.
    struct Carpal {
        var center: V3, radii: V3, exponent: Float = 2.4
        var rotation = simd_quatf.identity
        /// Concave facets: direction (local), depth, sharpness.
        var facets: [(V3, Float, Float)] = []
        /// Processes: direction (local), amount, width.
        var processes: [(V3, Float, Float)] = []
        /// Kidney bend: x offset by bend * (y/ry)^2.
        var bend: Float = 0
        var seed: UInt32 = 0
    }

    static let carpalSpecs: [Carpal] = {
        func q(_ deg: Float, _ axis: V3) -> simd_quatf { simd_quatf(degrees: deg, axis: axis) }
        return [
            // Scaphoid: long axis radial-distal-palmar, waist, distal tubercle palmar.
            Carpal(center: V3(0.0125, -0.0015, -0.0025), radii: V3(0.0062, 0.0128, 0.0058), exponent: 2.2,
                   rotation: q(-42, V3(0, 0, 1)) * q(-22, V3(1, 0, 0)),
                   facets: [(V3(-1, 0.2, 0), 0.0018, 3), (V3(0, -1, 0.2), 0.0012, 2)],
                   processes: [(V3(0.2, 0.9, -0.5), 0.0022, 0.35)], bend: -0.0022, seed: 31),
            // Lunate: crescent, concave distal facet for the capitate head.
            Carpal(center: V3(0.0005, -0.0042, 0.0004), radii: V3(0.0082, 0.0066, 0.0094), exponent: 2.3,
                   facets: [(V3(0, 1, 0), 0.0032, 2.2), (V3(0.9, 0, 0), 0.0008, 3)], seed: 32),
            // Triquetrum: pyramidal, pisiform facet palmar.
            Carpal(center: V3(-0.0122, -0.0012, 0.0004), radii: V3(0.0066, 0.0064, 0.0074), exponent: 2.5,
                   rotation: q(18, V3(0, 0, 1)),
                   facets: [(V3(0, 0, -1), 0.0009, 4), (V3(0.9, 0.3, 0), 0.0012, 3)], seed: 33),
            // Pisiform: pea on the palmar triquetrum.
            Carpal(center: V3(-0.0138, 0.0006, -0.0098), radii: V3(0.0048, 0.0058, 0.0046), exponent: 2.05,
                   facets: [(V3(0, 0, 1), 0.0007, 4)], seed: 34),
            // Trapezium: saddle facet for MC1, palmar tubercle and groove for FCR.
            Carpal(center: V3(0.0192, 0.0118, -0.0058), radii: V3(0.0074, 0.0076, 0.0068), exponent: 2.6,
                   rotation: q(-30, V3(0, 0, 1)) * q(-18, V3(0, 1, 0)),
                   facets: [(V3(0.4, 0.8, -0.3), 0.0012, 3), (V3(-1, 0, 0), 0.0012, 4)],
                   processes: [(V3(-0.3, 0.2, -1), 0.0024, 0.3)], seed: 35),
            // Trapezoid: small wedge, broader dorsally.
            Carpal(center: V3(0.0109, 0.0172, 0.0016), radii: V3(0.0056, 0.0062, 0.0074), exponent: 2.9,
                   facets: [(V3(0, 1, 0), 0.0009, 4), (V3(-1, 0, 0), 0.0008, 4)], seed: 36),
            // Capitate: largest, rounded head proximally into the lunate-scaphoid fossa, flat distal facets.
            Carpal(center: V3(0.0, 0.0124, 0.0004), radii: V3(0.0082, 0.0128, 0.0090), exponent: 2.5,
                   facets: [(V3(0, 1, 0), 0.0012, 5), (V3(1, 0, 0), 0.0006, 4), (V3(-1, 0, 0), 0.0006, 4)], seed: 37),
            // Hamate: wedge with the hook (hamulus) projecting palmarly.
            Carpal(center: V3(-0.0136, 0.0136, -0.0005), radii: V3(0.0066, 0.0104, 0.0084), exponent: 2.6,
                   rotation: q(14, V3(0, 0, 1)),
                   facets: [(V3(0, 1, 0), 0.001, 5), (V3(1, 0, 0), 0.0007, 4)],
                   processes: [(V3(0.25, 0.35, -1), 0.0068, 0.22)], seed: 38),
        ]
    }()

    static func carpal(_ c: Carpal, material: MaterialKey, detail: Float) -> Surface {
        var s = Prim.cubeSphere(subdivisions: max(6, Int(14 * detail)), material: material) { dir in
            let n = c.exponent
            let k = pow(pow(abs(dir.x / c.radii.x), n) + pow(abs(dir.y / c.radii.y), n) + pow(abs(dir.z / c.radii.z), n), 1 / n)
            var p = dir / k
            for (f, depth, sharp) in c.facets {
                let fd = simd_normalize(f)
                p -= fd * depth * pow(max(0, simd_dot(dir, fd)), sharp)
            }
            for (pd, amt, width) in c.processes {
                let pn = simd_normalize(pd)
                let a = 1 - simd_dot(dir, pn)
                p += dir * amt * exp(-a * a / (width * width * 0.25))
            }
            p.x += c.bend * pow(p.y / c.radii.y, 2)
            p += dir * 0.00012 * Noise.fbm(p * 900, octaves: 3, seed: c.seed)
            return c.center + c.rotation.act(p)
        }
        s.bakeCavityAO(strength: 0.8, floor: 0.6)
        return s
    }

    static func carpals(material: MaterialKey, cartilage: MaterialKey?, detail: Float) -> Model {
        var m = Model(name: "carpus")
        for c in carpalSpecs { m.add(carpal(c, material: material, detail: detail)) }
        return m
    }

    // MARK: forearm

    static func radiusUlna(material: MaterialKey, cartilage: MaterialKey?, detail: Float) -> Model {
        typealias St = BoneLoft.Station
        var m = Model(name: "forearm")
        // Distal radius: round shaft flaring into the wide metaphysis; concave radiocarpal surface with the
        // radial styloid and Lister's tubercle dorsally.
        var r = BoneLoft(y0: -0.095, y1: -0.0165, stations: [
            St(0, w: 0.0125, d: 0.011, dx: 0.0085, nDorsal: 2.1, nPalmar: 2.0),
            St(0.5, w: 0.0145, d: 0.0118, dx: 0.0088, nDorsal: 2.2, nPalmar: 2.1),
            St(0.78, w: 0.021, d: 0.0148, dx: 0.0095, dz: 0.0004, nDorsal: 2.4, nPalmar: 2.3),
            St(0.93, w: 0.0285, d: 0.0182, dx: 0.0108, dz: 0.0006, nDorsal: 2.7, nPalmar: 2.5),
            St(1, w: 0.031, d: 0.0192, dx: 0.0112, dz: 0.0004, nDorsal: 2.8, nPalmar: 2.6),
        ], base: .init(depth: 0.004, articular: false), head: .init(depth: -0.0022, groove: -0.0006, grooveWidth: 0.1))
        r.bumps = [
            .init(V3(0.0255, -0.0175, -0.001), radius: V3(0.0035, 0.006, 0.0042), amount: 0.0042),  // radial styloid
            .init(V3(0.0085, -0.026, 0.0096), radius: V3(0.0018, 0.005, 0.0012), amount: 0.0016), // Lister's tubercle
        ]
        r.seed = 71
        r.sides = max(16, Int(40 * detail)); r.rings = max(16, Int(40 * detail))
        for s in r.build(bone: material, cartilage: cartilage) { m.add(s) }
        // Distal ulna: slender shaft, rounded head, ulnar styloid dorsomedially.
        var u = BoneLoft(y0: -0.095, y1: -0.0215, stations: [
            St(0, w: 0.0098, d: 0.0102, dx: -0.0165, nDorsal: 2.0, nPalmar: 2.0),
            St(0.6, w: 0.0092, d: 0.0096, dx: -0.0162, nDorsal: 2.0, nPalmar: 2.0),
            St(0.88, w: 0.0128, d: 0.0124, dx: -0.0158, nDorsal: 2.05, nPalmar: 2.05),
            St(1, w: 0.0152, d: 0.0142, dx: -0.0158, nDorsal: 2.1, nPalmar: 2.1),
        ], base: .init(depth: 0.004, articular: false), head: .init(depth: 0.0042))
        u.bumps = [.init(V3(-0.0225, -0.0195, 0.003), radius: V3(0.0022, 0.0055, 0.0022), amount: 0.0036)]   // ulnar styloid
        u.seed = 72
        u.sides = max(16, Int(36 * detail)); u.rings = max(16, Int(36 * detail))
        for s in u.build(bone: material, cartilage: cartilage) { m.add(s) }
        return m
    }
}

public extension HandPose {
    /// A relaxed hand built from the reference skeleton. `curl` 0 (open, slight natural flexion) to 1
    /// (loose fist). Coordinates: palm frame mapped into a space by `origin` (wrist), `distal`
    /// (wrist toward middle knuckle) and `dorsal` (back of the hand).
    static func rest(_ chirality: Chirality, origin: V3 = .zero, distal: V3 = V3(0, 0, -1), dorsal: V3 = V3(0, 1, 0),
                     curl: Float = 0, handLength: Float = HandMorphometry.referenceHandLength) -> HandPose {
        let k = handLength / HandMorphometry.referenceHandLength
        let yA = distal.normalized
        let zA = (dorsal - yA * simd_dot(dorsal, yA)).normalized
        // Radial direction: thumb side. Right hand: y x z points ulnarly.
        let radialW = simd_cross(yA, zA) * (chirality == .right ? -1 : 1)
        func world(_ p: V3) -> V3 { origin + (radialW * p.x + yA * p.y + zA * p.z) * k }

        var pos = [V3](repeating: .zero, count: HandJoint.allCases.count)
        pos[HandJoint.wrist.rawValue] = world(.zero)
        pos[HandJoint.forearmWrist.rawValue] = world(V3(0, -0.004, 0.001))
        pos[HandJoint.forearmArm.rawValue] = world(V3(0, -0.22, 0.004))
        let c = saturate(curl)
        for d in Digit.allCases {
            let js = d.joints
            let cmc = HandMorphometry.restCMC[d.rawValue]
            var dir = simd_normalize(HandMorphometry.restMetacarpalDirection[d.rawValue])
            var axis: V3
            var flex: [Float]
            if d == .thumb {
                // Opposition with curl: the first ray swings palmarly and ulnarly.
                dir = simd_normalize(simd_quatf(angle: radians(-25 * c), axis: V3(0, 1, 0.3)).act(dir))
                let hint = V3(0.8, -0.1, 0.55)
                let dz = (hint - dir * simd_dot(hint, dir)).normalized
                axis = simd_cross(dir, dz)
                flex = [radians(12 + 28 * c), radians(14 + 50 * c)]
            } else {
                axis = V3(1, 0, 0)
                let spread: Float = [0, 4, 0, -4, -9][d.rawValue] * (1 - c)
                dir = simd_quatf(angle: radians(spread * 0.4), axis: V3(0, 0, 1)).act(dir)
                flex = [radians(12 + 70 * c), radians(18 + 80 * c), radians(8 + 50 * c)]
            }
            var p = cmc
            pos[js[0].rawValue] = world(p)
            for s in 0..<(js.count - 1) {
                if s > 0 { dir = simd_quatf(angle: -flex[s - 1], axis: axis).act(dir) }
                p += dir * HandMorphometry.length(d, s)
                pos[js[s + 1].rawValue] = world(p)
            }
        }
        return HandPose(chirality: chirality, positions: pos)
    }
}
