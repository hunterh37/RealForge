# RealityHD agent protocol

Procedural photoreal assets for RealityKit (visionOS 26). Apps depend on the package; new assets,
materials and scenes land here as Swift code, tested and rendered before commit. No mesh, texture or
image files ship under `Sources/`.

Read in this order: this file, `CATALOG.md` (what exists), `docs/IDEAS.md` (what to build next), then
the guide for the task: `docs/guides/assets.md`, `docs/guides/scenes.md`, `docs/guides/materials.md`.

## Using it in an app

```swift
import RealKit; import RealLibrary
RealityHD.setup(.balanced)                                   // once, App.init
let env = try RealityHD.environment(.afternoon, skybox: true) // ImmersiveSpace: skybox true; mixed: false
let e = try await RealityHD.entity("oak-tree", seed: 3)       // or .scene("forest-glade")
let d = try await RealityHD.articulated("office-door")        // live parts: d.setArticulation("open")
env.illuminate(e); content.add(env.root); content.add(e)
await RealViewerTracker.shared.start()                        // head-tracked LOD (ImmersiveSpace only)
```

Interior scenes: `RealityHD.environment(for: scene)` applies the scene's sky, indoor probe and fog.
Tap gesture for articulated parts: `SpatialTapGesture().targetedToAnyEntity().onEnded { $0.entity.realToggle() }`.

Mixed reality: skip the skybox, keep `env` for IBL and sun shadows, or skip `env` entirely and let
the system lighting apply (fog uses `RealAtmosphere`; set `fogDensity = 0` indoors).

## Source layout

```
Sources/
  RealCore/        geometry: Surface, Model, LODModel, Prim, TreeGenerator, Noise, Scatter, Rig, AOBake/BVH (no RealityKit)
  RealMaterials/
    MaterialSpec.swift          MaterialSpec, TextureProgram, MaterialLibrary.all
    Library/<Family>.swift      material specs by family (bark, wood, metal, ...)
    Shaders/<Family>Shaders.swift  Metal texture programs; ShaderSource.swift assembles them
    TextureSynth.swift          GPU synthesis
  RealKit/         RealityKit bridge: mesh upload, material cache, ShaderGraph, sky + InteriorLight, LOD, instancing,
                   articulation runtime, preview
  RealLibrary/
    Core/          RealAsset, AssetTag vocabulary, Catalog, RealityHD facade
    Building/      plank, board, turned, groundAO, jittered, catmull, cuboid, Room (public helpers)
    Nature/<Group>/<Type>.swift      registry: Nature/Nature.swift
    Props/<Theme>/<Type>.swift       registry: Props/Props.swift
    Structures/<Theme>/<Type>.swift  registry: Structures/Structures.swift
    Scenes/<Type>.swift              registry: Scenes/SceneCatalog.swift
  realityhd/       CLI: list, stats, render, thumbs, textures, shaders, catalog, new, bench,
                   context, brief, lint, sheet, gate (Gate.swift, Imaging.swift, Agent.swift)
briefs/<id>.json, briefs/signoff/<id>.json   prop briefs and gate sign-offs (tests check both)
.claude/skills/  realityhd-prop, realityhd-brief, realityhd-gate, realityhd-material
Scripts/vision_judge.py   headless vision verdict via the Claude API
Tests/RealityHDTests/  AssetContractTests, SceneTests, MaterialTests, CoreTests
docs/assets/<id>.png, docs/scenes/<id>.png   thumbnails (tests require them)
Demo/              visionOS demo app (xcodegen)
```

One asset per file, file named after the type. Registries end in a `// realityhd:<marker>` line that
`realityhd new` inserts above.

## Workflow: add an asset

Props: use the `realityhd-prop` skill (`.claude/skills/realityhd-prop/SKILL.md`). Short form:

1. `swift run -q realityhd context prop` (API, materials, props by theme, loop). Reuse helpers and materials.
2. `swift run -q realityhd brief <id> --theme <Folder> --name "..."`, fill `briefs/<id>.json` (real size, parts, materials).
3. `swift run -q realityhd new prop <id> --brief briefs/<id>.json` (`nature` or `structure` without a brief:
   `realityhd new nature <id> --theme <Folder>`).
