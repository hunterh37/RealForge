# Changelog

## 4.1.0

Baseball: a regulation ballpark scene with the field, structures, gear and materials to build it.

- Scene `ballpark`: home plate at the origin, center field along -Z; padded walls (8 ft fair, 4 ft foul),
  foul poles, backstop with hood, dugouts, bleachers behind the foul walls and the plate, six light towers,
  oaks and maples past the outfield. Camera in the right-handed batter's box. Demo case "Ballpark".
- Structures: baseball-diamond (90 ft paths, 10 in mound with rubber, 95 ft arc, home circle, clay
  batter's boxes, chalked boxes, foul lines, runner's lane and coach's boxes, warning track; exposes
  `bases`, `foulPoles`, `wallLine()`, `wallDistance`, `inside`), outfield-wall, foul-pole, backstop,
  dugout, bleachers, light-tower. Off-center structures expose `anchor(seed:)` for their design origin.
- Props (gated, signed off): home-plate, base-bag, baseball-bat (ash or two-tone maple), baseball,
  ball-bucket, batting-helmet.
- Texture programs `turf` (mowing stripes or checkerboard), `infieldClay` (drag lines, granules, cleat
  prints), `chainLink` (cutout woven mesh). Keys: turf.ballpark, turf.ballpark-stripe, turf.worn,
  ground.infield, ground.mound-clay, ground.warning-track, paint.field-white, fence.chainlink,
  fence.chainlink-vinyl, fence.chainlink-veil (+ -light, -yellow), padding.vinyl, masonry.cmu,
  masonry.cmu-green, plus gear keys in SportsGear.swift.

## 4.0.0

Articulated multi-state assets, building interiors, and the engine work that keeps them cheap
(see docs/V4.md and docs/guides/articulation.md).

- Articulation: `Rig`, `RigPart`, `Joint` (revolute, prismatic, fixed, mimic), `RigState`, part options,
  `RigLight`; `RealArticulated` protocol (`rig(seed:)`, `build(seed:state:)`); `Rig.validate()`.
- Runtime: `RealJointComponent`, `RealArticulationComponent`, `RealArticulationSystem`; `Entity`
  `setArticulation`, `setJoints`, `nextArticulation`, `realToggle` (tap a part); `RealityHD.articulated`;
  LOD switching across part hierarchies.
- 15 articulated assets: office-door, glass-door, elevator-doors, office-window, filing-cabinet,
  desk-pedestal, storage-cabinet, executive-desk, office-chair, pedal-bin, laptop, desktop-monitor,
  hardcover-book, banker-lamp, ceiling-light.
- 11 static office props: office-desk, bookshelf, conference-table, lobby-sofa, reception-desk,
  whiteboard, water-cooler, snake-plant, keyboard-mouse, coffee-mug, paper-stack. Structure office-block.
- Scenes: open-office, executive-office, office-lobby, conference-room, office-plaza.
- Interiors: `Room` shell builder (openings, columns, skirting, T-bar or plaster ceiling, slab);
  `InteriorLight` indoor probe (`.office`, `.warm`, `.lobby`); `RealScene.lighting` hints applied by
  `RealityHD.environment(for:)` and `realityhd render`; `RealScene.lights`.
- Optimization: `RealScene.batchStatics` (cell/material/LOD merge), `AOBake` + `BVH` scene AO bake,
  `scene.field(asset, state:)` instanced baked states, tint keys share normal/roughness/AO/metallic maps
  with a half-resolution albedo (open-office 574 MB to 308 MB), unlit textured displays.
- 14 texture programs and 31 keys for offices (carpet, acoustic tile, wall paint, veneers, marble,
  terrazzo, pavers, laminate, chair mesh, page edges, screen UI, snake plant, potting soil).
- CLI: `states`, `render --state`, scene lighting hints, `REALITYHD_TEX_REPORT`; CATALOG.md Articulated section.
- Helpers: `cuboid`, `groundAO(&rig)`, `Xform.inverse/then`, `Xform(matrix:)`.
- Tags `door`, `window`, `electronics`, `book`, `building`, `articulated`.
- Demo: five new scenes, tap-to-toggle articulated parts, scene-driven lighting.

## 3.0.0

Agent pipeline and photoreal props (see docs/V3.md).

- Quality gate: `realityhd gate` renders a six-view sheet, compares against a reference photo
  (Vision subject mask, silhouette IoU with camera search, feature-print similarity, Lab color,
  aspect, detail), lints geometry, scores a nine-criterion vision rubric and signs off
  (`briefs/signoff/<id>.json`, fingerprint-checked by tests). `Scripts/vision_judge.py` judges headless
  through the Claude API.
- CLI: `context`, `brief`, `lint`, `sheet`, `gate`; `new prop --brief`.
- Prop briefs (`briefs/<id>.json`, `PropBrief`), `GeometryLint`, `Rubric`, `Verdict`, `GateResult`, `Signoff`.
- Geometry kit: `Shape2D`, `Prim.extrude/sweep/loft/ring/superellipsoid/torus/helix/cylinder`, `Profile`,
  `Surface.deform/displace/subdivided/flipped`; hardware helpers `rivet`, `rivetRow`, `hexBolt`,
  `stitches`, `barHandle`, `chain`, `caster`, `panelWithBead`, `tuftedPanel`, `buttons`, `facing`, `resample`.
