# RealForge

![Forest glade](docs/forest-glade.png)

Procedural, photoreal asset and scene package for RealityKit on visionOS 26 (also macOS/iOS 26).
Every tree, rock, prop and texture is generated from code at load time: zero bytes of meshes or
textures in your app bundle. Built so a coding agent can drop a realistic outdoor scene into a
prototype in a few lines and keep frame rate on Vision Pro.

![Park path](docs/park-path.png)

```swift
// Package.swift
.package(url: "https://github.com/hunterh37/RealForge.git", branch: "main")
// target dependency: .product(name: "RealForge", package: "RealForge")

import RealityKit
import RealKit
import RealLibrary

// App.init
RealForge.setup(.balanced)

// ImmersiveSpace
RealityView { content in
    let env = try! RealForge.environment(.afternoon, skybox: true)
    let forest = try! await RealForge.scene("forest-glade")
    env.illuminate(forest)
    content.add(env.root)
    content.add(forest)
}
.task { await RealViewerTracker.shared.start() }   // head-tracked LOD
```

Single assets and custom parameters:

```swift
let oak = try await RealForge.entity("oak-tree", seed: 4)
let drum = try await RealForge.entity(OilDrum().with { $0.color = 0x8C1F1F })
let birch = try await RealForge.entity(Tree(.birch).with { $0.species.height = 9 })

// 3,000 instanced rocks, one draw per cell per LOD
let rocks = try await RealForge.field(Boulder(), transforms: myMatrices)
```

## What is in it

Geometry (RealCore, no RealityKit dependency): smooth-shaded, UV'd, tangent-space meshes. Weber-Penn
style trees with parallel-transport branch tubes, root flare, alpha-card foliage with crown-sphere
normals and baked crown occlusion, wind weights per vertex, three LODs from one skeleton. Cube-sphere
boulders with ridged displacement, fracture facets and cavity AO. Beveled boxes, lathes and tubes for
props. Poisson scatter for scenes.

Textures (RealMaterials): a runtime-compiled Metal compute library synthesizes tileable PBR sets
(albedo, RG8 normal, roughness, AO, metallic) for 29 materials: oak/birch/pine bark, oak/maple/birch
leaves, spruce needle sprays, grass blades, granite, sandstone, forest floor with leaf litter, meadow,
oak/pine/weathered planks, painted and rusted metal, concrete, asphalt, brick, plastics. Alpha mips
keep foliage coverage at distance (GPU coverage search per mip). 1024² set in 7 to 20 ms.

Rendering (RealKit): LowLevelMesh upload (no CPU MeshResource processing), ShaderGraph materials
emitted as USDA at runtime with vertex wind, leaf back-light translucency, aerial-perspective fog,
anti-tiling for large ground surfaces, triplanar rocks and world-up moss. A ray-marched Rayleigh/Mie
sky (with ozone) renders the IBL environment and the skybox; a cascaded-shadow sun matches it.
`MeshInstancesComponent` cells for forests and grass, distance LOD with hysteresis and culling.

Catalog: 4 tree species, boulder, pebbles, terrain patch, grass, 12 props (crate, barrel, oil drum,
park bench, picnic table, street lamp, traffic cone, fire hydrant, bollard, pallet, mailbox, trash
can) and 3 scenes. Full list in [CATALOG.md](CATALOG.md).

![Prop yard](docs/prop-yard.png)

## Performance

Release build, M2 Pro, `swift run -c release realforge bench`:

| | |
|---|---|
| Oak / birch / spruce generation (3 LODs) | 12 / 17 / 13 ms |
| Props generation | 0.2 to 2 ms |
| 1024² PBR texture set (GPU) | 7 to 20 ms |
| forest-glade build + upload, cold | 0.3 s + 0.9 s, 7,555 instances in 422 instanced draws |
| park-path build + upload, cold | 0.08 s + 0.16 s, 22,120 instances |
| Tree LOD0 / LOD1 / LOD2 tris | ~20k / ~8k / ~2.5k |
| Texture memory, balanced preset | ~11 MB per material at 1024² |

Defaults that keep Vision Pro at frame rate: instancing by spatial cell, LOD switching every 0.2 s
with 8% hysteresis, LOD2 and grass excluded from shadow casting, foliage twigs implied by cards
instead of meshed, textures shared process-wide per material key, RG8 normals, presets
(`.performance` halves texture size).

## Agent workflow

[CLAUDE.md](CLAUDE.md) holds the full API surface and the verification loop:
`swift run -q realforge render <id>` writes a PNG through RealityRenderer that an agent reads before
committing. `swift test` checks determinism, budgets, grounding, winding and material keys.

Design notes: [DESIGN.md](DESIGN.md). MIT license.