4. Write `build(seed:)`. Real dimensions in meters; expose dimensions, colors and material keys as `var`s.
5. `swift run -q realityhd lint <id>`, then `swift run -q realityhd gate <id> [--ref photo.jpg]`. Read
   `out/gate/<id>/sheet.png`, write `out/gate/<id>/verdict.json` (rubric in `realityhd-gate`), rerun with
   `--verdict out/gate/<id>/verdict.json`. Iterate on the fixes until it passes, then add `--signoff`.
6. `swift run -q realityhd thumbs <id>`, `swift run -q realityhd catalog`, `swift test`. Commit sources, brief,
   sign-off, thumbnail, CATALOG.md.

## Workflow: add an articulated asset

Guide: `docs/guides/articulation.md`. Conform to `RealArticulated`, implement `rig(seed:)` (geometry in
asset space at rest, parts with pivots and joints, states; `build(seed:)` is provided). Tag `articulated`.
Check every state with `swift run -q realityhd states <id>` (live rig) and `swift test --filter ArticulationTests`.

## Workflow: add a scene

1. `swift run -q realityhd new scene <id> --author <handle>`.
2. Compose with `scene.add(asset, at:, seed:)` for heroes and `scene.field(asset, seed:, transforms:, options: .trees)`
   for anything repeated. Set `scene.camera`.
   Interiors: `Room(size:)` with openings for doors and windows, `scene.add(room.shell(), bake: true)`,
   `scene.add(room.ceilingModel())`, `scene.lighting = .init(sky:, interior: .office, fog: 0)`,
   `scene.bake = .interior`, `scene.batchStatics = true`. Live parts: `scene.addLive(asset, ..., state:)`;
   baked: `scene.add(asset, ..., state:)` or `scene.field(asset, seed:, state:, transforms:)`.
3. `swift test`, `swift run -q realityhd render <id>`, Read the PNG, iterate. Scenes with a bake render
   in seconds with `swift build -c release` and `.build/release/realityhd render <id>` (debug is ~40x slower).
4. `swift run -q realityhd thumbs <id>`, `swift run -q realityhd catalog`. Demo app: add a case to `DemoScene`
   in `Demo/RealityHDDemo/DemoApp.swift`.

## Workflow: add a material

1. Existing program, new look: `swift run -q realityhd new material <family.variant> --like <key>` (or
   `--program <TextureProgram>`). Tune colors and knobs (table in `docs/guides/materials.md`).
2. `swift run -q realityhd textures <key> --size 512`, Read `out/tex/<key>-albedo.png`, then render an asset using it.
3. New pattern: a function in `Shaders/<Family>Shaders.swift` plus `case name` at the end of `TextureProgram`.
   The case name is the Metal function name; dispatch is generated.
4. ShaderGraph change (RealKit/ShaderGraph.swift): `swift run -q realityhd shaders` loads all 256 variants.

Visual check flags: `--az --el --dist` camera, `--sky morning|midday|afternoon|golden`, `--lod n`,
`--pbr` (PhysicallyBasedMaterial path), `--fog 0`, `--no-ground`, `--w --h`, `--seed n`.
Per-asset defaults: `static let preview = PreviewHint(...)`.

## Conventions

- Meters, +Y up, base at y = 0, centered on X/Z. Deterministic from `seed` (SeededRNG, `rng.fork`).
- `tags[0]` is the kind (`nature`, `prop`, `structure`); all tags come from `AssetTag.vocabulary`.
- UVs are meters; materials convert with `tileSize`. Atlased foliage (`tileSize = 0`) uses 0...1.
- Wood grain runs along U: build boards along +X with `plank()`/`board()`; lathes take `grainVertical`.
- Per-vertex channels: `extra.x` wind weight (0 anchored, 1 tip), `occlusion` baked AO
  (`bakeCavityAO`, `groundAO`). Both reach the shader through uv1.
- Budgets: test-enforced `budget` per asset (LOD0 tris). Caps: props 15k, structures 30k, nature 60k.
  Trees ~20k, typical props under 10k.
- Texture V: row 0 = v 0 (RealityKit LowLevelTexture). Atlas content is drawn with v up the card.
- Material keys are `family.variant`; a `:RRGGBB` suffix tints `colorA`.
- Never put `\.keypath` on `any RealAsset.Type` (Swift 6.3 SILGen crash); use closures.
- Ids are permanent once merged. Asset and scene ids share one namespace.

## API cheat sheet

Full live listing: `swift run -q realityhd context api`.

