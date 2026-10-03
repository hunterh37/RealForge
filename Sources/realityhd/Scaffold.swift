import Foundation
import RealMaterials
import RealLibrary

/// `realityhd new ...`: writes a compiling, test-shaped source file and registers it at the
/// `// realityhd:<marker>` line of the matching registry. Tests then name what is left to do
/// (summary, thumbnail).
func newCommand(_ args: Args) throws {
    let root = try repoRoot()
    let author = args.opt("--author") ?? "realityhd"
    let theme = args.opt("--theme")
    let material = args.opt("--material")
    let program = args.opt("--program")
    let like = args.opt("--like")
    let briefPath = args.opt("--brief")
    guard let what = args.next(), let id = args.next() else { print(usage); return }
    switch what {
    case "prop", "nature", "structure":
        if let briefPath {
            let b = try PropBrief.load(URL(fileURLWithPath: briefPath, relativeTo: root))
            try newAsset(kind: what, id: id, theme: theme ?? b.theme, author: author, material: material ?? b.materials.first, root: root, brief: b)
        } else {
            try newAsset(kind: what, id: id, theme: theme ?? defaultTheme[what]!, author: author, material: material, root: root)
        }
    case "scene":
        try newScene(id: id, author: author, root: root)
    case "material":
        try newMaterial(key: id, program: program, like: like, root: root)
    default:
        throw CLIError("new: expected prop, nature, structure, scene or material")
    }
}

private let defaultTheme = ["prop": "Misc", "nature": "Plants", "structure": "Misc"]
private let kindFolder = ["prop": "Props", "nature": "Nature", "structure": "Structures"]
private let kindDefaults: [String: (budget: String, material: String, size: String)] = [
    "prop": ("6_000", "wood.pine", "V3(0.6, 0.8, 0.4)"),
    "nature": ("12_000", "rock.granite", "V3(1, 0.6, 1)"),
    "structure": ("20_000", "concrete.smooth", "V3(2, 1.2, 0.2)"),
]

func typeName(_ id: String) -> String {
    id.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
}

private func validID(_ id: String) throws {
    guard id.range(of: "^[a-z0-9]+(-[a-z0-9]+)*$", options: .regularExpression) != nil else {
        throw CLIError("id must be kebab-case: \(id)")
    }
}

/// Inserts `text` on the line before `// realityhd:<marker>`, matching its indentation.
func register(_ text: String, marker: String, in file: URL) throws {
    var src = try String(contentsOf: file, encoding: .utf8)
    guard let r = src.range(of: "// realityhd:\(marker)\n") else { throw CLIError("marker realityhd:\(marker) missing in \(file.lastPathComponent)") }
    let lineStart = src[..<r.lowerBound].lastIndex(of: "\n").map { src.index(after: $0) } ?? src.startIndex
    let indent = String(src[lineStart..<r.lowerBound])
    let block = text.split(separator: "\n", omittingEmptySubsequences: false).map { indent + $0 }.joined(separator: "\n") + "\n"
    src.insert(contentsOf: block, at: lineStart)
    try src.write(to: file, atomically: true, encoding: .utf8)
}

private func create(_ url: URL, _ text: String) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else { throw CLIError("exists: \(url.path)") }
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try text.write(to: url, atomically: true, encoding: .utf8)
}

private func rel(_ url: URL, _ root: URL) -> String { String(url.path.dropFirst(root.path.count + 1)) }

