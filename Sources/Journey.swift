import Foundation

struct UsageContext: Codable, Equatable, Hashable {
    var externalDisplays: Int = 0
    var lowPower = false
    var heavyLoad = false
    var screenSharing = false // User-selected; never inferred from private screen or call contents.
    var apps: [String] = []
    var environmentKey: String { "\(externalDisplays)|\(lowPower)|\(heavyLoad)|\(screenSharing)" }
    var combinationKey: String { apps.sorted().joined(separator: "|") }
    func sameConditions(as other: UsageContext) -> Bool { environmentKey == other.environmentKey }
}

struct FrozenRate: Codable {
    let activity: Activity
    let central: Double
    let high: Double
    let low: Double
    let raw: Double
}

struct ActiveTrip: Codable {
    var id = UUID()
    let startedAt: Date
    let items: [TripItem]
    let initialRate: Double
    var warned = false
    // Optional fields preserve v2 archives without inventing a starting charge.
    var initialBattery: Double?
    var rates: [FrozenRate]?
    var context: UsageContext?
    var pausedAt: Date?
    var pauseReason: String?
    var pausedSeconds: Double?
    var hadCharging: Bool?
    var hadGap: Bool?
    var conditionsChanged: Bool?
    var lastObserved: Date?
    var lastBattery: Double?
    var alertState: SmartAlertState?
    var validationLabel: String?
    var totalMinutes: Double { Double(items.reduce(0) { $0 + $1.minutes }) }
    var isPaused: Bool { pausedAt != nil }
    func elapsed(at now: Date) -> Double {
        max(0, min(totalMinutes * 60, (pausedAt ?? now).timeIntervalSince(startedAt) - (pausedSeconds ?? 0)))
    }
    func remaining(at now: Date) -> [TripItem] {
        var minutes = elapsed(at: now) / 60
        return items.compactMap { item in
            if minutes >= Double(item.minutes) { minutes -= Double(item.minutes); return nil }
            let left = Int(ceil(Double(item.minutes) - minutes)); minutes = 0
            return TripItem(id: item.id, activity: item.activity, minutes: left)
        }
    }
    mutating func pause(at date: Date, reason: String) {
        guard !isPaused else { return }
        pausedAt = date; pauseReason = reason
    }
    mutating func resume(at date: Date) {
        guard let pausedAt else { return }
        pausedSeconds = (pausedSeconds ?? 0) + max(0, date.timeIntervalSince(pausedAt))
        self.pausedAt = nil; pauseReason = nil; lastObserved = date
    }
    func predictedCost(at now: Date, kind: String = "central") -> Double? {
        guard let rates else { return nil }
        var minutes = elapsed(at: now) / 60
        return items.reduce(0) { total, item in
            let used = min(minutes, Double(item.minutes)); minutes = max(0, minutes - used)
            guard let rate = rates.first(where: { $0.activity == item.activity }) else { return total }
            let value = kind == "high" ? rate.high : kind == "low" ? rate.low : kind == "raw" ? rate.raw : rate.central
            return total + used / 60 * value
        }
    }
}

