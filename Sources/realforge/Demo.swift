import Foundation
import RealityKit
import RealCore
import RealMaterials
import RealKit
import RealLibrary

/// Engine feature demos rendered to out/demo-<name>.png. They build ad-hoc content with material
/// overrides, so they need no catalog entries.
@MainActor
func demoCommand(_ args: Args) async throws {
    RealKitSetup.register()
    let sky = skyPreset(args.opt("--sky") ?? "afternoon")
    let az = args.opt("--az").flatMap(Float.init), el = args.opt("--el").flatMap(Float.init)
    let pbr = args.flag("--pbr")
    RealMaterialCache.shared.useShaderGraph = !pbr
    guard let name = args.next() else { print("realforge demo splat|water|glass [--sky s] [--az deg] [--el deg] [--pbr]"); return }
    let env = try RealEnvironment(sky, skybox: true)
    let preview = try RealPreview(environment: env)
    let root = Entity()
    var cam: (eye: V3, at: V3) = (V3(0, 1.7, 7), V3(0, 0.2, -4))
    switch name {
    case "splat": cam = try await splatDemo(root)
    default: throw CLIError("unknown demo \(name)")
    }
    if let az {
        // Orbit the default camera around its target.
        let d = cam.eye - cam.at, r = simd_length(SIMD2(d.x, d.z)), e = el.map { $0 * .pi / 180 } ?? atan2(d.y, r)
        let a = az * .pi / 180, dist = simd_length(d)
        cam.eye = cam.at + V3(sin(a) * cos(e), sin(e), cos(a) * cos(e)) * dist
    }
    env.illuminate(root)
    preview.add(root)
    preview.look(from: cam.eye, at: cam.at, fov: 55)
    guard let img = try await preview.render(width: 1280, height: 800, frames: 6) else { throw CLIError("render failed") }
    let out = args.opt("--out") ?? "out/demo-\(name)\(pbr ? "-pbr" : "").png"
    writePNG(img, out)
    print(out)
}

/// Meadow ground with a worn dirt footpath and mud patches painted into the splat channel; grass
/// avoids the worn areas.
@MainActor
func splatDemo(_ root: Entity) async throws -> (eye: V3, at: V3) {
    let cache = RealMaterialCache.shared
    // Bare packed soil: forest floor without moss and with little litter.
    cache.overrides["demo.dirt"] = MaterialLibrary.spec(for: "ground.forest").with {
        $0.key = "demo.dirt"; $0.knobs = V4(0.05, 0.04, 0, 0); $0.colorA = linear(0x4A3F33); $0.colorB = linear(0x6B5D4C); $0.tileSize = 1.4; $0.seed = 21
    }
    cache.overrides["demo.worn"] = MaterialLibrary.spec(for: "ground.meadow").with {
        $0.key = "demo.worn"; $0.splat = "demo.dirt"; $0.splatSoftness = 0.25; $0.splatHeight = 1.5
    }
    func pathX(_ z: Float) -> Float { 1.6 * sin(z * 0.22) + 0.4 * sin(z * 0.61 + 1) }
    func wear(_ x: Float, _ z: Float) -> Float {
        // Ragged edge: the half-width wanders with fine noise.
        let d = abs(x - pathX(z)) + Noise.fbm(V3(x * 2.2, 1, z * 2.2), octaves: 3, seed: 3) * 0.35
        let path = 1 - smoothstep(0.3, 1.0, d)
        let mud = smoothstep(0.12, 0.3, Noise.fbm(V3(x * 0.3, 3, z * 0.3), octaves: 4, seed: 7))
        return max(path, mud * 0.85)
    }
    let ground = GroundPatch().with { $0.size = 30; $0.segments = 150; $0.relief = 0.12; $0.flatCenter = 4; $0.material = "demo.worn" }
    var model = ground.build(seed: 2).levels[0]
    for i in model.surfaces.indices { model.surfaces[i].paintSplat { wear($0.x, $0.z) } }
    root.addChild(try await model.modelEntityAsync())
    let far = Model(name: "far-ground", surfaces: [Prim.terrain(size: V2(4000, 4000), segments: 8, material: "ground.meadow") { _ in -0.25 }])
    root.addChild(try await far.modelEntityAsync())

    var rng = SeededRNG(seed: 5)
    let spots = Scatter.uniform(count: 9000, outerRadius: 14, seed: 9) { wear($0.x, $0.y) < 0.2 + 0.15 * Float(abs(Noise.perlin(V3($0.x * 3, 0, $0.y * 3)))) }
    let xfs = spots.map { p in
        Xform(translation: V3(p.x, ground.height(x: p.x, z: p.y, seed: 2) - 0.02, p.y),
              rotation: simd_quatf(degrees: rng.float(0...360), axis: .up), scale: V3(repeating: rng.float(0.7...1.2))).matrix
    }
    root.addChild(try await RealInstancing.field(GrassClump().with { $0.height = 0.3; $0.width = 0.4 }.build(seed: 4), transforms: xfs, options: .groundCover(cull: 30)))
    let eyeZ: Float = 8
    return (V3(pathX(eyeZ) + 0.3, 1.65, eyeZ), V3(pathX(-2), 0.1, -2))
}
