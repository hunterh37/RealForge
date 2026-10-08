import Foundation
import CoreGraphics
import RealityKit
import RealCore
import RealMaterials
import RealKit
import RealLibrary

/// One asset on a lit stage, rendered from many cameras without rebuilding (sheets, view search).
@MainActor
final class Stage {
    let preview: RealPreview
    let focus: Entity
    let root = Entity()

    init(id: String, seed: UInt64, sky: String = "afternoon", ground: Bool = true, matte: Bool = false, lod: Int = 0, state: String? = nil, live: Bool = false, floor floorKey: String = "concrete.smooth") async throws {
        RealKitSetup.register()
        RealMaterialCache.shared.useShaderGraph = true
        let hint = Catalog.type(id)?.preview ?? PreviewHint()
        var s = skyPreset(sky)
        if let fog = hint.fog { s.fogDensity = fog }
        if matte { s.fogDensity = 0 }
        let env = try RealEnvironment(s, skybox: !matte)
        preview = try RealPreview(environment: env)
        if matte { preview.renderer.cameraSettings.colorBackground = .color(CGColor(red: 1, green: 0, blue: 1, alpha: 1)) }
        if live, let rig = Catalog.rig(id, seed: seed) {
            // Runtime path: part entities driven to the state through the articulation API.
            focus = try await rig.entityAsync(name: id)
            if let state { focus.setArticulation(state, animated: false) }
        } else {
            let asset = state.flatMap { st in Catalog.rig(id, seed: seed).map { $0.posed(st) } } ?? Catalog.build(id, seed: seed)
            guard let asset else { throw CLIError("unknown asset id \(id) (realityhd list)") }
            focus = try await asset.levels[min(lod, asset.levels.count - 1)].modelEntityAsync()
        }
        root.addChild(focus)
        let isProp = Catalog.type(id)?.tags.first == "prop" || hint.studio
        if ground && hint.ground && !matte && isProp {
            // Props: neutral sealed-concrete floor, so the judge sees the object, not giant forest litter.
            var floor = Prim.terrain(size: V2(80, 80), segments: 8, material: floorKey) { _ in 0 }
            floor.uvs = floor.uvs.map { $0 * (floorKey == "concrete.smooth" ? 2.5 : 8) }   // finer aggregate: a smooth studio-like slab at prop scale
            let pad = Model(name: "stage-floor", surfaces: [floor])
            root.addChild(try await pad.modelEntityAsync())
        } else if ground && hint.ground && !matte {
            let g = try await GroundPatch().with { $0.size = 30; $0.segments = 60; $0.relief = 0.05; $0.flatCenter = 6 }.build(seed: 3).levels[0].modelEntityAsync()
            root.addChild(g)
            let far = Model(name: "far-ground", surfaces: [Prim.terrain(size: V2(4000, 4000), segments: 8, material: "ground.forest") { _ in -0.12 }])
            let fe = try await far.modelEntityAsync()
            fe.components.set(DynamicLightShadowComponent(castsShadow: false))
            root.addChild(fe)
        }
        env.illuminate(root)
        preview.add(root)
    }

    func shot(az: Float, el: Float, dist: Float, w: Int, h: Int, frames: Int = 4) async throws -> CGImage {
        preview.frame(focus, azimuth: az, elevation: el, distanceScale: dist)
        guard let img = try await preview.render(width: w, height: h, frames: frames) else { throw CLIError("render failed") }
        return img
    }
}

struct GatePaths {
    let dir: String
    init(_ id: String) { dir = "out/gate/\(id)" }
    var sheet: String { "\(dir)/sheet.png" }
    var compare: String { "\(dir)/compare.png" }
    var report: String { "\(dir)/report.json" }
    var verdict: String { "\(dir)/verdict.json" }
    var template: String { "\(dir)/verdict.template.json" }
    var history: String { "\(dir)/history.jsonl" }
}

func fmt(_ v: Float?, _ d: Int = 2) -> String { v.map { String(format: "%.\(d)f", $0) } ?? "-" }
func fmtSize(_ s: [Float]) -> String { s.map { String(format: "%.3f", $0) }.joined(separator: " x ") }

