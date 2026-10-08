import simd
import Foundation

/// Main-street storefront bay, 3.0 m: painted cast-iron pilasters on stone bases, 0.45 m paneled
/// wood bulkhead, clear-anodized aluminum display framing with a vertical mullion, glazed aluminum
/// entry door (push bar, pull handle, closer), transom lights over the full width, a sign band with
/// a blank fascia board and a projecting cornice. Exterior faces +Z, base y = 0 is the sidewalk.
/// The door swings inward on its right-hand hinge stile.
public struct StorefrontBay: RealArticulated {
    public static let id = "storefront-bay"
    public static let summary = "Storefront bay, 3 m: 0.45 m paneled bulkhead, aluminum-framed glazing with an entry door, transom lights and a sign band with cornice."
    public static let tags = ["structure", "architecture", "facade", "door", "window", "metal", "glass", "urban", "articulated"]
    public static let budget = 24_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 6, distance: 1.0, studio: true)

    /// Bay width, pilaster outside to outside (m).
    public var width: Float = 3.0
    /// Bulkhead height (m).
    public var bulkhead: Float = 0.45
    /// Top of the display glass (m).
    public var glassTop: Float = 2.75
    /// Transom light height (m).
    public var transom: Float = 0.4
    /// Sign band height (m).
    public var signBand: Float = 0.5
    /// Entry door width (m); 0 makes the whole bay a display window.
    public var doorWidth: Float = 0.95
    /// Display lites across (split by mullions).
    public var displayLites: Int = 2
    public var woodMaterial: MaterialKey = "wood.painted-exterior:213A33"
    public var ironMaterial: MaterialKey = "metal.painted:213A33"
    public var frameMaterial: MaterialKey = "metal.anodized"
    public var signMaterial: MaterialKey = "wood.painted-exterior:E3D7B8"
    public var stoneMaterial: MaterialKey = "stone.cast-grey"
    public var glass: MaterialKey = "glass.pane"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [12])
        let W = width, pw: Float = 0.26, L = W - 2 * pw
        let zf: Float = 0.0, fd: Float = 0.1, fw: Float = 0.045     // aluminum face, depth, face width
        let yT = glassTop, yS = yT + transom, yC = yS + signBand
        let dw = doorWidth, dx1 = L / 2, dx0 = dw > 0 ? dx1 - dw : dx1
        let al = frameMaterial, wood = woodMaterial

        var st: [Surface] = []
        // Pilasters: stone base, iron shaft with recessed panel and rosettes, capital block.
        for sx: Float in [-1, 1] {
            let x = sx * (L / 2 + pw / 2)
            st.append(HK.box(V3(pw + 0.04, 0.3, 0.32), V3(x, 0.15, zf + 0.02), stoneMaterial, r: 0.01))
            st.append(FK.vbox(V3(pw, yS - 0.3, 0.26), V3(x, 0.3 + (yS - 0.3) / 2, zf), ironMaterial, r: 0.006))
            st.append(FK.vbox(V3(pw - 0.08, yS - 0.8, 0.02), V3(x, 0.55 + (yS - 0.8) / 2, zf + 0.135), ironMaterial, r: 0.008))
            for ry in [0.45, yS - 0.2] {
                st.append(Prim.lathe([V2(0, 0), V2(0.05, 0), V2(0.045, 0.012), V2(0.02, 0.025), V2(0, 0.028)], segments: 16, seamTile: 0.05, material: ironMaterial)
                    .transformed(Xform(translation: V3(x, ry, zf + 0.13), rotation: facing(V3(0, 0, 1)))))
            }
            st.append(HK.box(V3(pw + 0.06, 0.12, 0.32), V3(x, yS + 0.06 - 0.12, zf + 0.03), ironMaterial, r: 0.012))
        }
        // Bulkhead under the display (raised panels), sill cap, kick at the sidewalk.
        let bx0 = -L / 2, bx1 = dw > 0 ? dx0 - fw : L / 2
        let bl = bx1 - bx0, bc = (bx0 + bx1) / 2
        st.append(HK.box(V3(bl, bulkhead, 0.12), V3(bc, bulkhead / 2, zf - 0.02), wood, r: 0.004))
        let np = max(1, Int((bl / 0.6).rounded()))
        for i in 0..<np {
            let cx = bx0 + bl * (Float(i) + 0.5) / Float(np)
            st += FK.raisedPanel(w: bl / Float(np) - 0.1, h: bulkhead - 0.16, t: 0.04, at: V3(cx, bulkhead / 2 + 0.01, zf + 0.04), mat: wood, raise: 0.03)
        }
        st.append(HK.box(V3(bl + 0.02, 0.05, 0.16), V3(bc, bulkhead + 0.025, zf), wood, r: 0.01))
        st.append(HK.box(V3(bl, 0.08, 0.13), V3(bc, 0.04, zf - 0.005), stoneMaterial, r: 0.006))

        // Aluminum storefront: sill, head, jambs, mullions, transom bar, transom mullions.
        let gy0 = bulkhead + 0.05
        st.append(HK.box(V3(bl, fw, fd), V3(bc, gy0 + fw / 2, zf), al, r: 0.002))
        st.append(HK.box(V3(L, fw, fd), V3(0, yT + fw / 2, zf), al, r: 0.002))
        st.append(HK.box(V3(L, fw, fd), V3(0, yS - fw / 2, zf), al, r: 0.002))
        var mx: [Float] = [-L / 2 + fw / 2]
        for i in 1..<max(1, displayLites) { mx.append(bx0 + bl * Float(i) / Float(displayLites)) }
        if dw > 0 { mx.append(dx0 - fw / 2) }
        mx.append(L / 2 - fw / 2)
        for x in mx {
            let y0: Float = (dw > 0 && x > dx0 - fw) ? 0 : gy0
            st.append(FK.vbox(V3(fw, yT - y0, fd), V3(x, y0 + (yT - y0) / 2, zf), al, r: 0.002))
        }
        // Display glass between mullions.
        let dispX = mx.filter { $0 <= (dw > 0 ? dx0 : L / 2) }
        for i in 0..<(dispX.count - 1) {
            let a = dispX[i] + fw / 2, b = dispX[i + 1] - fw / 2
            st.append(HK.box(V3(b - a + 0.01, yT - gy0 - fw + 0.01, 0.01), V3((a + b) / 2, gy0 + fw + (yT - gy0 - fw) / 2, zf), glass, r: 0.001, seg: 1))
        }
        // Transom lites across the full width.
        let nt = max(2, Int((L / 0.8).rounded()))
        for i in 0..<nt {
            let a = -L / 2 + L * Float(i) / Float(nt), b = a + L / Float(nt)
            if i > 0 { st.append(FK.vbox(V3(fw * 0.8, transom - 2 * fw, fd), V3(a, yT + transom / 2, zf), al, r: 0.002)) }
            st.append(HK.box(V3(b - a - 0.01, transom - 2 * fw + 0.01, 0.01), V3((a + b) / 2, yT + transom / 2, zf), glass, r: 0.001, seg: 1))
        }
        // Sign band: framed fascia board, cornice with dentil-like blocks.
        st.append(HK.box(V3(W, signBand, 0.18), V3(0, yS + signBand / 2, zf - 0.02), wood, r: 0.006))
        st.append(HK.box(V3(W - 2 * pw + 0.1, signBand - 0.12, 0.03), V3(0, yS + signBand / 2, zf + 0.085), signMaterial, r: 0.005))
        st.append(HK.box(V3(W - 2 * pw + 0.16, 0.035, 0.05), V3(0, yS + 0.04, zf + 0.09), wood, r: 0.012))
        st.append(HK.box(V3(W - 2 * pw + 0.16, 0.035, 0.05), V3(0, yC - 0.04, zf + 0.09), wood, r: 0.012))
        var cy = yC, depthC: Float = 0.24
        for (h, d) in [(Float(0.05), Float(0.26)), (0.08, 0.32), (0.06, 0.38)] {
            st.append(HK.box(V3(W + (d - 0.2) * 1.2, h, d), V3(0, cy + h / 2, zf - 0.11 + d / 2), wood, r: 0.012))
            cy += h; depthC = d
        }
        _ = depthC
        for i in 0..<14 {
            let x = -W / 2 + 0.12 + (W - 0.24) * Float(i) / 13
            st.append(HK.box(V3(0.06, 0.12, 0.12), V3(x, yC - 0.02, zf + 0.12), wood, r: 0.006))
        }
        rig.addBase(st)

        // MARK: entry door (glazed aluminum, hinge on the right jamb, swings in)
        if dw > 0 {
            let leafW = dw - fw - 0.006, leafH = yT - 0.012
            let hx = dx1 - fw - 0.001, hz = zf - fd / 2 + 0.002
            rig.part("door", pivot: V3(hx, 0, hz), joint: .hinge(axis: .up, -95...0, duration: 1.3))
            let cx = hx - leafW / 2 - 0.002, t: Float = 0.045
            let dz = zf
            var d: [Surface] = []
            let stile: Float = 0.1, top: Float = 0.1, bot: Float = 0.25
            for sx: Float in [-1, 1] { d.append(FK.vbox(V3(stile, leafH, t), V3(cx + sx * (leafW / 2 - stile / 2), 0.006 + leafH / 2, dz), al, r: 0.002)) }
            d.append(HK.box(V3(leafW - 2 * stile + 0.002, bot, t), V3(cx, 0.006 + bot / 2, dz), al, r: 0.002))
            d.append(HK.box(V3(leafW - 2 * stile + 0.002, top, t), V3(cx, 0.006 + leafH - top / 2, dz), al, r: 0.002))
            d.append(HK.box(V3(leafW - 2 * stile + 0.01, leafH - top - bot + 0.01, 0.01), V3(cx, 0.006 + bot + (leafH - top - bot) / 2, dz), glass, r: 0.001, seg: 1))
            // Push bar across the glass (exterior), offset pull handle, closer arm inside.
            d.append(HK.cyl(r: 0.014, len: leafW - 2 * stile, at: V3(cx, 1.0, dz + t / 2 + 0.05), axis: V3(1, 0, 0), mat: "metal.stainless", seg: 12))
            for sx: Float in [-1, 1] {
                d.append(HK.pipe([V3(cx + sx * (leafW / 2 - stile / 2), 1.0, dz + t / 2), V3(cx + sx * (leafW / 2 - stile / 2), 1.0, dz + t / 2 + 0.05)], r: 0.01, sides: 8, mat: "metal.stainless"))
            }
            d.append(HK.box(V3(0.3, 0.06, 0.05), V3(hx - 0.2, leafH - 0.04, dz - t / 2 - 0.03), al, r: 0.006))
            d.append(HK.box(V3(0.03, 0.08, 0.02), V3(cx - leafW / 2 + 0.05, 1.0, dz + t / 2 + 0.01), al, r: 0.004))
            for s in d { rig.add(s, Xform.identity.jittered(&rng, deg: 0, offset: 0.0001), to: "door") }
        }

        groundAO(&rig, height: 0.15, floor: 0.6)
        rig.states = [RigState("closed"), RigState("ajar", ["door": -25]), RigState("open", ["door": -90])]
        return rig
    }
}