private func newAsset(kind: String, id: String, theme: String, author: String, material: String?, root: URL, brief: PropBrief? = nil) throws {
    try validID(id)
    guard Catalog.type(id) == nil else { throw CLIError("asset id taken: \(id)") }
    let d = kindDefaults[kind]!, name = typeName(id), folder = kindFolder[kind]!
    let mat = material ?? d.material
    guard MaterialLibrary.keys.contains(String(mat.split(separator: ":")[0])) else { throw CLIError("unknown material \(mat)") }
    var tags = ["\"\(kind)\""]
    if AssetTag.vocabulary.contains(theme.lowercased()), theme.lowercased() != kind { tags.append("\"\(theme.lowercased())\"") }
    if let brief { tags = ([kind] + brief.tags.filter { $0 != kind && AssetTag.vocabulary.contains($0) }).map { "\"\($0)\"" } }
    let size = brief.map { "V3(\($0.size[0]), \($0.size[1]), \($0.size[2]))" } ?? d.size
    let budget = brief.map { String($0.budget) } ?? d.budget
    let summary = brief?.summary ?? "TODO: one sentence, what it is and how it's built."
    let doc = brief.map { "\($0.name): \($0.style). Parts: \($0.parts.joined(separator: ", "))." } ?? "TODO: what it is, real-world dimensions, construction (parts, materials, wear)."
    let matNote = brief.map { "// Brief materials: \($0.materials.joined(separator: " ")). Gate: realityhd gate \(id)." } ?? "// Replace with the real construction."
    let file = root.appendingPathComponent("Sources/RealLibrary/\(folder)/\(theme)/\(name).swift")
    try create(file, """
    import simd
    import Foundation

    /// \(doc)
    public struct \(name): RealAsset {
        public static let id = "\(id)"
        public static let summary = "\(summary)"
        public static let tags = [\(tags.joined(separator: ", "))]
        public static let budget = \(budget)
        public static let author = "\(author)"

        /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
        public var size = \(size)
        public init() {}

        public func build(seed: UInt64) -> LODModel {
            var rng = SeededRNG(seed: seed)
            var m = Model(name: Self.id)
            \(matNote) Boards: plank()/board() along +X (grain on U).
            // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
            m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "\(mat)"),
                  Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
            groundAO(&m)
            return LODModel(m)
        }
    }

    """)
    let registry = root.appendingPathComponent("Sources/RealLibrary/\(folder)/\(folder).swift")
    try register("\(name).self,", marker: kind, in: registry)
    print("""
    created \(rel(file, root))
    registered in \(rel(registry, root))
    next: write build(), swift test, swift run -q realityhd render \(id), swift run -q realityhd thumbs \(id), swift run -q realityhd catalog
    """)
}

private func newScene(id: String, author: String, root: URL) throws {
    try validID(id)
    guard SceneCatalog.type(id) == nil, Catalog.type(id) == nil else { throw CLIError("id taken: \(id)") }
    let name = typeName(id)
    let file = root.appendingPathComponent("Sources/RealLibrary/Scenes/\(name).swift")
    try create(file, """
    import simd
    import Foundation
    import RealityKit
    import RealKit

    /// TODO: setting, size, what the viewer sees from the camera hint.
    public struct \(name): RealSceneBuilder {
        public static let id = "\(id)"
        public static let summary = "TODO: one sentence, setting and contents."
        public static let tags = ["showcase"]
        public static let author = "\(author)"

        public var radius: Float = 25
        public init() {}

        public func build(seed: UInt64) -> RealScene {
            var scene = RealScene(name: Self.id)
            var rng = SeededRNG(seed: seed &+ 99)
            let ground = GroundPatch().with { $0.size = radius * 2.2; $0.segments = 128; $0.relief = 0.3; $0.flatCenter = 6 }
            scene.add(ground, seed: seed)
            func y(_ p: V2) -> Float { ground.height(x: p.x, z: p.y, seed: seed) }

            // Hero assets: one entity each. Give every placement its own seed offset.
            scene.add(Boulder(), at: place(2, -4, y: y(V2(2, -4)), yaw: rng.float(0...360)), seed: seed &+ 1)

            // Anything repeated: one instanced field per asset variant.
            let spots = Scatter.poisson(count: 40, outerRadius: radius, innerRadius: 12, minSpacing: 4, seed: seed &+ 2)
            scene.field(SpruceTree(), seed: seed &+ 3, transforms: spots.map {
                place($0.x, $0.y, y: y($0) - 0.1, yaw: rng.float(0...360), scale: rng.float(0.8...1.2)).matrix
            }, options: .trees)

            let eyeY = y(V2(0, 6)) + 1.6
            scene.camera = .init(eye: V3(0, eyeY, 6), target: V3(0, eyeY - 0.4, -10), fov: 60)
            return scene
        }
    }

    """)
    let registry = root.appendingPathComponent("Sources/RealLibrary/Scenes/SceneCatalog.swift")
    try register("\(name).self,", marker: "scene", in: registry)
    print("""
    created \(rel(file, root))
    registered in \(rel(registry, root))
    next: compose build(), swift test, swift run -q realityhd render \(id), swift run -q realityhd thumbs \(id), swift run -q realityhd catalog
    demo app: add a case to DemoScene in Demo/RealityHDDemo/DemoApp.swift
    """)
}

