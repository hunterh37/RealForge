import simd
import Foundation

/// Frameless glass entrance, 1.6 m wide x 2.45 m: a 12 mm tempered glass swing leaf (1.0 x 2.4 m) on a
/// floor pivot with stainless bottom and top patch fittings, top pivot into a stainless head rail,
/// back-to-back 1.2 m stainless ladder pulls, and a fixed 0.6 m glass sidelight in a floor U-channel
/// with top patch connectors. Base y = 0, centered, glass plane at z = 0; the leaf is double acting.
public struct GlassDoor: RealArticulated {
    public static let id = "glass-door"
    public static let summary = "Frameless 12 mm tempered glass pivot door with stainless patch fittings, ladder pulls, head rail and fixed sidelight."
    public static let tags = ["structure", "interior", "door", "glass", "metal", "articulated"]
    public static let budget = 10_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 6, distance: 1.0, studio: true)

    public var leafWidth: Float = 1.0
    public var leafHeight: Float = 2.4
    public var sidelightWidth: Float = 0.6
    public var glassThickness: Float = 0.012
    public var glass: MaterialKey = "glass.clear"
    public var steel: MaterialKey = "metal.stainless"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [9])
        let W = leafWidth, H = leafHeight, S = sidelightWidth, t = glassThickness
        let gap: Float = 0.004, floorGap: Float = 0.008
        let total = W + gap + S
        let x0 = -total / 2                       // leaf hinge edge
        let x1 = x0 + W                           // leaf free edge
        let s0 = x1 + gap, s1 = total / 2         // sidelight
        let railY = floorGap + H + gap            // underside of the head rail
        let railH: Float = 0.05, railD: Float = 0.06
        let pivotX = x0 + 0.055

        func box(_ size: V3, _ c: V3, _ mat: MaterialKey, r: Float = 0.002, seg: Int = 2) -> (Surface, Xform) {
            (Prim.roundedBox(size, radius: r, bevelSegments: seg, material: mat), Xform(translation: c))
        }
        /// Patch fitting: two clamp plates sandwiching the glass with a radiused outer corner.
        func patch(len: Float, height: Float, corner: Float) -> Surface {
            let outline = Shape2D.rounded([V2(0, 0), V2(len, 0), V2(len, height - corner), V2(len - corner, height), V2(0, height)], radius: 0.004, segments: 2)
            var s = Surface(material: steel)
            let plate: Float = 0.011
            for side: Float in [-1, 1] {
                s.append(Prim.extrude(outline, depth: plate, bevel: 0.0025, bevelSegments: 2, material: steel),
                         Xform(translation: V3(0, 0, side * (t / 2 + plate / 2))))
            }
            return s
        }

        // MARK: static: head rail, sidelight, U-channel, floor pivot cover, connectors
        for l in 0..<2 {
            var m = Model(name: Self.id)
            func add(_ b: (Surface, Xform)) { m.add(b.0, b.1) }
            // Head rail: stainless-clad 50 x 60 mm channel across the opening.
            add(box(V3(total + 0.01, railH, railD), V3(0, railY + railH / 2, 0), steel, r: 0.003))
            // Sidelight glass sits 20 mm into the floor channel.
            let sh = railY - 0.006
            add(box(V3(S - 0.002, sh, t), V3((s0 + s1) / 2, sh / 2 + 0.006, 0), glass, r: 0.0015, seg: 1))
            for ex in [s0 + 0.0006, s1 - 0.0016] {
                m.add(cuboid(V3(0.0012, sh - 0.004, t - 0.002), material: "glass.emerald"), Xform(translation: V3(ex, sh / 2 + 0.006, 0)))
            }
            // Floor U-channel (40 x 20 mm) with gaskets.
            for side: Float in [-1, 1] {
                add(box(V3(S, 0.04, 0.004), V3((s0 + s1) / 2, 0.02, side * (t / 2 + 0.004)), steel, r: 0.0015, seg: 1))
                if l == 0 { add(box(V3(S - 0.004, 0.006, 0.003), V3((s0 + s1) / 2, 0.041, side * (t / 2 + 0.0012)), "rubber", r: 0.001, seg: 1)) }
            }
            add(box(V3(S, 0.006, t + 0.012), V3((s0 + s1) / 2, 0.003, 0), steel, r: 0.0015, seg: 1))
            // Sidelight top corner connectors into the head rail.
            let conn = patch(len: 0.12, height: 0.05, corner: 0.02)
            m.add(conn, Xform(translation: V3(s0 + 0.002, railY, 0), rotation: simd_quatf(degrees: 180, axis: V3(1, 0, 0))))
            m.add(conn, Xform(translation: V3(s1 - 0.002, railY, 0), rotation: simd_quatf(degrees: 180, axis: V3(0, 0, 1))))
            // Floor pivot (floor spring) cover plate, flush with the floor.
            add(box(V3(0.33, 0.004, 0.11), V3(pivotX + 0.11, 0.002, 0), steel, r: 0.0015, seg: 1))
            if l == 0 {
                for dx: Float in [-0.15, 0.15] {
                    m.add(Prim.cylinder(radius: 0.0035, height: 0.0008, bevel: 0.0003, segments: 10, bevelSegments: 1, material: "plastic.black"),
                          Xform(translation: V3(pivotX + 0.11 + dx, 0.0038, 0)))
                }
                // Top pivot pin housing in the rail.
                m.add(Prim.cylinder(radius: 0.012, height: 0.004, bevel: 0.001, segments: 20, bevelSegments: 1, material: steel),
                      Xform(translation: V3(pivotX, railY - 0.004, 0)))
            }
            rig.base[l] = m
        }

        // MARK: leaf
        rig.part("leaf", pivot: V3(pivotX, 0, 0), joint: .hinge(axis: .up, -95...95, duration: 1.4))
        let leaf = box(V3(W, H, t), V3(x0 + W / 2, floorGap + H / 2, 0), glass, r: 0.0015, seg: 1)
        rig.add(leaf.0, leaf.1, to: "leaf")
        // Polished float-glass edges read green-black.
        let edge: MaterialKey = "glass.emerald", e: Float = 0.0012
        for sx: Float in [0, 1] {
            rig.add(cuboid(V3(e, H - 0.004, t - 0.002), material: edge), Xform(translation: V3(x0 + sx * W + (sx > 0 ? 0.0004 : -0.0004), floorGap + H / 2, 0)), to: "leaf")
        }
        for sy: Float in [0, 1] {
            rig.add(cuboid(V3(W - 0.004, e, t - 0.002), material: edge), Xform(translation: V3(x0 + W / 2, floorGap + sy * H + (sy > 0 ? 0.0004 : -0.0004), 0)), to: "leaf")
        }
        // Bottom patch (PT10-style, 182 x 55 mm) and top patch (PT20) on the pivot corner.
        let bottom = patch(len: 0.182, height: 0.056, corner: 0.025)
        rig.add(bottom, Xform(translation: V3(x0 - 0.0015, floorGap - 0.0015, 0)), to: "leaf")
        rig.add(bottom, Xform(translation: V3(x0 - 0.0015, floorGap + H + 0.0015, 0), rotation: simd_quatf(degrees: 180, axis: V3(1, 0, 0))), to: "leaf")
        // Pivot spindles into floor and rail.
        rig.add(Prim.cylinder(radius: 0.009, height: floorGap - 0.003, bevel: 0.001, segments: 16, bevelSegments: 1, material: steel),
                Xform(translation: V3(pivotX, 0.004, 0)), to: "leaf")
        rig.add(Prim.cylinder(radius: 0.008, height: 0.0045, bevel: 0.0008, segments: 16, bevelSegments: 1, material: steel),
                Xform(translation: V3(pivotX, railY - 0.0042 - 0.0005 - 0.0003, 0)), to: "leaf", lods: 0...0)
        // Fixing screw caps on the patch faces.
        for py in [floorGap + 0.028, floorGap + H - 0.028] {
            for side: Float in [-1, 1] {
                rig.add(Prim.cylinder(radius: 0.0055, height: 0.0012, bevel: 0.0005, segments: 14, bevelSegments: 1, material: steel),
                        Xform(translation: V3(x0 + 0.115, py, side * (t / 2 + 0.011)), rotation: facing(V3(0, 0, side))), to: "leaf", lods: 0...0)
            }
        }

        // Back-to-back ladder pulls: 32 mm bar, 1.2 m, standoffs 900 mm apart, 70 mm off the glass.
        let px = x1 - 0.1, py: Float = 1.05
        let bar: Float = 0.016, standoff: Float = 0.07
        for side: Float in [1, -1] {
            let zf = side * t / 2
            rig.add(Prim.cylinder(radius: bar, height: 1.2, bevel: 0.008, segments: 24, bevelSegments: 3, material: steel),
                    Xform(translation: V3(px, py - 0.6, zf + side * standoff)), to: "leaf")
            for dy: Float in [-0.45, 0.45] {
                rig.add(Prim.cylinder(radius: 0.0095, height: standoff - 0.004, bevel: 0.001, segments: 16, bevelSegments: 1, material: steel),
                        Xform(translation: V3(px, py + dy, zf), rotation: facing(V3(0, 0, side))), to: "leaf")
                rig.add(Prim.cylinder(radius: 0.016, height: 0.004, bevel: 0.0012, segments: 20, bevelSegments: 1, material: steel),
                        Xform(translation: V3(px, py + dy, zf), rotation: facing(V3(0, 0, side))), to: "leaf")
            }
        }

        groundAO(&rig, height: 0.1, floor: 0.65)
        rig.states = [RigState("closed"), RigState("ajar", ["leaf": -20]), RigState("open", ["leaf": -90]), RigState("open-in", ["leaf": 90])]
        return rig
    }
}