func loadBrief(_ id: String) -> PropBrief? {
    guard let root = try? repoRoot() else { return nil }
    return try? PropBrief.load(root.appendingPathComponent("briefs/\(id).json"))
}

/// Six-view contact sheet with a stats header. One image for the vision judge instead of six.
@MainActor
func makeSheet(_ id: String, seed: UInt64, geometry g: GeometryReport, brief: PropBrief?, panel: (w: Int, h: Int) = (640, 480), views: Set<String>? = nil) async throws -> CGImage {
    let hint = Catalog.type(id)?.preview ?? PreviewHint()
    let stage = try await Stage(id: id, seed: seed)
    let az = hint.azimuth, el = hint.elevation, d = hint.distance
    var shots: [(String, CGImage)] = []
    func want(_ v: String) -> Bool { views?.contains(v) ?? true }
    if want("hero") { shots.append(("hero az \(Int(az)) el \(Int(el))", try await stage.shot(az: az, el: el, dist: d, w: panel.w, h: panel.h))) }
    if want("side") { shots.append(("side az \(Int(az + 90))", try await stage.shot(az: az + 90, el: el, dist: d, w: panel.w, h: panel.h))) }
    if want("back") { shots.append(("back az \(Int(az + 180))", try await stage.shot(az: az + 180, el: el + 5, dist: d, w: panel.w, h: panel.h))) }
    if want("high") { shots.append(("high az \(Int(az - 45)) el 50", try await stage.shot(az: az - 45, el: 50, dist: d, w: panel.w, h: panel.h))) }
    if want("detail") { shots.append(("detail 2.2x", try await stage.shot(az: az + 15, el: el + 6, dist: d * 0.45, w: panel.w, h: panel.h))) }
    if want("golden") {
        let golden = try await Stage(id: id, seed: seed, sky: "golden")
        shots.append(("golden hour, grazing light", try await golden.shot(az: az - 20, el: el, dist: d, w: panel.w, h: panel.h)))
    }
    guard !shots.isEmpty else { throw CLIError("--views: none of hero,side,back,high,detail,golden") }
    let cols = min(3, shots.count), rows = (shots.count + cols - 1) / cols
    let header = 64
    let c = Canvas(panel.w * cols, panel.h * rows + header)
    for (i, (label, img)) in shots.enumerated() {
        let x = (i % cols) * panel.w, y = header + (i / cols) * panel.h
        c.image(img, x: x, y: y, w: panel.w, h: panel.h)
        c.text(label, x: x + 12, y: y + 10, size: 15, pill: true)
    }
    c.text(id, x: 14, y: 10, size: 22, bold: true)
    var line = "tris \(g.triangles.map(String.init).joined(separator: "/")) of \(g.budget)   size \(fmtSize(g.size)) m"
    if let b = brief { line += "   brief \(fmtSize(b.size))" }
    line += "   seed \(seed)"
    c.text(line, x: 14, y: 38, size: 15, color: CGColor(gray: 0.8, alpha: 1))
    let mats = g.materials.sorted { $0.value > $1.value }.map(\.key).joined(separator: "  ")
    c.text(mats, x: panel.w * cols - 14 - min(panel.w * (cols - 1), mats.count * 9), y: 12, size: 14, color: CGColor(gray: 0.7, alpha: 1))
    return c.cgImage
}

