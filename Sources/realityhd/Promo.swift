import Foundation
import CoreGraphics
import ImageIO
import RealityKit
import RealCore
import RealMaterials
import RealKit
import RealLibrary

/// Release media: `realityhd promo [--out dir] [--fps 24] [--w 1920 --h 1080] [--probe] [--only id]`
/// writes the 30 s demo as a PNG sequence (frames/f00000.png ...; encode with ffmpeg), and
/// `realityhd promo --stills` writes four 3840x2160 screenshots.

private struct SceneShot { var id: String; var sec: Double; var push: Float; var drift: Float; var caption: String }
private struct PropShot { var id: String; var sec: Double; var states: [String]; var spin: Float }
private enum Shot {
    case scene(SceneShot), prop(PropShot)
    var id: String { switch self { case .scene(let s): return s.id; case .prop(let p): return p.id } }
    var sec: Double { switch self { case .scene(let s): return s.sec; case .prop(let p): return p.sec } }
}

private let shotList: [Shot] = [
    .scene(.init(id: "hospital-lobby", sec: 3.5, push: 1.6, drift: 0.8, caption: "Hospital lobby")),
    .scene(.init(id: "er-room", sec: 3.5, push: 1.2, drift: 0.6, caption: "Emergency room")),
    .prop(.init(id: "hospital-bed", sec: 2.6, states: ["flat", "fowler", "rails-down"], spin: 40)),
    .prop(.init(id: "aed", sec: 2.6, states: ["closed", "open", "pads-out", "analyzing"], spin: 30)),
    .prop(.init(id: "patient-monitor", sec: 2.2, states: ["off", "on", "alarm"], spin: 30)),
    .scene(.init(id: "operating-room", sec: 3.5, push: 1.2, drift: 0.6, caption: "Operating room")),
    .prop(.init(id: "syringe", sec: 2.4, states: ["empty", "drawn-5ml", "full", "capped"], spin: 30)),
    .prop(.init(id: "exam-table", sec: 2.7, states: ["flat", "sitting", "drawers-open", "stirrups-out"], spin: 40)),
    .prop(.init(id: "hemostat", sec: 2.0, states: ["open", "first-click", "closed-locked"], spin: 30)),
    .scene(.init(id: "hospital", sec: 5.0, push: 3.0, drift: 0.0, caption: "Hospital floor")),
]

private let repoURL = "github.com/hunterh37/RealityHD"
private func smooth(_ a: Double, _ b: Double, _ x: Double) -> Double { let t = min(1, max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t) }

private struct SceneStage {
    let preview: RealPreview
    let scene: RealScene
    let cam: RealScene.Camera

    @MainActor
    init(_ id: String) async throws {
        RealKitSetup.register()
        RealMaterialCache.shared.useShaderGraph = true
        guard let scene = SceneCatalog.build(id, seed: 1), let cam = scene.camera else { throw CLIError("scene \(id) has no camera") }
        var sky = skyPreset("afternoon")
        if let s = scene.lighting.sky { sky = s }
        if let f = scene.lighting.fog { sky.fogDensity = f }
        if let k = scene.lighting.sunScale { sky.sunLux *= k }
        let env = try RealEnvironment(sky, skybox: true, interior: scene.lighting.interior)
        preview = try RealPreview(environment: env)
        let root = Entity()
        root.addChild(try await scene.entity())
        env.illuminate(root)
        preview.add(root)
        self.scene = scene; self.cam = cam
    }

    @MainActor
    func shot(u: Float, push: Float, drift: Float, w: Int, h: Int, frames: Int, dt: Double) async throws -> CGImage {
        let fwd = simd_normalize(V3(cam.target.x - cam.eye.x, 0, cam.target.z - cam.eye.z))
        let side = V3(-fwd.z, 0, fwd.x)
        let eye = cam.eye + fwd * push * u + side * drift * (u - 0.5)
        let at = cam.target + side * drift * (u - 0.5) * 0.6
        preview.look(from: eye, at: at, fov: cam.fov)
        guard let img = try await preview.render(width: w, height: h, frames: frames, deltaTime: dt) else { throw CLIError("render failed") }
        return img
    }
}

/// Partner logo for the top-right corner (`--medvr <png>`); nil leaves the RealityHD-only layout.
nonisolated(unsafe) private var partnerLogo: CGImage?

private func brand(_ c: Canvas) {
    let size = CGFloat(c.h) / 48
    c.text("RealityHD", x: Int(size * 2), y: Int(size * 1.6), size: size, bold: true, pill: true)
    if let logo = partnerLogo {
        let lh = c.h / 13, lw = lh * logo.width / logo.height
        let x = c.w - Int(size * 2) - lw, y = Int(size * 1.0)
        // Transparent logo with a soft shadow for legibility on light scenes.
        c.ctx.saveGState()
        c.ctx.setShadow(offset: .zero, blur: CGFloat(c.h) / 60, color: CGColor(gray: 0, alpha: 0.75))
        c.image(logo, x: x, y: y, w: lw, h: lh)
        c.ctx.restoreGState()
    }
}

