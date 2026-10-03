# Design

## Layers

RealCore is pure Swift geometry: `Surface` (one material, indexed, smooth normals, UV0 in meters,
tangents with handedness, wind weight, baked occlusion), `Model` (surfaces merged by material),
`LODModel`. Generators (trees, rocks, lathes, tubes, beveled boxes, terrain, scatter) are value types
and Sendable, so scenes build off the main actor and tests run on any Mac.

RealMaterials owns texture synthesis. One Metal source string compiles at runtime
(`makeLibrary(source:)`), so `swift build` needs no metallib step. `rf_material` evaluates a
material program per texel into albedo/height/roughness/AO/metallic; `rf_normal` derives normals
from height with a wrapping Sobel; `rf_alpha_down/count/apply` build alpha mips that keep the
mip-0 alpha-test coverage (Castano 2010) by counting coverage for 16 candidate scales on the GPU,
with no CPU round trip. All noise is periodic, so every texture tiles.

RealKit maps it to RealityKit. Meshes go straight into a `LowLevelMesh` (one interleaved 72-byte
vertex buffer, one part per material). Textures are written by compute into `LowLevelTexture`s and
wrapped as `TextureResource`s once per material key. Materials are ShaderGraph USDA emitted at
runtime from `RealShaderOptions` (cutout, wind, translucency, anti-tile, top layer, fog, triplanar,
metallic map), compiled once per option set and copied per material. `PhysicallyBasedMaterial` is
the synchronous fallback.

RealLibrary holds the catalog and scenes plus the `RealForge` facade.

## Realism techniques

Lighting carries most of it. The sky is a 16x6-sample single-scattering ray march (Rayleigh, Mie,
ozone) into an RGBA16F equirect. The IBL copy omits the sun disk, because the directional light
carries the sun with cascaded shadows; the skybox copy includes it. Grazing elevations clamp to 2.5
degrees to stand in for multiple scattering, which keeps horizons bright. Aerial perspective in
every material mixes toward the measured horizon color with distance, and a 4 km far-ground plane
makes the horizon land fading into haze.

Foliage: alpha-tested cards with coverage-preserving mips, crown-sphere normals blended 45 to 70
percent (volumetric crown shading), crown occlusion baked per vertex (interior and underside darker),
back-lit transmission term toward the sun, two-sided. Grass cards use up-tilted normals and root
occlusion. Bark: furrow networks from zero-crossings of anisotropic noise (oak), lenticels and scars
(birch), stacked plates (pine); root flare lobes on trunks; UV seams quantized to the bark tile.

Surfaces: beveled edges on every box prop (highlights on edges are the main tell of real objects),
per-board jitter, cavity AO from mesh concavity, contact AO toward the ground, triplanar rock color
to avoid stretching on fracture facets, world-up moss masked by texture luminance, two-scale plus
macro anti-tiling on ground and asphalt.

## Performance techniques

Forests and grass are `MeshInstancesComponent` cells (18 m for trees, 8 m for grass). Each cell has
one child per LOD; `RealLODSystem` enables one child by distance every 0.2 s with 8 percent
hysteresis and optional cull distance. Grass and LOD2 cast no shadows. Tree LODs share a skeleton:
LOD1 drops twigs and keeps 45 percent of cards at 1.45x size, LOD2 keeps trunk and limbs with 16
percent of cards at 2.4x. Twigs are never meshed at LOD0 for oak/birch/spruce (`woodLevels`); cards
imply them.

Textures are generated once per key and shared. Normals are RG8 (half of RGBA8) with Z rebuilt in
the shader; the PBR fallback sees blue = 1 through a texture swizzle. `RealQuality` presets cap
texture size. Geometry generation is 0.2 to 17 ms per asset in release, so assets build on demand
instead of shipping.

On visionOS, Systems can't read head pose, so `RealViewerTracker` runs ARKit world tracking and
feeds `RealViewer.position` before each LOD pass.

## Limits and next steps

No vertex animation for instanced trees beyond the shader wind (by design). ShaderGraph only exposes
uv0/uv1 to the graph, so per-vertex data is packed into uv1 (wind weight, AO); the phase comes from
world position. No GPU texture compression yet: ASTC encode in compute, then blit into compressed
`LowLevelTexture`s, would cut texture memory about 4x. Candidates after that: impostor billboards
for LOD3 via `RealityRenderer` captures, terrain splat blending (path wear, moss), snow and wet
variants of the top layer, more species (maple, pine, palm), interiors (furniture, kitchen props),
and disk caching of generated textures keyed by spec hash.