/// Reference comparison: matched-view matte render vs the reference photo, silhouette overlay, metrics.
@MainActor
func compareReference(_ id: String, seed: UInt64, refPath: String, view: [Float]?, fitView: Bool) async throws -> (ImageMetrics, CGImage) {
    let refImg = try Pixels.load(refPath)
    let scale = min(1, 768 / Float(max(refImg.width, refImg.height)))
    let refPx = Pixels(refImg, width: Int(Float(refImg.width) * scale), height: Int(Float(refImg.height) * scale))
    let refMask = subjectMask(refPx.cgImage, refPx)
    let n = 256
    guard let (refCrop, refM) = normalizedCrop(refPx, refMask, n: n, matte: true) else { throw CLIError("no subject found in \(refPath)") }
    let hint = Catalog.type(id)?.preview ?? PreviewHint()
    let matte = try await Stage(id: id, seed: seed, matte: true)
    func silhouette(az: Float, el: Float) async throws -> (Float, Pixels, [Float])? {
        let img = try await matte.shot(az: az, el: el, dist: 1.2, w: 384, h: 384, frames: 2)
        let p = Pixels(img), m = matteMask(p)
        guard let (crop, mm) = normalizedCrop(p, m, n: n, matte: true) else { return nil }
        return (iou(refM, mm), crop, mm)
    }
    var best: (az: Float, el: Float, iou: Float) = (view?.first ?? hint.azimuth, view.map { $0.count > 1 ? $0[1] : hint.elevation } ?? hint.elevation, -1)
    if fitView {
        for el: Float in [0, 10, 20, 32, 45] { for k in 0..<16 {
            let az = Float(k) * 22.5
            if let (s, _, _) = try await silhouette(az: az, el: el), s > best.iou { best = (az, el, s) }
        }}
        let (a0, e0) = (best.az, best.el)
        for de: Float in [-6, 0, 6] { for da: Float in [-10, -5, 0, 5, 10] {
            if let (s, _, _) = try await silhouette(az: a0 + da, el: max(-5, e0 + de)), s > best.iou { best = (a0 + da, max(-5, e0 + de), s) }
        }}
    }
    guard let (sil, _, renM) = try await silhouette(az: best.az, el: best.el) else { throw CLIError("render is empty") }
    // Lit render (same view) for color, detail and perceptual metrics.
    let lit = try await Stage(id: id, seed: seed, ground: false, matte: true)
    let litImg = Pixels(try await lit.shot(az: best.az, el: best.el, dist: 1.2, w: 512, h: 512))
    guard let (litCrop, litM) = normalizedCrop(litImg, matteMask(litImg), n: n, matte: true) else { throw CLIError("render is empty") }
    var im = ImageMetrics()
    im.silhouette = sil
    im.view = [best.az, best.el]
    if let rb = bbox(refMask, refPx.w, refPx.h), let lb = bbox(litM, n, n) {
        let ar = Float(rb.w) / Float(rb.h), al = Float(lb.w) / Float(lb.h)
        im.aspect = max(0, 1 - abs(log(ar / al)) / log(2))
    }
    let la = meanLab(refCrop, refM), lb = meanLab(litCrop, litM)
    let dE = simd_length((la - lb) * SIMD3(0.5, 1, 1))
    im.color = exp(-dE / 20)
    let dr = detailEnergy(refCrop, refM), dl = detailEnergy(litCrop, litM)
    if dr > 1e-5 && dl > 1e-5 { im.detail = exp(-abs(log(dl / dr))) }
    if let d = featureDistance(refCrop.cgImage, litCrop.cgImage) { im.perceptual = max(0, min(1, 1 - (d - 0.25) / 0.75)) }
    // Composite: reference | render | overlay.
    let side = 512, header = 56
    let c = Canvas(side * 3, side + header)
    c.image(refCrop.cgImage, x: 0, y: header, w: side, h: side)
    c.image(litCrop.cgImage, x: side, y: header, w: side, h: side)
    c.image(overlay(refM, renM, n: n).cgImage, x: side * 2, y: header, w: side, h: side)
    c.text("reference", x: 12, y: header + 10, size: 15, pill: true)
    c.text("render az \(Int(best.az)) el \(Int(best.el))", x: side + 12, y: header + 10, size: 15, pill: true)
    c.text("white both  red ref only  cyan render only", x: side * 2 + 12, y: header + 10, size: 13, pill: true)
    c.text("\(id) vs \(URL(fileURLWithPath: refPath).lastPathComponent)", x: 12, y: 8, size: 18, bold: true)
    c.text("silhouette \(fmt(im.silhouette))  perceptual \(fmt(im.perceptual))  color \(fmt(im.color))  aspect \(fmt(im.aspect))  detail \(fmt(im.detail))",
           x: 12, y: 32, size: 14, color: CGColor(gray: 0.8, alpha: 1))
    return (im, c.cgImage)
}

