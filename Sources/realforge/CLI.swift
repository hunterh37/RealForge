import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Argument list with `--name value` options and `--flag` switches consumed as they are read.
final class Args {
    var rest: [String]
    init(_ a: [String]) { rest = a }
    func opt(_ name: String) -> String? {
        guard let i = rest.firstIndex(of: name), i + 1 < rest.count else { return nil }
        let v = rest[i + 1]; rest.removeSubrange(i...(i + 1)); return v
    }
    func flag(_ name: String) -> Bool { if let i = rest.firstIndex(of: name) { rest.remove(at: i); return true }; return false }
    func next() -> String? { rest.isEmpty ? nil : rest.removeFirst() }
}

struct CLIError: Error, CustomStringConvertible { let description: String; init(_ d: String) { description = d } }

func writePNG(_ img: CGImage, _ path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
}

func pad(_ s: String, _ n: Int = 16) -> String { s.padding(toLength: max(n, s.count + 1), withPad: " ", startingAt: 0) }

/// Repo root (directory holding Package.swift); commands that write sources or docs need it.
func repoRoot() throws -> URL {
    var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    while url.path != "/" {
        if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path),
           FileManager.default.fileExists(atPath: url.appendingPathComponent("Sources/RealLibrary").path) { return url }
        url.deleteLastPathComponent()
    }
    throw CLIError("run inside the RealForge checkout")
}

let usage = """
realforge list [tag]                      assets and scenes (filter by tag)
realforge stats [id...] [--seed n]        triangles per LOD, materials, generation time
realforge render <id|scene> [options]     out/<id>.png via RealityRenderer
    --seed n --out path --w 1280 --h 800 --sky morning|midday|afternoon|golden --fog d --dt s
    --az deg --el deg --dist k --lod n --pbr --no-ground --eye x,y,z --at x,y,z
realforge thumbs [id...] [--missing]      docs/assets/<id>.png (640x480), docs/scenes/<id>.png (1280x800)
realforge textures [key...] [--size 512] [--out out/tex]
realforge shaders [--dump]                load every ShaderGraph variant
realforge catalog                         regenerate CATALOG.md
realforge new prop|nature|structure <id> [--theme Folder] [--author handle] [--material key]
realforge new scene <id> [--author handle]
realforge new material <family.variant> --program <TextureProgram> [--like key]
realforge bench                           release timing (swift run -c release realforge bench)
"""
