import simd
import Foundation

/// Corner quoins: ten courses of alternating long and short dressed limestone blocks standing proud
/// of the wall, each course 0.2 m, with 5 mm joints. A pair, one stack per face of an external corner.
public struct QuoinStones: RealAsset {
    public static let id = "quoin-stones"
    public static let summary = "Corner quoins, 2.0 m: ten courses of alternating long and short dressed blocks on both faces."
    public static let tags = ["prop", "architecture", "facade", "trim", "stone"]
    public static let budget = 7_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 10, distance: 3.6)

    public var courses: Int = 10
    public var courseHeight: Float = 0.2
    public var longBlock: Float = 0.5
    public var shortBlock: Float = 0.3
    public var stone: MaterialKey = "stone.limestone"
    public var alt: MaterialKey = "stone.limestone-sooted"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let h = courseHeight, joint: Float = 0.005, proud: Float = 0.05
        // Wall core as brick so the quoins read against it: corner column at the origin.
        FA.box(&m, V3(0.5, h * Float(courses), 0.5), V3(0.25, h * Float(courses) / 2, -0.25), "brick.common", r: 0.002)
        for i in 0..<courses {
            let long = i % 2 == 0
            let y = h * (Float(i) + 0.5)
            let lenFront = long ? longBlock : shortBlock
            let lenSide = long ? shortBlock : longBlock
            let mat = rng.chance(0.2) ? alt : stone
            // Front face: blocks run from the corner (x = 0) toward +X.
            FA.box(&m, V3(lenFront - joint, h - joint, proud), V3(lenFront / 2, y, proud / 2), mat, r: 0.004)
            // Side face: runs back along -Z from the corner.
            FA.box(&m, V3(proud, h - joint, lenSide - joint), V3(-proud / 2, y, -lenSide / 2), mat, r: 0.004)
            // Corner block cap overlapping both faces.
            FA.box(&m, V3(proud, h - joint, proud), V3(-proud / 2, y, proud / 2), mat, r: 0.004)
        }
        groundAO(&m, height: 0.15, floor: 0.8)
        return LODModel(FC.place(m))
    }
}