private func newMaterial(key: String, program: String?, like: String?, root: URL) throws {
    guard key.range(of: "^[a-z]+\\.[a-z0-9]+(-[a-z0-9]+)*$", options: .regularExpression) != nil else {
        throw CLIError("material key must be family.variant: \(key)")
    }
    guard !MaterialLibrary.keys.contains(key) else { throw CLIError("material key taken: \(key)") }
    let family = String(key.split(separator: ".")[0])
    let fileName = family.prefix(1).uppercased() + family.dropFirst()
    let lib = root.appendingPathComponent("Sources/RealMaterials/Library")
    var spec: String
    if let like {
        spec = try copySpec(like, as: key, in: lib)
        if let program { spec = spec.replacingOccurrences(of: #"program: \.?[A-Za-z]+\)"#, with: "program: .\(program))", options: .regularExpression) }
    } else {
        guard let program, TextureProgram.allCases.contains(where: { "\($0)" == program }) else {
            throw CLIError("--program one of: \(TextureProgram.allCases.map { "\($0)" }.joined(separator: ", ")) (or --like key)")
        }
        spec = """
        MaterialSpec(key: "\(key)", program: .\(program)).with {
            $0.colorA = linear(0x808080); $0.colorB = linear(0x404040); $0.colorC = linear(0x202020, 0)
            $0.knobs = V4(0.5, 0.5, 0, 0); $0.seed = \(key.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % 90 + 10); $0.tileSize = 1; $0.normalStrength = 2
        }
        """
    }
    let file = lib.appendingPathComponent("\(fileName).swift")
    if !FileManager.default.fileExists(atPath: file.path) {
        try create(file, """
        import RealCore

        public extension MaterialLibrary {
            /// TODO: what this family covers.
            static let \(family): [MaterialSpec] = [
                // realityhd:material.\(family)
            ]
        }

        """)
        let specFile = root.appendingPathComponent("Sources/RealMaterials/MaterialSpec.swift")
        var src = try String(contentsOf: specFile, encoding: .utf8)
        guard let r = src.range(of: #"public static let all: \[MaterialSpec\] = [^\n]+"#, options: .regularExpression) else {
            throw CLIError("MaterialLibrary.all not found")
        }
        src.replaceSubrange(r, with: src[r] + " + \(family)")
        try src.write(to: specFile, atomically: true, encoding: .utf8)
        print("created \(rel(file, root)), added .\(family) to MaterialLibrary.all")
    }
    try register(spec + ",", marker: "material.\(family)", in: file)
    print("""
    registered \(key) in \(rel(file, root))\(like.map { " (copy of \($0): change colors and seed)" } ?? "")
    next: tune colors/knobs, swift run -q realityhd textures \(key), render an asset using it, swift run -q realityhd catalog
    """)
}

/// Copies the source text of an existing spec under a new key.
private func copySpec(_ key: String, as newKey: String, in lib: URL) throws -> String {
    let files = try FileManager.default.contentsOfDirectory(at: lib, includingPropertiesForKeys: nil)
    for f in files where f.pathExtension == "swift" {
        let src = try String(contentsOf: f, encoding: .utf8)
        guard let start = src.range(of: "MaterialSpec(key: \"\(key)\"") else { continue }
        let lineStart = src[..<start.lowerBound].lastIndex(of: "\n").map { src.index(after: $0) }!
        let indent = src[lineStart..<start.lowerBound]
        // Brace-match the `.with { ... }` body.
        var depth = 0, i = start.lowerBound, opened = false
        while i < src.endIndex {
            if src[i] == "{" { depth += 1; opened = true }
            if src[i] == "}" { depth -= 1; if opened && depth == 0 { break } }
            i = src.index(after: i)
        }
        guard i < src.endIndex else { break }
        let text = String(src[start.lowerBound...i])
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let body = lines.enumerated().map { $0.offset == 0 ? String($0.element) : String($0.element.dropFirst(indent.count)) }.joined(separator: "\n")
        return body.replacingOccurrences(of: "key: \"\(key)\"", with: "key: \"\(newKey)\"")
    }
    throw CLIError("no spec \(key) to copy")
}
