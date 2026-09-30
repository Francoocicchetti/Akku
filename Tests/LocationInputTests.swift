import Foundation
@main struct LocationInputTests {
    static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            checks += 1; if !condition() { fputs("FAIL: \(message)\n", stderr); exit(1) }
        }
        let prefs = UserDefaults.standard
        let original = prefs.object(forKey: "locationEnabled")
        prefs.set(false, forKey: "locationEnabled")
        defer { if let original { prefs.set(original, forKey: "locationEnabled") } else { prefs.removeObject(forKey: "locationEnabled") } }
        let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/manual-location-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = LocalStore(directory: dir)
        let location = HomeLocation(store: store)
        check(!location.enabled && location.currentPosition == nil, "No automatic fix when location is disabled")
        location.setManualPosition(latitude: 45, longitude: 10, label: "Synthetic test position")
        check(location.usingManual && location.currentPosition?.coordinate.latitude == 45, "Manual coordinates are accepted without OS authorization")
        check(location.canSaveHome, "Valid manual current location can be saved")
        location.saveCurrentPlace(kind: "home", name: "Test home")
        check(location.home?.latitude == 45 && location.home?.longitude == 10, "Saving current place uses manual coordinates rather than stale automatic ones")
        check(location.homeDistance?.meters == 0 && location.homeDistance?.manual == true, "Home distance labels manual source")
        check(location.presence == .home, "Manual at-home presence can be classified")
        location.setManualPosition(latitude: 46, longitude: 10, label: "Synthetic away")
        check(location.presence == .away && location.homeDistance?.far == true, "Manual distant point drives distance and context")
        var departed = false; location.onLeaveHome = { departed = true }
        var automaticDeparture = false; location.onAutomaticDeparture = { automaticDeparture = true }
        location.recompute(); location.recompute()
        check(!departed && !automaticDeparture, "Manual inputs never generate automatic departure alerts or start data sessions")
        location.setManualPosition(latitude: 999, longitude: 10, label: "Invalid")
        check(location.currentPosition?.coordinate.latitude == 46, "Invalid coordinates cannot overwrite an existing position")
        location.clearManualPosition()
        check(!location.usingManual && location.homeDistance == nil && location.presence == .unknown, "Clearing manual input while disabled invalidates distance and presence")
        check(location.saveManualPlace(latitude: 47, longitude: 11, name: "Other home", kind: "home"), "Home can be entered without current position")
        check(location.home?.latitude == 47 && location.currentPosition == nil, "Setting home doesn't claim current presence")
        check(location.learner.places.filter { $0.kind == "home" }.count == 1, "Replacing home keeps a single home designation")
        location.forgetPlaces()
        check(location.home == nil && location.learner.places.isEmpty && store.read("home.json", as: SavedHome.self) == nil, "Forget removes synthetic saved positions")
        print("PASS: \(checks) native manual-location, home replacement, source separation and distance checks")
    }
}
