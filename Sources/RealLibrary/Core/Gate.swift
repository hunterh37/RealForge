import simd
import Foundation

// RealityHD 3 quality gate: prop briefs, geometry lint, the vision rubric and the score that signs an
// asset off. Pure Swift (no RealityKit) so tests run it; the CLI adds renders and image metrics.

/// What a prop must be: written before modeling (`realityhd brief <id>`), read by `realityhd new
/// --brief`, `realityhd gate` and `BriefTests`. Stored at `briefs/<id>.json`.
public struct PropBrief: Codable, Sendable, Equatable {
    public var id: String
    /// Plain name ("Victorian leather suitcase").
    public var name: String
    public var kind: String = "prop"
    /// Theme folder under Props/ (`Travel`, `Kitchen`).
    public var theme: String
    /// One sentence for `RealAsset.summary`.
    public var summary: String
    public var tags: [String]
    /// Real overall size in meters: x width, y height, z depth (as built, +Y up).
    public var size: [Float]
    /// Allowed relative error per axis (0.08 = 8 percent).
    public var tolerance: Float = 0.08
    /// Material keys the asset should use (existing or planned).
    public var materials: [String]
    /// Parts a viewer should be able to point at. The vision judge checks them.
    public var parts: [String]
    /// Look and era in a few words ("1920s steamer trunk, well travelled").
    public var style: String = ""
    public var budget: Int = 10_000
    /// Reference images (paths relative to the repo root, usually `briefs/refs/<id>/*.jpg`).
    public var references: [String] = []
    /// Camera that matches the main reference (degrees). nil = `--fit-view` search or preview hint.
    public var view: [Float]? = nil
    /// Final score required to sign off.
    public var threshold: Float = 0.85
    public var notes: String = ""

    public init(id: String, name: String, theme: String, summary: String, tags: [String], size: [Float],
                materials: [String], parts: [String], style: String = "", budget: Int = 10_000) {
        self.id = id; self.name = name; self.theme = theme; self.summary = summary; self.tags = tags; self.size = size
        self.materials = materials; self.parts = parts; self.style = style; self.budget = budget
    }

    public var sizeV3: V3 { size.count == 3 ? V3(size[0], size[1], size[2]) : .zero }

    enum CodingKeys: String, CodingKey { case id, name, kind, theme, summary, tags, size, tolerance, materials, parts, style, budget, references, view, threshold, notes }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); name = try c.decode(String.self, forKey: .name)
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "prop"
        theme = try c.decode(String.self, forKey: .theme); summary = try c.decode(String.self, forKey: .summary)
        tags = try c.decode([String].self, forKey: .tags); size = try c.decode([Float].self, forKey: .size)
        tolerance = try c.decodeIfPresent(Float.self, forKey: .tolerance) ?? 0.08
        materials = try c.decodeIfPresent([String].self, forKey: .materials) ?? []
        parts = try c.decodeIfPresent([String].self, forKey: .parts) ?? []
        style = try c.decodeIfPresent(String.self, forKey: .style) ?? ""
        budget = try c.decodeIfPresent(Int.self, forKey: .budget) ?? 10_000
        references = try c.decodeIfPresent([String].self, forKey: .references) ?? []
        view = try c.decodeIfPresent([Float].self, forKey: .view)
        threshold = try c.decodeIfPresent(Float.self, forKey: .threshold) ?? 0.85
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    public static func load(_ url: URL) throws -> PropBrief { try JSONDecoder().decode(PropBrief.self, from: Data(contentsOf: url)) }
    public func write(_ url: URL) throws {
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try e.encode(self).write(to: url)
    }
}

/// One lint finding. `error` blocks sign-off; `warn` costs lint score.
public struct LintIssue: Codable, Sendable {
    public enum Severity: String, Codable, Sendable { case error, warn, info }
    public var severity: Severity
    public var code: String
    public var message: String
}

/// Geometry facts and problems an agent cannot see in a render.
public struct GeometryReport: Codable, Sendable {
    public var triangles: [Int]
    public var budget: Int
    public var vertices: Int
    public var size: [Float]
    public var minY: Float
    public var center: [Float]
    public var materials: [String: Int]
    /// Per material: median meters per UV unit (1 = meters, as RealCore expects).
    public var texelRatio: [String: Float]
    public var degenerate: Int
    public var issues: [LintIssue]

    public var errors: Int { issues.filter { $0.severity == .error }.count }
    public var warnings: Int { issues.filter { $0.severity == .warn }.count }
    /// 1 with no warnings, minus 0.08 per warning, 0 with any error.
    public var score: Float { errors > 0 ? 0 : max(0, 1 - Float(warnings) * 0.08) }
}

