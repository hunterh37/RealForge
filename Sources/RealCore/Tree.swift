import simd

/// Parameters for one branching level (children of the previous level).
public struct BranchLevel: Sendable {
    /// Children per meter of parent length.
    public var density: Float
    /// Where on the parent children start/end (0 = base, 1 = tip).
    public var span: ClosedRange<Float>
    /// Child length as a fraction of parent length, before the profile.
    public var lengthRatio: Float
    /// Length multiplier over parent position t: conical (spruce) vs dome (oak).
    public var profile: Profile
    /// Angle from the parent axis, degrees, and its random spread.
    public var downAngle: Float
    public var downAngleSpread: Float
    /// Rotation around the parent between successive children, degrees (137.5 = phyllotaxis).
    public var rotate: Float
    /// Total bend over the branch length, degrees (random sign applied per branch).
    public var curve: Float
    /// Per-meter pull toward +Y (positive, phototropism) or -Y (negative, droop/pendulous).
    public var gravity: Float
    /// Child base radius relative to parent radius at the attach point.
    public var radiusRatio: Float
    /// Noise wobble amplitude, fraction of length.
    public var wobble: Float
    /// Chance that a child is a dead broken stub: 12 to 30 percent of its length, jagged end, no children
    /// or leaves. Children low on the parent die more often. 0 = none.
    public var stubChance: Float = 0
    /// Branches per whorl (0 = off, children spread along the parent). Conifers such as fir and pine put
    /// their branches out in rings at each year's node: children are grouped into rings of this many,
    /// evenly spaced around the parent, with the rings spaced along `span`. `density` still sets the total.
    public var whorl: Int = 0

    public enum Profile: Sendable { case flat, conical, dome, tapered }

    public init(density: Float, span: ClosedRange<Float> = 0.2...1, lengthRatio: Float, profile: Profile = .flat,
                downAngle: Float, downAngleSpread: Float = 10, rotate: Float = 137.5, curve: Float = 20,
                gravity: Float = 0, radiusRatio: Float = 0.6, wobble: Float = 0.04, stubChance: Float = 0, whorl: Int = 0) {
        self.density = density; self.span = span; self.lengthRatio = lengthRatio; self.profile = profile
        self.downAngle = downAngle; self.downAngleSpread = downAngleSpread; self.rotate = rotate; self.curve = curve
        self.gravity = gravity; self.radiusRatio = radiusRatio; self.wobble = wobble; self.stubChance = stubChance
        self.whorl = whorl
    }

    func shape(_ t: Float) -> Float {
        switch profile {
        case .flat: return 1
        case .conical: return 0.15 + 0.85 * (1 - t)
        case .dome: return 0.35 + 0.65 * sin(.pi * (0.25 + 0.75 * t))
        case .tapered: return 0.5 + 0.5 * (1 - t)
        }
    }
}

public struct LeafParams: Sendable {
    /// `outward`: clusters point out of the crown. `horizontal`: needle sprigs along the branch.
    /// `pendant`: strands hang along the twig toward the ground (weeping willow).
    public enum Orientation: Sendable { case outward, horizontal, pendant }
    /// Card width/height in meters (a card shows one leaf cluster or needle sprig from the atlas).
    public var cardSize: V2
    /// Cards per meter along leaf-bearing branches.
    public var density: Float
    /// Portion of each leaf-bearing branch carrying cards.
    public var span: ClosedRange<Float>
    public var orientation: Orientation
    /// 0 = flat card normals, 1 = normals from crown center (volumetric shading, game-standard trick).
    public var crownNormalBlend: Float
    /// Atlas grid (cells per side). Each card picks a random cell.
    public var atlasGrid: Int
    /// 0 = cards spread evenly over `span`; 1 = most cards cluster at the twig tips.
    public var tipCluster: Float = 0
    /// 0...1: tilts card faces toward the sky (leaves turn to the light).
    public var sunBias: Float = 0
    public init(cardSize: V2, density: Float, span: ClosedRange<Float> = 0.25...1, orientation: Orientation = .outward,
                crownNormalBlend: Float = 0.65, atlasGrid: Int = 2, tipCluster: Float = 0, sunBias: Float = 0) {
        self.cardSize = cardSize; self.density = density; self.span = span; self.orientation = orientation
        self.crownNormalBlend = crownNormalBlend; self.atlasGrid = atlasGrid; self.tipCluster = tipCluster; self.sunBias = sunBias
    }
}

