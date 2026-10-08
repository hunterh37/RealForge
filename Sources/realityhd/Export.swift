import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import RealCore
import RealMaterials
import RealLibrary

/// `realityhd export <id> [--state s] [--seed n] [--lod n] [--size px] [--out dir] [--no-usdz]`:
/// writes `<out>/<id>.glb` (glTF 2.0 PBR, synthesized textures embedded, UVs scaled to 0...1 tiles)
/// and `<out>/<id>.usdz` through headless Blender when it is on PATH.
func exportCommand(_ args: Args) throws {
    guard let id = args.rest.first else { throw CLIError("usage: realityhd export <id> [--state s]") }
    let seed = UInt64(args.opt("--seed") ?? "1") ?? 1
    let lod = Int(args.opt("--lod") ?? "0") ?? 0
    let size = Int(args.opt("--size") ?? "1024") ?? 1024
    let outDir = args.opt("--out") ?? "out/export"
    let lm: LODModel
    if let rig = Catalog.rig(id, seed: seed) { lm = rig.posed(args.opt("--state")) }
    else if let b = Catalog.build(id, seed: seed) { lm = b }
    else { throw CLIError("unknown id \(id)") }
    let model = lm.levels[min(lod, lm.levels.count - 1)]
    try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    let glb = "\(outDir)/\(id).glb"
    try GLBWriter(textureSize: size).write(model, to: glb)
    var line = "\(glb) tris \(model.triangleCount)"
    if !args.rest.contains("--no-usdz"), let blender = which("blender") {
        let usdz = "\(outDir)/\(id).usdz"
        let py = "import bpy;bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=r'\(abs(glb))');bpy.ops.wm.usd_export(filepath=r'\(abs(usdz))',export_materials=True)"
        let p = Process(); p.executableURL = URL(fileURLWithPath: blender)
        p.arguments = ["-b", "--factory-startup", "--python-expr", py]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        line += FileManager.default.fileExists(atPath: usdz) ? " \(usdz)" : " usdz: blender failed"
    }
    print(line)
}

private func abs(_ p: String) -> String { URL(fileURLWithPath: p).standardizedFileURL.path }
private func which(_ tool: String) -> String? {
    for d in ["/opt/homebrew/bin", "/usr/local/bin", "/Applications/Blender.app/Contents/MacOS"] where FileManager.default.isExecutableFile(atPath: "\(d)/\(tool)") { return "\(d)/\(tool)" }
    return nil
}

struct GLBWriter {
    var textureSize: Int
    private var bin = Data()
    private var bufferViews: [[String: Any]] = []
    private var accessors: [[String: Any]] = []
    private var images: [[String: Any]] = []
    private var textures: [[String: Any]] = []
    private var materials: [[String: Any]] = []
    private var materialIndex: [MaterialKey: Int] = [:]

    init(textureSize: Int) { self.textureSize = textureSize }

