# API cheat sheet

Moved from AGENTS.md. Live listing: `swift run -q realityhd context api`.


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
entity.makeGrabbable(min:, max:)   entity.resetGrab()   rig.restBounds   scene.addLive(asset, ..., grabbable:)   // RealityHD 5
Room(size:).with { $0.openings = [.init(.south, offset:, width:, sill:, head:)] }   room.shell()   room.ceilingModel()   room.fixturePattern(every:)

// RealityKit
model.modelEntityAsync()   lod.entityAsync()   RealInstancing.field(lod, transforms:, options:)
RealMaterialCache.shared.materialAsync(key)   .warm([keys])   .overrides[key] = spec
RealEnvironment(SunSky(elevation:, azimuth:, turbidity:), skybox:)   env.illuminate(entity)
RealWind.direction/.speed/.strength   RealAtmosphere.fogDensity/.fogColor   RealQuality.apply(.performance)
RealPreview(environment:).frame(entity); await preview.render(width:, height:)
```

