import simd

/// Thermal and browning constants for one family of food. Values are SI (m, s, kg, J, K) with
/// temperatures in degrees Celsius. Defaults per `Cook.Kind` come from food science references
/// (heat capacity and diffusivity of lean meat, protein denaturation bands, Maillard onset).
public struct CookProfile: Sendable, Equatable {
    /// Thermal diffusivity (m^2/s). Lean meat ~1.3e-7, vegetables ~1.5e-7, batter ~1.1e-7.
    public var diffusivity: Float
    /// Volumetric heat capacity rho * c (J/m^3K). Meat ~3.6e6.
    public var heatCapacity: Float
    /// Surface water the face must boil off before it can rise past 100 C (kg/m^2, includes water the
    /// tissue keeps pushing out while it cooks).
    public var surfaceWater: Float
    /// Temperature band over which the food "cooks" (protein sets, starch gelatinizes, cell walls soften).
    public var setBand: ClosedRange<Float>
    /// Seconds at or above the top of `setBand` to reach full doneness (0 = instant on reaching it).
    /// Roots and starches need time at temperature, proteins mostly need the temperature.
    public var setTime: Float
    /// Surface temperature where browning starts (Maillard / caramelization).
    public var browningOnset: Float
    /// Browning rate (1/s) at `browningOnset + 40 C`; doubles about every `browningDoubling` C.
    public var browningRate: Float
    public var browningDoubling: Float
    /// Core temperature that makes it safe and done (chicken 74 C). nil = no safety threshold.
    public var safeCore: Float?
    public init(diffusivity: Float, heatCapacity: Float, surfaceWater: Float, setBand: ClosedRange<Float>, setTime: Float,
                browningOnset: Float, browningRate: Float, browningDoubling: Float, safeCore: Float?) {
        self.diffusivity = diffusivity; self.heatCapacity = heatCapacity; self.surfaceWater = surfaceWater
        self.setBand = setBand; self.setTime = setTime; self.browningOnset = browningOnset
        self.browningRate = browningRate; self.browningDoubling = browningDoubling; self.safeCore = safeCore
    }
}

/// Cooking physics: food pieces as 1D slabs through their thinnest axis with six face states, heated by
/// conduction from a pan, convection from air or oven, and limited by surface water boiling off.
/// Deterministic and allocation-free per step; runs anywhere (no RealityKit).
public enum Cook {
    public enum Kind: String, Sendable, CaseIterable {
        case protein, vegetable, root, egg, dairy, batter, leaf
    }

    public static func profile(_ k: Kind) -> CookProfile {
        switch k {
        case .protein:   // chicken breast: ~10-12 min for 2 cm at medium-high, flipped once
            return CookProfile(diffusivity: 1.35e-7, heatCapacity: 3.6e6, surfaceWater: 0.6, setBand: 55...72, setTime: 0,
                               browningOnset: 115, browningRate: 1.0 / 200, browningDoubling: 16, safeCore: 74)
        case .vegetable: // onion, pepper: soften in minutes, caramelize at high sugar
            return CookProfile(diffusivity: 1.5e-7, heatCapacity: 3.9e6, surfaceWater: 1.4, setBand: 75...95, setTime: 150,
                               browningOnset: 112, browningRate: 1.0 / 260, browningDoubling: 18, safeCore: nil)
        case .root:      // carrot, potato: slow to soften
            return CookProfile(diffusivity: 1.4e-7, heatCapacity: 3.7e6, surfaceWater: 1.0, setBand: 80...98, setTime: 420,
                               browningOnset: 120, browningRate: 1.0 / 300, browningDoubling: 18, safeCore: nil)
        case .egg:       // whites set 62-80 C
            return CookProfile(diffusivity: 1.4e-7, heatCapacity: 3.8e6, surfaceWater: 0.5, setBand: 62...80, setTime: 0,
                               browningOnset: 125, browningRate: 1.0 / 120, browningDoubling: 15, safeCore: 71)
        case .dairy:     // butter: melts, foams (water boils off), browns, burns
            return CookProfile(diffusivity: 1.0e-7, heatCapacity: 2.4e6, surfaceWater: 0.4, setBand: 30...36, setTime: 0,
                               browningOnset: 120, browningRate: 1.0 / 70, browningDoubling: 14, safeCore: nil)
        case .batter:    // pancakes, cookies, cake: sets ~ 90-100 C, crust browns
            return CookProfile(diffusivity: 1.1e-7, heatCapacity: 3.0e6, surfaceWater: 0.9, setBand: 70...98, setTime: 20,
                               browningOnset: 120, browningRate: 1.0 / 150, browningDoubling: 16, safeCore: 93)
        case .leaf:      // garlic, herbs, spinach: fast, burns fast
            return CookProfile(diffusivity: 1.6e-7, heatCapacity: 3.9e6, surfaceWater: 0.25, setBand: 60...85, setTime: 20,
                               browningOnset: 110, browningRate: 1.0 / 80, browningDoubling: 14, safeCore: nil)
        }
    }

