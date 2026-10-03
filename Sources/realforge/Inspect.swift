import Foundation
import RealityKit
import Metal
import RealCore
import RealMaterials
import RealKit
import RealLibrary

func listCommand(_ args: Args) {
    let tag = args.next()
    for t in Catalog.assets where tag == nil || t.tags.contains(tag!) { print(pad(t.id), t.summary) }
    for s in SceneCatalog.all where tag == nil || s.tags.contains(tag!) { print(pad(s.id), "(scene)", s.summary) }
}

func statsCommand(_ args: Args) {
    let seed = UInt64(args.opt("--seed") ?? "1") ?? 1
    let ids = args.rest.isEmpty ? Catalog.assets.map { $0.id } : args.rest
    for id in ids {
        guard let m = Catalog.build(id, seed: seed) else { print("unknown \(id)"); continue }
        let t0 = Date()
        _ = Catalog.build(id, seed: seed)
        let ms = Date().timeIntervalSince(t0) * 1000
        let lods = m.levels.map { "\($0.triangleCount)" }.joined(separator: "/")
        let budget = Catalog.type(id)!.budget
        print(pad(id), "tris \(lods)", "budget \(budget)", "mats \(m.levels[0].materials.joined(separator: ","))", String(format: "gen %.0fms", ms))
    }
}

@MainActor
func texturesCommand(_ args: Args) throws {
    let size = Int(args.opt("--size") ?? "512") ?? 512
    let out = args.opt("--out") ?? "out/tex"
    guard let synth = TextureSynth.shared else { throw CLIError("Metal unavailable") }
    for key in args.rest.isEmpty ? MaterialLibrary.keys : args.rest {
        let spec = MaterialLibrary.spec(for: key)
        guard spec.program != nil else { continue }
        let set = try synth.generate(spec, size: size)
        writePNG(synth.cgImage(set.albedo)!, "\(out)/\(key)-albedo.png")
        writePNG(synth.cgImage(set.normal)!, "\(out)/\(key)-normal.png")
        writePNG(synth.cgImage(set.roughness)!, "\(out)/\(key)-rough.png")
        print(key)
    }
}

/// Loads every ShaderGraph option variant; prints failures (bad node ids, type mismatches).
@MainActor
func shadersCommand(_ args: Args) async throws {
    let keepAlive = try RealityRenderer()
    _ = keepAlive
    var failures = 0
    // One setter per RealShaderOptions flag; every combination is loaded.
    let flags: [(inout RealShaderOptions, Bool) -> Void] = [
        { $0.cutout = $1 }, { $0.wind = $1 }, { $0.translucency = $1 }, { $0.antiTile = $1 }, { $0.topLayer = $1 },
        { $0.fog = $1 }, { $0.triplanar = $1 }, { $0.metallicMap = $1 }, { $0.instanceJitter = $1 }, { $0.splat = $1 },
        { $0.transparent = $1 }, { $0.flowNormals = $1 },
    ]
    let t0 = Date()
    var checked = 0
    for bits in 0..<(1 << flags.count) {
        var o = RealShaderOptions()
        for (i, set) in flags.enumerated() { set(&o, bits & (1 << i) != 0) }
        // Combinations no material produces: transparent water/glass never uses foliage or splat paths,
        // and flow normals only come with transparency.
        if o.flowNormals && !o.transparent { continue }
        if o.transparent && (o.cutout || o.wind || o.translucency || o.splat || o.topLayer || o.triplanar) { continue }
        checked += 1
        do { _ = try await RealShaderGraph.material(o) } catch { failures += 1; print("FAIL \(o): \(error)") }
    }
    print("\(checked) variants in \(Int(Date().timeIntervalSince(t0)))s")
    if args.flag("--dump") {
        var o = RealShaderOptions(); o.cutout = true; o.wind = true; o.translucency = true; o.topLayer = true
        print(RealShaderGraph.usda(o))
    }
    print("shaders checked, \(failures) failures")
    if failures > 0 { throw CLIError("\(failures) ShaderGraph variants failed") }
}

@MainActor
func skyCommand(_ args: Args) throws {
    guard let synth = TextureSynth.shared else { throw CLIError("Metal unavailable") }
    let sky = skyPreset(args.next() ?? "afternoon")
    let tex = try synth.skyTexture(SkyParams(sunDir: sky.sunDirection, turbidity: sky.turbidity, width: 512, drawSun: true))
    var half = [Float16](repeating: 0, count: 512 * 256 * 4)
    tex.getBytes(&half, bytesPerRow: 512 * 8, from: MTLRegionMake2D(0, 0, 512, 256), mipmapLevel: 0)
    for (name, y) in [("zenith", 2), ("mid", 64), ("horizon+", 120), ("ground", 200)] {
        var acc = SIMD3<Float>.zero
        for x in 0..<512 { let i = (y * 512 + x) * 4; acc += SIMD3(Float(half[i]), Float(half[i + 1]), Float(half[i + 2])) }
        print(name, acc / 512)
    }
}

func skyPreset(_ name: String) -> SunSky {
    ["morning": .morning, "midday": .midday, "golden": .goldenHour][name] ?? .afternoon
}