public enum GeometryLint {
    /// Lints LOD0 (and LOD ordering) of a built asset.
    public static func run(_ lod: LODModel, budget: Int, brief: PropBrief? = nil, hanging: Bool = false) -> GeometryReport {
        let m = lod.levels[0]
        let bb = m.bounds, e = bb.max - bb.min, c = (bb.min + bb.max) / 2
        var issues: [LintIssue] = []
        func add(_ s: LintIssue.Severity, _ code: String, _ msg: String) { issues.append(LintIssue(severity: s, code: code, message: msg)) }
        let tris = lod.levels.map(\.triangleCount)
        if tris[0] > budget { add(.error, "budget", "LOD0 \(tris[0]) tris > budget \(budget)") }
        else if Float(tris[0]) < Float(budget) * 0.35 && budget > 4000 { add(.info, "budget-slack", "LOD0 uses \(tris[0] * 100 / max(budget, 1))% of budget; lower budget or add detail") }
        for i in 1..<max(1, tris.count) where tris[i] > tris[i - 1] { add(.error, "lod-order", "LOD\(i) heavier than LOD\(i - 1)") }
        if tris[0] > 5000 && tris.count == 1 { add(.info, "lod", "single LOD above 5k tris; scenes instancing it want 2-3 levels") }
        if bb.min.y < -0.02 { add(.warn, "sunk", String(format: "base at y %.3f m; props sit on y = 0", bb.min.y)) }
        if bb.min.y > 0.01 && !hanging { add(.error, "floating", String(format: "lowest point at y %.3f m; asset floats", bb.min.y)) }
        if abs(c.x) > e.x * 0.15 + 0.02 || abs(c.z) > e.z * 0.15 + 0.02 { add(.warn, "center", String(format: "bounds center (%.3f, %.3f) off the origin", c.x, c.z)) }
        var mats: [String: Int] = [:], ratios: [String: Float] = [:]
        var degenerate = 0
        for s in m.surfaces {
            mats[s.material, default: 0] += s.triangleCount
            var r: [Float] = []
            for t in stride(from: 0, to: s.indices.count, by: 3) {
                let a = Int(s.indices[t]), b = Int(s.indices[t + 1]), cc = Int(s.indices[t + 2])
                let area = simd_length(simd_cross(s.positions[b] - s.positions[a], s.positions[cc] - s.positions[a])) / 2
                if area < 1e-10 { degenerate += 1; continue }
                if t % 9 != 0 || s.uvs.count != s.positions.count { continue }
                let d1 = s.uvs[b] - s.uvs[a], d2 = s.uvs[cc] - s.uvs[a]
                let uvArea = abs(d1.x * d2.y - d1.y * d2.x) / 2
                if uvArea > 1e-12 { r.append(sqrt(area / uvArea)) }
            }
            r.sort()
            let base = String(s.material.split(separator: ":")[0])
            let ratio = r.isEmpty ? 1 : r[r.count / 2]
            ratios[s.material] = ratio
            let spec = MaterialLibrary.spec(for: base)
            // Labels and screens map 0...1 across the panel, like atlases.
            let panel: [TextureProgram] = [.medLabel, .vitalsUI, .screenUI]
            let atlas = spec.tileSize == 0 || spec.program == nil || spec.program.map(panel.contains) == true
            if !atlas && !base.contains("endgrain") && (ratio > 2.5 || ratio < 0.4) {
                add(.warn, "texel", String(format: "%@: UVs at %.2f m per unit (expected ~1); texture scale will look wrong", s.material, ratio))
            }
            if !MaterialLibrary.keys.contains(base) { add(.error, "material", "unknown material \(s.material)") }
        }
        if degenerate > tris[0] / 4 + 10 { add(.warn, "degenerate", "\(degenerate) zero-area triangles") }
        if m.surfaces.count > 8 { add(.info, "draws", "\(m.surfaces.count) materials = \(m.surfaces.count) draw calls") }
        if let brief, brief.size.count == 3 {
            let target = brief.sizeV3
            for (i, axis) in ["width x", "height y", "depth z"].enumerated() where target[i] > 0 {
                let err = abs(e[i] - target[i]) / target[i]
                if err > brief.tolerance * 2 { add(.error, "size", String(format: "%@ %.3f m vs brief %.3f m (%.0f%% off)", axis, e[i], target[i], err * 100)) }
                else if err > brief.tolerance { add(.warn, "size", String(format: "%@ %.3f m vs brief %.3f m (%.0f%% off)", axis, e[i], target[i], err * 100)) }
            }
            for k in brief.materials where !mats.keys.contains(where: { $0.hasPrefix(k) }) {
                add(.info, "brief-material", "brief lists \(k), model does not use it")
            }
        }
        return GeometryReport(triangles: tris, budget: budget, vertices: m.vertexCount, size: [e.x, e.y, e.z], minY: bb.min.y,
                              center: [c.x, c.z], materials: mats, texelRatio: ratios, degenerate: degenerate, issues: issues)
    }

