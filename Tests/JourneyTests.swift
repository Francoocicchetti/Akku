import Foundation
@main struct JourneyTests {
    static func main() throws {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            checks += 1; if !condition() { fputs("FAIL: \(message)\n", stderr); exit(1) }
        }
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let context = UsageContext(apps: ["Safari", "Preview"])
        func active() -> ActiveTrip {
            var a = ActiveTrip(startedAt: start, items: [.init(activity: .browsing, minutes: 60), .init(activity: .reading, minutes: 60)], initialRate: 15)
            a.initialBattery = 80; a.context = context
            a.rates = [.init(activity: .browsing, central: 20, high: 25, low: 15, raw: 20), .init(activity: .reading, central: 10, high: 15, low: 5, raw: 10)]
            return a
        }
        var a = active()
        a.pause(at: start.addingTimeInterval(1800), reason: "manual")
        check(a.elapsed(at: start.addingTimeInterval(3600)) == 1800, "Pause freezes active time")
        a.pause(at: start.addingTimeInterval(2700), reason: "sleep")
        check(a.pauseReason == "manual", "Sleep cannot overwrite manual pause")
        a.resume(at: start.addingTimeInterval(3600))
        check(a.elapsed(at: start.addingTimeInterval(5400)) == 3600, "Resume subtracts pause")
        check(a.remaining(at: start.addingTimeInterval(5400)).first?.activity == .reading, "Sequential activity advances by active time")
        check(a.predictedCost(at: start.addingTimeInterval(7200)) == 25, "Partial forecast respects sequential rates")
        check(a.remaining(at: start.addingTimeInterval(999999)).isEmpty, "Elapsed caps at planned duration")
        let paused = TripOutcome.make(a, endedAt: start.addingTimeInterval(7200), battery: 50)
        check(!paused.eligible && paused.exclusion == "paused", "Paused discharge is not used for correction")
        let half = TripOutcome.make(active(), endedAt: start.addingTimeInterval(1800), battery: 68)
        check(half.predictedBattery == 70 && half.actualBattery == 68 && half.error == -2, "Early finish compares elapsed forecast with actual battery")
        check(half.eligible && half.inRange == true && !half.completed, "Early comparable outcome records range coverage")
        var changing = active(); changing.conditionsChanged = true
        check(TripOutcome.make(changing, endedAt: start.addingTimeInterval(3600), battery: 50).exclusion == "conditions", "Changed conditions excluded")
        changing = active(); changing.hadCharging = true
        check(TripOutcome.make(changing, endedAt: start.addingTimeInterval(3600), battery: 90).exclusion == "charging", "Charging excluded")
        changing = active(); changing.hadGap = true
        check(TripOutcome.make(changing, endedAt: start.addingTimeInterval(3600), battery: 50).exclusion == "gap", "Absent app excluded")
        check(!TripOutcome.make(active(), endedAt: start.addingTimeInterval(60), battery: 79).eligible, "Short outing not calibrated")
        let decoder = JSONDecoder(), encoder = JSONEncoder()
        var legacy = try JSONSerialization.jsonObject(with: encoder.encode(active())) as! [String: Any]
        for key in ["initialBattery", "rates", "context", "lastObserved"] { legacy.removeValue(forKey: key) }
        let migrated = try decoder.decode(ActiveTrip.self, from: JSONSerialization.data(withJSONObject: legacy))
        check(migrated.initialBattery == nil && !migrated.isPaused, "V2 active trip migrates without fabricated battery")
        let restored = try decoder.decode(ActiveTrip.self, from: encoder.encode(a))
        check(restored.pausedSeconds == 1800, "Pause duration persists")
        let end = start.addingTimeInterval(3600)
        let outcome = TripOutcome.make(active(), endedAt: start.addingTimeInterval(7200), battery: 39)
        let calibrationTime = start.addingTimeInterval(7200)
        let cal = Calibration(outcomes: [outcome, outcome, outcome])
        check(cal.factor(items: active().items, context: context, now: calibrationTime) > 1, "Repeated underprediction increases forecast cost")
        check(cal.factor(items: active().items, context: UsageContext(externalDisplays: 1), now: calibrationTime) == 1, "Correction doesn't transfer across environments")
        check(cal.factor(items: active().items, context: UsageContext(apps: ["Other"]), now: calibrationTime) == 1, "Correction doesn't transfer across app combinations")
        check(Calibration(outcomes: [outcome]).factor(items: active().items, context: context, now: calibrationTime) == 1, "No correction from a single outing")
        check(cal.meanAbsoluteError == 11 && cal.coverage == 0, "Validation reports mean absolute error and actual coverage")
        check(ChargeTarget.make(cost: 90, reserve: 15).reachable == false, "Impossible target not silently clamped")
        check(ChargeTarget.make(cost: 40.1, reserve: 15).percent == 56, "Target rounds upward")
        var charge = ChargeAccumulator(); var chargeResult: ChargeSample?
        for i in 0...6 { chargeResult = charge.ingest(date: start.addingTimeInterval(Double(i) * 30), percent: 40 + Double(i) / 3, charging: true, adapter: "30W") ?? chargeResult }
        check(chargeResult?.gain == 2 && chargeResult?.band == 0, "Observed charge sample")
        charge.reset(); _ = charge.ingest(date: start, percent: 40, charging: true, adapter: "30W")
        check(charge.ingest(date: start.addingTimeInterval(3600), percent: 70, charging: true, adapter: "30W") == nil, "Charge gap rejected")
        let cs = ChargeSample(date: start, minutes: 3, gain: 2, band: 0, adapter: "30W")
        check(ChargeETA.estimate(from: 40, target: 50, adapter: "30W", samples: [cs,cs], now: end) == nil, "Few charge samples means no ETA")
        let eta = ChargeETA.estimate(from: 40, target: 50, adapter: "30W", samples: [cs,cs,cs], now: end)
        check(eta != nil && eta!.lower < 15 && eta!.upper > 15, "Charge ETA provides a conservative range")
        check(ChargeETA.estimate(from: 40, target: 70, adapter: "30W", samples: [cs,cs,cs], now: end) == nil, "ETA needs observations for every battery band crossed")
        check(ChargeETA.estimate(from: 40, target: 50, adapter: "60W", samples: [cs,cs,cs], now: end) == nil, "Different adapter doesn't reuse rates")
        let sample = DischargeSample(date: end, minutes: 15, drop: 5, activity: .browsing, appID: nil, confirmed: true, mode: "normal", context: context)
        var alerts = SmartAlertState()
        check(!alerts.evaluate(sample: sample, at: end, shortfallMinutes: 30, isPaused: false), "One discharge spike doesn't alert")
        check(!alerts.evaluate(sample: sample, at: end, shortfallMinutes: 30, isPaused: false), "Repeated polling not counted twice")
        let next = DischargeSample(date: end.addingTimeInterval(900), minutes: 15, drop: 5, activity: .browsing, appID: nil, confirmed: true, mode: "normal")
        check(alerts.evaluate(sample: next, at: next.date, shortfallMinutes: 30, isPaused: false), "Two sustained intervals alert")
        alerts.snooze(at: next.date)
        let third = DischargeSample(date: next.date.addingTimeInterval(600), minutes: 10, drop: 3, activity: .browsing, appID: nil, confirmed: true, mode: "normal")
        check(!alerts.evaluate(sample: third, at: third.date, shortfallMinutes: 30, isPaused: false), "Snooze respected")
        var gate = DepartureGate()
        check(!gate.ingest(.away, fix: start, now: start), "No departure without prior home")
        let homeTime = start.addingTimeInterval(300)
        _ = gate.ingest(.home, fix: homeTime, now: homeTime)
        let outside = start.addingTimeInterval(600)
        check(!gate.ingest(.away, fix: outside, now: outside), "Single outside fix doesn't notify")
        check(!gate.ingest(.away, fix: outside, now: outside.addingTimeInterval(300)), "Same cached fix never counts twice")
        check(gate.ingest(.away, fix: outside.addingTimeInterval(300), now: outside.addingTimeInterval(300)), "Two accurate outside fixes confirm departure")
        _ = gate.ingest(.home, fix: start.addingTimeInterval(1000), now: start.addingTimeInterval(1000))
        _ = gate.ingest(.away, fix: start.addingTimeInterval(1300), now: start.addingTimeInterval(1300))
        check(!gate.ingest(.away, fix: start.addingTimeInterval(1600), now: start.addingTimeInterval(1600)), "Departure cooldown prevents nagging")
        var places = PlaceLearner()
        for i in 0...12 {
            let date = start.addingTimeInterval(Double(i) * 300)
            places.observe(latitude: 10, longitude: 20, accuracy: 20, date: date, now: date)
        }
        check(places.places.count == 1 && places.places[0].dwellMinutes == 60, "Stable fixes accumulate dwell at a single place")
        check(!places.places[0].suggested, "One visit isn't enough for a place suggestion")
        let elsewhere = start.addingTimeInterval(4000)
        places.observe(latitude: 11, longitude: 20, accuracy: 20, date: elsewhere, now: elsewhere)
        let returning = start.addingTimeInterval(6000)
        places.observe(latitude: 10, longitude: 20, accuracy: 20, date: returning, now: returning)
        check(places.places[0].visits == 2 && places.places[0].suggested, "Return visit with enough dwell suggests a place")
        check(places.places[0].name == nil, "Learning never labels a home without confirmation")
        places.observe(latitude: 30, longitude: 40, accuracy: 500, date: returning.addingTimeInterval(300), now: returning.addingTimeInterval(300))
        check(places.places.count == 2, "Imprecise fixes don't create places")
        let roundtrip = try decoder.decode(PlaceLearner.self, from: encoder.encode(places))
        check(roundtrip.places.count == 2, "Aggregated places persist")
        var engine = ForecastEngine(samples: Array(repeating: sample, count: 5), baselineHours: 10, mode: "normal", now: end, context: context)
        let familiar = engine.estimate(activity: .browsing, battery: 80, reserve: 15)
        engine.context = UsageContext(externalDisplays: 1, apps: ["Safari"])
        let unknown = engine.estimate(activity: .browsing, battery: 80, reserve: 15)
        check(familiar.contextMatched && !unknown.contextMatched && unknown.confidence == .low, "New environment lowers confidence")
        check(unknown.highRate - unknown.lowRate >= familiar.highRate - familiar.lowRate, "Unfamiliar context widens range")
        print("PASS: \(checks) journey, migration, calibration, charging, place-learning and sustained-alert checks")
    }
}
