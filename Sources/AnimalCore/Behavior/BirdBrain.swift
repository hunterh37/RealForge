import Foundation
import simd
import RealCore

public enum BirdPhase: String, Sendable, Equatable {
    case approach, landing, perched, takeoff, hover, leaving, fleeing, gone
}

public enum BirdActivity: String, Sendable, CaseIterable {
    case idle, look, watch, preen, sing, feed, drink, hop, stretch, shake, peck
}

/// Things that happened to a bird this frame. The host turns them into sound, rewards and journal entries.
public enum BirdEvent: Sendable, Equatable {
    case arrived
    case landed(kind: PerchKind, item: String?)
    /// Song or call index into `BirdVoice.songs` / `calls`.
    case sang(index: Int, call: Bool)
    case drank
    case fed
    case spooked
    case handLanded
    case handHover
    case fedFromHand
    case wingClap
    case left
}

/// One bird's mind: picks a place, flies there, lands, goes about its business and leaves. Pure logic:
/// the host reads `body`, `input` and the events and renders them.
public final class BirdBrain {
    public let id: Int
    public let profile: BirdProfile
    public private(set) var body: FlightBody
    public private(set) var input = BirdMotionInput()
    public private(set) var phase: BirdPhase = .approach
    public private(set) var activity: BirdActivity = .idle
    public private(set) var siteID: Int?
    /// 0...1 familiarity with people, set by the journal.
    public var trust: Float
    /// Seconds left in the visit. At zero the bird leaves.
    public private(set) var stay: Float
    public private(set) var singTimeline: [(start: Float, duration: Float)] = []
    public private(set) var onHand = false
    public var pitchRest: Float { profile.anatomy.restPitch }

    private var rng: SeededRNG
    private let spec: FlightSpec
    private var events: [BirdEvent] = []
    private var plan: LandingPlan?
    private var target = V3.zero
    private var waypoints: [V3] = []
    private var targetSite: PerchSite?
    private var activityTime: Float = 0, activityDuration: Float = 2
    private var dwell: Float = 0
    private var phaseTime: Float = 0
    private var fear: Float = 0
    private var blinkTimer: Float = 3, blinkPhase: Float = -1
    private var headAim = V3.zero          // yaw, pitch, roll targets in degrees
    private var headNow = V3.zero
    private var lookTimer: Float = 0
    private var foldLevel: Float = 0, legsLevel: Float = 1, crouchLevel: Float = 0, flareLevel: Float = 0, gripLevel: Float = 0
    private var exit = V3.zero
    private var ground = V3.zero           // ground forage point while on the ground
    private var hopTimer: Float = 0, hopT: Float = -1, hopFrom = V3.zero, hopTo = V3.zero
    private var handStay: Float = 0
    private var handCooldown: Float = 0
    private var tailWag: Float = 0
    private var singIndex = 0
    private var voiceCooldown: Float = 4
    private var preenSide: Float = 1
    private var takeoffNext: BirdPhase = .approach
    private var impulseDone = false
    private var hoverBase = V3.zero

    public init(id: Int, profile: BirdProfile, spawn: V3, yaw: Float, stay: Float, trust: Float, seed: UInt64) {
        self.id = id; self.profile = profile; self.trust = trust; self.stay = stay
        rng = SeededRNG(seed: seed)
        spec = FlightSpec(profile)
        body = FlightBody(position: spawn, yaw: yaw, pitch: 6)
        body.velocity = forward(yaw: yaw) * spec.cruise
        body.phase = rng.float()
        foldLevel = 0; legsLevel = 1
        events.append(.arrived)
    }

    public func drainEvents() -> [BirdEvent] { let e = events; events.removeAll(keepingCapacity: true); return e }

    public var isGone: Bool { phase == .gone }
    public var isPerched: Bool { phase == .perched }
    public var currentSite: PerchSite? { targetSite }

    // MARK: update

    public func update(dt rawDt: Float, view: YardView, book: PerchBook) {
        let dt = min(rawDt, 1 / 20)
        guard phase != .gone else { return }
        phaseTime += dt
        fear = max(0, fear - dt)
        handCooldown = max(0, handCooldown - dt)
        voiceCooldown = max(0, voiceCooldown - dt)

        if senseThreat(view: view, book: book) { return }
        considerHand(view: view, book: book)

        switch phase {
        case .approach: flyToTarget(dt: dt, view: view, book: book)
        case .landing: landing(dt: dt, book: book, view: view)
        case .perched: perched(dt: dt, view: view, book: book)
        case .takeoff: takeoff(dt: dt, view: view, book: book)
        case .hover: hover(dt: dt, view: view, book: book)
        case .leaving, .fleeing: leave(dt: dt, view: view)
        case .gone: break
        }
        updateBlink(dt)
        refreshInput(dt: dt)
    }

