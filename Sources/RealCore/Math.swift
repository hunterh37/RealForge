import simd

public typealias V2 = SIMD2<Float>
public typealias V3 = SIMD3<Float>
public typealias V4 = SIMD4<Float>

@inlinable public func lerp<T: FloatingPoint>(_ a: T, _ b: T, _ t: T) -> T { a + (b - a) * t }
@inlinable public func lerp(_ a: V3, _ b: V3, _ t: Float) -> V3 { a + (b - a) * t }
@inlinable public func saturate(_ x: Float) -> Float { min(max(x, 0), 1) }
@inlinable public func smoothstep(_ e0: Float, _ e1: Float, _ x: Float) -> Float {
    let t = saturate((x - e0) / (e1 - e0)); return t * t * (3 - 2 * t)
}
@inlinable public func radians(_ deg: Float) -> Float { deg * .pi / 180 }

public extension V3 {
    static let up = V3(0, 1, 0)
    var normalized: V3 { let l = simd_length(self); return l > 1e-12 ? self / l : V3(0, 1, 0) }
    /// Any unit vector perpendicular to self.
    var anyPerpendicular: V3 {
        let a: V3 = abs(x) < 0.9 ? V3(1, 0, 0) : V3(0, 1, 0)
        return simd_normalize(simd_cross(self, a))
    }
}

public extension simd_quatf {
    static let identity = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    init(degrees: Float, axis: V3) { self.init(angle: radians(degrees), axis: simd_normalize(axis)) }
}

/// Affine transform used while assembling meshes.
public struct Xform: Sendable, Equatable {
    public var translation: V3
    public var rotation: simd_quatf
    public var scale: V3
    public init(translation: V3 = .zero, rotation: simd_quatf = .identity, scale: V3 = V3(1, 1, 1)) {
        self.translation = translation; self.rotation = rotation; self.scale = scale
    }
    public static let identity = Xform()
    public var matrix: simd_float4x4 {
        let r = simd_float4x4(rotation)
        var m = r
        m.columns.0 *= scale.x; m.columns.1 *= scale.y; m.columns.2 *= scale.z
        m.columns.3 = V4(translation, 1)
        return m
    }
    @inlinable public func point(_ p: V3) -> V3 { rotation.act(p * scale) + translation }
    /// Normals use inverse-transpose; for non-uniform scale divide by scale before rotating.
    @inlinable public func normal(_ n: V3) -> V3 { simd_normalize(rotation.act(n / scale)) }
    @inlinable public func direction(_ d: V3) -> V3 { simd_normalize(rotation.act(d * scale)) }
}

/// SplitMix64. Deterministic across platforms; every generator takes a seed.
public struct SeededRNG: RandomNumberGenerator, Sendable {
    public var state: UInt64
    public init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 &+ 0xD1B54A32D192ED03 }
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    public mutating func float() -> Float { Float(next() >> 40) / Float(1 << 24) }
    public mutating func float(_ r: ClosedRange<Float>) -> Float { r.lowerBound + (r.upperBound - r.lowerBound) * float() }
    /// base * (1 ± spread)
    public mutating func vary(_ base: Float, _ spread: Float) -> Float { base * (1 + float(-spread...spread)) }
    public mutating func int(_ r: ClosedRange<Int>) -> Int { r.lowerBound + Int(next() % UInt64(r.count)) }
    public mutating func chance(_ p: Float) -> Bool { float() < p }
    public mutating func pick<T>(_ a: [T]) -> T { a[Int(next() % UInt64(a.count))] }
    public mutating func unitVector() -> V3 {
        let z = float(-1...1), t = float(0...(2 * .pi)), r = (1 - z * z).squareRoot()
        return V3(r * cos(t), z, r * sin(t))
    }
    public mutating func inDisc(radius: Float) -> V2 {
        let r = radius * float().squareRoot(), t = float(0...(2 * .pi))
        return V2(r * cos(t), r * sin(t))
    }
    public func fork(_ i: Int) -> SeededRNG { SeededRNG(seed: state ^ (UInt64(truncatingIfNeeded: i) &* 0xA24BAED4963EE407)) }
}
