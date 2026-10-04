import simd
import Foundation

/// Hospital cubicle curtain on a straight 3.0 m ceiling track (Kirsch / Inpro cubicle track class):
/// 32 x 20 mm aluminium C-channel with white end stops and ceiling clips, 21 nylon carriers with chrome
/// hooks at 150 mm, a 500 mm open-weave mesh top band with nickel grommets (sprinkler clearance) and a
/// pleated flame-retardant curtain body at 1.3x fullness hanging to 300 mm above the floor. The body
/// is three part options (spread closed, half drawn, gathered stack at the wall end) and the
/// leading-edge binding with its pull tab slides with the lead carrier. Authored with the hem at
/// y = 0: place it at y = `hemClearance` so the track sits at `trackHeight` (2.7 m default).
public struct PrivacyCurtain: RealArticulated {
    public static let id = "privacy-curtain"
    public static let summary = "Hospital cubicle curtain: 3 m ceiling track with nylon carriers, white mesh top band and pleated teal curtain that draws open, half or closed."
    public static let tags = ["structure", "medical", "hospital", "interior", "fabric", "metal", "articulated"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 10, distance: 1.0, studio: true)

    public var trackLength: Float = 3.0
    /// Track underside above the finished floor in the room (m).
    public var trackHeight: Float = 2.7
    /// Hem above the floor (m); the asset's y = 0.
    public var hemClearance: Float = 0.3
    /// Mesh band depth (m).
    public var meshDepth: Float = 0.5
    /// Fabric width / track length.
    public var fullness: Float = 1.3
    public var fabric: MaterialKey = "fabric.curtain"
    public var mesh: MaterialKey = "fabric.curtain-mesh"
    /// Width of the gathered stack when open (m).
    public var stackWidth: Float = 0.36
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [8])
        let L = trackLength, carriers = 21, waves = carriers - 1
        let trackBottom = trackHeight - hemClearance, trackTop = trackBottom + 0.02
        let grommetY = trackBottom - 0.034, topY = grommetY + 0.016, meshY = topY - meshDepth
        let x0 = -L / 2 + 0.03, xClosed = L / 2 - 0.035
        let fabricHalf = fullness * (xClosed - x0) / Float(waves)        // fabric per half wave (m)
        let skipped = 7 + Int(rng.float(0...4))                          // carrier left off its hook
        let ampJitter = (0..<waves).map { _ in rng.float(0.8...1.18) }
        let nodeJitter = (0...waves).map { _ in rng.float(-1...1) }

        // MARK: track (sweep of the C profile along X), end stops, ceiling clips
        let c: [V2] = [V2(0, -0.004), V2(0, -0.016), V2(0.02, -0.016), V2(0.02, 0.016), V2(0, 0.016), V2(0, 0.004),
                       V2(0.002, 0.004), V2(0.002, 0.014), V2(0.018, 0.014), V2(0.018, -0.014), V2(0.002, -0.014), V2(0.002, -0.004)]
        let profile = Shape2D.rounded(c, radius: 0.0006, segments: 1)
        for l in 0..<2 {
            var m = Model(name: Self.id)
            m.add(Prim.sweep(l == 0 ? profile : c, along: [V3(-L / 2, trackBottom, 0), V3(L / 2, trackBottom, 0)], up: V3(0, 1, 0), material: "metal.aluminum-brushed"))
            for s: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(0.012, 0.024, 0.036), radius: 0.003, bevelSegments: l == 0 ? 2 : 1, material: "plastic.white"),
                      Xform(translation: V3(s * (L / 2 + 0.005), trackBottom + 0.011, 0)))
            }
            rig.base[l] = m
        }
        var clips = Surface(material: "metal.aluminum-brushed")
        for k in 0...5 {
            let x = -L / 2 + 0.1 + Float(k) * (L - 0.2) / 5
            clips.append(Prim.roundedBox(V3(0.03, 0.003, 0.042), radius: 0.001, bevelSegments: 1, material: "metal.aluminum-brushed"), Xform(translation: V3(x, trackTop + 0.0015, 0)))
        }
        rig.base[0].add(clips)

        // MARK: curtain body options
        func body(_ xEnd: Float, lod: Int, gathered: Float) -> [Surface] {
            let per = lod == 0 ? 6 : 5
            let s = (xEnd - x0) / Float(waves)
            let a0 = min(0.045 + 0.035 * gathered, 0.5 * sqrt(max(0, fabricHalf * fabricHalf - s * s)) * 0.82)
            let cols = waves * per + 1
            let ys: [Float] = lod == 0 ? [topY, topY - 0.06, topY - 0.25, meshY, meshY - 0.03, meshY - 0.3, meshY - 0.8, 0.5, 0.12, 0.035, 0]
                                       : [topY, meshY + 0.25, meshY, meshY - 0.6, 1.0, 0.5, 0]
            func point(_ ci: Int, _ y: Float) -> V3 {
                let k = min(waves - 1, ci / per), u = Float(ci - k * per) / Float(per)
                let t = (topY - y) / topY                           // 0 top ... 1 hem
                let sign: Float = k % 2 == 0 ? 1 : -1
                // Pleats soften below the grommets; a gathered stack flares a little at the hem.
                let relax = 1 - 0.18 * min(1, t * 2.5) + gathered * 0.25 * t
                var z = sign * a0 * ampJitter[k] * relax * sin(u * .pi)
                z += 0.012 * sin(Float(ci) * 0.05 + y * 1.3) * t
                var yy = y
                // Sag around the skipped carrier, fading down the drop.
                let dk = abs(Float(ci) / Float(per) - Float(skipped))
                if dk < 1.5 { yy -= 0.03 * (1 - dk / 1.5) * max(0, 1 - t * 3) }
                // Pleat widths wander below the carriers (nodes fixed at the track, free at the hem).
                func node(_ j: Int) -> Float { j == 0 || j == waves ? 0 : nodeJitter[j] * s * 0.35 * t }
                let x = x0 + (Float(k) + u) * s + node(k) * (1 - u) + node(k + 1) * u
                return V3(x, yy, z)
            }
            var out: [Surface] = []
            for (mat, r0, r1) in [(mesh, 0, 3), (fabric, 3, ys.count - 1)] {
                let rr0 = lod == 0 ? r0 : (r0 == 0 ? 0 : 2)
                let rr1 = lod == 0 ? r1 : (r0 == 0 ? 2 : ys.count - 1)
                var f = Surface(material: mat)
                for r in rr0...rr1 {
                    var uAcc: Float = 0
                    var prev = point(0, ys[r])
                    for ci in 0..<cols {
                        let p = point(ci, ys[r]); uAcc += simd_distance(p, prev); prev = p
                        _ = f.add(p, V3(0, 0, 1), V2(uAcc, p.y))
                    }
                }
                let row = UInt32(cols)
                for r in 0..<(rr1 - rr0) { for ci in 0..<(cols - 1) {
                    let a = UInt32(r) * row + UInt32(ci)
                    f.quad(a + row, a + row + 1, a + 1, a)
                }}
                f.recomputeNormals(weldSeams: true)
                f.computeTangents()
                // Back face: same sheet, offset 0.8 mm, reversed.
                var b = Surface(material: mat)
                for i in f.positions.indices { _ = b.add(f.positions[i] - f.normals[i] * 0.0008, -f.normals[i], f.uvs[i]) }
                for t in stride(from: 0, to: f.indices.count, by: 3) { b.tri(f.indices[t], f.indices[t + 2], f.indices[t + 1]) }
                b.computeTangents()
                f.append(b)
                out.append(f)
            }
            // Double-folded hem (weighted, a little soiled) and the bound seam between mesh band and body.
            let hemPath = stride(from: 0, to: cols, by: lod == 0 ? 1 : 2).map { point($0, 0.02) }
            out.append(Prim.sweep(Shape2D.rect(0.04, 0.007), along: hemPath, up: V3(0, 1, 0), material: fabric + ":7A9C98"))
            if lod == 0 {
                let seamPath = stride(from: 0, to: cols, by: lod == 0 ? 1 : 2).map { point($0, meshY) }
                out.append(Prim.sweep(Shape2D.rect(0.022, 0.0065), along: seamPath, up: V3(0, 1, 0), material: "fabric.curtain:E2E2DC"))
                let topPath = stride(from: 0, to: cols, by: lod == 0 ? 1 : 2).map { point($0, topY - 0.012) }
                out.append(Prim.sweep(Shape2D.rect(0.026, 0.0065), along: topPath, up: V3(0, 1, 0), material: "fabric.curtain:E2E2DC"))
            }
            // Grommets, carrier stems and hooks at every node (top row, z = 0).
            var chrome = Surface(material: "metal.chrome"), nylon = Surface(material: "plastic.white")
            for k in 0...waves {
                let x = x0 + Float(k) * s
                let gy = grommetY - (k == skipped ? 0.03 : 0)
                if lod == 0 {
                    chrome.append(Prim.torus(major: 0.009, minor: 0.0022, segments: 10, sides: 5, material: "metal.chrome"),
                                  Xform(translation: V3(x, gy, 0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
                }
                if k == skipped || k == waves { continue }
                nylon.append(Prim.cylinder(radius: 0.0032, height: 0.013, bevel: 0.0008, segments: lod == 0 ? 8 : 5, bevelSegments: 1, material: "plastic.white"),
                             Xform(translation: V3(x, trackBottom - 0.012, 0)))
                if lod == 0 {
                    chrome.append(Prim.torus(major: 0.0075, minor: 0.0011, segments: 8, sides: 4, arc: 1.4 * .pi, material: "metal.chrome"),
                                  Xform(translation: V3(x, trackBottom - 0.02, 0.004), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
                    chrome.append(Prim.tube([V3(x, trackBottom - 0.012, 0), V3(x, gy + 0.007, 0)], radii: [0.0011, 0.0011], sides: 4, seamTile: 0.02, material: "metal.chrome"))
                }
            }
            out.append(chrome); out.append(nylon)
            return out
        }

        let xHalf: Float = 0.0, xOpen = x0 + stackWidth
        rig.part("curtain", pivot: V3(0, topY, 0), joint: .fixed, options: 3)
        for (o, xe, g) in [(0, xClosed, Float(0)), (1, xHalf, 0.3), (2, xOpen, 1)] {
            for l in 0..<2 { for s in body(xe, lod: l, gathered: g) where !s.isEmpty { rig.add(s, to: "curtain", option: o, lods: l...l) } }
        }

        // MARK: leading edge (binding, lead carrier, pull tab) slides with the lead carrier
        rig.part("lead", pivot: V3(xClosed, trackBottom, 0), joint: .slide(axis: V3(1, 0, 0), (xOpen - xClosed)...0, duration: 1.6))
        let edge: MaterialKey = fabric + ":6F9894"
        rig.add(Prim.roundedBox(V3(0.022, topY - 0.004, 0.007), radius: 0.003, bevelSegments: 1, material: edge), Xform(translation: V3(xClosed, (topY - 0.004) / 2, 0)), to: "lead")
        rig.add(Prim.roundedBox(V3(0.05, 0.13, 0.006), radius: 0.004, bevelSegments: 1, material: edge), Xform(translation: V3(xClosed + 0.03, 1.15, 0)), to: "lead")
        rig.add(Prim.cylinder(radius: 0.0034, height: trackBottom - grommetY - 0.004, bevel: 0.0008, segments: 8, bevelSegments: 1, material: "plastic.white"),
                Xform(translation: V3(xClosed, grommetY + 0.004, 0)), to: "lead")

        groundAO(&rig, height: 0.05, floor: 0.75)
        rig.states = [
            RigState("closed"),
            RigState("open", ["lead": xOpen - xClosed], options: ["curtain": 2]),
            RigState("half", ["lead": xHalf - xClosed], options: ["curtain": 1]),
        ]
        return rig
    }
}
