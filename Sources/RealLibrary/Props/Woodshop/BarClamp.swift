import simd
import Foundation

/// 12 in F-style bar clamp lying on its side. Zinc-plated bar 19 x 5.5 x 430 mm with a serrated back
/// edge; red enamel cast fixed jaw riveted to the bar end; sliding cast jaw (flanged I-section arm) on a
/// collar around the bar; 3/4 in (8.5 TPI acme) threaded screw through the arm boss with a ball-jointed
/// swivel pad; turned beech handle with a steel ferrule; soft black caps on both jaw faces. Throat
/// depth 86 mm to the screw axis, 300 mm capacity. Story detail: dried glue on the bar and the fixed pad.
///
/// Frame: bar along +X (fixed jaw at -X), jaws toward +Z, rolled 3.3 degrees about X so it rests on the
/// handle and the jaw collars. Rig: `jaw` slides +X along the bar (0...0.3 m), `screw` slides -X out of
/// the boss (0...0.03 m, final clamping travel), `handle` turns about the screw axis (0...360 degrees).
/// Pad gap = jaw - screw.
public struct BarClamp: RealArticulated {
    public static let id = "bar-clamp"
    public static let summary = "12 in F-style bar clamp: serrated plated steel bar, red cast fixed and sliding jaws, threaded screw with swivel pad, beech handle, soft jaw pads."
    public static let tags = ["prop", "workshop", "tool", "handheld", "articulated", "metal", "wood"]
    public static let budget = 9_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 20, elevation: 38, distance: 1.0, studio: true)

    /// Casting paint (chips through to black iron in the material).
    public var casting: MaterialKey = "metal.enamel:B3261E"
    /// Bar plating.
    public var barMaterial: MaterialKey = "metal.clamp-bar"
    /// Handle wood.
    public var handleWood: MaterialKey = "wood.maple-natural"
    /// Soft jaw pad caps.
    public var padMaterial: MaterialKey = "rubber"
    /// Bar length (m).
    public var barLength: Float = 0.43
    /// Screw axis distance from the bar centerline (m).
    public var throat: Float = 0.086
    /// Dried glue on the bar and fixed pad.
    public var glue = true
    public init() {}

    // MARK: geometry constants (flat frame: bar centerline on z = 0, clamp mid-plane y = 0)

    let hb: Float = 0.019, tb: Float = 0.0055
    let handleR: Float = 0.016, collarHalf: Float = 0.0100, collarZ: Float = 0.0175
    var x0: Float { -0.034 }
    var xEnd: Float { x0 + barLength }

    /// Flat frame to asset space: roll about X so the handle and the collars touch y = 0, centered.
    public var frame: Xform {
        let s = (handleR - collarHalf) / (throat + collarZ), th = asin(s), c = cos(th)
        let ty = handleR * c - throat * s
        let cx = (x0 - 0.002 + xEnd) / 2, cz = c * (-collarZ + 0.108) / 2
        return Xform(translation: V3(-cx, ty, -cz), rotation: simd_quatf(angle: -th, axis: V3(1, 0, 0)))
    }

    // MARK: public API

    /// Pad gap (m) for a jaw slide and screw travel: the soft pad faces part by `jaw - screw`.
    public func opening(jaw: Float, screw: Float = 0) -> Float { max(0, jaw - screw) }
    /// Center of the fixed jaw's pad face (asset space); the face normal is +X.
    public var fixedJawFace: V3 { frame.point(V3(0, 0, throat)) }
    /// Center of the moving swivel pad's face (asset space) for a jaw slide and screw travel; normal -X.
    public func movingJawFace(jaw: Float, screw: Float = 0) -> V3 { frame.point(V3(jaw - screw, 0, throat)) }
    /// Unit screw axis, pointing from the handle toward the fixed jaw (asset space).
    public var screwAxis: V3 { frame.rotation.act(V3(-1, 0, 0)) }
    /// Hand position on the handle at a jaw slide and screw travel.
    public func grip(jaw: Float, screw: Float = 0) -> V3 { frame.point(V3(0.165 + jaw - screw, 0, throat)) }
    /// Hand position on the handle in the default (`idle`) state.
    public var grip: V3 { grip(jaw: Self.idleJaw) }
    /// Jaw slide of the `idle` state (m).
    public static let idleJaw: Float = 0.1
    /// Board thicknesses of the clamping states (m).
    public static let clampedBoards: [String: Float] = ["clamping-38mm": 0.038, "clamping-19mm": 0.019]

    // MARK: rig

    public func rig(seed: UInt64) -> Rig {
        let rng = SeededRNG(seed: seed)
        let F = frame
        func at(_ x: Xform) -> Xform { x.then(F) }
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [2])
        let zP = throat
        let qX = simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))       // extrude XY outline -> XZ plane, depth along Y
        let toNegX = simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1))   // local +Y -> -X
        let toPosX = simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))  // local +Y -> +X
        let steel: MaterialKey = "metal.steel", zinc: MaterialKey = "metal.screw-zinc"

        // Flanged casting: thin web, swept edge flange, both from one outline (x, z).
        func castArm(_ outline: [V2], web: Float, flange: Float, lod: Int) -> [Surface] {
            let o = Shape2D.rounded(outline, radius: 0.003, segments: lod == 0 ? 2 : 1)
            var out = [Prim.extrude(o, depth: web, bevel: 0.0008, bevelSegments: 1, material: casting).transformed(Xform(rotation: qX))]
            let inset = Shape2D.offset(o, -0.0017)
            let path = inset.map { V3($0.x, 0, $0.y) }
            let prof = Shape2D.roundedRect(flange, 0.0034, radius: 0.0012, segments: 1)
            out.append(Prim.sweep(prof, along: path, up: V3(0, 1, 0), closedPath: true, material: casting))
            return out
        }

        for l in 0..<2 {
            var m = Model(name: Self.id)
            // Bar: serrated back edge (notches every 5 mm), plain front edge.
            var bar: [V2] = [V2(x0, hb / 2), V2(x0, -hb / 2)]
            if l == 0 {
                var x = x0 + 0.04
                bar = [V2(x0, hb / 2), V2(x0, -hb / 2), V2(x, -hb / 2)]
                while x < xEnd - 0.012 {
                    bar += [V2(x + 0.0012, -hb / 2 + 0.0011), V2(x + 0.0024, -hb / 2 + 0.0011), V2(x + 0.0036, -hb / 2)]
                    x += 0.006
                }
                bar.append(V2(xEnd, -hb / 2))
            } else { bar.append(V2(xEnd, -hb / 2)) }
            bar.append(V2(xEnd, hb / 2))
            let barS = Prim.extrude(bar, depth: tb, bevel: 0.0005, bevelSegments: 1, material: barMaterial)
            m.add(barS, at(Xform(rotation: qX)))
            // End stop: peened pin through the bar tail.
            m.add(Prim.cylinder(radius: 0.0026, height: tb + 0.0036, bevel: 0.0008, segments: 10, bevelSegments: 1, material: steel),
                  at(Xform(translation: V3(xEnd - 0.007, -(tb + 0.0036) / 2, 0))))

            // Fixed jaw: collar block over the bar end, flanged arm, pad boss.
            m.add(Prim.roundedBox(V3(0.033, 0.020, 2 * collarZ), radius: 0.003, bevelSegments: 1, material: casting),
                  at(Xform(translation: V3(-0.0205, 0, 0))))
            let fixedArm: [V2] = [V2(-0.004, 0.012), V2(-0.004, 0.024), V2(-0.013, 0.040), V2(-0.014, 0.060), V2(-0.004, 0.068), V2(-0.004, 0.106),
                                  V2(-0.026, 0.108), V2(-0.036, 0.090), V2(-0.036, 0.012)]
            for s in castArm(fixedArm, web: 0.009, flange: 0.018, lod: l) { m.add(s, at(.identity)) }
            m.add(Prim.roundedBox(V3(0.008, 0.019, 0.040), radius: 0.0025, bevelSegments: l == 0 ? 2 : 1, material: casting),
                  at(Xform(translation: V3(-0.0085, 0, zP))))
            // Fixed soft pad: cap over the jaw face, skirt wrapping the boss edge.
            m.add(Prim.superellipsoid(V3(0.0046, 0.0215, 0.040), exponent: 5, subdivisions: l == 0 ? 6 : 3, material: padMaterial),
                  at(Xform(translation: V3(-0.0023, 0, zP))))
            if l == 0 {
                // Rivets through the collar, both faces.
                for (px, pz) in [(Float(-0.027), Float(0.007)), (-0.012, -0.007)] {
                    for side: Float in [-1, 1] {
                        rivet(&m, at: F.point(V3(px, side * 0.0099, pz)), normal: F.rotation.act(V3(0, side, 0)), radius: 0.0034, height: 0.0016, segments: 10, material: steel)
                    }
                }
                // Story detail: dried glue squeeze-out on the bar and the fixed pad.
                if glue {
                    var g = rng.fork(3)
                    // Squeeze-out runs: flattened lens-shaped beads across the bar faces, amber, a few mm wide.
                    for k in 0..<3 {
                        let x = 0.018 + Float(k) * g.float(0.03...0.06)
                        let side: Float = k == 1 ? -1 : 1
                        let len = g.float(0.012...0.022), w = g.float(0.004...0.0065)
                        var path: [V3] = []
                        for i in 0...8 { let u = Float(i) / 8; path.append(V3(x + u * len * 0.25, side * (tb / 2 - 0.0002), hb / 2 - 0.001 - u * len)) }
                        let prof = Shape2D.superellipse(0.0013, w, exponent: 2.2, segments: 8)
                        let sc = (0...8).map { i -> Float in let u = Float(i) / 8; return 0.45 + 0.55 * sin(u * .pi * 0.9 + 0.15) }
                        m.add(Prim.sweep(prof, along: path, up: V3(0, side, 0), scales: sc, material: "plastic.glue-dried"), at(.identity))
                    }
                    m.add(Prim.superellipsoid(V3(0.0022, 0.009, 0.014), exponent: 2.5, subdivisions: 3, material: "plastic.glue-dried"),
                          at(Xform(translation: V3(-0.0015, 0.0105, zP - 0.006))))
                }
            }
            rig.base[l] = m
        }

        // MARK: moving jaw (slides along the bar)
        rig.part("jaw", pivot: F.point(V3(0.06, 0, 0)), joint: .slide(axis: F.rotation.act(V3(1, 0, 0)), 0...0.3, duration: 1.2))
        for l in 0..<2 {
            rig.add(Prim.roundedBox(V3(0.042, 0.020, 2 * collarZ), radius: 0.003, bevelSegments: 1, material: casting),
                    at(Xform(translation: V3(0.06, 0, 0))), to: "jaw", lods: l...l)
            let arm: [V2] = [V2(0.040, 0.012), V2(0.080, 0.012), V2(0.080, 0.030), V2(0.074, 0.060), V2(0.076, 0.098), V2(0.044, 0.098),
                             V2(0.046, 0.060), V2(0.040, 0.030)]
            for s in castArm(arm, web: 0.009, flange: 0.018, lod: l) { rig.add(s, at(.identity), to: "jaw", lods: l...l) }
            // Screw boss along X.
            let boss: [V2] = [V2(0.0098, 0), V2(0.0112, 0.0012), V2(0.0115, 0.003), V2(0.0115, 0.027), V2(0.0112, 0.0288), V2(0.0098, 0.030)]
            rig.add(Prim.lathe(boss, segments: l == 0 ? 16 : 10, seamTile: 0.08, material: casting), at(Xform(translation: V3(0.045, 0, zP), rotation: toPosX)), to: "jaw", lods: l...l)
            // Bore rings (thread entry) at both boss ends.
            rig.add(Prim.lathe([V2(0.0068, 0.0012), V2(0.0068, 0.0006), V2(0.0098, 0)], segments: l == 0 ? 16 : 10, seamTile: 0.05, material: "metal.cast-iron"),
                    at(Xform(translation: V3(0.0752, 0, zP), rotation: toNegX)), to: "jaw", lods: l...l)
            rig.add(Prim.lathe([V2(0.0068, 0.0012), V2(0.0068, 0.0006), V2(0.0098, 0)], segments: l == 0 ? 16 : 10, seamTile: 0.05, material: "metal.cast-iron"),
                    at(Xform(translation: V3(0.0448, 0, zP), rotation: toPosX)), to: "jaw", lods: l...l)
        }
        // Set screw dimple on the collar face (LOD0).
        rig.add(Prim.cylinder(radius: 0.0028, height: 0.0012, bevel: 0.0004, segments: 10, bevelSegments: 1, material: steel),
                at(Xform(translation: V3(0.068, 0.0096, -0.009))), to: "jaw", lods: 0...0)

        // MARK: screw (final clamping travel)
        rig.part("screw", parent: "jaw", pivot: F.point(V3(0.06, 0, zP)), joint: .slide(axis: F.rotation.act(V3(-1, 0, 0)), 0...0.03, duration: 0.8))
        let rodStart: Float = 0.010, rodEnd: Float = 0.118
        for l in 0..<2 {
            let rod = l == 0 ? Self.threadedRod(length: rodEnd - rodStart, rMajor: 0.0068, rMinor: 0.0053, pitch: 0.0042, sides: 10, material: zinc)
                             : Prim.cylinder(radius: 0.0062, height: rodEnd - rodStart, bevel: 0.0005, segments: 8, bevelSegments: 1, material: zinc)
            rig.add(rod, at(Xform(translation: V3(rodEnd, 0, zP), rotation: toNegX)), to: "screw", lods: l...l)
            // Swivel pad: steel disc on a ball cup.
            let sw: [V2] = [V2(0, 0.004), V2(0.0128, 0.004), V2(0.0135, 0.0047), V2(0.0135, 0.0076), V2(0.0124, 0.0088), V2(0.0085, 0.0094),
                            V2(0.0078, 0.0112), V2(0.0080, 0.0130), V2(0.0068, 0.0148), V2(0.0058, 0.0152)]
            rig.add(Prim.lathe(sw, segments: l == 0 ? 16 : 10, seamTile: 0.06, material: steel), at(Xform(translation: V3(0, 0, zP), rotation: toPosX)), to: "screw", lods: l...l)
            // Soft pad cap on the swivel face.
            let cap: [V2] = [V2(0, 0), V2(0.0118, 0), V2(0.0134, 0.0010), V2(0.0140, 0.0030), V2(0.0140, 0.0046), V2(0.0128, 0.0046)]
            rig.add(Prim.lathe(cap, segments: l == 0 ? 16 : 10, seamTile: 0.06, material: padMaterial), at(Xform(translation: V3(0, 0, zP), rotation: toPosX)), to: "screw", lods: l...l)
        }

        // MARK: handle (turns about the screw axis)
        rig.part("handle", parent: "screw", pivot: F.point(V3(0.16, 0, zP)), joint: .hinge(axis: F.rotation.act(V3(1, 0, 0)), 0...360, duration: 1.0))
        let hx0: Float = 0.109
        for l in 0..<2 {
            let sg = l == 0 ? 20 : 10
            // Steel ferrule.
            rig.add(Prim.lathe([V2(0.0062, -0.0004), V2(0.0118, 0), V2(0.0124, 0.0006), V2(0.0124, 0.0084), V2(0.0118, 0.009), V2(0.0108, 0.0092)],
                               segments: sg, seamTile: 0.08, material: steel), at(Xform(translation: V3(hx0, 0, zP), rotation: toPosX)), to: "handle", lods: l...l)
            // Beech handle: swelling barrel, two scorched rings, domed end.
            var hp: [V2] = [V2(0.0108, 0.0088), V2(0.0122, 0.012), V2(0.0140, 0.024), V2(0.0154, 0.040)]
            if l == 0 { hp += [V2(0.0159, 0.050), V2(0.0153, 0.0515), V2(0.0153, 0.0535), V2(0.0160, 0.055)] }
            hp += [V2(handleR, 0.068), V2(0.0158, 0.082)]
            if l == 0 { hp += [V2(0.0156, 0.0855), V2(0.0150, 0.0868), V2(0.0150, 0.0885), V2(0.0155, 0.090)] }
            hp += [V2(0.0152, 0.096), V2(0.0138, 0.102), V2(0.0110, 0.1055), V2(0.0060, 0.1072), V2(0, 0.1076)]
            rig.add(Prim.lathe(hp, segments: sg, seamTile: 0.1, material: handleWood, swapUV: true),
                    at(Xform(translation: V3(hx0, 0, zP), rotation: toPosX)), to: "handle", lods: l...l)
        }

        groundAO(&rig, height: 0.02, floor: 0.6)
        rig.states = [
            RigState("idle", ["jaw": Self.idleJaw]),
            RigState("open", ["jaw": 0.3]),
            RigState("closed"),
            RigState("clamping-38mm", ["jaw": 0.038 + 0.012, "screw": 0.012, "handle": 230]),
            RigState("clamping-19mm", ["jaw": 0.019 + 0.014, "screw": 0.014, "handle": 300]),
        ]
        return rig
    }

    /// Threaded rod along +Y from y = 0: acme-like trapezoid thread on a helical grid (every crest a true
    /// helix), chamfered ends.
    static func threadedRod(length: Float, rMajor: Float, rMinor: Float, pitch p: Float, sides n: Int, material: MaterialKey) -> Surface {
        let J = 4
        let tooth: [Float] = [0, 1, 1, 0]
        let ch: Float = 0.0012
        var s = Surface(material: material)
        let m0 = -J, m1 = Int(ceil(length / p * Float(J))) + 1
        let row = UInt32(n + 1)
        for r in m0...m1 {
            let u = ((r % J) + J) % J
            for k in 0...n {
                let a = Float(k) / Float(n) * 2 * .pi
                let y = p * (Float(r) / Float(J) + a / (2 * .pi))
                let yc = min(max(y, 0), length)
                // Chamfer: the thread drops to the minor radius over the last `ch` at each end.
                let e = min(1, min(yc, length - yc) / ch)
                var rad = rMinor + (rMajor - rMinor) * tooth[u] * e
                if y <= 0 || y >= length { rad = rMinor - 0.0004 }
                s.add(V3(rad * cos(a), yc, -rad * sin(a)), .up, V2(a * rMajor, y))
            }
        }
        for r in 0..<UInt32(m1 - m0) { for k in 0..<UInt32(n) {
            let a = r * row + k
            s.quad(a, a + 1, a + row + 1, a + row)
        }}
        // End caps.
        for (y, up) in [(Float(0), false), (length, true)] {
            let c = s.add(V3(0, y, 0), up ? .up : -.up, .zero)
            for k in 0...n { let a = Float(k) / Float(n) * 2 * .pi; s.add(V3((rMinor - 0.0004) * cos(a), y, -(rMinor - 0.0004) * sin(a)), up ? .up : -.up, V2(cos(a), sin(a)) * rMinor) }
            for k in 0..<UInt32(n) { up ? s.tri(c, c + 1 + k, c + 2 + k) : s.tri(c, c + 2 + k, c + 1 + k) }
        }
        s.recomputeNormals()
        s.computeTangents()
        return s
    }
}
