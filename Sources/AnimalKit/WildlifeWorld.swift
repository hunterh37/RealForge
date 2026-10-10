import Foundation
import RealityKit
import RealKit
import RealLibrary
import RealCore
import AnimalCore

/// A placed item the animals can see.
public struct WildlifePlacement: Sendable, Equatable {
    public var id: UUID
    public var itemID: String
    public var seed: UInt64
    public var frame: ItemFrame
    /// Ground footprint radius in meters (obstacle for walkers).
    public var radius: Float
    public init(id: UUID, itemID: String, seed: UInt64, frame: ItemFrame, radius: Float) {
        self.id = id; self.itemID = itemID; self.seed = seed; self.frame = frame; self.radius = radius
    }
}

/// Something worth telling the person.
public enum WildlifeNotice: Sendable {
    case arrived(AnimalKind)
    case rewards([JournalReward])
    case handLanding(AnimalKind)
    case left(AnimalKind)
}

/// Owns every visiting animal: spawns them from the habitat, ticks their brains, poses their rigs,
/// plays their voices and keeps the journal. Add `root` under the yard root (yard-local space).
@MainActor
public final class WildlifeWorld {
    public let root = Entity()
    public var settings = WildlifeSettings() { didSet { applySettings() } }
    public private(set) var journal: Journal
    public private(set) var habitat = HabitatInventory()
    public let book = PerchBook()
    public var onNotice: ((WildlifeNotice) -> Void)?
    /// Called when the journal changes so the host can persist it.
    public var onJournal: ((Journal) -> Void)?

    private var scheduler = VisitScheduler(seed: UInt64.random(in: 1...UInt64.max), firstVisitIn: 6)
    private var hand = HandTracker()
    private var birds: [BirdActor] = []
    private var ground: [GroundActor] = []
    private var pending: Set<String> = []
    private var nextID = 1
    private var placements: [WildlifePlacement] = []
    private var localSites: [String: [PerchSite]] = [:]
    private var siteTask: Task<Void, Never>?
    private var obstacles: [Obstacle] = []
    private var cover: [V2] = []
    private var forage: [V2] = []
    private var noises: [(at: V3, loudness: Float, age: Float)] = []
    private var bounds = (min: V2(-4, -4), max: V2(4, 4))
    public var groundY: Float = 0
    public var openArea: Float = 20 { didSet { rebuildHabitat() } }

    private final class BirdActor {
        let brain: BirdBrain
        let puppet: BirdPuppet
        var settled: Float = 0
        var spooked = false
        var counted = false
        var wasHover = false
        var phase: BirdPhase = .approach
        var audio: AudioPlaybackController?
        init(brain: BirdBrain, puppet: BirdPuppet) { self.brain = brain; self.puppet = puppet }
    }

    private final class GroundActor {
        let brain: GroundBrain
        let puppet: GroundPuppet
        init(brain: GroundBrain, puppet: GroundPuppet) { self.brain = brain; self.puppet = puppet }
    }

    public init(journal: Journal = Journal()) {
        self.journal = journal
        root.name = "Wildlife"
        AnimalMaterials.registerAll()
    }

    // MARK: yard description

    public func setBounds(min: V2, max: V2) { bounds = (min, max) }

    public func setJournal(_ j: Journal) { journal = j }

    /// Call whenever placements change. Perch sites are derived from the props' own geometry.
    public func setPlacements(_ list: [WildlifePlacement]) {
        placements = list
        obstacles = list.filter { $0.radius > 0.05 && ($0.itemID != "sod-roll" && $0.itemID != "mulch-bed") }
            .map { Obstacle(center: V2($0.frame.position.x, $0.frame.position.z), radius: $0.radius * 0.8) }
        cover = list.filter { HabitatTable.cover.contains($0.itemID) }.map { V2($0.frame.position.x, $0.frame.position.z) }
        forage = list.filter { HabitatTable.forage.contains($0.itemID) }.map { V2($0.frame.position.x + 0.3, $0.frame.position.z + 0.3) }
        rebuildHabitat()
        rebuildSites()
    }