public struct TreeSpecies: Sendable {
    public var name: String
    public var bark: MaterialKey
    public var leaf: MaterialKey
    public var height: Float
    public var trunkRadius: Float
    /// Radius at the top as a fraction of the base radius.
    public var trunkTipRatio: Float
    /// Trunk length as a fraction of height when the trunk splits into limbs (decurrent, e.g. oak).
    /// 1 = monopodial (leader continues to the top: spruce, birch).
    public var trunkFraction: Float
    public var trunkCurve: Float
    public var trunkWobble: Float
    /// Root flare: extra trunk radius at the ground as a fraction of the trunk radius, split into
    /// `flareLobes` buttresses.
    public var flare: Float
    public var flareLobes: Float
    public var levels: [BranchLevel]
    public var leaves: LeafParams
    /// Levels (indices into `levels`) whose branches carry leaves. Defaults to the last one.
    public var leafLevels: [Int]
    /// Bark texture tile size in meters (around the trunk circumference). Thinner branches wrap one
    /// repeat around and scale V to match, so twig bark is finer and never stretched.
    public var barkTile: Float
    /// Deepest branch level meshed as wood at LOD 0 (finer twigs are implied by the foliage cards).
    public var woodLevels: Int = 9
    /// Surface roots, one per flare lobe, as a length multiplier (0 = none). Needs `flare > 0`.
    public var roots: Float = 1
    /// Branch collar: extra radius where a branch leaves its parent, as a fraction of the branch radius.
    public var collar: Float = 0.45
    /// Bark darkening in branch crotches, 0...1.
    public var crotchOcclusion: Float = 0.55
    /// Leaf card multiplier: 1 = full summer crown, 0 = leafless (winter, dead).
    public var leafDensity: Float = 1
    /// Fraction of leaf cards drawn with `autumnLeaf` (0 = summer, 1 = full autumn colour).
    public var autumn: Float = 0
    public var autumnLeaf: MaterialKey? = nil
    /// Snapped trunk: fraction of the trunk length kept (0 = intact). The break is jagged.
    public var brokenTop: Float = 0

    public init(name: String, bark: MaterialKey, leaf: MaterialKey, height: Float, trunkRadius: Float, trunkTipRatio: Float = 0.12,
                trunkFraction: Float = 1, trunkCurve: Float = 6, trunkWobble: Float = 0.015, flare: Float = 0.35, flareLobes: Float = 5,
                levels: [BranchLevel], leaves: LeafParams, leafLevels: [Int]? = nil, barkTile: Float = 0.5) {
        self.name = name; self.bark = bark; self.leaf = leaf; self.height = height; self.trunkRadius = trunkRadius
        self.trunkTipRatio = trunkTipRatio; self.trunkFraction = trunkFraction; self.trunkCurve = trunkCurve
        self.trunkWobble = trunkWobble; self.flare = flare; self.flareLobes = flareLobes; self.levels = levels
        self.leaves = leaves; self.leafLevels = leafLevels ?? [levels.count - 1]; self.barkTile = barkTile
    }
}

/// Weber-Penn style recursive branching. The skeleton is built once per seed; each LOD meshes the same
/// skeleton with fewer sides, segments, levels and leaves, so LOD transitions keep the silhouette.
///
/// Per-vertex data: `extra.x` is the wind weight, continuous from trunk (about 0.1 at the top) through
/// limbs and twigs to leaf tips (up to 1). `extra.y` packs the motion layer and phase as
/// `layer + phase`: layer 0 trunk and roots, 1 limbs, 2 finer branches, 3 leaves; phase in 0..<1 is shared
/// by a limb and everything on it, and random per leaf card. `occlusion` carries crown shade, ground
/// contact and crotch darkening.
public struct TreeGenerator: Sendable {
    public struct Branch: Sendable {
        public var points: [V3]
        public var radii: [Float]
        public var level: Int          // -1 = trunk
        /// Limb phase in 0..<1, inherited by sub-branches.
        public var phase: Float
        public var length: Float
        /// Parent branch index (-1 for the trunk), junction point on the parent axis and parent tangent there.
        public var parent: Int = -1
        public var attach: V3 = .zero
        public var attachTangent: V3 = .up
        /// Wind weight per point, continuous with the parent at the junction.
        public var wind: [Float] = []
        /// Dead stub or snapped trunk: jagged end, no children, no leaves.
        public var broken: Bool = false
    }

    public let species: TreeSpecies
    public let seed: UInt64
    public private(set) var branches: [Branch] = []
    public private(set) var crownCenter: V3 = .zero
    public private(set) var crownRadius: Float = 1
    /// Root flare lobe angles (radians) in the trunk base frame.
    public private(set) var lobeAngles: [Float] = []

    public init(species: TreeSpecies, seed: UInt64) {
        self.species = species; self.seed = seed
        build()
    }

    // MARK: skeleton

