---
name: realityhd-material
description: Add or tune a RealityHD material - a variant of an existing texture program (colors, knobs, tile size, wear) or a new Metal texture program - and verify it with texture swatches and a render. Use when a prop needs a material that is not in `realityhd context materials`, or when the vision gate scores materials or wear below 8. Triggers on "new material", "texture looks wrong", "make the leather/metal/wood more real", "/realityhd-material".
---

# RealityHD material

## Variant (most cases)

```sh
swift run -q realityhd context materials leather     # family listing
swift run -q realityhd new material leather.saddle --like leather.tan
swift run -q realityhd textures leather.saddle --size 512   # Read out/tex/leather.saddle-albedo.png
```

Knob tables: `docs/guides/materials.md`. RealityHD 3 programs:

| program | colorA / B / C | knobs x y z w |
|---|---|---|
| `leather` | dye / crease dark / rubbed highlight | grain cells per tile, wear, roughness, creases |
| `brushedMetal` | metal / smudge | streak strength, roughness, smudges, scratches |
| `polishedMetal` | metal / tarnish / verdigris | tarnish, patina, hammer dimples per tile (0 smooth), roughness |
| `ceramicGlaze` | glaze / thin glaze / speckle | speckle, runs and variation, crackle, roughness |
| `caneWeave` | cane / shadow | cells per tile, strand width, roughness, aging (cutout, two-sided) |

Scale check: real feature size = tileSize / count. Leather pebble 1.5-3 mm, hammer dents 10-15 mm,
cane holes 8-12 mm, willow weave 8-10 mm. Wrong scale is the most common materials failure.

Wear belongs in a separate worn variant applied to the parts that get handled (seat cushion, arm
tops, handle ends); a single key cannot localize wear.

## New program

1. Function `S name(float2 uv, constant RFParams &P)` in `Sources/RealMaterials/Shaders/<Family>Shaders.swift`
   (RealityHD 3 craft programs: `CraftShaders.swift`). Use only the periodic helpers (`fbm`,
   `worley`, `cellLocal`, `gnoise` with integer frequencies) so it tiles.
2. `case name` appended to the end of `TextureProgram` in `MaterialSpec.swift`.
3. Specs in `Library/<Family>.swift`; a new family array is appended to `MaterialLibrary.all`.
4. `swift run -q realityhd textures <key> --size 512`, Read the albedo, render a prop that uses it,
   `swift test --filter MaterialTests` (every program must be used by a key).