    private func rebuildHabitat() {
        habitat = HabitatInventory.build(items: placements.map { ($0.itemID, ($0.frame.scale.x + $0.frame.scale.z) / 2) }, openArea: openArea)
    }

    private func rebuildSites() {
        siteTask?.cancel()
        let needed = placements.filter { PerchRules.has($0.itemID) }
        let missing = needed.filter { localSites["\($0.itemID)#\($0.seed)"] == nil }
        if missing.isEmpty { applySites(); return }
        let jobs = Dictionary(missing.map { ("\($0.itemID)#\($0.seed)", ($0.itemID, $0.seed)) }, uniquingKeysWith: { a, _ in a })
        siteTask = Task { [weak self] in
            let built = await Task.detached(priority: .utility) { () -> [String: [PerchSite]] in
                var out: [String: [PerchSite]] = [:]
                for (k, j) in jobs {
                    guard let t = Catalog.type(j.0) else { continue }
                    let model = t.init().build(seed: j.1).levels[0]
                    out[k] = PerchExtractor.localSites(itemID: j.0, model: model, seed: j.1)
                }
                return out
            }.value
            guard !Task.isCancelled, let self else { return }
            for (k, v) in built { self.localSites[k] = v }
            self.applySites()
        }
    }

    private func applySites() {
        var all: [PerchSite] = []
        for p in placements {
            guard let local = localSites["\(p.itemID)#\(p.seed)"] else { continue }
            all += PerchExtractor.sites(itemID: p.itemID, local: local, frame: p.frame, source: p.id)
        }
        book.replace(with: all)
    }

    /// A loud event near `at` (placing a prop, dropping something) that startles animals.
    public func noise(at p: V3, loudness: Float = 0.5) { noises.append((p, loudness, 0)) }

    // MARK: tick

    public struct Input {
        public var head: V3
        public var headSpeed: Float
        public var palm: PalmReading?
        public var weather: AnimalWeather
        public var dayPart: DayPart
        public var season: AnimalSeason
        public init(head: V3, headSpeed: Float, palm: PalmReading?, weather: AnimalWeather = .init(), dayPart: DayPart = .day, season: AnimalSeason = .summer) {
            self.head = head; self.headSpeed = headSpeed; self.palm = palm; self.weather = weather; self.dayPart = dayPart; self.season = season
        }
    }

    public var activeCount: Int { birds.count + ground.count }
    public var presentKinds: [AnimalKind] { birds.map { .bird($0.brain.profile.species) } + ground.map { .ground($0.brain.profile.species) } }

    public func tick(dt: Float, input: Input) {
        guard settings.enabled else { if activeCount > 0 { clear() }; return }
        var view = YardView(min: bounds.min, max: bounds.max)
        view.groundY = groundY
        view.player.head = input.head
        view.player.headSpeed = input.headSpeed
        hand.update(dt: dt, palm: input.palm, head: input.head, groundY: groundY)
        view.player.hand = hand.offer
        view.player.handSpeed = hand.motion?.speed ?? 0
        view.player.handPosition = hand.motion?.position
        view.obstacles = obstacles; view.cover = cover; view.forage = forage
        view.weather = input.weather; view.dayPart = input.dayPart; view.season = input.season
        noises = noises.map { ($0.at, $0.loudness, $0.age + dt) }.filter { $0.age < 0.5 }
        view.noises = noises.map { ($0.at, $0.loudness) }
        if let o = hand.offer { book.setHand(PerchSite(id: 0, kind: .hand, position: o.palm + o.normal * 0.012, facing: nil, radius: 0.03, capacity: 1)) } else { book.setHand(nil) }

        // Arrivals.
        scheduler.settings = settings
        for r in scheduler.tick(dt: dt, habitat: habitat, view: view, present: presentKinds, journal: journal) { spawn(r, view: view) }

        // Birds.
        for a in birds {
            a.brain.update(dt: dt, view: view, book: book)
            render(a)
            handle(a)
        }
        birds.removeAll { a in
            if a.brain.isGone { finish(a); a.puppet.holder.removeFromParent(); return true }
            return false
        }
        // Ground animals.
        for a in ground {
            a.brain.update(dt: dt, view: view, book: book)
            render(a)
            handle(a)
        }
        ground.removeAll { a in
            if a.brain.isGone { a.puppet.holder.removeFromParent(); onNotice?(.left(.ground(a.brain.profile.species))); return true }
            return false
        }
    }