    /// Object-space face index for a signed axis: 0 +X, 1 -X, 2 +Y, 3 -Y, 4 +Z, 5 -Z.
    public static func face(axis: Int, positive: Bool) -> Int { axis * 2 + (positive ? 0 : 1) }

    /// The face pointing most along `dir` (object space) and how aligned it is (0...1).
    public static func face(facing dir: V3) -> (face: Int, alignment: Float) {
        let a = simd_abs(dir)
        let axis = a.x >= a.y && a.x >= a.z ? 0 : (a.y >= a.z ? 1 : 2)
        let positive = dir[axis] >= 0
        return (face(axis: axis, positive: positive), a[axis] / max(simd_length(dir), 1e-6))
    }
}

/// What touches a food piece this step.
public struct HeatContact: Sendable {
    /// Temperature of the cooking surface or liquid (C).
    public var surface: Float
    /// Contact conductance (W/m^2K): dry pan ~250, oiled pan ~450, boiling water ~1500, deep oil ~400.
    public var conductance: Float
    /// Face in contact (object space, see `Cook.face`), and fraction of that face touching (0...1).
    public var face: Int
    public var fraction: Float
    /// Surrounding air or oven temperature (C) and its convective coefficient (still air ~12,
    /// oven ~25, convection oven ~45, lid on a pan ~30).
    public var air: Float
    public var airConductance: Float
    /// Submerged (boiling, poaching, deep frying): every face sees `surface`.
    public var submerged: Bool
    public init(surface: Float, conductance: Float, face: Int, fraction: Float = 1, air: Float = 24, airConductance: Float = 12, submerged: Bool = false) {
        self.surface = surface; self.conductance = conductance; self.face = face; self.fraction = fraction
        self.air = air; self.airConductance = airConductance; self.submerged = submerged
    }
    /// Sitting in air only (counter, plate).
    public static func air(_ t: Float = 24, conductance h: Float = 10) -> HeatContact {
        HeatContact(surface: t, conductance: 0, face: 3, fraction: 0, air: t, airConductance: h)
    }
}

/// Thermal state of one food piece. `extent` is the piece's object-space bounding size; the slab runs
/// along its thinnest axis (`slabAxis`), discretized into `layers` nodes.
public struct FoodThermal: Sendable {
    public static let layers = 9
    public var profile: CookProfile
    public var extent: V3
    public private(set) var slabAxis: Int
    /// Node temperatures (C) from the slab's -axis face to its +axis face.
    public private(set) var t: [Float]
    /// Highest temperature each node has reached (protein setting is irreversible).
    public private(set) var peak: [Float]
    /// Seconds each node has spent at or above the top of the set band.
    public private(set) var held: [Float]
    /// Remaining surface water per face (kg/m^2).
    public private(set) var water: [Float]
    /// Browning per face: 0 raw, 1 deep golden brown, 2 burnt black.
    public private(set) var browning: [Float]
    /// Surface temperature per face (C), for the shader and for sizzle loudness.
    public private(set) var faceTemp: [Float]
    /// Water boiled off in the last step (kg/s): drives sizzle and steam.
    public private(set) var steam: Float = 0
    /// Simulated seconds of cooking (any face above 60 C).
    public private(set) var cookedSeconds: Float = 0

