# vision-optimize 2026-10-07

Scope: Sources/RealKit (systems, LOD, articulation, performance, grab cue), Demo/RealityHDDemo.
Baseline: `swift build` clean, 0 warnings. After: unchanged (no edits).

## Applied

None. No candidate met the zero-regression bar with a measurable gain.

## Checked, already correct

- RealLODSystem (LOD.swift:45): static `EntityQuery`, 0.2 s throttle, writes component only on change.
- RealArticulationSystem (Articulation.swift:86): static query, skips non-moving joints.
- RealPerformanceSystem (Performance.swift:334): static queries; shadow policy reapplied only on generation change; stats published every 0.5 s.
- ImmersiveSceneView: `update:` only toggles HUD `isEnabled`; build runs in `.task(id:)`; viewer tracker and capture loop use `.task` (auto-cancelled); `stop()` on disappear.
- No `print` in per-frame paths; no force unwraps on entity lookups.

## Skipped RISKY

- GrabCue.swift:85 `MeshResource.generateSphere` per grabbable. Radius varies per object; a cache keyed by radius saves little and adds shared state. Report only.
- Articulation.swift:248-325 `findEntity(named: "joint:...")` per part on state change. Event-driven, not per frame; caching joint references changes entity ownership semantics. Report only.
- Performance.swift:379 RealStats writes 10 observed properties every 0.5 s even when unchanged; values change each window, so guarding writes yields no gain.
- MenuView.swift:20,74 unstructured `Task {}` on button actions: short one-shot open/dismiss calls; converting changes cancellation timing.

## Architecture notes

- Articulation: store joint entity references in `RealArticulationComponent` at build to drop recursive lookups on toggle.
- Instruments plan: RealityKit Trace on forest-glade and hospital scenes at `.balanced`; targets 90 fps, frame < 11 ms, zero steady-state allocations in the three systems.