struct TripOutcome: Codable, Identifiable {
    let id: UUID
    let endedAt: Date
    let items: [TripItem]
    let activeMinutes: Double
    let initialBattery: Double?
    let actualBattery: Double?
    let predictedBattery: Double?
    let lowerBattery: Double?
    let upperBattery: Double?
    let rawPredictedDrop: Double?
    let context: UsageContext?
    let eligible: Bool
    let exclusion: String?
    let completed: Bool
    let validationLabel: String?
    var calibrationItems: [TripItem] {
        var left = activeMinutes
        return items.compactMap { item in
            let used = min(left, Double(item.minutes)); left = max(0, left - used)
            return used >= 1 ? TripItem(activity: item.activity, minutes: Int(used.rounded())) : nil
        }
    }
    var error: Double? {
        guard let predictedBattery, let actualBattery else { return nil }
        return actualBattery - predictedBattery
    }
    var inRange: Bool? {
        guard eligible, let actualBattery, let lowerBattery, let upperBattery else { return nil }
        return (lowerBattery...upperBattery).contains(actualBattery)
    }
    static func make(_ active: ActiveTrip, endedAt now: Date, battery: Double?) -> TripOutcome {
        let start = active.initialBattery
        let central = active.predictedCost(at: now)
        let high = active.predictedCost(at: now, kind: "high")
        let low = active.predictedCost(at: now, kind: "low")
        var exclusion: String?
        if start == nil || battery == nil || central == nil { exclusion = "missing" }
        else if active.hadCharging == true { exclusion = "charging" }
        else if active.hadGap == true { exclusion = "gap" }
        else if active.conditionsChanged == true { exclusion = "conditions" }
        else if (active.pausedSeconds ?? 0) > 0 || active.isPaused { exclusion = "paused" }
        else if active.elapsed(at: now) < 900 || (start! - battery!) < 2 || (central ?? 0) < 2 || battery! < 1 { exclusion = "short" }
        func remaining(_ cost: Double?) -> Double? {
            guard let start, let cost else { return nil }; return max(0, min(100, start - cost))
        }
        return .init(id: active.id, endedAt: now, items: active.items, activeMinutes: active.elapsed(at: now) / 60,
                     initialBattery: start, actualBattery: battery, predictedBattery: remaining(central), lowerBattery: remaining(high), upperBattery: remaining(low),
                     rawPredictedDrop: active.predictedCost(at: now, kind: "raw"), context: active.context, eligible: exclusion == nil, exclusion: exclusion,
                     completed: active.remaining(at: now).isEmpty, validationLabel: active.validationLabel)
    }
}

struct Calibration {
    var outcomes: [TripOutcome]
    static func signature(_ items: [TripItem]) -> String {
        let total = max(1, items.reduce(0) { $0 + $1.minutes })
        let grouped = Dictionary(grouping: items, by: \.activity)
        return grouped.map { activity, items in "\(activity.rawValue):\(Int((Double(items.reduce(0) { $0 + $1.minutes }) / Double(total) * 10).rounded()))" }.sorted().joined(separator: "|")
    }
    func factor(items: [TripItem], context: UsageContext, now: Date = Date()) -> Double {
        let matching = outcomes.filter { $0.eligible && $0.context?.sameConditions(as: context) == true && Self.signature($0.calibrationItems) == Self.signature(items) && $0.context?.combinationKey == context.combinationKey && now.timeIntervalSince($0.endedAt) >= 0 && now.timeIntervalSince($0.endedAt) < 30 * 86400 }
        guard matching.count >= 3 else { return 1 }
        let ratios = matching.suffix(12).compactMap { outcome -> Double? in
            guard let start = outcome.initialBattery, let actual = outcome.actualBattery, let raw = outcome.rawPredictedDrop, raw >= 2 else { return nil }
            return max(0.5, min(2, (start - actual) / raw))
        }.sorted()
        guard ratios.count >= 3 else { return 1 }
        let median = ratios[ratios.count / 2]
        return max(0.8, min(1.3, 1 + (median - 1) * min(0.6, Double(ratios.count) / 20)))
    }
    var eligible: [TripOutcome] { outcomes.filter(\.eligible) }
    var meanAbsoluteError: Double? {
        let errors = eligible.compactMap(\.error).map(abs)
        return errors.isEmpty ? nil : errors.reduce(0, +) / Double(errors.count)
    }
    var coverage: Double? {
        let values = eligible.compactMap(\.inRange)
        return values.isEmpty ? nil : Double(values.filter { $0 }.count) / Double(values.count)
    }
}

