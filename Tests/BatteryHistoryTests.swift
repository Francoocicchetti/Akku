import Foundation
@main struct BatteryHistoryTests {
    static func main() throws {
        var count = 0
        func check(_ value: @autoclosure () -> Bool, _ name: String) {
            count += 1; if !value() { fputs("FAIL: \(name)\n", stderr); exit(1) }
        }
        func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.001 }
        let base = Date(timeIntervalSinceReferenceDate: 810000000) // aligned 5 min
        func reading(_ seconds: Double, level: Double? = 80, connected: Bool = false, charging: Bool = false, screen: Bool = true, uptime: Double? = nil) -> BatteryHistoryReading {
            .init(date: base.addingTimeInterval(seconds), uptime: uptime ?? 10000 + seconds, percent: level, connected: connected, charging: charging, screenOn: screen)
        }
        var tracker = BatteryHistoryTracker(hardware: "Test")
        tracker.ingest(reading(0))
        check(tracker.archive.buckets.count == 1, "First real level recorded")
        check(tracker.archive.buckets[0].observed == 0, "No invented past time")
        tracker.ingest(reading(60, level: 79))
        check(tracker.archive.buckets[0].screen == 60, "Time with screen on counted")
        check(tracker.archive.buckets[0].minimum == 79 && tracker.archive.buckets[0].maximum == 80, "Range retained")
        check(tracker.archive.buckets[0].level == 79, "Most recent level retained")
        tracker.ingest(reading(60, level: 2))
        check(tracker.archive.buckets[0].level == 79 && tracker.archive.buckets[0].screen == 60, "Duplicate time doesn't alter history")
        tracker.ingest(reading(30, level: 1))
        tracker.ingest(reading(90, level: 78))
        check(tracker.archive.buckets[0].screen == 90, "Backward clock doesn't double count")
        tracker.ingest(reading(600, level: 70))
        check(tracker.archive.buckets.reduce(0) { $0 + $1.screen } == 90, "Long gaps excluded")
        tracker.interrupt(); tracker.ingest(reading(660))
        check(tracker.archive.buckets.reduce(0) { $0 + $1.screen } == 90, "Sleep/pause breaks continuity")
        tracker.ingest(reading(720, screen: false))
        tracker.ingest(reading(780, screen: false))
        check(tracker.archive.buckets.reduce(0) { $0 + $1.screen } == 150, "Display-off time excluded")
        check(tracker.archive.buckets.reduce(0) { $0 + $1.observed } == 210, "Display-off observation remains distinct")
        var boundary = BatteryHistoryTracker(hardware: "Test")
        boundary.ingest(reading(270, connected: true, charging: true))
        boundary.ingest(reading(330, level: 81, connected: false))
        check(boundary.archive.buckets.count == 2, "Splits at five-minute boundary")
        check(boundary.archive.buckets.allSatisfy { $0.screen == 30 && $0.connected == 30 && $0.charging == 30 }, "Time before unplug belongs to previous power state")
        boundary.ingest(reading(390))
        check(boundary.archive.buckets[1].connected == 30 && boundary.archive.buckets[1].screen == 90, "On battery time is separate")
        let roundtrip = try JSONDecoder().decode(BatteryHistoryArchive.self, from: JSONEncoder().encode(boundary.archive))
        var restored = BatteryHistoryTracker(hardware: "Test", saved: roundtrip, now: base.addingTimeInterval(400))
        check(restored.archive.buckets.count == 2, "Archive reload")
        restored.ingest(reading(420))
        check(restored.archive.buckets.reduce(0) { $0 + $1.screen } == 120, "Restart never fills unobserved interval")
        check(BatteryHistoryTracker(hardware: "Other", saved: roundtrip, now: base.addingTimeInterval(400)).archive.buckets.isEmpty, "Different hardware rejected")
        var future = roundtrip; future.version = 2
        check(BatteryHistoryTracker(hardware: "Test", saved: future).archive.buckets.isEmpty, "Unknown schema rejected")
        var invalid = BatteryHistoryArchive(hardware: "Test")
        invalid.buckets = [.init(start: base, level: 101), .init(start: base.addingTimeInterval(300), observed: -1), .init(start: base.addingTimeInterval(600), observed: 2, screen: 3), .init(start: base.addingTimeInterval(900), observed: 10, connected: 1, charging: 2), .init(start: base.addingTimeInterval(1200), level: .nan), .init(start: base.addingTimeInterval(1800)), .init(start: base.addingTimeInterval(-12 * 86400))]
        check(BatteryHistoryTracker(hardware: "Test", saved: invalid, now: base.addingTimeInterval(1300)).archive.buckets.isEmpty, "Invalid, future and expired rows rejected")
        var missing = BatteryHistoryTracker(hardware: "Test")
        missing.ingest(reading(0, level: nil)); missing.ingest(reading(60, level: .nan))
        check(missing.archive.buckets.first?.level == nil && missing.archive.buckets.first?.screen == 60, "Missing battery doesn't invent zero; screen remains measurable")
        var jumped = BatteryHistoryTracker(hardware: "Test")
        jumped.ingest(reading(0)); jumped.ingest(reading(60, uptime: 10010))
        check(jumped.archive.buckets[0].observed == 0, "Wall/monotonic mismatch excluded")
        var workload = BatteryHistoryTracker(hardware: "Test")
        for minute in 0...120 { workload.ingest(reading(Double(minute * 60), level: 80 - Double(minute) / 6, connected: minute < 30, charging: minute < 20)) }
        check(workload.archive.buckets.count == 25, "Two hours compacted to 25 buckets")
        check(workload.archive.buckets.allSatisfy(\.valid), "All produced buckets satisfy constraints")
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let hourSummary = BatteryHistorySummary(archive: workload.archive, period: .hours24, now: base.addingTimeInterval(7200), calendar: utc)
        check(near(hourSummary.screenSeconds, 7200), "Hourly aggregation conserves observed time")
        check(near(hourSummary.connectedSeconds, 1800), "Charging and plugged intervals counted accurately")
        check(hourSummary.usage.allSatisfy { $0.screen <= 3600.01 }, "Hourly bars cannot exceed 60 min")
        check(hourSummary.levels.count < 288, "No fake bars before collection")
        let days = BatteryHistorySummary(archive: workload.archive, period: .days10, now: base.addingTimeInterval(7200), calendar: utc)
        check(days.usage.count == 10, "Ten calendar days")
        check(near(days.screenSeconds, 7200), "Daily aggregation conserves time")
        check(days.usage.filter { $0.level == nil }.count >= 8, "Unobserved days remain missing")
        check(days.levels.compactMap(\.level).allSatisfy { (60...80).contains($0) }, "Daily average stays inside observed range")
        let clipped = BatteryHistorySummary(archive: workload.archive, period: .hours24, now: base.addingTimeInterval(86400 + 3600), calendar: utc)
        check(near(clipped.screenSeconds, 3600), "Sliding window excludes old hours")
        var long = BatteryHistoryTracker(hardware: "Test")
        for day in 0...15 { long.ingest(reading(Double(day * 86400))); long.ingest(reading(Double(day * 86400 + 60))) }
        check(long.archive.buckets.allSatisfy { $0.start >= base.addingTimeInterval(4 * 86400) }, "Retention bounded")
        var dense = BatteryHistoryTracker(hardware: "Test")
        for second in 0...600 { dense.ingest(reading(Double(second))) }
        check(dense.archive.buckets.count == 3 && dense.archive.buckets.reduce(0) { $0 + $1.screen } == 600, "Frequent events do not multiply duration or storage")
        var duplicate = roundtrip; duplicate.buckets += roundtrip.buckets
        check(BatteryHistoryTracker(hardware: "Test", saved: duplicate, now: base.addingTimeInterval(400)).archive.buckets.count == 2, "Duplicate persisted buckets removed")
        // DST calendar days may contain 23 or 25 hours; elapsed time remains real.
        var ny = Calendar(identifier: .gregorian); ny.timeZone = TimeZone(identifier: "America/New_York")!
        for components in [DateComponents(year: 2026, month: 3, day: 9, hour: 12), DateComponents(year: 2026, month: 11, day: 2, hour: 12)] {
            let now = ny.date(from: components)!
            let summary = BatteryHistorySummary(archive: .init(hardware: "Test"), period: .days10, now: now, calendar: ny)
            check(summary.usage.count == 10, "DST still displays 10 calendar days")
            check(Set(summary.usage.map(\.start)).count == 10, "DST doesn't duplicate dates")
            check(summary.usage.contains { abs($0.end.timeIntervalSince($0.start) - 86400) > 100 && $0.end != now }, "DST day uses actual elapsed length")
        }
        print("PASS: \(count) battery history checks: real levels, charging, display time, gaps, restart, retention, aggregation and DST")
    }
}
