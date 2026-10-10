import simd
import Foundation

/// Vintage naturalist crossbody satchel, 28 x 21 x 9 cm: oiled saddle-tan full-grain leather body with
/// a slight bulge and rounded bottom corners, open top with lined inner walls and a suede floor,
/// welted gusset seams with waxed saddle stitching, burnished edges, a front flap with a buckled
/// tongue strap, brass rivets and brass D-rings at both top sides.
///
/// Origin at the bottom centre of the body, +Y up, front toward +Z. Parts (entities `joint:<name>`):
/// `body` (fixed, holds the body), `flap` (hinged on the top back edge, opens up and back),
/// `floor` (marker at the top of the lining floor), `lug-l` / `lug-r` (markers at the D-ring centres).
public struct CrossbodyBag: RealArticulated {
    public static let id = "crossbody-bag"
    public static let summary = "Naturalist crossbody satchel, 28 x 21 x 9 cm: saddle-tan leather gusseted body, open top with suede floor, buckled flap, brass D-rings; articulated flap."
    public static let tags = ["prop", "leather", "antique", "container", "articulated"]
    public static let budget = 13300
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 28, distance: 0.9, studio: true)

    /// Body width (x), height (y) and depth (z) in meters.
    public var size = V3(0.28, 0.21, 0.09)
    /// Outer leather.
    public var leather: MaterialKey = "leather.oxblood-worn:8E5228"
    /// Flap and tongue strap (handled most, worn variant).
    public var flapLeather: MaterialKey = "leather.oxblood-worn:8E5228"
    /// Burnished edges and welts.
    public var edge: MaterialKey = "leather.oxblood:3A2212"
    /// Suede lining (inner walls and floor).
    public var lining: MaterialKey = "leather.split-tan:3A2A1E"
    /// Waxed saddle thread.
    public var thread: MaterialKey = "fabric.linen:E6D7B0"
    /// Buckle, rivets and D-rings.
    public var brass: MaterialKey = "metal.brass-aged"
    /// Flap angle of the `open` state in degrees.
    public var openAngle: Float = 150
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3])
        let W = size.x, H = size.y, D = size.z
        let rc: Float = 0.045, rb: Float = 0.012, rr: Float = 0.016, wall: Float = 0.0035
        let bulge = rng.float(0.8...1.2)
        func half(_ y: Float) -> (Float, Float) {
            let yy = min(max(y, 0), H)
            var w = W / 2 + 0.002 * bulge * sin(.pi * yy / H)
            if yy < rc { w -= rc - sqrt(max(0, rc * rc - (rc - yy) * (rc - yy))) }
            var d = D / 2 * (0.9 + 0.1 * bulge * sin(.pi * yy / H))
            if yy < rb { d -= rb - sqrt(max(0, rb * rb - (rb - yy) * (rb - yy))) }
            return (w, d)
        }
        func wr(_ y: Float) -> Float { half(y).0 }
        func dr(_ y: Float) -> Float { half(y).1 }

        // Key heights and depths.
        let floorY: Float = 0.007, floorTop: Float = 0.0105
        let rimHalf: Float = 0.00225
        let ft: Float = 0.003                                     // flap leather
        let rbf: Float = 0.009                                    // flap bend radius
        let yT = H + rimHalf + ft / 2 + 0.0004                    // flap top mid-surface
        let zB = -(dr(H) + ft / 2 + 0.0003)                       // flap back mid-surface
        let zF = D / 2 * (0.9 + 0.1 * bulge) + 0.0035             // flap front mid-surface
        let yHinge = yT - rbf
        let yJ = yT - rbf - 0.006
        let yTip = rng.float(0.082...0.088)
        let Wf = 2 * wr(H) + 0.008
        let xr = wr(H) + 0.0018 + 0.0035                          // D-ring plane
        let ringY = H + 0.0075

        rig.part("body", pivot: .zero, joint: .fixed)
        rig.part("flap", parent: "body", pivot: V3(0, yHinge, zB), joint: .hinge(axis: V3(-1, 0, 0), 0...165, duration: 0.7))
        rig.part("floor", parent: "body", pivot: V3(0, floorTop, 0), joint: .fixed)
        rig.part("lug-l", parent: "body", pivot: V3(-xr, ringY + 0.005, 0), joint: .fixed)
        rig.part("lug-r", parent: "body", pivot: V3(xr, ringY + 0.005, 0), joint: .fixed)

        // Body shell: outer loft, lined inner loft, burnished rim.
        var ys: [Float] = [0, 0.0015, 0.004, 0.008, 0.013, 0.02, 0.03, 0.045]
        var y: Float = 0.065
        while y < H - 0.01 { ys.append(y); y += 0.022 }
        ys.append(H)
        let outer = ys.map { y in Prim.ring(Shape2D.roundedRect(2 * wr(y), 2 * dr(y), radius: rr, segments: 5), y: y) }
        let innerYs = [floorY] + ys.filter { $0 > floorY + 0.002 }
        let inner = innerYs.map { y in Prim.ring(Shape2D.roundedRect(2 * (wr(y) - wall), 2 * (dr(y) - wall), radius: rr - wall, segments: 5), y: y) }
        let liningFloor = [floorY - 0.002, floorTop].map { y in
            Prim.ring(Shape2D.roundedRect(2 * (wr(floorY) - wall - 0.0008), 2 * (dr(floorY) - wall - 0.0008), radius: rr - wall, segments: 5), y: y)
        }
        let rimPath = Prim.ring(Shape2D.roundedRect(2 * (wr(H) - wall / 2), 2 * (dr(H) - wall / 2), radius: rr - wall / 2, segments: 6), y: H)

        // Seam paths: down the left corner, across the bottom, up the right corner.
        func seam(_ sz: Float, a: Float, b: Float, bottom: Float) -> [V3] {
            var side: [Float] = []
            var t: Float = H - 0.004
            while t > 0.05 { side.append(t); t -= 0.02 }
            var u: Float = 0.05
            while u > bottom { side.append(u); u -= 0.004 }
            side.append(bottom)
            let left = side.map { V3(-(wr($0) - a), $0, sz * (dr($0) - b)) }
            let right = side.reversed().map { V3(wr($0) - a, $0, sz * (dr($0) - b)) }
            return left + right
        }

        for lod in 0..<2 {
            let L = lod...lod, hi = lod == 0
            rig.add(Prim.loft(outer, capStart: true, material: leather), to: "body", lods: L)
            rig.add(Prim.loft(inner, material: lining).flipped(), to: "body", lods: L)
            rig.add(Prim.loft(liningFloor, capStart: true, capEnd: true, material: lining), to: "body", lods: L)
            rig.add(Prim.sweep(Shape2D.roundedRect(2 * rimHalf, wall + 0.0014, radius: 0.0012), along: rimPath, up: .up,
                               closedPath: true, material: edge), to: "body", lods: L)
            // Welted gusset seams, front and back.
            for sz: Float in [1, -1] {
                let w = seam(sz, a: rr * 0.293 - 0.0008, b: rr * 0.293 - 0.0008, bottom: 0.0032)
                rig.add(Prim.tube(w, radii: w.map { _ in 0.0019 }, sides: hi ? 6 : 4, seamTile: 0.02, material: edge, capEnd: true), to: "body", lods: L)
            }

            // Back strip where the flap is sewn on.
            let backPath = [V3(0, H - 0.05, -(dr(H - 0.05) + ft / 2 + 0.0003)), V3(0, H - 0.025, -(dr(H - 0.025) + ft / 2 + 0.0003)), V3(0, yHinge + 0.0004, zB)]
            rig.add(Prim.sweep(Shape2D.roundedRect(Wf - 0.05, ft, radius: 0.0013), along: backPath, up: V3(1, 0, 0), material: leather), to: "body", lods: L)

            // Buckle tab on the body front.
            let yBk = yTip - 0.028
            let tabYs: [Float] = stride(from: yBk + 0.02, through: yBk - 0.034, by: -0.009).map { $0 }
            rig.add(Prim.sweep(Shape2D.roundedRect(0.026, 0.0032, radius: 0.0012), along: tabYs.map { V3(0, $0, dr($0) + 0.0019) }, up: V3(1, 0, 0),
                               material: leather), to: "body", lods: L)
            let z3 = dr(yBk) + 0.0089
            let frame = Shape2D.roundedRect(0.034, 0.026, radius: 0.0055, segments: hi ? 4 : 2).map { V3($0.x, yBk + $0.y, z3) }
            rig.add(Prim.sweep(Shape2D.circle(0.0017, segments: hi ? 8 : 5), along: frame, closedPath: true, material: brass), to: "body", lods: L)
            rig.add(Prim.tube([V3(-0.017, yBk, z3), V3(0.017, yBk, z3)], radii: [0.0015, 0.0015], sides: hi ? 6 : 4, seamTile: 0.02, material: brass), to: "body", lods: L)

            // Side lugs: leather tab looped over a brass D-ring.
            for sx: Float in [-1, 1] {
                var p: [V3] = [V3(sx * (wr(H - 0.036) + 0.0018), H - 0.036, 0), V3(sx * (wr(H - 0.01) + 0.0018), H - 0.01, 0)]
                for k in 0...6 { let a = Float.pi * (1 - Float(k) / 6); p.append(V3(sx * (xr + cos(a) * 0.0035), ringY + sin(a) * 0.0035, 0)) }
                p.append(V3(sx * (xr + 0.0035), H - 0.022, 0))
                rig.add(Prim.sweep(Shape2D.roundedRect(0.0028, 0.02, radius: 0.0011), along: p, up: V3(1, 0, 0), material: leather), to: "body", lods: L)
                rig.add(Prim.tube([V3(sx * xr, ringY, -0.0125), V3(sx * xr, ringY, 0.0125)], radii: [0.0022, 0.0022], sides: hi ? 8 : 5, seamTile: 0.02, material: brass), to: "body", lods: L)
                let rot = simd_quatf(simd_float3x3(columns: (V3(0, 0, 1), V3(-1, 0, 0), V3(0, -1, 0))))
                rig.add(Prim.torus(major: 0.0125, minor: 0.0022, segments: hi ? 16 : 8, sides: hi ? 8 : 5, arc: .pi, material: brass),
                        Xform(translation: V3(sx * xr, ringY, 0), rotation: rot, scale: V3(1, 1, 1)), to: "body", lods: L)
            }

            // Flap: back bend, top, front bend (sweep), then a flat front drop with rounded corners.
            var fp: [V3] = []
            let nb = hi ? 7 : 3
            for k in 0...nb { let a = Float.pi - Float.pi / 2 * Float(k) / Float(nb); fp.append(V3(0, yT - rbf + sin(a) * rbf, zB + rbf + cos(a) * rbf)) }
            for k in 0...nb { let a = Float.pi / 2 - Float.pi / 2 * Float(k) / Float(nb); fp.append(V3(0, yT - rbf + sin(a) * rbf, zF - rbf + cos(a) * rbf)) }
            fp.append(V3(0, yJ, zF))
            rig.add(Prim.sweep(Shape2D.roundedRect(Wf, ft, radius: 0.0013), along: fp, up: V3(1, 0, 0), material: flapLeather), to: "flap", lods: L)
            let cr: Float = 0.03, yTop = yJ + 0.001, cs = hi ? 6 : 3
            var outline: [V2] = [V2(-Wf / 2, yTop), V2(-Wf / 2, yTip + cr)]
            for k in 1...cs { let a = Float.pi + Float.pi / 2 * Float(k) / Float(cs); outline.append(V2(-Wf / 2 + cr + cos(a) * cr, yTip + cr + sin(a) * cr)) }
            for k in 0...cs { let a = -Float.pi / 2 + Float.pi / 2 * Float(k) / Float(cs); outline.append(V2(Wf / 2 - cr + cos(a) * cr, yTip + cr + sin(a) * cr)) }
            outline.append(V2(Wf / 2, yTop))
            rig.add(Prim.extrude(outline, depth: ft, bevel: 0.0011, bevelSegments: hi ? 2 : 1, material: flapLeather),
                    Xform(translation: V3(0, 0, zF)), to: "flap", lods: L)
            // Burnished edge around the flap.
            let drop = outline.map { V3($0.x, $0.y, zF) }
            let leftSide = fp.map { V3(-Wf / 2 + 0.0004, $0.y, $0.z) }
            let rightSide = fp.reversed().map { V3(Wf / 2 - 0.0004, $0.y, $0.z) }
            let rim = leftSide + drop.dropFirst().dropLast() + rightSide
            rig.add(Prim.tube(rim, radii: rim.map { _ in 0.00165 }, sides: hi ? 6 : 4, seamTile: 0.02, material: edge), to: "flap", lods: L)

            // Tongue strap riveted to the flap, buckled through the frame.
            let zS = zF + ft / 2 + 0.0018
            var sp: [V3] = [V3(0, yTip + 0.05, zS), V3(0, yTip + 0.002, zS)]
            for yy in stride(from: yTip - 0.008, through: yBk - 0.03, by: -0.008) { sp.append(V3(0, yy, dr(yy) + 0.0053)) }
            rig.add(Prim.sweep(Shape2D.roundedRect(0.021, 0.0032, radius: 0.0013), along: sp, up: V3(1, 0, 0), material: flapLeather), to: "flap", lods: L)
            if hi {
                rig.add(Prim.tube([V3(0, yBk, z3), V3(0, yBk + 0.0145, z3 - 0.0012)], radii: [0.0011, 0.0009], sides: 5, seamTile: 0.02, material: brass), to: "body", lods: L)
            }

            guard hi else { continue }
            // Saddle stitching: body seams, back strip, flap perimeter, tongue strap.
            var bodyStitch = Model(name: "s")
            for sz: Float in [1, -1] {
                bodyStitch.add(stitches(along: seam(sz, a: rr + 0.0045, b: -0.0004, bottom: 0.006), normal: { _ in V3(0, 0, sz) }, pitch: 0.0042, thread: 0.0007, material: thread))
            }
            for sx: Float in [-1, 1] {
                if sx < 0 { bodyStitch.add(stitches(along: [V3(-(Wf / 2 - 0.035), H - 0.046, -(dr(H - 0.046) + ft + 0.0004)), V3(Wf / 2 - 0.035, H - 0.046, -(dr(H - 0.046) + ft + 0.0004))],
                                        normal: { _ in V3(0, 0, -1) }, pitch: 0.0042, thread: 0.0007, material: thread)) }
                rivet(&bodyStitch, at: V3(sx * (Wf / 2 - 0.04), H - 0.033, -(dr(H - 0.033) + ft + 0.0003)), normal: V3(0, 0, -1), radius: 0.0034, material: brass)
                rivet(&bodyStitch, at: V3(sx * (xr + 0.0035 + 0.0014), H - 0.015, 0), normal: V3(sx, 0, 0), radius: 0.003, material: brass)
                rivet(&bodyStitch, at: V3(sx * (wr(H - 0.012) - rr - 0.008), H - 0.012, dr(H - 0.012) + 0.0001), normal: V3(0, 0, 1), radius: 0.003, material: brass)
            }
            rig.add(bodyStitch, to: "body", lod: 0)

            var flapDetail = Model(name: "f")
            let inset: Float = 0.0065
            var sPath: [V3] = [V3(-Wf / 2 + inset, yTop - 0.002, zF + ft / 2 + 0.0002)]
            for k in 0...8 { let a = Float.pi + Float.pi / 2 * Float(k) / 8; sPath.append(V3(-Wf / 2 + cr + cos(a) * (cr - inset), yTip + cr + sin(a) * (cr - inset), zF + ft / 2 + 0.0002)) }
            for k in 0...8 { let a = -Float.pi / 2 + Float.pi / 2 * Float(k) / 8; sPath.append(V3(Wf / 2 - cr + cos(a) * (cr - inset), yTip + cr + sin(a) * (cr - inset), zF + ft / 2 + 0.0002)) }
            sPath.append(V3(Wf / 2 - inset, yTop - 0.002, zF + ft / 2 + 0.0002))
            flapDetail.add(stitches(along: sPath, normal: { _ in V3(0, 0, 1) }, pitch: 0.0042, thread: 0.0007, material: thread))
            for sx: Float in [-1, 1] {
                flapDetail.add(stitches(along: [V3(sx * 0.0072, yTip + 0.048, zS + 0.0017), V3(sx * 0.0072, yTip + 0.004, zS + 0.0017)],
                                        normal: { _ in V3(0, 0, 1) }, pitch: 0.004, thread: 0.0006, material: thread))
            }
            for ry in [yTip + 0.04, yTip + 0.016] { rivet(&flapDetail, at: V3(0, ry, zS + 0.0015), normal: V3(0, 0, 1), radius: 0.0036, material: brass) }
            for hy in [yBk - 0.014, yBk - 0.023] {
                flapDetail.add(Prim.cylinder(radius: 0.0016, height: 0.0008, bevel: 0.0002, segments: 8, bevelSegments: 1, material: "leather.black"),
                               Xform(translation: V3(0, hy, dr(hy) + 0.0053 + 0.0012), rotation: simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))))
            }
            rig.add(flapDetail, to: "flap", lod: 0)
        }
        rig.states = [RigState("closed"), RigState("open", ["flap": openAngle])]
        groundAO(&rig, height: 0.05, floor: 0.6)
        return rig
    }
}