    func write(_ model: Model, to path: String) throws {
        var w = self
        // Merge surfaces per material: one primitive each.
        var merged: [MaterialKey: Surface] = [:], order: [MaterialKey] = []
        for s in model.surfaces where !s.isEmpty {
            if merged[s.material] == nil { merged[s.material] = Surface(material: s.material); order.append(s.material) }
            merged[s.material]!.append(s, Xform())
        }
        var prims: [[String: Any]] = []
        for key in order {
            let s = merged[key]!
            let spec = MaterialLibrary.spec(for: key)
            let tile: Float = spec.tileSize > 0 && spec.mode != .emissive ? spec.tileSize : 1
            let pos = w.addFloats(s.positions.flatMap { [$0.x, $0.y, $0.z] }, comps: 3, minMax: true, target: 34962)
            let nrm = w.addFloats(s.normals.count == s.positions.count ? s.normals.flatMap { [$0.x, $0.y, $0.z] } : Array(repeating: 0, count: s.positions.count * 3), comps: 3, target: 34962)
            let uvs = s.uvs.count == s.positions.count ? s.uvs : Array(repeating: V2(0, 0), count: s.positions.count)
            let uv = w.addFloats(uvs.flatMap { [$0.x / tile, $0.y / tile] }, comps: 2, target: 34962)
            let idx = w.addIndices(s.indices)
            prims.append(["attributes": ["POSITION": pos, "NORMAL": nrm, "TEXCOORD_0": uv], "indices": idx, "material": try w.material(spec)])
        }
        var json: [String: Any] = [
            "asset": ["version": "2.0", "generator": "realityhd export"],
            "scene": 0, "scenes": [["nodes": [0]]],
            "nodes": [["mesh": 0, "name": model.name]],
            "meshes": [["name": model.name, "primitives": prims]],
            "materials": w.materials, "accessors": w.accessors, "bufferViews": w.bufferViews,
            "buffers": [["byteLength": w.bin.count]],
            "samplers": [["magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497]],
        ]
        if !w.images.isEmpty { json["images"] = w.images; json["textures"] = w.textures }
        var jd = try JSONSerialization.data(withJSONObject: json)
        while jd.count % 4 != 0 { jd.append(0x20) }
        var out = Data()
        func u32(_ v: Int) { var x = UInt32(v).littleEndian; out.append(Data(bytes: &x, count: 4)) }
        u32(0x46546C67); u32(2); u32(12 + 8 + jd.count + 8 + w.bin.count)
        u32(jd.count); u32(0x4E4F534A); out.append(jd)
        u32(w.bin.count); u32(0x004E4942); out.append(w.bin)
        try out.write(to: URL(fileURLWithPath: path))
    }

    private mutating func align() { while bin.count % 4 != 0 { bin.append(0) } }

    private mutating func addView(_ d: Data, target: Int?) -> Int {
        align()
        var v: [String: Any] = ["buffer": 0, "byteOffset": bin.count, "byteLength": d.count]
        if let target { v["target"] = target }
        bin.append(d); bufferViews.append(v)
        return bufferViews.count - 1
    }

    private mutating func addFloats(_ f: [Float], comps: Int, minMax: Bool = false, target: Int) -> Int {
        let view = addView(f.withUnsafeBufferPointer { Data(buffer: $0) }, target: target)
        var a: [String: Any] = ["bufferView": view, "componentType": 5126, "count": f.count / comps, "type": comps == 3 ? "VEC3" : "VEC2"]
        if minMax {
            var lo = [Float](repeating: .greatestFiniteMagnitude, count: comps), hi = [Float](repeating: -.greatestFiniteMagnitude, count: comps)
            for i in 0..<f.count { lo[i % comps] = min(lo[i % comps], f[i]); hi[i % comps] = max(hi[i % comps], f[i]) }
            a["min"] = lo; a["max"] = hi
        }
        accessors.append(a); return accessors.count - 1
    }

    private mutating func addIndices(_ i: [UInt32]) -> Int {
        let view = addView(i.withUnsafeBufferPointer { Data(buffer: $0) }, target: 34963)
        accessors.append(["bufferView": view, "componentType": 5125, "count": i.count, "type": "SCALAR"])
        return accessors.count - 1
    }

    private mutating func addImage(_ img: CGImage) -> Int {
        let d = NSMutableData()
        let dest = CGImageDestinationCreateWithData(d, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
        images.append(["bufferView": addView(d as Data, target: nil), "mimeType": "image/png"])
        textures.append(["source": images.count - 1, "sampler": 0])
        return textures.count - 1
    }

    private mutating func material(_ spec: MaterialSpec) throws -> Int {
        if let i = materialIndex[spec.key] { return i }
        var pbr: [String: Any] = ["metallicFactor": spec.metallic, "roughnessFactor": spec.roughness]
        var m: [String: Any] = ["name": spec.key, "pbrMetallicRoughness": pbr]
        if spec.program != nil, let synth = TextureSynth.shared {
            let set = try synth.generate(spec, size: textureSize)
            if let a = synth.cgImage(set.albedo) { pbr["baseColorTexture"] = ["index": addImage(a)] }
            if let r = synth.cgImage(set.roughness) {
                let met = set.metallic.flatMap { synth.cgImage($0) }
                pbr["metallicRoughnessTexture"] = ["index": addImage(packMR(r, met, metal: spec.metallic))]
                pbr["metallicFactor"] = 1; pbr["roughnessFactor"] = 1
            }
            if let n = synth.cgImage(set.normal) { m["normalTexture"] = ["index": addImage(n)] }
        } else {
            let c = spec.baseColor
            pbr["baseColorFactor"] = [c.x, c.y, c.z, 1]
        }
        switch spec.mode {
        case .transparent:
            var f = (pbr["baseColorFactor"] as? [Float]) ?? [1, 1, 1, 1]; f[3] = spec.opacity
            pbr["baseColorFactor"] = f; m["alphaMode"] = "BLEND"; m["doubleSided"] = true
        case .cutout: m["alphaMode"] = "MASK"; m["alphaCutoff"] = 0.5
        case .emissive:
            let e = spec.emissive == .zero ? spec.baseColor : spec.emissive
            m["emissiveFactor"] = [min(1, e.x), min(1, e.y), min(1, e.z)]
        case .opaque: break
        }
        if spec.twoSided { m["doubleSided"] = true }
        m["pbrMetallicRoughness"] = pbr
        materials.append(m); materialIndex[spec.key] = materials.count - 1
        return materials.count - 1
    }

    /// glTF metallicRoughness: G = roughness, B = metallic.
    private func packMR(_ rough: CGImage, _ metal: CGImage?, metal k: Float) -> CGImage {
        let w = rough.width, h = rough.height
        func gray(_ img: CGImage) -> [UInt8] {
            var p = [UInt8](repeating: 0, count: w * h)
            let ctx = CGContext(data: &p, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)!
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h)); return p
        }
        let r = gray(rough), mt = metal.map(gray)
        var px = [UInt8](repeating: 255, count: w * h * 4)
        for i in 0..<(w * h) { px[i * 4 + 1] = r[i]; px[i * 4 + 2] = mt?[i] ?? UInt8(k * 255); px[i * 4] = 255 }
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        return ctx.makeImage()!
    }
}