    // MARK: spawning

    private func spawn(_ r: VisitRequest, view: YardView) {
        let key = r.kind.rawValue
        guard !pending.contains(key) else { return }
        pending.insert(key)
        Task { [weak self] in
            guard let self else { return }
            defer { self.pending.remove(key) }
            do {
                switch r.kind {
                case .bird(let s):
                    for i in 0..<r.group {
                        let puppet = try await BirdFactory.puppet(s)
                        self.addBird(puppet, species: s, request: r, view: view, index: i)
                    }
                case .ground(let s):
                    let puppet = try await GroundFactory.puppet(s)
                    self.addGround(puppet, species: s, request: r, view: view)
                }
            } catch { print("wildlife spawn failed: \(error)") }
        }
    }

    private func edgePoint(_ view: YardView, margin: Float) -> (V2, Float) {
        let side = Int.random(in: 0..<4)
        let u = Float.random(in: 0...1)
        let mn = view.min - V2(repeating: margin), mx = view.max + V2(repeating: margin)
        let p: V2
        switch side {
        case 0: p = V2(mn.x + (mx.x - mn.x) * u, mn.y)
        case 1: p = V2(mn.x + (mx.x - mn.x) * u, mx.y)
        case 2: p = V2(mn.x, mn.y + (mx.y - mn.y) * u)
        default: p = V2(mx.x, mn.y + (mx.y - mn.y) * u)
        }
        let c = (view.min + view.max) / 2
        return (p, yaw(of: V3(c.x - p.x, 0, c.y - p.y)))
    }

    private func addBird(_ puppet: BirdPuppet, species: BirdSpecies, request: VisitRequest, view: YardView, index: Int) {
        let (e, y) = edgePoint(view, margin: 4)
        let spawn = V3(e.x + Float(index) * 0.6, groundY + Float.random(in: 2.5...5), e.y + Float(index) * 0.4)
        let brain = BirdBrain(id: nextID, profile: species.profile, spawn: spawn, yaw: y + Float.random(in: -0.3...0.3), stay: request.stay,
                              trust: journal.trust(.bird(species)), seed: UInt64.random(in: 1...UInt64.max))
        nextID += 1
        let a = BirdActor(brain: brain, puppet: puppet)
        root.addChild(puppet.holder)
        birds.append(a)
        render(a)
        if index == 0 {
            apply(journal.record(.visit(.bird(species))))
            onNotice?(.arrived(.bird(species)))
        }
    }

    private func addGround(_ puppet: GroundPuppet, species: GroundSpecies, request: VisitRequest, view: YardView) {
        let (e, y) = edgePoint(view, margin: 1)
        let brain = GroundBrain(id: nextID, profile: species.profile, spawn: e, yaw: y, stay: request.stay, trust: journal.trust(.ground(species)),
                                groundY: groundY, seed: UInt64.random(in: 1...UInt64.max))
        nextID += 1
        let a = GroundActor(brain: brain, puppet: puppet)
        root.addChild(puppet.holder)
        ground.append(a)
        render(a)
        apply(journal.record(.visit(.ground(species))))
        onNotice?(.arrived(.ground(species)))
    }

    // MARK: rendering

    private func render(_ a: BirdActor) {
        let b = a.brain.body
        let p = a.brain.profile
        a.puppet.apply(BirdMotion.pose(p, a.brain.input))
        let qYaw = simd_quatf(angle: b.yaw, axis: [0, 1, 0])
        let qPitch = simd_quatf(angle: radians(b.pitch - a.brain.pitchRest), axis: [1, 0, 0])
        let qRoll = simd_quatf(angle: radians(-b.roll), axis: [0, 0, 1])
        a.puppet.holder.position = b.position
        a.puppet.holder.orientation = qYaw * qPitch * qRoll
    }