struct ChargeSample: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let minutes: Double
    let gain: Double
    let band: Int
    let adapter: String
    var rate: Double { gain / minutes * 60 }
    var valid: Bool { minutes >= 3 && minutes <= 21 && gain >= 1 && rate > 0 && rate <= 150 }
}
struct ChargeAccumulator {
    private var initial: (date: Date, percent: Double, adapter: String)?
    private var previous: (date: Date, percent: Double)?
    mutating func reset() { initial = nil; previous = nil }
    static func band(_ percent: Double) -> Int { percent < 60 ? 0 : percent < 80 ? 1 : percent < 95 ? 2 : 3 }
    mutating func ingest(date: Date, percent: Double?, charging: Bool, adapter: String) -> ChargeSample? {
        guard charging, let percent, percent.isFinite, (0...100).contains(percent) else { reset(); return nil }
        defer { previous = (date, percent) }
        guard let first = initial, let previous else { initial = (date, percent, adapter); return nil }
        let gap = date.timeIntervalSince(previous.date)
        if gap <= 0 || gap > 95 || percent < previous.percent || adapter != first.adapter || Self.band(percent) != Self.band(first.percent) {
            initial = (date, percent, adapter); return nil
        }
        let minutes = date.timeIntervalSince(first.date) / 60
        guard minutes >= 3 && percent - first.percent >= 1 || minutes >= 20 else { return nil }
        let sample = ChargeSample(date: date, minutes: minutes, gain: percent - first.percent, band: Self.band(percent), adapter: adapter)
        initial = (date, percent, adapter)
        return sample.valid ? sample : nil
    }
}
struct ChargeTarget {
    let requestedPercent: Double
    var reachable: Bool { requestedPercent <= 100 }
    var percent: Int { Int(ceil(max(0, min(100, requestedPercent)))) }
    static func make(cost: Double, reserve: Double) -> ChargeTarget { .init(requestedPercent: cost + reserve) }
}
struct ChargeETA {
    let lower: Double
    let upper: Double
    var range: String { "\(duration(lower)) – \(duration(upper))" }
    static func estimate(from current: Double, target: Double, adapter: String, samples: [ChargeSample], now: Date = Date()) -> ChargeETA? {
        guard target <= 100, current >= 0, target > current else { return nil }
        let boundaries = [0.0, 60, 80, 95, 100]
        var lower = 0.0, upper = 0.0
        for band in 0..<4 {
            let gain = max(0, min(target, boundaries[band + 1]) - max(current, boundaries[band]))
            if gain == 0 { continue }
            let matching = samples.filter { $0.valid && $0.adapter == adapter && $0.band == band && now.timeIntervalSince($0.date) >= 0 && now.timeIntervalSince($0.date) < 30 * 86400 }
            guard matching.count >= 3, matching.reduce(0, { $0 + $1.minutes }) >= 9 else { return nil }
            let rate = matching.reduce(0) { $0 + $1.gain } / matching.reduce(0) { $0 + $1.minutes } * 60
            lower += gain / (rate * 1.25) * 60; upper += gain / (rate * 0.7) * 60
        }
        return .init(lower: lower, upper: upper)
    }
}

struct SmartAlertState: Codable {
    var consecutive = 0
    var lastSampleID: UUID?
    var snoozedUntil: Date?
    var lastSent: Date?
    var count = 0
    mutating func evaluate(sample: DischargeSample, at now: Date, shortfallMinutes: Double, isPaused: Bool) -> Bool {
        guard !isPaused, sample.valid, sample.date <= now, now.timeIntervalSince(sample.date) < 1800, sample.id != lastSampleID else { return false }
        lastSampleID = sample.id
        consecutive = shortfallMinutes >= 10 ? consecutive + 1 : 0
        guard consecutive >= 2, count < 3, (snoozedUntil ?? .distantPast) <= now, now.timeIntervalSince(lastSent ?? .distantPast) >= 3600 else { return false }
        lastSent = now; count += 1; return true
    }
    mutating func snooze(at date: Date) { snoozedUntil = date.addingTimeInterval(20 * 60); consecutive = 0 }
}
