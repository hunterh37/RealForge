# Performance

`RealPerformance` (RealKit/Performance.swift) holds every render setting the package exposes. One value is
active process-wide; apps set it once and may change it at any time.

```swift
RealityHD.setup(.performance)                        // tier; adaptive governor on for battery/performance
RealityHD.setup(.ultra, adaptive: true)
RealityHD.setup(restoring: RealPerformance.defaultsKey, fallback: .balanced)   // saved settings
RealityHD.performance.lodBias = 0.8                  // live edit
RealityHD.performance.save()                         // UserDefaults JSON
RealityHD.stats.summary                              // "88 fps 11.3 ms (max 14.0)  412k tris  210 draws ..."
```

## Tiers

| Tier | Textures | LOD bias | Draw dist | Grass | Shadows | Shading cuts | Batching | Adaptive |
|---|---|---|---|---|---|---|---|---|
| battery | 0.5x, 512 max | 0.55 | 140 m | 50%, thin 60% far | LOD0, >0.5 m, 0.3x dist | wind, translucency, anti-tile, splat, variation, flow | all | on |
| performance | 0.5x, 1024 max | 0.75 | 260 m | 75%, thin 40% far | LOD0, >0.25 m, 0.5x dist | translucency, anti-tile | all | on |
| balanced | 1x, 1024 | 1 | unlimited | 100% | LOD0-1 | none | interiors | off |
| ultra | 1x, 2048 | 1.35 | unlimited | 100% | LOD0-2, 1.5x dist | none | interiors | off |
| cinematic | 2x, 4096 | 2 | unlimited | 100% | LOD0-3, 2x dist | none | interiors | off |

`balanced` reproduces RealityHD 5 output exactly; renders, thumbnails and tests use it.

## Live and build-time settings

Live (next LOD tick, 0.1 to 0.25 s): `lodBias`, `drawDistance`, `detailCullDistance`/`detailSize`,
`groundCoverDistance`, `shadows`, `shadowDistanceScale`, `shadowCasterMaxLOD`, `minShadowCasterSize`, `adaptive`.

Build-time (entities built after the change): textures, the eight shading switches, `fieldDensity`,
`distantThinning`, `forceBatching`, `maxSceneLights`, `skyboxScale`. `settings.needsRebuild(from: builtWith)`
says when a loaded scene should be rebuilt. Texture changes purge the material cache; shading changes drop
compiled materials and keep textures.

## Mechanisms

- LOD: `RealLODSystem` divides viewer distance by `lodBias x adaptiveScale` before comparing with each asset's
  switch distances. Hysteresis runs on the scaled distance.
- Culling: `RealPerformance.hidden` combines the entity's own cull distance (ground cover scales with
  `groundCoverDistance`), `drawDistance`, and `detailCullDistance` for objects whose bounds diagonal is under
  `detailSize`. Every scene static has a LOD root, single-level assets included, so all three reach it.
- Ground cover (`RealInstancing.Options.thinnable`, set by `.groundCover`): `fieldDensity` drops instances by
  position hash at build; `distantThinning` drops a further share at coarse LODs and scales survivors in XZ by
  `1/sqrt(keep)` (max 1.6) so coverage holds. Deterministic per position.
- Shadows: every mesh entity carries `RealRenderCostComponent` (triangles, draws, instances, size, LOD, author
  eligibility). `RealPerformance.castsShadow` decides; `RealPerformanceSystem` re-applies on change and LOD
  switches apply it when a level turns on. The sun carries `RealSunComponent`; its cascade distance follows
  `shadowDistanceScale x adaptiveScale`.
- Shading: switches feed `RealShaderOptions`, so each off switch compiles a smaller ShaderGraph variant
  (no vertex wind, no subsurface term, one texture fetch instead of three for anti-tiling, and so on).
- Batching: `forceBatching` merges statics per cell for every scene. Objects under `detailSize` batch apart so
  detail culling and the shadow size rule still apply to them.
- Lights: scene lights beyond `maxSceneLights` are dropped, dimmest first.
- Adaptive governor: `RealPerformanceSystem` keeps an EMA of frame time. Over 112% of the `targetFPS` budget
  for 0.75 s steps `adaptiveScale` down by 12% (floor `minAdaptiveScale`); at budget for 4 s (6 s after a drop)
  steps it up 8%. The scale multiplies LOD bias, draw and detail distances, ground cover range and shadow distance.

## Measuring

- Device: `RealityHD.stats` (fps, frame ms, worst frame, triangles, draws, instances, casters, LOD switches/s,
  adaptive scale, texture MB), refreshed every 0.5 s. Triangle counts are pre-frustum.
- Offline: `swift build -c release && .build/release/realityhd perf [scene...]` prints triangles, shadow
  triangles, draws and instances at each scene's camera for every tier, plus a weight relative to balanced.
  `RealScene.estimate(viewer:settings:)` is the same computation in code.
- Any CLI command takes `--tier` (`realityhd render forest-glade --tier battery`).

## Demo app

Menu > Performance: tier picker, adaptive switch, stats overlay (head-locked, inside the immersive space),
live stats, every setting grouped by live and rebuild, and a reload button when build-time settings changed.
Settings persist in UserDefaults. Launch args: `-tier performance -adaptive YES -hud YES`.
