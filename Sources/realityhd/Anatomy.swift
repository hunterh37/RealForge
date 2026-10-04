import Foundation
import CoreGraphics
import RealityKit
import RealCore
import RealMaterials
import RealKit

/// `realityhd anatomy [--mode xray|muscle|both|all] [--view dorsal|palmar|radial|ulnar|all] [--curl 0.2]
/// [--hand right|left] [--w 1280 --h 960]`: renders the live hand overlay (`RealHandAnatomy`) on the
/// reference rest pose. Writes out/anatomy/<hand>-<mode>-<view>.png.
@MainActor
func anatomyCommand(_ args: Args) async throws {
    RealKitSetup.register()
    let modeArg = args.opt("--mode") ?? "all", viewArg = args.opt("--view") ?? "all"
    let modes: [RealHandAnatomy.Mode] = modeArg == "all" ? [.xray, .muscle, .both] : [RealHandAnatomy.Mode(rawValue: modeArg) ?? .muscle]
    let views = viewArg == "all" ? ["dorsal", "palmar", "radial"] : [viewArg]
    let curl = Float(args.opt("--curl") ?? "0.15") ?? 0.15
    let zoom = Float(args.opt("--dist") ?? "1") ?? 1
    let target = args.opt("--at").map { s -> V3 in let c = s.split(separator: ",").compactMap { Float($0) }; return c.count == 3 ? V3(c[0], c[1], c[2]) : V3(0, 0, -0.075) } ?? V3(0, 0, -0.075)
    let hand: Chirality = args.opt("--hand") == "left" ? .left : .right
    let w = Int(args.opt("--w") ?? "1280") ?? 1280, h = Int(args.opt("--h") ?? "960") ?? 960
    try FileManager.default.createDirectory(atPath: "out/anatomy", withIntermediateDirectories: true)
    RealAtmosphere.fogDensity = 0
    let anatomy = RealHandAnatomy(chirality: hand, detail: 1)
    anatomy.smoothing = 0
    let t0 = Date()
    await anatomy.prepare()
    print("prepare \(Int(Date().timeIntervalSince(t0) * 1000))ms")
    // Hand lying on its palm, fingers toward -Z, wrist at the origin.
    let pose = HandPose.rest(hand, origin: .zero, distal: V3(0, 0, -1), dorsal: V3(0, 1, 0), curl: curl)
    for mode in modes {
        anatomy.setMode(mode)
        let t1 = Date()
        anatomy.update(pose)
        let ms = Int(Date().timeIntervalSince(t1) * 1000)
        for view in views {
            let xray = mode != .muscle
            var sky = SunSky.midday
            sky.fogDensity = 0
            let env = try RealEnvironment(sky, skybox: false)
            let preview = try RealPreview(environment: env)
            preview.renderer.cameraSettings.colorBackground = .color(xray ? CGColor(red: 0.01, green: 0.015, blue: 0.03, alpha: 1) : CGColor(red: 0.08, green: 0.085, blue: 0.09, alpha: 1))
            let holder = Entity()
            holder.addChild(anatomy.root)
            env.illuminate(holder)
            preview.add(holder)
            let c = target
            let radial: Float = hand == .right ? -1 : 1
            let eye: V3
            switch view {
            case "palmar": eye = c + V3(0.02, -0.34, 0.06)
            case "radial": eye = c + V3(radial * 0.3, 0.12, 0.05)
            case "ulnar": eye = c + V3(-radial * 0.3, 0.12, 0.05)
            default: eye = c + V3(0.03, 0.33, 0.1)
            }
            preview.look(from: c + (eye - c) * zoom, at: c, fov: 38)
            guard let img = try await preview.render(width: w, height: h, frames: 6) else { throw CLIError("render failed") }
            let out = "out/anatomy/\(hand == .right ? "right" : "left")-\(mode.rawValue)-\(view).png"
            writePNG(img, out)
            holder.removeChild(anatomy.root)
            print("\(out) update \(ms)ms")
        }
    }
}