    private mutating func build() {
        var rng = SeededRNG(seed: seed)
        let sp = species
        let h = rng.vary(sp.height, 0.12)
        let trunkLen = h * sp.trunkFraction
        let lean = rng.unitVector() * radians(sp.trunkCurve) * 0.5
        let trunkDir = simd_normalize(V3(lean.x, 1, lean.z))
        var trunk = stem(origin: V3(0, -0.08, 0), dir: trunkDir, length: trunkLen + 0.08, baseRadius: rng.vary(sp.trunkRadius, 0.08),
                         tipRatio: sp.trunkFraction < 1 ? 0.55 : sp.trunkTipRatio, curve: sp.trunkCurve, gravity: 0.02,
                         wobble: sp.trunkWobble, level: -1, rng: &rng)
        // Dense rings at the base so the buttresses are resolved.
        if sp.flare > 0 { Self.insertRings(&trunk, at: [0.04, 0.1, 0.17, 0.26, 0.38, 0.55, 0.8].map { $0 * sp.trunkRadius / 0.36 }) }
        if sp.brokenTop > 0 && sp.brokenTop < 1 { Self.truncate(&trunk, sp.brokenTop); trunk.broken = true }
        trunk.phase = rng.float()
        trunk.wind = trunk.points.map { 0.12 * pow(saturate($0.y / h), 2) }
        branches.append(trunk)

        let lobes = max(0, Int(sp.flareLobes.rounded()))
        let rot0 = rng.float(0...(2 * .pi))
        lobeAngles = (0..<lobes).map { rot0 + (Float($0) + rng.float(-0.22...0.22)) / Float(lobes) * 2 * .pi }

        grow(parentIndex: 0, levelIndex: 0, rng: &rng)

        // Crown sphere from leaf-bearing branch tips (for volumetric leaf normals).
        let tips = branches.filter { sp.leafLevels.contains($0.level) && !$0.broken }.map { $0.points[$0.points.count - 1] }
        if !tips.isEmpty {
            var lo = tips[0], hi = tips[0]
            for p in tips { lo = simd_min(lo, p); hi = simd_max(hi, p) }
            crownCenter = (lo + hi) / 2
            crownRadius = max(0.2, simd_length(hi - lo) / 2)
        } else { crownCenter = V3(0, h * 0.7, 0); crownRadius = h * 0.3 }
    }

    private func stem(origin: V3, dir: V3, length: Float, baseRadius: Float, tipRatio: Float, curve: Float, gravity: Float,
                      wobble: Float, level: Int, collarAt: Float = 0, parentRadius: Float = 0, rng: inout SeededRNG) -> Branch {
        let segs = max(3, min(24, Int((length * (level < 0 ? 5 : level == 0 ? 2.5 : 2)).rounded(.up)) + (level < 0 ? 3 : 1)))
        let bendAxis = dir.anyPerpendicular
        let bendAxis2 = simd_quatf(angle: rng.float(0...(2 * .pi)), axis: dir).act(bendAxis)
        let perStep = radians(curve) / Float(segs) * (rng.chance(0.5) ? 1 : -1)
        let nseed = UInt32(truncatingIfNeeded: rng.next())
        var p = origin, d = dir
        var pts = [p]
        let step = length / Float(segs)
        for i in 1...segs {
            let t = Float(i) / Float(segs)
            d = simd_quatf(angle: perStep, axis: bendAxis2).act(d)
            d = simd_normalize(d + V3(0, gravity * step, 0))
            let w = V3(Noise.perlin(V3(t * 3, 0.5, 0), seed: nseed), Noise.perlin(V3(t * 3, 4.5, 0), seed: nseed), Noise.perlin(V3(t * 3, 9.5, 0), seed: nseed))
            p += d * step + w * wobble * length / Float(segs) * 2.2
            // Branches never dip into the ground: deflect along it instead.
            if level >= 0 && p.y < 0.25 { p.y = 0.25; d = simd_normalize(V3(d.x, max(d.y, 0.05), d.z)) }
            pts.append(p)
        }
        var b = Branch(points: pts, radii: [], level: level, phase: 0, length: length)
        // Collar: rings where the branch leaves the parent, flared and blended into it.
        let collar = level >= 0 ? species.collar : 0
        if collar > 0 && collarAt > 0 {
            Self.insertRings(&b, at: baseRadius > 0.025 ? [collarAt * 0.7, collarAt, collarAt + baseRadius * 1.2, collarAt + baseRadius * 3] : [collarAt, collarAt + baseRadius * 2])
        }
        // Pipe-model-ish taper: fast near the tip, slow near the base.
        var s: Float = 0
        b.radii = b.points.indices.map { i in
            if i > 0 { s += simd_distance(b.points[i], b.points[i - 1]) }
            let t = min(1, s / max(length, 1e-4))
            var r = baseRadius * lerp(1, tipRatio, pow(t, 0.85))
            if collar > 0 && collarAt > 0 {
                r *= 1 + collar * (s < collarAt ? 1 : exp(-(s - collarAt) / (1.4 * baseRadius)))
                if s < collarAt { r = min(r, parentRadius * 0.95) }
            }
            return r
        }
        return b
    }