private func caption(_ c: Canvas, _ s: String) {
    let size = CGFloat(c.h) / 40
    c.text(s, x: Int(size * 2), y: c.h - Int(size * 3.2), size: size, pill: true)
}

private func centered(_ c: Canvas, _ s: String, y: Int, size: CGFloat, bold: Bool = false, alpha: CGFloat) {
    let w = Int(CGFloat(s.count) * size * 0.6)
    c.text(s, x: (c.w - w) / 2, y: y, size: size, color: CGColor(gray: 1, alpha: alpha), bold: bold)
}

/// Dark wash with the title (first shot, first 2 s) or the end card (last shot, last 2 s).
private func cards(_ c: Canvas, t: Double, shotSec: Double, first: Bool, last: Bool) {
    let h = CGFloat(c.h)
    if first && t < 2.0 {
        let a = 1 - smooth(1.5, 2.0, t)
        c.rect(x: 0, y: 0, w: c.w, h: c.h, CGColor(gray: 0, alpha: 0.5 * a))
        centered(c, "RealityHD", y: Int(h * 0.38), size: h / 11, bold: true, alpha: a)
        centered(c, "Open-source medical assets for RealityKit", y: Int(h * 0.38 + h / 11 * 1.7), size: h / 36, alpha: a)
    }
    if last && t > shotSec - 2.0 {
        let a = smooth(shotSec - 2.0, shotSec - 1.5, t)
        c.rect(x: 0, y: 0, w: c.w, h: c.h, CGColor(gray: 0, alpha: 0.62 * a))
        centered(c, "RealityHD", y: Int(h * 0.34), size: h / 11, bold: true, alpha: a)
        centered(c, "Free and open source  |  Swift package  |  visionOS 26", y: Int(h * 0.34 + h / 11 * 1.7), size: h / 36, alpha: a)
        centered(c, repoURL, y: Int(h * 0.34 + h / 11 * 1.7 + h / 36 * 2.2), size: h / 36, bold: true, alpha: a)
    }
}

@MainActor
func promoCommand(_ args: Args) async throws {
    let dir = args.opt("--out") ?? "out/promo"
    let fps = Int(args.opt("--fps") ?? "24") ?? 24
    let probe = args.flag("--probe")
    var W = Int(args.opt("--w") ?? "1920") ?? 1920, H = Int(args.opt("--h") ?? "1080") ?? 1080
    if probe { (W, H) = (960, 540) }
    let only = args.opt("--only")
    if let path = args.opt("--medvr") {
        guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { throw CLIError("cannot read \(path)") }
        partnerLogo = img
    }
    try FileManager.default.createDirectory(atPath: "\(dir)/frames", withIntermediateDirectories: true)
    if args.flag("--stills") { try await stills(dir: dir); return }

    var counts = shotList.map { Int(($0.sec * Double(fps)).rounded()) }
    counts[counts.count - 1] += Int((shotList.map(\.sec).reduce(0, +) * Double(fps)).rounded()) - counts.reduce(0, +)
    var base = 0
    for (si, shot) in shotList.enumerated() {
        let n = counts[si], start = base
        base += n
        if let only, only != shot.id { continue }
        let idx = probe ? [0, n / 2, n - 1] : Array(0..<n)
        let t0 = Date()
        switch shot {
        case .scene(let s):
            let stage = try await SceneStage(s.id)
            for i in idx {
                let u = Float(i) / Float(max(1, n - 1))
                let img = try await stage.shot(u: u, push: s.push, drift: s.drift, w: W, h: H, frames: i == idx.first ? 8 : 2, dt: 1 / Double(fps))
                let c = Canvas(W, H); c.image(img, x: 0, y: 0, w: W, h: H)
                finish(c, i: i, n: n, start: start, fps: fps, si: si, id: s.id, label: s.caption, dir: dir, probe: probe)
            }
        case .prop(let p):
            try await propFrames(p, idx: idx, n: n, W: W, H: H, fps: fps) { i, img, label in
                let c = Canvas(W, H); c.image(img, x: 0, y: 0, w: W, h: H)
                finish(c, i: i, n: n, start: start, fps: fps, si: si, id: p.id, label: label, dir: dir, probe: probe)
            }
        }
        print("\(shot.id) \(idx.count) frames \(Int(Date().timeIntervalSince(t0)))s")
    }
}

/// Overlays, fades, and file write for one frame.
@MainActor
private func finish(_ c: Canvas, i: Int, n: Int, start: Int, fps: Int, si: Int, id: String, label: String, dir: String, probe: Bool) {
    let t = Double(i) / Double(fps), sec = Double(n) / Double(fps)
    cards(c, t: t, shotSec: sec, first: si == 0, last: si == shotList.count - 1)
    brand(c)
    caption(c, label)
    // Dip to black over 4 frames at each cut (not on the very first or last frame of the film).
    let dip = max(0, 1 - Double(i) / 4), dipOut = max(0, 1 - Double(n - 1 - i) / 4)
    let a = max(si == 0 ? 0 : dip, si == shotList.count - 1 ? 0 : dipOut)
    if a > 0 { c.rect(x: 0, y: 0, w: c.w, h: c.h, CGColor(gray: 0, alpha: a)) }
    let path = probe ? "\(dir)/probe/\(si)-\(id)-\(i).png" : String(format: "\(dir)/frames/f%05d.png", start + i)
    writePNG(c.cgImage, path)
}