    // MARK: sensing

    /// Returns true when the bird just decided to bolt.
    private func senseThreat(view: YardView, book: PerchBook) -> Bool {
        guard phase == .perched || phase == .approach || phase == .landing || phase == .hover else { return false }
        let p = body.position
        let tame = 1 - 0.65 * trust
        var radius = profile.behavior.skittishRadius * tame
        if onHand { radius *= 0.25 }
        let head = view.player.head
        let dHead = simd_distance(p, head)
        var threat = false
        if dHead < radius && view.player.headSpeed > (onHand ? 1.4 : 0.55) { threat = true }
        if dHead < radius * 0.45 && !onHand && phase == .perched && trust < 0.5 { threat = true }
        if let h = view.player.handPosition, view.player.handSpeed > (onHand ? 1.1 : 1.3), simd_distance(p, h) < max(radius, 0.9) { threat = true }
        for n in view.noises where simd_distance(n.at, p) < 3.5 * n.loudness * tame { threat = true }
        if view.weather.kind == .storm { threat = true }
        guard threat else { return false }
        flee(from: head, view: view, book: book)
        events.append(.spooked)
        return true
    }

    private func considerHand(view: YardView, book: PerchBook) {
        guard let hand = view.player.hand, let hs = book.handSite else { return }
        guard phase != .leaving, phase != .fleeing, phase != .takeoff, handCooldown <= 0, fear <= 0, !onHand else { return }
        if targetSite?.id == PerchBook.handID { return }
        let needSteady: Float = 0.9 * (1 - 0.6 * trust) + 0.3
        guard hand.steady >= needSteady, hand.speed < 0.35 else { return }
        let reach = 5 + 4 * trust
        guard simd_distance(hand.palm, body.position) < reach else { return }
        // Bolder birds come sooner; shy birds need trust.
        let want = profile.behavior.boldness * 0.7 + trust * 0.5 + 0.15
        guard want > 0.45, book.isFree(PerchBook.handID) else { return }
        if phase == .perched { releaseSite(book) }
        targetSite = hs
        siteID = PerchBook.handID
        if phase == .perched { beginTakeoff(next: .approach) } else { phase = .approach; plan = nil }
        retarget(book: book)
    }

    // MARK: choosing places

    private func like(_ s: PerchSite) -> Float { profile.behavior.likes[s.feature] ?? 0.05 }

    /// Picks a site for this bird. `avoid` is the site it is leaving.
    private func chooseSite(view: YardView, book: PerchBook, avoid: Int?) -> PerchSite? {
        var best: (PerchSite, Float)?
        func consider(_ s: PerchSite, bonus: Float = 0) {
            if s.id == avoid { return }
            if s.id != PerchBook.handID, !book.isFree(s.id), s.kind != .ground { return }
            if !view.contains(V2(s.position.x, s.position.z), margin: 0.1) { return }
            var score = like(s) + bonus
            let b = profile.behavior
            if s.kind == .ground { score *= 0.15 + 0.85 * b.groundForaging } else { score *= 1.05 - 0.55 * b.groundForaging }
            if s.kind != .ground {
                let want = 0.4 + b.perchHeight * 3.2
                let z = (s.position.y - want) / 2.2
                score *= 0.45 + 0.55 * exp(-z * z)
            }
            if s.kind == .rim || s.kind == .feeder { score *= 1 + (view.weather.kind == .rain ? 0 : 0.1) }
            let dHead = simd_distance(s.position, view.player.head)
            if dHead < 1.0 { score *= 0.15 + 0.5 * b.boldness }
            score *= 0.75 + 0.5 * rng.float()
            if best == nil || score > best!.1 { best = (s, score) }
        }
        for s in book.sites { consider(s) }
        // Ground candidates: random lawn points and forage spots.
        if profile.behavior.groundForaging > 0.15 {
            for k in 0..<4 {
                var p = V2(rng.float(view.min.x + 0.5...view.max.x - 0.5), rng.float(view.min.y + 0.5...view.max.y - 0.5))
                if k == 0, let f = view.forage.randomElement(using: &rng) { p = f + V2(rng.float(-0.4...0.4), rng.float(-0.4...0.4)) }
                if view.obstacles.contains(where: { simd_distance($0.center, p) < $0.radius + 0.15 }) { continue }
                consider(PerchSite(id: -100 - k, kind: .ground, position: V3(p.x, view.groundY, p.y), radius: 0.2, capacity: 99))
            }
        }
        guard let (site, score) = best, score > 0.02 else { return nil }
        return site
    }