    /// Inserts polyline points at the given arc lengths from the start (skipped beyond the end).
    static func insertRings(_ b: inout Branch, at distances: [Float]) {
        var pts = [b.points[0]], radii: [Float] = b.radii.isEmpty ? [] : [b.radii[0]]
        var acc: Float = 0
        var queue = distances.filter { $0 > 1e-3 }.sorted()
        for i in 1..<b.points.count {
            let a = b.points[i - 1], c = b.points[i], seg = simd_distance(a, c)
            while let q = queue.first, q < acc + seg - 0.02 * seg {
                if q > acc + 0.02 * seg {
                    let u = (q - acc) / seg
                    pts.append(lerp(a, c, u))
                    if !radii.isEmpty { radii.append(lerp(b.radii[i - 1], b.radii[i], u)) }
                }
                queue.removeFirst()
            }
            pts.append(c); if !radii.isEmpty { radii.append(b.radii[i]) }
            acc += seg
        }
        b.points = pts; b.radii = radii
    }

    /// Keeps the first `fraction` of a branch (by point count), ending on an interpolated point.
    static func truncate(_ b: inout Branch, _ fraction: Float) {
        let f = fraction * Float(b.points.count - 1)
        let i = max(1, min(b.points.count - 1, Int(f.rounded(.up))))
        let u = f - Float(i - 1)
        b.points = Array(b.points[0..<i]) + [lerp(b.points[i - 1], b.points[i], min(1, u))]
        if !b.radii.isEmpty { b.radii = Array(b.radii[0..<i]) + [lerp(b.radii[i - 1], b.radii[i], min(1, u))] }
        b.length *= fraction
    }

    private mutating func grow(parentIndex: Int, levelIndex: Int, rng: inout SeededRNG) {
        guard levelIndex < species.levels.count else { return }
        let L = species.levels[levelIndex]
        let parent = branches[parentIndex]
        if parent.broken && parent.level >= 0 { return }
        let isTrunkSplit = parent.level == -1 && species.trunkFraction < 1
        var count = Int((L.density * parent.length).rounded())
        if isTrunkSplit { count = max(3, Int(L.density.rounded())) }
        guard count > 0 else { return }
        var rot = rng.float(0...360)
        var whorlT: Float = 0
        var children: [Int] = []
        let gain: Float = [0.3, 0.26, 0.22, 0.18][min(3, levelIndex)]
        for c in 0..<count {
            var t: Float
            if isTrunkSplit { t = rng.float(0.82...1.0) }
            else if L.whorl > 0 {
                // Whorls: ring w holds children w * whorl ..< (w + 1) * whorl, spread evenly around the parent.
                let rings = max(1, (count + L.whorl - 1) / L.whorl), w = c / L.whorl, k = c % L.whorl
                if k == 0 { whorlT = L.span.lowerBound + (L.span.upperBound - L.span.lowerBound) * (Float(w) + rng.float(0.35...0.65)) / Float(rings) }
                t = whorlT + rng.float(-0.006...0.006)
            }
            else { t = L.span.lowerBound + (L.span.upperBound - L.span.lowerBound) * (Float(c) + rng.float(0.15...0.85)) / Float(count) }
            t = min(t, 0.985)
            let (pos, tan, rad) = sample(parent, t)
            if L.whorl > 0 && !isTrunkSplit {
                if c % L.whorl == 0 { rot += 360 / Float(L.whorl) * 0.5 + rng.float(-20...20) }
                else { rot += 360 / Float(L.whorl) + rng.float(-12...12) }
            } else {
                rot += L.rotate + rng.float(-15...15)
            }
            let perp = simd_quatf(angle: radians(rot), axis: tan).act(tan.anyPerpendicular)
            let down = L.downAngle + rng.float(-L.downAngleSpread...L.downAngleSpread)
            let dir = simd_normalize(simd_quatf(angle: radians(down), axis: simd_cross(tan, perp).normalized).act(tan))
            var len = parent.length * L.lengthRatio * L.shape(t) * rng.vary(1, 0.18)
            if isTrunkSplit { len = species.height * L.lengthRatio * rng.vary(1, 0.15) }
            let r = max(0.004, rad * L.radiusRatio * rng.vary(1, 0.1))
            let stub = L.stubChance > 0 && rng.chance(L.stubChance * (1.5 - t))
            var tipRatio: Float = 0.08
            if stub { len *= rng.float(0.12...0.3); tipRatio = 0.7 }
            // Start slightly inside the parent so the junction is buried; the collar flares where it exits.
            let origin = pos - dir * rad * 0.4
            let sinA = max(0.35, simd_length(simd_cross(dir, tan)))
            let exitAt = rad * 0.4 + rad / sinA * 0.9
            var b = stem(origin: origin, dir: dir, length: len, baseRadius: r, tipRatio: tipRatio, curve: L.curve, gravity: L.gravity,
                         wobble: L.wobble, level: levelIndex, collarAt: exitAt, parentRadius: rad, rng: &rng)
            b.parent = parentIndex; b.attach = pos; b.attachTangent = tan; b.broken = stub
            b.phase = levelIndex == 0 ? rng.float() : (parent.phase + rng.float(-0.06...0.06) + 1).truncatingRemainder(dividingBy: 1)
            let w0 = sampleWind(parent, t)
            var acc: Float = 0
            b.wind = b.points.indices.map { i in
                if i > 0 { acc += simd_distance(b.points[i], b.points[i - 1]) }
                return min(0.92, w0 + gain * pow(min(1, acc / max(len, 1e-4)), 1.3))
            }
            branches.append(b)
            if !stub { children.append(branches.count - 1) }
        }
        for ci in children { var sub = rng.fork(ci); grow(parentIndex: ci, levelIndex: levelIndex + 1, rng: &sub) }
    }

