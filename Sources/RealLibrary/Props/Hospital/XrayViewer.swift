import simd
import Foundation

/// Two-bank wall X-ray film illuminator (14 x 17 in viewbox class, 86 x 50 x 9.5 cm): powder-coated steel
/// housing with 8 mm corner radii, front bezel with a centre mullion and a deeper bottom rail carrying
/// one rocker switch per bank, two opal acrylic diffusers recessed 6 mm, a hinged chrome spring clip bar
/// with roller balls along the top of each bank, and two PA chest radiographs (35 x 41 cm) held in the
/// clips. Each diffuser switches between unlit opal and lit 6500 K; an inspection sticker sits on the
/// right end. Authored on its wall: back at z = -depth/2, viewing face +Z, housing bottom at y = 0
/// (scenes mount it with the bottom at about 1.2 m).
public struct XrayViewer: RealArticulated {
    public static let id = "xray-viewer"
    public static let summary = "Wall-mounted two-panel X-ray film illuminator: white steel housing, opal diffusers that light per panel, spring film clips, chest films."
    public static let tags = ["prop", "medical", "hospital", "interior", "light", "metal", "electronics", "articulated"]
    public static let budget = 7_200
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 10, distance: 1.0, studio: true)

    public var width: Float = 0.86
    public var height: Float = 0.5
    public var depth: Float = 0.095
    /// Housing paint: `metal.powder-white`, or tint it (`metal.powder-white:E6E2D6` for aged cream).
    public var housing: MaterialKey = "metal.powder-white:E9E6DC"
    /// Films hanging in the left and right banks.
    public var films = (left: true, right: true)
    /// Clip opening angle (degrees) used when a clip is toggled.
    public var clipOpen: Float = 35
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [4])
        let W = width, H = height, D = depth
        let side: Float = 0.022, top: Float = 0.028, bottom: Float = 0.046, mull: Float = 0.024
        let zf = D / 2, recess: Float = 0.006, zr = zf - recess      // bezel face, diffuser plane
        let pw = (W - 2 * side - mull) / 2, ph = H - top - bottom
        let cx: [Float] = [-(mull / 2 + pw / 2), mull / 2 + pw / 2]
        let cy = bottom + ph / 2

        // MARK: housing and bezel
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let seg = l == 0 ? 2 : 1
            // Body: deep drawn tray, front face under the diffusers.
            m.add(Prim.roundedBox(V3(W, H, D - recess), radius: 0.008, bevelSegments: seg, material: housing),
                  Xform(translation: V3(0, H / 2, -recess / 2)))
            // Bezel rails proud of the diffusers.
            func rail(_ w: Float, _ h: Float, _ x: Float, _ y: Float) {
                m.add(Prim.roundedBox(V3(w, h, recess + 0.002), radius: 0.0025, bevelSegments: seg, material: housing),
                      Xform(translation: V3(x, y, zr + recess / 2 - 0.001)).jittered(&rng, deg: 0.02, offset: 0.0001))
            }
            rail(W - 0.004, top, 0, H - top / 2 - 0.002)
            rail(W - 0.004, bottom, 0, bottom / 2 + 0.002)
            rail(side, ph + 0.004, -W / 2 + side / 2 + 0.002, cy)
            rail(side, ph + 0.004, W / 2 - side / 2 - 0.002, cy)
            rail(mull, ph + 0.004, 0, cy)
            rig.base[l] = m
        }
        // Bezel screws, switch surrounds, keyhole cover and the inspection sticker (LOD0 only).
        var screws = Surface(material: "metal.chrome")
        for x in [-W / 2 + side / 2 + 0.002, 0, W / 2 - side / 2 - 0.002] { for y in [bottom / 2 + 0.002, H - top / 2 - 0.002] {
            screws.append(Prim.lathe([V2(0, 0.0012), V2(0.0028, 0.0009), V2(0.0032, 0)], segments: 8, seamTile: 0.02, material: "metal.chrome"),
                          Xform(translation: V3(x, y, zf + 0.0009), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }}
        rig.base[0].add(screws)
        var surround = Surface(material: "plastic.medical-grey")
        for x in cx {
            surround.append(Prim.roundedBox(V3(0.03, 0.02, 0.004), radius: 0.0015, bevelSegments: 1, material: "plastic.medical-grey"),
                            Xform(translation: V3(x + pw / 2 - 0.035, bottom / 2 + 0.002, zf + 0.0015)))
        }
        for l in 0..<2 { rig.base[l].add(surround) }
        rig.base[0].add(labelQuad(V3(W / 2 + 0.0004, H * 0.55, -0.005), right: V3(0, 0, -1), up: V3(0, 1, 0), w: 0.045, h: 0.03, mat: "label.inspection"))
        // Ballast vent slots in the top, keyhole hangers and the cord grommet on the back.
        var vents = Surface(material: "plastic.black")
        for k in 0..<14 {
            let x = -W / 2 + 0.12 + Float(k) * (W - 0.24) / 13
            vents.append(cuboid(V3(0.004, 0.0012, 0.04), material: "plastic.black"),
                         Xform(translation: V3(x, H + 0.0001, -recess / 2)))
            if k % 13 == 0 {
                vents.append(cuboid(V3(0.012, 0.03, 0.0012), material: "plastic.black"),
                             Xform(translation: V3(x, H - 0.07, -D / 2 + 0.0001)))
            }
        }
        rig.base[0].add(vents)
        rig.base[0].add(Prim.lathe([V2(0, 0.003), V2(0.0055, 0.003), V2(0.007, 0.0015), V2(0.007, 0)], segments: 12, seamTile: 0.03, material: "rubber"),
                        Xform(translation: V3(W / 2 - 0.06, 0.06, -D / 2 + 0.0001), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
        // Strip of masking tape on the top rail with a handwritten bed number (story detail).
        rig.base[0].add(labelQuad(V3(-W / 2 + 0.11, H - top / 2 - 0.002, zf + 0.0012), right: V3(cos(0.05), sin(0.05), 0), up: V3(-sin(0.05), cos(0.05), 0),
                                  w: 0.075, h: 0.018, mat: "paper.sheet:E6DCB8", meters: true))

        // MARK: diffusers (off / lit)
        let names = ["left", "right"]
        for (i, n) in names.enumerated() {
            rig.part("\(n)-panel", pivot: V3(cx[i], cy, zr), joint: .fixed, options: 2)
            for (o, mat) in [(0, "plastic.diffuser"), (1, "emissive.panel")] {
                rig.add(labelQuad(V3(cx[i], cy, zr + 0.0006), right: V3(1, 0, 0), up: V3(0, 1, 0), w: pw + 0.003, h: ph + 0.003, mat: mat), to: "\(n)-panel", option: o)
            }
        }
        rig.lights = names.enumerated().map { i, n in
            RigLight(name: "\(n)-glow", kind: .point, part: "\(n)-panel", option: 1, position: V3(cx[i], cy, zf + 0.3),
                     color: V3(0.9, 0.95, 1.0), intensity: 240, attenuationRadius: 1.6)
        }

        // MARK: films (ride on the diffuser parts: unlit film, or the same film transilluminated)
        let fw: Float = 0.356, fh: Float = min(0.41, ph - 0.012)
        var idLabel = Surface(material: "label.film-id")
        for (i, on) in [films.left, films.right].enumerated() where on {
            var r = rng.fork(i + 1)
            let fx = cx[i] + r.float(-0.012...0.012), ftop = H - top + 0.012
            let tilt = r.float(-0.6...0.6)
            let z = zr + 0.0016
            func world(_ p: V2) -> V3 {   // film space: x -0.5...0.5 across, y 0 (top) ... 1 (bottom)
                let a = tilt * .pi / 180, q = V2(p.x * fw, -p.y * fh)
                return V3(fx + q.x * cos(a) - q.y * sin(a), ftop + q.x * sin(a) + q.y * cos(a), z)
            }
            var layers = [Surface(material: "film.xray-chest"), Surface(material: "film.xray-soft"), Surface(material: "film.xray-bone")]
            flat(&layers[0], [V2(-0.5, 0), V2(-0.5, 1), V2(0.5, 1), V2(0.5, 0)], world, dz: 0)
            chest(&layers, world, rng: &r)
            for var s in layers {
                rig.add(s, to: "\(names[i])-panel", option: 0)
                s.material = s.material + "-lit"
                rig.add(s, to: "\(names[i])-panel", option: 1)
            }
            // Patient ID flash card printed at the lower corner.
            let c = world(V2(i == 0 ? 0.36 : -0.36, 0.92))
            idLabel.append(labelQuad(c + V3(0, 0, 0.0028), right: V3(1, 0, 0), up: V3(0, 1, 0), w: 0.06, h: 0.032, mat: "label.film-id"))
        }
        rig.base[0].add(idLabel)

        // MARK: clip bars (hinged at the top edge, swing out to load a film)
        for (i, n) in names.enumerated() {
            let py = H - top - 0.001, pz = zr + 0.006
            rig.part("\(n)-clip", pivot: V3(cx[i], py, pz), joint: .hinge(axis: V3(1, 0, 0), -clipOpen...0, duration: 0.35))
            let cw = pw - 0.03
            rig.add(Prim.roundedBox(V3(cw, 0.02, 0.007), radius: 0.0025, bevelSegments: 2, material: "metal.chrome"),
                    Xform(translation: V3(cx[i], py - 0.011, pz + 0.0005)), to: "\(n)-clip")
            // Hinge knuckles at both ends.
            for s: Float in [-1, 1] {
                rig.add(Prim.cylinder(radius: 0.0035, height: 0.02, bevel: 0.0008, segments: 10, bevelSegments: 1, material: "metal.chrome"),
                        Xform(translation: V3(cx[i] + s * (cw / 2 - 0.01) - 0.01, py, pz), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "\(n)-clip")
            }
            // Roller balls pressing the film.
            var balls = Surface(material: "metal.chrome")
            for k in 0..<5 {
                let x = cx[i] - cw / 2 + 0.03 + Float(k) * (cw - 0.06) / 4
                balls.append(Prim.superellipsoid(V3(0.008, 0.008, 0.008), exponent: 2, subdivisions: 3, material: "metal.chrome"),
                             Xform(translation: V3(x, py - 0.014, pz - 0.003)))
            }
            rig.add(balls, to: "\(n)-clip", lods: 0...0)
        }

        // MARK: rocker switches (tilt about X; top in = off)
        for (i, n) in names.enumerated() {
            let p = V3(cx[i] + pw / 2 - 0.035, bottom / 2 + 0.002, zf + 0.004)
            rig.part("\(n)-switch", pivot: p, joint: .hinge(axis: V3(1, 0, 0), 0...16, duration: 0.15))
            rig.add(Prim.roundedBox(V3(0.022, 0.013, 0.006), radius: 0.002, bevelSegments: 1, material: "plastic.black"),
                    Xform(translation: p, rotation: simd_quatf(degrees: 8, axis: V3(1, 0, 0))), to: "\(n)-switch")
        }

        groundAO(&rig, height: 0.02, floor: 0.8)
        rig.states = [
            RigState("off"),
            RigState("left-on", ["left-switch": 16], options: ["left-panel": 1]),
            RigState("both-on", ["left-switch": 16, "right-switch": 16], options: ["left-panel": 1, "right-panel": 1]),
        ]
        return rig
    }

    /// Bone and soft-tissue shadows of a PA chest radiograph in film space (x -0.5...0.5, y 0 top...1 bottom).
    /// Each layer sits a little proud of the last so overlaps read denser, as on a real film.
    private func chest(_ L: inout [Surface], _ world: (V2) -> V3, rng: inout SeededRNG) {
        let lift: Float = 0.00025
        // Soft tissue of the chest wall and shoulders (outside the rib cage).
        for sx: Float in [-1, 1] {
            flat(&L[1], [V2(sx * 0.5, 0.02), V2(sx * 0.5, 1), V2(sx * 0.42, 1), V2(sx * 0.41, 0.6), V2(sx * 0.39, 0.25), V2(sx * 0.3, 0.06), V2(sx * 0.2, 0.0)].map { $0 }, world, dz: lift)
        }
        // Abdomen below the hemidiaphragms (right dome higher).
        var dia: [V2] = [V2(-0.5, 1), V2(0.5, 1)]
        for k in 0...10 {
            let t: Float = Float(k) / 10
            let x: Float = 0.46 - 0.92 * t
            let dome: Float = x < 0 ? 0.70 : 0.74
            let d: Float = abs(abs(x) - 0.22) / 0.24
            dia.append(V2(x, dome + 0.16 * d * d))
        }
        flat(&L[1], dia, world, dz: 2 * lift)
        // Mediastinum and heart (heart bulges to the patient's left = viewer's right).
        let hx = rng.float(0.05...0.09), hr = rng.float(0.17...0.2)
        var heart: [V2] = []
        for k in 0..<20 {
            let a = Float(k) / 20 * 2 * .pi
            heart.append(V2(hx + cos(a) * hr * (cos(a) > 0 ? 1.1 : 0.75), 0.64 + sin(a) * 0.15))
        }
        flat(&L[1], heart, world, dz: 3 * lift)
        flat(&L[1], [V2(-0.07, 0.08), V2(-0.09, 0.5), V2(0.1, 0.5), V2(0.06, 0.08)], world, dz: 3 * lift)
        // Spine.
        flat(&L[2], [V2(-0.035, 0.03), V2(-0.04, 0.98), V2(0.04, 0.98), V2(0.035, 0.03)], world, dz: 4 * lift)
        // Disc spaces along the spine.
        for k in 0..<12 {
            let y = 0.08 + Float(k) * 0.074
            flat(&L[1], [V2(-0.034, y), V2(-0.034, y + 0.005), V2(0.034, y + 0.007), V2(0.034, y + 0.002)], world, dz: 5 * lift)
        }
        // Posterior ribs: arc out and down from the spine; anterior ends fade toward the sternum.
        let pitch = rng.float(0.066...0.074)
        for sx: Float in [-1, 1] {
            for k in 0..<9 {
                let y0 = 0.1 + Float(k) * pitch, w: Float = 0.014 + Float(k) * 0.001
                let reach = min(0.4, 0.26 + Float(k) * 0.03)
                var path: [V2] = []
                for j in 0...8 {
                    let t = Float(j) / 8
                    path.append(V2(sx * (0.04 + (reach - 0.04) * t), y0 - 0.05 * sin(t * .pi * 0.8) + 0.06 * t * t))
                }
                ribbon(&L[2], path, width: w, world, dz: 5 * lift)
                // Medullary band: ribs read as two bright cortical lines.
                ribbon(&L[1], Array(path.dropFirst()), width: w * 0.42, world, dz: 6 * lift)
                if k < 6 {
                    let a = path.last!, b = V2(sx * (reach - 0.12), y0 + 0.17), c = V2(sx * 0.12, y0 + 0.23)
                    ribbon(&L[1], [a, (a + b) / 2 + V2(sx * 0.02, 0), b, c], width: w * 0.7, world, dz: 6 * lift)
                }
            }
            // Clavicle.
            ribbon(&L[2], [V2(sx * 0.05, 0.13), V2(sx * 0.18, 0.1), V2(sx * 0.3, 0.085), V2(sx * 0.38, 0.06)], width: 0.03, world, dz: 7 * lift)
            // Humeral head in the upper corner.
            var head: [V2] = []
            for k in 0..<12 { let a = Float(k) / 12 * 2 * .pi; head.append(V2(sx * 0.47 + cos(a) * 0.06, 0.1 + sin(a) * 0.07)) }
            flat(&L[2], head.map { V2(min(0.5, max(-0.5, $0.x)), $0.y) }, world, dz: 6 * lift)
        }
        // Lead "R" marker at the patient's right (viewer's left) upper corner.
        flat(&L[2], [V2(-0.44, 0.03), V2(-0.44, 0.075), V2(-0.4, 0.075), V2(-0.4, 0.03)], world, dz: 8 * lift)
    }
}

/// Flat polygon (film space) mapped through `world`, facing +Z.
private func flat(_ s: inout Surface, _ poly: [V2], _ world: (V2) -> V3, dz: Float) {
    // Film y runs down, so flip to keep CCW in world space.
    let pts = poly.map { V2($0.x, -$0.y) }
    let tri = Shape2D.triangulate(pts)
    let base = UInt32(s.positions.count)
    for p in poly { let w = world(p); _ = s.add(w + V3(0, 0, dz), V3(0, 0, 1), V2(w.x, w.y)) }
    for t in stride(from: 0, to: tri.count, by: 3) { s.tri(base + tri[t], base + tri[t + 1], base + tri[t + 2]) }
}

/// Flat ribbon of `width` along a film-space polyline, facing +Z.
private func ribbon(_ s: inout Surface, _ path: [V2], width: Float, _ world: (V2) -> V3, dz: Float) {
    let base = UInt32(s.positions.count)
    for (i, p) in path.enumerated() {
        let a = path[max(0, i - 1)], b = path[min(path.count - 1, i + 1)]
        let d = simd_normalize(b - a), n = V2(-d.y, d.x)
        let taper: Float = (i == 0 || i == path.count - 1) ? 0.6 : 1
        let w = width / 2 * taper
        let a0 = world(p + n * w), a1 = world(p - n * w)
        _ = s.add(a0 + V3(0, 0, dz), V3(0, 0, 1), V2(a0.x, a0.y))
        _ = s.add(a1 + V3(0, 0, dz), V3(0, 0, 1), V2(a1.x, a1.y))
    }
    for i in 0..<(path.count - 1) {
        let a = base + UInt32(i * 2)
        // Choose winding so the face points +Z whatever the ribbon direction.
        let p0 = s.positions[Int(a)], p1 = s.positions[Int(a + 1)], p2 = s.positions[Int(a + 2)]
        if simd_cross(p1 - p0, p2 - p0).z > 0 { s.quad(a, a + 1, a + 3, a + 2) } else { s.quad(a, a + 2, a + 3, a + 1) }
    }
}

/// Quad with UVs 0...1 (labels, screens, diffusers): `right` is +u, `up` is +v.
private func labelQuad(_ c: V3, right: V3, up: V3, w: Float, h: Float, mat: MaterialKey, meters: Bool = false) -> Surface {
    var s = Surface(material: mat)
    let n = simd_normalize(simd_cross(right, up)), r = right * (w / 2), u = up * (h / 2)
    let su: Float = meters ? w : artSpan(mat), sv: Float = meters ? h : artSpan(mat)
    let a = s.add(c - r - u, n, V2(0, 0)), b = s.add(c + r - u, n, V2(su, 0))
    let cc = s.add(c + r + u, n, V2(su, sv)), d = s.add(c - r + u, n, V2(0, sv))
    s.quad(a, b, cc, d)
    s.computeTangents()
    return s
}

/// UV span for one artwork across a label or screen: the material's tileSize (so texel density lints at ~1), else 1.
private func artSpan(_ mat: MaterialKey) -> Float {
    let s = MaterialLibrary.spec(for: String(mat.split(separator: ":")[0]))
    return s.program != nil && s.tileSize > 0 ? s.tileSize : 1
}
