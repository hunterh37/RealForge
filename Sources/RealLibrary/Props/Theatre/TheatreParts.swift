import simd
import Foundation

// Shared operating-room hardware for the Theatre props: light hospital casters and low-poly surgical
// instruments. Everything is built in asset space; callers place it with an Xform.

/// Hospital swivel caster: square top plate, swivel bearing, pressed fork, polyurethane wheel with a hub and
/// an axle bolt. Wheel bottom at y = 0, plate top at `height`. `brake` adds a foot tab on the fork.
/// `detail` 0 is about 300 tris, 1 about 110 for distance LODs.
func theatreCaster(_ m: inout Model, at p: V3, height: Float, wheelRadius r: Float, width: Float = 0.026, yaw: Float = 0,
                   brake: Bool = false, detail: Int = 0, frame: MaterialKey = "metal.chrome", wheel: MaterialKey = "rubber.tubing:2A2B2D",
                   hub: MaterialKey = "plastic.medical-grey") {
    let q = simd_quatf(degrees: yaw, axis: .up)
    func X(_ t: V3, _ rot: simd_quatf = .identity) -> Xform { Xform(translation: p + q.act(t), rotation: q * rot) }
    func box(_ size: V3) -> Surface { cuboid(size, material: frame) }
    let plate = min(0.07, max(0.04, r * 1.6))
    m.add(detail == 0 ? Prim.roundedBox(V3(plate, 0.004, plate), radius: 0.0015, bevelSegments: 1, material: frame) : box(V3(plate, 0.004, plate)),
          X(V3(0, height - 0.002, 0)))
    let bearingH: Float = min(0.016, (height - 2 * r) * 0.5 + 0.006)
    let bs = detail == 0 ? 12 : 6
    m.add(Prim.lathe([V2(0, 0), V2(plate * 0.3, 0), V2(plate * 0.34, bearingH * 0.5), V2(plate * 0.3, bearingH), V2(0, bearingH)], segments: bs, material: frame),
          X(V3(0, height - 0.004 - bearingH, 0)))
    // Fork: two side cheeks from the bearing to the axle, trailing the swivel axis by a third of the radius.
    let trail = r * 0.35, top = height - 0.004 - bearingH
    let cheekH = top - r + 0.006
    for side: Float in [-1, 1] {
        m.add(box(V3(0.004, cheekH, r * 1.1)), X(V3(side * (width / 2 + 0.003), r - 0.006 + cheekH / 2, -trail * 0.5),
                                                simd_quatf(angle: atan2(trail, cheekH) * 0.5, axis: V3(1, 0, 0))))
    }
    m.add(box(V3(width + 0.01, 0.004, r * 1.1)), X(V3(0, top - 0.002, -trail * 0.3)))
    // Wheel: rounded tread lathe about the axle (X), recessed hub through it.
    let segs = detail == 0 ? 16 : 8
    let w = width / 2
    let tread: [V2] = detail == 0
        ? [V2(r * 0.6, -w), V2(r - 0.004, -w), V2(r, -w + 0.004), V2(r, w - 0.004), V2(r - 0.004, w), V2(r * 0.6, w)]
        : [V2(r * 0.6, -w), V2(r, -w + 0.003), V2(r, w - 0.003), V2(r * 0.6, w)]
    let axle = simd_quatf(degrees: -90, axis: V3(0, 0, 1))
    m.add(Prim.lathe(tread, segments: segs, seamTile: 0.1, material: wheel), X(V3(0, r, -trail), axle))
    m.add(Prim.lathe([V2(0, -w + 0.002), V2(r * 0.6, -w + 0.002), V2(r * 0.6, w - 0.002), V2(0, w - 0.002)], segments: segs, material: hub),
          X(V3(0, r, -trail), axle))
    if detail == 0 {
        m.add(Prim.lathe([V2(0, -w - 0.008), V2(0.0035, -w - 0.008), V2(0.0035, w + 0.008), V2(0, w + 0.008)], segments: 6, material: frame),
              X(V3(0, r, -trail), axle))
    }
    if brake {
        m.add(Prim.roundedBox(V3(0.022, 0.005, 0.028), radius: 0.002, bevelSegments: 1, material: "plastic.matte:B3261E"),
              X(V3(0, r * 1.5, r + 0.012), simd_quatf(degrees: -14, axis: V3(1, 0, 0))))
    }
}

/// Kinds of low-poly surgical instruments (`theatreInstrument`).
enum TheatreInstrument { case hemostat, curvedHemostat, scissors, forceps, scalpel, needleHolder, towelClip }

