import Foundation

// Compact five-minute aggregates. No new timer, location lookup, process scan or content capture.
struct BatteryHistoryBucket: Codable, Identifiable {
    var start: Date
    var level: Double?
    var minimum: Double?
    var maximum: Double?
    var observed = 0.0
    var screen = 0.0
    var connected = 0.0
    var charging = 0.0
    var id: Date { start }
    var valid: Bool {
        start.timeIntervalSinceReferenceDate.isFinite &&
        [observed, screen, connected, charging].allSatisfy { $0.isFinite && (0...300.01).contains($0) } &&
        screen <= observed + 0.01 && connected <= observed + 0.01 && charging <= connected + 0.01 &&
        [level, minimum, maximum].allSatisfy { $0 == nil || ($0!.isFinite && (0...100).contains($0!)) } &&
        (minimum == nil || maximum == nil || minimum! <= maximum!)
    }
}
struct BatteryHistoryArchive: Codable {
    var version = 1
    var hardware: String
    var buckets: [BatteryHistoryBucket] = []
}
struct BatteryHistoryReading {
    var date: Date
    var uptime: Double
    var percent: Double?
    var connected: Bool
    var charging: Bool
    var screenOn: Bool
}
struct BatteryHistoryTracker {
    private(set) var archive: BatteryHistoryArchive
    private var previous: BatteryHistoryReading?
    static let retention: TimeInterval = 11 * 86400
    init(hardware: String, saved: BatteryHistoryArchive? = nil, now: Date = Date()) {
        archive = BatteryHistoryArchive(hardware: hardware)
        if let saved, saved.version == 1, saved.hardware == hardware {
            var seen = Set<Date>()
            archive.buckets = Array(saved.buckets.filter {
                $0.valid && $0.start <= now && $0.start >= now.addingTimeInterval(-Self.retention) && seen.insert($0.start).inserted
            }.sorted { $0.start < $1.start }.suffix(3200))
        }
    }
    mutating func interrupt() { previous = nil }
    mutating func ingest(_ r: BatteryHistoryReading) {
        guard r.date.timeIntervalSinceReferenceDate.isFinite, r.uptime.isFinite else { interrupt(); return }
        // Never rewrite history or count an interval twice after a wall-clock correction.
        if let previous, r.date <= previous.date { return }
        let level = r.percent.flatMap { $0.isFinite && (0...100).contains($0) ? $0 : nil }
        if let p = previous {
            let elapsed = r.uptime - p.uptime, wall = r.date.timeIntervalSince(p.date)
            if elapsed > 0 && elapsed <= 95 && wall > 0 && wall <= 95 && abs(elapsed - wall) <= 3 {
                var cursor = p.date
                while cursor < r.date {
                    let start = Self.bucketStart(cursor), end = min(start.addingTimeInterval(300), r.date)
                    let seconds = end.timeIntervalSince(cursor)
                    update(start) { bucket in
                        let accepted = min(seconds, max(0, 300 - bucket.observed))
                        bucket.observed += accepted
                        if p.screenOn { bucket.screen += accepted }
                        if p.connected { bucket.connected += accepted }
                        if p.connected && p.charging { bucket.charging += accepted }
                    }
                    cursor = end
                }
            }
        }
        if let level {
            update(Self.bucketStart(r.date)) { bucket in
                bucket.level = level
                bucket.minimum = min(bucket.minimum ?? level, level)
                bucket.maximum = max(bucket.maximum ?? level, level)
            }
        }
        previous = r
        if let oldest = archive.buckets.first, oldest.start < r.date.addingTimeInterval(-Self.retention) || archive.buckets.count > 3200 {
            archive.buckets = Array(archive.buckets.filter { $0.start >= r.date.addingTimeInterval(-Self.retention) }.suffix(3200))
        }
    }
    static func bucketStart(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: floor(date.timeIntervalSinceReferenceDate / 300) * 300)
    }
    private mutating func update(_ start: Date, change: (inout BatteryHistoryBucket) -> Void) {
        if archive.buckets.last?.start == start { change(&archive.buckets[archive.buckets.count - 1]); return }
        if let last = archive.buckets.last, last.start > start { return }
        archive.buckets.append(BatteryHistoryBucket(start: start)); change(&archive.buckets[archive.buckets.count - 1])
    }
}

