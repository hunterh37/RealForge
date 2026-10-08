import simd
import Foundation

/// Class-7 insulated aerial device truck (Altec AT/TA style on an International conventional chassis),
/// life-size: 10.2 m long, 3.6 m stowed. Front faces +Z, driver side is +X. Conventional cab with
/// sloped hood and separate fenders, white steel utility body with compartment doors, turret on a
/// pedestal behind the cab, steel lower boom and fiberglass upper boom stowed rearward over the body,
/// one-man fiberglass bucket hung beside the boom tip, four vertical outriggers, amber beacons, rear
/// steps, single front axle and rear duals on 11R22.5 tires with molded tread.
///
/// Parts: `turret` (yaw 0...360), `lowerBoom` (0...80), `upperBoom` (0...170), `bucketLevel` (mimic of
/// `upperBoom`) with child `bucketLevelLower` (mimic of `lowerBoom`) so the bucket stays level,
/// `outriggerFL/FR/RL/RR` (slide down 0...0.9 m), `doorL`, `doorR` (0...70), `wheelFL/FR` (steer
/// -35...35) and wheel spin `spinFL/FR/RL/RR` (degrees). States `stowed`, `deployed`, `working`.
public struct BucketTruck: RealArticulated {
    public static let id = "bucket-truck"
    public static let summary = "White class-7 aerial device truck: conventional cab, utility body, turret, steel and fiberglass booms, one-man bucket, outriggers, beacons."
    public static let tags = ["structure", "vehicle", "utility", "electrical", "metal", "articulated", "street"]
    public static let budget = 30_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 62, elevation: 12, distance: 1.0)

    // MARK: attachment points (asset space, rest pose `stowed`)
    /// Driver eye point in the cab (seated, left-hand drive on +X).
    public static let driverEye = V3(0.55, 2.42, 2.45)
    /// Standing floor inside the bucket.
    public static let bucketFloor = V3(-0.55, 2.60, 1.1)
    /// Upper control console top in the bucket.
    public static let bucketConsole = V3(-0.36, 3.73, 1.1)
    /// Pivots for runtime kinematics (boom joints, rest pose).
    public static let turretPivot = V3(0, 2.3, 1.0)
    public static let lowerBoomPivot = V3(0, 2.65, 1.0)
    public static let upperBoomPivot = V3(0, 3.08, -4.75)
    public static let boomTip = V3(0, 3.08, 1.2)
    public static let wheelbase: Float = 5.3
    public static let tireRadius: Float = 0.522

    /// Cab paint.
    public var cabPaint: MaterialKey = "paint.truck-white"
    /// Utility body paint.
    public var bodyPaint: MaterialKey = "paint.body-white"
    /// Upper boom fiberglass.
    public var boomGlass: MaterialKey = "fiberglass.boom"
    public init() {}

    static let frontAxleZ: Float = 3.75, rearAxleZ: Float = -1.55
    static let frontTrack: Float = 1.03, dualInner: Float = 0.8, dualOuter: Float = 1.105

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [18])
        let dark: MaterialKey = "metal.painted:1E1F20", chrome: MaterialKey = "metal.chrome", glass: MaterialKey = "plastic.gloss:121518"
        let plate: MaterialKey = "metal.aluminum-brushed", rubber: MaterialKey = "rubber.truck-tire"

        for l in 0..<2 {
            var m = Model(name: Self.id)
            let s = l == 0 ? 2 : 1
            // MARK: frame, axles
            for sx: Float in [-1, 1] {
                m.add(VK.span(V3(sx * 0.4, 0.78, -4.45), V3(sx * 0.47, 1.05, 4.75), dark, r: 0.01))
            }
            m.add(HK.cyl(r: 0.07, len: 1.75, at: V3(0, 0.5, Self.frontAxleZ), axis: V3(1, 0, 0), mat: dark, seg: 10))
            m.add(HK.cyl(r: 0.11, len: 1.6, at: V3(0, 0.52, Self.rearAxleZ), axis: V3(1, 0, 0), mat: dark, seg: 12))
            m.add(HK.cyl(r: 0.2, len: 0.32, at: V3(0, 0.52, Self.rearAxleZ), axis: V3(1, 0, 0), mat: dark, seg: 14))
            for sx: Float in [-1, 1] {
                // Leaf spring packs.
                m.add(VK.span(V3(sx * 0.4, 0.6, Self.frontAxleZ - 0.7), V3(sx * 0.48, 0.7, Self.frontAxleZ + 0.7), dark))
                m.add(VK.span(V3(sx * 0.4, 0.66, Self.rearAxleZ - 0.75), V3(sx * 0.48, 0.78, Self.rearAxleZ + 0.75), dark))
            }
            // Driveshaft and exhaust.
            m.add(HK.cyl(r: 0.05, len: 4.6, at: V3(0, 0.62, 0.75), axis: V3(0, 0, 1), mat: dark, seg: 8))

            // MARK: hood (lofted), grille, bumper, fenders, headlights
            let hood: [(Float, Float, Float, Float)] = [(3.18, 1.52, 1.0, 1.99), (3.6, 1.5, 1.0, 1.97), (4.55, 1.42, 1.0, 1.87), (4.88, 1.36, 1.02, 1.78), (4.97, 1.3, 1.06, 1.72)]
            let rings = hood.map { h -> [V3] in
                Shape2D.roundedRect(h.1, h.3 - h.2, radius: 0.14, segments: s + 1).map { V3($0.x, (h.2 + h.3) / 2 + $0.y, h.0) }
            }
            m.add(Prim.loft(rings, capEnd: true, material: cabPaint))
            m.add(VK.span(V3(-0.56, 1.1, 4.94), V3(0.56, 1.66, 5.0), chrome, r: 0.02))
            m.add(VK.span(V3(-0.5, 1.14, 4.96), V3(0.5, 1.62, 5.005), "plastic.black", r: 0.008))
            if l == 0 {
                for k in 0..<9 { m.add(cuboid(V3(0.98, 0.02, 0.017), material: chrome), Xform(translation: V3(0, 1.18 + Float(k) * 0.052, 5.003))) }
                m.add(HK.box(V3(0.5, 0.05, 0.01), V3(0, 1.36, 5.016), "metal.chrome", r: 0.004, seg: 1))
            }
            m.add(VK.span(V3(-1.2, 0.58, 4.95), V3(1.2, 0.92, 5.1), "metal.painted:2A2B2C", r: 0.03))
            for sx: Float in [-1, 1] {
                var fender: [V2] = [V2(5.0, 0.95), V2(5.0, 1.42), V2(4.82, 1.58), V2(3.32, 1.64), V2(3.2, 1.55), V2(3.2, 0.95), V2(3.27, 0.95)]
                let a0: Float = 2.47, a1: Float = 0.67
                for k in 0...10 { let a = a0 + (a1 - a0) * Float(k) / 10; fender.append(V2(Self.frontAxleZ + 0.63 * cos(a), 0.52 + 0.63 * sin(a))) }
                m.add(VK.side(fender, width: 0.5, x: sx * 0.93, bevel: 0.05, seg: s, mat: cabPaint))
                // Headlight with chrome bezel and amber turn lamp.
                m.add(HK.box(V3(0.34, 0.2, 0.06), V3(sx * 0.86, 1.28, 4.99), chrome, r: 0.02, seg: 1))
                m.add(HK.box(V3(0.3, 0.16, 0.02), V3(sx * 0.86, 1.28, 5.02), "glass.pane", r: 0.015, seg: 1))
                m.add(HK.box(V3(0.12, 0.1, 0.02), V3(sx * 1.08, 1.28, 5.0), "emissive.signal-orange", r: 0.01, seg: 1))
            }

            // MARK: cab shell, windshield, roof lamps, mirrors, steps, fuel tank
            let cabSide: [V2] = [V2(1.5, 1.02), V2(1.5, 2.86), V2(2.9, 2.9), V2(3.12, 2.05), V2(3.22, 1.98), V2(3.22, 1.02)]
            m.add(VK.side(Shape2D.rounded(cabSide, radius: 0.06, segments: s), width: 2.3, bevel: 0.07, seg: s, mat: cabPaint))
            // Windshield: on the slope plane.
            let wsN = simd_normalize(V3(0, 0.22, 0.85 * 0.0 + 0.85)), wsUp = simd_normalize(V3(0, 2.9 - 2.05, 2.9 - 3.12))
            m.add(HK.rect(glass, center: V3(0, 2.47, 3.012) + wsN * 0.012, right: V3(1, 0, 0), up: wsUp, w: 2.05, h: 0.76))
            m.add(HK.box(V3(0.04, 0.8, 0.03), V3(0, 2.47, 3.03), "plastic.black", r: 0.01, seg: 1, rot: simd_quatf(from: V3(0, 1, 0), to: wsUp)))
            // Rear window and extended-cab quarter windows.
            m.add(HK.rect(glass, center: V3(0, 2.45, 1.498), right: V3(-1, 0, 0), up: .up, w: 1.2, h: 0.4))
            for sx: Float in [-1, 1] {
                m.add(VK.side(Shape2D.rounded([V2(1.6, 2.05), V2(1.6, 2.72), V2(1.92, 2.74), V2(1.92, 2.05)], radius: 0.04, segments: 2), width: 0.006, x: sx * 1.152, bevel: 0.002, seg: 1, mat: glass))
            }
            // Roof clearance lamps (five amber) and the amber beacon light bar.
            for k in -2...2 { m.add(cuboid(V3(0.08, 0.04, 0.05), material: "emissive.signal-orange"), Xform(translation: V3(Float(k) * 0.3, 2.9, 2.85))) }
            m.add(VK.span(V3(-0.7, 2.88, 1.9), V3(0.7, 2.96, 2.1), "plastic.black", r: 0.02))
            for sx: Float in [-1, 1] {
                m.add(Prim.lathe([V2(0, 0), V2(0.1, 0), V2(0.1, 0.06), V2(0.08, 0.14), V2(0, 0.16)], segments: 14, material: "emissive.signal-orange")
                    .transformed(Xform(translation: V3(sx * 0.55, 2.96, 2.0))))
            }
            // West-coast mirrors on tube arms.
            for sx: Float in [-1, 1] {
                m.add(HK.pipe([V3(sx * 1.14, 2.35, 3.05), V3(sx * 1.36, 2.4, 3.05), V3(sx * 1.36, 1.85, 3.05), V3(sx * 1.14, 1.9, 3.05)], r: 0.014, sides: 6, mat: chrome))
                m.add(HK.box(V3(0.05, 0.42, 0.2), V3(sx * 1.38, 2.12, 3.05), "plastic.black", r: 0.02, seg: s))
            }
            // Steps (driver side on the fuel tank, passenger side on the battery box).
            m.add(HK.cyl(r: 0.3, len: 0.95, at: V3(0.82, 0.68, 2.45), axis: V3(0, 0, 1), mat: "metal.aluminum-brushed", seg: l == 0 ? 20 : 10, bevel: 0.03))
            for sx: Float in [-1, 1] {
                m.add(VK.span(V3(sx * 1.0, 0.98, 2.05), V3(sx * 1.2, 1.0, 2.9), plate, r: 0.006))
                m.add(VK.span(V3(sx * 1.0, 0.48, 2.1), V3(sx * 1.22, 0.5, 2.85), plate, r: 0.006))
            }
            m.add(VK.span(V3(-1.12, 0.5, 2.05), V3(-0.55, 0.95, 2.9), dark, r: 0.02))
            // Grab handles beside the doors.
            for sx: Float in [-1, 1] { m.add(HK.pipe([V3(sx * 1.155, 1.6, 1.97), V3(sx * 1.17, 1.6, 1.97), V3(sx * 1.17, 2.4, 1.97), V3(sx * 1.155, 2.4, 1.97)], r: 0.016, sides: 6, mat: chrome)) }

            // MARK: utility body
            let bodyTop: Float = 2.02, bodyFront: Float = 1.42, bodyRear: Float = -4.4
            let vBot: Float = 0.8, hBot: Float = 1.2, w: Float = 1.22, d: Float = 0.55
            let comps: [(Float, Float, Float)] = [(bodyFront, 0.6, vBot), (0.6, -2.4, hBot), (-2.4, bodyRear, vBot)]
            for sx: Float in [-1, 1] {
                for c in comps {
                    m.add(VK.span(V3(sx * (w - d), c.2, c.1), V3(sx * w, bodyTop, c.0), bodyPaint, r: 0.025))
                    // Doors: vertical compartments one tall door, horizontal ones two lift-up doors.
                    let doors = c.2 == hBot ? 2 : 1
                    let len = (c.0 - c.1) / Float(doors)
                    for k in 0..<doors {
                        let z1 = c.0 - Float(k) * len - 0.04, z0 = c.0 - Float(k + 1) * len + 0.04
                        m.add(VK.span(V3(sx * (w - 0.004), c.2 + 0.06, z0), V3(sx * (w + 0.012), bodyTop - 0.1, z1), bodyPaint, r: 0.012))
                        // Paddle latch (chrome).
                        let hy: Float = c.2 == hBot ? bodyTop - 0.2 : (c.2 + bodyTop) / 2
                        m.add(cuboid(V3(0.02, 0.05, 0.15), material: chrome), Xform(translation: V3(sx * (w + 0.02), hy, (z0 + z1) / 2)))
                        if l == 0 {
                            // Reflective conspicuity tape strip on the door .
                            let n = max(1, Int((z1 - z0 - 0.1) / 0.3))
                            for t in 0..<n {
                                let zz = z0 + 0.05 + (Float(t) + 0.5) * (z1 - z0 - 0.1) / Float(n)
                                m.add(cuboid(V3(0.003, 0.05, (z1 - z0 - 0.1) / Float(n) - 0.004), material: t % 2 == 0 ? "plastic.gloss:B52A22" : "plastic.gloss:E8E8E4"),
                                      Xform(translation: V3(sx * (w + 0.0135), c.2 + 0.2, zz)))
                            }
                        }
                    }
                }
                // Skirt with rear wheel arch under the horizontal compartments.


                var skirt: [V2] = [V2(0.6, 0.8), V2(0.6, 1.21), V2(-2.4, 1.21), V2(-2.4, 0.8), V2(Self.rearAxleZ - 0.68, 0.8)]
                for k in 1..<12 {
                    let a = Float.pi - Float.pi * Float(k) / 12
                    skirt.append(V2(Self.rearAxleZ + 0.68 * cos(a), 0.52 + 0.68 * max(sin(a), 0.42)))
                }
                skirt.append(V2(Self.rearAxleZ + 0.68, 0.8))
                m.add(VK.side(skirt.reversed(), width: 0.04, x: sx * (w - 0.02), bevel: 0.01, seg: 1, mat: bodyPaint))
                // Rubber mud flap behind the duals.
                m.add(VK.span(V3(sx * 0.82, 0.18, Self.rearAxleZ - 0.72), V3(sx * 1.2, 0.8, Self.rearAxleZ - 0.7), "rubber.plate", r: 0.004))
                // Top rail cap.
                m.add(VK.span(V3(sx * (w - d - 0.01), bodyTop, bodyRear), V3(sx * (w + 0.01), bodyTop + 0.03, bodyFront), plate, r: 0.008))
            }
            // Cargo floor (aluminum tread plate), front bulkhead and rear tailgate rail.
            m.add(VK.span(V3(-(w - d), 1.1, bodyRear), V3(w - d, 1.16, bodyFront), plate, r: 0.006))
            m.add(VK.span(V3(-w, 1.16, bodyFront - 0.06), V3(w, 2.3, bodyFront), bodyPaint, r: 0.02))
            m.add(VK.span(V3(-(w - d), 1.16, bodyRear), V3(w - d, 1.5, bodyRear + 0.04), bodyPaint, r: 0.01))
            // Boom rest on the rear compartments (V cradle) with rubber pad.
            m.add(VK.span(V3(-0.08, bodyTop, -4.3), V3(0.08, 2.45, -4.18), dark, r: 0.01))
            m.add(VK.span(V3(-0.22, 2.45, -4.32), V3(0.22, 2.47, -4.16), "rubber.plate", r: 0.005))
            // Rear bumper with two steps, tail lights, license plate.
            m.add(VK.span(V3(-1.15, 0.55, bodyRear - 0.2), V3(1.15, 0.75, bodyRear), dark, r: 0.02))
            m.add(VK.span(V3(-0.45, 0.32, bodyRear - 0.35), V3(0.45, 0.35, bodyRear - 0.02), plate, r: 0.005))
            m.add(VK.span(V3(-0.45, 0.32, bodyRear - 0.35), V3(-0.43, 0.75, bodyRear - 0.02), dark, r: 0.004))
            m.add(VK.span(V3(0.43, 0.32, bodyRear - 0.35), V3(0.45, 0.75, bodyRear - 0.02), dark, r: 0.004))
            for sx: Float in [-1, 1] {
                m.add(HK.box(V3(0.18, 0.1, 0.03), V3(sx * 0.95, 1.0, bodyRear - 0.005), "emissive.signal-red", r: 0.01, seg: 1))
                m.add(HK.box(V3(0.18, 0.08, 0.03), V3(sx * 0.95, 0.88, bodyRear - 0.005), "emissive.signal-orange", r: 0.01, seg: 1))
                m.add(HK.cyl(r: 0.06, len: 0.08, at: V3(sx * 0.95, 2.1, bodyRear + 0.2), axis: .up, mat: "emissive.signal-orange", seg: 10, bevel: 0.01))
                m.add(HK.pipe([V3(sx * 0.6, 1.1, bodyRear - 0.02), V3(sx * 0.6, 1.1, bodyRear - 0.06), V3(sx * 0.6, 1.6, bodyRear - 0.06), V3(sx * 0.6, 1.6, bodyRear - 0.02)], r: 0.015, sides: 6, mat: chrome))
            }
            m.add(HK.box(V3(0.3, 0.15, 0.01), V3(0.0, 0.85, bodyRear - 0.006), "label.inspection", r: 0.003, seg: 1))

            // MARK: pedestal (static under the turret)
            m.add(VK.span(V3(-0.32, 1.16, 0.68), V3(0.32, 2.2, 1.32), bodyPaint, r: 0.03))
            m.add(HK.cyl(r: 0.44, len: 0.1, at: V3(0, 2.25, 1.0), axis: .up, mat: dark, seg: l == 0 ? 24 : 12, bevel: 0.01))
            rig.base[l] = m
        }

        // MARK: wheels (steer + spin) and tires
        rig.part("wheelFL", pivot: V3(Self.frontTrack, Self.tireRadius, Self.frontAxleZ), joint: .hinge(axis: .up, -35...35, duration: 1.2))
        rig.part("wheelFR", pivot: V3(-Self.frontTrack, Self.tireRadius, Self.frontAxleZ), joint: .hinge(axis: .up, -35...35, duration: 1.2))
        rig.part("spinFL", parent: "wheelFL", pivot: V3(Self.frontTrack, Self.tireRadius, Self.frontAxleZ), joint: .hinge(axis: V3(1, 0, 0), -360...360, duration: 2))
        rig.part("spinFR", parent: "wheelFR", pivot: V3(-Self.frontTrack, Self.tireRadius, Self.frontAxleZ), joint: .hinge(axis: V3(1, 0, 0), -360...360, duration: 2))
        rig.part("spinRL", pivot: V3(0.95, Self.tireRadius, Self.rearAxleZ), joint: .hinge(axis: V3(1, 0, 0), -360...360, duration: 2))
        rig.part("spinRR", pivot: V3(-0.95, Self.tireRadius, Self.rearAxleZ), joint: .hinge(axis: V3(1, 0, 0), -360...360, duration: 2))
        for l in 0..<2 {
            for (part, x, z, outward, lugs) in [("spinFL", Self.frontTrack, Self.frontAxleZ, Float(1), false), ("spinFR", -Self.frontTrack, Self.frontAxleZ, -1, false),
                                                 ("spinRL", Self.dualOuter, Self.rearAxleZ, 1, true), ("spinRL", Self.dualInner, Self.rearAxleZ, 0, true),
                                                 ("spinRR", -Self.dualOuter, Self.rearAxleZ, -1, true), ("spinRR", -Self.dualInner, Self.rearAxleZ, 0, true)] {
                for s in Self.wheel(lod: l, outward: outward == 0 ? 1 : outward, drive: lugs && outward != 0, face: outward != 0, rubber: rubber, rim: cabPaint) {
                    rig.add(s, Xform(translation: V3(x, Self.tireRadius, z)), to: part, lods: l...l)
                }
            }
        }

        // MARK: doors
        rig.part("doorL", pivot: V3(1.16, 1.5, 3.08), joint: .hinge(axis: V3(0, -1, 0), 0...70, duration: 1.0))
        rig.part("doorR", pivot: V3(-1.16, 1.5, 3.08), joint: .hinge(axis: V3(0, 1, 0), 0...70, duration: 1.0))
        for (part, sx) in [("doorL", Float(1)), ("doorR", -1)] {
            let doorSide: [V2] = [V2(2.02, 1.06), V2(2.02, 2.78), V2(2.86, 2.8), V2(3.06, 2.06), V2(3.06, 1.06)]
            rig.add(VK.side(Shape2D.rounded(doorSide, radius: 0.04, segments: 2), width: 0.04, x: sx * 1.16, bevel: 0.012, seg: 2, mat: cabPaint), to: part)
            let win: [V2] = [V2(2.1, 2.02), V2(2.1, 2.7), V2(2.82, 2.72), V2(2.98, 2.1), V2(2.98, 2.02)]
            rig.add(VK.side(Shape2D.rounded(win, radius: 0.03, segments: 2), width: 0.006, x: sx * 1.182, bevel: 0.002, seg: 1, mat: glass), to: part)
            rig.add(HK.box(V3(0.03, 0.04, 0.18), V3(sx * 1.19, 1.9, 2.3), chrome, r: 0.01, seg: 1), to: part)
            rig.add(HK.box(V3(0.006, 0.02, 0.9), V3(sx * 1.181, 1.96, 2.52), "plastic.black", r: 0.003, seg: 1), to: part, lods: 0...0)
        }

        // MARK: outriggers (vertical legs in housings outside the body)
        for (name, sx, z) in [("outriggerFL", Float(1), Float(1.2)), ("outriggerFR", -1, 1.2), ("outriggerRL", 1, -4.18), ("outriggerRR", -1, -4.18)] {
            let hx = sx * 1.32
            for l in 0..<2 {
                rig.base[l].add(VK.span(V3(hx - 0.1, 0.95, z - 0.1), V3(hx + 0.1, 1.95, z + 0.1), "metal.painted:1E1F20", r: 0.012, seg: l == 0 ? 2 : 1))
                rig.base[l].add(VK.span(V3(sx * 1.2, 1.6, z - 0.08), V3(hx, 1.75, z + 0.08), "metal.painted:1E1F20", r: 0.01))
            }
            rig.part(name, pivot: V3(hx, 0.95, z), joint: .slide(axis: V3(0, -1, 0), 0...0.9, duration: 4))
            rig.add(VK.span(V3(hx - 0.075, 0.96, z - 0.075), V3(hx + 0.075, 1.9, z + 0.075), "metal.painted:C8C9C5", r: 0.008), to: name)
            rig.add(HK.cyl(r: 0.2, len: 0.04, at: V3(hx, 0.94, z), axis: .up, mat: "metal.painted:1E1F20", seg: 16, bevel: 0.008), to: name)
        }

        // MARK: turret, booms, bucket
        rig.part("turret", pivot: Self.turretPivot, joint: .hinge(axis: .up, 0...360, duration: 20))
        rig.part("lowerBoom", parent: "turret", pivot: Self.lowerBoomPivot, joint: .hinge(axis: V3(1, 0, 0), 0...80, duration: 14))
        rig.part("upperBoom", parent: "lowerBoom", pivot: Self.upperBoomPivot, joint: .hinge(axis: V3(-1, 0, 0), 0...170, duration: 20))
        rig.part("bucketLevel", parent: "upperBoom", pivot: Self.boomTip, joint: Joint(.revolute, axis: V3(1, 0, 0), range: 0...170, mimic: .init("upperBoom", ratio: 1)))
        rig.part("bucketLevelLower", parent: "bucketLevel", pivot: Self.boomTip, joint: Joint(.revolute, axis: V3(1, 0, 0), range: -80...0, mimic: .init("lowerBoom", ratio: -1)))
        let white = bodyPaint
        for l in 0..<2 {
            let lo = l...l, s = l == 0 ? 2 : 1
            // Turret: turntable, side plates, valve bank, lower controls box.
            rig.add(HK.cyl(r: 0.42, len: 0.12, at: V3(0, 2.36, 1.0), axis: .up, mat: white, seg: l == 0 ? 24 : 12, bevel: 0.02), to: "turret", lods: lo)
            // Turret housing: boxed riser with a rounded cap carrying the lower boom pin.
            rig.add(VK.side(Shape2D.rounded([V2(0.66, 2.42), V2(1.36, 2.42), V2(1.28, 2.78), V2(1.0, 2.9), V2(0.76, 2.82)], radius: 0.06, segments: s), width: 0.44, x: 0, bevel: 0.025, seg: s, mat: white), to: "turret", lods: lo)
            rig.add(HK.cyl(r: 0.06, len: 0.5, at: V3(0, 2.62, 0.82), axis: V3(1, 0, 0), mat: dark, seg: 10), to: "turret", lods: lo)
            rig.add(HK.box(V3(0.22, 0.28, 0.3), V3(0.36, 2.6, 1.15), "metal.painted:D0D2CF", r: 0.02, seg: s), to: "turret", lods: lo)
            rig.add(HK.cyl(r: 0.07, len: 0.5, at: V3(0, 2.65, 1.0), axis: V3(1, 0, 0), mat: chrome, seg: 12), to: "turret", lods: lo)
            // Lower boom: steel box section with a lift cylinder underneath.
            rig.add(VK.span(V3(-0.16, 2.47, -4.95), V3(0.16, 2.83, 1.12), white, r: 0.03), to: "lowerBoom", lods: lo)
            rig.add(HK.cyl(r: 0.07, len: 1.6, at: V3(0, 2.38, 0.0), axis: simd_normalize(V3(0, 0.12, 1)), mat: white, seg: 10, bevel: 0.01), to: "lowerBoom", lods: lo)
            rig.add(HK.cyl(r: 0.04, len: 0.7, at: V3(0, 2.33, 1.0) - V3(0, 0, 0.1), axis: simd_normalize(V3(0, 0.12, 1)), mat: chrome, seg: 8), to: "lowerBoom", lods: lo)
            rig.add(HK.cyl(r: 0.08, len: 0.4, at: Self.upperBoomPivot, axis: V3(1, 0, 0), mat: dark, seg: 12), to: "lowerBoom", lods: lo)
            // Upper boom: steel knuckle, then fiberglass insulating section to the tip casting.
            rig.add(VK.span(V3(-0.15, 2.92, -4.97), V3(0.15, 3.24, -3.9), white, r: 0.03), to: "upperBoom", lods: lo)
            rig.add(HK.cyl(r: 0.15, len: 4.97, at: V3(0, 3.08, (-3.92 + 1.05) / 2), axis: V3(0, 0, 1), mat: boomGlass, seg: l == 0 ? 20 : 10, bevel: 0.02), to: "upperBoom", lods: lo)
            rig.add(HK.cyl(r: 0.155, len: 0.06, at: V3(0, 3.08, -1.2), axis: V3(0, 0, 1), mat: "plastic.matte:2B2D30", seg: l == 0 ? 20 : 10, bevel: 0.01), to: "upperBoom", lods: lo)
            rig.add(VK.span(V3(-0.15, 2.92, 1.0), V3(0.15, 3.24, 1.35), white, r: 0.03), to: "upperBoom", lods: lo)
            // Jib stub on top of the tip with a winch hook.
            rig.add(VK.span(V3(-0.06, 3.24, 0.2), V3(0.06, 3.34, 1.3), boomGlass, r: 0.025, seg: 1), to: "upperBoom", lods: lo)
            if l == 0 {
                rig.add(HK.cyl(r: 0.06, len: 0.18, at: V3(0, 3.3, 1.15), axis: V3(1, 0, 0), mat: dark, seg: 10), to: "upperBoom", lods: lo)
                rig.add(Prim.torus(major: 0.035, minor: 0.008, segments: 10, sides: 6, arc: 4.5, material: "metal.painted:C8A814")
                    .transformed(Xform(translation: V3(0, 3.12, 1.38), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1)))), to: "upperBoom", lods: lo)
                // Boom tip lights and hydraulic lines along the fiberglass.
                for sx: Float in [-1, 1] {
                    rig.add(HK.pipe([V3(sx * 0.165, 3.0, -3.9), V3(sx * 0.165, 3.0, 1.0)], r: 0.012, sides: 6, mat: "rubber.plate"), to: "upperBoom", lods: lo)
                }
                rig.add(HK.cyl(r: 0.05, len: 0.03, at: V3(0, 3.08, 1.365), axis: V3(0, 0, 1), mat: "emissive.signal-red", seg: 10), to: "upperBoom", lods: lo)
            }
            // Bucket: rotated so the mounting plate faces the boom (+X), hung on a bracket off the tip.
            let bo = V3(-0.55, 2.53, 1.1), rot = simd_quatf(angle: -.pi / 2, axis: .up)
            for b in VK.bucket(.zero, lod: l) + VK.consoleHousing(.zero, lod: l) {
                rig.add(b, Xform(translation: bo, rotation: rot), to: "bucketLevelLower", lods: lo)
            }
            rig.add(VK.span(V3(-0.25, 2.95, 0.95), V3(0.0, 3.25, 1.25), dark, r: 0.02), to: "bucketLevelLower", lods: lo)
            rig.add(VK.span(V3(-0.25, 3.0, 0.98), V3(-0.235, 3.24, 1.22), "metal.galvanized-aged", r: 0.004), to: "bucketLevelLower", lods: lo)
            if l == 0 {
                for (x, z) in [(Float(-0.37), Float(1.26)), (-0.37, 1.1), (-0.42, 0.94)] {
                    rig.add(HK.cyl(r: 0.008, len: 0.08, at: V3(x, 3.77, z), axis: .up, mat: chrome, seg: 6), to: "bucketLevelLower", lods: lo)
                    rig.add(Prim.cubeSphere(subdivisions: 2, material: "plastic.black") { $0 * 0.016 }, Xform(translation: V3(x, 3.82, z)), to: "bucketLevelLower", lods: lo)
                }
            }
        }

        groundAO(&rig, height: 0.3)
        rig.states = [
            RigState("stowed"),
            RigState("deployed", ["outriggerFL": 0.9, "outriggerFR": 0.9, "outriggerRL": 0.9, "outriggerRR": 0.9]),
            RigState("working", ["outriggerFL": 0.9, "outriggerFR": 0.9, "outriggerRL": 0.9, "outriggerRR": 0.9,
                                 "turret": 90, "lowerBoom": 55, "upperBoom": 115]),
        ]
        return rig
    }

    /// One wheel centered at the origin, axle along X: 11R22.5 tire (rib tread with four grooves, drive tires
    /// add shoulder lugs) on a white steel disc wheel with hub and ten lug nuts on the `outward` face.
    static func wheel(lod: Int, outward: Float, drive: Bool, face: Bool = true, rubber: MaterialKey, rim: MaterialKey) -> [Surface] {
        var out: [Surface] = []
        let R: Float = 0.522, hw: Float = 0.14
        let seg = lod == 0 ? 28 : 14
        // Profile (radius, axial) from one bead over the tread to the other bead.
        var p: [V2] = [V2(0.3, -0.115), V2(0.42, -hw), V2(0.5, -0.13), V2(R, -0.105)]
        if lod == 0 {
            for g: Float in [-0.045, 0.045] { p += [V2(R, g - 0.008), V2(R - 0.014, g - 0.006), V2(R - 0.014, g + 0.006), V2(R, g + 0.008)] }
        }
        p += [V2(R, 0.105), V2(0.5, 0.13), V2(0.42, hw), V2(0.3, 0.115)]
        let toX = simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))   // +Y -> +X
        out.append(Prim.lathe(p, segments: seg, seamTile: 0.3, material: rubber).transformed(Xform(rotation: toX)))
        if drive && lod == 0 {
            // Shoulder lugs on drive tires.
            for k in 0..<22 {
                let a = Float(k) / 22 * 2 * .pi
                for sgn: Float in [-1, 1] {
                    let c = V3(sgn * 0.112, cos(a) * (R - 0.003), sin(a) * (R - 0.003))
                    out.append(cuboid(V3(0.045, 0.012, 0.035), material: rubber).transformed(Xform(translation: c, rotation: simd_quatf(angle: a, axis: V3(1, 0, 0)))))
                }
            }
        }
        // Disc wheel: rim lip, dished face, hub, lug nuts.
        let f = outward
        let rimP: [V2] = [V2(0.29, -0.12), V2(0.3, -0.125), V2(0.28, -0.1), V2(0.27, 0.0), V2(0.28, 0.1), V2(0.3, 0.125), V2(0.29, 0.12)]
        out.append(Prim.lathe(rimP, segments: lod == 0 ? 24 : 12, material: rim).transformed(Xform(rotation: toX)))
        guard face else { return out }
        let disc: [V2] = [V2(0.27, 0.0), V2(0.2, 0.03), V2(0.12, 0.05), V2(0.11, 0.06), V2(0, 0.06)]
        out.append(Prim.lathe(disc, segments: lod == 0 ? 24 : 12, material: rim)
            .transformed(Xform(rotation: f > 0 ? toX : simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1)))))
        out.append(HK.cyl(r: 0.1, len: 0.06, at: V3(f * 0.08, 0, 0), axis: V3(f, 0, 0), mat: "metal.painted:2A2B2C", seg: lod == 0 ? 16 : 8, bevel: 0.01))
        if lod == 0 {
            for k in 0..<10 {
                let a = Float(k) / 10 * 2 * .pi
                out.append(cuboid(V3(0.03, 0.022, 0.022), material: "metal.chrome").transformed(Xform(translation: V3(f * 0.07, cos(a) * 0.143, sin(a) * 0.143), rotation: simd_quatf(angle: a, axis: V3(1, 0, 0)))))
            }
        }
        return out
    }
}