    private func comAt(_ s: PerchSite) -> V3 {
        let a = profile.anatomy
        return s.position + V3(0, a.standHeight * (s.kind == .hand ? 0.9 : 1), 0)
    }

    private func claim(_ s: PerchSite, book: PerchBook) {
        if s.id >= 0 || s.id == PerchBook.handID { book.claim(s.id, by: id) }
        siteID = s.id
    }

    private func releaseSite(_ book: PerchBook) { book.releaseAll(by: id); siteID = nil }

    /// Sets `target`, the approach waypoints and flags for the current `targetSite`.
    private func retarget(book: PerchBook) {
        guard let s = targetSite else { return }
        let com = comAt(s)
        let from = body.position
        var dir = V3(com.x - from.x, 0, com.z - from.z)
        dir = simd_length(dir) > 0.01 ? simd_normalize(dir) : forward(yaw: body.yaw)
        let hovers = profile.behavior.hovers && (s.kind == .blossom || s.kind == .feeder || s.kind == .hand)
        let lead: Float = hovers ? 0.5 : 1.3
        target = com - dir * lead + V3(0, hovers ? 0.05 : 0.5, 0)
        waypoints.removeAll()
        let dist = simd_distance(from, com)
        if dist > 4 {
            let side = V3(-dir.z, 0, dir.x) * rng.float(-1.4...1.4)
            waypoints.append(lerp(from, target, 0.5) + side + V3(0, rng.float(0.2...1.0), 0))
        }
    }

    // MARK: approach and landing

    private func flyToTarget(dt: Float, view: YardView, book: PerchBook) {
        if targetSite == nil || (siteID != PerchBook.handID && siteID.map({ id in book.site(id) == nil && id >= 0 }) == true) {
            guard let s = chooseSite(view: view, book: book, avoid: nil) else { startLeaving(view: view, fast: false); return }
            targetSite = s; claim(s, book: book); retarget(book: book)
        }
        if let s = targetSite, s.id == PerchBook.handID {
            guard let live = book.handSite, view.player.hand != nil else {
                // Hand withdrawn: look for somewhere else.
                targetSite = nil; siteID = nil; handCooldown = 8
                return
            }
            targetSite = live
            retarget(book: book)
            waypoints.removeAll()
        }
        guard let s = targetSite else { return }
        let goal = waypoints.first ?? target
        let isFinal = waypoints.isEmpty
        let effort = BirdFlight.steer(&body, toward: goal, speed: spec.cruise, spec: spec, dt: dt, arrive: isFinal ? 1.2 : 0, minSpeed: spec.cruise * 0.5)
        BirdFlight.advanceWings(&body, hz: spec.wingbeatHz, effort: effort, dt: dt)
        flapEffort = effort
        if !isFinal {
            if simd_distance(body.position, goal) < 0.5 { waypoints.removeFirst() }
            return
        }
        let close = simd_distance(body.position, goal) < 0.55
        if close {
            let hovers = profile.behavior.hovers && (s.kind == .blossom || s.kind == .feeder || s.kind == .hand)
            if hovers {
                phase = .hover; phaseTime = 0; hoverBase = comAt(s) + V3(0, 0.02, 0)
                if s.kind == .hand { events.append(.handHover) }
            } else {
                plan = LandingPlan(from: body, target: comAt(s), facing: s.facing ?? approachFacing(s), restPitch: pitchRest)
                phase = .landing
            }
        }
    }

    private var flapEffort: Float = 0.7

    /// Face away from where the bird came from unless told otherwise (birds land into the wind: toward the approach).
    private func approachFacing(_ s: PerchSite) -> Float? {
        if s.kind == .ground { return nil }
        return body.yaw
    }

