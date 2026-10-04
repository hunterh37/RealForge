import simd
import Foundation

/// 14-inch aluminum laptop (MacBook Pro 14 class), 312.6 x 221.2 mm, 15.5 mm closed: machined unibody
/// base with 9 mm plan corners, black keyboard well with 78 low-profile keycaps (half-height function row,
/// inverted-T arrows), glass trackpad, speaker grilles, side ports, rubber feet; display lid on a hinge
/// barrel with a black glass front, thin bezel and camera notch. The lid opens about the hinge axis
/// (X); the screen is a fixed child of the lid with off and on options and a faint fill light when on.
public struct Laptop: RealArticulated {
    public static let id = "laptop"
    public static let summary = "14-inch aluminum laptop: unibody base with 78-key keyboard well, glass trackpad, hinged display lid with thin bezel and an on/off screen."
    public static let tags = ["prop", "office", "electronics", "metal", "articulated"]
    public static let budget = 9_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 24, distance: 0.72, studio: true)

    /// Body finish: "metal.anodized" (silver) or "metal.anodized-black" (space black).
    public var finish: MaterialKey = "metal.anodized"
    public var width: Float = 0.3126
    public var depth: Float = 0.2212
    /// Base and lid thickness (m); closed height = base + lid + gap.
    public var baseHeight: Float = 0.0103
    public var lidThickness: Float = 0.0048
    /// Lid angle in the open states (degrees past closed).
    public var openAngle: Float = 108
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [5])
        let W = width, D = depth, hb = baseHeight, hl = lidThickness
        let feet: Float = 0.0008, corner: Float = 0.0095
        let yt = hb                                           // base top
        let flat = simd_quatf(degrees: -90, axis: V3(1, 0, 0))  // extrude depth (z) -> +Y, outline y -> -Z
        let black: MaterialKey = "plastic.black", keyMat: MaterialKey = "plastic.matte:1E1F21"

        // MARK: base
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let body = Prim.extrude(Shape2D.roundedRect(W, D, radius: corner, segments: l == 0 ? 5 : 2), depth: hb - feet,
                                    bevel: l == 0 ? 0.0014 : 0.001, bevelSegments: l == 0 ? 2 : 1, material: finish)
            m.add(body, Xform(translation: V3(0, feet + (hb - feet) / 2, 0), rotation: flat))
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                m.add(Prim.cylinder(radius: 0.0055, height: feet + 0.0004, bevel: 0.0004, segments: 12, bevelSegments: 1, material: "rubber"),
                      Xform(translation: V3(sx * (W / 2 - 0.026), 0, sz * (D / 2 - 0.022))))
            }}
            rig.base[l] = m
        }
        // Keyboard well: black plate the keys sit in.
        let pitch: Float = 0.0186, gap: Float = 0.0024, fnH: Float = 0.0104
        let kbW = 14.5 * pitch, kbZ0 = -D / 2 + 0.0125
        let kbD = fnH + 5 * pitch
        let well = Prim.extrude(Shape2D.roundedRect(kbW + 0.002, kbD + 0.002, radius: 0.002, segments: 2), depth: 0.0004, bevel: 0.0001, bevelSegments: 1, material: black)
        for l in 0..<2 { rig.base[l].add(well, Xform(translation: V3(0, yt + 0.0001, kbZ0 + kbD / 2), rotation: flat)) }
        // LOD1: the keys become one dark slab.
        rig.base[1].add(Prim.extrude(Shape2D.roundedRect(kbW - 0.002, kbD - 0.002, radius: 0.002, segments: 1), depth: 0.0008, bevel: 0, material: keyMat),
                        Xform(translation: V3(0, yt + 0.0006, kbZ0 + kbD / 2), rotation: flat))
        // Keys: Mac ANSI layout in key units per row (row 0 is the half-height function row).
        let rows: [[Float]] = [
            [1.5] + Array(repeating: 1, count: 13),
            Array(repeating: 1, count: 13) + [1.5],
            [1.5] + Array(repeating: 1, count: 13),
            [1.75] + Array(repeating: 1, count: 11) + [1.75],
            [2.25] + Array(repeating: 1, count: 10) + [2.25],
            [1, 1, 1, 1.25, 5, 1.25, 1, 1, 1, 1],
        ]
        var keys = Surface(material: keyMat)
        let capH: Float = 0.0007
        func key(_ x: Float, _ z: Float, _ w: Float, _ d: Float) {
            let s = Prim.extrude(Shape2D.roundedRect(w, d, radius: 0.0016, segments: 1), depth: capH, bevel: 0.00025, bevelSegments: 1, material: keyMat)
            keys.append(s, Xform(translation: V3(x, yt + 0.0004 + capH / 2, z), rotation: flat).jittered(&rng, deg: 0.03, offset: 0.00003))
        }
        var z = kbZ0
        for (r, row) in rows.enumerated() {
            let h = r == 0 ? fnH : pitch
            var x = -kbW / 2
            for (i, u) in row.enumerated() {
                let w = u * pitch
                if r == 5 && i == 8 {
                    // Up and down arrows share one key slot, stacked.
                    let hh = (h - gap) / 2 - gap / 4
                    key(x + w / 2, z + gap / 2 + hh / 2, w - gap, hh)
                    key(x + w / 2, z + h - gap / 2 - hh / 2, w - gap, hh)
                } else if r == 5 && (i == 7 || i == 9) {
                    // Left and right arrows are half height, sitting low.
                    let hh = (h - gap) / 2 - gap / 4
                    key(x + w / 2, z + h - gap / 2 - hh / 2, w - gap, hh)
                } else {
                    key(x + w / 2, z + h / 2, w - gap, h - gap)
                }
                x += w
            }
            z += h
        }
        rig.base[0].add(keys)
        // Trackpad: glass slab flush with the deck in a hairline dark gap.
        let tpW: Float = 0.148, tpD: Float = 0.0905, tpZ = D / 2 - 0.0095 - tpD / 2
        for l in 0..<2 {
            rig.base[l].add(Prim.extrude(Shape2D.roundedRect(tpW + 0.0012, tpD + 0.0012, radius: 0.0055, segments: 3), depth: 0.0002, bevel: 0, material: black),
                            Xform(translation: V3(0, yt + 0.00005, tpZ), rotation: flat))
            rig.base[l].add(Prim.extrude(Shape2D.roundedRect(tpW, tpD, radius: 0.005, segments: 3), depth: 0.0003, bevel: 0.0001, bevelSegments: 1,
                                         material: "plastic.gloss:9A9DA2"), Xform(translation: V3(0, yt + 0.00012, tpZ), rotation: flat))
        }
        // Speaker grilles either side of the keyboard (perforated fields read as dark strips).
        for sx: Float in [-1, 1] {
            rig.base[0].add(Prim.extrude(Shape2D.roundedRect(0.0105, kbD - 0.006, radius: 0.0015, segments: 1), depth: 0.0002, bevel: 0, material: "fabric.mesh:3A3B3E"),
                            Xform(translation: V3(sx * (kbW / 2 + 0.0105), yt + 0.00008, kbZ0 + kbD / 2 + 0.002), rotation: flat))
        }
        // Side ports: MagSafe, two USB-C and the headphone jack on the left; HDMI, USB-C, SD on the right.
        let portY = feet + (hb - feet) * 0.48
        let ports: [(Float, Float, Float, Float)] = [(-1, -0.075, 0.0115, 0.0042), (-1, -0.052, 0.0089, 0.0032), (-1, -0.038, 0.0089, 0.0032),
                                                     (-1, 0.055, 0.0036, 0.0036), (1, -0.07, 0.0089, 0.0032), (1, -0.05, 0.0145, 0.0045), (1, 0.04, 0.025, 0.0018)]
        for (side, pz, len, h) in ports {
            rig.base[0].add(Prim.roundedBox(V3(0.0006, h, len), radius: min(h, len) * 0.45, bevelSegments: 1, material: black),
                            Xform(translation: V3(side * (W / 2 - 0.0001), portY, pz)))
        }

        // MARK: lid
        // Hinge axis runs along X at mid lid thickness, inset half a lid thickness from the back edge.
        let lidY0 = yt + 0.0004, pivot = V3(0, lidY0 + hl / 2, -D / 2 + hl / 2 + 0.0008)
        rig.part("lid", pivot: pivot, joint: .hinge(axis: V3(1, 0, 0), -115...0, duration: 1.0))
        rig.part("screen", parent: "lid", pivot: pivot, joint: .fixed, options: 2)
        for l in 0..<2 {
            let lid = Prim.extrude(Shape2D.roundedRect(W, D, radius: corner, segments: l == 0 ? 5 : 2), depth: hl,
                                   bevel: l == 0 ? 0.0012 : 0.001, bevelSegments: l == 0 ? 2 : 1, material: finish)
            rig.add(lid, Xform(translation: V3(0, lidY0 + hl / 2, 0), rotation: flat), to: "lid", lods: l...l)
            // Black glass front with the rubber border, facing down when closed.
            rig.add(Prim.extrude(Shape2D.roundedRect(W - 0.0016, D - 0.0016, radius: corner - 0.0008, segments: l == 0 ? 4 : 2), depth: 0.0005, bevel: 0.0002,
                                 bevelSegments: 1, material: black), Xform(translation: V3(0, lidY0 - 0.0001, 0), rotation: flat), to: "lid", lods: l...l)
        }
        // Hinge barrel: dark cylinder along the axis between the clutch blocks.
        rig.add(Prim.cylinder(radius: hl / 2 + 0.0004, height: W - 0.05, bevel: 0.0008, segments: 16, bevelSegments: 1, material: finish),
                Xform(translation: pivot + V3(-(W - 0.05) / 2, 0, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "lid")
        // Camera notch in the top bezel (front edge of the lid at rest).
        let sw: Float = 0.3025, sh: Float = 0.1964
        let sz0 = -D / 2 + 0.0172, sz1 = sz0 + sh
        rig.add(Prim.roundedBox(V3(0.031, 0.0003, 0.0062), radius: 0.00012, bevelSegments: 1, material: black),
                Xform(translation: V3(0, lidY0 - 0.00062, sz1 - 0.0031 + 0.0004)), to: "lid", lods: 0...0)
        rig.add(Prim.cylinder(radius: 0.0011, height: 0.0001, bevel: 0, segments: 10, bevelSegments: 1, material: "screen.off"),
                Xform(translation: V3(0, lidY0 - 0.00078, sz1 - 0.0028), rotation: simd_quatf(degrees: 180, axis: V3(1, 0, 0))), to: "lid", lods: 0...0)
        // Display: quad facing down at rest, UVs 0...1 with v up the open screen.
        func panel(_ mat: MaterialKey) -> Surface {
            var s = Surface(material: mat)
            let y = lidY0 - 0.00045, n = V3(0, -1, 0)
            let a = s.add(V3(-sw / 2, y, sz0), n, V2(0, 0)), b = s.add(V3(sw / 2, y, sz0), n, V2(1, 0))
            let c = s.add(V3(sw / 2, y, sz1), n, V2(1, 1)), d = s.add(V3(-sw / 2, y, sz1), n, V2(0, 1))
            s.quad(a, b, c, d)
            s.computeTangents()
            return s
        }
        rig.add(panel("screen.off"), to: "screen")
        rig.add(panel("screen.ui"), to: "screen", option: 1)
        rig.lights = [RigLight(name: "screen-glow", kind: .point, part: "screen", option: 1,
                               position: V3(0, lidY0 - 0.25, (sz0 + sz1) / 2), color: V3(0.78, 0.85, 1.0), intensity: 60, attenuationRadius: 1.2)]
        groundAO(&rig, height: 0.006, floor: 0.7)
        rig.states = [RigState("closed"), RigState("open", ["lid": -openAngle]), RigState("on", ["lid": -openAngle], options: ["screen": 1])]
        return rig
    }
}
