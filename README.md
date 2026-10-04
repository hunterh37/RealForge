# RealityHD

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-visionOS%2026%20%7C%20macOS%2026%20%7C%20iOS%2026-0A84FF)](#requirements)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen)](#installation)
[![License: MIT](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

Procedural, photoreal trees, rocks, ground, props and scenes for RealityKit, generated from code at
load time. No mesh or texture files ship in your app: geometry is built on the CPU in milliseconds and
every PBR texture is synthesized on the GPU.

![RealityHDDemo running park-path in the Apple Vision Pro simulator](docs/demo/hero.png)

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Demo app](#demo-app)
- [Usage](#usage)
- [Gallery](#gallery)
- [Performance](#performance)
- [Command-line tool](#command-line-tool) (3.0 agent loop)
- [Interiors and articulated assets](#interiors-and-articulated-assets-40) (4.0)
- [Ballpark](#ballpark-41) (4.1)
- [Package structure](#package-structure)
- [Contributing](#contributing)
- [License](#license)

## Features

- 21 assets and 3 composed scenes: oak, birch, spruce, shrub, boulder, pebbles, terrain, grass, and
  12 street and park props. Every asset is parameterized and seeded.
- Trees with recursive branching, root flare, alpha-card foliage, crown-sphere normals, baked crown
  occlusion and three LODs built from one skeleton.
- 29 GPU-synthesized PBR materials (albedo, normal, roughness, AO, metallic), all tileable, with
  coverage-preserving alpha mips for foliage.
- ShaderGraph materials generated at runtime: vertex wind, leaf back-light translucency, aerial
  perspective fog, ground anti-tiling, triplanar rock projection, moss on upward faces.
- Physically based sky (Rayleigh, Mie, ozone) used for image-based lighting and the skybox, with a
  matching shadow-casting sun.
- `MeshInstancesComponent` instancing in spatial cells, distance LOD with hysteresis, head-tracked LOD
  on visionOS, quality presets.
- Offscreen PNG rendering through `RealityRenderer` for previews, thumbnails and automated checks.

## Requirements

| Platform | Minimum |
|---|---|
| visionOS | 26.0 |
| macOS | 26.0 |
| iOS | 26.0 |
| Xcode | 26.0 (Swift 6.2 tools) |

Metal is required for texture synthesis. ARKit world tracking (visionOS, ImmersiveSpace) is used only
for head-tracked LOD.

## Installation

### Xcode

File > Add Package Dependencies, enter the repository URL, and add the `RealityHD` product to your
app target.

```
https://github.com/hunterh37/RealityHD.git
```

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/hunterh37/RealityHD.git", branch: "main"),
],
targets: [
    .target(name: "MyApp", dependencies: [.product(name: "RealityHD", package: "RealityHD")]),
]
```

## Quick start

A full forest in an immersive space:

```swift
import SwiftUI
import RealityKit
import RealKit
import RealLibrary

@main
struct ForestApp: App {
    init() { RealityHD.setup(.balanced) }

    var body: some Scene {
        ImmersiveSpace(id: "forest") {
            RealityView { content in
                let env = try! RealityHD.environment(.afternoon, skybox: true)
                let forest = try! await RealityHD.scene("forest-glade")
                env.illuminate(forest)
                content.add(env.root)
                content.add(forest)
            }
            .task { await RealViewerTracker.shared.start() }
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
```

## Demo app

`Demo/` is a visionOS app that opens `forest-glade` and `park-path` as full ImmersiveSpaces. The menu
window picks the scene, sky (morning, midday, afternoon, golden hour) and seed. The scene's camera
hint is placed at the viewer's feet, and LOD follows head pose through `RealViewerTracker`.

<table>
  <tr>
    <td><img src="docs/demo/forest-glade.png" alt="forest-glade, afternoon"></td>
    <td><img src="docs/demo/forest-glade-golden.png" alt="forest-glade, golden hour"></td>
  </tr>
  <tr>
    <td><img src="docs/demo/park-path.png" alt="park-path, afternoon"></td>
    <td><img src="docs/demo/park-path-golden.png" alt="park-path, golden hour"></td>
  </tr>
</table>

Captured in the visionOS 26 simulator. The forest scene has 140 instanced trees, 7,000 grass clumps and
camp props (picnic table, crates on a pallet, barrels, drum) along the edge of the glade.

```sh
brew install xcodegen
cd Demo && xcodegen generate && open RealityHDDemo.xcodeproj
```

Launch arguments open a scene without input, for captures and checks:
`-scene forest-glade|park-path`, `-sky morning|midday|afternoon|golden`, `-seed n`, `-yaw deg`,
`-hideMenu YES`. `Scripts/frame.py` frames a simulator screenshot for this README.

## Usage

### Single assets

```swift
let oak = try await RealityHD.entity("oak-tree", seed: 4)
let hydrant = try await RealityHD.entity("fire-hydrant")
content.add(oak)
```

### Custom parameters

Assets are value types with stored parameters; edit them inline.

```swift
let drum  = try await RealityHD.entity(OilDrum().with { $0.color = 0x8C1F1F })
let birch = try await RealityHD.entity(Tree(.birch).with { $0.species.height = 9 }, seed: 2)
let rock  = try await RealityHD.entity(Boulder().with { $0.size = [3, 1.6, 2.4]; $0.facets = 12 })
```

### Instanced fields

One draw per cell per LOD, however many instances.

```swift
let spots = Scatter.poisson(count: 400, outerRadius: 60, minSpacing: 4, seed: 1)
let transforms = spots.map { place($0.x, $0.y, yaw: .random(in: 0...360)).matrix }
let forest = try await RealityHD.field(SpruceTree(), transforms: transforms)
```

### Lighting

```swift
let env = try RealityHD.environment(SunSky(elevation: 20, azimuth: 250, turbidity: 2.8), skybox: true)
env.illuminate(myContent)   // image-based light for every model under it
content.add(env.root)       // sun with cascaded shadows, IBL entity, optional skybox
```

Presets: `.morning`, `.midday`, `.afternoon`, `.goldenHour`. In mixed reality pass `skybox: false`, or
skip the environment and let system lighting apply (set `RealAtmosphere.fogDensity = 0` indoors).

### Wind, fog and quality

```swift
RealWind.direction = [1, 0, 0.3]; RealWind.strength = 1.5      // before materials are created
RealAtmosphere.fogDensity = 0.002
RealityHD.setup(.performance)                                  // 512 px textures
```

### Materials on your own meshes

```swift
var m = Model(name: "plinth")
m.add(Prim.roundedBox([1, 0.4, 1], radius: 0.03, material: "concrete.smooth"))
let entity = try await m.modelEntityAsync()
```

Material keys accept a hex tint: `"metal.painted:1F4E8C"`. All keys are listed in
[CATALOG.md](CATALOG.md).

## Gallery

### Scenes

| `forest-glade` | `park-path` |
|---|---|
| ![forest-glade](docs/scenes/forest-glade.png) | ![park-path](docs/scenes/park-path.png) |
| `park-path`, golden hour | `prop-yard` |
| ![park-path golden hour](docs/park-golden.png) | ![prop-yard](docs/scenes/prop-yard.png) |

### Nature

![Trees and rocks](docs/nature-gallery.png)

### Props

![Props](docs/props-gallery.png)

| | | | |
|---|---|---|---|
| ![wooden-crate](docs/assets/wooden-crate.png)<br>`wooden-crate` | ![barrel](docs/assets/barrel.png)<br>`barrel` | ![oil-drum](docs/assets/oil-drum.png)<br>`oil-drum` | ![park-bench](docs/assets/park-bench.png)<br>`park-bench` |
| ![picnic-table](docs/assets/picnic-table.png)<br>`picnic-table` | ![street-lamp](docs/assets/street-lamp.png)<br>`street-lamp` | ![traffic-cone](docs/assets/traffic-cone.png)<br>`traffic-cone` | ![fire-hydrant](docs/assets/fire-hydrant.png)<br>`fire-hydrant` |
| ![bollard](docs/assets/bollard.png)<br>`bollard` | ![pallet](docs/assets/pallet.png)<br>`pallet` | ![mailbox](docs/assets/mailbox.png)<br>`mailbox` | ![trash-can](docs/assets/trash-can.png)<br>`trash-can` |

### Photoreal props (3.0)

Built and signed off through the vision gate (`docs/V3.md`).

![RealityHD 3 props](docs/props-hd-gallery.png)

### Interiors and articulated assets (4.0)

Office scenes lit by the sun through real openings plus an indoor probe, with baked scene AO and
static batching. Doors, drawers, lids, chairs, lamps and screens have named states and animate live
(`docs/V4.md`, `docs/guides/articulation.md`).

![open-office in the Apple Vision Pro simulator](docs/demo/open-office-sim.png)
`open-office` in the RealityHDDemo app, Apple Vision Pro simulator (visionOS 26.4): tilted window live,
monitors showing the `screen.ui` display material, sun through the ribbon windows.

| | |
|---|---|
| ![open-office](docs/v4/open-office.png)<br>`open-office` | ![executive-office](docs/scenes/executive-office.png)<br>`executive-office` |
| ![office-lobby](docs/scenes/office-lobby.png)<br>`office-lobby` | ![conference-room](docs/scenes/conference-room.png)<br>`conference-room` |
| ![office-plaza](docs/scenes/office-plaza.png)<br>`office-plaza` | ![laptop on](docs/v4/laptop-on.png)<br>`laptop` state `on` |

Every state of every articulated asset, rendered through the live rig (`realityhd states`):

![office-door states](docs/states/office-door.png)
![office-window states](docs/states/office-window.png)
![elevator-doors states](docs/states/elevator-doors.png)
![glass-door states](docs/states/glass-door.png)
![filing-cabinet states](docs/states/filing-cabinet.png)
![desk-pedestal states](docs/states/desk-pedestal.png)
![storage-cabinet states](docs/states/storage-cabinet.png)
![executive-desk states](docs/states/executive-desk.png)
![office-chair states](docs/states/office-chair.png)
![laptop states](docs/states/laptop.png)
![desktop-monitor states](docs/states/desktop-monitor.png)
![hardcover-book states](docs/states/hardcover-book.png)
![banker-lamp states](docs/states/banker-lamp.png)
![pedal-bin states](docs/states/pedal-bin.png)
![ceiling-light states](docs/states/ceiling-light.png)

Static office props:

| | | | |
|---|---|---|---|
| ![office-desk](docs/assets/office-desk.png)<br>`office-desk` | ![bookshelf](docs/assets/bookshelf.png)<br>`bookshelf` | ![conference-table](docs/assets/conference-table.png)<br>`conference-table` | ![lobby-sofa](docs/assets/lobby-sofa.png)<br>`lobby-sofa` |
| ![reception-desk](docs/assets/reception-desk.png)<br>`reception-desk` | ![whiteboard](docs/assets/whiteboard.png)<br>`whiteboard` | ![water-cooler](docs/assets/water-cooler.png)<br>`water-cooler` | ![snake-plant](docs/assets/snake-plant.png)<br>`snake-plant` |
| ![keyboard-mouse](docs/assets/keyboard-mouse.png)<br>`keyboard-mouse` | ![coffee-mug](docs/assets/coffee-mug.png)<br>`coffee-mug` | ![paper-stack](docs/assets/paper-stack.png)<br>`paper-stack` | ![office-block](docs/assets/office-block.png)<br>`office-block` |

```swift
let cabinet = try await RealityHD.articulated("filing-cabinet")
cabinet.setArticulation("drawer2-open")          // eased animation
// tap a part to toggle it
.gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { $0.entity.realToggle() })
```

### Materials

Albedo channel of the GPU-generated texture sets.

![Material swatches](docs/materials/swatches.png)

### Ballpark (4.1)

A regulation baseball field built from code: 90 ft base paths, a 10 in mound with the rubber at
60 ft 6 in, a 95 ft infield arc, chalked boxes and foul lines, checkerboard-mowed turf, a red warning
track, padded walls, foul poles, a hooded backstop, block dugouts, aluminum bleachers and six light
towers. The `ballpark` camera, and the Demo app viewer, stand in the right-handed batter's box.

![ballpark from the batter's box](docs/scenes/ballpark.png)

| | |
|---|---|
| ![aerial](docs/v41/ballpark-aerial.png)<br>Aerial from behind first base | ![backstop](docs/v41/ballpark-backstop.png)<br>Home plate and the backstop from the infield |
| ![plate](docs/v41/ballpark-plate.png)<br>Batter's boxes, catcher's box, `home-plate` | ![first base](docs/v41/ballpark-first-base.png)<br>`base-bag` at first, runner's lane |
| ![mound](docs/v41/ballpark-mound-golden.png)<br>Mound at golden hour | ![stands](docs/v41/ballpark-stands.png)<br>Bleachers, backstop and dugout from foul ground |

Structures: `baseball-diamond`, `outfield-wall`, `foul-pole`, `backstop`, `dugout`, `bleachers`, `light-tower`.

![ballpark structures](docs/v41/ballpark-structures.png)

Props, gated and signed off: `home-plate`, `base-bag`, `baseball-bat`, `baseball`, `ball-bucket`, `batting-helmet`.

![ballpark props](docs/v41/ballpark-props.png)

New texture programs `turf` (mowing stripes or checkerboard), `infieldClay` (drag lines, conditioner
granules, cleat prints) and `chainLink` (woven cutout mesh with a distance veil).

## Performance

Release build on an M2 Pro (`swift run -c release realityhd bench`).

| Measure | Result |
|---|---|
| Oak / birch / spruce generation, 3 LODs | 12 / 17 / 13 ms |
| Prop generation | 0.2 to 2 ms |
| 1024² PBR texture set on the GPU | 7 to 20 ms |
| `forest-glade` build + upload | 0.3 s + 0.9 s, 7,555 instances in 422 instanced draws |
| `park-path` build + upload | 0.08 s + 0.16 s, 22,120 instances |
| Tree LOD0 / LOD1 / LOD2 | ~20k / ~8k / ~2.5k triangles |
| Texture memory, `.balanced` | ~11 MB per material |

Instancing by spatial cell, LOD every 0.2 s with hysteresis, no shadow casting for grass and LOD2,
foliage twigs implied by cards, shared per-key textures, RG8 normal maps and quality presets keep
scenes at frame rate on Vision Pro.

## Command-line tool

```sh
swift run -q realityhd list                      # assets and scenes
swift run -q realityhd stats oak-tree            # triangles per LOD, materials, generation time
swift run -q realityhd render park-bench         # out/park-bench.png via RealityRenderer
swift run -q realityhd render forest-glade --sky golden --w 1920 --h 1080
swift run -q realityhd thumbs --missing          # docs/assets/<id>.png, docs/scenes/<id>.png
swift run -q realityhd textures bark.oak         # dump albedo/normal/roughness PNGs
swift run -q realityhd shaders                   # load every ShaderGraph variant
swift run -q realityhd catalog                   # regenerate CATALOG.md
swift run -q realityhd new prop wheelbarrow --theme Construction   # scaffold + register
swift run -c release realityhd bench

# 3.0 agent loop
swift run -q realityhd context prop              # API, materials, props, loop in one print
swift run -q realityhd brief copper-kettle --theme Kitchen --name "Hammered copper kettle"
swift run -q realityhd new prop copper-kettle --brief briefs/copper-kettle.json
swift run -q realityhd lint copper-kettle        # budget, grounding, texel scale, size vs brief
swift run -q realityhd gate copper-kettle --ref photo.jpg    # sheet, compare, report, verdict template
swift run -q realityhd gate copper-kettle --verdict out/gate/copper-kettle/verdict.json --signoff
python3 Scripts/vision_judge.py copper-kettle    # headless verdict via the Claude API
```

Coding agents: `.claude/skills/realityhd-prop` runs the loop end to end; `realityhd-gate` holds the
rubric and scoring.

## Package structure

| Target | Contents |
|---|---|
| `RealCore` | Surfaces, models, LODs, primitives, tree generator, noise, scatter. No RealityKit. |
| `RealMaterials` | `MaterialSpec`, material library by family (`Library/`), Metal texture programs (`Shaders/`), sky. |
| `RealKit` | LowLevelMesh upload, material cache, ShaderGraph emitter, environment, LOD, instancing, preview. |
| `RealLibrary` | `RealAsset` and registries (`Core/`), building helpers, `Nature/`, `Props/<Theme>/`, `Structures/`, `Scenes/`, `RealityHD` entry points. |
| `realityhd` | Command-line tool. |

One asset per file. The full tree and conventions are in [AGENTS.md](AGENTS.md); design notes in
[DESIGN.md](DESIGN.md).

## Contributing

Assets, scenes and materials are welcome, one per pull request. Start with
[CONTRIBUTING.md](CONTRIBUTING.md), pick a theme pack from [docs/IDEAS.md](docs/IDEAS.md), and follow the
guides for [assets](docs/guides/assets.md), [scenes](docs/guides/scenes.md) and
[materials](docs/guides/materials.md).

```sh
swift run -q realityhd new prop wheelbarrow --theme Construction --author your-handle
# write build(seed:), then:
swift test && swift run -q realityhd render wheelbarrow
swift run -q realityhd thumbs wheelbarrow && swift run -q realityhd catalog
```

Coding agents read [AGENTS.md](AGENTS.md); IDEAS.md ends with prompts to paste into one.

## License

RealityHD is available under the MIT license. See [LICENSE](LICENSE).