    private func landing(dt: Float, book: PerchBook, view: YardView) {
        guard var p = plan, let s = targetSite else { phase = .approach; return }
        if s.id == PerchBook.handID, let live = book.handSite, view.player.hand != nil {
            p.p1 = comAt(live)
            targetSite = live
        } else if s.id == PerchBook.handID {
            plan = nil; targetSite = nil; siteID = nil; phase = .approach; handCooldown = 8
            return
        }
        let r = p.step(dt, restPitch: pitchRest)
        body.position = r.pos; body.velocity = r.vel; body.yaw = r.yaw
        body.pitch += (r.pitch - body.pitch) * min(1, dt * 9)
        body.roll += (0 - body.roll) * min(1, dt * 5)
        flareLevel = r.flare
        legsLevel = 1 - smoothstep(0.35, 0.75, p.progress)
        BirdFlight.advanceWings(&body, hz: spec.wingbeatHz * (1 - 0.35 * r.flare), effort: 1, dt: dt)
        flapEffort = 1
        plan = p
        if p.done {
            plan = nil
            touchdown(s, book: book, view: view)
        }
    }

    private func touchdown(_ s: PerchSite, book: PerchBook, view: YardView) {
        phase = .perched; phaseTime = 0
        body.velocity = .zero; body.position = comAt(s)
        flareLevel = 0; legsLevel = 0; crouchLevel = 0.8
        body.roll = 0
        if s.kind == .ground { ground = s.position; chooseActivity(view: view, book: book, forced: .look) } else { chooseActivity(view: view, book: book, forced: .look) }
        dwell = rng.float(6...20) * (s.kind == .hand ? 0 : 1)
        if s.id == PerchBook.handID {
            onHand = true
            handStay = rng.float(7...14) * (1 + trust)
            events.append(.handLanded)
        }
        events.append(.landed(kind: s.kind, item: s.itemID))
        if s.kind == .ground { gripLevel = 0 }
        if profile.species == .mourningDove { events.append(.wingClap) }
    }

    // MARK: hover (hummingbirds at flowers, feeders and hands)

    private func hover(dt: Float, view: YardView, book: PerchBook) {
        guard let s = targetSite else { phase = .approach; return }
        var anchor = comAt(s) + V3(0, 0.02, 0)
        if s.id == PerchBook.handID {
            guard let live = book.handSite, view.player.hand != nil else { targetSite = nil; siteID = nil; handCooldown = 8; startLeaving(view: view, fast: false); return }
            targetSite = live
            anchor = comAt(live) + V3(0, 0.03, 0)
        }
        hoverBase = anchor
        let t = phaseTime
        let drift = V3(0.012 * sin(t * 2.3), 0.01 * sin(t * 3.1 + 1), 0.012 * sin(t * 1.7 + 2))
        let f = hoverBase + drift
        body.velocity = (f - body.position) / max(dt, 1e-3)
        body.position += (f - body.position) * min(1, dt * 7)
        let faceYaw = s.facing ?? body.yaw
        body.yaw = wrapAngle(body.yaw + wrapAngle(faceYaw - body.yaw) * min(1, dt * 3))
        body.pitch += (34 - body.pitch) * min(1, dt * 4)
        body.roll += (0 - body.roll) * min(1, dt * 4)
        BirdFlight.advanceWings(&body, hz: spec.wingbeatHz, effort: 1, dt: dt)
        flapEffort = 1
        legsLevel = 1
        // Feed: bill open and in, with periodic sips.
        let sip = sin(t * 9)
        headAim = V3(0, -6, 0)
        input.beak = sip > 0.2 ? 1 : 0
        if Int(t * 1.4) != Int((t - dt) * 1.4) { events.append(s.id == PerchBook.handID ? .fedFromHand : .fed) }
        let limit: Float = s.id == PerchBook.handID ? 7 : 6 + 4 * profile.behavior.boldness
        if phaseTime > limit {
            if s.id == PerchBook.handID { handCooldown = 10 }
            releaseSite(book)
            targetSite = nil
            if stay <= 0 { startLeaving(view: view, fast: false) } else { phase = .approach; plan = nil }
        }
        stay -= dt
    }

    // MARK: perched behavior

