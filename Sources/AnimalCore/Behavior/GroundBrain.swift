import Foundation
import simd
import RealCore

public enum GroundPhase: String, Sendable, Equatable { case arriving, foraging, alert, resting, climbing, perched, descending, fleeing, leaving, gone }

public enum GroundEvent: Sendable, Equatable {
    case arrived
    case fed
    case spooked
    /// Took food from the offered hand.
    case handFed
    case climbed(item: String?)
    case left
}

/// A rabbit, squirrel, chipmunk or hedgehog visiting the yard.
public final class GroundBrain {
    public let id: Int
    public let profile: GroundProfile
    /// Center of mass, yard-local.
    public private(set) var position: V3
    public private(set) var yaw: Float
    /// Body tilt in degrees (nose up) on top of the rest posture: climbing, rearing.
    public private(set) var tilt: Float = 0
    public private(set) var input = GroundMotionInput()
    public private(set) var phase: GroundPhase = .arriving
    public private(set) var stay: Float
    public var trust: Float
    public private(set) var siteID: Int?
    public private(set) var speedNow: Float = 0

    private var rng: SeededRNG
    private var events: [GroundEvent] = []
    private var goal = V2.zero
    private var phaseTime: Float = 0
    private var hold: Float = 0
    private var gaitPhase: Float = 0
    private var fear: Float = 0
    private var blinkTimer: Float = 2
    private var blinkPhase: Float = -1
    private var exit = V2.zero
    private var climbTarget: PerchSite?
    private var handCooldown: Float = 0
    private var hopT: Float = 0
    private var headAim = V2.zero
    private var headNow = V2.zero
    private var lookTimer: Float = 0
    private var restMode = 0
    private let standY: Float

    public init(id: Int, profile: GroundProfile, spawn: V2, yaw: Float, stay: Float, trust: Float, groundY: Float, seed: UInt64) {
        self.id = id; self.profile = profile; self.stay = stay; self.trust = trust; self.yaw = yaw
        standY = groundY + profile.anatomy.standHeight
        position = V3(spawn.x, standY, spawn.y)
        rng = SeededRNG(seed: seed)
        input.gait = profile.behavior.gait
        events.append(.arrived)
    }

    public func drainEvents() -> [GroundEvent] { let e = events; events.removeAll(keepingCapacity: true); return e }
    public var isGone: Bool { phase == .gone }
    var xz: V2 { V2(position.x, position.z) }

    // MARK: update

    public func update(dt rawDt: Float, view: YardView, book: PerchBook) {
        let dt = min(rawDt, 1 / 20)
        guard phase != .gone else { return }
        phaseTime += dt; fear = max(0, fear - dt); handCooldown = max(0, handCooldown - dt)
        stay -= dt
        if phase != .fleeing, phase != .leaving, phase != .climbing, phase != .perched, phase != .descending, threatened(view) { flee(view); return }

        switch phase {
        case .arriving: walk(to: goal == .zero ? pickForage(view) : goal, speed: 0.6, dt: dt, view: view) { self.phase = .foraging; self.phaseTime = 0; self.goal = .zero }
        case .foraging: forage(dt: dt, view: view, book: book)
        case .alert: alert(dt: dt, view: view)
        case .resting: rest(dt: dt, view: view)
        case .climbing: climb(dt: dt, up: true, book: book)
        case .perched: perch(dt: dt, view: view)
        case .descending: climb(dt: dt, up: false, book: book)
        case .fleeing: run(dt: dt, view: view)
        case .leaving: walk(to: exit, speed: 0.8, dt: dt, view: view) { self.phase = .gone; self.events.append(.left) }
        case .gone: break
        }
        updateFace(dt: dt, view: view)
        input.phase = gaitPhase
        input.speed = min(1, speedNow / max(0.2, profile.behavior.run * AnimalTuning.groundSpeedScale))
    }

