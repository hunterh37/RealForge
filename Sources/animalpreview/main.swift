import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import RealityKit
import RealCore
import RealMaterials
import RealKit
import AnimalCore
import AnimalKit

// animalpreview <species|all> [--pose perched|flight|<name>] [--out dir] [--w n] [--h n] [--sky afternoon]
// Renders a contact sheet per species: side, front, top and three-quarter views.

func writePNG(_ img: CGImage, _ path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(d, img, nil)
    CGImageDestinationFinalize(d)
}

func tile(_ imgs: [CGImage], cols: Int) -> CGImage? {
    guard let f = imgs.first else { return nil }
    let rows = (imgs.count + cols - 1) / cols
    let w = f.width, h = f.height
    guard let ctx = CGContext(data: nil, width: w * cols, height: h * rows, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
    for (i, im) in imgs.enumerated() {
        ctx.draw(im, in: CGRect(x: (i % cols) * w, y: (rows - 1 - i / cols) * h, width: w, height: h))
    }
    return ctx.makeImage()
}

@MainActor
func run() async throws {
    var args = Array(CommandLine.arguments.dropFirst())
    func opt(_ k: String) -> String? { if let i = args.firstIndex(of: k), i + 1 < args.count { return args[i + 1] } else { return nil } }
    let out = opt("--out") ?? "out"
    let w = Int(opt("--w") ?? "640") ?? 640, h = Int(opt("--h") ?? "520") ?? 520
    let poseName = opt("--pose") ?? "perched"
    let tight = args.contains("--tight")
    let names = args.filter { !$0.hasPrefix("-") && ![out, opt("--pose") ?? "", opt("--w") ?? "", opt("--h") ?? ""].contains($0) }
    if args.contains("--dump") {
        let sp = BirdSpecies(rawValue: names.first ?? "eastern-bluebird") ?? .easternBluebird
        let built = BirdRigBuilder.build(sp.profile)
        var pose = poseName == "flight" ? BirdPoses.glide(sp.profile) : poseName == "perched" ? BirdPoses.perched(sp.profile) : BirdMotion.preview(poseName, sp.profile)
        pose.clamp()
        var vals: [String: Float] = [:]
        for j in BirdJoint.all { vals[j.name] = pose[j] }
        let rv = built.rig.values(vals)
        let xf = built.rig.partTransforms(rv)
        let S = built.wingRoot[1]
        for (i, part) in built.rig.parts.enumerated() where part.name.hasSuffix("R") && part.levels[0].triangleCount > 0 && !part.name.contains("lid") {
            var far = V3.zero, best: Float = -1, sum = V3.zero, n: Float = 0
            let pivotW = xf[i].point(part.pivot.translation)
            for surf in part.levels[0].surfaces { for p in surf.positions {
                let w = xf[i].point(p)
                sum += w; n += 1
                let d = simd_length(w - pivotW)
                if d > best { best = d; far = w }
            }}
            let psi = radians(sp.profile.anatomy.restPitch)
            let Bk = V3(0, -sin(psi), cos(psi)), U = V3(0, cos(psi), sin(psi))
            func body(_ v: V3) -> V3 { V3(v.x, simd_dot(v, Bk), simd_dot(v, U)) }
            let c = body(sum / n - S), f = body(far - S)
            let pv = body(pivotW - S), rel = f - pv
            print(String(format: "%@ centroid x %.3f back %.3f up %.3f | tip x %.3f back %.3f up %.3f | alpha %.0f | val %.1f", part.name, c.x, c.y, c.z, f.x, f.y, f.z, atan2(rel.y, rel.x) * 180 / Float.pi, rv[part.name] ?? 0))
        }
        exit(0)
    }
    let kinds: [AnimalKind] = names.isEmpty || names.contains("all") ? AnimalKind.all : names.compactMap { AnimalKind(rawValue: $0) }
    args.removeAll()
    RealityHD_setup()
    for k in kinds {
        let t0 = Date()
        var holder = Entity()
        var comHeight: Float = 0.1, length: Float = 0.2, tris = 0
        switch k {
        case .bird(let s):
            let bird = try await BirdFactory.puppet(s)
            let p = s.profile
            var pose: BirdPose
            switch poseName {
            case "flight": pose = BirdPoses.glide(p)
            case "perched": pose = BirdPoses.perched(p)
            default: pose = BirdMotion.preview(poseName, p)
            }
            pose.clamp()
            bird.apply(pose)
            if !["perched", "gape", "look", "preen"].contains(poseName) {
                bird.holder.orientation = simd_quatf(angle: -(p.anatomy.restPitch - 6) * .pi / 180, axis: [1, 0, 0])
            }
            holder = bird.holder; comHeight = bird.built.comHeight; length = p.anatomy.length; tris = bird.built.triangleCount
        case .ground(let s):
            let g = try await GroundFactory.puppet(s)
            var pose = GroundMotion.preview(poseName, s.profile)
            pose.clamp()
            g.apply(pose)
            let a = s.profile.anatomy
            g.holder.orientation = simd_quatf(angle: -GroundMotion.previewPitch(poseName, s.profile) * .pi / 180, axis: [1, 0, 0])
            holder = g.holder; comHeight = g.built.comHeight; length = a.bodyLength + a.headLength + a.tailLength * 0.5; tris = g.built.triangleCount
        }
        var frames: [CGImage] = []
        let env = try RealEnvironment(.afternoon, skybox: true)
        let preview = try RealPreview(environment: env)
        let root = Entity()
        root.addChild(holder)
        var floor = Prim.terrain(size: V2(4, 4), segments: 4, material: "concrete.smooth") { _ in 0 }
        floor.uvs = floor.uvs.map { $0 * 2.5 }
        let ge = try await Model(name: "g", surfaces: [floor]).modelEntityAsync()
        ge.position = [0, -comHeight, 0]
        root.addChild(ge)
        env.illuminate(root)
        preview.add(root)
        let c = SIMD3<Float>(0, 0.0, 0)
        let d = max(0.28, length * (tight ? 1.7 : 2.6))
        let views: [(Float, Float)] = [(90, 4), (0, 4), (0, 80), (35, 16), (145, 14), (-50, 22)]
        for (az, el) in views {
            let a = az * .pi / 180, e = el * .pi / 180
            let eye = c + SIMD3(sin(a) * cos(e), sin(e), -cos(a) * cos(e)) * d
            preview.look(from: eye, at: c, fov: 32)
            if let img = try await preview.render(width: w, height: h, frames: 4) { frames.append(img) }
        }
        if let sheet = tile(frames, cols: 3) { writePNG(sheet, "\(out)/\(k.rawValue)-\(poseName).png") }
        print("\(k.rawValue) \(poseName): \(tris) tris, \(Int(Date().timeIntervalSince(t0) * 1000)) ms")
    }
}

@MainActor func RealityHD_setup() { RealKitSetup.register() }

Task { @MainActor in
    do { try await run() } catch { print("error: \(error)") }
    exit(0)
}
RunLoop.main.run()