    private func perched(dt: Float, view: YardView, book: PerchBook) {
        guard let s = targetSite else { phase = .approach; return }
        stay -= dt
        let live: PerchSite
        if s.id == PerchBook.handID {
            guard let h = book.handSite, view.player.hand != nil else {
                // The hand is gone: leap off.
                onHand = false; handCooldown = 8; releaseSite(book); targetSite = nil
                beginTakeoff(next: .approach)
                return
            }
            live = h; targetSite = h
            handStay -= dt
            let ho = view.player.hand!
            if ho.speed > 0.9 || handStay <= 0 {
                onHand = false; handCooldown = 12; releaseSite(book); targetSite = nil
                beginTakeoff(next: stay > 0 ? .approach : .leaving)
                if stay <= 0 { startLeaving(view: view, fast: false) }
                return
            }
        } else { live = s }

        // Position: stuck to the site, or foraging on the ground.
        if live.kind == .ground {
            groundStep(dt: dt, view: view, site: live)
        } else {
            let c = comAt(live)
            body.position += (c - body.position) * min(1, dt * 20)
            body.velocity = .zero
        }
        crouchLevel = max(0, crouchLevel - dt * 3)
        body.pitch += (pitchRest - body.pitch) * min(1, dt * 6)
        body.roll += (0 - body.roll) * min(1, dt * 6)
        // Heading follows the player slowly when watching; otherwise the site's facing.
        if let f = live.facing, activity != .watch, live.kind != .ground, live.kind != .hand {
            body.yaw = wrapAngle(body.yaw + wrapAngle(f - body.yaw) * min(1, dt * 2))
        }
        if live.kind == .hand, let h = view.player.hand {
            let toHead = view.player.head - h.palm
            let y = yaw(of: V3(toHead.x, 0, toHead.z))
            body.yaw = wrapAngle(body.yaw + wrapAngle(y - body.yaw) * min(1, dt * 3))
        }
        gripLevel += ((live.kind == .ground || live.kind == .hand ? 0.25 : max(0.25, min(1, 1 - (live.radius - 0.01) / 0.05))) - gripLevel) * min(1, dt * 10)

        activityTime += dt
        dwell -= dt
        updateActivity(dt: dt, view: view, live: live)
        if activityTime >= activityDuration { chooseActivity(view: view, book: book, forced: nil) }

        // Leave or relocate.
        if live.id != PerchBook.handID {
            if stay <= 0 {
                releaseSite(book); targetSite = nil
                startLeaving(view: view, fast: false)
            } else if dwell <= 0 {
                let from = live.id
                if rng.chance(0.55), let next = chooseSite(view: view, book: book, avoid: from) {
                    releaseSite(book)
                    targetSite = next; claim(next, book: book); retarget(book: book)
                    beginTakeoff(next: .approach)
                } else { dwell = rng.float(5...14) }
            }
        }
    }

    // MARK: activities

    private func chooseActivity(view: YardView, book: PerchBook, forced: BirdActivity?) {
        activityTime = 0
        singTimeline = []
        guard let s = targetSite else { activity = .idle; return }
        if let f = forced { activity = f; activityDuration = rng.float(0.8...1.6); return }
        let b = profile.behavior
        var w: [(BirdActivity, Float)] = [(.idle, 1.2), (.look, 2), (.preen, s.kind == .hand ? 0.2 : 1), (.shake, 0.25), (.stretch, 0.3)]
        if view.player.head.y > 0, simd_distance(view.player.head, body.position) < 5 { w.append((.watch, 2.2 * (0.4 + b.boldness))) }
        if s.kind.food { w.append((.feed, 5)) }
        if s.kind.water { w.append((.drink, 5)) }
        if s.kind == .ground { w.append((.peck, 4)); w.append((.hop, 3)) }
        if s.kind == .hand { w.append((.peck, 3)); w.append((.watch, 3)) }
        if voiceCooldown <= 0, view.dayPart != .night, s.kind != .ground { w.append((.sing, b.voiceRate * 70)) }
        let total = w.reduce(0) { $0 + $1.1 }
        var r = rng.float() * total
        activity = .idle
        for (a, x) in w { r -= x; if r <= 0 { activity = a; break } }
        switch activity {
        case .idle: activityDuration = rng.float(1.2...3)
        case .look: activityDuration = rng.float(1.5...4); lookTimer = 0
        case .watch: activityDuration = rng.float(2...5)
        case .preen: activityDuration = rng.float(2.5...5); preenSide = rng.chance(0.5) ? 1 : -1
        case .sing: startSong()
        case .feed: activityDuration = rng.float(3...7)
        case .drink: activityDuration = rng.float(3.5...6)
        case .hop: activityDuration = rng.float(2...4)
        case .stretch: activityDuration = rng.float(1.4...2.2)
        case .shake: activityDuration = 0.7
        case .peck: activityDuration = rng.float(2.5...5)
        }
    }