    private func threatened(_ v: YardView) -> Bool {
        let b = profile.behavior
        let r = b.skittishRadius * (1 - 0.6 * trust)
        let head = V2(v.player.head.x, v.player.head.z)
        if simd_distance(head, xz) < r && v.player.headSpeed > 0.6 { return true }
        if simd_distance(head, xz) < r * 0.4 && trust < 0.4 { return true }
        if let h = v.player.handPosition, v.player.handSpeed > 1.2, simd_distance(V2(h.x, h.z), xz) < max(r, 0.8) { return true }
        for n in v.noises where simd_distance(V2(n.at.x, n.at.z), xz) < 3 * n.loudness * (1 - 0.5 * trust) { return true }
        return v.weather.kind == .storm
    }

    private func flee(_ v: YardView) {
        events.append(.spooked)
        fear = 15; stay = 0; phaseTime = 0
        let head = V2(v.player.head.x, v.player.head.z)
        // Nearest cover away from the person, else the nearest edge.
        let cover = v.cover.filter { simd_distance($0, head) > 0.6 }.min { simd_distance($0, xz) < simd_distance($1, xz) }
        if let c = cover, simd_distance(c, xz) < 6 { goal = c; phase = .fleeing; restMode = 1 } else { chooseExit(v, away: head); goal = exit; phase = .fleeing; restMode = 0 }
        tilt = 0
    }

    private func chooseExit(_ v: YardView, away: V2?) {
        var d = away.map { xz - $0 } ?? V2(rng.float(-1...1), rng.float(-1...1))
        if simd_length(d) < 0.1 { d = V2(1, 0) }
        d = simd_normalize(d)
        // Walk to the nearest edge along that heading.
        var p = xz
        for _ in 0..<60 where v.contains(p) { p += d * 0.5 }
        exit = p + d * 2
    }

    // MARK: movement

    private func pickForage(_ v: YardView) -> V2 {
        if let f = v.forage.randomElement(using: &rng), rng.chance(0.6) { return f + V2(rng.float(-0.3...0.3), rng.float(-0.3...0.3)) }
        if let c = v.cover.randomElement(using: &rng), rng.chance(0.3) { return c + V2(rng.float(-0.5...0.5), rng.float(0.2...0.8)) }
        return V2(rng.float(v.min.x + 0.6...v.max.x - 0.6), rng.float(v.min.y + 0.6...v.max.y - 0.6))
    }

    /// Walks toward `target`, steering around obstacles. Calls `arrive` within 0.12 m.
    private func walk(to target: V2, speed: Float, dt: Float, view: YardView, arrive: () -> Void) {
        let to = target - xz
        let dist = simd_length(to)
        if dist < 0.12 { speedNow = 0; arrive(); return }
        var dir = to / dist
        for o in view.obstacles {
            let d = xz - o.center, l = simd_length(d)
            if l < o.radius + 0.35 && l > 0.001 {
                let push = (o.radius + 0.35 - l) / 0.35
                let tangent = V2(-d.y, d.x) / l
                dir = simd_normalize(dir + (d / l) * push * 0.9 + tangent * push * (simd_dot(tangent, dir) >= 0 ? 0.6 : -0.6))
            }
        }
        let want = speed * profile.behavior.walk / 0.6 * AnimalTuning.groundSpeedScale * (phase == .fleeing ? 1 : 1)
        let tgtYaw = headingOf(V3(dir.x, 0, dir.y))
        let turn = wrapAngle(tgtYaw - yaw)
        yaw = wrapAngle(yaw + max(-6 * dt, min(6 * dt, turn * 8 * dt)))
        let k = max(0.15, 1 - abs(turn) / 1.6)
        speedNow += (want * k - speedNow) * min(1, dt * 6)
        let f = forward(yaw: yaw)
        position += V3(f.x, 0, f.z) * speedNow * dt
        position = V3(max(view.min.x - 6, min(view.max.x + 6, position.x)), position.y, max(view.min.y - 6, min(view.max.y + 6, position.z)))
        advanceGait(dt)
        input.sit = 0
        position.y = standY + bounce()
    }

