import simd
import Foundation

/// Cloth hardcover book, 235 x 155 x 32 mm, lying cover up with the spine on -X: 3 mm boards with 3 mm
/// squares, rounded spine with French hinge grooves, page block with a convex spine edge and a concave
/// fore-edge, headbands, gilt bands on the spine, pastedown endpapers. The front cover and four leaf
/// groups hinge about the spine axis (the leaves follow the cover at slightly lower ratios so they fan
/// and lift at the fore-edge); the spine folds under the gutter at half the angle. A slide keeps the open book centered.
public struct HardcoverBook: RealArticulated {
    public static let id = "hardcover-book"
    public static let summary = "Cloth hardcover book, 235 x 155 x 32 mm: boards with squares, rounded spine with hinge grooves, page block whose leaves fan as the cover opens."
    public static let tags = ["prop", "office", "book", "paper", "articulated"]
    public static let budget = 4_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 38, distance: 0.78, studio: true)

    /// Bookcloth color (sRGB hex): oxblood 0x6B2026, navy 0x24364F, bottle green 0x23402F, grey 0x5A5A58.
    public var color: UInt32 = 0x6B2026
    /// Head-to-tail height, width (spine to fore-edge) and closed thickness (m).
    public var height: Float = 0.235
    public var width: Float = 0.155
    public var thickness: Float = 0.032
    public var gilt = true
    /// Leaf-group ratios (cover side first): lower ratios lag behind and lift at the fore-edge.
    public var leafRatios: [Float] = [0.995, 0.985, 0.97, 0.95]
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [6])
        let cloth: MaterialKey = "book.cloth:" + String(format: "%06X", color)
        let L = height, W = width, T = thickness
        let b: Float = 0.003, sq: Float = 0.003, bulge: Float = 0.0045
        let sx = -W / 2 + bulge / 2                     // spine line (outer cover edge at the hinge)
        let pivot = V3(sx, T / 2, 0)
        let blockL = L - 2 * sq, blockX0 = sx + 0.0015, blockX1 = sx + W - sq
        let boardX0 = sx + 0.0075

        // Parts: whole book slides so the open spread stays centered; cover and leaves hinge about Z.
        let open: Float = 178
        rig.part("book", pivot: .zero, joint: Joint(.prismatic, axis: V3(1, 0, 0), range: 0...W / 2, mimic: .init("cover", ratio: (W / 2) / 180)))
        rig.part("spine", parent: "book", pivot: V3(sx, bulge + 0.0006, 0), joint: Joint(.revolute, axis: V3(0, 0, 1), range: 0...90, mimic: .init("cover", ratio: 0.5)))
        rig.part("cover", parent: "book", pivot: pivot, joint: .hinge(axis: V3(0, 0, 1), 0...open, duration: 1.1))
        for (k, r) in leafRatios.enumerated() {
            rig.part("leaves\(k + 1)", parent: "book", pivot: pivot, joint: Joint(.revolute, axis: V3(0, 0, 1), range: 0...open, mimic: .init("cover", ratio: r)))
        }

        // Page block section between y0 and y1: convex at the spine, concave at the fore-edge.
        let blockLo = b, blockHi = T - b, blockMid = (blockLo + blockHi) / 2, blockHalf = (blockHi - blockLo) / 2
        func edgeX(_ y: Float, fore: Bool) -> Float {
            let t = (y - blockMid) / blockHalf, bow = 1 - t * t
            return fore ? blockX1 - 0.0016 * bow : blockX0 - 0.0012 * bow
        }
        func block(_ y0: Float, _ y1: Float, lod: Int) -> Surface {
            let n = lod == 0 ? 3 : 1
            var pts: [V2] = []
            for k in 0...n { let y = y0 + (y1 - y0) * Float(k) / Float(n); pts.append(V2(edgeX(y, fore: true), y)) }
            for k in 0...n { let y = y1 - (y1 - y0) * Float(k) / Float(n); pts.append(V2(edgeX(y, fore: false), y)) }
            var s = Prim.extrude(pts, depth: blockL, bevel: 0, material: "paper.pages")
            for i in s.positions.indices where abs(s.normals[i].z) < 0.9 { s.uvs[i] = V2(s.uvs[i].y, s.uvs[i].x) }
            s.computeTangents()
            return s
        }
        // Page surface card (top or bottom face of a leaf group).
        func pageFace(_ y: Float, up: Bool) -> (Surface, Xform) {
            let x0 = edgeX(y, fore: false) + 0.0004, x1 = edgeX(y, fore: true) - 0.0004
            var s = Prim.terrain(size: V2(x1 - x0, blockL - 0.0008), segments: 1, material: "paper.sheet:F1ECDD") { _ in 0 }
            if !up { s = s.flipped() }
            return (s, Xform(translation: V3((x0 + x1) / 2, y + (up ? 0.00012 : -0.00012), 0)))
        }

        for l in 0..<2 {
            let lod = l...l
            // Back board (static half): cloth over board, groove strip at the hinge, pastedown under the block.
            rig.add(Prim.roundedBox(V3(sx + W - boardX0, b, L), radius: 0.0012, bevelSegments: l == 0 ? 2 : 1, material: cloth),
                    Xform(translation: V3((boardX0 + sx + W) / 2, b / 2, 0)).jittered(&rng, deg: 0.05, offset: 0.0001), to: "book", lods: lod)
            rig.add(Prim.roundedBox(V3(0.0065, 0.0016, L - 0.001), radius: 0.0006, bevelSegments: 1, material: cloth),
                    Xform(translation: V3(sx + 0.0038, 0.0008, 0)), to: "book", lods: lod)
            // Back half of the block and its top page.
            rig.add(block(blockLo, T / 2, lod: l), to: "book", lods: lod)
            let top = pageFace(T / 2, up: true); rig.add(top.0, top.1, to: "book", lods: lod)
            // Front board: mirror of the back board on top, pastedown endpaper on its underside.
            rig.add(Prim.roundedBox(V3(sx + W - boardX0, b, L), radius: 0.0012, bevelSegments: l == 0 ? 2 : 1, material: cloth),
                    Xform(translation: V3((boardX0 + sx + W) / 2, T - b / 2, 0)).jittered(&rng, deg: 0.05, offset: 0.0001), to: "cover", lods: lod)
            rig.add(Prim.roundedBox(V3(0.0065, 0.0016, L - 0.001), radius: 0.0006, bevelSegments: 1, material: cloth),
                    Xform(translation: V3(sx + 0.0038, T - 0.0008, 0)), to: "cover", lods: lod)
            var paste = Prim.terrain(size: V2(sx + W - boardX0 - 0.012, L - 0.012), segments: 1, material: "paper.sheet:EDE4CC") { _ in 0 }.flipped()
            paste.computeTangents()
            rig.add(paste, Xform(translation: V3((boardX0 + sx + W) / 2 + 0.002, T - b - 0.00012, 0)), to: "cover", lods: lod)
            // Front leaf groups, cover side first.
            let n = leafRatios.count, step = (blockHi - T / 2) / Float(n)
            for k in 0..<n {
                let y1 = blockHi - Float(k) * step, y0 = y1 - step + 0.00015
                rig.add(block(y0, y1, lod: l), to: "leaves\(k + 1)", lods: lod)
                let f = pageFace(y0, up: false); rig.add(f.0, f.1, to: "leaves\(k + 1)", lods: lod)
                if l == 0 && k > 0 { let u = pageFace(y1, up: true); rig.add(u.0, u.1, to: "leaves\(k + 1)", lods: lod) }
            }
            // Spine: cloth shell bowed out on -X, closing the gap between the boards.
            let R = ((T / 2) * (T / 2) + bulge * bulge) / (2 * bulge)
            let cx = sx - bulge + R, alpha = asin(min(0.999, (T / 2) / R))
            let segs = l == 0 ? 10 : 4
            var shell: [V2] = []
            for k in 0...segs { let a = .pi - alpha + 2 * alpha * Float(k) / Float(segs); shell.append(V2(cx + cos(a) * R, T / 2 + sin(a) * R)) }
            for k in 0...segs { let a = .pi + alpha - 2 * alpha * Float(k) / Float(segs); shell.append(V2(cx + cos(a) * (R - 0.0022), T / 2 + sin(a) * (R - 0.0022) * 0.9)) }
            rig.add(Prim.extrude(shell, depth: L, bevel: 0.0006, bevelSegments: 1, material: cloth), to: "spine", lods: lod)
            if gilt && l == 0 {
                for z in [-L / 2 + 0.022, -L / 2 + 0.026, L / 2 - 0.026, L / 2 - 0.022] {
                    let band = shell.prefix(segs + 1).map { V2(cx + ($0.x - cx) * 1.012, T / 2 + ($0.y - T / 2) * 1.0) }
                    let inner = band.reversed().map { V2(cx + ($0.x - cx) * 0.99, $0.y) }
                    rig.add(Prim.extrude(Array(band) + inner, depth: 0.0012, bevel: 0.0002, bevelSegments: 1, material: "metal.brass"),
                            Xform(translation: V3(0, 0, z)), to: "spine", lods: 0...0)
                }
                // Title label block between the bands.
                let label = shell.prefix(segs + 1).enumerated().filter { $0.offset >= 2 && $0.offset <= segs - 2 }.map { V2(cx + ($0.element.x - cx) * 1.011, $0.element.y) }
                let labelIn = label.reversed().map { V2(cx + ($0.x - cx) * 0.99, $0.y) }
                rig.add(Prim.extrude(label + labelIn, depth: 0.05, bevel: 0.0002, bevelSegments: 1, material: "metal.brass"),
                        Xform(translation: V3(0, 0, -L / 2 + 0.07)), to: "spine", lods: 0...0)
            }
            // Headbands at head and tail, split between the halves.
            for z in [-blockL / 2 - 0.0006, blockL / 2 + 0.0006] {
                for (part, y0, y1) in [("book", blockLo + 0.0015, T / 2), ("leaves\(leafRatios.count)", T / 2, blockHi - 0.0015)] {
                    rig.add(Prim.cylinder(radius: 0.0012, height: y1 - y0, bevel: 0.0005, segments: 6, bevelSegments: 1, material: "fabric.canvas:B8A060"),
                            Xform(translation: V3(blockX0 + 0.0003, y0, z)), to: part, lods: 0...0)
                }
            }
        }
        groundAO(&rig, height: 0.012, floor: 0.7)
        rig.states = [RigState("closed"), RigState("ajar", ["cover": 35]), RigState("open", ["cover": open])]
        return rig
    }
}