- Texture programs `leather`, `brushedMetal`, `polishedMetal`, `ceramicGlaze`, `caneWeave`; 29 craft material keys.
- Ten props: vintage-suitcase, chesterfield-armchair, bentwood-chair, anglepoise-lamp, copper-kettle,
  stoneware-crock, stone-lantern, ship-anchor, tool-chest, wicker-basket.
- `PreviewHint.studio` (concrete studio floor). Small lathes and tubes use their true circumference
  for U (no texture stretch on knobs and wires).
- Claude skills in `.claude/skills`: realityhd-prop, realityhd-brief, realityhd-gate, realityhd-material.
- Tags `leather`, `workshop`, `travel`, `antique`.

## 2.0.0

96 assets (from 21), 10 scenes (from 3), 142 materials (from 29), 54 texture programs (from 15).
Scope and research notes: `docs/V2.md`.

Trees
- TreeGenerator v2: branch collars, root buttresses and surface roots, crotch occlusion, per-level bark
  scale, leaf clusters at twig tips with sun bias, pendant leaves, dead stubs, broken tops, seasonal
  `leafDensity`/`autumn`, `BranchLevel.whorl`, hierarchical wind data.
- Broadleaf: maple-tree, beech-tree, willow-tree, japanese-maple, aspen-tree, dead-snag.
- Conifer, palm, desert: scots-pine, fir-tree, cypress-tree, larch-tree, snowy-spruce, palm-tree,
  saguaro, barrel-cactus, agave.

Ground cover and terrain
- Geometry-blade grass with card LODs: grass-tuft, tall-grass, dry-grass, lawn-patch; grass-clump reworked.
- Plants: fern, meadow-flowers, clover-patch, dandelion, reed-clump, mushroom-cluster, moss-mound,
  ivy-patch, leaf-litter.
- Ground programs gravel, sand, mud, snow, cobblestone, dirtPath; forestFloor rework.
- terrain-hill, dirt-path, puddle, mud-patch, gravel-patch, snow-drift, sand-dune; ground-patch erosion
  relief and worn-path knobs.

Rocks
- `RockShape` generator (warped ridged body, beveled fractures, chips, strata); boulder and pebbles use it.
- rock-outcrop, cliff-face (tiles along X), scree-pile, river-stones, stepping-stone, mossy-rock,
  mesa-rock, flagstone, rock-pile. Programs strataRock, rockSlate, rockRiver.

Props and structures
- Campsite pack: dome-tent, campfire-ring, firewood-stack, camp-chair, cooler, camp-lantern, canoe,
  axe-in-stump; log-stump, fallen-log, firewood, root-stump.
- Construction pack: sawhorse, jersey-barrier, wheelbarrow, cement-mixer, rebar-bundle, sandbag,
  cable-spool, construction-fence, scaffold-bay, traffic-barrel, dumpster.
- Farm pack: round-hay-bale, square-hay-bale, rail-fence, water-trough, milk-can, feed-sack,
  tractor-tire, barn-wall.
- Programs fabricWeave, woodEndGrain, charcoal, plywood, galvanized, straw, paintedWood, jute.

Scenes
- New: lakeside-camp, autumn-woods, construction-lot, farmyard, alpine-meadow, canyon-road, winter-forest.
- forest-glade, park-path and prop-yard rebuilt with v2 content.

Engine
- Per-instance hue, value and scale jitter for instanced fields (`RealInstancing.Options.tintJitter`).
- Splat blending: `Surface.splat` weights and `MaterialSpec.splat` second layer.
- Texture disk cache keyed by spec, size and shader hash (`REALFORGE_NO_DISK_CACHE=1` to opt out).
- Leaf flutter from per-vertex phase; transparent mode, `water` program, water.pond, glass.pane.
- Lighting recalibrated (sun 9000 lux, IBL -0.3 EV); `--sun`/`--ibl` render flags; `realityhd demo`.
- PBR path fixes: cutout foliage opacity and atlas V flip.

Known limits
- Splat layers and emissive textures show only on the ShaderGraph path.
- Backdrop mountains in alpine-meadow read flat beyond 200 m; light rock can render near white under
  the new lighting.
- Scene worst-case LOD0 counts are 6 to 11M triangles; check frame time on Vision Pro.

## 1.1.0

- Library layout for contributors: one asset per file under `Nature/`, `Props/<Theme>/`, `Structures/`;
  per-kind registries; scenes in `Scenes/` behind `RealSceneBuilder` and `SceneCatalog.all`.
- `RealAsset.author`, `RealAsset.preview` (`PreviewHint`), controlled tag vocabulary (`AssetTag`).
- Materials split into `RealMaterials/Library/<Family>.swift`; Metal programs split into
  `Shaders/<Family>Shaders.swift` with dispatch generated from `TextureProgram`.
- Building helpers (`plank`, `board`, `turned`, `groundAO`, `catmull`, `Xform.jittered`) are public.
- `RealScene.add`, `RealScene.field`, `RealScene.worstCaseTriangles`, `RealInstancing.Options.trees`,
  `.groundCover(cull:)`.
- CLI: `realityhd new` (asset, scene, material scaffolding), `realityhd thumbs`; CLI split into files.
- Contract tests for assets, scenes and materials; CI with a stale-`CATALOG.md` check.
- Scene thumbnails moved to `docs/scenes/`. `prop-yard` grid sizes itself to `Props.all`.
- Docs: AGENTS.md, CONTRIBUTING.md, docs/IDEAS.md, guides for assets, scenes and materials.

## 0.1.0

- 21 assets, 3 scenes, 29 materials, ShaderGraph materials, sky, instancing, LOD, CLI.
