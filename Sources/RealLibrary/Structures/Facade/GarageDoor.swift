import simd
import Foundation

/// Sectional garage door, 2.4 x 2.1 m: four 45 mm insulated steel sections with pressed raised
/// panels (optional glazed top section), section hinges and rollers on the back, vertical and
/// horizontal tracks inside, painted jamb and head trim with stop molding, rubber bottom seal,
/// exterior lift handle and T-handle lock. Exterior faces +Z, base y = 0 is the floor. The door
/// swings up and in about its head until it lies flat on the horizontal tracks under the ceiling.
public struct GarageDoor: RealArticulated {
    public static let id = "garage-door"
    public static let summary = "Sectional garage door, 2.4 x 2.1 m: four insulated steel sections with raised panels, hinges, rollers in tracks, trim, lift handle and seal."
    public static let tags = ["structure", "architecture", "facade", "door", "metal", "articulated"]
    public static let budget = 17_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 8, distance: 1.0, studio: true)

    /// Door width (m).
    public var width: Float = 2.4
    /// Door height (m).
    public var height: Float = 2.1
    /// Number of horizontal sections.
    public var sections: Int = 4
    /// Raised panels per section.
    public var panelsPerSection: Int = 4
    /// Glass lites in the top section instead of panels.
    public var glazedTop = true
    /// Horizontal tracks back into the garage (adds about 2.3 m of depth).
    public var horizontalTracks = false
    public var doorMaterial: MaterialKey = "metal.powder-white"
    /// Bottom section skin: road splash and scuffs.
    public var bottomMaterial: MaterialKey = "metal.painted:DDDAD0"
    /// Backdrop behind the top lites (garage interior in shadow).
    public var interiorMaterial: MaterialKey = "plastic.matte:2A2724"
    public var trimMaterial: MaterialKey = "wood.painted-exterior"
    public var trackMaterial: MaterialKey = "metal.galvanized"
    public var glass: MaterialKey = "glass.clear"
    public var sealMaterial: MaterialKey = "rubber"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [12])
        let W = width, H = height, T: Float = 0.045
        let zf: Float = 0.067, zb = zf - T                      // door faces (exterior wall face at z = 0.02)
        let hs = H / Float(sections)

        // MARK: trim and tracks (static)
        var st: [Surface] = []
        let tw: Float = 0.14, tt: Float = 0.035
        for sx: Float in [-1, 1] {
            st.append(FK.vbox(V3(tw, H + tw, tt), V3(sx * (W / 2 + tw / 2 - 0.02), (H + tw) / 2, zf + 0.012 + tt / 2), trimMaterial, r: 0.004))
            // Stop molding against the door face.
            st.append(FK.vbox(V3(0.03, H, 0.02), V3(sx * (W / 2 - 0.005), H / 2, zf + 0.012), trimMaterial, r: 0.005))
            // Vertical track: angle and channel behind the jamb.
            st.append(FK.vbox(V3(0.05, H - 0.1, 0.003), V3(sx * (W / 2 + 0.01), (H - 0.1) / 2 + 0.05, zb - 0.03), trackMaterial, r: 0.001))
            st.append(FK.vbox(V3(0.003, H - 0.1, 0.05), V3(sx * (W / 2 + 0.035), (H - 0.1) / 2 + 0.05, zb - 0.055), trackMaterial, r: 0.001))
            if horizontalTracks {
                let ty = H + 0.08
                st.append(HK.box(V3(0.003, 0.05, 2.3), V3(sx * (W / 2 + 0.035), ty, zb - 0.055 - 1.15), trackMaterial, r: 0.001, seg: 1))
                st.append(HK.box(V3(0.05, 0.003, 2.3), V3(sx * (W / 2 + 0.01), ty - 0.025, zb - 0.055 - 1.15), trackMaterial, r: 0.001, seg: 1))
                // Hanger strap at the back.
                st.append(HK.box(V3(0.04, 0.4, 0.004), V3(sx * (W / 2 + 0.035), ty + 0.2, zb - 2.3), trackMaterial, r: 0.001, seg: 1))
            }
        }
        st.append(HK.box(V3(W + 2 * tw - 0.04, tw, tt), V3(0, H + tw / 2, zf + 0.012 + tt / 2), trimMaterial, r: 0.004))
        st.append(HK.box(V3(W, 0.03, 0.02), V3(0, H + 0.015, zf + 0.012), trimMaterial, r: 0.005))
        // Torsion spring tube over the head (inside).
        st.append(HK.cyl(r: 0.025, len: W, at: V3(0, H + 0.07, zb - 0.12), axis: V3(1, 0, 0), mat: trackMaterial, seg: 16))
        st.append(Prim.helix(radius: 0.032, pitch: 0.008, turns: 26, wire: 0.004, perTurn: 12, sides: 6, material: "metal.steel")
            .transformed(Xform(translation: V3(0.05, H + 0.07, zb - 0.12), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1)))))
        rig.addBase(st)
        rig.base[1].surfaces.removeAll { $0.material == "metal.steel" }

        // MARK: door (single leaf of hinged sections)
        rig.part("door", pivot: V3(0, H, zb - 0.03), joint: .hinge(axis: V3(1, 0, 0), 0...88, duration: 3.0))
        var d: [Surface] = []
        let gap: Float = 0.004
        let pw = (W - 0.16) / Float(panelsPerSection)
        for i in 0..<sections {
            let y0 = Float(i) * hs + gap / 2, h = hs - gap
            let top = i == sections - 1
            // Section skin with a tongue-and-groove profile hinted by a rounded top edge.
            let skin = i == 0 ? bottomMaterial : doorMaterial
            d.append(HK.box(V3(W, h, T), V3(0, y0 + h / 2, zb + T / 2), skin, r: 0.008, seg: 2))
            for p in 0..<panelsPerSection {
                let cx = -W / 2 + 0.08 + pw * (Float(p) + 0.5)
                if top && glazedTop {
                    d.append(HK.box(V3(pw - 0.06, h - 0.16, 0.006), V3(cx, y0 + h / 2, zf + 0.0045), glass, r: 0.002, seg: 1))
                    // Dark garage interior seen through the lite.
                    d.append(HK.box(V3(pw - 0.07, h - 0.17, 0.003), V3(cx, y0 + h / 2, zf + 0.0012), interiorMaterial, r: 0.001, seg: 1))
                    d.append(Prim.extrude(Shape2D.roundedRect(pw - 0.03, h - 0.13, radius: 0.01), depth: 0.012, bevel: 0.004, bevelSegments: 1, material: "plastic.black")
                        .transformed(Xform(translation: V3(cx, y0 + h / 2, zf - 0.003))))
                } else {
                    // Pressed raised panel: chamfered field proud of the skin.
                    d.append(Prim.extrude(Shape2D.rect(pw - 0.05, h - 0.14), depth: 0.026, bevel: 0.011, bevelSegments: 2, material: skin)
                        .transformed(Xform(translation: V3(cx, y0 + h / 2, zf - 0.002))))
                }
            }
            if i > 0 {
                // Section hinges and roller brackets on the back.
                for k in 0...3 {
                    let x = -W / 2 + 0.05 + (W - 0.1) * Float(k) / 3
                    d.append(HK.box(V3(0.06, 0.1, 0.006), V3(x, Float(i) * hs, zb - 0.003), trackMaterial, r: 0.002, seg: 1))
                }
            }
            for sx: Float in [-1, 1] {
                let ry = Float(i) * hs + (i == 0 ? 0.08 : 0)
                d.append(HK.cyl(r: 0.022, len: 0.012, at: V3(sx * (W / 2 + 0.02), ry, zb - 0.055), axis: V3(1, 0, 0), mat: "plastic.white", seg: 16))
                d.append(HK.cyl(r: 0.005, len: 0.06, at: V3(sx * (W / 2 - 0.01), ry, zb - 0.055), axis: V3(1, 0, 0), mat: trackMaterial, seg: 8))
            }
        }
        // Bottom seal, lift handle, T-lock.
        d.append(HK.box(V3(W - 0.004, 0.012, T * 0.8), V3(0, 0.004, zb + T / 2), sealMaterial, r: 0.005, seg: 1))
        d.append(barHandle(length: 0.16, standoff: 0.03, radius: 0.007, material: "metal.stainless")
            .transformed(Xform(translation: V3(0.25, hs * 0.55, zf + 0.002))))
        d.append(Prim.cylinder(radius: 0.025, height: 0.006, bevel: 0.002, segments: 20, bevelSegments: 1, material: "metal.stainless")
            .transformed(Xform(translation: V3(0, hs * 0.55, zf), rotation: facing(V3(0, 0, 1)))))
        d.append(HK.box(V3(0.09, 0.016, 0.014), V3(0, hs * 0.55, zf + 0.016), "metal.stainless", r: 0.006))
        for s in d { rig.add(s, Xform.identity.jittered(&rng, deg: 0, offset: 0.0001), to: "door") }

        groundAO(&rig, height: 0.15, floor: 0.6)
        rig.states = [RigState("closed"), RigState("vent", ["door": 12]), RigState("open", ["door": 88])]
        return rig
    }
}
