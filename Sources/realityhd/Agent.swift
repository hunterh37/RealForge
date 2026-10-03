import Foundation
import RealCore
import RealMaterials
import RealLibrary

/// `realityhd context [prop|materials|api|gate]`: everything an agent needs to write a prop, in one
/// compact print, generated from the live library so it never goes stale. Replaces reading the
/// sources of several assets and material files.
func contextCommand(_ args: Args) {
    let what = args.next() ?? "prop"
    switch what {
    case "api": print(apiSheet)
    case "materials": print(materialSheet(filter: args.next()))
    case "gate": print(gateSheet)
    case "props": print(propSheet)
    default:
        print(conventionsSheet); print(apiSheet); print(materialSheet(filter: nil)); print(propSheet); print(gateSheet)
    }
}

let conventionsSheet = """
## Conventions
Meters, +Y up, base at y = 0, centered on X/Z. build(seed:) deterministic (SeededRNG, rng.fork(i)).
UVs in meters (materials tile by tileSize); wood grain runs along U: build boards along +X.
Bevel every edge (real radii 1-5 mm). Inset touching parts 1-2 mm (no coplanar faces).
Knobs: every stored `public var` with a real default and a `///` doc. Colors as UInt32 sRGB hex.
Tint suffix: "metal.painted:B3201C" replaces colorA. tags[0] = "prop"; tags from AssetTag.vocabulary.
groundAO(&m) last (contact AO + cavity AO). Budget ~20% over LOD0 tris; props cap 15k.
"""

let apiSheet = """
## API (RealCore + RealLibrary/Building)
Prim.roundedBox(V3 size, radius:, bevelSegments:, material:)          centered box, rounded edges
Prim.lathe([V2(r, y)], segments:, seamTile:, material:, swapUV:)      revolve about +Y; turned([(r, y)], material:, grainVertical:)
Prim.cylinder(radius:, height:, bevel:, segments:, material:)          y 0...height, rounded rims
Prim.tube(points, radii:, sides:, seamTile:, material:, capEnd:)        round tube along a path
Prim.sweep(profile2D, along: path3D, up:, scales:, closedPath:, caps:, grainAlongPath:, material:)  any section along a path (profile x follows up)
Prim.extrude(outline2D, depth:, bevel:, bevelSegments:, material:)     XY outline -> prism along Z (centered), beveled caps
Prim.loft([Prim.ring(outline2D, y:, offset:)], capStart:, capEnd:, material:)   skin changing sections (spouts, bodies)
Prim.superellipsoid(V3 size, exponent: 2...12, subdivisions:, material:, bulge: { dir in 1 })   cushions, pebbles, soft boxes
Prim.torus(major:, minor:, segments:, sides:, arc:, minorY:, material:) rings, hoops, handles (XZ plane)
Prim.helix(radius:, pitch:, turns:, wire:, material:)                  springs, coils (+Y)
Prim.cubeSphere(subdivisions:, material:) { dir in point }   Prim.terrain(size:, segments:, material:) { xz in h }
Shape2D.rect / roundedRect(w, h, radius:) / circle(r, ry:) / superellipse(w, h, exponent:) / polygon(sides:, radius:)
Shape2D.rounded(points, radius:) fillet corners   Shape2D.offset(points, d)   Shape2D.triangulate(points)
Profile.roundedCylinder(...)  Profile.smooth(points, per:)  Profile.shell(outer, wall:, floor:)  thin-walled vessels
surface.deform { p in p' }  surface.displace { p, n in meters }  surface.subdivided()  surface.flipped()  surface.bakeCavityAO()
plank(len, width, thick, bevel:, material:)  board(from:, to:, width:, thick:, up:, material:) -> (Surface, Xform)
catmull(points, per:)  resample(path, spacing:)  facing(normal) -> quat (+Y to normal)  xform.jittered(&rng)
rivet(&m, at:, normal:, radius:, material:)  rivetRow(&m, along:, spacing:, normal:, material:)
hexBolt(&m, at:, normal:, size:, material:)  stitches(along:, normal:, pitch:, material:) -> Surface
barHandle(length:, standoff:, radius:, material:) -> Surface (bar along X, posts to z = 0)
chain(along:, wire:, material:) -> Surface   caster(&m, at:, height:, wheelRadius:, frame:, wheel:, hub:)
panelWithBead(&m, outline:, y:, panel:, beadMaterial:)   groundAO(&m, height:, floor:)
let (panel, pts) = tuftedPanel(width:, height:, spacing:, puff:, material:)   buttons(&m, pts, xform, material:)   deep-buttoned upholstery (local XY, puffs +Z)
var m = Model(name: Self.id); m.add(surface, Xform(translation:, rotation: simd_quatf(degrees:, axis:), scale:))
LODModel(m)  or  LODModel(levels: [m0, m1], switchDistances: [8])
static let preview = PreviewHint(azimuth:, elevation:, distance:, studio: true)   rng.float(a...b) rng.vary(x, 0.1) rng.chance(p)
"""