    private func startSong() {
        let call = rng.chance(0.3)
        let list = call ? profile.voice.calls : profile.voice.songs
        singIndex = list.isEmpty ? 0 : rng.int(0...(list.count - 1))
        let notes = list.isEmpty ? [] : list[singIndex]
        var t: Float = 0.15
        singTimeline = []
        for n in notes { singTimeline.append((t, n.duration)); t += n.duration + n.gap }
        activityDuration = max(1.2, t + 0.5)
        voiceCooldown = rng.float(8...20) / max(0.3, profile.behavior.voiceRate * 12)
        events.append(.sang(index: singIndex, call: call))
    }

    private func updateActivity(dt: Float, view: YardView, live: PerchSite) {
        let t = activityTime
        var aim = V3(0, 0, 0)       // head yaw, pitch, roll
        var beak: Float = 0
        var neck: Float = 0
        var wingOpen: Float = 0
        var crest: Float = 0
        var tail: Float = 0
        var spread: Float = 0.05
        switch activity {
        case .idle:
            aim = V3(0, 2 * sin(t * 0.7), 0)
        case .look:
            lookTimer -= dt
            if lookTimer <= 0 {
                lookTimer = rng.float(0.5...1.5)
                headAim = V3(rng.float(-85...85), rng.float(-12...18), rng.float(-14...14))
            }
            aim = headAim
        case .watch:
            let to = view.player.head - body.position
            let rel = wrapAngle(yaw(of: V3(to.x, 0, to.z)) - body.yaw)
            let ydeg = max(-95, min(95, rel * 180 / .pi))
            if abs(rel * 180 / .pi) > 85 { body.yaw = wrapAngle(body.yaw + rel * min(1, dt * 1.6)) }
            let up = atan2(to.y, max(0.2, simd_length(V2(to.x, to.z)))) * 180 / .pi
            aim = V3(ydeg, max(-15, min(30, up * 0.6)), 12 * sin(t * 0.8))
            crest = 0.6
        case .preen:
            let k = smoothstep(0, 0.4, t) * (1 - smoothstep(activityDuration - 0.5, activityDuration, t))
            aim = V3(preenSide * 105 * k, 38 * k, preenSide * 16 * k)
            neck = 24 * k
            beak = 0.18 * max(0, sin(t * 28)) * k
            wingOpen = 0.35 * k * (sin(t * 1.5) * 0.5 + 0.5)
        case .sing:
            let k = smoothstep(0, 0.2, t)
            aim = V3(0, 24 * k, 0)
            neck = -6 * k
            crest = 0.5
            for n in singTimeline where t >= n.start && t <= n.start + n.duration {
                let u = (t - n.start) / n.duration
                beak = 0.55 + 0.45 * sin(u * .pi)
            }
            tail = 4 * sin(t * 5)
        case .feed:
            let cycle = t * 2.4
            let dip = max(0, sin(cycle * 2 * .pi))
            aim = V3(rng.float(-3...3) * 0, -44 * dip + 8 * (1 - dip), 0)
            neck = 12 * dip
            beak = dip > 0.6 ? 0.5 : 0
            if Int(cycle) != Int((t - dt) * 2.4) { if live.kind == .feeder || live.kind == .ground { events.append(.fed) } }
        case .drink:
            let cycle = t / 1.8
            let ph = cycle - floor(cycle)
            let dip = ph < 0.55 ? sin(ph / 0.55 * .pi) : 0
            let tip = ph > 0.6 ? sin((ph - 0.6) / 0.4 * .pi) : 0
            aim = V3(0, -50 * dip + 40 * tip, 0)
            neck = 16 * dip - 8 * tip
            beak = dip > 0.5 ? 0.7 : (tip > 0.3 ? 0.4 : 0)
            if ph < 0.05 && Int(cycle) != Int((t - dt) / 1.8) { events.append(.drank) }
        case .peck:
            let cycle = t * 1.6
            let dip = pow(max(0, sin(cycle * 2 * .pi)), 3)
            aim = V3(sin(t * 0.9) * 25, -55 * dip + 6, 0)
            neck = 14 * dip
            if live.kind == .hand, dip > 0.9, Int(cycle) != Int((t - dt) * 1.6) { events.append(.fedFromHand) }
        case .hop:
            aim = V3(0, 0, 0)
        case .stretch:
            let k = sin(min(1, t / activityDuration) * .pi)
            wingOpen = 0.9 * k
            spread = 0.05 + 0.9 * k
            aim = V3(0, 14 * k, 0)
            beak = 0.3 * k
        case .shake:
            body.yaw += sin(t * 70) * 0.05 * dt * 60 * 0.15
            tail = 8 * sin(t * 60)
            neck = 6 * sin(t * 50)
        }
        // Body tail flick and breathing keep a resting bird alive.
        tailWag += dt
        tail += 3 * sin(tailWag * 1.3) + (activity == .idle && Int(tailWag * 0.4) % 4 == 0 ? 3 * sin(tailWag * 14) : 0)
        // Head follows its aim fast (saccades), with a little overshoot damping.
        let rate = min(1, dt * (activity == .look || activity == .watch ? 14 : 9))
        headNow += (aim - headNow) * rate
        input.headYaw = headNow.x; input.headPitch = headNow.y; input.headRoll = headNow.z
        input.neck = neck
        input.beak = beak
        input.crest = crest
        input.wingOpen = wingOpen
        input.tailPitch = tail
        input.tailSpread = spread
    }

