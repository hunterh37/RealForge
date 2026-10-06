import simd
import Foundation

/// 7-1/4 inch (184 mm) corded sidewinder circular saw, modeled at full depth of cut (60 mm). Tool plastic
/// motor housing with a rubber overmold band, vents and brush caps; rear loop handle with rubber grip,
/// trigger and lock-off; front assist knob; die-cast shoe with side lips, blade slot, 0 and 45 degree
/// cut-line notches; front bevel quadrant with wing nut; rear depth bracket and lever; die-cast upper guard
/// with a rotation arrow; spring lower guard with retract lever; 24-tooth carbide blade with washer and arbor
/// bolt; spindle lock; cord with strain relief to a plug.
///
/// Frame (asset space): shoe bottom on y = 0, cutting direction +X, blade plane XY at z = `bladeZ`
/// (blade on the operator's right, motor toward -Z), arbor axis Z. The blade and lower guard project
/// `maxDepth` below y = 0, as on a real saw set to full depth. Rig: `blade` (hinge +Z through the arbor,
/// 0...360, increasing spins in the cutting direction: teeth at the front rise), `lower-guard` (hinge -Z
/// through the arbor, 0...165 degrees, positive retracts into the upper guard), `trigger` (0...15, 15 = pulled).
public struct CircularSaw: RealArticulated {
    public static let id = "circular-saw"
    public static let summary = "7-1/4 inch corded sidewinder circular saw: rubber-gripped housing, rear trigger handle, front knob, die-cast bevel shoe, spring lower guard, carbide blade."
    public static let tags = ["prop", "workshop", "tool", "handheld", "articulated", "metal", "plastic"]
    public static let budget = 9000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: -40, elevation: 22, distance: 1.1, studio: true)

    /// Blade radius to the carbide tips (184 mm blade).
    public var bladeRadius: Float = 0.092
    /// Maximum depth of cut below the shoe (m); the model is built at this setting.
    public var maxDepth: Float = 0.0603
    /// Blade plane z (m).
    public var bladeZ: Float = 0.05
    /// Arbor x (m).
    public var arborX: Float = 0.025
    /// Shoe extent along X (m): rear and front edges.
    public var shoeRearX: Float = -0.15
    public var shoeFrontX: Float = 0.15
    /// Blade cut width (carbide tips), m.
    public var kerf: Float = 0.0022
    /// Number of carbide teeth.
    public var teeth: Int = 24
    /// Livery body color, sRGB hex. Teal 0x1E7F8C also fits.
    public var bodyColor: UInt32 = 0xF2B705
    /// Trim color, sRGB hex.
    public var trimColor: UInt32 = 0x1A1A1B
    public init() {}

    // MARK: game contract

    /// Depth-of-cut range (m below the shoe bottom). The geometry is built at `maxDepth`.
    public var depthRange: ClosedRange<Float> { 0...maxDepth }
    /// Arbor center for a depth setting (m): the blade bottom sits `depth` below y = 0.
    public func bladeCenterBelowShoe(depth: Float) -> V3 { V3(arborX, bladeRadius - depth, bladeZ) }
    /// Arbor center as built (full depth).
    public var arborCenter: V3 { bladeCenterBelowShoe(depth: maxDepth) }
    /// Front edge x of the shoe at the 0-degree cut-line notch (the notch is centered on z = `bladeZ`).
    public var notchX: Float { shoeFrontX }
    /// Rear handle grip center (dominant hand).
    public var rearGrip: V3 { V3(-0.06, 0.2, -0.02) }
    /// Front assist knob center (support hand).
    public var frontKnob: V3 { V3(0.08, 0.148, -0.03) }

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [2.5])
        typealias G = SawGeo
        let A = arborCenter, a2 = V2(A.x, A.y), bZ = bladeZ
        let body = String(format: "plastic.tool:%06X", bodyColor)
        let trim = String(format: "plastic.tool:%06X", trimColor)
        let cast: MaterialKey = "metal.diecast", steel: MaterialKey = "metal.steel", rubber: MaterialKey = "rubber"
        let dark: MaterialKey = "plastic.matte:0E0E0F", red: MaterialKey = "plastic.matte:C4241A", guardMat: MaterialKey = "metal.satin-aluminum"
        let toNegZ = simd_quatf(angle: -.pi / 2, axis: V3(1, 0, 0))   // +Y -> -Z

        rig.part("blade", pivot: A, joint: .hinge(axis: V3(0, 0, 1), 0...360, duration: 0.3))
        rig.part("lower-guard", pivot: A, joint: .hinge(axis: V3(0, 0, -1), 0...165, duration: 0.4))
        let trigPivot = V3(-0.012, 0.181, -0.02)
        rig.part("trigger", pivot: trigPivot, joint: .hinge(axis: V3(0, 0, -1), 0...15, duration: 0.12))

        func put(_ sx: (Surface, Xform), _ part: String? = nil, _ lods: ClosedRange<Int> = 0...0) {
            if let part { rig.add(sx.0, sx.1, to: part, lods: lods) } else { for l in lods { rig.base[l].add(sx.0, sx.1) } }
        }

        // MARK: shoe (zinc-plated stamped steel)
        let shoeMat: MaterialKey = "metal.galvanized-aged"
        let x0 = shoeRearX, x1 = shoeFrontX, zl: Float = -0.07, zr: Float = 0.085, slotX = A.x + 0.098
        let shoe: [V2] = [V2(x0, zl), V2(x1, zl), V2(x1, bZ - 0.0245), V2(x1 - 0.005, bZ - 0.02), V2(x1, bZ - 0.0155),
                          V2(x1, bZ - 0.0045), V2(x1 - 0.007, bZ), V2(x1, bZ + 0.0045), V2(x1, zr), V2(x0, zr), V2(x0, 0.07),
                          V2(slotX, 0.07), V2(slotX, 0.035), V2(x0, 0.035)]
        put(G.slabXZ(Shape2D.rounded(shoe, radius: 0.004, segments: 2), 0, 0.0035, bevel: 0.001, seg: 1, shoeMat), nil, 0...1)
        put(G.slabXZ(Shape2D.roundedRect(A.x - 0.098 - x0, 0.036, radius: 0.003, segments: 1).map { $0 + V2((x0 + A.x - 0.098) / 2, 0.0525) }, 0, 0.0035, bevel: 0.001, seg: 1, shoeMat), nil, 0...1)
        for z in [zl + 0.0025, zr - 0.0025] {
            put((Prim.roundedBox(V3(x1 - x0 - 0.02, 0.009, 0.005), radius: 0.0018, bevelSegments: 1, material: shoeMat), Xform(translation: V3((x0 + x1) / 2 - 0.004, 0.0045, z))), nil, 0...1)
        }
        var marks = Surface(material: dark)
        for z in [bZ, bZ - 0.02] { marks.append(cuboid(V3(0.012, 0.0004, 0.0008), material: dark), Xform(translation: V3(x1 - 0.016, 0.0036, z))) }
        put((marks, .identity))

        // MARK: bevel quadrant (front) and wing nut
        let qc = V2(bZ, 0.0035)
        put(G.slabYZ(G.arc(qc, 0.07, 95, 175, 12) + G.arc(qc, 0.045, 175, 95, 10), 0.105, 0.108, bevel: 0.0008, seg: 1, cast), nil, 0...1)
        put(G.slabYZ(G.arc(qc, 0.06, 105, 165, 10) + G.arc(qc, 0.055, 165, 105, 10), 0.1078, 0.1086, bevel: 0, seg: 1, dark))
        put((Prim.roundedBox(V3(0.014, 0.008, 0.045), radius: 0.002, bevelSegments: 1, material: cast), Xform(translation: V3(0.1065, 0.0065, bZ - 0.055))), nil, 0...1)
        let wn = G.pol(qc, 0.0575, 120)
        put(G.cylX(0.006, 0.108, 0.118, y: wn.y, z: wn.x, bevel: 0.001, seg: 12, steel), nil, 0...1)
        put((Prim.superellipsoid(V3(0.004, 0.03, 0.009), exponent: 3, subdivisions: 4, material: steel), Xform(translation: V3(0.116, wn.y, wn.x))), nil, 0...1)
        put(G.slabXY([V2(0.05, 0.04), V2(0.106, 0.045), V2(0.106, 0.062), V2(0.055, 0.075)], 0.017, 0.025, bevel: 0.0015, seg: 1, cast), nil, 0...1)

        // MARK: depth bracket and lever (rear)
        let dc = V2(0.13, 0.0035)
        put(G.slabXY(G.arc(dc, 0.212, 160, 178.5, 8) + G.arc(dc, 0.196, 178.5, 160, 8), 0.03, 0.034, bevel: 0.0008, seg: 1, cast), nil, 0...1)
        put(G.slabXY(G.arc(dc, 0.207, 162, 176, 8) + G.arc(dc, 0.201, 176, 162, 8), 0.0338, 0.0345, bevel: 0, seg: 1, dark))
        put(G.slabXY(Shape2D.rounded([V2(-0.072, 0.055), V2(-0.06, 0.066), V2(-0.1, 0.091), V2(-0.109, 0.08)], radius: 0.003, segments: 1), 0.0345, 0.038, bevel: 0.0008, seg: 1, steel), nil, 0...1)
        put((Prim.superellipsoid(V3(0.022, 0.016, 0.008), exponent: 3, subdivisions: 4, material: trim), Xform(translation: V3(-0.103, 0.087, 0.0365), rotation: simd_quatf(angle: -0.55, axis: V3(0, 0, 1)))), nil, 0...1)

        // MARK: upper guard (fixed) with rotation arrow
        for l in 0...1 {
            let n = l == 0 ? 18 : 9
            let outer = G.arc(a2, 0.102, -12, 192, n)
            put(G.slabXY(outer + G.arc(a2, 0.03, 192, -12, n / 2), 0.0645, 0.068, bevel: 0.001, seg: 1, cast), nil, l...l)
            put(G.slabXY(outer + G.arc(a2, 0.014, 192, -12, 4), 0.0385, 0.0415, bevel: 0, seg: 1, cast), nil, l...l)
            put(G.slabXY(outer + G.arc(a2, 0.097, 192, -12, n), 0.0385, 0.068, bevel: 0.0018, seg: 1, cast), nil, l...l)
        }
        let arrow = G.arc(a2, 0.075, 60, 140, 8) + [G.pol(a2, 0.07, 140), G.pol(a2, 0.078, 151), G.pol(a2, 0.086, 140)] + G.arc(a2, 0.081, 140, 60, 8)
        put(G.slabXY(arrow, 0.0678, 0.0686, bevel: 0, seg: 1, red))

        // MARK: gearbox, motor, vents
        let gear = Shape2D.rounded([V2(A.x + 0.03, A.y - 0.005), V2(A.x + 0.045, A.y + 0.04), V2(0.055, 0.12), V2(0.02, 0.135), V2(-0.03, 0.115),
                                    V2(-0.035, 0.07), V2(A.x - 0.03, A.y - 0.01), V2(A.x, A.y - 0.028)], radius: 0.012, segments: 3)
        put(G.slabXY(gear, 0.028, 0.0388, bevel: 0.002, seg: 1, cast), nil, 0...1)
        put((Prim.cylinder(radius: 0.0055, height: 0.008, bevel: 0.0015, segments: 10, bevelSegments: 1, material: red), Xform(translation: V3(0.036, 0.125, 0.033))))
        let mc = V3(0.012, 0.078, 0.03)
        let motorBody = [V2(0, 0), V2(0.044, 0), V2(0.048, 0.006), V2(0.049, 0.06), V2(0.048, 0.1), V2(0, 0.1)]
        let motorCap = [V2(0, 0.098), V2(0.0465, 0.098), V2(0.046, 0.112), V2(0.04, 0.126), V2(0.026, 0.134), V2(0, 0.136)]
        let band = [V2(0.0482, 0.034), V2(0.0506, 0.037), V2(0.0508, 0.07), V2(0.0484, 0.073)]
        for l in 0...1 {
            let seg = l == 0 ? 18 : 10
            put((Prim.lathe(motorBody, segments: seg, seamTile: 0.1, material: body), Xform(translation: mc, rotation: toNegZ)), nil, l...l)
            put((Prim.lathe(motorCap, segments: seg, seamTile: 0.1, material: body), Xform(translation: mc, rotation: toNegZ)), nil, l...l)
        }
        put((Prim.lathe(band, segments: 18, seamTile: 0.05, material: rubber), Xform(translation: mc, rotation: toNegZ)))
        var vents = Surface(material: dark)
        for k in 0..<7 {
            let a = (Float(k) / 7 - 0.5) * 2.4, q = simd_quatf(angle: a, axis: V3(0, 0, 1))
            vents.append(cuboid(V3(0.004, 0.0012, 0.014), material: dark), Xform(translation: V3(mc.x, mc.y, mc.z - 0.088) + q.act(V3(0, 0.0485, 0)), rotation: q))
        }
        put((Prim.cylinder(radius: 0.03, height: 0.004, bevel: 0.0015, segments: 20, bevelSegments: 1, material: trim), Xform(translation: V3(mc.x, mc.y, mc.z - 0.1325), rotation: toNegZ)))
        for k in 0..<10 {
            let a = Float(k) / 10 * 2 * .pi, q = simd_quatf(angle: a, axis: V3(0, 0, 1))
            vents.append(cuboid(V3(0.0035, 0.012, 0.003), material: dark), Xform(translation: V3(mc.x, mc.y, mc.z - 0.126) + q.act(V3(0, 0.036, 0)), rotation: q))
        }
        put((vents, .identity))
        put((Prim.cylinder(radius: 0.0085, height: 0.006, bevel: 0.0015, segments: 10, bevelSegments: 1, material: trim), Xform(translation: V3(mc.x - 0.0475, mc.y, -0.075), rotation: facing(V3(-1, 0, 0)))))

        // MARK: rear handle, grip, lock-off, front knob
        let hPath = catmull([(0.035, 0.112), (0.02, 0.165), (-0.01, 0.198), (-0.06, 0.207), (-0.105, 0.2), (-0.132, 0.178), (-0.136, 0.145),
                             (-0.118, 0.12), (-0.08, 0.112), (-0.03, 0.115)].map { V3($0.0, $0.1, -0.02) }, per: 3)
        put((Prim.sweep(Shape2D.circle(0.0155, ry: 0.0195, segments: 10), along: hPath, up: V3(0, 0, 1), material: body), .identity), nil, 0...1)
        put((Prim.sweep(Shape2D.circle(0.0172, ry: 0.0214, segments: 10), along: Array(hPath[6...13]), up: V3(0, 0, 1), material: rubber), .identity))
        // Front web: the handle's front leg is a solid shell down into the motor housing.
        put(G.slabXY(Shape2D.rounded([V2(0.045, 0.1), V2(0.03, 0.172), V2(0.0, 0.203), V2(-0.022, 0.19), V2(-0.01, 0.15), V2(-0.03, 0.112)], radius: 0.01, segments: 3),
                     -0.035, -0.005, bevel: 0.006, seg: 2, body), nil, 0...1)
        // Rear web: the clamshell closes the bottom of the handle loop behind the motor.
        put(G.slabXY(Shape2D.rounded([V2(-0.134, 0.168), V2(-0.124, 0.118), V2(-0.09, 0.104), V2(-0.02, 0.108), V2(-0.03, 0.136), V2(-0.095, 0.138), V2(-0.112, 0.162)], radius: 0.01, segments: 3),
                     -0.034, -0.006, bevel: 0.006, seg: 2, body), nil, 0...1)
        put(G.cylZ(0.0045, -0.042, 0.002, x: -0.003, y: 0.194, bevel: 0.0012, seg: 10, trim))
        put((Prim.tube([V3(0.045, 0.105, -0.03), V3(0.07, 0.135, -0.03)], radii: [0.012, 0.01], sides: 12, seamTile: 0.05, material: body), .identity), nil, 0...1)
        put((Prim.superellipsoid(V3(0.046, 0.026, 0.046), exponent: 3, subdivisions: 4, material: rubber), Xform(translation: frontKnob, rotation: simd_quatf(angle: -0.7, axis: V3(0, 0, 1)))), nil, 0...1)

        // MARK: cord
        put((Prim.tube([V3(-0.133, 0.155, -0.02), V3(-0.153, 0.152, -0.02), V3(-0.173, 0.148, -0.02)], radii: [0.0095, 0.0075, 0.006], sides: 12, seamTile: 0.03, material: rubber), .identity), nil, 0...1)
        let cord = catmull([V3(-0.171, 0.148, -0.02), V3(-0.195, 0.13, -0.025), V3(-0.212, 0.06, -0.035), V3(-0.205, 0.0045, -0.05), V3(-0.17, 0.0045, -0.09), V3(-0.11, 0.0045, -0.105)], per: 4)
        put((Prim.tube(cord, radii: cord.map { _ in 0.0042 }, sides: 6, seamTile: 0.03, material: rubber), .identity), nil, 0...1)
        put((Prim.roundedBox(V3(0.034, 0.016, 0.023), radius: 0.005, bevelSegments: 2, material: trim), Xform(translation: V3(-0.094, 0.008, -0.106))), nil, 0...1)
        for pz: Float in [-0.0063, 0.0063] { put((cuboid(V3(0.016, 0.006, 0.0012), material: "metal.brass"), Xform(translation: V3(-0.07, 0.008, -0.106 + pz)))) }
        // Sawdust caught on the shoe nose.
        put((Prim.superellipsoid(V3(0.03, 0.0014, 0.012), exponent: 2, subdivisions: 3, material: "wood.sawdust") { d in 1 + 0.1 * sin(d.x * 4 + d.z * 3) },
             Xform(translation: V3(0.128, 0.0036, bZ + 0.026), rotation: simd_quatf(angle: rng.float(-0.3...0.3), axis: .up))))

        put((Prim.superellipsoid(V3(0.05, 0.0012, 0.02), exponent: 2, subdivisions: 3, material: "wood.sawdust") { d in 1 + 0.1 * sin(d.x * 4 + d.z * 3) },
             Xform(translation: V3(-0.11, 0.0036, 0.06), rotation: simd_quatf(angle: 0.2, axis: .up))))
        for (p, w, d, yaw) in [(V3(0.1, 0.0036, 0.024), Float(0.03), Float(0.014), Float(-0.3)), (V3(-0.095, 0.0036, 0.032), 0.026, 0.01, 0.5),
                               (V3(A.x + 0.1, A.y - 0.012, 0.053), 0.012, 0.024, 0)] {
            put((Prim.superellipsoid(V3(w, 0.0012, d), exponent: 2, subdivisions: 3, material: "wood.sawdust") { d in 1 + 0.1 * sin(d.x * 4 + d.z * 3) },
                 Xform(translation: p, rotation: simd_quatf(angle: yaw, axis: .up))))
        }
        // Rating plate on the motor top.
        put((Prim.roundedBox(V3(0.03, 0.0008, 0.04), radius: 0.0003, bevelSegments: 1, material: "metal.satin-aluminum"), Xform(translation: V3(mc.x - 0.012, mc.y + 0.0485, -0.055), rotation: simd_quatf(angle: 0.25, axis: V3(0, 0, 1)))))

        // MARK: blade
        for l in 0...1 {
            var plate = Prim.extrude(l == 0 ? G.toothed(teeth, bladeRadius - 0.002, mirror: true) : Shape2D.circle(bladeRadius - 0.003, segments: 24),
                                     depth: 0.0015, bevel: 0, bevelSegments: 1, material: "metal.sawblade")
            G.radialUV(&plate)
            put((plate, Xform(translation: A)), "blade", l...l)
        }
        put((G.carbide(teeth, bladeRadius, kerf: kerf, mirror: true, "metal.carbide"), Xform(translation: A)), "blade")
        var slots = Surface(material: dark)
        for k in 0..<4 {
            let a = Float(k) * 90 + 30
            slots.append(cuboid(V3(0.001, 0.014, 0.0018), material: dark), Xform(translation: V3(G.pol(.zero, 0.066, a), 0), rotation: simd_quatf(angle: radians(a), axis: V3(0, 0, 1))))
        }
        put((slots, Xform(translation: A)), "blade")
        put(G.cylZ(0.016, bZ + 0.0007, bZ + 0.0027, x: A.x, y: A.y, bevel: 0.0004, seg: 16, steel), "blade", 0...1)
        put(G.cylZ(0.016, bZ - 0.0035, bZ - 0.0007, x: A.x, y: A.y, bevel: 0.0004, seg: 16, steel), "blade")
        put(G.slabXY(Shape2D.rounded(Shape2D.polygon(sides: 6, radius: 0.0078), radius: 0.0007, segments: 1).map { $0 + a2 }, bZ + 0.0027, bZ + 0.0077, bevel: 0.0007, seg: 1, "metal.chrome"), "blade", 0...1)

        // MARK: lower guard (spring loaded, retracts)
        for l in 0...1 {
            let n = l == 0 ? 14 : 6
            let outer = G.arc(a2, 0.0965, 185, 350, n)
            put(G.slabXY(outer + G.arc(a2, 0.045, 350, 185, n / 2), 0.0605, 0.0625, bevel: 0.0006, seg: 1, guardMat), "lower-guard", l...l)
            put(G.slabXY(outer + G.arc(a2, 0.04, 350, 185, n / 2), 0.0425, 0.0445, bevel: 0.0006, seg: 1, guardMat), "lower-guard", l...l)
            put(G.slabXY(outer + G.arc(a2, 0.0935, 350, 185, n), 0.0425, 0.0625, bevel: 0.001, seg: 1, guardMat), "lower-guard", l...l)
        }
        put(G.slabXY([G.pol(a2, 0.09, 196), G.pol(a2, 0.116, 199), G.pol(a2, 0.116, 206), G.pol(a2, 0.09, 207)], 0.048, 0.057, bevel: 0.001, seg: 1, guardMat), "lower-guard", 0...1)
        put((Prim.superellipsoid(V3(0.014, 0.012, 0.013), exponent: 3, subdivisions: 3, material: trim), Xform(translation: V3(G.pol(a2, 0.118, 202.5), 0.0525))), "lower-guard")
        put(G.cylZ(0.02, 0.0388, 0.0425, x: A.x, y: A.y, bevel: 0.0005, seg: 16, steel), "lower-guard")

        // MARK: trigger
        let trig = Shape2D.rounded([V2(-0.012, 0.183), V2(-0.045, 0.186), V2(-0.046, 0.174), V2(-0.038, 0.164), V2(-0.026, 0.161), V2(-0.016, 0.169)], radius: 0.003, segments: 2)
        put(G.slabXY(trig, -0.026, -0.014, bevel: 0.0015, seg: 1, trim), "trigger", 0...1)

        groundAO(&rig, height: 0.05, floor: 0.65)
        rig.states = [
            RigState("idle"),
            RigState("running", ["trigger": 15]),
            RigState("plunge", ["trigger": 15, "lower-guard": 150]),
        ]
        return rig
    }
}
