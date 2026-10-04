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
    var studio = false
    var skyGiven = false
    var state: String?

    init(hint: PreviewHint = PreviewHint()) {
        azimuth = hint.azimuth; elevation = hint.elevation; distance = hint.distance; ground = hint.ground; fog = hint.fog; studio = hint.studio
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
        if let v = a.opt("--sky") { sky = v; skyGiven = true }
        state = a.opt("--state")
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
    let t0 = Date()
    let scene = SceneCatalog.build(id, seed: o.seed)
    var sky = skyPreset(o.sky)
    if !o.skyGiven, let s = scene?.lighting.sky { sky = s }
    if let f = scene?.lighting.fog { sky.fogDensity = f }
    if let k = scene?.lighting.sunScale { sky.sunLux *= k }
    if let fog = o.fog { sky.fogDensity = fog }
    if let v = o.sunLux { sky.sunLux = v }
    if let v = o.iblExposure { sky.iblExposure = v }
    var interior = scene?.lighting.interior
    if let v = o.iblExposure, interior != nil { interior!.exposure = v }
    let env = try RealEnvironment(sky, skybox: true, interior: interior)
    let preview = try RealPreview(environment: env)
    let root = Entity()
    if let scene {
        root.addChild(try await scene.entity())
        if let cam = scene.camera { preview.look(from: o.eye ?? cam.eye, at: o.at ?? cam.target, fov: cam.fov) }
    } else {
        let asset = o.state.flatMap { st in Catalog.rig(id, seed: o.seed).map { $0.posed(st) } } ?? Catalog.build(id, seed: o.seed)
        guard let asset else { throw CLIError("unknown id \(id) (realityhd list)") }
        let focus = try await asset.levels[min(o.lod, asset.levels.count - 1)].modelEntityAsync()
        root.addChild(focus)
        if o.ground && o.studio {
            var floor = Prim.terrain(size: V2(80, 80), segments: 8, material: "concrete.smooth") { _ in 0 }
            floor.uvs = floor.uvs.map { $0 * 2.5 }
            root.addChild(try await Model(name: "studio-floor", surfaces: [floor]).modelEntityAsync())
        } else if o.ground {
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
    if ProcessInfo.processInfo.environment["REALITYHD_TEX_REPORT"] != nil {
        for (k, n) in RealMaterialCache.shared.textureSizes.sorted(by: { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }) { print("  \(n) \(k)") }
    }
    return "\(out) build \(Int(build))ms tex \(RealMaterialCache.shared.textureBytes / 1_048_576)MB sets \(RealMaterialCache.shared.textureSizes.count)"
}

@MainActor
func renderCommand(_ args: Args) async throws {
    let valued: Set<String> = ["--seed", "--w", "--h", "--az", "--el", "--dist", "--lod", "--sky", "--fog", "--dt", "--eye", "--at", "--out", "--sun", "--ibl", "--state"]
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

/// Every state of an articulated asset side by side, rendered through the live rig (part entities
/// posed by `setArticulation`), so the runtime path is what gets checked. out/states/<id>.png.
@MainActor
func statesCommand(_ args: Args) async throws {
    let seed = UInt64(args.opt("--seed") ?? "1") ?? 1
    let ids = args.rest.isEmpty ? Catalog.articulated.map { $0.id } : args.rest
    for id in ids {
        guard let rig = Catalog.rig(id, seed: seed) else { throw CLIError("\(id) is not articulated (realityhd list)") }
        let hint = Catalog.type(id)?.preview ?? PreviewHint()
        let panel = (w: 560, h: 420), header = 44
        let names = rig.stateNames
        let cols = min(4, names.count), rows = (names.count + cols - 1) / cols
        let c = Canvas(panel.w * cols, panel.h * rows + header)
        for (i, st) in names.enumerated() {
            let stage = try await Stage(id: id, seed: seed, state: st, live: true)
            let img = try await stage.shot(az: hint.azimuth, el: hint.elevation, dist: hint.distance, w: panel.w, h: panel.h)
            let x = (i % cols) * panel.w, y = header + (i / cols) * panel.h
            c.image(img, x: x, y: y, w: panel.w, h: panel.h)
            c.text(st, x: x + 12, y: y + 10, size: 15, pill: true)
        }
        let joints = rig.parts.filter { $0.joint.kind != .fixed }.map(\.name)
        c.text("\(id)   states \(names.count)   joints \(joints.joined(separator: " "))", x: 14, y: 12, size: 17, bold: true)
        let out = "out/states/\(id).png"
        writePNG(c.cgImage, out)
        let tris = names.map { rig.posed($0).levels[0].triangleCount }
        print("\(out) states \(names.joined(separator: ",")) tris \(tris.min() ?? 0)-\(tris.max() ?? 0)")
    }
}