```swift
// RealityHD 3 geometry kit
Prim.extrude(Shape2D.roundedRect(w, h, radius:), depth:, bevel:, material:)   Prim.sweep(profile2D, along: path, up:, grainAlongPath:, material:)
Prim.loft([Prim.ring(outline2D, y:)], capStart:, capEnd:, material:)   Prim.superellipsoid(size, exponent:, material:)
Prim.torus(major:, minor:, arc:, material:)   Prim.helix(radius:, pitch:, turns:, wire:, material:)   Prim.cylinder(radius:, height:, bevel:, material:)
rivet / rivetRow / hexBolt / stitches / barHandle / chain / caster / tuftedPanel / buttons   surface.deform { }  surface.displace { }

// Primitives (RealCore.Prim), all return Surface (one material)
Prim.roundedBox(size, radius:, bevelSegments:, material:)   Prim.lathe([V2(r, y)], segments:, seamTile:, material:, swapUV:)
Prim.tube(points, radii:, sides:, seamTile:, material:, weights:)   Prim.cubeSphere(subdivisions:, material:) { dir in point }
Prim.terrain(size:, segments:, material:) { xz in height }   Prim.card(width:, height:, cell:, material:, normal:)

// Building helpers (RealLibrary/Building)
plank(len, width, thick, material:)   board(from:, to:, width:, thick:, up:, material:)   turned([(r, y)], material:)
catmull(points, per:)   groundAO(&model)   surface.bakeCavityAO()   xform.jittered(&rng)

// Assembly
var m = Model(name:); m.add(surface, Xform(translation:, rotation: simd_quatf(degrees:, axis:), scale:))
LODModel(levels: [m0, m1, m2], switchDistances: [12, 35])   LODModel(m)
TreeGenerator(species: .oak, seed:).model(.lod0)   Tree(.spruce).build(seed:)   TreeSpecies.oak.with { $0.height = 8 }
Scatter.poisson(count:, outerRadius:, innerRadius:, minSpacing:, seed:) { accept }   Scatter.uniform(...)
place(x, z, y:, yaw:, scale:) -> Xform

// Scenes
var scene = RealScene(name: Self.id)
scene.add(asset, at: place(...), seed:)   scene.add(model)   scene.field(asset, seed:, transforms:, options: .trees)
RealInstancing.Options.trees   .groundCover(cull: 30)   scene.camera = .init(eye:, target:, fov:)

// Articulation (RealityHD 4)
var rig = Rig(name:, lods:, switchDistances:)   rig.base[l].add(s, x)   rig.part("lid", parent:, pivot:, joint: .hinge(axis:, -95...0) | .slide(axis:, 0...0.4), options:)
rig.add(s, x, to: "lid", option:, lods:)   Joint(.revolute, axis:, range:, mimic: .init("pedal", ratio: 6))   RigState("open", ["lid": -95], options: ["bulb": 1])
RigLight(name:, kind: .spot(inner:, outer:), part:, option:, position:, direction:, intensity:)   rig.posed("open")   rig.validate()
entity.setArticulation("open")   entity.setJoints(["lid": -40])   entity.nextArticulation()   entity.realToggle()
Room(size:).with { $0.openings = [.init(.south, offset:, width:, sill:, head:)] }   room.shell()   room.ceilingModel()   room.fixturePattern(every:)

// RealityKit
model.modelEntityAsync()   lod.entityAsync()   RealInstancing.field(lod, transforms:, options:)
RealMaterialCache.shared.materialAsync(key)   .warm([keys])   .overrides[key] = spec
RealEnvironment(SunSky(elevation:, azimuth:, turbidity:), skybox:)   env.illuminate(entity)
RealWind.direction/.speed/.strength   RealAtmosphere.fogDensity/.fogColor   RealQuality.apply(.performance)
RealPreview(environment:).frame(entity); await preview.render(width:, height:)
```

## Demo app (visionOS)

`Demo/` holds a visionOS app (xcodegen; `.xcodeproj` is gitignored). The menu window lists scenes, sky
and seed; each opens a full ImmersiveSpace with the scene's camera hint at the viewer's feet.

```sh
cd Demo && xcodegen generate && open RealityHDDemo.xcodeproj
# simulator: launch args -scene forest-glade -sky golden -seed 2 -yaw -30 -hideMenu YES
```
