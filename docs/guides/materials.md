# Materials

A material is a `MaterialSpec`: a texture program plus colors, knobs and render flags. Specs live in
`Sources/RealMaterials/Library/<Family>.swift` and are looked up by key (`family.variant`). Textures are
generated once per key on the GPU and cached; the ShaderGraph material adds wind, translucency,
anti-tiling, triplanar projection, a world-up top layer and aerial fog.

## Adding a variant

```sh
swift run -q realityhd new material wood.walnut --like wood.oak
swift run -q realityhd textures wood.walnut --size 512        # out/tex/wood.walnut-albedo.png
```

Change colors and `seed` so the variant is distinct, then render an asset that uses it. Colors are
written as sRGB hex and converted with `linear(0xRRGGBB)`. Albedo of real materials sits between
about 0x303030 (dark asphalt) and 0xE0E0E0 (fresh snow); stay inside it.

## Spec fields

| Field | Meaning |
|---|---|
| `program` | `TextureProgram`, or `nil` for a scalar (untextured) material |
| `colorA/B/C` | program colors (linear RGBA), see the table below |
| `knobs` | program parameters `x y z w`, see the table below |
| `seed` | pattern seed; change it for every variant |
| `tileSize` | meters per texture repeat; `0` = atlas UVs (foliage) |
| `resolution` | 512, 1024 or 2048 before the quality preset scales it |
| `normalStrength` | height-to-normal gain |
| `mode` | `.opaque`, `.cutout` (alpha-tested, needs `twoSided`), `.emissive`, `.transparent` (alpha-blended, `opacity` plus Fresnel) |
| `hasMetallicMap` | program writes metalness (painted and rusted metal) |
| `roughness`, `metallic`, `baseColor`, `emissive`, `emissiveIntensity` | scalar values and fallbacks |
| `wind` | vertex sway in meters at weight 1 |
| `translucency` | back-lit transmission (leaves, grass) |
| `antiTile` | two-scale plus macro variation for large surfaces |
| `triplanar` | object-space projection (rock) |
| `topColor`, `topAmount`, `topLow` | world-up layer (moss, snow, dust) by normal.y |
| `splat`, `splatSoftness`, `splatHeight` | second material blended by per-vertex `Surface.splat` weights (`paintSplat`); `realityhd demo splat` |
| `flow` | transparent water: ripple normal scroll speed (tiles/s); `Surface.splat` = shallowness; `realityhd demo water` |

## Program parameters

| Program | colorA | colorB | colorC | knobs |
|---|---|---|---|---|
| `barkOak` | ridge | furrow | lichen | x lichen, y moss |
| `barkBirch` | white bark | lenticels, marks | warm inner bark | |
| `barkPine` | plate | crack | grey weathering | |
| `leafBroad` | dark leaf | light leaf | autumn tint | x lobed (0/1), y autumn amount, z atlas grid |
| `leafNeedle` | old needles | mid | fresh tips | x fresh growth, z atlas grid |
| `grassBlades` | base | tip | dry blades | x dry fraction, z atlas grid |
| `rockGranite` | base | speckle | lichen/iron | x lichen |
| `forestFloor` | soil | litter | moss | x moss, y litter amount |
| `woodPlank` | light wood | dark grain | | x weathering, y roughness |
| `paintedMetal` | paint | | rust (a = unused) | x chips and scratches, y dirt, z paint roughness |
| `rustMetal` | rust | dark scale | | x bare-metal amount |
| `concrete` | base | stains | | x roughness, y stains |
| `asphalt` | binder | aggregate | | x cracks |
| `plastic` | color | | | x scuffs, y dirt, z roughness |
| `brick` | brick | brick variation | mortar | |
| `water` | deep body color | shallow color (ShaderGraph) | | x chop |

Read the program in `Sources/RealMaterials/Shaders/` before relying on a knob; the table is a summary.

## Adding a texture program

1. Write `S myProgram(float2 uv, constant RFParams &P)` in the matching `<Family>Shaders.swift`, or in a
   new `<Family>Shaders.swift` added to `programSources` in `ShaderSource.swift`.
2. It must tile: use `gnoise`, `fbm`, `ridged`, `worley`, `cellLocal` and the hash helpers in `CommonShaders.swift` with a
   period that divides the texture (`int2(8, 8)`, `int2(16, 16)`). Never use `uv` in non-periodic math.
3. Fill every field of `S`: albedo, alpha (cutout only), height (normals come from it), rough, ao, metal.
4. Append `case myProgram` to `TextureProgram`. The case name is the Metal function name; dispatch is
   generated, and `MaterialTests` checks both sides.
5. Add at least one material that uses it (tests require every program to be used).
6. `swift run -q realityhd textures <key> --size 1024`: check tiling by viewing the PNG tiled 2x2,
   check the normal map for stair-stepping, check roughness range.

Texture V: row 0 is v = 0. Atlas content is drawn with v up the card.

## ShaderGraph options

`RealKit/ShaderGraph.swift` emits USDA from `RealShaderOptions` (12 flags; `shaders` loads every valid combination). After any
change, `swift run -q realityhd shaders` must report 0 failures, and `--pbr` renders must still work
(the `PhysicallyBasedMaterial` fallback).