    /// 0...1 match of measured size to the brief (Gaussian per axis: 1 exact, 0.5 at the tolerance).
    public static func sizeScore(_ measured: [Float], _ brief: PropBrief) -> Float {
        guard brief.size.count == 3, measured.count == 3 else { return 1 }
        var s: Float = 0, n: Float = 0
        for i in 0..<3 where brief.size[i] > 0 {
            let err = abs(measured[i] - brief.size[i]) / brief.size[i]
            let r = err / max(brief.tolerance, 0.01); s += exp(-0.693 * r * r); n += 1
        }
        return n > 0 ? s / n : 1
    }

    /// Changes whenever the built geometry changes (triangle counts, size, materials). Sign-offs store it.
    public static func fingerprint(_ lod: LODModel) -> String {
        let m = lod.levels[0], bb = m.bounds
        var h: UInt64 = 1469598103934665603
        func mix(_ v: UInt64) { h = (h ^ v) &* 1099511628211 }
        for t in lod.levels.map(\.triangleCount) { mix(UInt64(t)) }
        for v in [bb.min, bb.max] { for i in 0..<3 { mix(UInt64(bitPattern: Int64((v[i] * 1000).rounded()))) } }
        for k in m.materials.sorted() { for b in k.utf8 { mix(UInt64(b)) } }
        return String(format: "%016llx", h)
    }
}

/// Image metrics from `realityhd gate --ref` (all 0...1, 1 = identical). nil = not measured.
public struct ImageMetrics: Codable, Sendable {
    public var silhouette: Float?
    public var aspect: Float?
    public var color: Float?
    public var perceptual: Float?
    public var detail: Float?
    public var view: [Float]?
    public init() {}
}

/// The vision rubric. Each criterion is scored 0-10 by a vision judge (Claude reading the gate sheet,
/// or `Scripts/vision_judge.py`). Anchors keep scores comparable between runs and judges.
public enum Rubric {
    public struct Criterion: Sendable { public let id: String; public let weight: Float; public let question: String; public let anchors: String }
    public static let criteria: [Criterion] = [
        .init(id: "silhouette", weight: 1.2, question: "Does the outline read instantly as the object from every view?",
              anchors: "10 unmistakable from any angle; 6 recognizable but generic; 3 wrong shape language"),
        .init(id: "proportion", weight: 1.0, question: "Are proportions and scale right against the brief size and the ground?",
              anchors: "10 matches a real one; 6 one part visibly off; 3 toy-like or stretched"),
        .init(id: "construction", weight: 1.3, question: "Are the brief's parts present, joined believably (seams, fasteners, thickness)?",
              anchors: "10 every part, real joinery and wall thickness; 6 main parts only; 3 blocky placeholders"),
        .init(id: "edges", weight: 0.8, question: "Do edges carry bevels and catch highlights; any knife-sharp CG edges?",
              anchors: "10 all edges softened at real radii; 6 major edges only; 3 raw boxes"),
        .init(id: "materials", weight: 1.4, question: "Do albedo, roughness and metalness read as the real material at the right texel scale?",
              anchors: "10 photographic; 6 right material, flat or wrong scale; 3 wrong material"),
        .init(id: "wear", weight: 0.8, question: "Is aging plausible (where hands and weather reach) and not uniform?",
              anchors: "10 tells a story, varies per part; 6 uniform noise; 3 none or random"),
        .init(id: "grounding", weight: 0.5, question: "Does it sit on the ground with contact shadow and AO, no float or sink?",
              anchors: "10 planted; 6 slight float or missing AO; 3 floating"),
        .init(id: "artifacts", weight: 1.0, question: "Free of z-fighting, holes, stretched UVs, shading seams, interpenetration? (10 = clean)",
              anchors: "10 clean; 6 one visible artifact; 3 several"),
        .init(id: "reference", weight: 1.5, question: "With a reference: how exactly does it match the reference object? Omit without one.",
              anchors: "10 same object; 6 same type, different details; 3 different object"),
    ]
    public static let floor = 6
}

