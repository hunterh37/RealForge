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

## RealityHD 3 craft programs

| program | colorA / B / C | knobs x y z w | keys |
|---|---|---|---|
| `leather` | dye / crease / rubbed | grain cells per tile, wear, roughness, creases | `leather.tan` `leather.oxblood` `leather.oxblood-worn` `leather.black` |
| `brushedMetal` | metal / smudge | streaks, roughness, smudges, scratches (grain along U) | `metal.aluminum-brushed` `metal.stainless` |
| `polishedMetal` | metal / tarnish / verdigris | tarnish, patina, dents per tile, roughness | `metal.brass` `metal.brass-aged` `metal.copper` `metal.copper-patina` |
| `ceramicGlaze` | glaze / thin glaze / speckle | speckle, runs, crackle, roughness (runs along V) | `ceramic.stoneware` `ceramic.cobalt` `ceramic.celadon` `ceramic.bisque` |
| `caneWeave` | cane / shadow | cells per tile, strand width, roughness, aging (cutout) | `cane.woven` |

Feature size = tileSize / count: leather pebbles 1.5-3 mm, hammer dents 10-15 mm, cane holes 8-12 mm.

## RealityHD 4 office programs

Source: `Shaders/OfficeShaders.swift`; specs: `Library/Office.swift`.

| program | colorA / B / C | knobs x y z w | keys |
|---|---|---|---|
| `carpetTile` | yarn / second yarn (a share) / fleck (a share) | rows per 50 cm tile, pattern, roughness, wear. 2 x 2 quarter-turn tiles per repeat with seams | `carpet.tile` |
| `carpetPile` | pile / heather (a share) / border | tufts per tile, pile shading, roughness, border width (tile fraction; map one tile over the rug) | `carpet.rug` |
| `acousticTile` | face / fissure shadow | fissures, pinholes, roughness, aging | `ceiling.acoustic` |
| `paintedWall` | paint | stipple, roller laps, roughness | `paint.wall` |
| `woodVeneer` | earlywood / latewood / pores (a ray flecks) | ring density, cathedral arches per tile, pores, book-matched leaves per tile (even). Grain along U | `wood.veneer-oak` `wood.veneer-walnut` |
| `screenUI` | wallpaper deep / light / glow | ribbon glow, dim. Atlas: UV 0...1 across a 16:10 screen, v up; emissive | `screen.ui` |
| `pageEdge` | paper / gap shadow / dirt | sheets per V tile, dirt, waviness, signature gaps. Lines along U | `paper.pages` |
| `marble` | ground / vein / cloud (a amount) | vein frequency, warp, vein width, roughness | `stone.marble` `stone.marble-dark` |
| `terrazzo` | matrix / chip / chip 2 (a share) | large chips per tile, coverage, roughness, white-chip share | `stone.terrazzo` |
| `pavers` | concrete / stain / joint sand | slabs per tile, tone variation, weathering, joint width (slab fraction) | `paving.slab` |
| `sansevieria` | leaf / cross bands / margin | bands per leaf, zigzag, roughness, margin width. u 0...1 across the leaf, v base to tip | `leaf.sansevieria` |
| `laminate` | color | emboss, paper flocs, roughness, speckle | `laminate.white` `paper.sheet` |
| `chairMesh` | monofilament / weft / gap | strands per tile, openness, roughness, weft picks per strand (opaque) | `fabric.mesh` |
| `pottingSoil` | peat / bark / perlite | perlite, bark, moisture, crumbs per tile | `soil.potting` |

`screen.ui` uses tileSize 1 (one image per UV unit; tests require tileSize > 0). `paving.slab` keeps
`antiTile` off: the second sample would misalign the joints. Feature sizes: carpet loops ~4 mm,
pavers 60 cm with 6 mm joints, terrazzo chips 5-20 mm, veneer leaves 15 cm.
