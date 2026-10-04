import simd
import Foundation

/// Aluminum tilt-and-turn window, 1.2 x 1.5 m: black anodized 70 mm frame, inward-opening sash with
/// an interior overlap lip, 4-16-4 insulated glass unit (two clear panes on a black warm-edge spacer),
/// EPDM glazing gaskets, silver sash handle on an oval rosette, white laminate interior sill board and
/// a pressed aluminum exterior sill with drip nose. The sash tilts inward about its bottom edge or turns
/// on its left hinges; the handle selects the mode (down closed, horizontal turn, up tilt).
/// Base y = 0 is the bottom of the frame; interior faces +Z.
public struct OfficeWindow: RealArticulated {
    public static let id = "office-window"
    public static let summary = "Tilt-and-turn window: black anodized aluminum frame and sash, double glazing with spacer, gaskets, handle, sill board and drip sill."
    public static let tags = ["structure", "interior", "window", "glass", "metal", "articulated"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 10, distance: 1.0, studio: true)

    public var width: Float = 1.2
    public var height: Float = 1.5
    public var frameMaterial: MaterialKey = "metal.anodized-black"
    public var glass: MaterialKey = "glass.clear"
    public var handleMaterial: MaterialKey = "metal.anodized"
    public var sillMaterial: MaterialKey = "laminate.white"
    /// Interior sill board projection into the room (m).
    public var sillDepth: Float = 0.2
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [8])
        let W = width, H = height
        let fw: Float = 0.05, fd: Float = 0.07          // frame face width, depth
        let fz0 = -fd / 2, fz1 = fd / 2
        let ox = W / 2 - fw, oy0 = fw, oy1 = H - fw       // frame opening
        let gap: Float = 0.003
        let sx0 = ox - gap, sy0 = oy0 + gap, sy1 = oy1 - gap   // sash outer edges (main profile)
        let sw: Float = 0.075                               // sash face width
        let sz0: Float = -0.022, sz1: Float = fz1 + 0.012   // sash depth (stands 12 mm proud inside)
        let lip: Float = 0.014
        let mat = frameMaterial, seal: MaterialKey = "rubber"

        func box(_ size: V3, _ c: V3, _ m: MaterialKey, r: Float = 0.002, seg: Int = 2) -> (Surface, Xform) {
            (Prim.roundedBox(size, radius: r, bevelSegments: seg, material: m), Xform(translation: c))
        }

        // MARK: frame, sills (static)
        for l in 0..<2 {
            var m = Model(name: Self.id)
            func add(_ b: (Surface, Xform)) { m.add(b.0, b.1) }
            for s: Float in [-1, 1] {
                add(box(V3(fw, H, fd), V3(s * (W / 2 - fw / 2), H / 2, 0), mat, r: 0.0025))
                // Inner frame step (rebate) toward the exterior glass line.
                add(box(V3(0.008, oy1 - oy0, 0.03), V3(s * (ox - 0.004 + 0.002), H / 2, fz0 + 0.015), mat, r: 0.0015, seg: 1))
            }
            for y in [fw / 2, H - fw / 2] {
                add(box(V3(W - 2 * fw + 0.002, fw, fd), V3(0, y, 0), mat, r: 0.0025))
            }
            for y in [oy0 - 0.004 + 0.002, oy1 + 0.004 - 0.002] {
                add(box(V3(2 * ox, 0.008, 0.03), V3(0, y, fz0 + 0.015), mat, r: 0.0015, seg: 1))
            }
            // Interior sill board: 25 mm white laminate, horns 50 mm past the frame, rounded nose.
            add(box(V3(W + 0.1, 0.025, sillDepth), V3(0, -0.0125 + 0.012, fz1 + sillDepth / 2 - 0.004), sillMaterial, r: 0.005, seg: 3))
            // Exterior pressed-aluminum sill with upstand and drip nose.
            let prof = Shape2D.rounded([V2(0, -0.004), V2(0.158, -0.02), V2(0.158, -0.042), V2(0.162, -0.042), V2(0.162, -0.013),
                                        V2(0.004, 0.0012), V2(0.004, 0.02), V2(0, 0.02)], radius: 0.0012, segments: 2)
            m.add(Prim.extrude(prof, depth: W + 0.04, bevel: 0.001, bevelSegments: 1, material: mat),
                  Xform(translation: V3(0, 0, fz0), rotation: simd_quatf(degrees: 90, axis: .up)))
            if l == 0 {
                // Drainage slot caps on the outer frame bottom, frame-to-sash seal.
                for dx: Float in [-0.35, 0.35] {
                    add(box(V3(0.03, 0.006, 0.003), V3(dx, fw * 0.55, fz0 - 0.001), "plastic.black", r: 0.001, seg: 1))
                }
                for s: Float in [-1, 1] {
                    add(box(V3(0.004, oy1 - oy0 - 0.01, 0.004), V3(s * (ox - 0.002), H / 2, fz0 + 0.032), seal, r: 0.0012, seg: 1))
                }
                for y in [oy0 + 0.002, oy1 - 0.002] {
                    add(box(V3(2 * ox - 0.01, 0.004, 0.004), V3(0, y, fz0 + 0.032), seal, r: 0.0012, seg: 1))
                }
                // Corner hinge cover (bottom left) and stay cover (top left) on the frame.
                add(box(V3(0.012, 0.06, 0.016), V3(-ox - 0.006, oy0 + 0.04, fz1 + 0.006), mat, r: 0.004))
                add(box(V3(0.012, 0.05, 0.016), V3(-ox - 0.006, oy1 - 0.04, fz1 + 0.006), mat, r: 0.004))
            }
            rig.base[l] = m
        }

        // MARK: sash chain: tilt (bottom edge, X) -> sash (left edge, Y) -> handle (normal)
        rig.part("tilt", pivot: V3(0, sy0, sz1), joint: .hinge(axis: V3(1, 0, 0), 0...15, duration: 0.9))
        let hingeX = -(sx0 + lip)
        rig.part("sash", parent: "tilt", pivot: V3(hingeX, 0, sz1), joint: .hinge(axis: .up, -95...0, duration: 1.2))
        let sd = sz1 - sz0, sc = (sz0 + sz1) / 2
        for s: Float in [-1, 1] {
            let b = box(V3(sw, sy1 - sy0, sd), V3(s * (sx0 - sw / 2), (sy0 + sy1) / 2, sc), mat, r: 0.003)
            rig.add(b.0, b.1.jittered(&rng, deg: 0, offset: 0.0001), to: "sash")
            // Interior overlap lip covering the frame joint.
            let lb = box(V3(lip + 0.004, sy1 - sy0 + 2 * lip, 0.012), V3(s * (sx0 + lip / 2 - 0.002), (sy0 + sy1) / 2, sz1 - 0.006), mat, r: 0.003)
            rig.add(lb.0, lb.1, to: "sash")
        }
        for (y, s) in [(sy0, Float(1)), (sy1, -1)] {
            let b = box(V3(2 * (sx0 - sw) + 0.002, sw, sd), V3(0, y + s * sw / 2, sc), mat, r: 0.003)
            rig.add(b.0, b.1, to: "sash")
            let lb = box(V3(2 * sx0 + 0.004, lip + 0.004, 0.012), V3(0, y - s * (lip / 2 - 0.002), sz1 - 0.006), mat, r: 0.003)
            rig.add(lb.0, lb.1, to: "sash")
        }
        // Insulated glass unit: 4 mm panes, 16 mm cavity, black spacer just inside the sight line.
        let gx = sx0 - sw, gy0 = sy0 + sw, gy1 = sy1 - sw
        let paneW = 2 * gx + 0.03, paneH = gy1 - gy0 + 0.03, gyc = (gy0 + gy1) / 2
        let zIn: Float = 0.026, zOut: Float = 0.002
        for z in [zIn, zOut] {
            rig.add(Prim.roundedBox(V3(paneW, paneH, 0.004), radius: 0.001, bevelSegments: 1, material: glass), Xform(translation: V3(0, gyc, z)), to: "sash")
        }
        let spW: Float = 0.007, spD = zIn - zOut - 0.004
        let spC = (zIn + zOut) / 2
        for s: Float in [-1, 1] {
            rig.add(cuboid(V3(spW + 0.01, paneH - 0.02, spD), material: seal), Xform(translation: V3(s * (gx + 0.005 - spW), gyc, spC)), to: "sash")
            rig.add(cuboid(V3(paneW - 0.02, spW + 0.01, spD), material: seal), Xform(translation: V3(0, s > 0 ? gy1 + 0.005 - spW : gy0 - 0.005 + spW, spC)), to: "sash")
        }
        // EPDM glazing gaskets, both faces, at the sight line.
        for (z, lods) in [(zIn + 0.0035, 0...1), (zOut - 0.0035, 0...0)] {
            for s: Float in [-1, 1] {
                rig.add(Prim.roundedBox(V3(0.005, gy1 - gy0 + 0.004, 0.004), radius: 0.0015, bevelSegments: 1, material: seal),
                        Xform(translation: V3(s * (gx - 0.001), gyc, z)), to: "sash", lods: lods)
                rig.add(Prim.roundedBox(V3(2 * gx + 0.004, 0.005, 0.004), radius: 0.0015, bevelSegments: 1, material: seal),
                        Xform(translation: V3(0, s > 0 ? gy1 - 0.001 : gy0 + 0.001, z)), to: "sash", lods: lods)
            }
        }
        // Sash-side hinge knuckles (bottom and top left).
        for y in [oy0 + 0.04, oy1 - 0.04] {
            rig.add(Prim.cylinder(radius: 0.007, height: 0.045, bevel: 0.002, segments: 14, bevelSegments: 1, material: mat),
                    Xform(translation: V3(hingeX - 0.002, y - 0.0225, sz1 + 0.002)), to: "sash", lods: 0...0)
        }

        // Handle on the right sash stile at mid height: oval rosette, cranked lever.
        let hx = sx0 - sw / 2, hy = H / 2, hz = sz1
        rig.part("handle", parent: "sash", pivot: V3(hx, hy, hz), joint: .hinge(axis: V3(0, 0, -1), 0...180, duration: 0.5))
        let rosette = Prim.superellipsoid(V3(0.032, 0.074, 0.02), exponent: 5, subdivisions: 8, material: handleMaterial)
        rig.add(rosette, Xform(translation: V3(hx, hy, hz + 0.0)), to: "sash")
        let ctrl: [V3] = [V3(0, 0, 0.008), V3(0, 0, 0.026), V3(0, -0.006, 0.037), V3(0, -0.03, 0.04), V3(0, -0.1, 0.038), V3(0, -0.122, 0.034)]
        let path = catmull(ctrl, per: 4).map { V3(hx, hy, hz) + $0 }
        let radii = path.indices.map { i -> Float in let t = Float(i) / Float(path.count - 1); return t < 0.2 ? 0.0085 : 0.0095 - t * 0.002 }
        rig.add(Prim.tube(path, radii: radii, sides: 14, seamTile: 0.05, material: handleMaterial), to: "handle")
        rig.add(Prim.cylinder(radius: 0.011, height: 0.012, bevel: 0.002, segments: 18, bevelSegments: 1, material: handleMaterial),
                Xform(translation: V3(hx, hy, hz + 0.006), rotation: facing(V3(0, 0, 1))), to: "handle")

        groundAO(&rig, height: 0.06, floor: 0.75)
        rig.states = [RigState("closed"), RigState("tilted", ["tilt": 12, "handle": 180]), RigState("open", ["sash": -90, "handle": 90])]
        return rig
    }
}