    public init(profile: CookProfile, extent: V3, temperature: Float = 4) {
        self.profile = profile
        self.extent = simd_max(extent, V3(repeating: 0.002))
        slabAxis = extent.x <= extent.y && extent.x <= extent.z ? 0 : (extent.y <= extent.z ? 1 : 2)
        t = Array(repeating: temperature, count: Self.layers)
        peak = t
        held = Array(repeating: 0, count: Self.layers)
        water = Array(repeating: profile.surfaceWater, count: 6)
        browning = Array(repeating: 0, count: 6)
        faceTemp = Array(repeating: temperature, count: 6)
    }

    public var thickness: Float { extent[slabAxis] }
    /// Center node temperature (thermometer reading at the thickest point).
    public var core: Float { t[Self.layers / 2] }
    /// Coldest node: what a careful cook probes for.
    public var coldest: Float { t.min() ?? 0 }

    /// Doneness of a node (0 raw ... 1 fully set), from its peak temperature and time held.
    public func doneness(node i: Int) -> Float {
        let b = profile.setBand
        let byTemp = simd_smoothstep(b.lowerBound, b.upperBound, peak[i])
        guard profile.setTime > 0 else { return byTemp }
        return byTemp * min(1, 0.35 + 0.65 * held[i] / profile.setTime)
    }
    /// Doneness of the interior (center node): drives cut faces.
    public var coreDoneness: Float { doneness(node: Self.layers / 2) }
    /// Doneness of the outer layer: drives the outside of the piece.
    public var surfaceDoneness: Float { max(doneness(node: 0), doneness(node: Self.layers - 1)) * 0.5 + coreDoneness * 0.5 }
    /// True once every node has passed the profile's safe core temperature.
    public var isSafe: Bool { profile.safeCore.map { s in peak.allSatisfy { $0 >= s } } ?? true }
    /// Highest browning on any face.
    public var maxBrowning: Float { browning.max() ?? 0 }
    /// Browning packed for the cook shader: (+X, +Y, +Z) and (-X, -Y, -Z).
    public var browningPos: V3 { V3(browning[0], browning[2], browning[4]) }
    public var browningNeg: V3 { V3(browning[1], browning[3], browning[5]) }

    /// Splits off a piece after a cut: same temperatures, browning and water, new extent.
    public func piece(extent e: V3) -> FoodThermal {
        var p = self
        p.extent = simd_max(e, V3(repeating: 0.002))
        let axis = e.x <= e.y && e.x <= e.z ? 0 : (e.y <= e.z ? 1 : 2)
        if axis != slabAxis {
            // New slab direction: start from the mean so energy is roughly conserved.
            let mean = t.reduce(0, +) / Float(t.count), meanPeak = peak.reduce(0, +) / Float(peak.count)
            p.t = Array(repeating: mean, count: Self.layers)
            p.peak = Array(repeating: meanPeak, count: Self.layers)
            p.held = Array(repeating: held.reduce(0, +) / Float(held.count), count: Self.layers)
            p.slabAxis = axis
        }
        return p
    }

