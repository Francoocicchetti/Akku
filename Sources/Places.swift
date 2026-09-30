import Foundation

struct FamiliarPlace: Codable, Identifiable {
    var id = UUID()
    var latitude: Double
    var longitude: Double
    var accuracy: Double
    var name: String? = nil
    var kind: String? = nil
    var visits = 1
    var dwellMinutes = 0.0
    var lastSeen: Date
    var days: [String] = []
    var nightDays: [String] = []
    var workDays: [String] = []
    var dismissed = false
    var suggested: Bool { !dismissed && name == nil && visits >= 2 && dwellMinutes >= 45 }
    var suggestion: String { nightDays.count >= 3 ? "home" : workDays.count >= 3 ? "work" : "place" }
}
struct PlaceLearner: Codable {
    var places: [FamiliarPlace] = []
    var lastPlaceID: UUID?
    var lastFix: Date?
    static func distance(_ lat: Double, _ lon: Double, _ p: FamiliarPlace) -> Double {
        let dlat = (p.latitude - lat) * .pi / 180
        let dlon = (p.longitude - lon) * .pi / 180
        let a = pow(sin(dlat / 2), 2) + cos(lat * .pi / 180) * cos(p.latitude * .pi / 180) * pow(sin(dlon / 2), 2)
        return 6_371_000 * 2 * atan2(sqrt(max(0, a)), sqrt(max(0, 1 - a)))
    }
    mutating func observe(latitude: Double, longitude: Double, accuracy: Double, date: Date, now: Date = Date(), calendar: Calendar = .current) {
        guard accuracy >= 0, accuracy <= 100, abs(now.timeIntervalSince(date)) <= 120,
              date > (lastFix ?? .distantPast), latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else { return }
        places.removeAll { $0.name == nil && now.timeIntervalSince($0.lastSeen) > 60 * 86400 }
        let gap = lastFix.map { date.timeIntervalSince($0) } ?? .infinity
        let near = places.indices.filter { Self.distance(latitude, longitude, places[$0]) < 200 }.min { Self.distance(latitude, longitude, places[$0]) < Self.distance(latitude, longitude, places[$1]) }
        var index: Int
        if let near { index = near }
        else {
            guard places.count < 30 else { lastPlaceID = nil; lastFix = date; return }
            places.append(FamiliarPlace(latitude: latitude, longitude: longitude, accuracy: accuracy, lastSeen: date)); index = places.count - 1
        }
        let continuous = lastPlaceID == places[index].id && gap <= 660
        if continuous { places[index].dwellMinutes += max(0, gap / 60) }
        else if places[index].lastSeen != date && date.timeIntervalSince(places[index].lastSeen) >= 1800 { places[index].visits += 1 }
        places[index].lastSeen = date
        let components = calendar.dateComponents([.year, .month, .day, .hour, .weekday], from: date)
        let key = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        if !places[index].days.contains(key) { places[index].days = Array((places[index].days + [key]).suffix(60)) }
        // Labels remain suggestions; neither hours nor Wi-Fi can prove where home is.
        if continuous && (components.hour ?? 12) >= 21 || continuous && (components.hour ?? 12) < 7 {
            if !places[index].nightDays.contains(key) { places[index].nightDays = Array((places[index].nightDays + [key]).suffix(60)) }
        }
        if continuous && (2...6).contains(components.weekday ?? 1) && (9...17).contains(components.hour ?? 0) {
            if !places[index].workDays.contains(key) { places[index].workDays = Array((places[index].workDays + [key]).suffix(60)) }
        }
        lastPlaceID = places[index].id; lastFix = date
    }
}
struct DepartureGate {
    var wasHome = false
    var firstOutside: Date?
    var lastFix: Date?
    var lastNotice = Date.distantPast
    var snoozedUntil = Date.distantPast
    mutating func ingest(_ presence: HomePresence, fix: Date, now: Date) -> Bool {
        guard fix > (lastFix ?? .distantPast), abs(now.timeIntervalSince(fix)) <= 600 else { return false }
        lastFix = fix
        if presence == .home { wasHome = true; firstOutside = nil; return false }
        if presence == .unknown { firstOutside = nil; return false }
        guard wasHome else { return false }
        guard let first = firstOutside else { firstOutside = fix; return false }
        guard fix.timeIntervalSince(first) >= 120 else { return false }
        wasHome = false; firstOutside = nil
        guard now >= snoozedUntil, now.timeIntervalSince(lastNotice) >= 4 * 3600 else { return false }
        lastNotice = now; return true
    }
}
