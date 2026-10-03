# Ideas and theme packs

Work is grouped into theme packs: a set of assets, the materials they need, and a scene that shows
them together. A pack can be built by several people; each asset is its own PR. Claim an asset by
opening an issue from the asset template (title `[pack] id`) before starting.

Ids below are proposals. Check `CATALOG.md` first; something may already exist under another name.
Budgets are LOD0 triangle targets. Material keys in *italics* do not exist yet.

## Packs

| Pack | Folder | Scene | Needs new programs |
|---|---|---|---|
| [Construction site](#construction-site) | `Props/Construction`, `Structures/Construction` | `construction-lot` | `fabricWeave`, `plywood` |
| [Harbor](#harbor) | `Props/Harbor`, `Structures/Harbor` | `harbor-dock` | `rope`, water (engine) |
| [Campsite](#campsite) | `Props/Camp` | `lakeside-camp` | `fabricWeave`, `charcoal` |
| [Farm](#farm) | `Props/Farm`, `Structures/Farm` | `farmyard` | `straw`, `paintedWood` |
| [Kitchen](#kitchen) | `Props/Kitchen` | `farmhouse-kitchen` | `ceramic`, `tiles`, `brushedMetal`; indoor lighting, glass (engine) |
| [Office](#office) | `Props/Office` | `open-office` | `carpet`, `laminate`; indoor lighting (engine) |
| [Japanese garden](#japanese-garden) | `Props/Garden`, `Structures/Garden` | `zen-garden` | `rakedGravel`, `bamboo` |
| [Desert](#desert) | `Nature/Desert`, `Props/Desert` | `canyon-road` | `sand`, `strataRock` |
| [Winter](#winter) | `Props/Winter`, `Structures/Winter` | `winter-cabin` | `snow`, `ice` |
| [Beach](#beach) | `Nature/Beach`, `Props/Beach` | `beach-cove` | `sand`, `fabricWeave` |
| [Rail](#rail) | `Structures/Rail`, `Props/Rail` | `rural-halt` | `gravel` |
| [Playground](#playground) | `Props/Playground` | `neighborhood-park` | `rubberMulch` |
| [Village market](#village-market) | `Props/Market`, `Structures/Market` | `village-square` | `cobblestone`, `fabricWeave` |
| [Back alley](#back-alley) | `Props/Street`, `Structures/Urban` | `back-alley` | `grime` overlay |

### Construction site

| id | kind | build | materials | budget |
|---|---|---|---|---|
| `sawhorse` | prop | 2 x 4 boards on A-legs, metal brackets | `wood.pine`, `metal.steel` | 3k |
| `jersey-barrier` | structure | 3 m concrete profile extrusion, lifting slots, chipped arrises | `concrete.rough` | 2k |
| `wheelbarrow` | prop | pressed tray (lofted), tube frame (`catmull` + `Prim.tube`), pneumatic wheel | `metal.painted`, `rubber`, `wood.oak` | 8k |
| `cement-mixer` | prop | drum lathe with fins, A-frame, motor box, wheels | `metal.painted`, `metal.rust` | 12k |
| `rebar-bundle` | prop | 20 to 40 ribbed tubes with sag, wire ties | `metal.rust` | 10k |
| `sandbag` | prop | pillow cube-sphere, seam ridge; stackable variant knob | *`fabric.burlap`* | 1.5k |
| `cable-spool` | prop | plywood flanges, drum, wound cable rings | *`wood.plywood`*, `rubber` | 6k |
| `construction-fence` | structure | 3.5 m mesh panel in concrete-filled feet (alpha mesh card) | `metal.steel`, `plastic.white` | 2k |
| `scaffold-bay` | structure | 2 m bay: standards, ledgers, boards, braces, couplers | `metal.steel`, `wood.weathered` | 20k |
| `traffic-barrel` | prop | ribbed drum lathe with reflective bands | `plastic.orange`, `plastic.white` | 3k |
| `dumpster` | prop | tapered steel box, ribs, lids, forklift pockets | `metal.painted`, `metal.rust` | 6k |

Materials: *`fabric.burlap`* (`fabricWeave`: weave cell pattern, fiber noise), *`wood.plywood`*
(`plywood`: veneer grain plus ply lines on edges), *`metal.galvanized`* (spangle pattern on
`paintedMetal` or a new `galvanized` program), *`plastic.yellow`*.
Scene `construction-lot`: asphalt and gravel pad, fence perimeter, scaffold against a block wall, mixer,
pallets of sandbags, cones and barrels along a lane.

### Harbor

| id | kind | build | materials | budget |
|---|---|---|---|---|
| `mooring-bollard` | prop | cast iron lathe with cap lip | `metal.iron` | 2k |
| `dock-cleat` | prop | horn cleat, two bolts | `metal.steel` | 1k |
| `rope-coil` | prop | helical tube spiral, 3-strand twist in normals | *`rope.manila`* | 8k |
| `crab-pot` | prop | wire frame cage, mesh cards, buoy | `metal.steel`, `plastic.orange` | 6k |
| `marker-buoy` | prop | lathe float with ring | `plastic.orange` | 2k |
| `fish-crate` | prop | stackable plastic crate with vent slots | `plastic.white` | 4k |
| `life-ring` | prop | torus with rope loops | `plastic.orange`, *`rope.manila`* | 3k |
| `wooden-pier` | structure | 4 m modular deck on piles, cross bracing, bolts | *`wood.driftwood`*, `metal.rust` | 15k |
| `shipping-container` | structure | 20 ft corrugated box, corner castings, doors, locking bars | `metal.painted`, `metal.rust` | 12k |
| `rowing-skiff` | prop | lofted hull from cross sections, thwarts, oarlocks | `wood.weathered`, `metal.painted` | 12k |

Engine: water surface (see Engine). Scene `harbor-dock`: pier over water, containers on a quay, crates,
coils and buoys, skiff at the pier.

### Campsite

| id | kind | build | materials | budget |
|---|---|---|---|---|
| `dome-tent` | prop | 2 crossed pole arcs, fly sheet as cloth-sagged grid, guy lines, pegs | *`fabric.nylon`* | 8k |
| `campfire-ring` | prop | river stones ring (`Pebbles` style), charred logs, ember card | `rock.granite`, *`wood.charred`*, `emissive.warm` | 10k |
| `firewood-stack` | prop | split logs (half lathes) stacked with jitter | `bark.oak`, `wood.oak` | 10k |
| `log-stump` | nature | lathe with flare, cut top end grain rings | `bark.pine`, *`wood.endgrain`* | 4k |
| `fallen-log` | nature | `Prim.tube` with taper, broken branch stubs, moss top layer | `bark.oak` | 6k |
| `camp-chair` | prop | folding frame tubes, sagging seat cloth | `metal.steel`, *`fabric.canvas`* | 5k |
| `cooler` | prop | rounded box, lid hinge, handles | `plastic.white`, `plastic.black` | 3k |
| `camp-lantern` | prop | metal frame, glass chimney, emissive mantle | `metal.painted`, `glass.lamp` | 3k |
| `canoe` | prop | lofted hull, gunwales, thwarts, seats | `plastic.orange` or `wood.oak` | 10k |

Scene `lakeside-camp`: forest-glade edge, tent, fire ring with chairs, woodpile, canoe on the shore.

### Farm

| id | kind | build | materials | budget |
|---|---|---|---|---|
| `round-hay-bale` | prop | cylinder with wrapped-straw normals, net wrap | *`straw.hay`* | 4k |
| `square-hay-bale` | prop | rounded box, twine bands | *`straw.hay`* | 2k |
| `rail-fence` | structure | 3 m split-rail section, posts, modular | `wood.weathered` | 3k |
| `water-trough` | prop | galvanized oval tub, rolled rim | *`metal.galvanized`* | 3k |
| `milk-can` | prop | lathe with shoulder and lid | *`metal.galvanized`* | 2k |
| `feed-sack` | prop | slumped pillow shape, folded top | *`fabric.burlap`* | 2k |
| `tractor-tire` | prop | torus with chevron lugs | `rubber` | 8k |
| `scarecrow` | prop | post, crossbar, stuffed clothes as tubes, hat | `wood.weathered`, *`fabric.canvas`*, *`straw.hay`* | 8k |
| `barn-wall` | structure | 4 m board-and-batten section with door frame | *`wood.barn-red`* | 6k |

Materials: *`straw.hay`* (`straw`: dense directional strands), *`wood.barn-red`* (`paintedWood`: paint
over grain with peeling).
Scene `farmyard`: barn walls, fenced paddock, bales, trough, tire, scarecrow in a field of grass.

### Kitchen

Needs indoor lighting first (Engine). Props sit on counters, so origins stay at the base.

| id | kind | build | materials | budget |
|---|---|---|---|---|
| `kitchen-table` | prop | plank top, turned legs, aprons | `wood.oak` | 6k |
| `ladder-back-chair` | prop | turned posts, rungs, woven seat | `wood.oak`, *`fabric.rush`* | 8k |
| `cutting-board` | prop | rounded slab with end grain and knife marks | *`wood.butcher-block`* | 1k |
| `stock-pot` | prop | lathe pot, rolled rim, handles, lid | *`metal.stainless`* | 4k |
| `cast-iron-pan` | prop | lathe pan, handle with hole | `metal.iron` | 3k |
| `kettle` | prop | lathe body, spout tube, handle | *`metal.stainless`*, `plastic.black` | 5k |
| `mug` | prop | lathe with handle torus segment | *`ceramic.glazed`* | 2k |
| `plate-stack` | prop | 3 to 8 lathe plates with jitter | *`ceramic.glazed`* | 4k |
| `glass-jar` | prop | lathe jar, threaded lid | *`glass.clear`*, `metal.painted` | 3k |
| `fruit-bowl` | prop | bowl lathe plus apples/lemons from cube-spheres | *`ceramic.glazed`*, *`fruit.apple`* | 8k |
| `wall-cabinet` | structure | carcass, shaker doors, knobs | *`wood.painted`* | 6k |

Materials: *`ceramic.glazed`* (`ceramic`: glaze pooling, crazing), *`tile.subway`* (`tiles`: grout grid,
per-tile tilt in height), *`metal.stainless`* (`brushedMetal`: anisotropic streaks), *`glass.clear`*
(transparent mode, engine).
Scene `farmhouse-kitchen`: tiled wall, counter run, table and chairs, cookware.

### Office

| id | kind | build | materials | budget |
|---|---|---|---|---|
| `office-desk` | prop | laminate top, steel legs, cable tray | *`laminate.oak`*, `metal.painted` | 3k |
| `office-chair` | prop | 5-star base, gas lift, mesh back, padded seat | `plastic.black`, *`fabric.mesh`* | 12k |
| `monitor` | prop | thin panel, stand, emissive screen | `plastic.black`, `emissive.warm` | 2k |
| `keyboard` | prop | key grid (instanced keys as one surface) | `plastic.black` | 6k |
| `filing-cabinet` | prop | 4 drawers, handles, label slots | `metal.painted` | 4k |
| `bookshelf` | prop | carcass plus books (boxes with spine variation) | *`laminate.oak`*, *`paper.cover`* | 12k |
| `potted-plant` | nature | pot lathe, soil disc, leaf cards (`TreeSpecies` small) | *`ceramic.glazed`*, `leaf.maple` | 6k |
| `water-cooler` | prop | cabinet, bottle, taps | `plastic.white`, *`glass.clear`* | 3k |

Scene `open-office`: carpet floor, desk pods, chairs, shelving, plants.

### Japanese garden

| id | kind | build | materials | budget |
|---|---|---|---|---|
| `stone-lantern` | prop | stacked lathe and box stones (base, shaft, firebox, roof, finial) | `rock.granite` | 6k |
| `torii-gate` | structure | two pillars, kasagi with upturned ends, nuki | *`wood.vermilion`*, `plastic.black` | 6k |
| `bamboo-fence` | structure | 2 m section of culms with nodes, rope ties | *`bamboo.dry`* | 8k |
| `stepping-stone` | nature | flat boulder variant (`Boulder` with low `size.y`) | `rock.granite` | 2k |
| `japanese-maple` | nature | `TreeSpecies.japaneseMaple`: layered horizontal crown, red leaves | `bark.oak`, *`leaf.japanese-maple`* | 25k |
| `moss-mound` | nature | low cube-sphere with moss top layer | `rock.granite` | 2k |
| `arched-bridge` | structure | curved deck from `catmull`, rails, posts | *`wood.vermilion`* | 10k |

Materials: *`gravel.raked`* (`rakedGravel`: parallel ripples with circles around stones; anti-tile off),
*`bamboo.dry`* (`bamboo`: node bands, fibers).
Scene `zen-garden`: raked gravel, stones, lantern, maples, bamboo fence, gate.

### Desert

| id | kind | build | materials | budget |
|---|---|---|---|---|
| `saguaro` | nature | ribbed tube trunk and arms from a small skeleton, spine dots | *`cactus.saguaro`* | 10k |
| `barrel-cactus` | nature | ribbed squashed lathe | *`cactus.saguaro`* | 3k |
| `agave` | nature | rosette of thick folded leaf strips | *`leaf.agave`* | 6k |
| `tumbleweed` | nature | random tube tangle in a sphere | `bark.oak` | 8k |
| `mesa-rock` | nature | `Boulder` with stacked horizontal strata facets | *`rock.redstone`* | 15k |
| `water-tower` | structure | tank on four legs, ladder, braces | `metal.rust`, `wood.weathered` | 15k |

Materials: *`sand.dune`* (`sand`: wind ripples, grain sparkle), *`rock.redstone`* (`strataRock`: layered
bands).
Scene `canyon-road`: asphalt road through sand, mesas, cacti, water tower, golden-hour sky.

### Winter

| id | kind | build | materials | budget |
|---|---|---|---|---|
| `snowy-spruce` | nature | `SpruceTree` with snow top layer on bark and leaves | `bark.pine`, *`leaf.spruce-snow`* | 25k |
| `snowman` | prop | three cube-spheres with lumpy noise, stick arms, scarf | *`snow.packed`*, `bark.oak`, *`fabric.wool`* | 5k |
| `wooden-sled` | prop | runners from `catmull`, slats | `wood.oak`, `metal.steel` | 4k |
| `log-cabin-wall` | structure | 4 m section of stacked notched logs, window opening | `bark.pine`, `wood.weathered` | 20k |
| `snow-drift` | nature | smooth terrain patch blob | *`snow.packed`* | 4k |

Materials: *`snow.packed`*, *`ground.snow`* (`snow`: sparkle, sastrugi), *`ice.pond`* (`ice`).
Material variants with `topColor` white and higher `topAmount` give snow on any existing asset.
Scene `winter-cabin`: snow ground, cabin walls, snowy spruce ring, sled, woodpile.

### Beach

| id | kind | build | materials | budget |
|---|---|---|---|---|
| `palm-tree` | nature | curved trunk with ring scars, frond cards (new `TreeSpecies` options for a crown of fronds) | *`bark.palm`*, *`leaf.palm`* | 20k |
| `beach-umbrella` | prop | pole, ribs, cloth panels with sag | *`fabric.stripe`*, `metal.steel` | 4k |
| `lounge-chair` | prop | frame, slats or sling | `wood.weathered` | 5k |
| `surfboard` | prop | lofted board outline, fins | `plastic.white` | 3k |
| `lifeguard-tower` | structure | stilted hut, ramp, rails | `wood.weathered`, `plastic.white` | 15k |
| `driftwood` | nature | bleached twisted tube | *`wood.driftwood`* | 3k |
| `seashell-cluster` | nature | small shells (spiral lathes) | *`ceramic.shell`* | 4k |

Scene `beach-cove`: sand, water edge (engine), palms, umbrella, chairs, tower.

### Rail

| id | kind | build | materials | budget |
|---|---|---|---|---|
| `rail-track` | structure | 5 m section: rails (profile extrusion), sleepers, clips, ballast mound | *`metal.rail`*, *`wood.creosote`*, *`gravel.ballast`* | 12k |
| `rail-signal` | prop | mast, head with lamps, ladder | `metal.painted`, `emissive.warm` | 5k |
| `platform-bench` | prop | steel frame, timber slats | `metal.painted`, `wood.oak` | 5k |
| `luggage-cart` | prop | flatbed, wheels, handle | `wood.weathered`, `metal.iron` | 5k |

Scene `rural-halt`: single platform, track running out of view, signal, benches, shelter.

### Playground

| id | kind | build | materials | budget |
|---|---|---|---|---|
| `swing-set` | prop | A-frame tubes, chains (link instancing), seats | `metal.painted`, `rubber` | 12k |
| `slide` | prop | ladder, platform, curved chute | `metal.painted`, `plastic.orange` | 8k |
| `seesaw` | prop | beam, pivot, handles | `metal.painted`, `wood.oak` | 3k |
| `basketball-hoop` | prop | pole, backboard, rim, net cards | `metal.painted`, `plastic.white` | 5k |
| `soccer-goal` | prop | frame tubes, net cards | `metal.painted` | 4k |
| `bleachers` | structure | aluminium plank tiers on frames | *`metal.galvanized`* | 10k |

Scene `neighborhood-park`: rubber mulch play area, equipment, benches from `Props/Street`, trees.

### Village market

| id | kind | build | materials | budget |
|---|---|---|---|---|
| `market-stall` | structure | timber frame, plank counter, cloth awning with sag | `wood.weathered`, *`fabric.stripe`* | 10k |
| `hand-cart` | prop | two big spoked wheels, bed, shafts | `wood.weathered`, `metal.iron` | 10k |
| `grain-sack` | prop | slumped sack, tied neck | *`fabric.burlap`* | 2k |
| `anvil` | prop | horn and body from lofted sections, stump base | `metal.iron`, `bark.oak` | 4k |
| `stone-well` | structure | cylinder of stone blocks, roof, crank, bucket | *`stone.block`*, `wood.weathered` | 15k |

Materials: *`ground.cobble`* (`cobblestone`: rounded sets, mud joints), *`stone.block`*.
Scene `village-square`: cobbles, well at the center, stalls, carts, barrels and crates.

### Back alley

| id | kind | build | materials | budget |
|---|---|---|---|---|
| `ac-unit` | prop | box, fan grille, fins | `metal.painted` | 5k |
| `electrical-box` | prop | cabinet, conduit, padlock | `metal.painted` | 3k |
| `newspaper-box` | prop | box on post, window, coin slot | `metal.painted` | 3k |
| `bike-rack` | prop | bent tube hoops, base rail | `metal.steel` | 3k |
| `bicycle` | prop | tube frame, spoked wheels (instanced spokes), saddle, chain | `metal.painted`, `rubber` | 14k |
| `manhole-cover` | prop | disc with raised pattern in height | `metal.iron` | 1k |
| `brick-wall` | structure | 4 m section, coping, downpipe | `brick.red`, `concrete.smooth` | 4k |

Materials: grime overlay as a top-layer variant (dark, low `topLow` so it collects at the base).
Scene `back-alley`: two brick walls, asphalt with drain, dumpster, AC units, bikes.

## Nature, any pack

- Tree species: maple, Scots pine, willow, dead snag, palm (fronds), Japanese maple. Each is a
  `TreeSpecies` in `Nature/Trees/Species.swift` plus a short asset file.
- Ground cover: fern (card fan), meadow flowers (atlas program `flowers`), reeds and cattails, clover
  patch, mushrooms cluster, ivy on walls (cards along a mesh).
- Rocks: cliff face section, scree pile, river stones (smooth, wet variant), sandstone arch.
- Ground: path wear and puddles need terrain splat blending (Engine).

## Engine

Issue-sized; discuss in an issue before starting.

- ASTC texture compression in compute, blitted into compressed `LowLevelTexture`s (about 4x memory).
- Disk cache of generated textures keyed by spec hash.
- Impostor billboards as LOD3, captured with `RealityRenderer`.
- Terrain splat blending: per-vertex weights for path wear, moss, mud; second ground material.
- Transparent mode in `MaterialSpec` (glass, water bottles, windows) through ShaderGraph opacity.
- Water surface: animated normal blend, depth tint, fresnel reflection of the sky.
- Indoor environment: `RealEnvironment.indoor` with area-light IBL and no sun, for interior packs.
- Decals: projected cards for stains, leaves, graffiti-free signage.
- Per-instance color variation for fields (tint jitter through a custom instance attribute).
- Collision shapes from assets (`CollisionComponent` boxes and hulls) for interactive apps.
- USDZ export of a generated asset (`realityhd export <id>`) for Reality Composer Pro.
- Snow and wet variants of the top layer, driven by a global weather parameter.

## Prompting a coding agent

Paste one of these into Claude Code, Codex or another agent working in a clone of this repo.

Single asset:

```
Read AGENTS.md and docs/guides/assets.md. Add the `wheelbarrow` prop from docs/IDEAS.md
(Construction site pack) with `realityhd new prop wheelbarrow --theme Construction --author <me>`.
Model a real builder's wheelbarrow with real dimensions. Follow the photoreal checklist. Iterate
with `realityhd render` from at least two angles until scale, bevels and materials look right. Finish
with swift test, realityhd thumbs, realityhd catalog.
```

Whole pack:

```
Read AGENTS.md, docs/IDEAS.md and the guides. Build the <Pack> pack: every asset in its table that
does not exist in CATALOG.md, using existing materials where the table allows, then the pack's scene.
One commit per asset. Render and inspect each asset before moving on. Stop and report if a needed
material or engine feature is missing instead of faking it.
```

New material family:

```
Read AGENTS.md and docs/guides/materials.md. Add a `fabricWeave` texture program and the materials
fabric.burlap, fabric.canvas and fabric.nylon. Verify tiling with realityhd textures at 1024, then
render sandbag and dome-tent placeholders that use them.
```