    /// Position, tangent, radius at parameter t along a branch polyline.
    func sample(_ b: Branch, _ t: Float) -> (V3, V3, Float) {
        let f = t * Float(b.points.count - 1)
        let i = min(Int(f), b.points.count - 2), u = f - Float(i)
        let p = lerp(b.points[i], b.points[i + 1], u)
        return (p, simd_normalize(b.points[i + 1] - b.points[i]), lerp(b.radii[i], b.radii[i + 1], u))
    }

    func sampleWind(_ b: Branch, _ t: Float) -> Float {
        guard b.wind.count == b.points.count else { return 0 }
        let f = t * Float(b.points.count - 1)
        let i = min(Int(f), b.points.count - 2), u = f - Float(i)
        return lerp(b.wind[i], b.wind[i + 1], u)
    }

    // MARK: meshing

    public struct LODSettings: Sendable {
        public var sidesScale: Float
        public var minSides: Int
        public var maxLevel: Int          // deepest branch level meshed as wood
        public var leafFraction: Float    // fraction of leaf cards kept
        public var leafScale: Float       // card size multiplier to keep crown density
        public var pointStride: Int       // skip polyline points
        public init(sidesScale: Float, minSides: Int, maxLevel: Int, leafFraction: Float, leafScale: Float, pointStride: Int) {
            self.sidesScale = sidesScale; self.minSides = minSides; self.maxLevel = maxLevel
            self.leafFraction = leafFraction; self.leafScale = leafScale; self.pointStride = pointStride
        }
        public static let lod0 = LODSettings(sidesScale: 1, minSides: 3, maxLevel: 9, leafFraction: 1, leafScale: 1, pointStride: 1)
        public static let lod1 = LODSettings(sidesScale: 0.55, minSides: 3, maxLevel: 1, leafFraction: 0.45, leafScale: 1.45, pointStride: 2)
        public static let lod2 = LODSettings(sidesScale: 0.3, minSides: 3, maxLevel: 0, leafFraction: 0.16, leafScale: 2.4, pointStride: 3)
    }