    private func advanceGait(_ dt: Float) {
        let stride: Float = profile.behavior.gait == .hop ? 0.28 : (profile.behavior.gait == .bound ? 0.22 : 0.12)
        gaitPhase = (gaitPhase + speedNow * dt / stride).truncatingRemainder(dividingBy: 1)
    }

    private func bounce() -> Float {
        switch profile.behavior.gait {
        case .hop: let u = min(1, max(0, (gaitPhase - 0.15) / 0.65)); return 0.1 * sin(u * .pi) * min(1, speedNow / 1.2)
        case .bound: let u = min(1, max(0, (gaitPhase - 0.1) / 0.7)); return 0.045 * sin(u * .pi) * min(1, speedNow / 1.5)
        case .walk: return 0
        }
    }

    // MARK: states

    private func forage(dt: Float, view: YardView, book: PerchBook) {
        if stay <= 0 { chooseExit(view, away: nil); phase = .leaving; phaseTime = 0; return }
        if goal == .zero { goal = pickForage(view) }
        if hold > 0 {
            hold -= dt; speedNow = 0
            input.sit = restMode == 2 ? 1 : 0; input.paws = restMode == 2 ? 1 : 0
            input.jaw = restMode == 2 ? 0.5 + 0.5 * sin(phaseTime * 14) : 0
            position.y += (standY - position.y) * min(1, dt * 10)
            tilt += ((restMode == 2 ? 40 : 0) - tilt) * min(1, dt * 6)
            if restMode == 3 { headAim = V2(0, -50 + 40 * sin(phaseTime * 5)) } // sniff the ground
            if hold <= 0 { restMode = 0; input.paws = 0; input.sit = 0 }
            return
        }
        tilt += (0 - tilt) * min(1, dt * 6)
        walk(to: goal, speed: 0.6, dt: dt, view: view) {
            // Arrived at the spot: eat, sniff, or look around, then pick another.
            self.goal = .zero
            let r = self.rng.float()
            if r < 0.4 { self.restMode = 2; self.hold = self.rng.float(2.5...6); self.events.append(.fed) }
            else if r < 0.7 { self.restMode = 3; self.hold = self.rng.float(1.5...3.5) }
            else { self.phase = .alert; self.phaseTime = 0; self.hold = self.rng.float(1.2...3) }
        }
        if profile.behavior.climbs, rng.chance(0.0015), let s = book.sites.filter({ ($0.kind == .branch || $0.kind == .rail) && $0.position.y > 0.8 && $0.position.y < 6 }).randomElement(using: &rng) {
            climbTarget = s; goal = V2(s.position.x, s.position.z); siteID = s.id
        }
        if let t = climbTarget, simd_distance(V2(t.position.x, t.position.z), xz) < 0.4 { phase = .climbing; phaseTime = 0 }
        if rng.chance(profile.behavior.alertRate * dt * 0.5) { phase = .alert; phaseTime = 0; hold = rng.float(1.2...3) }
        // A hand held low and still brings bold animals over.
        if let h = view.player.hand, handCooldown <= 0, profile.behavior.boldness + trust > 0.9, h.palm.y < view.groundY + 0.6, h.steady > 1.2, h.speed < 0.3,
           simd_distance(V2(h.palm.x, h.palm.z), xz) < 5 {
            goal = V2(h.palm.x, h.palm.z) + simd_normalize(xz - V2(h.palm.x, h.palm.z) + V2(0.001, 0)) * 0.12
            if simd_distance(goal, xz) < 0.2 {
                restMode = 2; hold = 2.5; handCooldown = 5; events.append(.handFed)
            }
        }
    }

    private func alert(dt: Float, view: YardView) {
        speedNow = 0
        hold -= dt
        input.alert = 1
        tilt += (profile.behavior.climbs || profile.behavior.gait == .bound ? 48 : (profile.behavior.gait == .hop ? 30 : 0) - tilt) * min(1, dt * 5)
        input.sit = profile.behavior.gait == .walk ? 0 : 1
        input.paws = profile.behavior.gait == .bound ? 0.8 : 0
        let to = V2(view.player.head.x, view.player.head.z) - xz
        headAim = V2(max(-70, min(70, wrapAngle(headingOf(V3(to.x, 0, to.y)) - yaw) * 180 / .pi)), 8)
        if hold <= 0 { phase = .foraging; input.sit = 0; input.alert = 0; input.paws = 0 }
    }

