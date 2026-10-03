import Foundation
import RealityKit
import RealCore
import RealMaterials
import RealKit
import RealLibrary

struct RenderOptions {
    var seed: UInt64 = 1
    var width = 1280, height = 800
    var azimuth: Float = 35, elevation: Float = 10, distance: Float = 1.15
    var lod = 0
    var sky = "afternoon"
    var fog: Float?
    var sunLux: Float?, iblExposure: Float?
    var pbr = false, ground = true
    var deltaTime = 0.0166
    var eye: SIMD3<Float>?, at: SIMD3<Float>?

    init(hint: PreviewHint = PreviewHint()) {
        azimuth = hint.azimuth; elevation = hint.elevation; distance = hint.distance; ground = hint.ground; fog = hint.fog
    }
    /// Flags override the asset's `PreviewHint`.
    init(_ a: Args, hint: PreviewHint) {
        self.init(hint: hint)
        func v3(_ k: String) -> SIMD3<Float>? {
            guard let c = a.opt(k)?.split(separator: ",").compactMap({ Float($0) }), c.count == 3 else { return nil }
            return SIMD3(c[0], c[1], c[2])
        }
        seed = UInt64(a.opt("--seed") ?? "1") ?? 1
        width = Int(a.opt("--w") ?? "1280") ?? 1280; height = Int(a.opt("--h") ?? "800") ?? 800
        if let v = a.opt("--az").flatMap(Float.init) { azimuth = v }
        if let v = a.opt("--el").flatMap(Float.init) { elevation = v }
        if let v = a.opt("--dist").flatMap(Float.init) { distance = v }
        lod = Int(a.opt("--lod") ?? "0") ?? 0
        sky = a.opt("--sky") ?? "afternoon"
        if let v = a.opt("--fog").flatMap(Float.init) { fog = v }
        sunLux = a.opt("--sun").flatMap(Float.init); iblExposure = a.opt("--ibl").flatMap(Float.init)
        deltaTime = Double(a.opt("--dt") ?? "0.0166") ?? 0.0166
        pbr = a.flag("--pbr"); if a.flag("--no-ground") { ground = false }
        eye = v3("--eye"); at = v3("--at")
    }
}

/// Renders an asset or scene id to a PNG. Returns a one-line report.
@MainActor
func render(_ id: String, to out: String, _ o: RenderOptions) async throws -> String {
    RealKitSetup.register()
    RealMaterialCache.shared.useShaderGraph = !o.pbr
    var sky = skyPreset(o.sky)
    if let fog = o.fog { sky.fogDensity = fog }
    if let v = o.sunLux { sky.sunLux = v }
    if let v = o.iblExposure { sky.iblExposure = v }
    let env = try RealEnvironment(sky, skybox: true)
    let preview = try RealPreview(environment: env)
    let root = Entity()
    let t0 = Date()
    if let scene = SceneCatalog.build(id, seed: o.seed) {
        root.addChild(try await scene.entity())
        if let cam = scene.camera { preview.look(from: o.eye ?? cam.eye, at: o.at ?? cam.target, fov: cam.fov) }
    } else {
        guard let asset = Catalog.build(id, seed: o.seed) else { throw CLIError("unknown id \(id) (realityhd list)") }
        let focus = try await asset.levels[min(o.lod, asset.levels.count - 1)].modelEntityAsync()
        root.addChild(focus)
        if o.ground {
            let g = try await GroundPatch().with { $0.size = 30; $0.segments = 60; $0.relief = 0.05; $0.flatCenter = 6 }.build(seed: 3).levels[0].modelEntityAsync()
            root.addChild(g)
            // Land to the horizon so the 30 m patch has no visible edge.
            let far = Model(name: "far-ground", surfaces: [Prim.terrain(size: V2(4000, 4000), segments: 8, material: "ground.forest") { _ in -0.12 }])
            let fe = try await far.modelEntityAsync()
            fe.components.set(DynamicLightShadowComponent(castsShadow: false))
            root.addChild(fe)
        }
        preview.frame(focus, azimuth: o.azimuth, elevation: o.elevation, distanceScale: o.distance)
    }
    env.illuminate(root)
    preview.add(root)
    let build = Date().timeIntervalSince(t0) * 1000
    guard let img = try await preview.render(width: o.width, height: o.height, frames: 6, deltaTime: o.deltaTime) else { throw CLIError("render failed") }
    writePNG(img, out)
    return "\(out) build \(Int(build))ms tex \(RealMaterialCache.shared.textureBytes / 1_048_576)MB"
}

@MainActor
func renderCommand(_ args: Args) async throws {
    let valued: Set<String> = ["--seed", "--w", "--h", "--az", "--el", "--dist", "--lod", "--sky", "--fog", "--dt", "--eye", "--at", "--out", "--sun", "--ibl"]
    let r = args.rest
    guard let id = r.indices.first(where: { !r[$0].hasPrefix("-") && ($0 == 0 || !valued.contains(r[$0 - 1])) }).map({ r[$0] }) else { print(usage); return }
    let o = RenderOptions(args, hint: Catalog.type(id)?.preview ?? PreviewHint())
    let out = args.opt("--out")
    args.rest.removeAll { $0 == id }
    print(try await render(id, to: out ?? "out/\(id).png", o))
}

/// Catalog thumbnails used by README, CATALOG.md and the PR checklist.
@MainActor
func thumbsCommand(_ args: Args) async throws {
    let root = try repoRoot().path
    let missingOnly = args.flag("--missing")
    let ids = args.rest.isEmpty ? Catalog.assets.map { $0.id } + SceneCatalog.ids : args.rest
    for id in ids {
        let isScene = SceneCatalog.type(id) != nil
        let path = "\(root)/docs/\(isScene ? "scenes" : "assets")/\(id).png"
        if missingOnly && FileManager.default.fileExists(atPath: path) { continue }
        var o = RenderOptions(hint: Catalog.type(id)?.preview ?? PreviewHint())
        (o.width, o.height) = isScene ? (1280, 800) : (640, 480)
        print(try await render(id, to: path, o))
    }
}