    public func model(_ lodIn: LODSettings = .lod0) -> Model {
        var lod = lodIn
        lod.maxLevel = min(lod.maxLevel, species.woodLevels)
        let sp = species
        var bark = Surface(material: sp.bark)
        var leaves = Surface(material: sp.leaf)
        var autumnLeaves = Surface(material: sp.autumnLeaf ?? sp.leaf)
        var rng = SeededRNG(seed: seed &+ 0xBEEF)
        var kids = [[Int]](repeating: [], count: branches.count)
        for (i, b) in branches.enumerated() where b.parent >= 0 { kids[b.parent].append(i) }

        // Trunk base frame: flare lobes and surface roots share it.
        let trunk = branches[0]
        let t0 = simd_normalize(trunk.points[1] - trunk.points[0])
        let n0 = simd_normalize(V3(1, 0, 0) - t0 * t0.x), b0 = simd_cross(t0, n0)
        let r0 = trunk.radii[0]

        for (bi, b) in branches.enumerated() {
            let woody = b.level <= lod.maxLevel
            if woody {
                var idx = Array(stride(from: 0, to: b.points.count, by: lod.pointStride))
                if idx.last != b.points.count - 1 { idx.append(b.points.count - 1) }
                let pts = idx.map { b.points[$0] }, radii = idx.map { b.radii[$0] }, wind = idx.map { b.wind[$0] }
                let maxSides = b.level < 0 ? 28 : (b.level == 0 ? 14 : 8)
                let sides = max(lod.minSides, min(maxSides, Int((b.radii[b.radii.count / 4] * 190 * lod.sidesScale).rounded()) + (b.level < 0 ? 6 : 2)))
                let ripple: ((Float, Float) -> Float)? = (b.level < 0 && sp.flare > 0) ? trunkRipple(r0) : nil
                let code: Float = b.level < 0 ? 0 : (b.level == 0 ? 1 : 2)
                var tube = barkTube(pts, radii: radii, sides: sides, wind: wind, extraY: code + b.phase * 0.999,
                                    capEnd: b.level >= 0 || b.broken, jagged: b.broken, frame: b.level < 0 ? n0 : nil,
                                    ripple: ripple, rng: &rng)
                // Crotches: own junction plus every meshed child's junction.
                let junctions = (b.parent >= 0 ? [bi] : []) + kids[bi].filter { branches[$0].level <= lod.maxLevel }
                let crotch = junctions.map { j -> (V3, Float, V3) in
                    let c = branches[j]
                    let cd = simd_normalize(c.points[min(2, c.points.count - 1)] - c.points[0])
                    return (c.attach, c.radii[min(2, c.radii.count - 1)], simd_normalize(cd + c.attachTangent))
                }
                tube.occlusion = tube.positions.map { p in
                    let d = simd_length(p - crownCenter) / crownRadius
                    var ao = saturate(0.45 + 0.55 * smoothstep(0.3, 1.1, d)) * (0.55 + 0.45 * smoothstep(0, 0.6, p.y))
                    if b.level < 0 && sp.roots > 0 && p.y < r0 * 1.5 {
                        ao *= 0.75 + 0.25 * smoothstep(0, r0 * 1.5, p.y)
                    }
                    for (c, r, bis) in crotch {
                        let q = p - c, dl = simd_length(q)
                        let fall = exp(-pow(dl / (r * 2.4 + 0.02), 2))
                        if fall < 0.01 { continue }
                        let side = saturate(0.5 + 0.5 * simd_dot(q / max(dl, 1e-5), bis))
                        ao *= 1 - sp.crotchOcclusion * fall * (0.35 + 0.65 * side)
                    }
                    return saturate(ao)
                }
                bark.append(tube)
            }
            // Leaves: on leaf levels, or on the deepest woody level when finer levels are culled.
            let deepest = min(lodIn.maxLevel, sp.levels.count - 1)
            let carries = sp.leafLevels.contains(b.level) || (b.level == deepest && sp.leafLevels.allSatisfy { $0 > deepest })
            if carries && !b.broken && sp.leafDensity > 0 { addLeaves(b, to: &leaves, autumn: &autumnLeaves, lod: lod, rng: &rng) }
        }

        // Surface roots along the flare lobes, running out and down into the soil.
        if sp.roots > 0 && sp.flare > 0 && lod.sidesScale >= 0.5 {
            for a in lobeAngles {
                var rr = SeededRNG(seed: seed &+ UInt64(bitPattern: Int64(a * 1000)))
                let dir = n0 * cos(a) + b0 * sin(a)
                let side = simd_normalize(simd_cross(V3.up, dir))
                let len = r0 * rr.float(1.4...2.4) * sp.roots * (1 + 0.6 * sp.flare)
                let wig = rr.float(-0.3...0.3)
                var pts: [V3] = [], radii: [Float] = []
                for j in 0...7 {
                    let s = Float(j) / 7
                    let d = r0 * 0.3 + s * len
                    let rad = r0 * (0.4 * pow(1 - s, 0.9) + 0.07) * (0.6 + 0.6 * sp.flare)
                    // Top of the root rides just above the soil, then the tip dives under it.
                    let y = r0 * 0.9 * pow(1 - s, 2.6) + rad * 0.1 - (0.05 + rad) * pow(s, 4)
                    pts.append(V3(trunk.points[0].x, 0, trunk.points[0].z) + dir * d + side * wig * s * s * len * 0.4 + V3(0, y, 0))
                    radii.append(rad)
                }
                var tube = barkTube(pts, radii: radii, sides: max(5, Int(9 * lod.sidesScale)), wind: Array(repeating: 0, count: pts.count),
                                    extraY: 0, capEnd: true, jagged: false, frame: nil, ripple: nil, rng: &rr)
                let jc = V3(trunk.points[0].x, 0, trunk.points[0].z) + dir * r0 * 1.1 + V3(0, r0 * 0.5, 0)
                tube.occlusion = tube.positions.map { p in
                    let crotch = exp(-pow(simd_distance(p, jc) / (r0 * 0.9), 2)) * 0.45
                    return saturate((0.4 + 0.45 * smoothstep(-0.03, r0 * 0.8, p.y)) * (1 - crotch))
                }
                bark.append(tube)
            }
        }

        var m = Model(name: sp.name)
        bark.computeTangents()
        m.add(bark)
        if !leaves.isEmpty { leaves.computeTangents(); m.add(leaves) }
        if !autumnLeaves.isEmpty { autumnLeaves.computeTangents(); m.add(autumnLeaves) }
        return m
    }

