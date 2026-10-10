import simd
import Foundation

/// Thrown capture pod: packed, a 5 cm brass-banded ball with a leather grip ring and the folded net
/// visible through its vents; deployed, a 45 cm dome of fine netting held out by a brass rim of
/// weighted beads. Part `net` switches between the two (`packed`, `deploy`).
public struct CaptureNetPod: RealArticulated {
    public static let id = "capture-net-pod"
    public static let summary = "Capture net pod: 5 cm brass-banded ball (packed) that opens to a 45 cm weighted net dome (deploy); articulated net."
    public static let tags = ["prop", "tool", "metal", "handheld", "articulated"]
    public static let budget = 9_000
    public static let preview = PreviewHint(azimuth: 35, elevation: 30, distance: 1.0, studio: true)

    public var podDiameter: Float = 0.05
    public var netDiameter: Float = 0.45
    public var brass: MaterialKey = "metal.brass-aged"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [4])
        let r = podDiameter / 2
        rig.part("net", pivot: V3(0, r, 0), joint: .fixed, options: 2)
        for lod in 0..<2 {
            let L = lod...lod, sub = lod == 0 ? 8 : 4
            // Packed: folded net ball inside two brass hemispheres with vents and a leather grip band.
            rig.add(Prim.cubeSphere(subdivisions: sub, material: "fabric.canvas:D8D0B8") { V3(0, r, 0) + $0 * r * 0.93 * (1 + 0.05 * Noise.fbm($0 * 6, octaves: 2)) }, to: "net", option: 0, lods: L)
            for s: Float in [1, -1] {
                for k in 0..<6 {
                    let a = Float(k) / 6 * 2 * .pi
                    // Meridian brass ribs over each hemisphere.
                    var pts: [V3] = []
                    for i in 0...8 {
                        let t = Float(i) / 8 * (.pi / 2 - 0.2) + 0.2
                        pts.append(V3(cos(a) * sin(t) * r, r + s * cos(t) * r, sin(a) * sin(t) * r) * 1.0)
                    }
                    rig.add(Prim.tube(pts, radii: pts.map { _ in 0.0015 }, sides: lod == 0 ? 6 : 4, seamTile: 0.01, material: brass, capEnd: true), to: "net", option: 0, lods: L)
                }
                rig.add(Prim.cylinder(radius: r * 0.25, height: 0.003, bevel: 0.0008, segments: 16, material: brass),
                        Xform(translation: V3(0, s > 0 ? 2 * r - 0.001 : 0.0, 0)), to: "net", option: 0, lods: L)
            }
            rig.add(Prim.torus(major: r * 1.0, minor: 0.0032, segments: lod == 0 ? 40 : 20, sides: 8, minorY: 0.006, material: "vinyl.seat-grey:5A2018"),
                    Xform(translation: V3(0, r, 0)), to: "net", option: 0, lods: L)
            // Deployed: netting dome with a beaded brass rim on the ground.
            let R = netDiameter / 2, H: Float = 0.16
            let nr = lod == 0 ? 40 : 16, nl = lod == 0 ? 12 : 5
            var dome = Surface(material: "insect.netting")
            for j in 0...nl {
                let t = Float(j) / Float(nl)
                let rr = R * sin((1 - t) * .pi / 2) * 0.99 + 0.0001
                let y = 0.006 + H * cos((1 - t) * .pi / 2) * (1 - 0.15 * t)
                for i in 0...nr {
                    let a = Float(i) / Float(nr) * 2 * .pi
                    let sag = 1 - 0.06 * abs(sin(a * 4)) * (1 - t)
                    _ = dome.add(V3(cos(a) * rr * sag, y, sin(a) * rr * sag), .up, V2(a * R, t * R))
                }
            }
            let row = UInt32(nr + 1)
            for j in 0..<UInt32(nl) { for i in 0..<UInt32(nr) { let a = j * row + i; dome.quad(a, a + 1, a + row + 1, a + row) } }
            dome.recomputeNormals(weldSeams: false); dome.computeTangents()
            rig.add(dome, to: "net", option: 1, lods: L)
            rig.add(Prim.torus(major: R * 0.99, minor: 0.003, segments: lod == 0 ? 72 : 28, sides: 6, material: brass), Xform(translation: V3(0, 0.004, 0)), to: "net", option: 1, lods: L)
            for k in 0..<(lod == 0 ? 12 : 6) {
                let a = Float(k) / Float(lod == 0 ? 12 : 6) * 2 * .pi
                rig.add(Prim.cubeSphere(subdivisions: lod == 0 ? 3 : 2, material: brass) { V3(cos(a) * R * 0.99, 0.008, sin(a) * R * 0.99) + $0 * 0.008 }, to: "net", option: 1, lods: L)
            }
            rig.add(Prim.cubeSphere(subdivisions: sub, material: brass) { V3(0, 0.006 + H + 0.004, 0) + $0 * V3(0.012, 0.007, 0.012) }, to: "net", option: 1, lods: L)
        }
        rig.states = [RigState("packed"), RigState("deploy", [:], options: ["net": 1])]
        groundAO(&rig, height: 0.05, floor: 0.6)
        return rig
    }
}