    /// Hops on the ground: crouch, small arc, stop. Robins run in 2 to 3 hops then freeze.
    private func groundStep(dt: Float, view: YardView, site: PerchSite) {
        let stand = comAt(site).y
        if hopT >= 0 {
            hopT += dt / 0.2
            let u = min(1, hopT)
            let p = lerp(hopFrom, hopTo, u)
            body.position = V3(p.x, stand + 0.03 * 4 * u * (1 - u), p.z)
            crouchLevel = 0.5 * sin(u * .pi)
            if hopT >= 1 { hopT = -1; hopTimer = rng.float(0.5...1.4) }
            return
        }
        body.position.y += (stand - body.position.y) * min(1, dt * 12)
        if body.position.y < stand - 0.01 { body.position.y = stand }
        hopTimer -= dt
        guard activity == .hop || (activity == .peck && hopTimer <= 0 && rng.chance(Float(0.15))) else { return }
        guard hopTimer <= 0 else { return }
        let dir = forward(yaw: body.yaw + rng.float(-0.9...0.9))
        let d = rng.float(0.06...0.14)
        var to = body.position + dir * d
        let p2 = V2(to.x, to.z)
        if !view.contains(p2, margin: 0.3) || view.obstacles.contains(where: { simd_distance($0.center, p2) < $0.radius + 0.08 }) {
            body.yaw = wrapAngle(body.yaw + rng.float(1.2...2.4))
            hopTimer = 0.3
            return
        }
        to.y = stand
        hopFrom = body.position; hopTo = to; hopT = 0
        body.yaw = wrapAngle(body.yaw + wrapAngle(yaw(of: dir) - body.yaw) * 0.6)
    }

    // MARK: takeoff and leaving

    private func beginTakeoff(next: BirdPhase) {
        phase = .takeoff; phaseTime = 0; impulseDone = false; takeoffNext = next
        onHand = false
        plan = nil
    }

    private func takeoff(dt: Float, view: YardView, book: PerchBook) {
        let t = phaseTime
        let crouchT: Float = 0.2
        if t < crouchT {
            crouchLevel = min(1, t / crouchT)
            body.position += V3(0, -0.012 * dt * 4, 0)
            return
        }
        if !impulseDone {
            impulseDone = true
            let heading: V3
            if takeoffNext == .leaving || takeoffNext == .fleeing { heading = simd_normalize(V3(exit.x - body.position.x, 0, exit.z - body.position.z)) }
            else if let s = targetSite { let c = comAt(s); let d = V3(c.x - body.position.x, 0, c.z - body.position.z); heading = simd_length(d) > 0.05 ? simd_normalize(d) : forward(yaw: body.yaw) }
            else { heading = forward(yaw: body.yaw) }
            body.yaw = yaw(of: heading)
            body.velocity = heading * spec.cruise * 0.45 + V3(0, 2.0, 0)
            crouchLevel = 0
        }
        legsLevel = min(1, (t - crouchT) / 0.25)
        let goal: V3
        switch takeoffNext {
        case .leaving, .fleeing: goal = exit
        default: goal = targetSite.map { comAt($0) + V3(0, 0.6, 0) } ?? (body.position + V3(0, 1, 0))
        }
        let effort = BirdFlight.steer(&body, toward: goal.y < body.position.y + 0.8 && t < 0.6 ? body.position + forward(yaw: body.yaw) * 2 + V3(0, 1.2, 0) : goal,
                                      speed: spec.cruise, spec: spec, dt: dt)
        BirdFlight.advanceWings(&body, hz: spec.wingbeatHz, effort: 1, dt: dt)
        flapEffort = max(0.9, effort)
        if t > 0.65 {
            if takeoffNext == .approach { phase = .approach; retarget(book: book) } else { phase = takeoffNext }
        }
    }