/// One surgical instrument lying flat on y = 0, tip toward +Z, handle end at z = 0, centered on X. About 150-300
/// tris: finger rings, shanks, box lock and jaws, all extruded from outlines 2.5-3 mm thick.
func theatreInstrument(_ kind: TheatreInstrument, length L: Float, material: MaterialKey = "metal.surgical") -> Surface {
    var s = Surface(material: material)
    let t: Float = 0.0026
    let flat = simd_quatf(degrees: -90, axis: V3(1, 0, 0))   // outline (x, y) -> (x, -z)
    func slab(_ pts: [V2], _ thick: Float = t, y: Float = 0) {
        let o = Shape2D.deduped(pts.map { V2($0.x, -$0.y) })
        s.append(Prim.extrude(o, depth: thick, bevel: 0, bevelSegments: 1, material: material),
                 Xform(translation: V3(0, y + thick / 2, 0), rotation: flat))
    }
    func rings(_ z: Float, _ spread: Float, _ r: Float = 0.0085) {
        for sx: Float in [-1, 1] {
            s.append(Prim.torus(major: r, minor: 0.0017, segments: 10, sides: 4, minorY: t / 2, material: material),
                     Xform(translation: V3(sx * spread, t / 2, z)))
        }
    }
    switch kind {
    case .hemostat, .curvedHemostat, .needleHolder, .towelClip:
        let box = L * (kind == .needleHolder ? 0.68 : 0.6), spread: Float = 0.0115, rr: Float = 0.0085
        rings(rr, spread, rr)
        for sx: Float in [-1, 1] {
            slab([V2(sx * (spread - 0.0035), rr * 1.6), V2(sx * (spread - 0.0005), rr * 1.6 + 0.004), V2(sx * 0.0022, box), V2(sx * 0.0005, box - 0.004)])
        }
        // Ratchets: two small teeth blocks near the rings.
        s.append(cuboid(V3(0.009, t, 0.004), material: material), Xform(translation: V3(0, t / 2, rr * 2 + 0.006)))
        s.append(cuboid(V3(0.006, t * 1.5, 0.009), material: material), Xform(translation: V3(0, t * 0.75, box)))
        let jawL = L - box - 0.004, tipW: Float = kind == .needleHolder ? 0.0022 : (kind == .towelClip ? 0.001 : 0.0014)
        let curve: Float = kind == .curvedHemostat ? 0.006 : (kind == .towelClip ? 0.012 : 0)
        var jaw: [V2] = []
        let n = 4
        for i in 0...n { let f = Float(i) / Float(n); jaw.append(V2(-0.0026 * (1 - f) - tipW * f + curve * f * f, box + 0.004 + jawL * f)) }
        for i in (0...n).reversed() { let f = Float(i) / Float(n); jaw.append(V2(0.0026 * (1 - f) + tipW * f + curve * f * f, box + 0.004 + jawL * f)) }
        slab(jaw)
    case .scissors:
        let box = L * 0.55, spread: Float = 0.012, rr: Float = 0.0088
        rings(rr, spread, rr)
        for sx: Float in [-1, 1] {
            slab([V2(sx * (spread - 0.004), rr * 1.6), V2(sx * (spread - 0.0005), rr * 1.6 + 0.004), V2(sx * 0.0035, box), V2(sx * 0.0005, box - 0.005)])
        }
        // Blades: curved Mayo pattern, wide at the screw, rounded tips.
        let bl = L - box
        var blade: [V2] = []
        let n = 5
        for i in 0...n { let f = Float(i) / Float(n); blade.append(V2(-0.0055 * (1 - f) - 0.0018 * f + 0.005 * f * f, box - 0.004 + bl * f)) }
        for i in (0...n).reversed() { let f = Float(i) / Float(n); blade.append(V2(0.0055 * (1 - f) + 0.0018 * f + 0.005 * f * f, box - 0.004 + bl * f)) }
        slab(blade, t * 0.8)
        s.append(Prim.lathe([V2(0, 0), V2(0.0028, 0), V2(0.0028, t * 1.2), V2(0, t * 1.2)], segments: 8, material: material), Xform(translation: V3(0, 0, box)))
    case .forceps:
        // Two tapering arms joined at the back, slightly open at the tips; serrated grip zone is a raised pad.
        for sx: Float in [-1, 1] {
            slab([V2(sx * 0.0005, 0), V2(sx * 0.005, 0.004), V2(sx * 0.0045, L * 0.55), V2(sx * 0.0022, L), V2(sx * 0.0008, L), V2(sx * 0.0012, L * 0.5), V2(sx * 0.0005, 0.006)], 0.002)
            s.append(cuboid(V3(0.0035, 0.0006, L * 0.18), material: material),
                     Xform(translation: V3(sx * 0.0036, 0.0021, L * 0.42)))
        }
    case .scalpel:
        // #3 handle with a fitted #10 blade.
        let hl = L - 0.038
        slab(Shape2D.rounded([V2(-0.0045, 0), V2(0.0045, 0), V2(0.004, hl), V2(-0.004, hl)], radius: 0.002, segments: 2), 0.0024)
        slab([V2(-0.0035, hl - 0.012), V2(0.0035, hl - 0.012), V2(0.0045, hl + 0.012), V2(0.002, L - 0.004), V2(-0.0005, L), V2(-0.004, hl + 0.016)], 0.0004, y: 0.0012)
    }
    return s
}
