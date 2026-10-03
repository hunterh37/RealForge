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

    public enum Profile: Sendable { case flat, conical, dome, tapered }

    public init(density: Float, span: ClosedRange<Float> = 0.2...1, lengthRatio: Float, profile: Profile = .flat,
                downAngle: Float, downAngleSpread: Float = 10, rotate: Float = 137.5, curve: Float = 20,
                gravity: Float = 0, radiusRatio: Float = 0.6, wobble: Float = 0.04) {
        self.density = density; self.span = span; self.lengthRatio = lengthRatio; self.profile = profile
        self.downAngle = downAngle; self.downAngleSpread = downAngleSpread; self.rotate = rotate; self.curve = curve
        self.gravity = gravity; self.radiusRatio = radiusRatio; self.wobble = wobble
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
    public enum Orientation: Sendable { case outward, horizontal }
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
    public init(cardSize: V2, density: Float, span: ClosedRange<Float> = 0.25...1, orientation: Orientation = .outward,
                crownNormalBlend: Float = 0.65, atlasGrid: Int = 2) {
        self.cardSize = cardSize; self.density = density; self.span = span; self.orientation = orientation
        self.crownNormalBlend = crownNormalBlend; self.atlasGrid = atlasGrid
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
    public var flare: Float
    public var flareLobes: Float
    public var levels: [BranchLevel]
    public var leaves: LeafParams
    /// Levels (indices into `levels`) whose branches carry leaves. Defaults to the last one.
    public var leafLevels: [Int]
    /// Bark texture tile size in meters (around the trunk circumference).
    public var barkTile: Float
    /// Deepest branch level meshed as wood at LOD 0 (finer twigs are implied by the foliage cards).
    public var woodLevels: Int = 9

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
public struct TreeGenerator: Sendable {
    public struct Branch: Sendable {
        public var points: [V3]
        public var radii: [Float]
        public var level: Int          // -1 = trunk
        public var phase: Float
        public var length: Float
    }

    public let species: TreeSpecies
    public let seed: UInt64
    public private(set) var branches: [Branch] = []
    public private(set) var crownCenter: V3 = .zero
    public private(set) var crownRadius: Float = 1

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
        let trunk = stem(origin: V3(0, -0.08, 0), dir: trunkDir, length: trunkLen + 0.08, baseRadius: rng.vary(sp.trunkRadius, 0.08),
                         tipRatio: sp.trunkFraction < 1 ? 0.55 : sp.trunkTipRatio, curve: sp.trunkCurve, gravity: 0.02,
                         wobble: sp.trunkWobble, level: -1, rng: &rng)
        branches.append(trunk)
        grow(parentIndex: 0, levelIndex: 0, rng: &rng)

        // Crown sphere from leaf-bearing branch tips (for volumetric leaf normals).
        let tips = branches.filter { sp.leafLevels.contains($0.level) }.map { $0.points[$0.points.count - 1] }
        if !tips.isEmpty {
            var lo = tips[0], hi = tips[0]
            for p in tips { lo = simd_min(lo, p); hi = simd_max(hi, p) }
            crownCenter = (lo + hi) / 2
            crownRadius = max(0.2, simd_length(hi - lo) / 2)
        } else { crownCenter = V3(0, h * 0.7, 0); crownRadius = h * 0.3 }
    }

    private func stem(origin: V3, dir: V3, length: Float, baseRadius: Float, tipRatio: Float, curve: Float, gravity: Float,
                      wobble: Float, level: Int, rng: inout SeededRNG) -> Branch {
        let segs = max(3, min(24, Int((length * (level < 0 ? 5 : 3.5)).rounded(.up)) + (level < 1 ? 3 : 1)))
        let bendAxis = dir.anyPerpendicular
        let bendAxis2 = simd_quatf(angle: rng.float(0...(2 * .pi)), axis: dir).act(bendAxis)
        let perStep = radians(curve) / Float(segs) * (rng.chance(0.5) ? 1 : -1)
        let nseed = UInt32(truncatingIfNeeded: rng.next())
        var p = origin, d = dir
        var pts = [p], radii = [baseRadius]
        let step = length / Float(segs)
        for i in 1...segs {
            let t = Float(i) / Float(segs)
            d = simd_quatf(angle: perStep, axis: bendAxis2).act(d)
            d = simd_normalize(d + V3(0, gravity * step, 0))
            let w = V3(Noise.perlin(V3(t * 3, 0.5, 0), seed: nseed), Noise.perlin(V3(t * 3, 4.5, 0), seed: nseed), Noise.perlin(V3(t * 3, 9.5, 0), seed: nseed))
            p += d * step + w * wobble * length / Float(segs) * 2.2
            pts.append(p)
            // Pipe-model-ish taper: fast near the tip, slow near the base.
            radii.append(baseRadius * lerp(1, tipRatio, pow(t, 0.85)))
        }
        return Branch(points: pts, radii: radii, level: level, phase: rng.float(0...6.28), length: length)
    }

    private mutating func grow(parentIndex: Int, levelIndex: Int, rng: inout SeededRNG) {
        guard levelIndex < species.levels.count else { return }
        let L = species.levels[levelIndex]
        let parent = branches[parentIndex]
        let isTrunkSplit = parent.level == -1 && species.trunkFraction < 1
        var count = Int((L.density * parent.length).rounded())
        if isTrunkSplit { count = max(3, Int(L.density.rounded())) }
        guard count > 0 else { return }
        var rot = rng.float(0...360)
        var children: [Int] = []
        for c in 0..<count {
            var t: Float
            if isTrunkSplit { t = rng.float(0.82...1.0) }
            else { t = L.span.lowerBound + (L.span.upperBound - L.span.lowerBound) * (Float(c) + rng.float(0.15...0.85)) / Float(count) }
            t = min(t, 0.985)
            let (pos, tan, rad) = sample(parent, t)
            rot += L.rotate + rng.float(-15...15)
            let perp = simd_quatf(angle: radians(rot), axis: tan).act(tan.anyPerpendicular)
            let down = L.downAngle + rng.float(-L.downAngleSpread...L.downAngleSpread)
            let dir = simd_normalize(simd_quatf(angle: radians(down), axis: simd_cross(tan, perp).normalized).act(tan))
            var len = parent.length * L.lengthRatio * L.shape(t) * rng.vary(1, 0.18)
            if isTrunkSplit { len = species.height * L.lengthRatio * rng.vary(1, 0.15) }
            let r = max(0.004, rad * L.radiusRatio * rng.vary(1, 0.1))
            // Start slightly inside the parent so the junction is buried.
            let origin = pos - dir * rad * 0.4
            let b = stem(origin: origin, dir: dir, length: len, baseRadius: r, tipRatio: 0.08, curve: L.curve, gravity: L.gravity,
                         wobble: L.wobble, level: levelIndex, rng: &rng)
            branches.append(b)
            children.append(branches.count - 1)
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
        var bark = Surface(material: species.bark)
        var leaves = Surface(material: species.leaf)
        var rng = SeededRNG(seed: seed &+ 0xBEEF)
        let maxH = max(0.1, branches.reduce(0) { max($0, $1.points.map(\.y).max() ?? 0) })

        for b in branches {
            let woody = b.level <= lod.maxLevel
            if woody {
                let idx = Array(stride(from: 0, to: b.points.count, by: lod.pointStride)) + (((b.points.count - 1) % lod.pointStride == 0) ? [] : [b.points.count - 1])
                let pts = idx.map { b.points[$0] }, radii = idx.map { b.radii[$0] }
                let sides = max(lod.minSides, min(20, Int((b.radii[0] * 260 * lod.sidesScale).rounded()) + (b.level < 0 ? 4 : 0)))
                // Wind weight: 0 at ground, grows with height and with branch order.
                let weights = pts.enumerated().map { (i, p) -> Float in
                    let t = Float(i) / Float(max(1, pts.count - 1))
                    let base = b.level < 0 ? 0 : 0.25 + 0.2 * Float(b.level)
                    return saturate((p.y / maxH) * 0.35 + base * t)
                }
                let flare = b.level < 0 ? species.flare : 0, lobes = species.flareLobes
                let ns = UInt32(truncatingIfNeeded: seed)
                let ripple: ((Float, Float) -> Float)? = flare > 0 ? { a, v in
                    let k = exp(-v * 4.5)
                    let n = Noise.perlin(V3(cos(a * 2 * .pi) * 1.5, sin(a * 2 * .pi) * 1.5, v * 2), seed: ns)
                    return 1 + flare * k * (0.55 + 0.45 * sin(a * 2 * .pi * lobes + n * 2.5)) + 0.05 * n
                } : nil
                var tube = Prim.tube(pts, radii: radii, sides: sides, seamTile: species.barkTile, material: species.bark,
                                     weights: weights, phase: b.phase, capEnd: b.level >= 0, rippling: ripple)
                // Wood inside the crown sits in shade; trunk base meets the ground.
                tube.occlusion = tube.positions.map { p in
                    let d = simd_length(p - crownCenter) / crownRadius
                    return saturate(0.45 + 0.55 * smoothstep(0.3, 1.1, d)) * (0.55 + 0.45 * smoothstep(0, 0.6, p.y))
                }
                bark.append(tube)
            }
            // Leaves: on leaf levels, or on the deepest woody level when finer levels are culled.
            let deepest = min(lodIn.maxLevel, species.levels.count - 1)
            let carries = species.leafLevels.contains(b.level) || (b.level == deepest && species.leafLevels.allSatisfy { $0 > deepest })
            if carries { addLeaves(b, to: &leaves, lod: lod, rng: &rng) }
        }
        var m = Model(name: species.name)
        bark.computeTangents()
        m.add(bark)
        leaves.computeTangents()
        m.add(leaves)
        return m
    }

    private func addLeaves(_ b: Branch, to s: inout Surface, lod: LODSettings, rng: inout SeededRNG) {
        let lp = species.leaves
        // When finer levels are culled, the culled twigs' leaves are represented by bigger, sparser cards
        // spread over this branch.
        let n = max(1, Int((lp.density * b.length * lod.leafFraction).rounded()))
        let g = lp.atlasGrid, cell = 1 / Float(g)
        for i in 0..<n {
            let t = lp.span.lowerBound + (lp.span.upperBound - lp.span.lowerBound) * (Float(i) + rng.float(0...1)) / Float(n)
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
            }
            let right = simd_normalize(simd_cross(up, normal))
            let fwd = simd_cross(right, up)
            let rot = simd_quatf(simd_float3x3(right, up, fwd))
            let cx = Float(rng.int(0...(g - 1))), cy = Float(rng.int(0...(g - 1)))
            // Shading normal: blend card normal toward the crown sphere normal.
            let crownN = simd_normalize(pos + rot.act(V3(0, size.y * 0.5, 0)) - crownCenter)
            let shadeN = simd_normalize(lerp(fwd, crownN, lp.crownNormalBlend))
            var card = Prim.card(width: size.x, height: size.y, cell: (V2(cx * cell, cy * cell), V2(cell, cell)),
                                 material: species.leaf, normal: shadeN, extra: V2(1, b.phase))
            // Crown normals are world-space already; keep them when transforming.
            let xf = Xform(translation: pos, rotation: rot)
            card.positions = card.positions.map(xf.point)
            // Crown self-shadowing: interior and underside cards are darker (baked AO).
            card.occlusion = card.positions.map { p in
                let d = simd_length(p - crownCenter) / crownRadius
                let under = saturate((crownCenter.y - p.y) / crownRadius) * 0.25
                return saturate(0.45 + 0.55 * smoothstep(0.1, 1.0, d) - under)
            }
            // Lower card vertices bend less than tips.
            card.extra = [V2(0.75, b.phase), V2(0.75, b.phase), V2(1, b.phase), V2(1, b.phase)]
            s.append(card)
        }
    }
}
