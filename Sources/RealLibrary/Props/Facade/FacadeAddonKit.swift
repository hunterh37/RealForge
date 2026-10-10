import simd
import Foundation

/// Helpers shared by the facade add-on props. Pieces are authored with the wall plane at z = 0 and the
/// piece projecting toward +Z, then `centerZ` recenters bounds on X/Z (the catalog contract), so the wall
/// face ends at z = -depth / 2. Wall pieces keep y = 0 at their lowest point; roof pieces sit on y = 0.
enum FA {
    static let X = V3(1, 0, 0), Y = V3(0, 1, 0), Z = V3(0, 0, 1)
    static func q(_ deg: Float, _ axis: V3) -> simd_quatf { simd_quatf(degrees: deg, axis: axis) }

    static func box(_ m: inout Model, _ size: V3, _ c: V3, _ mat: MaterialKey, r: Float = 0.003, rot: simd_quatf = .identity) {
        m.add(Prim.roundedBox(size, radius: min(r, min(size.x, min(size.y, size.z)) * 0.4), bevelSegments: 1, material: mat),
              Xform(translation: c, rotation: rot))
    }
    /// Round rod between two points (start cap hidden by the mounting).
    static func rod(_ m: inout Model, _ a: V3, _ b: V3, r: Float, _ mat: MaterialKey, sides: Int = 10) {
        m.add(Prim.tube([a, b], radii: [r, r], sides: sides, seamTile: 0.15, material: mat, capEnd: true))
    }
    static func path(_ m: inout Model, _ pts: [V3], r: Float, _ mat: MaterialKey, sides: Int = 10) {
        m.add(Prim.tube(pts, radii: Array(repeating: r, count: pts.count), sides: sides, seamTile: 0.15, material: mat, capEnd: true))
    }
    /// Cylinder along +Z from a base point.
    static func cylZ(_ m: inout Model, r: Float, h: Float, at c: V3, _ mat: MaterialKey, bevel: Float = 0.002, segments: Int = 20) {
        m.add(Prim.cylinder(radius: r, height: h, bevel: bevel, segments: segments, bevelSegments: 1, material: mat),
              Xform(translation: c, rotation: q(90, X)))
    }
    /// Cylinder along +X from a base point.
    static func cylX(_ m: inout Model, r: Float, h: Float, at c: V3, _ mat: MaterialKey, bevel: Float = 0.002, segments: Int = 20) {
        m.add(Prim.cylinder(radius: r, height: h, bevel: bevel, segments: segments, bevelSegments: 1, material: mat),
              Xform(translation: c, rotation: q(-90, Z)))
    }
    /// Profile (x out from the wall, y up) extruded along X for `length`, centered on X.
    static func run(_ m: inout Model, _ profile: [V2], length: Float, at c: V3 = .zero, _ mat: MaterialKey, bevel: Float = 0.002) {
        m.add(Prim.extrude(profile, depth: length, bevel: bevel, bevelSegments: 1, material: mat),
              Xform(translation: c, rotation: q(-90, Y)))
    }
    /// Profile (x out from the wall, y up) extruded along Z for `depth` (a bracket, centered on Z=0 then shifted by c).
    static func side(_ m: inout Model, _ profile: [V2], thick: Float, at c: V3, _ mat: MaterialKey, bevel: Float = 0.002) {
        m.add(Prim.extrude(profile, depth: thick, bevel: bevel, bevelSegments: 1, material: mat),
              Xform(translation: c, rotation: q(-90, Y)))
    }
    static func ball(_ m: inout Model, r: Float, at c: V3, _ mat: MaterialKey) {
        m.add(Prim.superellipsoid(V3(repeating: r * 2), exponent: 2, subdivisions: 8, material: mat), Xform(translation: c))
    }
    /// Recenters the model on Z (X is already centered), keeping y.
    static func centerZ(_ m: Model) -> Model {
        let bb = m.bounds
        return m.transformed(Xform(translation: V3(0, 0, -(bb.min.z + bb.max.z) / 2)))
    }
}