    /// Advances `dt` seconds. Internally sub-steps for stability. Returns watts drawn from the contact
    /// surface (positive = the food cools the pan).
    @discardableResult
    public mutating func step(_ dt: Float, contact c: HeatContact) -> Float {
        let n = Self.layers
        let L = thickness, dx = L / Float(n - 1)
        let alpha = profile.diffusivity, rc = profile.heatCapacity
        // Area of the contact face (m^2), from the two other extents.
        func area(_ face: Int) -> Float { let ax = face / 2; var a: Float = 1; for k in 0..<3 where k != ax { a *= extent[k] }; return a }
        let stable = 0.4 * dx * dx / alpha
        let edgeMass = rc * dx * 0.5   // J/K per m^2 of a face node
        let steps = max(1, Int((dt / min(stable, 0.08)).rounded(.up)))
        let h = dt / Float(steps)
        var drawn: Float = 0, steamAcc: Float = 0
        let lo = Cook.face(axis: slabAxis, positive: false), hi = Cook.face(axis: slabAxis, positive: true)
        for _ in 0..<steps {
            // Heat flux into each face (W/m^2) from contact + air.
            var flux = [Float](repeating: 0, count: 6)
            for f in 0..<6 {
                let surfT = f == lo ? t[0] : (f == hi ? t[n - 1] : t.reduce(0, +) / Float(n))
                var q = c.airConductance * (c.air - surfT)
                if c.submerged || f == c.face {
                    let frac = c.submerged ? 1 : c.fraction
                    q = q * (1 - frac) + c.conductance * (c.surface - surfT) * frac
                }
                // Evaporative cooling: a wet face cannot pass 100 C; excess energy boils water off.
                if water[f] > 0, surfT >= 99.5, q > 0 {
                    let boiled = min(water[f], q * h / 2.26e6)
                    water[f] -= boiled
                    steamAcc += boiled * area(f)
                    q -= boiled * 2.26e6 / h
                } else if water[f] > 0, surfT > 60 {
                    // Simmering moisture loss below the boil (slow drying).
                    let e = water[f] * 0.0009 * h * (surfT - 60) / 40
                    water[f] -= e
                }
                flux[f] = q
                faceTemp[f] = surfT
                if f == c.face, c.fraction > 0, !c.submerged { drawn += c.conductance * (c.surface - surfT) * c.fraction * area(f) }
            }
            // Side faces (not on the slab axis) feed every node through their area / volume ratio.
            var sideGain: Float = 0
            for f in 0..<6 where f != lo && f != hi { sideGain += flux[f] * area(f) }
            let volume = extent.x * extent.y * extent.z
            let sideRate = sideGain / (rc * volume)
            var next = t
            for i in 0..<n {
                let left = i > 0 ? t[i - 1] : t[i], right = i < n - 1 ? t[i + 1] : t[i]
                var d = alpha * (left - 2 * t[i] + right) / (dx * dx)
                if i == 0 { d = alpha * (t[1] - t[0]) / (dx * dx) * 2 + flux[lo] / edgeMass }
                if i == n - 1 { d = alpha * (t[n - 2] - t[n - 1]) / (dx * dx) * 2 + flux[hi] / edgeMass }
                next[i] = t[i] + (d + sideRate) * h
            }
            // Wet faces clamp at 100 C (the energy went into steam above).
            if water[lo] > 0 { next[0] = min(next[0], 100) }
            if water[hi] > 0 { next[n - 1] = min(next[n - 1], 100) }
            t = next
            for i in 0..<n {
                peak[i] = max(peak[i], t[i])
                if t[i] >= profile.setBand.upperBound { held[i] += h }
            }
            // Browning per face from its surface temperature (dry faces only brown; wet ones steam).
            for f in 0..<6 {
                let ts = f == lo ? t[0] : (f == hi ? t[n - 1] : faceTemp[f])
                let wetness = min(1, water[f] / max(profile.surfaceWater * 0.15, 1e-4))
                guard ts > profile.browningOnset else { continue }
                let rate = profile.browningRate * pow(2, (ts - profile.browningOnset - 40) / profile.browningDoubling)
                // Past golden brown, darkening slows (crust insulates) until char sets in above ~205 C.
                let slow: Float = browning[f] < 1 ? 1 : (ts > 205 ? 0.9 : 0.22)
                browning[f] = min(2.2, browning[f] + rate * slow * (1 - 0.85 * wetness) * h)
            }
            if t.contains(where: { $0 > 60 }) { cookedSeconds += h }
        }
        steam = steamAcc / dt
        return drawn
    }
}

/// A pan, pot or sheet on a heat source: lumped metal mass with a fat layer.
public struct VesselThermal: Sendable {
    public enum Metal: Sendable {
        case castIron, stainless, aluminum, carbonSteel
        /// (mass per m^2 of base kg, specific heat J/kgK)
        var props: (Float, Float) {
            switch self {
            case .castIron: return (55, 460)
            case .stainless: return (22, 500)
            case .aluminum: return (12, 900)
            case .carbonSteel: return (25, 490)
            }
        }
    }
    public var metal: Metal
    /// Inner floor radius (m).
    public var radius: Float
    public var temperature: Float
    /// Fat in the pan (kg). Its smoke point decides when it smokes; it also raises contact conductance.
    public var fat: Float = 0
    public var smokePoint: Float = 205
    /// Water in the vessel (kg): caps temperature at 100 C while it boils off.
    public var water: Float = 0
    /// Lid on: traps heat and steam (raises air temperature around the food).
    public var lidded = false

