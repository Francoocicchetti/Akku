import Foundation
@main struct CompanionTests {
    static func main() {
        var count = 0
        func check(_ value: @autoclosure () -> Bool, _ label: String) {
            count += 1; if !value() { fputs("FAIL: \(label)\n", stderr); exit(1) }
        }
        var c = CompanionContext(battery: 80)
        check(c.mood == .ready, "Normal energy gives calm ready state")
        c.battery = 95; check(c.mood == .full, "Full battery celebrates gently")
        c.battery = 20; check(c.mood == .low, "Low energy looks tired")
        c.battery = 8; check(c.mood == .exhausted, "Critical battery takes priority")
        c.charging = true; check(c.mood == .charging, "Actual charging feeds Akku")
        c.charging = false; c.connected = true
        check(c.mood != .charging && c.mood != .exhausted, "Plugged in but not charging is not eating")
        c.connected = false; c.battery = 80; c.activeMinutes = 60
        check(c.mood == .breakTime, "Long session triggers a visual break cue")
        c.busy = true; check(c.mood != .breakTime, "Planned call or screen sharing suppresses rest suggestion")
        c.busy = false; c.quiet = true; check(c.mood != .breakTime, "Quiet mode suppresses rest suggestion")
        c.quiet = false; c.reminders = false; check(c.mood != .breakTime, "User can disable gentle suggestions")
        c.activeMinutes = 0; c.reminders = true; c.hour = 23
        check(c.mood == .evening, "Local hour gives a quieter evening state")
        c.hour = 14; c.away = true; check(c.mood == .away, "Confirmed away context changes companion state")
        c.battery = nil; check(!c.message(.es).contains("100"), "No invented percentage when battery is unknown")
        for mood in AkkuMood.allCases { check(!mood.name(.en).isEmpty && !mood.name(.es).isEmpty, "Every mood is bilingual") }
        var session = UsageSession()
        session.tick(uptime: 100, idleSeconds: 0, asleep: false)
        for i in 1...20 { session.tick(uptime: 100 + Double(i) * 30, idleSeconds: 20, asleep: false) }
        check(session.seconds == 600, "Awake recent use advances session clock")
        session.tick(uptime: 730, idleSeconds: 310, asleep: false)
        check(session.seconds == 0, "Five minutes idle resets session")
        session.tick(uptime: 760, idleSeconds: 0, asleep: false)
        check(session.seconds == 30, "Return after break starts a fresh session")
        session.tick(uptime: 5000, idleSeconds: 0, asleep: false)
        check(session.seconds == 0, "Large unobserved gap is not computer-use time")
        session.tick(uptime: 5030, idleSeconds: 0, asleep: true)
        check(session.seconds == 0, "Sleep does not accrue use")
        check(ManualPosition.validCoordinates(-33.4, -70.6), "Valid Southern Hemisphere coordinates")
        check(!ManualPosition.validCoordinates(91, 0), "Latitude boundary rejected")
        check(!ManualPosition.validCoordinates(0, -181), "Longitude boundary rejected")
        check(!ManualPosition.validCoordinates(.nan, 0), "NaN rejected")
        check(!ManualPosition.validCoordinates(0, .infinity), "Infinity rejected")
        let time = Date(timeIntervalSince1970: 1_700_000_000)
        let manual = ManualPosition(latitude: 10, longitude: 20, label: "Test", date: time)
        check(manual.valid(at: time.addingTimeInterval(1799)), "Manual fix valid before 30 minutes")
        check(!manual.valid(at: time.addingTimeInterval(1800)), "Manual fix expires exactly at 30 minutes")
        check(!manual.valid(at: time.addingTimeInterval(-1)), "Future manual fix rejected")
        let near = HomeDistance(meters: 1000, uncertainty: 100, manual: false)
        let far = HomeDistance(meters: 12000, uncertainty: 150, manual: false)
        check(!near.far && far.far, "Distance indicates near or far")
        check(!HomeDistance(meters: 5100, uncertainty: 300, manual: false).far, "Uncertainty prevents a false far label")
        check(HomeDistance(meters: 30, uncertainty: 100, manual: true).lower == 0, "Distance lower bound never negative")
        var plan = ReturnPlan(battery: 80, distance: far, highRate: 20)
        check(plan.advice == .askReturnTime, "Far alone cannot promise charging at home")
        plan.returnMinutes = 30; plan.workMinutes = 60
        check(plan.advice == .probablyHome, "Conservative plan fits with reserve")
        plan.battery = 20
        check(plan.advice == .chargeNearby, "Insufficient work reserve recommends charging nearby")
        plan.distance = near; plan.battery = 8; plan.workMinutes = 0
        check(plan.advice == .chargeNearby, "Low battery recommends charging even close to home")
        plan.battery = 40; plan.returnMinutes = 120; plan.workMinutes = 0
        check(plan.advice == .probablyHome, "Closed-Mac allowance is distinct from work rate")
        plan.usageDuringTravel = true
        check(plan.advice == .chargeNearby, "Working during a long return changes advice")
        plan.distance = nil; check(plan.advice == .unknown, "No distance means no invented location-based advice")
        plan.presence = .home; check(plan.advice == .atHome, "Confirmed home is handled directly")
        plan.connected = true; check(plan.advice == .connected, "Connected state takes precedence")
        plan.connected = false; plan.battery = nil; check(plan.advice == .unknown, "Missing battery doesn't produce assurance")
        print("PASS: \(count) Akku mood, quiet mode, use-time, manual position and return-planning checks")
    }
}
