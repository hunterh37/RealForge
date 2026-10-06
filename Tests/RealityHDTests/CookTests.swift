import Testing
import simd
@testable import RealCore

@Suite struct CookTests {
    /// Runs `seconds` with a 1/30 s frame at `speed`x, like the app.
    func run(_ seconds: Float, pan: inout VesselThermal, burner: Burner, food: inout [FoodThermal], face: Int) {
        let frame: Float = 1.0 / 30
        var t: Float = 0
        while t < seconds {
            var draw: Float = 0
            for i in food.indices { draw += food[i].step(frame, contact: pan.contact(face: face)) }
            pan.step(frame, watts: burner.absorbed(radius: pan.radius), foodDraw: draw)
            t += frame
        }
    }

    @Test func panPreheatsToSearingAndSmokesWhenLeft() {
        var pan = VesselThermal(metal: .castIron, radius: 0.12)
        pan.fat = 0.012; pan.smokePoint = 205
        var b = Burner(); b.level = 0.7
        var none: [FoodThermal] = []
        run(300, pan: &pan, burner: b, food: &none, face: 3)
        #expect(pan.temperature > 170 && pan.temperature < 260, "cast iron after 5 min medium-high: \(pan.temperature)")
        run(600, pan: &pan, burner: b, food: &none, face: 3)
        #expect(pan.isSmoking, "oil left 13 min on medium-high smokes: \(pan.temperature)")
    }

    @Test func chickenBreastCooksInRealTime() {
        var pan = VesselThermal(metal: .castIron, radius: 0.12)
        pan.fat = 0.012
        var b = Burner(); b.level = 0.65
        var none: [FoodThermal] = []
        run(300, pan: &pan, burner: b, food: &none, face: 3)
        var chicken = [FoodThermal(profile: Cook.profile(.protein), extent: V3(0.19, 0.02, 0.1))]
        run(330, pan: &pan, burner: b, food: &chicken, face: 3)
        let c1 = chicken[0]
        #expect(c1.browning[3] > 0.6 && c1.browning[3] < 1.4, "seared side after 5 min: \(c1.browning[3])")
        #expect(c1.browning[2] < 0.05, "top not browned: \(c1.browning[2])")
        #expect(!c1.isSafe, "not done after one side: core \(c1.core)")
        run(210, pan: &pan, burner: b, food: &chicken, face: 2)
        let c2 = chicken[0]
        #expect(c2.isSafe, "done after ~9 min flipped once: core \(c2.core) peak \(c2.peak)")
        #expect(c2.browning[2] > 0.6, "second side browned: \(c2.browning[2])")
        #expect(c2.maxBrowning < 1.7, "not burnt: \(c2.browning)")
    }

    @Test func forgottenChickenBurns() {
        var pan = VesselThermal(metal: .castIron, radius: 0.12)
        pan.fat = 0.012
        var b = Burner(); b.level = 1
        var none: [FoodThermal] = []
        run(200, pan: &pan, burner: b, food: &none, face: 3)
        var chicken = [FoodThermal(profile: Cook.profile(.protein), extent: V3(0.19, 0.022, 0.1))]
        run(1200, pan: &pan, burner: b, food: &chicken, face: 3)
        #expect(chicken[0].browning[3] > 1.6, "20 min on high, never flipped: \(chicken[0].browning[3])")
    }

    @Test func diceCookFasterThanWholeBreast() {
        let whole = FoodThermal(profile: Cook.profile(.protein), extent: V3(0.19, 0.022, 0.1))
        let die = whole.piece(extent: V3(0.02, 0.02, 0.02))
        var a = [whole], b2 = [die]
        var p1 = VesselThermal(metal: .stainless, radius: 0.12, temperature: 200); p1.fat = 0.01
        var p2 = p1
        var burner = Burner(); burner.level = 0.7
        run(150, pan: &p1, burner: burner, food: &a, face: 3)
        run(150, pan: &p2, burner: burner, food: &b2, face: 3)
        #expect(b2[0].core > a[0].core)
    }

    @Test func boilingWaterHoldsAt100() {
        var pot = VesselThermal(metal: .stainless, radius: 0.1)
        pot.water = 2
        var b = Burner(); b.level = 1
        var none: [FoodThermal] = []
        run(900, pan: &pot, burner: b, food: &none, face: 3)
        #expect(pot.isBoiling, "2 l boils within 15 min on high: \(pot.temperature)")
        #expect(pot.temperature <= 100.01)
        var carrot = [FoodThermal(profile: Cook.profile(.root), extent: V3(0.012, 0.025, 0.025))]
        run(480, pan: &pot, burner: b, food: &carrot, face: 3)
        #expect(carrot[0].coreDoneness > 0.8, "carrot coins tender after 8 min boil: \(carrot[0].coreDoneness)")
        #expect(carrot[0].maxBrowning == 0)
    }

    @Test func ovenPreheats() {
        var o = OvenThermal(); o.setpoint = 180
        for _ in 0..<(12 * 60) { o.step(1) }
        #expect(o.temperature > 150)
        for _ in 0..<(10 * 60) { o.step(1) }
        #expect(o.isPreheated)
    }

    @Test func faceLookup() {
        #expect(Cook.face(facing: V3(0, -1, 0)).face == 3)
        #expect(Cook.face(facing: V3(0.9, 0.1, 0)).face == 0)
    }
}
