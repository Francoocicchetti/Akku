import Foundation

enum Confidence: String, Codable {
    case low, medium, high
    func name(_ l: Language) -> String {
        switch self {
        case .low: return l.text("Low confidence", "Confianza baja")
        case .medium: return l.text("Medium confidence", "Confianza media")
        case .high: return l.text("High confidence", "Confianza alta")
        }
    }
}

struct DischargeSample: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let minutes: Double
    let drop: Double
    let activity: Activity?
    let appID: String?
    let confirmed: Bool
    let mode: String
    var context: UsageContext? = nil
    var rate: Double { drop / minutes * 60 }
    var valid: Bool { minutes >= 10 && minutes <= 46 && drop >= 1 && drop <= 70 && rate.isFinite && rate >= 0.5 && rate <= 100 }
}

struct Observation {
    let date: Date
    let percent: Double?
    let onBattery: Bool
    let activity: Activity?
    let appID: String?
    let confirmed: Bool
    let mode: String
    var context: UsageContext? = nil
}

// Only uninterrupted awake discharge intervals count. Never learn from charging or sleep.
struct DischargeAccumulator {
    private var start: Observation?
    private var last: Observation?
    private var activities: [Activity: Double] = [:]
    private var appSeconds: [String: Double] = [:]
    private var contexts: [UsageContext: Double] = [:]
    private var confirmedSeconds: Double = 0
    private(set) var minutes: Double = 0
    mutating func reset() { start = nil; last = nil; activities = [:]; appSeconds = [:]; contexts = [:]; confirmedSeconds = 0; minutes = 0 }
    mutating func ingest(_ now: Observation) -> DischargeSample? {
        guard now.onBattery, let percent = now.percent, percent.isFinite, (0...100).contains(percent) else { reset(); return nil }
        guard let first = start, let previous = last, let initial = first.percent, let lastPercent = previous.percent else {
            start = now; last = now; return nil
        }
        let gap = now.date.timeIntervalSince(previous.date)
        guard gap > 0 else { reset(); start = now; last = now; return nil }
        guard gap <= 95, percent <= lastPercent + 0.1, now.mode == first.mode else {
            reset(); start = now; last = now; return nil
        }
        if let activity = previous.activity { activities[activity, default: 0] += gap }
        if let app = previous.appID { appSeconds[app, default: 0] += gap }
        if let context = previous.context { contexts[context, default: 0] += gap }
        if previous.confirmed { confirmedSeconds += gap }
        last = now
        let elapsed = now.date.timeIntervalSince(first.date)
        minutes = elapsed / 60
        let drop = initial - percent
        guard (minutes >= 10 && drop >= 2) || minutes >= 45 else { return nil }
        let primary = activities.max { $0.value < $1.value }
        let activity = primary.map { $0.value / elapsed >= 0.8 ? $0.key : nil } ?? nil
        let primaryApp = appSeconds.max { $0.value < $1.value }
        let app = primaryApp.map { $0.value / elapsed >= 0.8 ? $0.key : nil } ?? nil
        let sample = DischargeSample(date: now.date, minutes: minutes, drop: drop, activity: activity, appID: app,
                                     confirmed: confirmedSeconds / elapsed >= 0.8, mode: now.mode, context: contexts.max { $0.value < $1.value }.flatMap { $0.value / elapsed >= 0.8 ? $0.key : nil })
        reset(); start = now; last = now
        return sample.valid ? sample : nil
    }
}

struct RuntimeEstimate {
    let lowerMinutes: Double
    let upperMinutes: Double
    let centralRate: Double
    let highRate: Double
    let lowRate: Double
    let confidence: Confidence
    let sampleCount: Int
    let observedMinutes: Double
    let usingRecent: Bool
    var contextMatched: Bool = true
    var range: String { "\(duration(lowerMinutes)) – \(duration(upperMinutes))" }
}

