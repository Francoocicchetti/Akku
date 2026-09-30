import Foundation

// A single coalescible timer supports observations; UI-only work is demand driven.
enum EnergyPolicy {
    static func interval(visible: Bool, learning: Bool, lowPower: Bool, emergency: Bool, sleeping: Bool) -> TimeInterval? {
        if sleeping { return nil }
        if !visible && !learning { return 300 }
        return visible && !lowPower && !emergency ? 30 : 60
    }
    static func tolerance(for interval: TimeInterval) -> TimeInterval { min(15, interval / 6) }
    static func nextAnimationDate(after date: Date, origin: Date = Date(timeIntervalSinceReferenceDate: 0)) -> Date {
        // Eight frames/second for two seconds, then no animation callbacks for 18 seconds.
        let phase = animationPhase(at: date, origin: origin)
        return date.addingTimeInterval(phase < 2 ? 0.125 : 20 - phase)
    }
    static func animationPhase(at date: Date, origin: Date) -> Double {
        max(0, date.timeIntervalSince(origin)).truncatingRemainder(dividingBy: 20)
    }
}
struct CheckpointGate {
    var interval: TimeInterval = 300
    private var saved: [String: TimeInterval] = [:]
    func due(_ key: String, uptime: TimeInterval, force: Bool = false) -> Bool {
        guard !force, let last = saved[key] else { return true }
        return uptime < last || uptime - last >= interval
    }
    mutating func committed(_ key: String, uptime: TimeInterval) { saved[key] = uptime }
    mutating func reset() { saved = [:] }
}
struct LocationBackoff {
    private(set) var failures = 0
    var interval: TimeInterval { min(1800, 300 * pow(2, Double(min(3, failures)))) }
    mutating func failed() { failures = min(3, failures + 1) }
    mutating func succeeded() { failures = 0 }
}