    /// Radius multiplier around the trunk base: a broad flare plus one buttress per lobe angle.
    private func trunkRipple(_ r0: Float) -> (Float, Float) -> Float {
        let flare = species.flare, lobes = lobeAngles
        let ns = UInt32(truncatingIfNeeded: seed)
        return { a, v in
            let th = a * 2 * .pi
            var bump: Float = 0
            for l in lobes {
                var d = abs(th - l).truncatingRemainder(dividingBy: 2 * .pi)
                d = min(d, 2 * .pi - d)
                bump = max(bump, exp(-(d * d) / 0.07))
            }
            let broad = exp(-v / (r0 * 2.5)), butt = exp(-v / (r0 * 1.8))
            let n = Noise.perlin(V3(cos(th) * 1.5, sin(th) * 1.5, v * 2), seed: ns)
            return 1 + flare * (0.45 * broad + 1.5 * butt * butt * bump) + 0.05 * n
        }
    }

    /// Bark tube. U wraps a whole number of bark tiles around the circumference; on branches thinner than
    /// one tile, V is scaled by the same factor so the bark keeps its aspect (finer bark, no stretching).
    private func barkTube(_ path: [V3], radii: [Float], sides: Int, wind: [Float], extraY: Float, capEnd: Bool, jagged: Bool,
                          frame: V3?, ripple: ((Float, Float) -> Float)?, rng: inout SeededRNG) -> Surface {
        var s = Surface(material: species.bark)
        let tile = species.barkTile
        let rRef = radii[radii.count / 4]
        let circ = 2 * .pi * max(rRef, 1e-3)
        let repeats = max(1, (circ / tile).rounded())
        let uTotal = repeats * tile, k = uTotal / circ
        var tangents: [V3] = []
        for i in path.indices {
            let a = path[max(0, i - 1)], b = path[min(path.count - 1, i + 1)]
            tangents.append((b - a).normalized)
        }
        var normal = frame.map { simd_normalize($0 - tangents[0] * simd_dot($0, tangents[0])) } ?? tangents[0].anyPerpendicular
        var v: Float = 0
        for i in path.indices {
            if i > 0 {
                v += simd_distance(path[i], path[i - 1])
                let t0 = tangents[i - 1], t1 = tangents[i]
                let axis = simd_cross(t0, t1), sl = simd_length(axis)
                if sl > 1e-6 { normal = simd_quatf(angle: atan2(sl, simd_dot(t0, t1)), axis: axis / sl).act(normal) }
                normal = simd_normalize(normal - t1 * simd_dot(normal, t1))
            }
            let bin = simd_cross(tangents[i], normal)
            for j in 0...sides {
                let t = Float(j) / Float(sides), a = t * 2 * .pi
                let dir = normal * cos(a) + bin * sin(a)
                let r = radii[i] * (ripple?(t, v) ?? 1)
                s.add(path[i] + dir * r, dir, V2(t * uTotal, v * k), extra: V2(wind[i], extraY))
            }
        }
        let row = UInt32(sides + 1)
        for i in 0..<(path.count - 1) { for j in 0..<sides {
            let a = UInt32(i) * row + UInt32(j)
            s.quad(a, a + 1, a + row + 1, a + row)
        }}
        guard capEnd else { return s }
        let li = path.count - 1, tEnd = tangents[li], rEnd = radii[li], wEnd = wind[li]
        let last = UInt32(li) * row
        if jagged {
            // Splintered break: a ring of uneven spikes, then a low cone of torn wood inside it.
            let bin = simd_cross(tEnd, normal)
            var spikes = (0..<sides).map { _ in rEnd * (0.15 + 2.2 * pow(rng.float(), 2.5)) }
            spikes.append(spikes[0])
            let ring = UInt32(s.positions.count)
            for j in 0...sides {
                let a = Float(j) / Float(sides) * 2 * .pi
                let dir = normal * cos(a) + bin * sin(a)
                s.add(path[li] + dir * rEnd * 0.82 + tEnd * spikes[j], dir, V2(Float(j) / Float(sides) * uTotal, (v + spikes[j]) * k),
                      extra: V2(wEnd, extraY))
            }
            let tip = s.add(path[li] + tEnd * rEnd * 0.35, tEnd, V2(uTotal / 2, (v + rEnd) * k), extra: V2(wEnd, extraY))
            for j in 0..<UInt32(sides) {
                s.quad(last + j, last + j + 1, ring + j + 1, ring + j)
                s.tri(ring + j, ring + j + 1, tip)
            }
        } else {
            let tip = s.add(path[li] + tEnd * rEnd * 0.5, tEnd, V2(uTotal / 2, (v + rEnd) * k), extra: V2(wEnd, extraY))
            for j in 0..<UInt32(sides) { s.tri(last + j, last + j + 1, tip) }
        }
        return s
    }

