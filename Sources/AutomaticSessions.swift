import Foundation

// Only aggregates are persisted: no route, screen contents or input events.
struct BatteryDay: Codable, Identifiable {
    var day: Date
    var minutes = 0.0
    var drop = 0.0
    var homeMinutes = 0.0
    var awayMinutes = 0.0
    var unknownMinutes = 0.0
    var id: Date { day }
}
struct AutomaticSession: Codable, Identifiable {
    var id = UUID()
    var startedAt: Date
    var lastSeen: Date
    var endedAt: Date?
    var trigger: String
    var leftHome = false
    var interrupted = false
    var days: [BatteryDay] = []
    var minutes: Double { days.reduce(0) { $0 + $1.minutes } }
    var drop: Double { days.reduce(0) { $0 + $1.drop } }
}
struct SessionArchive: Codable {
    var hardware: String
    var active: AutomaticSession?
    var completed: [AutomaticSession] = []
}
struct SessionReading {
    var date: Date
    var percent: Double?
    var connected: Bool
    var asleep = false
    var presence: HomePresence = .unknown
}
struct AutomaticSessionTracker {
    var archive: SessionArchive
    private var last: SessionReading?
    private var floor: Double?
    private var connectedSince: Date?
    private var initialized = false
    private var needsStart = true
    init(hardware: String, saved: SessionArchive? = nil) {
        archive = saved?.hardware == hardware ? saved! : SessionArchive(hardware: hardware)
        if archive.active != nil { archive.active?.interrupted = true }
    }
    mutating func interrupt() {
        last = nil; floor = nil; connectedSince = nil
        archive.active?.interrupted = true
    }
    mutating func stop(at date: Date) {
        finish(at: date); interrupt(); initialized = false; needsStart = true
    }
    mutating func ingest(_ r: SessionReading, departed: Bool = false, calendar: Calendar = .current) {
        // Invalid power readings must not masquerade as an unplug event.
        guard let percent = r.percent, percent.isFinite, (0...100).contains(percent) else { interrupt(); return }
        if let last, r.date <= last.date { return }
        let unplugged = last?.connected == true && !r.connected
        let initialOnBattery = (!initialized || needsStart) && !r.connected
        if archive.active == nil && (departed || unplugged || initialOnBattery) && !r.asleep {
            archive.active = AutomaticSession(startedAt: r.date, lastSeen: r.date,
                trigger: departed ? "home" : unplugged ? "unplugged" : "detected", leftHome: departed)
            needsStart = false
        }
        if departed { archive.active?.leftHome = true }
        initialized = true
        if r.connected {
            if connectedSince == nil || last.map({ r.date.timeIntervalSince($0.date) > 95 }) == true { connectedSince = r.date }
            if let since = connectedSince, r.date.timeIntervalSince(since) >= 60 {
                // End at the first connected reading, excluding the debounce minute.
                finish(at: since); needsStart = true
            }
            floor = nil
        } else {
            connectedSince = nil
            if var active = archive.active, !r.asleep, let previous = last, !previous.asleep, !previous.connected {
                let seconds = r.date.timeIntervalSince(previous.date)
                if seconds > 0 && seconds <= 95 {
                    // A percentage bounce must not be counted as discharge twice.
                    let drop = max(0, (floor ?? previous.percent ?? percent) - percent)
                    floor = min(floor ?? previous.percent ?? percent, percent)
                    let presence = previous.presence == r.presence ? r.presence : .unknown
                    var cursor = previous.date
                    while cursor < r.date {
                        let day = calendar.startOfDay(for: cursor)
                        let next = calendar.date(byAdding: .day, value: 1, to: day)!
                        let end = min(next, r.date)
                        let fraction = end.timeIntervalSince(cursor) / seconds
                        let minutes = end.timeIntervalSince(cursor) / 60
                        if !active.days.contains(where: { $0.day == day }) { active.days.append(BatteryDay(day: day)) }
                        let i = active.days.firstIndex { $0.day == day }!
                        active.days[i].minutes += minutes; active.days[i].drop += drop * fraction
                        switch presence {
                        case .home: active.days[i].homeMinutes += minutes
                        case .away: active.days[i].awayMinutes += minutes
                        case .unknown: active.days[i].unknownMinutes += minutes
                        }
                        cursor = end
                    }
                } else { active.interrupted = true; floor = percent }
                active.lastSeen = r.date; archive.active = active
            } else { floor = percent }
        }
        if r.asleep { interrupt() }
        archive.active?.lastSeen = r.date
        last = r
        prune(at: r.date)
    }
    private mutating func finish(at date: Date) {
        if var active = archive.active {
            active.endedAt = date
            if active.minutes > 0 { archive.completed.append(active) }
        }
        archive.active = nil
    }
    private mutating func prune(at date: Date) {
        let cutoff = date.addingTimeInterval(-60 * 86400)
        archive.completed = Array(archive.completed.filter { ($0.endedAt ?? $0.lastSeen) >= cutoff }.suffix(400))
        archive.active?.days.removeAll { $0.day < cutoff }
    }
}
struct WeeklyStatistics {
    let days: [BatteryDay]
    let sessions: [AutomaticSession]
    let priorMinutes: Double
    var minutes: Double { days.reduce(0) { $0 + $1.minutes } }
    var drop: Double { days.reduce(0) { $0 + $1.drop } }
    var observedDays: Int { days.filter { $0.minutes >= 10 }.count }
    var enoughForPattern: Bool { observedDays >= 3 && minutes >= 90 }
    var homeMinutes: Double { days.reduce(0) { $0 + $1.homeMinutes } }
    var awayMinutes: Double { days.reduce(0) { $0 + $1.awayMinutes } }
    var unknownMinutes: Double { days.reduce(0) { $0 + $1.unknownMinutes } }
    init(archive: SessionArchive, now: Date, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: today)!
        let priorStart = calendar.date(byAdding: .day, value: -7, to: start)!
        let all = archive.completed + (archive.active.map { [$0] } ?? [])
        sessions = all.filter { $0.days.contains { $0.day >= start && $0.day <= today && $0.minutes > 0 } }
        let rows = all.flatMap(\.days)
        days = (0..<7).map { index in
            let day = calendar.date(byAdding: .day, value: index, to: start)!
            return rows.filter { $0.day == day }.reduce(BatteryDay(day: day)) { acc, row in
                var result = acc; result.minutes += row.minutes; result.drop += row.drop
                result.homeMinutes += row.homeMinutes; result.awayMinutes += row.awayMinutes; result.unknownMinutes += row.unknownMinutes
                return result
            }
        }
        priorMinutes = rows.filter { $0.day >= priorStart && $0.day < start }.reduce(0) { $0 + $1.minutes }
    }
}