    private func flee(from threat: V3, view: YardView, book: PerchBook) {
        fear = 20
        releaseSite(book)
        let wasPerched = phase == .perched
        targetSite = nil; onHand = false
        let away = V3(body.position.x - threat.x, 0, body.position.z - threat.z)
        let d = simd_length(away) > 0.05 ? simd_normalize(away) : forward(yaw: body.yaw)
        exit = body.position + d * 9 + V3(0, 3.5, 0)
        phase = wasPerched ? .takeoff : .fleeing
        phaseTime = 0; impulseDone = false; takeoffNext = .fleeing
        stay = 0
        plan = nil
        if !wasPerched { phase = .fleeing }
    }

    private func startLeaving(view: YardView, fast: Bool) {
        let c = V2((view.min.x + view.max.x) / 2, (view.min.y + view.max.y) / 2)
        var d = V2(body.position.x - c.x, body.position.z - c.y)
        if simd_length(d) < 0.5 { d = V2(rng.float(-1...1), rng.float(-1...1)) }
        d = simd_normalize(d)
        let far = simd_length(V2(view.max.x - view.min.x, view.max.y - view.min.y)) / 2 + 8
        exit = V3(c.x + d.x * far, view.groundY + rng.float(4...7), c.y + d.y * far)
        if phase == .perched || phase == .landing { beginTakeoff(next: .leaving) } else { phase = .leaving }
        takeoffNext = .leaving
    }

    private func leave(dt: Float, view: YardView) {
        let fast = phase == .fleeing
        let effort = BirdFlight.steer(&body, toward: exit, speed: spec.cruise * (fast ? 1.5 : 1.1), spec: spec, dt: dt)
        BirdFlight.advanceWings(&body, hz: spec.wingbeatHz, effort: effort, dt: dt)
        flapEffort = effort
        legsLevel = min(1, legsLevel + dt * 4)
        if !view.contains(V2(body.position.x, body.position.z), margin: -6) || simd_distance(body.position, exit) < 1 || phaseTime > 40 {
            phase = .gone
            events.append(.left)
        }
    }

    // MARK: input assembly

    private func updateBlink(_ dt: Float) {
        if blinkPhase >= 0 {
            blinkPhase += dt / 0.14
            if blinkPhase >= 1 { blinkPhase = -1; blinkTimer = rng.float(1.5...6) }
            input.blink = blinkPhase < 0 ? 0 : sin(min(1, blinkPhase) * .pi)
        } else {
            blinkTimer -= dt
            input.blink = 0
            if blinkTimer <= 0 { blinkPhase = 0 }
        }
        if phase == .perched && activity == .sing { input.blink = min(input.blink, 0.5) }
    }

    private func refreshInput(dt: Float) {
        let flying = phase == .approach || phase == .landing || phase == .leaving || phase == .fleeing || phase == .takeoff || phase == .hover
        let airborne = flying && !(phase == .takeoff && phaseTime < 0.2)
        let foldTarget: Float = airborne ? 0 : 1
        foldLevel += (foldTarget - foldLevel) * min(1, dt * (airborne ? 12 : 5))
        input.fold = foldLevel
        input.phase = body.phase
        input.flap = airborne ? flapEffort : 0
        input.hover = phase == .hover ? 1 : 0
        input.flare = phase == .landing ? flareLevel : 0
        input.legs = airborne ? legsLevel : 0
        input.grip = gripLevel
        input.crouch = crouchLevel
        if airborne {
            input.tailSpread = phase == .landing ? 0.9 : 0.35
            input.tailPitch = 0
            input.headYaw = 0; input.headPitch = 0; input.headRoll = 0; input.neck = -6
            input.wingOpen = 0
            headNow = .zero
            if phase != .hover { input.beak = 0 }
            input.crest = 0.2
        }
    }
}
