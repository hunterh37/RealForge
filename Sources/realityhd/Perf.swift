import Foundation
import RealCore
import RealKit
import RealLibrary

/// `realityhd perf [scene...] [--tier t] [--seed n]`: per-scene cost at the camera hint for every tier
/// (or one), from the same LOD, culling, thinning, batching and shadow policy the runtime uses.
@MainActor
func perfCommand(_ args: Args, tier: RealPerformance.Tier?) {
    let seed = UInt64(args.opt("--seed") ?? "1") ?? 1
    let ids = args.rest.isEmpty ? SceneCatalog.ids : args.rest
    let tiers = tier.map { [$0] } ?? RealPerformance.Tier.allCases
    print(pad("scene", 18), pad("tier", 12), pad("tris", 9), pad("shadow", 9), pad("draws", 7), pad("inst", 8), pad("meshes", 8), "weight vs balanced")
    for id in ids {
        guard let scene = SceneCatalog.build(id, seed: seed) else { print("unknown scene \(id)"); continue }
        let base = scene.estimate(settings: RealPerformance(.balanced)).weight
        for t in tiers {
            let c = scene.estimate(settings: RealPerformance(t))
            let rel = base > 0 ? String(format: "%.2fx", Double(c.weight) / Double(base)) : "-"
            print(pad(id, 18), pad(t.rawValue, 12), pad("\(c.triangles / 1000)k", 9), pad("\(c.shadowTriangles / 1000)k", 9),
                  pad("\(c.drawCalls)", 7), pad("\(c.instances)", 8), pad("\(c.meshes)", 8), rel)
        }
    }
}
