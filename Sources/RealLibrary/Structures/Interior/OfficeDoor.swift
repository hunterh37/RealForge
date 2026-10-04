import simd
import Foundation

/// Interior office door set, 2.1 m x 0.92 m leaf: 44 mm flush oak-veneer leaf with solid hardwood
/// lippings, pressed anodized-aluminum frame (50 mm architraves both faces, soffit, rebated stop with
/// EPDM seal) set in a 100 mm wall, three stainless butt hinges with knuckles split between frame and
/// leaf, stainless return-to-door levers on round roses both faces, euro-profile escutcheons, latch
/// and strike, stainless kick plate. Sits in a wall opening: base y = 0, centered, depth along Z,
/// the leaf opens toward +Z about its left hinges.
public struct OfficeDoor: RealArticulated {
    public static let id = "office-door"
    public static let summary = "Office door set: flush oak-veneer leaf in an anodized frame, stainless butt hinges, lever handles on roses, latch and kick plate."
    public static let tags = ["structure", "interior", "door", "wood", "articulated"]
    public static let budget = 16_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 6, distance: 1.05, studio: true)

    public var leafWidth: Float = 0.92
    public var leafHeight: Float = 2.1
    public var leafThickness: Float = 0.044
    /// Frame depth (wall thickness plus architraves).
    public var depth: Float = 0.12
    public var leafMaterial: MaterialKey = "wood.veneer-oak"
    public var lippingMaterial: MaterialKey = "wood.oak"
    public var frameMaterial: MaterialKey = "metal.anodized"
    public var hardware: MaterialKey = "metal.stainless"
    public var kickPlate = true
    /// Lever height above the floor (m).
    public var handleHeight: Float = 1.05
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [9])
        let W = leafWidth, H = leafHeight, T = leafThickness, D = depth
        let gap: Float = 0.003, undercut: Float = 0.008
        let xo = W / 2 + gap                         // soffit plane (clear opening half width)
        let headY = undercut + H + gap               // head soffit
        let arch: Float = 0.05, archT: Float = 0.012, soffitT: Float = 0.014
        let zf = D / 2 - 0.004                       // leaf front face
        let zb = zf - T                              // leaf back face (against the stop seal)
        let stopW: Float = 0.015
        let dark: MaterialKey = "rubber"
        let ss = hardware

        func box(_ size: V3, _ c: V3, _ mat: MaterialKey, r: Float = 0.002, seg: Int = 2) -> (Surface, Xform) {
            (Prim.roundedBox(size, radius: r, bevelSegments: seg, material: mat), Xform(translation: c))
        }
        /// Box whose ±Z and ±X faces carry vertical grain (U along Y): built lying along X, stood up.
        func vbox(_ size: V3, _ c: V3, _ mat: MaterialKey, r: Float) -> (Surface, Xform) {
            (Prim.roundedBox(V3(size.y, size.x, size.z), radius: r, bevelSegments: 2, material: mat),
             Xform(translation: c, rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        }

        // MARK: frame (static)
        for l in 0..<2 {
            var m = Model(name: Self.id)
            func add(_ b: (Surface, Xform)) { m.add(b.0, b.1) }
            let jambH = headY + soffitT
            for sx: Float in [-1, 1] {
                // Soffit across the wall, architraves on both wall faces.
                add(box(V3(soffitT, jambH, D - 2 * archT + 0.002), V3(sx * (xo + soffitT / 2), jambH / 2, 0), frameMaterial, r: 0.0015, seg: 1))
                for sz: Float in [-1, 1] {
                    add(box(V3(arch, headY + arch, archT), V3(sx * (xo + arch / 2), (headY + arch) / 2, sz * (D / 2 - archT / 2)), frameMaterial, r: 0.003))
                }
                // Rebated stop behind the leaf with its EPDM seal.
                let stopD = zb - 0.003 - (-D / 2 + archT)
                add(box(V3(stopW, headY, stopD), V3(sx * (xo - stopW / 2), headY / 2, -D / 2 + archT + stopD / 2), frameMaterial, r: 0.0015))
                if l == 0 {
                    add(box(V3(0.006, headY - 0.01, 0.004), V3(sx * (xo - 0.005), headY / 2, zb - 0.0018), dark, r: 0.0015, seg: 1))
                }
            }
            // Head: soffit, architraves, stop, seal.
            add(box(V3(2 * xo + 0.002, soffitT, D - 2 * archT + 0.002), V3(0, headY + soffitT / 2, 0), frameMaterial, r: 0.0015, seg: 1))
            for sz: Float in [-1, 1] {
                add(box(V3(2 * (xo + arch) - 0.001, arch, archT), V3(0, headY + arch / 2, sz * (D / 2 - archT / 2)), frameMaterial, r: 0.003))
            }
            let stopD = zb - 0.003 - (-D / 2 + archT)
            add(box(V3(2 * xo, stopW, stopD), V3(0, headY - stopW / 2, -D / 2 + archT + stopD / 2), frameMaterial, r: 0.0015))
            if l == 0 {
                add(box(V3(2 * xo - 0.02, 0.006, 0.004), V3(0, headY - 0.005, zb - 0.0018), dark, r: 0.0015, seg: 1))
                // Strike plate and latch pocket on the lock jamb.
                add(box(V3(0.002, 0.11, 0.024), V3(xo + 0.0005, handleHeight, zb + T / 2), ss, r: 0.0008, seg: 1))
                add(box(V3(0.003, 0.022, 0.014), V3(xo + 0.0012, handleHeight, zb + T / 2), "plastic.black", r: 0.001, seg: 1))
            }
            rig.base[l] = m
        }

        // MARK: leaf
        let hingeX = -xo + 0.0005, hingeZ = zf + 0.0015
        rig.part("leaf", pivot: V3(hingeX, 0, hingeZ), joint: .hinge(axis: .up, -100...0, duration: 1.4))
        let lip: Float = 0.008
        let leafY = undercut + H / 2
        let core = vbox(V3(W - 2 * lip + 0.002, H - 2 * lip + 0.002, T), V3(0, leafY, zb + T / 2), leafMaterial, r: 0.0015)
        rig.add(core.0, core.1, to: "leaf")
        for sx: Float in [-1, 1] {
            let e = vbox(V3(lip, H, T), V3(sx * (W / 2 - lip / 2), leafY, zb + T / 2), lippingMaterial, r: 0.0025)
            rig.add(e.0, e.1.jittered(&rng, deg: 0.0, offset: 0.0001), to: "leaf")
        }
        for sy: Float in [-1, 1] {
            let e = box(V3(W - 2 * lip, lip, T - 0.001), V3(0, leafY + sy * (H / 2 - lip / 2), zb + T / 2), lippingMaterial, r: 0.002)
            rig.add(e.0, e.1, to: "leaf")
        }
        if kickPlate {
            let kp = box(V3(W - 0.05, 0.15, 0.0015), V3(0, undercut + 0.012 + 0.075, zf + 0.00075), ss, r: 0.0007, seg: 1)
            rig.add(kp.0, kp.1, to: "leaf")
            let kb = box(V3(W - 0.05, 0.15, 0.0015), V3(0, undercut + 0.012 + 0.075, zb - 0.00075), ss, r: 0.0007, seg: 1)
            rig.add(kb.0, kb.1, to: "leaf")
        }

        // MARK: hinges (100 mm butt hinges, 5 knuckles: frame 1,3,5 / leaf 2,4)
        let knR: Float = 0.0068, hingeLen: Float = 0.1
        let hingeYs: [Float] = [undercut + 0.2, undercut + H - 0.25, undercut + H - 0.25 - 0.2]
        for hy in hingeYs {
            let seg = hingeLen / 5
            for k in 0..<5 {
                let y0 = hy - hingeLen / 2 + Float(k) * seg + 0.0004
                let s = Prim.cylinder(radius: knR, height: seg - 0.0008, bevel: 0.0008, segments: 16, bevelSegments: 1, material: ss)
                let x = Xform(translation: V3(hingeX, y0, hingeZ))
                if k % 2 == 0 { rig.base[0].add(s, x); rig.base[1].add(s, x) } else { rig.add(s, x, to: "leaf") }
            }
            // Finials top and bottom on the frame knuckles.
            for (fy, flip) in [(hy + hingeLen / 2, false), (hy - hingeLen / 2, true)] {
                let f = Prim.lathe([V2(0, 0), V2(knR * 0.98, 0), V2(knR * 0.8, 0.003), V2(knR * 0.45, 0.0055), V2(0, 0.0062)], segments: 16, seamTile: 0.05, material: ss)
                rig.base[0].add(f, Xform(translation: V3(hingeX, fy, hingeZ), rotation: flip ? simd_quatf(degrees: 180, axis: V3(1, 0, 0)) : .identity))
            }
            // Leaves of the hinge: frame plate on the soffit, leaf plate in the leaf edge (fill the 3 mm gap).
            rig.base[0].add(cuboid(V3(0.0025, hingeLen - 0.002, 0.026), material: ss), Xform(translation: V3(-xo + 0.0012, hy, hingeZ - 0.016)))
            rig.add(cuboid(V3(0.0025, hingeLen - 0.002, 0.026), material: ss), Xform(translation: V3(-W / 2 - 0.0012, hy, hingeZ - 0.016)), to: "leaf", lods: 0...0)
        }

        // MARK: lever handles, roses, escutcheons, latch
        let hx = W / 2 - 0.06    // 60 mm backset
        let hy = handleHeight
        let roseFront = zf, roseBack = zb
        rig.part("handle", parent: "leaf", pivot: V3(hx, hy, zb + T / 2), joint: .hinge(axis: V3(0, 0, -1), -45...0, duration: 0.35))
        rig.part("latch", parent: "leaf", pivot: V3(W / 2, hy, zb + T / 2),
                 joint: Joint(.prismatic, axis: V3(1, 0, 0), range: -0.012...0, mimic: .init("handle", ratio: 0.0003)))
        for side: Float in [1, -1] {
            let face = side > 0 ? roseFront : roseBack
            let n = V3(0, 0, side)
            // Round rose (52 mm) and escutcheon (52 mm, 72 mm below) with euro cylinder.
            let roseProfile = [V2(0, 0), V2(0.026, 0), V2(0.026, 0.0045), V2(0.0245, 0.0085), V2(0.021, 0.0098), V2(0, 0.0098)]
            let rose = Prim.lathe(roseProfile, segments: 36, seamTile: 0.05, material: ss)
            rig.add(rose, Xform(translation: V3(hx, hy, face), rotation: facing(n)), to: "leaf")
            rig.add(rose, Xform(translation: V3(hx, hy - 0.072, face), rotation: facing(n)), to: "leaf")
            let cyl = Prim.cylinder(radius: 0.0085, height: 0.0035, bevel: 0.001, segments: 20, bevelSegments: 1, material: ss)
            rig.add(cyl, Xform(translation: V3(hx, hy - 0.072, face + side * 0.0095), rotation: facing(n)), to: "leaf", lods: 0...0)
            // Keyway: profile-cylinder slot.
            rig.add(Prim.roundedBox(V3(0.0026, 0.011, 0.002), radius: 0.0008, bevelSegments: 1, material: "plastic.black"),
                    Xform(translation: V3(hx, hy - 0.074, face + side * 0.0131)), to: "leaf", lods: 0...0)
            // Lever: 19 mm return-to-door, pointing toward the hinge side.
            let s = side
            let ctrl: [V3] = [V3(0, 0, 0.004), V3(0, 0, 0.03), V3(-0.006, 0, 0.05), V3(-0.03, 0, 0.06),
                              V3(-0.09, 0, 0.0615), V3(-0.125, 0, 0.058), V3(-0.137, 0, 0.044)]
            let path = catmull(ctrl, per: 4).map { V3(hx + $0.x, hy + $0.y, face + s * $0.z) }
            let radii = path.indices.map { i -> Float in
                let t = Float(i) / Float(path.count - 1)
                return t < 0.15 ? 0.0085 : (t > 0.93 ? 0.0095 - (t - 0.93) * 0.05 : 0.0095)
            }
            rig.add(Prim.tube(path, radii: radii, sides: 16, seamTile: 0.05, material: ss), to: "handle")
            // Collar on the rose.
            rig.add(Prim.cylinder(radius: 0.011, height: 0.008, bevel: 0.002, segments: 20, bevelSegments: 1, material: ss),
                    Xform(translation: V3(hx, hy, face + s * 0.008), rotation: facing(n)), to: "handle")
        }
        // Latch bolt (projects 12 mm into the strike) with its forend on the lock edge.
        let fe = box(V3(0.0025, 0.2, 0.022), V3(W / 2 + 0.0008, hy - 0.036, zb + T / 2), ss, r: 0.0008, seg: 1)
        rig.add(fe.0, fe.1, to: "leaf", lods: 0...0)
        rig.add(Prim.roundedBox(V3(0.013, 0.018, 0.012), radius: 0.002, bevelSegments: 1, material: ss),
                Xform(translation: V3(W / 2 + 0.0045, hy, zb + T / 2)), to: "latch", lods: 0...0)

        groundAO(&rig, height: 0.15, floor: 0.6)
        rig.states = [RigState("closed"), RigState("ajar", ["leaf": -20]), RigState("open", ["leaf": -90]),
                      RigState("unlatched", ["handle": -40])]
        return rig
    }
}