// A full-charge projection of the user's observed mix, independent of manual plans,
// current percentage and reserve. No hardware marketing baseline fills missing data.
struct RoutineAutonomy {
    let observedDays: Int
    let minutes: Double
    let drop: Double
    let estimate: RuntimeEstimate?

    init(days: [BatteryDay], now: Date, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: today)!
        let rows = days.filter {
            $0.day >= start && $0.day <= today && $0.minutes.isFinite && $0.drop.isFinite &&
            $0.minutes >= 10 && $0.minutes <= 1440 && $0.drop >= 0 && $0.drop / $0.minutes * 60 <= 100
        }
        observedDays = Set(rows.map { calendar.startOfDay(for: $0.day) }).count
        minutes = rows.reduce(0) { $0 + $1.minutes }
        drop = rows.reduce(0) { $0 + $1.drop }
        guard observedDays >= 3, minutes >= 90, drop >= 5 else { estimate = nil; return }
        // Sum energy / sum time, not an unweighted average of short and long days.
        let rate = drop / minutes * 60
        guard rate.isFinite && rate > 0 else { estimate = nil; return }
        let variance = rows.reduce(0) { $0 + pow($1.drop / $1.minutes * 60 - rate, 2) * $1.minutes } / minutes
        let cv = sqrt(variance) / rate
        // At least 25% uncertainty; include variation and percentage quantization.
        // Confidence is capped at medium until routine forecasts are calibrated.
        let spread = min(0.8, max(0.25, cv * 1.5, 2 / drop))
        let confidence: Confidence = observedDays >= 5 && minutes >= 300 && cv < 0.35 ? .medium : .low
        let high = rate * (1 + spread), low = rate * (1 - spread)
        estimate = RuntimeEstimate(lowerMinutes: 100 / high * 60, upperMinutes: 100 / low * 60,
            centralRate: rate, highRate: high, lowRate: low, confidence: confidence,
            sampleCount: observedDays, observedMinutes: minutes, usingRecent: false)
    }
}

// Data transitions do not depend on notification preferences or their cooldown.
struct HomeTransitionGate {
    private var wasHome = false
    private var firstOutside: Date?
    private var lastFix: Date?
    mutating func ingest(_ presence: HomePresence, fix: Date, now: Date) -> Bool {
        guard fix > (lastFix ?? .distantPast), abs(now.timeIntervalSince(fix)) <= 600 else { return false }
        lastFix = fix
        if presence == .home { wasHome = true; firstOutside = nil; return false }
        if presence == .unknown { firstOutside = nil; return false }
        guard wasHome else { return false }
        guard let first = firstOutside else { firstOutside = fix; return false }
        guard fix.timeIntervalSince(first) >= 120 else { return false }
        wasHome = false; firstOutside = nil; return true
    }
}