struct ForecastEngine {
    var samples: [DischargeSample]
    let baselineHours: Double
    let mode: String
    var now = Date()
    var context: UsageContext? = nil
    func estimate(activity: Activity, battery: Double, reserve: Double, includeRecent: Bool = false) -> RuntimeEstimate {
        let prior = 100 / max(3, baselineHours) * activity.multiplier
        var matching = samples.filter { $0.valid && $0.activity == activity && $0.mode == mode && now.timeIntervalSince($0.date) >= 0 && now.timeIntervalSince($0.date) < 60 * 86400 }
        var contextMatched = context == nil
        if let context {
            let similar = matching.filter { $0.context?.sameConditions(as: context) == true }
            let combos = similar.filter { !$0.context!.apps.isEmpty && $0.context!.combinationKey == context.combinationKey }
            if combos.count >= 3 { matching = combos; contextMatched = true }
            else if similar.count >= 3 { matching = similar; contextMatched = context.apps.isEmpty }
        }
        let minutes = matching.reduce(0) { $0 + $1.minutes }
        let weights = matching.map { $0.minutes * exp(-max(0, now.timeIntervalSince($0.date)) / (14 * 86400)) }
        let sum = weights.reduce(0, +)
        let measured = sum > 0 ? zip(matching, weights).reduce(0) { $0 + $1.0.rate * $1.1 } / sum : prior
        let blend = min(1, minutes / 180)
        var rate = prior * (1 - blend) + measured * blend
        let variance = sum > 0 ? zip(matching, weights).reduce(0) { $0 + pow($1.0.rate - measured, 2) * $1.1 } / sum : 0
        let cv = sqrt(variance) / max(1, measured)
        let days = Set(matching.map { Calendar.current.startOfDay(for: $0.date) }).count
        let confirmedMinutes = matching.filter(\.confirmed).reduce(0) { $0 + $1.minutes }
        var confidence: Confidence = .low
        if matching.count >= 4 && minutes >= 90 && cv < 0.5 { confidence = .medium }
        if matching.count >= 12 && minutes >= 300 && confirmedMinutes >= 180 && days >= 3 && cv < 0.25 { confidence = .high }
        var spread = max(confidence == .low ? 0.45 : confidence == .medium ? 0.30 : 0.20, min(0.75, cv * 1.5))
        var recentUsed = false
        if includeRecent, let recent = matching.last(where: { $0.valid && $0.mode == mode && $0.activity == activity && now.timeIntervalSince($0.date) >= 0 && now.timeIntervalSince($0.date) < 1800 }) {
            rate = max(rate, recent.rate * 0.65 + rate * 0.35)
            spread = max(spread, abs(recent.rate - rate) / max(rate, 1))
            recentUsed = true
        }
        if !contextMatched { confidence = .low; spread = max(0.6, spread) }
        let usable = max(0, min(100, battery) - reserve)
        let high = rate * (1 + spread)
        let low = max(0.25, rate * (1 - min(0.8, spread)))
        return RuntimeEstimate(lowerMinutes: usable / high * 60, upperMinutes: usable / low * 60,
                               centralRate: rate, highRate: high, lowRate: low, confidence: confidence,
                               sampleCount: matching.count, observedMinutes: minutes, usingRecent: recentUsed, contextMatched: contextMatched)
    }
    func tripCost(_ items: [TripItem], conservative: Bool) -> Double {
        items.reduce(0) { total, item in
            let e = estimate(activity: item.activity, battery: 100, reserve: 0, includeRecent: true)
            return total + Double(item.minutes) / 60 * (conservative ? e.highRate : e.centralRate)
        }
    }
}

enum TripVerdict: Equatable {
    case comfortable, tight, insufficient, unavailable
    static func evaluate(battery: Double?, reserve: Double, centralCost: Double, conservativeCost: Double) -> TripVerdict {
        guard let battery else { return .unavailable }
        if conservativeCost <= max(0, battery - reserve) { return .comfortable }
        if centralCost <= battery { return .tight }
        return .insufficient
    }
    func title(_ l: Language) -> String {
        switch self {
        case .comfortable: return l.text("Your plan looks good.", "Tu plan parece viable.")
        case .tight: return l.text("It's tight. Bring your charger.", "Vas justo. Lleva tu cargador.")
        case .insufficient: return l.text("You'll need your charger.", "Vas a necesitar tu cargador.")
        case .unavailable: return l.text("Battery unavailable.", "Batería no disponible.")
        }
    }
}

struct Routine: Identifiable, Codable {
    var id = UUID()
    var name: String
    var items: [TripItem]
}

struct AlertPolicy {
    static func shouldWarn(active: ActiveTrip, sample: DischargeSample, now: Date, available: Double, projectedCost: Double) -> Bool {
        guard !active.warned, !active.remaining(at: now).isEmpty,
              sample.date >= active.startedAt, now.timeIntervalSince(sample.date) >= 0, now.timeIntervalSince(sample.date) < 1800 else { return false }
        return sample.rate > active.initialRate * 1.25 || projectedCost > available
    }
}

enum HomePresence: String { case unknown, home, away }
struct HomeClassifier {
    static func classify(distance: Double, accuracy: Double, homeAccuracy: Double, radius: Double, age: Double) -> HomePresence {
        guard distance.isFinite, accuracy >= 0, accuracy <= 250, homeAccuracy >= 0, age >= -10, age <= 600 else { return .unknown }
        let uncertainty = accuracy + homeAccuracy
        if distance + uncertainty < radius { return .home }
        if distance - uncertainty > radius + 100 { return .away }
        return .unknown
    }
}