    private func rest(dt: Float, view: YardView) { phase = .foraging }

    private func climb(dt: Float, up: Bool, book: PerchBook) {
        guard let t = climbTarget else { phase = .foraging; return }
        let top = t.position.y + profile.anatomy.standHeight * 0.6
        tilt += (80 - tilt) * min(1, dt * 6)
        let v: Float = 1.3
        speedNow = v
        position.y += (up ? v : -v) * dt
        advanceGait(dt)
        input.sit = 0; input.speed = 1
        if up, position.y >= top {
            position.y = top
            phase = .perched; phaseTime = 0; hold = rng.float(5...12)
            events.append(.climbed(item: t.itemID))
            if t.id >= 0 { book.claim(t.id, by: id + 1000) }
        } else if !up, position.y <= standY {
            position.y = standY; tilt = 0; phase = .foraging; goal = .zero; climbTarget = nil
            if t.id >= 0 { book.release(t.id, by: id + 1000) }
        }
    }

    private func perch(dt: Float, view: YardView) {
        speedNow = 0
        hold -= dt
        tilt += (30 - tilt) * min(1, dt * 4)
        input.sit = 1; input.speed = 0; input.alert = 0.6
        input.tailRaise = 0.6
        if hold <= 0 || stay <= 0 { phase = .descending; phaseTime = 0 }
    }

    private func run(dt: Float, view: YardView) {
        let run = profile.behavior.run * AnimalTuning.groundSpeedScale
        let to = goal - xz
        let dist = simd_length(to)
        if dist < 0.25 {
            speedNow = 0
            if restMode == 1 {
                // Hide in cover and freeze, then slip away.
                phase = .foraging; stay = 6; goal = .zero; input.alert = 1; hold = 3; restMode = 0
            } else { phase = .gone; events.append(.left) }
            return
        }
        let dir = to / dist
        let tgtYaw = headingOf(V3(dir.x, 0, dir.y))
        yaw = wrapAngle(yaw + max(-9 * dt, min(9 * dt, wrapAngle(tgtYaw - yaw) * 10 * dt)))
        speedNow += (run - speedNow) * min(1, dt * 8)
        let f = forward(yaw: yaw)
        position += V3(f.x, 0, f.z) * speedNow * dt
        advanceGait(dt)
        position.y = standY + bounce()
        input.sit = 0
    }

    // MARK: face

    private func updateFace(dt: Float, view: YardView) {
        lookTimer -= dt
        if lookTimer <= 0, phase != .alert, hold <= 0 || restMode != 3 {
            lookTimer = rng.float(0.6...2.2)
            headAim = V2(rng.float(-40...40), rng.float(-10...12))
        }
        headNow += (headAim - headNow) * min(1, dt * 9)
        input.headYaw = headNow.x
        input.headPitch = headNow.y
        input.twitch += dt * (phase == .foraging ? 28 : 12)
        input.alert = phase == .alert || phase == .fleeing ? 1 : max(0, input.alert - dt * 3)
        input.tailRaise = profile.species == .easternGraySquirrel ? 0.5 + 0.2 * sin(phaseTime) : (profile.species == .easternChipmunk ? 0.9 : 0)
        input.tailSway = 6 * sin(phaseTime * 1.7)
        if phase == .fleeing { input.tailRaise = profile.species == .easternCottontail ? 0 : 0.8 }
        if blinkPhase >= 0 {
            blinkPhase += dt / 0.15
            if blinkPhase >= 1 { blinkPhase = -1; blinkTimer = rng.float(2...6) }
            input.blink = blinkPhase < 0 ? 0 : sin(min(1, blinkPhase) * .pi)
        } else { blinkTimer -= dt; input.blink = 0; if blinkTimer <= 0 { blinkPhase = 0 } }
    }
}