    private func addLeaves(_ b: Branch, to s: inout Surface, autumn a: inout Surface, lod: LODSettings, rng: inout SeededRNG) {
        let sp = species, lp = sp.leaves
        // When finer levels are culled, the culled twigs' leaves are represented by bigger, sparser cards
        // spread over this branch.
        let n = max(1, Int((lp.density * b.length * lod.leafFraction * sp.leafDensity).rounded()))
        let g = lp.atlasGrid, cell = 1 / Float(g)
        let cluster = 1 / (1 + 2 * lp.tipCluster)
        for i in 0..<n {
            let u = (Float(i) + rng.float(0...1)) / Float(n)
            let t = lp.span.lowerBound + (lp.span.upperBound - lp.span.lowerBound) * pow(u, cluster)
            let (pos, tan, _) = sample(b, min(t, 1))
            let outward = simd_normalize(pos - crownCenter + V3(0, 0.15, 0))
            let size = lp.cardSize * lod.leafScale * rng.vary(1, 0.2)
            var up: V3, normal: V3
            switch lp.orientation {
            case .outward:
                // Card grows from the twig outward/upward, rotated randomly around its axis.
                up = simd_normalize(tan * 0.55 + outward * 0.6 + rng.unitVector() * 0.45 + V3(0, 0.1, 0))
                normal = simd_quatf(angle: rng.float(0...(2 * .pi)), axis: up).act(up.anyPerpendicular)
            case .horizontal:
                // Needle sprigs: lie along the branch, facing mostly up, with slight droop.
                up = simd_normalize(tan + rng.unitVector() * 0.25 + V3(0, -0.05, 0))
                let side = simd_normalize(simd_cross(up, V3.up))
                normal = simd_normalize(simd_cross(side, up) + rng.unitVector() * 0.3)
                if normal.y < 0 { normal = -normal }
            case .pendant:
                // Strands hang from the twig: card axis points down, face turned outward.
                up = simd_normalize(V3(tan.x * 0.35, -1, tan.z * 0.35) + rng.unitVector() * 0.12)
                let flat = V3(outward.x, 0, outward.z).normalized
                normal = simd_quatf(angle: rng.float(-0.8...0.8), axis: up).act(simd_normalize(flat - up * simd_dot(flat, up)))
            }
            // Leaves turn toward the sky: tilt the face up, then re-orthogonalize the card axis.
            if lp.sunBias > 0 && lp.orientation != .pendant {
                if normal.y < 0 { normal = -normal }
                normal = simd_normalize(lerp(normal, V3.up, lp.sunBias))
                let u2 = up - normal * simd_dot(up, normal)
                up = simd_length(u2) > 1e-3 ? simd_normalize(u2) : normal.anyPerpendicular
            }
            let right = simd_normalize(simd_cross(up, normal))
            let fwd = simd_cross(right, up)
            let rot = simd_quatf(simd_float3x3(right, up, fwd))
            let cx = Float(rng.int(0...(g - 1))), cy = Float(rng.int(0...(g - 1)))
            // Shading normal: blend card normal toward the crown sphere normal.
            let crownN = simd_normalize(pos + rot.act(V3(0, size.y * 0.5, 0)) - crownCenter)
            let shadeN = simd_normalize(lerp(fwd, crownN, lp.crownNormalBlend))
            var card = Prim.card(width: size.x, height: size.y, cell: (V2(cx * cell, cy * cell), V2(cell, cell)),
                                 material: sp.leaf, normal: shadeN)
            let xf = Xform(translation: pos, rotation: rot)
            card.positions = card.positions.map(xf.point).map { V3($0.x, max($0.y, 0.03), $0.z) }
            // Crown self-shadowing: interior and underside cards are darker (baked AO).
            card.occlusion = card.positions.map { p in
                let d = simd_length(p - crownCenter) / crownRadius
                let under = saturate((crownCenter.y - p.y) / crownRadius) * 0.25
                return saturate(0.45 + 0.55 * smoothstep(0.1, 1.0, d) - under)
            }
            // Leaves ride the branch (its weight at the attach point) and flutter on top with their own phase.
            let wb = sampleWind(b, min(t, 1))
            let ey = 3 + rng.float() * 0.999
            card.extra = [V2(min(1, wb + 0.06), ey), V2(min(1, wb + 0.06), ey), V2(min(1, wb + 0.16), ey), V2(min(1, wb + 0.16), ey)]
            if sp.autumnLeaf != nil && sp.autumn > 0 && rng.chance(sp.autumn) {
                card.material = a.material; a.append(card)
            } else { s.append(card) }
        }
    }
}
