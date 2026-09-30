import Foundation

@main
struct LearningTests {
    static func main() throws {
        var checks = 0
        func check(_ value: @autoclosure () -> Bool, _ message: String) {
            checks += 1
            if !value() { fputs("FAIL: \(message)\n", stderr); exit(1) }
        }
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        func observation(_ seconds: Double, _ percent: Double, battery: Bool = true, activity: Activity? = .browsing, confirmed: Bool = true, mode: String = "normal") -> Observation {
            Observation(date: start.addingTimeInterval(seconds), percent: percent, onBattery: battery, activity: activity, appID: "com.apple.Safari", confirmed: confirmed, mode: mode)
        }
        var acc = DischargeAccumulator()
        var result: DischargeSample?
        for i in 0...10 { result = acc.ingest(observation(Double(i) * 60, 80 - Double(i) * 0.2)) ?? result }
        check(result != nil, "Measurable 10-minute awake discharge produces sample")
        check(result?.activity == .browsing && result?.confirmed == true, "Stable confirmed activity attributed")
        check(abs((result?.rate ?? 0) - 12) < 0.0001, "Rate reflects actual percentage drop per hour")
        acc.reset()
        for i in 0...30 { check(acc.ingest(observation(Double(i) * 60, 80 - Double(i) * 0.2, battery: false)) == nil, "Charging never creates samples") }
        acc.reset(); _ = acc.ingest(observation(0, 80)); _ = acc.ingest(observation(3600, 70))
        check(acc.minutes == 0, "Sleep gap resets learning")
        _ = acc.ingest(observation(3660, 71)); check(acc.minutes == 0, "Increasing percentage resets learning")
        _ = acc.ingest(observation(3670, 70, mode: "low")); check(acc.minutes == 0, "Power mode change resets interval")
        acc.reset(); _ = acc.ingest(observation(60, 80)); _ = acc.ingest(observation(0, 80)); check(acc.minutes == 0, "Clock reversal resets")
        acc.reset(); result = nil
        for i in 0...10 { result = acc.ingest(observation(Double(i) * 60, 80 - Double(i) * 0.2, activity: i < 5 ? .browsing : .meeting)) ?? result }
        check(result != nil && result?.activity == nil, "Mixed workloads are not mislabeled as a single activity")
        acc.reset(); result = nil
        for i in 0...45 { result = acc.ingest(observation(Double(i) * 60, 80)) ?? result }
        check(result == nil, "No drop does not teach infinite runtime")
        let sample = DischargeSample(date: start, minutes: 20, drop: 4, activity: .browsing, appID: nil, confirmed: true, mode: "normal")
        let now = start.addingTimeInterval(86400 * 5)
        var engine = ForecastEngine(samples: [], baselineHours: 10, mode: "normal", now: now)
        let empty = engine.estimate(activity: .browsing, battery: 80, reserve: 15)
        check(empty.confidence == .low && empty.sampleCount == 0, "Cold start honestly reports low confidence")
        check(empty.lowerMinutes < 390 && empty.upperMinutes > 390, "Prior is represented as a range")
        engine.samples = [sample]
        check(engine.estimate(activity: .browsing, battery: 80, reserve: 15).centralRate > 10, "Observed discharge adjusts the prior")
        check(engine.estimate(activity: .meeting, battery: 80, reserve: 15).sampleCount == 0, "No learning leakage across activities")
        engine.samples = (0..<16).map { i in DischargeSample(date: start.addingTimeInterval(Double(i / 4) * 86400 + Double(i % 4) * 1800), minutes: 30, drop: 6, activity: .browsing, appID: nil, confirmed: true, mode: "normal") }
        let trained = engine.estimate(activity: .browsing, battery: 80, reserve: 15)
        check(trained.confidence == .high && abs(trained.centralRate - 12) < 0.001, "Consistent multi-day confirmed observations replace prior")
        engine.samples = engine.samples.map { .init(date: $0.date, minutes: $0.minutes, drop: $0.drop, activity: $0.activity, appID: nil, confirmed: false, mode: $0.mode) }
        check(engine.estimate(activity: .browsing, battery: 80, reserve: 15).confidence != .high, "Inferred activity alone cannot reach high confidence")
        engine = ForecastEngine(samples: [sample], baselineHours: 10, mode: "low", now: now)
        check(engine.estimate(activity: .browsing, battery: 80, reserve: 15).sampleCount == 0, "Different power modes are kept separate")
        engine = ForecastEngine(samples: [sample], baselineHours: 10, mode: "normal", now: start.addingTimeInterval(61 * 86400))
        check(engine.estimate(activity: .browsing, battery: 80, reserve: 15).sampleCount == 0, "Stale evidence excluded")
        engine = ForecastEngine(samples: [sample], baselineHours: 10, mode: "normal", now: start.addingTimeInterval(-1))
        check(engine.estimate(activity: .browsing, battery: 80, reserve: 15).sampleCount == 0, "Future evidence excluded")
        check(engine.estimate(activity: .browsing, battery: 10, reserve: 15).upperMinutes == 0, "Range respects exhausted reserve")
        check(TripVerdict.evaluate(battery: 80, reserve: 15, centralCost: 40, conservativeCost: 60) == .comfortable, "Conservative plan fits")
        check(TripVerdict.evaluate(battery: 45, reserve: 15, centralCost: 35, conservativeCost: 48) == .tight, "Central-only fit is not reassuring")
        check(TripVerdict.evaluate(battery: 30, reserve: 15, centralCost: 35, conservativeCost: 48) == .insufficient, "Insufficient battery")
        check(TripVerdict.evaluate(battery: nil, reserve: 15, centralCost: 35, conservativeCost: 48) == .unavailable, "No invented battery")
        let active = ActiveTrip(startedAt: start, items: [.init(activity: .browsing, minutes: 60), .init(activity: .meeting, minutes: 60)], initialRate: 8)
        let after = active.remaining(at: start.addingTimeInterval(75 * 60))
        check(after.count == 1 && after[0].activity == .meeting && after[0].minutes == 45, "Sequential outing clock")
        check(active.remaining(at: start.addingTimeInterval(120 * 60)).isEmpty, "Completed outing has no tasks")
        check(AlertPolicy.shouldWarn(active: active, sample: sample, now: start.addingTimeInterval(60), available: 65, projectedCost: 20), "Higher discharge warns")
        var warned = active; warned.warned = true
        check(!AlertPolicy.shouldWarn(active: warned, sample: sample, now: start.addingTimeInterval(60), available: 65, projectedCost: 20), "No repeated alert within outing")
        check(!AlertPolicy.shouldWarn(active: active, sample: sample, now: start.addingTimeInterval(-1), available: 0, projectedCost: 20), "Future sample cannot trigger warning")
        check(HomeClassifier.classify(distance: 0, accuracy: 30, homeAccuracy: 30, radius: 300, age: 10) == .home, "Reliable home fix")
        check(HomeClassifier.classify(distance: 800, accuracy: 50, homeAccuracy: 30, radius: 300, age: 10) == .away, "Reliable away fix")
        check(HomeClassifier.classify(distance: 310, accuracy: 50, homeAccuracy: 30, radius: 300, age: 10) == .unknown, "Boundary buffer avoids false departure")
        check(HomeClassifier.classify(distance: 1000, accuracy: 400, homeAccuracy: 30, radius: 300, age: 10) == .unknown, "Poor accuracy is unknown")
        check(HomeClassifier.classify(distance: 0, accuracy: 30, homeAccuracy: 30, radius: 300, age: 601) == .unknown, "Stale home location is unknown")
        check(HomeClassifier.classify(distance: 0, accuracy: -1, homeAccuracy: 30, radius: 300, age: 10) == .unknown, "Invalid accuracy rejected")
        for (identifier, name) in HardwareProfile.models {
            check(HardwareProfile.identify(identifier: identifier, chip: "Apple M", hasBattery: true).name == name, "Recognized Air/Pro catalog entry")
        }
        check(HardwareProfile.identify(identifier: "Mac17,5", chip: "Apple A18 Pro", hasBattery: true).name.contains("Neo"), "Neo identified independently of M-series")
        check(!HardwareProfile.identify(identifier: "Mac17,5", chip: "Apple A18 Pro", hasBattery: true).supported, "Neo remains outside the current M1-M5 release scope")
        check(!HardwareProfile.identify(identifier: "Unknown", chip: "Unknown", hasBattery: true).supported, "Unknown device not falsely certified")
        check(AppCategory.suggestedActivity(bundleID: "com.apple.FaceTime") == .meeting, "FaceTime native bundle match")
        check(AppCategory.suggestedActivity(bundleID: "com.apple.Safari") == .browsing, "Safari native bundle match")
        check(AppCategory.suggestedActivity(bundleID: "com.openai.chat") == .writing, "ChatGPT native bundle match")
        check(AppCategory.suggestedActivity(bundleID: "net.whatsapp.WhatsApp") == .writing, "WhatsApp does not imply a call")
        check(AppCategory.suggestedActivity(bundleID: "org.unknown.editor") == nil, "Unknown apps remain unclassified")
        let recent = DischargeSample(date: now.addingTimeInterval(-60), minutes: 20, drop: 10, activity: .browsing, appID: nil, confirmed: true, mode: "normal")
        engine = ForecastEngine(samples: [recent], baselineHours: 10, mode: "normal", now: now)
        let smoothed = engine.estimate(activity: .browsing, battery: 80, reserve: 15)
        let live = engine.estimate(activity: .browsing, battery: 80, reserve: 15, includeRecent: true)
        check(live.lowerMinutes < smoothed.lowerMinutes && live.usingRecent, "Recent higher drain reduces runtime conservatively")
        check(abs(engine.tripCost([.init(activity: .browsing, minutes: 60)], conservative: true) - live.highRate) < 0.0001, "Trip verdict and runtime range use the same recent rate")
        check(live.lowerMinutes >= 0 && live.upperMinutes >= live.lowerMinutes, "Recent ranges remain ordered")
        let variable = (0..<16).map { i in DischargeSample(date: now.addingTimeInterval(-Double(i) * 1800), minutes: 30, drop: i % 2 == 0 ? 2 : 15, activity: .browsing, appID: nil, confirmed: true, mode: "normal") }
        engine = ForecastEngine(samples: variable, baselineHours: 10, mode: "normal", now: now)
        check(engine.estimate(activity: .browsing, battery: 80, reserve: 15).confidence == .low, "Volatile consumption is not assigned high confidence")
        let routine = Routine(name: "Clase del martes", items: [.init(activity: .writing, minutes: 60)])
        let saved = try JSONDecoder().decode(Routine.self, from: JSONEncoder().encode(routine))
        check(saved.name == routine.name && saved.items == routine.items, "Routines persist exact user data")
        print("PASS: \(checks) learning, forecast, alerts, location, hardware and app-classification checks")
    }
}
