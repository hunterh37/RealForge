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
    guard let name = args.next() else { print("realityhd demo splat|water [--sky s] [--az deg] [--el deg] [--pbr]"); return }
    let env = try RealEnvironment(sky, skybox: true)
    let preview = try RealPreview(environment: env)
    let root = Entity()
    var cam: (eye: V3, at: V3) = (V3(0, 1.7, 7), V3(0, 0.2, -4))
    switch name {
    case "splat": cam = try await splatDemo(root)
    case "water": cam = try await waterDemo(root)
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

/// Pond in a terrain bowl: transparent water whose shallowness (splat channel) follows the bowl
/// depth, scrolling ripple normals, Fresnel opacity, plus a free-standing glass pane.
@MainActor
func waterDemo(_ root: Entity) async throws -> (eye: V3, at: V3) {
    let level: Float = -0.12
    func bowl(_ x: Float, _ z: Float) -> Float {
        let r = simd_length(V2(x * 0.8, z)) + Noise.fbm(V3(x * 0.4, 0, z * 0.4), octaves: 3, seed: 4) * 1.2
        return -0.9 * (1 - smoothstep(1.5, 5.5, r)) + Noise.fbm(V3(x * 0.15, 1, z * 0.15), octaves: 4, seed: 2) * 0.25
    }
    var ground = Prim.terrain(size: V2(40, 40), segments: 160, material: "ground.meadow") { bowl($0.x, $0.y) }
    ground.bakeCavityAO(strength: 0.5)
    root.addChild(try await Model(name: "pond-bed", surfaces: [ground]).modelEntityAsync())
    let far = Model(name: "far-ground", surfaces: [Prim.terrain(size: V2(4000, 4000), segments: 8, material: "ground.meadow") { _ in -0.3 }])
    root.addChild(try await far.modelEntityAsync())

    var water = Prim.terrain(size: V2(14, 12), segments: 70, material: "water.pond") { _ in level }
    water.paintSplat { p in 1 - smoothstep(0.0, 0.45, level - bowl(p.x, p.z)) }   // 1 at the waterline
    let we = try await Model(name: "pond", surfaces: [water]).modelEntityAsync()
    we.components.set(DynamicLightShadowComponent(castsShadow: false))
    root.addChild(we)

    var pane = Model(name: "pane")
    pane.add(Prim.roundedBox(V3(1.2, 1.0, 0.006), radius: 0.002, bevelSegments: 1, material: "glass.pane"), Xform(translation: V3(0, 0.62, 0)))
    for x: Float in [-0.63, 0.63] {
        pane.add(Prim.roundedBox(V3(0.06, 1.2, 0.06), radius: 0.008, bevelSegments: 2, material: "wood.oak"), Xform(translation: V3(x, 0.6, 0)))
    }
    pane.add(Prim.roundedBox(V3(1.32, 0.06, 0.06), radius: 0.008, bevelSegments: 2, material: "wood.oak"), Xform(translation: V3(0, 1.15, 0)))
    let pe = try await pane.modelEntityAsync()
    pe.transform = Transform(rotation: simd_quatf(angle: 0.5, axis: V3(0, 1, 0)), translation: V3(2.6, bowl(2.6, 6.2) - 0.02, 6.2))
    root.addChild(pe)

    var rng = SeededRNG(seed: 11)
    let spots = Scatter.uniform(count: 7000, outerRadius: 16, seed: 3) { bowl($0.x, $0.y) > level + 0.06 }
    let xfs = spots.map { p in
        Xform(translation: V3(p.x, bowl(p.x, p.y) - 0.02, p.y), rotation: simd_quatf(degrees: rng.float(0...360), axis: .up),
              scale: V3(repeating: rng.float(0.7...1.2))).matrix
    }
    root.addChild(try await RealInstancing.field(GrassClump().with { $0.height = 0.32; $0.width = 0.4 }.build(seed: 4), transforms: xfs, options: .groundCover(cull: 30)))
    return (V3(1.5, 1.6, 9.5), V3(-0.5, -0.3, 0))
}
