import Foundation
import ImageIO
import UniformTypeIdentifiers
import RealityKit
import RealCore
import RealMaterials
import RealKit
import RealLibrary
import Metal

func writePNG(_ img: CGImage, _ path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
}

var args = Array(CommandLine.arguments.dropFirst())
func opt(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    let v = args[i + 1]; args.removeSubrange(i...(i + 1)); return v
}
func flag(_ name: String) -> Bool { if let i = args.firstIndex(of: name) { args.remove(at: i); return true }; return false }

let usage = """
realforge list [tag]
realforge stats [id] [--seed n]
realforge textures [key...] [--size 512] [--out out/tex]
realforge render <id|scene> [--seed n] [--out out/<id>.png] [--w 1280] [--h 800] [--sky morning|midday|afternoon|golden]
                 [--az deg] [--el deg] [--dist k] [--lod n] [--pbr] [--no-ground]
"""

@MainActor
func run() async throws {
    let cmd = args.isEmpty ? "help" : args.removeFirst()
    switch cmd {
    case "list":
        for t in Catalog.assets where args.isEmpty || t.tags.contains(args[0]) {
            print(t.id.padding(toLength: 16, withPad: " ", startingAt: 0), t.summary)
        }
        for s in SceneCatalog.ids { print(s.padding(toLength: 16, withPad: " ", startingAt: 0), "(scene)") }
    case "stats":
        let seed = UInt64(opt("--seed") ?? "1") ?? 1
        let ids = args.isEmpty ? Catalog.assets.map { $0.id } : args
        for id in ids {
            guard let m = Catalog.build(id, seed: seed) else { print("unknown \(id)"); continue }
            let t0 = Date()
            _ = Catalog.build(id, seed: seed)
            let ms = Date().timeIntervalSince(t0) * 1000
            let lods = m.levels.map { "\($0.triangleCount)" }.joined(separator: "/")
            print(id.padding(toLength: 16, withPad: " ", startingAt: 0), "tris \(lods)", "mats \(m.levels[0].materials.joined(separator: ","))", String(format: "gen %.0fms", ms))
        }
    case "textures":
        let size = Int(opt("--size") ?? "512") ?? 512
        let out = opt("--out") ?? "out/tex"
        let synth = TextureSynth.shared!
        for key in args.isEmpty ? MaterialLibrary.keys : args {
            let spec = MaterialLibrary.spec(for: key)
            guard spec.program != nil else { continue }
            let set = try synth.generate(spec, size: size)
            writePNG(synth.cgImage(set.albedo)!, "\(out)/\(key)-albedo.png")
            writePNG(synth.cgImage(set.normal)!, "\(out)/\(key)-normal.png")
            writePNG(synth.cgImage(set.roughness)!, "\(out)/\(key)-rough.png")
            print(key)
        }
    case "render":
        let seed = UInt64(opt("--seed") ?? "1") ?? 1
        let w = Int(opt("--w") ?? "1280") ?? 1280, h = Int(opt("--h") ?? "800") ?? 800
        let az = Float(opt("--az") ?? "35") ?? 35, el = Float(opt("--el") ?? "10") ?? 10
        let dist = Float(opt("--dist") ?? "1.15") ?? 1.15
        let lod = Int(opt("--lod") ?? "0") ?? 0
        let skyName = opt("--sky") ?? "afternoon"
        let pbr = flag("--pbr"), noGround = flag("--no-ground")
        let fog = opt("--fog")
        guard let id = args.first else { print(usage); return }
        let out = opt("--out") ?? "out/\(id).png"
        RealKitSetup.register()
        if pbr { RealMaterialCache.shared.useShaderGraph = false }
        let sky: SunSky = ["morning": .morning, "midday": .midday, "golden": .goldenHour][skyName] ?? .afternoon
        var skyP = sky
        if let fog, let d = Float(fog) { skyP.fogDensity = d }
        let env = try RealEnvironment(skyP, skybox: true)
        let preview = try RealPreview(environment: env)
        let root = Entity()
        let t0 = Date()
        var focus: Entity
        if let scene = SceneCatalog.build(id, seed: seed) {
            focus = try await scene.entity()
            root.addChild(focus)
            if let cam = scene.camera { preview.look(from: cam.eye, at: cam.target, fov: cam.fov) }
        } else {
            guard let asset = Catalog.build(id, seed: seed) else { print("unknown \(id)"); return }
            let model = asset.levels[min(lod, asset.levels.count - 1)]
            focus = try await model.modelEntityAsync()
            root.addChild(focus)
            if !noGround {
                let g = try await GroundPatch().with { $0.size = 30; $0.segments = 60; $0.relief = 0.05; $0.flatCenter = 6 }.build(seed: 3).levels[0].modelEntityAsync()
                root.addChild(g)
            }
            preview.frame(focus, azimuth: az, elevation: el, distanceScale: dist)
        }
        env.illuminate(root)
        preview.add(root)
        let build = Date().timeIntervalSince(t0) * 1000
        guard let img = try await preview.render(width: w, height: h, frames: 6) else { print("render failed"); return }
        writePNG(img, out)
        print("\(out) build \(Int(build))ms tex \(RealMaterialCache.shared.textureBytes / 1_048_576)MB")
    case "shaders":
        // Load every option variant; print failures (bad node ids, type mismatches).
        let keepAlive = try RealityRenderer()
        _ = keepAlive
        for bits in 0..<256 {
            var o = RealShaderOptions()
            o.cutout = bits & 1 != 0; o.wind = bits & 2 != 0; o.translucency = bits & 4 != 0
            o.antiTile = bits & 8 != 0; o.topLayer = bits & 16 != 0; o.fog = bits & 32 != 0
            o.triplanar = bits & 64 != 0; o.metallicMap = bits & 128 != 0
            do { _ = try await RealShaderGraph.material(o) } catch { print("FAIL \(o): \(error)") }
        }
        if let i = args.firstIndex(of: "--dump") {
            var o = RealShaderOptions(); o.cutout = true; o.wind = true; o.translucency = true; o.topLayer = true
            _ = i
            print(RealShaderGraph.usda(o))
        }
        print("shaders checked")
    case "catalog":
        var md = "# Catalog\n\nGenerated by `swift run -q realforge catalog`. Do not edit by hand.\n\n"
        md += "| id | tags | LOD tris | materials | summary |\n|---|---|---|---|---|\n"
        for t in Catalog.assets {
            let m = t.init().build(seed: 1)
            md += "| `\(t.id)` | \(t.tags.joined(separator: ", ")) | \(m.levels.map { "\($0.triangleCount)" }.joined(separator: " / ")) | \(m.levels[0].materials.map { "`\($0)`" }.joined(separator: " ")) | \(t.summary) |\n"
        }
        md += "\n## Scenes\n\n" + SceneCatalog.ids.map { "- `\($0)`" }.joined(separator: "\n") + "\n"
        md += "\n## Materials\n\nKeys accept a hex tint suffix, e.g. `metal.painted:1F4E8C`.\n\n| key | program | tile (m) | res | mode | wind | extras |\n|---|---|---|---|---|---|---|\n"
        for k in MaterialLibrary.keys {
            let s = MaterialLibrary.spec(for: k)
            var extras: [String] = []
            if s.translucency > 0 { extras.append("translucency") }
            if s.antiTile { extras.append("anti-tile") }
            if s.triplanar { extras.append("triplanar") }
            if s.topAmount > 0 { extras.append("moss layer") }
            if s.hasMetallicMap { extras.append("metallic map") }
            md += "| `\(k)` | \(s.program.map { "\($0)" } ?? "scalar") | \(s.tileSize > 0 ? String(format: "%.2g", s.tileSize) : "atlas") | \(s.program == nil ? "-" : "\(s.resolution)") | \(s.mode) | \(s.wind > 0 ? String(format: "%.2g", s.wind) : "-") | \(extras.joined(separator: ", ")) |\n"
        }
        try md.write(toFile: "CATALOG.md", atomically: true, encoding: .utf8)
        print("CATALOG.md")
    case "bench":
        // Release-mode timing: CPU generation, GPU texture synthesis, scene upload, scene stats.
        RealKitSetup.register()
        func ms(_ t: Date) -> String { String(format: "%6.1f ms", Date().timeIntervalSince(t) * 1000) }
        print("-- geometry generation (all LODs)")
        for t in Catalog.assets {
            let t0 = Date(); let m = t.init().build(seed: 1)
            print(t.id.padding(toLength: 16, withPad: " ", startingAt: 0), ms(t0), "tris", m.levels.map { "\($0.triangleCount)" }.joined(separator: "/"))
        }
        print("-- GPU texture synthesis (1024², full PBR set + mips)")
        let synth = TextureSynth.shared!
        for k in ["bark.oak", "leaf.oak", "rock.granite", "ground.forest", "wood.oak", "metal.painted"] {
            let spec = MaterialLibrary.spec(for: k)
            _ = try synth.generate(spec, size: 256)
            let t0 = Date(); _ = try synth.generate(spec, size: 1024)
            print(k.padding(toLength: 16, withPad: " ", startingAt: 0), ms(t0))
        }
        print("-- scenes (build + upload, cold materials)")
        for id in SceneCatalog.ids {
            RealMaterialCache.shared.purge()
            let t0 = Date()
            let scene = SceneCatalog.build(id, seed: 1)!
            let gen = ms(t0)
            let t1 = Date()
            let e = try await scene.entity()
            var models = 0, instanced = 0, instances = 0
            func walk(_ x: Entity) {
                if x.components.has(ModelComponent.self) { models += 1 }
                if let mi = x.components[MeshInstancesComponent.self], let p = mi[partIndex: 0] { instanced += 1; instances += p.data.instanceCount }
                x.children.forEach(walk)
            }
            walk(e)
            let tris = scene.singles.reduce(0) { $0 + $1.asset.levels[0].triangleCount }
                + scene.fields.reduce(0) { $0 + $1.asset.levels[0].triangleCount * $1.transforms.count }
            print(id.padding(toLength: 14, withPad: " ", startingAt: 0), "gen", gen, "upload", ms(t1), "entities \(models) (instanced \(instanced), \(instances) instances)",
                  "worst-case LOD0 tris \(tris / 1000)k", "tex \(RealMaterialCache.shared.textureBytes / 1_048_576)MB")
        }
    case "sky":
        let synth = TextureSynth.shared!
        let sky: SunSky = ["morning": .morning, "midday": .midday, "golden": .goldenHour][args.first ?? ""] ?? .afternoon
        let tex = try synth.skyTexture(SkyParams(sunDir: sky.sunDirection, turbidity: sky.turbidity, width: 512, drawSun: true))
        var half = [Float16](repeating: 0, count: 512 * 256 * 4)
        tex.getBytes(&half, bytesPerRow: 512 * 8, from: MTLRegionMake2D(0, 0, 512, 256), mipmapLevel: 0)
        for (name, y) in [("zenith", 2), ("mid", 64), ("horizon+", 120), ("ground", 200)] {
            var acc = SIMD3<Float>.zero
            for x in 0..<512 { let i = (y * 512 + x) * 4; acc += SIMD3(Float(half[i]), Float(half[i + 1]), Float(half[i + 2])) }
            print(name, acc / 512)
        }
    default:
        print(usage)
    }
}
try await run()