    public init(metal: Metal, radius: Float, temperature: Float = 22) {
        self.metal = metal; self.radius = radius; self.temperature = temperature
    }

    public var area: Float { .pi * radius * radius }
    public var heatCapacity: Float { let (kg, c) = metal.props; return kg * area * c + water * 4186 + fat * 2000 }
    public var isSmoking: Bool { fat > 0 && temperature >= smokePoint }
    /// Fat starts shimmering ~30 C under its smoke point: the classic "add the protein now" cue.
    public var isShimmering: Bool { fat > 0 && temperature >= smokePoint - 30 }
    public var isBoiling: Bool { water > 0.01 && temperature >= 99.5 }

    /// Contact for food sitting on the floor (face down = `face`).
    public func contact(face: Int, fraction: Float = 1) -> HeatContact {
        if water > 0.05 {
            return HeatContact(surface: min(temperature, 100), conductance: 1500, face: face, fraction: 1, air: min(temperature, 100), airConductance: 600, submerged: true)
        }
        let air: Float = lidded ? min(temperature, 100) * 0.9 : 24 + (temperature - 24) * 0.12
        return HeatContact(surface: temperature, conductance: fat > 0.002 ? 560 : 280, face: face, fraction: fraction,
                           air: air, airConductance: lidded ? 30 : 14)
    }

    /// Advances `dt` with burner input `watts` (absorbed by the pan) and `foodDraw` watts lost to food.
    public mutating func step(_ dt: Float, watts: Float, foodDraw: Float) {
        // Losses: convection plus radiation from the pan floor and walls (~2x floor area).
        let a = area * 2.2
        let tk = temperature + 273.15
        let rad = 0.6 * 5.67e-8 * a * (tk * tk * tk * tk - 297 * 297 * 297 * 297)
        let conv = 11 * a * (temperature - 24)
        var q = watts - foodDraw - rad - conv
        if water > 0, temperature >= 99.5, q > 0 {
            let boiled = min(water, q * dt / 2.26e6)
            water -= boiled
            q -= boiled * 2.26e6 / dt
        }
        temperature += q * dt / heatCapacity
        if water > 0 { temperature = min(temperature, 100) }
        // Fat degrades past the smoke point (burns off slowly).
        if fat > 0, temperature > smokePoint + 20 { fat = max(0, fat - 1.2e-7 * (temperature - smokePoint) * dt) }
    }
}

/// Gas burner: knob angle -> absorbed power. A 30 in range burner is ~2.6-3.5 kW input; roughly 40 %
/// reaches a pan.
public struct Burner: Sendable {
    /// Rated input (W).
    public var rated: Float
    /// Knob setting 0 (off) ... 1 (high). Low simmer sits near 0.12.
    public var level: Float = 0
    public init(rated: Float = 3000) { self.rated = rated }
    public var isOn: Bool { level > 0.01 }
    /// Power absorbed by a vessel of floor radius `r` (small pans catch less flame).
    public func absorbed(radius r: Float) -> Float {
        guard isOn else { return 0 }
        let catchFrac = min(1, 0.45 + r * 3.2)
        return rated * (0.1 + 0.9 * level) * 0.42 * catchFrac
    }
}

/// Oven cavity: preheats along a first-order curve, holds with thermostat swing.
public struct OvenThermal: Sendable {
    public var setpoint: Float = 0
    public var temperature: Float = 22
    /// Seconds to reach ~63 % of a setpoint change (real ovens: ~12 min to 180 C).
    public var timeConstant: Float = 420
    public init() {}
    public var isPreheated: Bool { setpoint > 0 && temperature >= setpoint - 8 }
    public mutating func step(_ dt: Float) {
        let target = setpoint > 0 ? setpoint : 22
        let k = 1 - exp(-dt / timeConstant)
        temperature += (target - temperature) * k
    }
    /// Contact for food on a sheet in the oven: hot air all around plus the sheet underneath.
    public func contact(face: Int) -> HeatContact {
        HeatContact(surface: temperature * 0.93, conductance: 90, face: face, fraction: 1, air: temperature, airConductance: 28)
    }
}