/// Prop turntable with state transitions: joints interpolated between consecutive states, part
/// options switched at the midpoint of each transition.
@MainActor
private func propFrames(_ p: PropShot, idx: [Int], n: Int, W: Int, H: Int, fps: Int, emit: (Int, CGImage, String) -> Void) async throws {
    guard let rig = Catalog.rig(p.id, seed: 1) else { throw CLIError("\(p.id) is not articulated") }
    let hint = Catalog.type(p.id)?.preview ?? PreviewHint()
    let states = try p.states.map { name in
        guard let s = rig.states.first(where: { $0.name == name }) else { throw CLIError("\(p.id) has no state \(name)") }
        return s
    }
    let stage = try await Stage(id: p.id, seed: 1, state: p.states[0], live: true, floor: "floor.vinyl")
    // Framing from the union of every state's bounds, fixed for the whole shot.
    var lo = V3(repeating: .infinity), hi = V3(repeating: -.infinity)
    for s in states {
        stage.focus.setArticulation(s.name, animated: false)
        let b = stage.focus.visualBounds(relativeTo: nil)
        lo = simd_min(lo, b.min); hi = simd_max(hi, b.max)
    }
    stage.focus.setArticulation(p.states[0], animated: false)
    let c = (lo + hi) / 2, r = max(0.2, simd_length(hi - lo) * 0.5), fov: Float = 40
    let d = r / tan(fov * .pi / 360) * hint.distance * 1.3
    let joints = Set(states.flatMap { $0.joints.keys }), options = Set(states.flatMap { $0.options.keys })
    var lastIdx = -1
    for i in idx {
        let u = Double(i) / Double(max(1, n - 1))
        let pos = u * Double(states.count - 1)
        let seg = min(Int(pos), states.count - 2)
        let e = smooth(0.2, 0.8, pos - Double(seg))
        var v: [String: Float] = [:]
        for j in joints {
            let a = states[seg].joints[j] ?? 0, b = states[seg + 1].joints[j] ?? 0
            v[j] = a + (b - a) * Float(e)
        }
        stage.focus.setJoints(v, animated: false)
        let si = e > 0.5 ? seg + 1 : seg
        if si != lastIdx {
            var o: [String: Int] = [:]
            for k in options { o[k] = states[si].options[k] ?? 0 }
            stage.focus.setOptions(o)
            lastIdx = si
        }
        let az = (hint.azimuth - p.spin / 2 + p.spin * Float(u)) * .pi / 180, el = hint.elevation * .pi / 180
        stage.preview.look(from: c + V3(sin(az) * cos(el), sin(el), cos(az) * cos(el)) * d, at: c, fov: fov)
        guard let img = try await stage.preview.render(width: W, height: H, frames: i == idx.first ? 8 : 2, deltaTime: 1 / Double(fps)) else { throw CLIError("render failed") }
        emit(i, img, "\(p.id)  \(states[si].name)")
    }
}

/// Four 3840x2160 screenshots: three scenes and a six-prop state collage.
@MainActor
private func stills(dir: String) async throws {
    let W = 3840, H = 2160
    for (k, id) in ["er-room", "operating-room", "hospital-lobby"].enumerated() {
        let stage = try await SceneStage(id)
        let img = try await stage.shot(u: 0.3, push: 1.0, drift: 0.4, w: W, h: H, frames: 10, dt: 1 / 60)
        let c = Canvas(W, H); c.image(img, x: 0, y: 0, w: W, h: H)
        brand(c)
        writePNG(c.cgImage, "\(dir)/0\(k + 1)-\(id).png")
        print("\(dir)/0\(k + 1)-\(id).png")
    }
    let props: [(String, String)] = [("hospital-bed", "fowler"), ("aed", "analyzing"), ("patient-monitor", "alarm"),
                                     ("exam-table", "stirrups-out"), ("syringe", "full"), ("hemostat", "open")]
    let c = Canvas(W, H)
    let pw = W / 3, ph = H / 2
    for (i, (id, st)) in props.enumerated() {
        let hint = Catalog.type(id)?.preview ?? PreviewHint()
        let stage = try await Stage(id: id, seed: 1, state: st, live: true, floor: "floor.vinyl")
        let img = try await stage.shot(az: hint.azimuth, el: hint.elevation, dist: hint.distance * 1.6, w: pw, h: ph, frames: 8)
        let x = (i % 3) * pw, y = (i / 3) * ph
        c.image(img, x: x, y: y, w: pw, h: ph)
        c.text("\(id)  \(st)", x: x + 48, y: y + ph - 96, size: 44, pill: true)
    }
    brand(c)
    writePNG(c.cgImage, "\(dir)/04-props.png")
    print("\(dir)/04-props.png")
}
