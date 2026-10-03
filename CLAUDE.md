# RealForge agent protocol

Procedural photoreal assets for RealityKit (visionOS 26). Apps depend on the package; new assets,
materials and scenes land here as code, tested and previewed before commit.

## Using it in an app

```swift
import RealKit; import RealLibrary
RealForge.setup(.balanced)                                   // once, App.init
let env = try RealForge.environment(.afternoon, skybox: true) // ImmersiveSpace: skybox true; mixed: false
let e = try await RealForge.entity("oak-tree", seed: 3)       // or .scene("forest-glade")
env.illuminate(e); content.add(env.root); content.add(e)
await RealViewerTracker.shared.start()                        // head-tracked LOD (ImmersiveSpace only)
```

Mixed reality: skip the skybox, keep `env` for IBL and sun shadows, or skip `env` entirely and let
the system lighting apply (fog uses `RealAtmosphere`; set `fogDensity = 0` indoors).

## Demo app (visionOS)

`Demo/` holds a visionOS app (xcodegen; `.xcodeproj` is gitignored). Menu window lists
forest-glade and park-path, sky and seed; each opens a full ImmersiveSpace with the scene's camera
hint at the viewer's feet. New scene in the demo: a case in `DemoScene` (`Demo/RealForgeDemo/DemoApp.swift`).

```sh
cd Demo && xcodegen generate && open RealForgeDemo.xcodeproj
# simulator: launch arg `-scene forest-glade` opens a scene without tapping
```

## Workflow for "add an asset / scene"

1. `swift run -q realforge list`, read `CATALOG.md`. Reuse assets and materials first.
2. New asset: a `RealAsset` struct in `Sources/RealLibrary/{Nature,Props}`. Register in `Catalog.assets`
   (or `Props.all`). New scene: a builder in `Scenes.swift`, registered in `SceneCatalog`.
3. New material: a case in `MaterialLibrary.builtIn` (+ key in `keys`). New look that needs a new
   pattern: a function in `Shaders.swift`, a `TextureProgram` case, a `case` in `evaluate()`.
4. `swift test`.
5. `swift run -q realforge render <id>` (or a scene id), then Read `out/<id>.png`. Check scale,
   grounding, material scale, orientation of atlases and grain. Fix and re-render.
6. `swift run -q realforge shaders` after any ShaderGraph change (loads all 256 variants).
7. `swift run -q realforge catalog`, then commit.

Visual check flags: `--az --el --dist` camera, `--sky morning|midday|afternoon|golden`, `--lod n`,
`--pbr` (PhysicallyBasedMaterial path), `--fog 0`, `--no-ground`, `--w --h`.

## Conventions

- Meters, +Y up, base at y = 0, centered on X/Z. Deterministic from `seed` (SeededRNG, `rng.fork`).
- UVs are meters; materials convert with `tileSize`. Atlased foliage (`tileSize = 0`) uses 0...1.
- Wood grain runs along U: build boards along +X with `plank()`/`board()`; lathes take `grainVertical`.
- Per-vertex channels: `extra.x` wind weight (0 anchored, 1 tip), `occlusion` baked AO
  (`bakeCavityAO`, `groundAO`). Both reach the shader through uv1.
- Budgets: test-enforced `budget` per asset (LOD0 tris). Trees ~20k, props under 10k.
- Texture V: row 0 = v 0 (RealityKit LowLevelTexture). Atlas content is drawn with v up the card.
- Never put `\.keypath` on `any RealAsset.Type` (Swift 6.3 SILGen crash); use closures.

## API cheat sheet

```swift
// Primitives (RealCore.Prim), all return Surface (one material)
Prim.roundedBox(size, radius:, bevelSegments:, material:)   Prim.lathe([V2(r, y)], segments:, seamTile:, material:, swapUV:)
Prim.tube(points, radii:, sides:, seamTile:, material:, weights:)   Prim.cubeSphere(subdivisions:, material:) { dir in point }
Prim.terrain(size:, segments:, material:) { xz in height }   Prim.card(width:, height:, cell:, material:, normal:)
plank(len, width, thick, material:)   board(from:, to:, width:, thick:, up:, material:)   turned([(r, y)], material:)
catmull(points, per:)   groundAO(&model)   surface.bakeCavityAO()

// Assembly
var m = Model(name:); m.add(surface, Xform(translation:, rotation: simd_quatf(degrees:, axis:), scale:))
LODModel(levels: [m0, m1, m2], switchDistances: [12, 35])   LODModel(m)
TreeGenerator(species: .oak, seed:).model(.lod0)   Tree(.spruce).build(seed:)   TreeSpecies.oak.with { $0.height = 8 }
Scatter.poisson(count:, outerRadius:, innerRadius:, minSpacing:, seed:) { accept }   Scatter.uniform(...)
place(x, z, yaw:, scale:) -> Xform

// RealityKit
model.modelEntityAsync()   lod.entityAsync()   RealInstancing.field(lod, transforms:, options:)
RealMaterialCache.shared.materialAsync(key)   .warm([keys])   .overrides[key] = spec
RealEnvironment(SunSky(elevation:, azimuth:, turbidity:), skybox:)   env.illuminate(entity)
RealWind.direction/.speed/.strength   RealAtmosphere.fogDensity/.fogColor   RealQuality.apply(.performance)
RealPreview(environment:).frame(entity); await preview.render(width:, height:)
```

## Asset template

```swift
public struct Thing: RealAsset {
    public static let id = "thing"
    public static let summary = "One sentence: what it is and how it's built."
    public static let tags = ["prop"]
    public static let budget = 6_000
    public var size: Float = 1
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        m.add(plank(size, 0.1, 0.02, material: "wood.oak"), Xform(translation: V3(0, 0.01, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
```
