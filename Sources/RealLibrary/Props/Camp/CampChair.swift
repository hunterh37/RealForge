import simd
import Foundation

/// Folding quad camp chair: 19 mm powder-coated steel tube frame with X braces front, back and sides,
/// seat 45 cm high and 52 cm wide, a polyester canvas sling that sags under its own weight, sleeves
/// around the frame, armrests and a mesh cup holder. Front faces +Z.
public struct CampChair: RealAsset {
    public static let id = "camp-chair"
    public static let summary = "Folding quad camp chair: steel tube X-frame, sagging canvas seat and back sling, armrests, cup holder, plastic feet."
    public static let tags = ["prop", "camp", "furniture", "fabric", "metal"]
    public static let budget = 6_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 14, distance: 1.1)

    /// Sling color (sRGB hex) on `fabric.canvas`.
    public var fabricColor: UInt32 = 0x2C4058
    /// Frame paint color.
    public var frameColor: UInt32 = 0x1C1D1F
    public var seatHeight: Float = 0.45
    public var width: Float = 0.54
    public var sag: Float = 0.07
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let cloth = "fabric.canvas:" + String(format: "%06X", fabricColor)
        let steel = "metal.painted:" + String(format: "%06X", frameColor)
        let hx = width / 2, sh = seatHeight
        let tr: Float = 0.0095
        let zf: Float = 0.24, zb: Float = -0.22
        let lean = rng.float(-1.5...1.5)
        func tube(_ pts: [V3], _ r: Float = tr) {
            m.add(Prim.tube(pts, radii: pts.map { _ in r }, sides: 8, seamTile: 0.2, material: steel, capEnd: false))
        }
        // Legs and back uprights.
        for s: Float in [-1, 1] {
            let x = s * (hx + 0.02)
            tube([V3(x, 0.02, zf + 0.02), V3(x * 0.99, 0.62, zf - 0.01)])                     // front leg up to the armrest
            tube(catmull([V3(x, 0.02, zb), V3(x * 0.98, 0.5, zb - 0.04), V3(x * 0.94, 0.97, zb - 0.13)], per: 4))  // back upright
            tube([V3(x * 0.99, 0.62, zf - 0.01), V3(x * 0.98, 0.6, zb - 0.06)])                 // armrest rail
            // Side X under the armrest.
            tube([V3(x, 0.06, zf), V3(x * 0.99, 0.5, zb - 0.03)])
            tube([V3(x, 0.06, zb), V3(x * 0.99, 0.5, zf - 0.005)])
            // Feet.
            for z in [zf + 0.02, zb] {
                m.add(turned([(0, 0), (0.016, 0), (0.017, 0.006), (0.013, 0.03), (0, 0.03)], segments: 10, material: "plastic.black"),
                      Xform(translation: V3(x, 0, z)))
            }
            // Armrest pad.
            m.add(Prim.roundedBox(V3(0.055, 0.022, 0.4), radius: 0.008, bevelSegments: 2, material: "plastic.black"),
                  Xform(translation: V3(x * 0.99, 0.625, (zf + zb) / 2 - 0.02), rotation: simd_quatf(degrees: 2.5, axis: V3(1, 0, 0))))
            // Rivets at the side X crossing.
            m.add(turned([(0, -0.004), (0.008, -0.004), (0.008, 0.004), (0, 0.004)], segments: 8, material: "metal.steel"),
                  Xform(translation: V3(x + s * 0.011, 0.28, (zf + zb) / 2), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        }
        // Front and back X braces, seat rails.
        tube([V3(-hx, 0.06, zf + 0.01), V3(hx, sh - 0.01, zf)]); tube([V3(hx, 0.06, zf + 0.01), V3(-hx, sh - 0.01, zf)])
        tube([V3(-hx, 0.06, zb), V3(hx, sh - 0.06, zb - 0.02)]); tube([V3(hx, 0.06, zb), V3(-hx, sh - 0.06, zb - 0.02)])
        // Sling: one sheet from the front edge, down into the seat, up the back; sags across X.
        let prof: [V3] = catmull([V3(0, sh, zf + 0.01), V3(0, sh - 0.03, 0.05), V3(0, sh - 0.07, -0.12), V3(0, sh + 0.02, zb - 0.06),
                                  V3(0, 0.72, zb - 0.1), V3(0, 0.95, zb - 0.14)], per: 4)
        let nu = 14
        var rows: [[V3]] = [], uvs: [[V2]] = []
        var vAcc: Float = 0
        for (j, p) in prof.enumerated() {
            if j > 0 { vAcc += simd_distance(p, prof[j - 1]) }
            let t = Float(j) / Float(prof.count - 1)
            let isSeat = 1 - smoothstep(0.45, 0.62, t)
            var row: [V3] = [], uv: [V2] = []
            for i in 0...nu {
                let u = Float(i) / Float(nu) * 2 - 1
                let bow = (1 - u * u)
                let x = u * (hx - 0.005) * (1 - 0.03 * bow)
                // Seat sags down, back bulges rearward; edges stay on the frame.
                let edgeT = min(t / 0.05, (1 - t) / 0.05, 1)
                let dy = -sag * bow * isSeat * edgeT
                let dz = -sag * 0.8 * bow * (1 - isSeat) * edgeT
                let wr = 0.004 * sin(u * 9 + t * 5) * bow
                row.append(V3(x, p.y + dy + wr, p.z + dz)); uv.append(V2(x, vAcc))
            }
            rows.append(row); uvs.append(uv)
        }
        var top = WoodParts.grid(rows, uvs: uvs, material: cloth)
        top.recomputeNormals(weldSeams: false)
        // Faces up/forward: flip if the seat normal points down.
        let midSeat = rows.count / 4 * (nu + 1) + nu / 2
        if top.normals[midSeat].y < 0 {
            for t in stride(from: 0, to: top.indices.count, by: 3) { top.indices.swapAt(t + 1, t + 2) }
            top.recomputeNormals(weldSeams: false)
        }
        var back = top
        for t in stride(from: 0, to: back.indices.count, by: 3) { back.indices.swapAt(t + 1, t + 2) }
        for i in back.positions.indices { back.positions[i] -= top.normals[i] * 0.002; back.normals[i] = -top.normals[i] }
        top.computeTangents(); back.computeTangents()
        m.add(top); m.add(back)
        // Sleeves: rolled fabric along each side edge.
        for i in [0, nu] {
            let pts = rows.map { $0[i] }
            m.add(Prim.tube(pts, radii: pts.map { _ in 0.014 }, sides: 8, seamTile: 0.1, material: cloth, capEnd: false))
        }
        // Mesh cup holder hanging from the right armrest.
        m.add(turned([(0.0, 0.0), (0.035, 0.0), (0.04, 0.05), (0.042, 0.1), (0.038, 0.1)], segments: 16, material: "fabric.canvas:202224"),
              Xform(translation: V3(hx + 0.07, 0.51, 0.12)))
        m.add(Prim.tube(catmull([V3(hx + 0.03, 0.61, 0.12), V3(hx + 0.07, 0.612, 0.16), V3(hx + 0.11, 0.61, 0.12), V3(hx + 0.07, 0.608, 0.08), V3(hx + 0.03, 0.61, 0.12)], per: 4),
                        radii: Array(repeating: 0.004, count: 17), sides: 5, seamTile: 0.1, material: steel, capEnd: false))
        groundAO(&m, height: 0.35, floor: 0.6)
        return LODModel(m.transformed(Xform(rotation: simd_quatf(degrees: lean, axis: .up))))
    }
}
