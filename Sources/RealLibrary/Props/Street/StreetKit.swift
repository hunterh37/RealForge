import simd
import Foundation

/// Box centered at `p`, optional yaw degrees.
func bx(_ m: inout Model, _ s: V3, _ p: V3, _ mat: MaterialKey, r: Float = 0.004, yaw: Float = 0, bs: Int = 1) {
    m.add(Prim.roundedBox(s, radius: min(r, min(s.x, s.y, s.z) / 2.2), bevelSegments: bs, material: mat), Xform(translation: p, rotation: simd_quatf(degrees: yaw, axis: .up)))
}
/// Upright cylinder with base at `p`.
func cy(_ m: inout Model, _ r: Float, _ h: Float, _ p: V3, _ mat: MaterialKey, bevel: Float = 0.003, seg: Int = 32) {
    m.add(Prim.cylinder(radius: r, height: h, bevel: min(bevel, r / 2.5), segments: seg, material: mat), Xform(translation: p))
}
/// Round rod from `a` to `b`.
func rod(_ m: inout Model, _ a: V3, _ b: V3, _ r: Float, _ mat: MaterialKey, sides: Int = 12) {
    m.add(Prim.tube([a, b], radii: [r, r], sides: sides, seamTile: 0.3, material: mat, capEnd: true))
}