func materialSheet(filter: String?) -> String {
    var lines = ["## Materials (key  program  tile m  notes)"]
    var family = ""
    for s in MaterialLibrary.all where filter == nil || s.key.hasPrefix(filter!) {
        let f = String(s.key.split(separator: ".")[0])
        if f != family { family = f; lines.append("# \(f)") }
        var notes: [String] = []
        if s.mode != .opaque { notes.append("\(s.mode)") }
        if s.metallic > 0 || s.hasMetallicMap { notes.append("metal") }
        if s.clearcoat > 0 { notes.append("clearcoat") }
        if s.triplanar { notes.append("triplanar") }
        if s.topAmount > 0 { notes.append("top layer") }
        if s.tileSize == 0 { notes.append("atlas UVs") }
        lines.append("\(pad(s.key, 26))\(pad(s.program.map { "\($0)" } ?? "scalar", 15))\(pad(s.tileSize == 0 ? "-" : String(format: "%.2f", s.tileSize), 6))\(notes.joined(separator: ", "))")
    }
    return lines.joined(separator: "\n")
}

var propSheet: String {
    var byTheme: [String: [String]] = [:]
    let files = (try? repoRoot()).map { root -> [String: String] in
        var out: [String: String] = [:]
        let base = root.appendingPathComponent("Sources/RealLibrary/Props")
        if let e = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) {
            for case let u as URL in e where u.pathExtension == "swift" { out[u.deletingPathExtension().lastPathComponent] = u.deletingLastPathComponent().lastPathComponent }
        }
        return out
    } ?? [:]
    for t in Props.all { byTheme[files[String(describing: t)] ?? "?", default: []].append(t.id) }
    var lines = ["## Props by theme (read one similar asset before writing: Sources/RealLibrary/Props/<Theme>/<Type>.swift)"]
    for k in byTheme.keys.sorted() { lines.append("\(pad(k, 13))\(byTheme[k]!.joined(separator: " "))") }
    lines.append("tags: " + AssetTag.vocabulary.sorted().joined(separator: " "))
    return lines.joined(separator: "\n")
}

let gateSheet = """
## Loop (each step prints one stat line)
realityhd brief <id> --theme T --name "..."   writes briefs/<id>.json; fill size, parts, materials, style
realityhd new prop <id> --brief briefs/<id>.json   scaffold with brief size and summary
swift build && realityhd lint <id>              budget, grounding, texel scale, size vs brief
realityhd gate <id> [--ref photo.jpg]           out/gate/<id>/sheet.png (+ compare.png), report.json, verdict.template.json
  Read the sheet, score each rubric criterion 0-10 honestly, list fixes -> out/gate/<id>/verdict.json
realityhd gate <id> --verdict out/gate/<id>/verdict.json --no-sheet   final score; pass needs final >= threshold, no criterion < 6
  fail -> apply the top fixes, rebuild, gate again (sheet re-renders). pass -> add --signoff (briefs/signoff/<id>.json)
realityhd thumbs <id> && realityhd catalog && swift test
"""

/// `realityhd brief <id> --theme T --name N`: writes a brief skeleton for the agent to complete.
func briefCommand(_ args: Args) throws {
    let root = try repoRoot()
    let theme = args.opt("--theme") ?? "Misc"
    let name = args.opt("--name")
    let force = args.flag("--force")
    guard let id = args.next() else { print(usage); return }
    let url = root.appendingPathComponent("briefs/\(id).json")
    if FileManager.default.fileExists(atPath: url.path) && !force { throw CLIError("exists: briefs/\(id).json (--force to overwrite)") }
    let b = PropBrief(id: id, name: name ?? id.replacingOccurrences(of: "-", with: " "), theme: theme,
                      summary: "TODO: one sentence, what it is and how it's built.", tags: ["prop"], size: [0, 0, 0],
                      materials: [], parts: [], style: "TODO: era, condition, finish")
    try b.write(url)
    print("briefs/\(id).json  next: fill size (m), parts, materials (realityhd context materials), style; then realityhd new prop \(id) --brief briefs/\(id).json")
}