func writeJSON<T: Encodable>(_ v: T, _ path: String) throws {
    let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try e.encode(v).write(to: url)
}

struct GateReport: Encodable {
    var result: GateResult
    var geometry: GeometryReport
    var image: ImageMetrics?
    var brief: PropBrief?
    var verdict: Verdict?
    var iteration: Int
    var files: [String: String]
    var rubric: [[String: String]]
}

struct VerdictTemplate: Encodable {
    var scores: [String: Int]
    var notes: [String: String]
    var fixes: [String]
    var judge: String
}

/// `realityhd gate <id>`: lint + sheet (+ reference compare) -> report.json; with --verdict, the final score.
@MainActor
func gateCommand(_ args: Args) async throws {
    let seed = UInt64(args.opt("--seed") ?? "1") ?? 1
    let refArg = args.opt("--ref")
    let verdictPath = args.opt("--verdict")
    let threshold = args.opt("--threshold").flatMap(Float.init)
    let viewArg = args.opt("--view")?.split(separator: ",").compactMap { Float($0) }
    let fitView = args.flag("--fit-view")
    let signoff = args.flag("--signoff")
    let skipSheet = args.flag("--no-sheet")
    let views = args.opt("--views").map { Set($0.split(separator: ",").map(String.init)) }
    if views != nil && signoff { throw CLIError("--signoff needs the full sheet; drop --views") }
    guard let id = args.next() else { print(usage); return }
    guard let t = Catalog.type(id) else { throw CLIError("unknown asset id \(id)") }
    var brief = loadBrief(id)
    if let threshold { brief?.threshold = threshold }
    let paths = GatePaths(id)
    let lod = t.init().build(seed: seed)
    let g = GeometryLint.run(lod, budget: t.budget, brief: brief, hanging: t.tags.contains("ceiling"))
    var files: [String: String] = [:]
    if !skipSheet || !FileManager.default.fileExists(atPath: paths.sheet) {
        writePNG(try await makeSheet(id, seed: seed, geometry: g, brief: brief, views: views), paths.sheet)
    }
    files["sheet"] = paths.sheet
    var image: ImageMetrics?
    let root = try repoRoot()
    let refPath = refArg ?? brief?.references.first.map { root.appendingPathComponent($0).path }
    if let refPath {
        let (im, cmp) = try await compareReference(id, seed: seed, refPath: refPath, view: viewArg ?? brief?.view, fitView: fitView || (viewArg == nil && brief?.view == nil))
        writePNG(cmp, paths.compare); files["compare"] = paths.compare
        image = im
    }
    var verdict: Verdict?
    if let verdictPath {
        verdict = try JSONDecoder().decode(Verdict.self, from: Data(contentsOf: URL(fileURLWithPath: verdictPath)))
    }
    let result = GateResult.compute(id: id, geometry: g, brief: brief, image: image, verdict: verdict)
    let prior = (try? String(contentsOfFile: paths.history, encoding: .utf8))?.split(separator: "\n").count ?? 0
    let iteration = verdict == nil ? prior : prior + 1
    let rubric = Rubric.criteria.filter { $0.id != "reference" || image != nil }.map { ["id": $0.id, "question": $0.question, "anchors": $0.anchors, "weight": String($0.weight)] }
    try writeJSON(GateReport(result: result, geometry: g, image: image, brief: brief, verdict: verdict, iteration: iteration, files: files, rubric: rubric), paths.report)
    if verdict == nil {
        var scores: [String: Int] = [:]
        for c in Rubric.criteria where c.id != "reference" || image != nil { scores[c.id] = 0 }
        try writeJSON(VerdictTemplate(scores: scores, notes: ["silhouette": "one line per criterion"], fixes: ["most valuable edit first"], judge: "agent"), paths.template)
    } else {
        let entry: [String: Any] = ["final": result.final ?? 0, "auto": result.automated, "vision": result.vision ?? 0, "status": result.status,
                                    "date": ISO8601DateFormatter().string(from: Date()), "fingerprint": GeometryLint.fingerprint(lod)]
        let line = String(data: try JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]), encoding: .utf8)! + "\n"
        if let h = FileHandle(forWritingAtPath: paths.history) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); h.closeFile() }
        else { try line.write(toFile: paths.history, atomically: true, encoding: .utf8) }
    }
    if signoff, let verdict, result.status == "pass", let final = result.final, let vision = result.vision {
        let so = Signoff(id: id, final: final, automated: result.automated, vision: vision, threshold: result.threshold, judge: verdict.judge,
                         fingerprint: GeometryLint.fingerprint(lod), seed: seed, date: String(ISO8601DateFormatter().string(from: Date()).prefix(10)),
                         scores: verdict.scores, iterations: iteration)
        try writeJSON(so, root.appendingPathComponent("briefs/signoff/\(id).json").path)
        files["signoff"] = "briefs/signoff/\(id).json"
    }
    // One stat line plus problems, nothing else (agents read report.json for detail).
    print("gate \(id): \(result.status) final \(fmt(result.final, 3)) auto \(fmt(result.automated, 3)) vision \(fmt(result.vision, 3)) thr \(fmt(result.threshold)) iter \(iteration)")
    for i in g.issues where i.severity != .info { print("  \(i.severity.rawValue) \(i.code): \(i.message)") }
    for r in result.reasons where verdict != nil { print("  \(r)") }
    if let im = image { print("  ref: silhouette \(fmt(im.silhouette)) perceptual \(fmt(im.perceptual)) color \(fmt(im.color)) view \(im.view?.map { String(Int($0)) }.joined(separator: ",") ?? "-")") }
    print("  " + files.sorted { $0.key < $1.key }.map(\.value).joined(separator: " ") + " \(paths.report)")
    if verdict == nil { print("  next: Read \(paths.sheet)\(image != nil ? " and \(paths.compare)" : ""), write \(paths.verdict) from \(paths.template), rerun with --verdict \(paths.verdict)") }
}