/// A vision judge's scores for one gate run (`out/gate/<id>/verdict.json`).
public struct Verdict: Codable, Sendable {
    public var scores: [String: Int]
    public var notes: [String: String] = [:]
    /// Concrete next edits, most valuable first ("bevel lid edge 4 mm", "brass too yellow: colorA D9B263 -> B8954E").
    public var fixes: [String] = []
    public var judge: String = "agent"
    public init(scores: [String: Int], notes: [String: String] = [:], fixes: [String] = [], judge: String = "agent") {
        self.scores = scores; self.notes = notes; self.fixes = fixes; self.judge = judge
    }
    enum CodingKeys: String, CodingKey { case scores, notes, fixes, judge }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        scores = try c.decode([String: Int].self, forKey: .scores)
        notes = try c.decodeIfPresent([String: String].self, forKey: .notes) ?? [:]
        fixes = try c.decodeIfPresent([String].self, forKey: .fixes) ?? []
        judge = try c.decodeIfPresent(String.self, forKey: .judge) ?? "agent"
    }

    /// Weighted mean of the scored criteria, 0...1.
    public var score: Float {
        var s: Float = 0, w: Float = 0
        for c in Rubric.criteria { if let v = scores[c.id] { s += Float(max(0, min(10, v))) / 10 * c.weight; w += c.weight } }
        return w > 0 ? s / w : 0
    }
    public var lowest: (String, Int)? { scores.min { $0.value < $1.value }.map { ($0.key, $0.value) } }
}

/// Final gate result written to `report.json` and, on pass, `briefs/signoff/<id>.json`.
public struct GateResult: Codable, Sendable {
    public var id: String
    public var automated: Float
    public var vision: Float?
    public var final: Float?
    public var threshold: Float
    public var status: String          // pass, fail, needs-vision
    public var reasons: [String]
    public var components: [String: Float]

    public static func compute(id: String, geometry g: GeometryReport, brief: PropBrief?, image: ImageMetrics?, verdict: Verdict?) -> GateResult {
        var comp: [String: Float] = ["lint": g.score]
        var weights: [String: Float] = ["lint": 0.15]
        if let brief { comp["size"] = GeometryLint.sizeScore(g.size, brief); weights["size"] = 0.25 }
        if let i = image {
            for (k, v, w) in [("silhouette", i.silhouette, Float(0.15)), ("perceptual", i.perceptual, 0.25), ("color", i.color, 0.12),
                              ("aspect", i.aspect, 0.06), ("detail", i.detail, 0.04)] {
                if let v { comp[k] = v; weights[k] = w }
            }
        }
        let wsum = weights.values.reduce(0, +)
        let auto = comp.reduce(Float(0)) { $0 + $1.value * (weights[$1.key] ?? 0) } / max(wsum, 1e-6)
        let threshold = brief?.threshold ?? 0.85
        var reasons: [String] = []
        if g.errors > 0 { reasons.append("lint: \(g.issues.filter { $0.severity == .error }.map(\.message).joined(separator: "; "))") }
        guard let verdict else {
            return GateResult(id: id, automated: auto, vision: nil, final: nil, threshold: threshold, status: "needs-vision",
                              reasons: reasons + ["no verdict: judge out/gate/\(id)/sheet.png, write verdict.json, rerun with --verdict"], components: comp)
        }
        let vision = verdict.score
        let hasRef = image?.silhouette != nil
        let final = hasRef ? 0.5 * auto + 0.5 * vision : 0.35 * auto + 0.65 * vision
        for c in Rubric.criteria { if let v = verdict.scores[c.id], v < Rubric.floor { reasons.append("\(c.id) \(v) < floor \(Rubric.floor)") } }
        if final < threshold { reasons.append(String(format: "final %.3f < threshold %.2f", final, threshold)) }
        if hasRef && verdict.scores["reference"] == nil { reasons.append("reference image given but verdict has no 'reference' score") }
        return GateResult(id: id, automated: auto, vision: vision, final: final, threshold: threshold,
                          status: reasons.isEmpty ? "pass" : "fail", reasons: reasons, components: comp)
    }
}

/// Committed record that an asset passed the gate (`briefs/signoff/<id>.json`). Tests fail when the
/// geometry fingerprint no longer matches, so changed assets get re-gated.
public struct Signoff: Codable, Sendable {
    public var id: String
    public var final: Float
    public var automated: Float
    public var vision: Float
    public var threshold: Float
    public var judge: String
    public var fingerprint: String
    public var seed: UInt64
    public var date: String
    public var scores: [String: Int]
    public var iterations: Int
    public init(id: String, final: Float, automated: Float, vision: Float, threshold: Float, judge: String, fingerprint: String,
                seed: UInt64, date: String, scores: [String: Int], iterations: Int) {
        self.id = id; self.final = final; self.automated = automated; self.vision = vision; self.threshold = threshold; self.judge = judge
        self.fingerprint = fingerprint; self.seed = seed; self.date = date; self.scores = scores; self.iterations = iterations
    }
}