enum BatteryHistoryPeriod: String, CaseIterable { case hours24, days10 }
struct BatteryHistoryColumn: Identifiable {
    var start: Date
    var end: Date
    var level: Double?
    var minimum: Double?
    var maximum: Double?
    var observed = 0.0
    var screen = 0.0
    var connected = 0.0
    var charging = 0.0
    var id: Date { start }
}
struct BatteryHistorySummary {
    let start: Date
    let end: Date
    let levels: [BatteryHistoryColumn]
    let usage: [BatteryHistoryColumn]
    var screenSeconds: Double { usage.reduce(0) { $0 + $1.screen } }
    var observedSeconds: Double { usage.reduce(0) { $0 + $1.observed } }
    var connectedSeconds: Double { usage.reduce(0) { $0 + $1.connected } }
    init(archive: BatteryHistoryArchive, period: BatteryHistoryPeriod, now: Date, calendar: Calendar = .current) {
        end = now
        let start = period == .hours24 ? now.addingTimeInterval(-86400) : calendar.date(byAdding: .day, value: -9, to: calendar.startOfDay(for: now))!
        self.start = start
        let rows = archive.buckets.filter { $0.valid && $0.start < now && $0.start.addingTimeInterval(300) > start }
        func intervals(unit: Calendar.Component) -> [BatteryHistoryColumn] {
            var result: [BatteryHistoryColumn] = []
            var cursor = calendar.dateInterval(of: unit, for: start)!.start
            while cursor < now {
                let finish = calendar.date(byAdding: unit, value: 1, to: cursor)!
                result.append(BatteryHistoryColumn(start: max(start, cursor), end: min(now, finish)))
                cursor = finish
            }
            return result
        }
        func aggregate(_ columns: [BatteryHistoryColumn]) -> [BatteryHistoryColumn] {
            var columns = columns
            // At most 3,200 buckets and 25 columns, only while this panel is visible.
            for i in columns.indices {
                var sum = 0.0, weight = 0.0
                for row in rows {
                    let overlap = min(columns[i].end, row.start.addingTimeInterval(300)).timeIntervalSince(max(columns[i].start, row.start))
                    guard overlap > 0 else { continue }
                    if let level = row.level {
                        sum += level * overlap; weight += overlap
                        columns[i].minimum = min(columns[i].minimum ?? row.minimum ?? level, row.minimum ?? level)
                        columns[i].maximum = max(columns[i].maximum ?? row.maximum ?? level, row.maximum ?? level)
                    }
                    // The current partial bucket contains only elapsed observations; don't reduce it again.
                    let bucketElapsed = min(300, max(1, now.timeIntervalSince(row.start)))
                    let timeFraction = min(1, overlap / bucketElapsed)
                    columns[i].observed += row.observed * timeFraction
                    columns[i].screen += row.screen * timeFraction
                    columns[i].connected += row.connected * timeFraction
                    columns[i].charging += row.charging * timeFraction
                }
                if weight > 0 { columns[i].level = sum / weight }
            }
            return columns
        }
        if period == .hours24 {
            // Keep real gaps: a missing bucket doesn't become a zero or an interpolated line.
            levels = rows.map { row in
                BatteryHistoryColumn(start: max(start, row.start), end: min(now, row.start.addingTimeInterval(300)), level: row.level, minimum: row.minimum, maximum: row.maximum, observed: row.observed, screen: row.screen, connected: row.connected, charging: row.charging)
            }
            usage = aggregate(intervals(unit: .hour))
        } else {
            let days = aggregate(intervals(unit: .day)); levels = days; usage = days
        }
    }
}
