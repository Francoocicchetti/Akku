import Foundation
@main struct PlaceHistoryTests {
    static func main() throws {
        var checks = 0
        func check(_ value: @autoclosure () -> Bool, _ message: String) {
            checks += 1; if !value() { fputs("FAIL: \(message)\n", stderr); exit(1) }
        }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 12))!
        let home = UUID(), work = UUID()
        func reading(_ seconds: Double, battery: Double? = 80, connected: Bool = false, charging: Bool = false, foreground: String? = "Safari", place: UUID? = nil, accuracy: Double = 20, fixAge: Double = 0, idle: Double = 0, awake: Bool = true) -> HistoryReading {
            let date = start.addingTimeInterval(seconds)
            let fix = place == nil ? nil : GeoFix(latitude: 40, longitude: 10, accuracy: accuracy, date: date.addingTimeInterval(-fixAge))
            return HistoryReading(date: date, uptime: seconds, percent: battery, connected: connected, charging: charging, awake: awake, idleSeconds: idle, foreground: foreground, apps: ["Safari": "Safari", "FaceTime": "FaceTime"], fix: fix, placeID: place)
        }
        var t = PlaceHistoryTracker(hardware: "fixture")
        t.ingest(reading(0, place: home), calendar: calendar)
        check(t.archive.apps.isEmpty && t.archive.places.isEmpty, "First reading doesn't invent historical use")
        t.ingest(reading(30, battery: 79, foreground: "FaceTime", place: home), calendar: calendar)
        check(t.archive.appSummary(since: start).count == 0, "Daily window is aligned to calendar midnight, not query noon")
        let midnight = calendar.startOfDay(for: start)
        let safari = t.archive.appSummary(since: midnight).first { $0.id == "Safari" }!
        check(safari.foregroundSeconds == 30 && safari.openSeconds == 30, "Foreground switch credits the app that owned the interval")
        let face = t.archive.appSummary(since: midnight).first { $0.id == "FaceTime" }!
        check(face.foregroundSeconds == 0 && face.openSeconds == 30, "An open FaceTime app is not automatically called active")
        check(t.archive.summary(placeID: home, since: midnight).batteryDrop == 1, "Discharge linked to stable precise place")
        t.ingest(reading(60, battery: 78, foreground: "FaceTime", place: home), calendar: calendar)
        check(t.archive.appSummary(since: midnight, placeID: home).first { $0.id == "FaceTime" }?.foregroundSeconds == 30, "Apps accumulate at their observed location")
        t.ingest(reading(90, battery: 77, place: work), calendar: calendar)
        check(t.archive.summary(placeID: home, since: midnight).batteryDrop == 2 && t.archive.summary(placeID: work, since: midnight).batteryDrop == 0, "Location transition is never attributed to either endpoint")
        t.ingest(reading(120, battery: 76, place: work, accuracy: 500), calendar: calendar)
        check(t.archive.summary(placeID: work, since: midnight).batteryDrop == 0, "Imprecise position is rejected")
        t.ingest(reading(150, battery: 75, place: work, fixAge: 700), calendar: calendar)
        check(t.archive.lastKnown?.date == start.addingTimeInterval(90), "Stale fixes do not replace last known location")
        let beforeIdle = t.archive.appSummary(since: midnight).reduce(0) { $0 + $1.foregroundSeconds }
        t.ingest(reading(180, place: home, idle: 400), calendar: calendar)
        t.ingest(reading(210, place: home, idle: 500), calendar: calendar)
        check(t.archive.appSummary(since: midnight).reduce(0) { $0 + $1.foregroundSeconds } == beforeIdle, "Idle time is excluded from active foreground totals")
        let beforeSleep = t.archive.apps.reduce(0) { $0 + $1.openSeconds }
        t.ingest(reading(240, awake: false), calendar: calendar)
        t.ingest(reading(5000, place: work), calendar: calendar)
        check(t.archive.apps.reduce(0) { $0 + $1.openSeconds } == beforeSleep, "Sleep and wake gaps don't count even as open-app time")
        let saved = try JSONDecoder().decode(PlaceHistoryArchive.self, from: JSONEncoder().encode(t.archive))
        var restarted = PlaceHistoryTracker(hardware: "fixture", saved: saved)
        restarted.ingest(reading(10000, battery: 40, place: home), calendar: calendar)
        check(restarted.archive.apps.reduce(0) { $0 + $1.openSeconds } == beforeSleep, "Restart does not reconstruct absent app time")
        check(PlaceHistoryTracker(hardware: "other", saved: saved).archive.apps.isEmpty, "History doesn't transfer across hardware")
        var charge = PlaceHistoryTracker(hardware: "fixture")
        charge.ingest(reading(0, connected: true, place: home), calendar: calendar)
        charge.ingest(reading(30, connected: true, place: home), calendar: calendar)
        check(charge.archive.events.isEmpty, "Plugged-in optimized-charge hold is not recorded as actual charging")
        charge.ingest(reading(60, connected: true, charging: true, place: home), calendar: calendar)
        charge.ingest(reading(90, battery: 81, connected: true, charging: true, place: home), calendar: calendar)
        charge.ingest(reading(120, battery: 82, connected: true, charging: true, place: home), calendar: calendar)
        check(charge.archive.events.filter { $0.kind == .charge }.count == 1, "One observed charging episode per place per connection")
        check(charge.archive.summary(placeID: home, since: midnight).chargeGain == 2, "Charging increase is aggregated independently from discharge")
        charge.ingest(reading(150, battery: 81, connected: true, charging: true, place: home), calendar: calendar)
        charge.ingest(reading(180, battery: 82, connected: true, charging: true, place: home), calendar: calendar)
        check(charge.archive.summary(placeID: home, since: midnight).chargeGain == 2, "Charge percentage bounce is not counted twice")
        charge.ingest(reading(210, battery: 82, place: home), calendar: calendar)
        charge.ingest(reading(240, battery: 82, connected: true, charging: true, place: home), calendar: calendar)
        charge.ingest(reading(270, battery: 83, connected: true, charging: true, place: home), calendar: calendar)
        check(charge.archive.events.filter { $0.kind == .charge }.count == 2, "A later recharge can be recognized")
        var low = PlaceHistoryTracker(hardware: "fixture")
        low.ingest(reading(0, battery: 10, place: home), calendar: calendar)
        low.ingest(reading(30, battery: 9, place: home), calendar: calendar)
        low.ingest(reading(60, battery: 3, place: home), calendar: calendar)
        low.ingest(reading(90, battery: 0, place: home), calendar: calendar)
        check(low.archive.events.map(\.kind) == [.low, .critical, .zero], "Separate evidence for low, critical and reported zero, no shutdown claim")
        var lowRestart = PlaceHistoryTracker(hardware: "fixture", saved: low.archive)
        lowRestart.ingest(reading(2000, battery: 0, place: home), calendar: calendar)
        check(lowRestart.archive.events.count == 3, "Low-battery latches survive restart and prevent repeated alerts/history")
        lowRestart.ingest(reading(2030, battery: 25, connected: true, charging: true, place: home), calendar: calendar)
        lowRestart.ingest(reading(2060, battery: 9, place: work), calendar: calendar)
        check(lowRestart.archive.events.filter { $0.kind == .low }.count == 2, "Recovery rearms a future low episode")
        var unknown = PlaceHistoryTracker(hardware: "fixture")
        unknown.ingest(reading(0, battery: 3), calendar: calendar)
        unknown.ingest(reading(30, battery: 3, place: home), calendar: calendar)
        check(unknown.archive.events.allSatisfy { $0.placeID == nil }, "New position cannot backfill where an earlier low event occurred")
        var missingBattery = PlaceHistoryTracker(hardware: "fixture")
        missingBattery.ingest(reading(0, battery: nil, place: home), calendar: calendar)
        missingBattery.ingest(reading(30, battery: nil, place: home), calendar: calendar)
        check(missingBattery.archive.summary(placeID: home, since: midnight).batterySeconds == 0, "Missing battery doesn't fabricate unplugged duration")
        check(missingBattery.archive.appSummary(since: midnight).first?.foregroundSeconds == 30, "App learning works independently of battery readings")
        var clock = PlaceHistoryTracker(hardware: "fixture")
        clock.ingest(reading(0, place: home), calendar: calendar)
        var jump = reading(30, place: home); jump.uptime = 10
        clock.ingest(jump, calendar: calendar)
        check(clock.archive.apps.isEmpty, "Clock discontinuities rejected")
        var split = PlaceHistoryTracker(hardware: "fixture")
        var a = reading(0, place: home); a.date = midnight.addingTimeInterval(-30); a.fix?.date = a.date
        var b = reading(60, battery: 79, place: home); b.date = midnight.addingTimeInterval(30); b.fix?.date = b.date
        split.ingest(a, calendar: calendar); split.ingest(b, calendar: calendar)
        check(split.archive.places.count == 2 && split.archive.places.allSatisfy { $0.batterySeconds == 30 && $0.batteryDrop == 0.5 }, "Midnight intervals split daily location energy exactly")
        check(split.archive.apps.filter { $0.bundleID == "Safari" }.allSatisfy { $0.foregroundSeconds == 30 }, "Daily app use splits at midnight")
        var fixture = PlaceHistoryArchive(hardware: "fixture")
        for index in 0..<3 {
            let date = calendar.date(byAdding: .day, value: index, to: midnight)!
            fixture.places.append(PlaceDayUsage(day: date, placeID: home, activeSeconds: 1800, batterySeconds: 1800, batteryDrop: 20))
            fixture.events.append(EnergyEvent(date: date.addingTimeInterval(1800), kind: .low, placeID: home, percent: 9))
        }
        check(fixture.summary(placeID: home, since: midnight, calendar: calendar).hasLowPattern, "Low pattern needs repeated days, denominator and sufficient observed time")
        fixture.events.removeLast()
        check(!fixture.summary(placeID: home, since: midnight, calendar: calendar).hasLowPattern, "Two low days are not a reliable recurring pattern")
        lowRestart.forgetPlaces()
        check(lowRestart.archive.places.isEmpty && lowRestart.archive.lastKnown == nil && lowRestart.archive.events.allSatisfy { $0.placeID == nil }, "Forget places removes last location and event associations")
        restarted.forgetPlaces()
        check(!restarted.archive.apps.isEmpty && restarted.archive.apps.allSatisfy { $0.places.isEmpty }, "Forget places preserves global daily app use without location links")
        check(!GeoFix(latitude: 100, longitude: 0, accuracy: 10, date: start).valid(at: start), "Reject invalid coordinates")
        check(!GeoFix(latitude: 0, longitude: 0, accuracy: -1, date: start).valid(at: start), "Reject negative accuracy")
        check(!GeoFix(latitude: 0, longitude: 0, accuracy: 10, date: start.addingTimeInterval(30)).valid(at: start), "Reject future location timestamps")
        print("PASS: \(checks) native-history model, foreground/open distinction, charging evidence, location attribution, low-battery patterns, restart/privacy and daily aggregation checks")
    }
}
