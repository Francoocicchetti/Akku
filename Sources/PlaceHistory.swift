import Foundation

struct GeoFix: Codable {
    var latitude: Double
    var longitude: Double
    var accuracy: Double
    var date: Date
    func valid(at now: Date, precision: Double = 100) -> Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
        && accuracy.isFinite && accuracy >= 0 && accuracy <= precision && now.timeIntervalSince(date) >= -5 && now.timeIntervalSince(date) <= 360
    }
}
struct AppDayUsage: Codable, Identifiable {
    var day: Date
    var bundleID: String
    var name: String
    var foregroundSeconds = 0.0
    var openSeconds = 0.0
    var places: [String: Double] = [:]
    var id: String { "\(day.timeIntervalSince1970)-\(bundleID)" }
}
struct PlaceDayUsage: Codable, Identifiable {
    var day: Date
    var placeID: UUID
    var activeSeconds = 0.0
    var batterySeconds = 0.0
    var batteryDrop = 0.0
    var chargeGain = 0.0
    var id: String { "\(day.timeIntervalSince1970)-\(placeID)" }
}
enum EnergyEventKind: String, Codable { case charge, low, critical, zero }
struct EnergyEvent: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var kind: EnergyEventKind
    var placeID: UUID?
    var percent: Double
}
struct PlaceHistoryArchive: Codable {
    var hardware: String
    var apps: [AppDayUsage] = []
    var places: [PlaceDayUsage] = []
    var events: [EnergyEvent] = []
    var lastKnown: GeoFix?
    var lowLatched = false
    var criticalLatched = false
    var zeroLatched = false
}
struct HistoryReading {
    var date: Date
    var uptime: Double
    var percent: Double?
    var connected: Bool
    var charging: Bool
    var awake = true
    var idleSeconds = 0.0
    var foreground: String?
    var apps: [String: String] = [:]
    var fix: GeoFix?
    var placeID: UUID?
}
struct AppUsageSummary: Identifiable {
    var id: String
    var name: String
    var foregroundSeconds: Double
    var openSeconds: Double
    var days: Int
}
struct PlaceUsageSummary {
    var activeSeconds = 0.0
    var batterySeconds = 0.0
    var batteryDrop = 0.0
    var chargeGain = 0.0
    var charges = 0
    var criticalEvents = 0
    var lowDays = 0
    var observedDays = 0
    var hasLowPattern: Bool { observedDays >= 3 && lowDays >= 3 && batterySeconds >= 5400 }
}
extension PlaceHistoryArchive {
    func appSummary(since: Date, placeID: UUID? = nil) -> [AppUsageSummary] {
        let rows = apps.filter { $0.day >= since }
        return Dictionary(grouping: rows, by: \.bundleID).map { id, values in
            let relevant = values.filter { row in (placeID.map { row.places[$0.uuidString] ?? 0 } ?? row.foregroundSeconds) > 0 }
            let seconds = values.reduce(0.0) { sum, row in sum + (placeID.map { row.places[$0.uuidString] ?? 0 } ?? row.foregroundSeconds) }
            return AppUsageSummary(id: id, name: values.last?.name ?? id, foregroundSeconds: seconds,
                openSeconds: placeID == nil ? values.reduce(0) { $0 + $1.openSeconds } : 0, days: Set(relevant.map(\.day)).count)
        }.filter { $0.foregroundSeconds >= 1 || (placeID == nil && $0.openSeconds >= 1) }.sorted { $0.foregroundSeconds > $1.foregroundSeconds }
    }
    func summary(placeID: UUID, since: Date, calendar: Calendar = .current) -> PlaceUsageSummary {
        let rows = places.filter { $0.placeID == placeID && $0.day >= since }
        let recorded = events.filter { $0.placeID == placeID && $0.date >= since }
        let observed = Set(rows.filter { $0.batterySeconds >= 600 }.map(\.day))
        let low = Set(recorded.filter { $0.kind == .low }.map { calendar.startOfDay(for: $0.date) }).intersection(observed)
        return PlaceUsageSummary(activeSeconds: rows.reduce(0) { $0 + $1.activeSeconds }, batterySeconds: rows.reduce(0) { $0 + $1.batterySeconds }, batteryDrop: rows.reduce(0) { $0 + $1.batteryDrop }, chargeGain: rows.reduce(0) { $0 + $1.chargeGain }, charges: recorded.filter { $0.kind == .charge }.count, criticalEvents: recorded.filter { $0.kind == .critical || $0.kind == .zero }.count, lowDays: low.count, observedDays: observed.count)
    }
}
struct PlaceHistoryTracker {
    var archive: PlaceHistoryArchive
    private var last: HistoryReading?
    private var dischargeFloor: Double?
    private var chargeCeiling: Double?
    private var chargedPlaces = Set<UUID>()
    init(hardware: String, saved: PlaceHistoryArchive? = nil) {
        archive = saved?.hardware == hardware ? saved! : PlaceHistoryArchive(hardware: hardware)
    }
    mutating func interrupt() { last = nil; dischargeFloor = nil; chargeCeiling = nil }
    mutating func forgetPlaces() {
        archive.places = []; archive.lastKnown = nil
        for i in archive.apps.indices { archive.apps[i].places = [:] }
        for i in archive.events.indices { archive.events[i].placeID = nil }
        chargedPlaces = []; interrupt()
    }
    mutating func ingest(_ input: HistoryReading, calendar: Calendar = .current) {
        var r = input
        if let last, r.date <= last.date { return }
        if r.fix?.valid(at: r.date) != true { r.fix = nil; r.placeID = nil }
        if let fix = r.fix { archive.lastKnown = fix }
        if !r.awake { interrupt(); return }
        let battery = r.percent.flatMap { $0.isFinite && (0...100).contains($0) ? $0 : nil }
        if let battery {
            if battery >= 20 { archive.lowLatched = false }
            if battery >= 8 { archive.criticalLatched = false }
            if battery >= 5 { archive.zeroLatched = false }
            if !r.connected {
                if battery <= 10 && !archive.lowLatched { event(.low, r, battery); archive.lowLatched = true }
                if battery <= 3 && !archive.criticalLatched { event(.critical, r, battery); archive.criticalLatched = true }
                if battery == 0 && !archive.zeroLatched { event(.zero, r, battery); archive.zeroLatched = true }
            }
        }
        if !r.connected { chargedPlaces = []; chargeCeiling = nil }
        if let p = last {
            let seconds = r.uptime - p.uptime
            let wall = r.date.timeIntervalSince(p.date)
            if seconds > 0 && seconds <= 95 && wall > 0 && wall <= 95 && abs(seconds - wall) <= 3 {
                let active = p.idleSeconds < 300 && r.idleSeconds < 300
                let place = p.placeID == r.placeID ? r.placeID : nil
                var drop = 0.0, gain = 0.0
                if let battery, let prior = p.percent, prior.isFinite, (0...100).contains(prior) {
                    if !r.connected && !p.connected {
                        drop = max(0, (dischargeFloor ?? prior) - battery)
                        dischargeFloor = min(dischargeFloor ?? prior, battery)
                    } else { dischargeFloor = battery }
                    if r.connected && p.connected && r.charging && p.charging {
                        gain = max(0, battery - (chargeCeiling ?? prior))
                        chargeCeiling = max(chargeCeiling ?? prior, battery)
                        if gain > 0, let place, !chargedPlaces.contains(place) {
                            event(.charge, r, battery); chargedPlaces.insert(place)
                        }
                    } else { chargeCeiling = battery }
                } else { dischargeFloor = nil; chargeCeiling = nil }
                var cursor = p.date
                while cursor < r.date {
                    let day = calendar.startOfDay(for: cursor)
                    let next = calendar.date(byAdding: .day, value: 1, to: day)!
                    let end = min(next, r.date)
                    let fraction = end.timeIntervalSince(cursor) / wall
                    let elapsed = seconds * fraction
                    for (id, name) in p.apps {
                        if !archive.apps.contains(where: { $0.day == day && $0.bundleID == id }) { archive.apps.append(AppDayUsage(day: day, bundleID: id, name: name)) }
                        let i = archive.apps.firstIndex { $0.day == day && $0.bundleID == id }!
                        archive.apps[i].openSeconds += elapsed
                        if active && p.foreground == id {
                            archive.apps[i].foregroundSeconds += elapsed
                            if let place { archive.apps[i].places[place.uuidString, default: 0] += elapsed }
                        }
                    }
                    if let place {
                        if !archive.places.contains(where: { $0.day == day && $0.placeID == place }) { archive.places.append(PlaceDayUsage(day: day, placeID: place)) }
                        let i = archive.places.firstIndex { $0.day == day && $0.placeID == place }!
                        if active && p.foreground != nil { archive.places[i].activeSeconds += elapsed }
                        if !r.connected && !p.connected && battery != nil && p.percent.map({ $0.isFinite && (0...100).contains($0) }) == true { archive.places[i].batterySeconds += elapsed; archive.places[i].batteryDrop += drop * fraction }
                        archive.places[i].chargeGain += gain * fraction
                    }
                    cursor = end
                }
            } else { dischargeFloor = battery; chargeCeiling = battery }
        } else { dischargeFloor = battery; chargeCeiling = battery }
        last = r
        let cutoff = calendar.startOfDay(for: r.date.addingTimeInterval(-60 * 86400))
        archive.apps = Array(archive.apps.filter { $0.day >= cutoff }.suffix(12000))
        archive.places = Array(archive.places.filter { $0.day >= cutoff }.suffix(2000))
        archive.events = Array(archive.events.filter { $0.date >= cutoff }.suffix(600))
        if let date = archive.lastKnown?.date, date < cutoff { archive.lastKnown = nil }
    }
    private mutating func event(_ kind: EnergyEventKind, _ r: HistoryReading, _ percent: Double) {
        archive.events.append(EnergyEvent(date: r.date, kind: kind, placeID: r.placeID, percent: percent))
    }
}