    private func render(_ a: GroundActor) {
        let g = a.brain
        a.puppet.apply(GroundMotion.pose(g.profile, g.input))
        let qYaw = simd_quatf(angle: g.yaw, axis: [0, 1, 0])
        let qTilt = simd_quatf(angle: radians(g.tilt), axis: [1, 0, 0])
        a.puppet.holder.position = g.position
        a.puppet.holder.orientation = qYaw * qTilt
    }

    // MARK: events

    private func apply(_ rewards: [JournalReward]) {
        guard !rewards.isEmpty else { onJournal?(journal); return }
        onNotice?(.rewards(rewards))
        onJournal?(journal)
    }

    private func handle(_ a: BirdActor) {
        let kind = AnimalKind.bird(a.brain.profile.species)
        if a.brain.isPerched { a.settled += 1 / 60 }
        for e in a.brain.drainEvents() {
            switch e {
            case .landed(_, let item): apply(journal.record(.landed(kind, item: item)))
            case .spooked: a.spooked = true; apply(journal.record(.spooked(kind)))
            case .handLanded:
                onNotice?(.handLanding(kind))
                apply(journal.record(.handLanded(kind)))
            case .fedFromHand, .handHover: apply(journal.record(.handFed(kind)))
            case .sang(let i, let call): sing(a, index: i, call: call)
            case .wingClap: playClip(a, .clap)
            default: break
            }
        }
        if a.brain.phase == .takeoff && a.phase != .takeoff { playClip(a, .takeoff) }
        a.phase = a.brain.phase
        let hover = a.brain.phase == .hover
        if hover != a.wasHover {
            a.wasHover = hover
            if hover { if let r = BirdVoiceSynth.resource(a.brain.profile.species, .hum), settings.sound { a.audio = a.puppet.holder.playAudio(r); a.audio?.gain = -14 } }
            else { a.audio?.stop(); a.audio = nil }
        }
    }

    private func finish(_ a: BirdActor) {
        let kind = AnimalKind.bird(a.brain.profile.species)
        a.audio?.stop()
        if a.settled > 4, !a.spooked { apply(journal.record(.settled(kind, seconds: a.settled))) }
        onNotice?(.left(kind))
    }

    private func handle(_ a: GroundActor) {
        let kind = AnimalKind.ground(a.brain.profile.species)
        for e in a.brain.drainEvents() {
            switch e {
            case .spooked: apply(journal.record(.spooked(kind)))
            case .handFed: onNotice?(.handLanding(kind)); apply(journal.record(.handLanded(kind)))
            case .climbed(let item): apply(journal.record(.landed(kind, item: item)))
            default: break
            }
        }
    }

    private func sing(_ a: BirdActor, index: Int, call: Bool) {
        guard settings.sound, let r = BirdVoiceSynth.resource(a.brain.profile.species, call ? .call(index) : .song(index)) else { return }
        a.puppet.holder.components.set(SpatialAudioComponent(gain: 0, directLevel: 0, reverbLevel: -10))
        _ = a.puppet.holder.playAudio(r)
    }

    private func playClip(_ a: BirdActor, _ c: BirdVoiceSynth.Clip) {
        guard settings.sound, let r = BirdVoiceSynth.resource(a.brain.profile.species, c) else { return }
        _ = a.puppet.holder.playAudio(r)
    }

    private func applySettings() {
        if !settings.birds { for a in birds { a.brain.update(dt: 0, view: YardView(), book: book) } }
    }

    /// Removes every animal immediately.
    public func clear() {
        for a in birds { a.audio?.stop(); a.puppet.holder.removeFromParent(); book.releaseAll(by: a.brain.id) }
        for a in ground { a.puppet.holder.removeFromParent() }
        birds.removeAll(); ground.removeAll()
    }

    /// Brings the next visitor in within a few seconds (the first launch, or a "call the birds" action).
    public func callVisitors() { scheduler.expedite(0.5) }
}
