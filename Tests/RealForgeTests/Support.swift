import Foundation
import simd
@testable import RealCore
@testable import RealLibrary
import RealMaterials

/// Repository root, from this file's location.
let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

func exists(_ relative: String) -> Bool { FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent(relative).path) }

func isKebab(_ s: String) -> Bool { s.range(of: "^[a-z0-9]+(-[a-z0-9]+)*$", options: .regularExpression) != nil }

/// Every `.swift` file under a source directory, keyed by file name without extension.
func swiftFiles(under relative: String) -> [String: String] {
    var out: [String: String] = [:]
    let root = repoRoot.appendingPathComponent(relative)
    guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return out }
    for case let url as URL in e where url.pathExtension == "swift" {
        out[url.deletingPathExtension().lastPathComponent] = String(url.path.dropFirst(repoRoot.path.count + 1))
    }
    return out
}

func baseKey(_ k: MaterialKey) -> String { String(k.split(separator: ":")[0]) }

/// Max LOD0 budget a contributor may declare per kind.
let budgetCap = ["nature": 60_000, "prop": 15_000, "structure": 30_000]

/// Registry each kind must be listed in.
let registry: [String: [any RealAsset.Type]] = ["nature": Nature.all, "prop": Props.all, "structure": Structures.all]
let kindFolder = ["nature": "Nature", "prop": "Props", "structure": "Structures"]