/// `realityhd sheet <id>`: the six-view sheet only.
@MainActor
func sheetCommand(_ args: Args) async throws {
    let seed = UInt64(args.opt("--seed") ?? "1") ?? 1
    let out = args.opt("--out")
    guard let id = args.next(), let t = Catalog.type(id) else { print(usage); return }
    let lod = t.init().build(seed: seed)
    let brief = loadBrief(id)
    let g = GeometryLint.run(lod, budget: t.budget, brief: brief, hanging: t.tags.contains("ceiling"))
    let path = out ?? GatePaths(id).sheet
    writePNG(try await makeSheet(id, seed: seed, geometry: g, brief: brief), path)
    print(path)
}

/// `realityhd lint [id...]`: geometry lint (budget, grounding, texel density, size vs brief).
func lintCommand(_ args: Args) {
    let seed = UInt64(args.opt("--seed") ?? "1") ?? 1
    let all = args.flag("--all")
    let ids = args.rest.isEmpty || all ? Catalog.assets.map { $0.id } : args.rest
    var bad = 0
    for id in ids {
        guard let t = Catalog.type(id) else { print("unknown \(id)"); continue }
        let g = GeometryLint.run(t.init().build(seed: seed), budget: t.budget, brief: loadBrief(id), hanging: t.tags.contains("ceiling"))
        let shown = g.issues.filter { $0.severity != .info || ids.count == 1 }
        if shown.isEmpty && ids.count > 1 { continue }
        if g.errors > 0 { bad += 1 }
        print("\(id): lint \(fmt(g.score)) tris \(g.triangles.map(String.init).joined(separator: "/"))/\(g.budget) size \(fmtSize(g.size))")
        for i in shown { print("  \(i.severity.rawValue) \(i.code): \(i.message)") }
    }
    if ids.count > 1 { print("\(ids.count) assets, \(bad) with errors") }
}
