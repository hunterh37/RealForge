# Composing a scene

A scene is a `RealSceneBuilder`: metadata plus `build(seed:) -> RealScene`. A `RealScene` holds
single entities (`singles`), GPU-instanced fields (`fields`) and a camera hint. `scene.entity()` uploads
it; the demo app and `realityhd render` use the camera hint.

```sh
swift run -q realityhd new scene harbor-dock --author your-handle
```

## Structure

```swift
public struct HarborDock: RealSceneBuilder {
    public static let id = "harbor-dock"
    public static let summary = "Timber pier on pilings with crates, rope coils, mooring bollards and a moored skiff."
    public static let tags = ["harbor", "outdoor"]
    public static let author = "your-handle"

    public var pierLength: Float = 24
    public init() {}

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed &+ 99)
        let ground = GroundPatch().with { $0.size = 80; $0.relief = 0.2; $0.material = "ground.meadow" }
        scene.add(ground, seed: seed)
        func y(_ p: V2) -> Float { ground.height(x: p.x, z: p.y, seed: seed) }

        scene.add(WoodenCrate(), at: place(1.2, -3, y: y(V2(1.2, -3)), yaw: 12), seed: seed &+ 1)
        // ...
        scene.camera = .init(eye: V3(0, 1.7, 8), target: V3(0, 1, -10), fov: 60)
        return scene
    }
}
```

## Rules

- Singles for hero objects (a handful to a few dozen). Fields for anything repeated: one
  `scene.field(asset, seed:, transforms:, options:)` per asset variant. A forest is 9 fields
  (3 species x 3 seeds), not 140 entities.
- `options: .trees` (18 m cells) for trees and large plants; `.groundCover(cull: 30)` for grass and
  small scatter (8 m cells, culled, no shadows).
- Place on the terrain: sample `ground.height(x:z:seed:)`; sink trees 0.1 m and grass 0.02 m.
- Give every placement its own seed offset (`seed &+ n`) so identical assets differ.
- Poisson scatter (`Scatter.poisson`) for things that shouldn't overlap; `Scatter.uniform` with an
  accept closure for density masks (paths, clearings).
- Camera at standing height (1.6 to 1.7 m above the ground at the eye), looking at the composition.
  The demo app puts the viewer's feet at the eye position.
- `scene.farGround` (default `ground.meadow`) extends the ground to the horizon; set it to a material
  that matches the scene edge, or `nil` for enclosed scenes.
- Keep `worstCaseTriangles` reasonable. `realityhd bench` prints it per scene. Vision Pro holds
  frame rate with LOD and culling doing their job; check that distant fields actually reach LOD2.

## Checking it

```sh
swift test --filter SceneTests
swift run -q realityhd render harbor-dock                       # camera hint
swift run -q realityhd render harbor-dock --eye 4,1.7,2 --at 0,1,-8 --sky golden
swift run -q realityhd thumbs harbor-dock && swift run -q realityhd catalog
```

Then add a case to `DemoScene` in `Demo/RealityHDDemo/DemoApp.swift` and walk it on device or in the
simulator (`-scene harbor-dock`).
