# Cooking

RealityHD 6 adds food that can be cut and cooked at runtime, the kitchen it happens in, and the
heat model behind it. Everything ships as Swift; no meshes, textures or sounds are bundled.

## Food entities

```swift
let chicken = try await RealityHD.food("chicken-breast")   // cook-shader materials, convex collider, dynamic body
content.add(chicken)
let (a, b) = try await chicken.realSlice(SlicePlane(point: p, normal: n))!   // world-space plane, capped halves
```

Food assets conform to `RealFood`: every LOD0 surface is a closed shell, `capMaterial(for:)` names the
cut-face material per shell (nil for peels and skins), and `coreCenter` centers radial cut textures
(onion rings, carrot core, tomato locules). `FoodKind` (`Cook.Kind`) picks the heat profile.

`RealFoodComponent` keeps the CPU mesh, cap recipe and `FoodThermal` state on the entity. Cuts split
the heat state, so a half-cooked breast cut open shows a raw center on its cut faces.

## Heat model (RealCore, no RealityKit)

| Type | Models |
|---|---|
| `FoodThermal` | 1D slab through the piece's thinnest axis (9 nodes), six face states: surface water boiling off, Maillard browning and char per face, protein setting from peak temperature, starch softening from time held |
| `VesselThermal` | lumped pan mass by metal, fat layer with smoke point and shimmer, water that caps at 100 C and boils off, lid |
| `Burner` | knob level to absorbed watts (flame catch by pan size) |
| `OvenThermal` | first-order preheat with a setpoint |
| `HeatContact` | contact conductance for dry pan, oiled pan, boiling water, oven air |

Calibration is in `Tests/RealityHDTests/CookTests.swift`: cast iron reaches searing heat in about five
minutes on medium-high; a 2 cm chicken breast browns deep golden in about five minutes per side and
reaches 74 C core in about nine; forgotten on high it chars; carrot coins go tender in eight minutes
of boiling.

Apps run the model faster than real time by passing a larger `dt` (the step sub-divides for stability).

## Cook shader

`RealShaderOptions.cook` (`RealMaterialCache.cookMaterialAsync(key)`) blends a material to its
`MaterialSpec.cooked` texture set by `Doneness`, then layers browning and char per object-space face
direction from `BrownPos` / `BrownNeg` (x, y, z; 0 raw, 1 deep golden, 2 burnt) and an `Oil` sheen.
`entity.realApplyCook()` copies a `RealFoodComponent`'s state into those parameters.

## Vessel and blade conventions

`RealVessel` (`floorY`, `innerRadius`, `rimY`, `rimRadius`, `metal`): pans, pots, bowls, sheets, handles
along +X. `RealBlade` (`bladeLength`): lying on its side, blade face normal +Y, blade along +X, edge
toward -Z.

## Sound and particles

`RealCookAudio.resource(.sizzle | .boil | .burner | .chop | .ignite | .drop | .whisk)` synthesizes
spatial audio buffers on first use. `RealCookFX.steam / smoke / spatter(radius:)` return particle emitters.
`RealCook.fill(material:)` makes a liquid or batter surface for a vessel.
