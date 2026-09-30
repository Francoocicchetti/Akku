import AppKit
import Combine
import CoreLocation
import UserNotifications
import ServiceManagement

final class LocalStore {
    private var lastWritten: [String: Data] = [:]
    private(set) var physicalWrites = 0
    private(set) var skippedWrites = 0
    let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("BatteryTrip", isDirectory: true)
    }
    func read<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    @discardableResult func write<T: Encodable>(_ value: T, name: String) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(value)
            if lastWritten[name] == data && FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path) {
                skippedWrites += 1; return true
            }
            let url = directory.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            lastWritten[name] = data; physicalWrites += 1
            return true
        } catch { return false }
    }
    @discardableResult func remove(_ name: String) -> Bool {
        lastWritten.removeValue(forKey: name)
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return true }
        do { try FileManager.default.removeItem(at: url); return true } catch { return false }
    }
}

struct SavedHome: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
}

final class HomeLocation: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var enabled = UserDefaults.standard.object(forKey: "locationEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "locationEnabled")
    @Published private(set) var manualPosition: ManualPosition?
    var usingManual: Bool { manualPosition?.valid(at: Date()) == true }
    var currentPosition: CLLocation? {
        if let p = manualPosition, p.valid(at: Date()) { return CLLocation(coordinate: CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude), altitude: 0, horizontalAccuracy: 100, verticalAccuracy: -1, timestamp: p.date) }
        guard enabled else { return nil }; return lastLocation
    }
    var automaticFix: GeoFix? {
        guard enabled, !usingManual, let point = lastLocation else { return nil }
        let value = GeoFix(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude, accuracy: point.horizontalAccuracy, date: point.timestamp)
        return value.valid(at: Date()) ? value : nil
    }
    var automaticPlaceID: UUID? {
        guard let fix = automaticFix else { return nil }
        let candidates = learner.places.filter { PlaceLearner.distance(fix.latitude, fix.longitude, $0) < 200 }
        return candidates.min { PlaceLearner.distance(fix.latitude, fix.longitude, $0) < PlaceLearner.distance(fix.latitude, fix.longitude, $1) }?.id
    }
    var homeDistance: HomeDistance? {
        guard let home, let p = currentPosition,
              usingManual || (abs(p.timestamp.timeIntervalSinceNow) <= 600 && p.horizontalAccuracy >= 0 && p.horizontalAccuracy <= 250) else { return nil }
        return HomeDistance(meters: p.distance(from: CLLocation(latitude: home.latitude, longitude: home.longitude)), uncertainty: p.horizontalAccuracy + home.accuracy, manual: usingManual)
    }
    func setManualPosition(latitude: Double, longitude: Double, label: String) {
        guard ManualPosition.validCoordinates(latitude, longitude) else { problem = "coordinates"; return }
        timeout?.cancel(); manager.stopUpdatingLocation(); locating = false
        automaticDeparture = HomeTransitionGate()
        manualPosition = ManualPosition(latitude: latitude, longitude: longitude, label: String(label.prefix(80)), date: Date())
        recompute()
    }
    func clearManualPosition() { manualPosition = nil; recompute(); request(force: true) }
    @discardableResult func saveManualPlace(latitude: Double, longitude: Double, name: String, kind: String) -> Bool {
        guard ManualPosition.validCoordinates(latitude, longitude), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { problem = "coordinates"; return false }
        var place = FamiliarPlace(latitude: latitude, longitude: longitude, accuracy: 100, lastSeen: Date())
        if let old = learner.places.first(where: { PlaceLearner.distance(latitude, longitude, $0) < 150 }) { place = old }
        else { guard learner.places.count < 30 else { problem = "capacity"; return false }; learner.places.append(place) }
        confirmPlace(place.id, kind: kind, name: name); return problem != "storage"
    }
    func requestPermission() {
        enabled = true; UserDefaults.standard.set(true, forKey: "locationEnabled")
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        else { request(force: true) }
    }
    @Published private(set) var home: SavedHome?
    @Published private(set) var presence: HomePresence = .unknown
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var problem: String?
    @Published private(set) var locating = false
    @Published private(set) var learner = PlaceLearner()
    @Published var departureAlerts = UserDefaults.standard.object(forKey: "departureAlerts") == nil ? true : UserDefaults.standard.bool(forKey: "departureAlerts") { didSet { UserDefaults.standard.set(departureAlerts, forKey: "departureAlerts") } }
    private var departure = DepartureGate()
    private var automaticDeparture = HomeTransitionGate()
    var places: [FamiliarPlace] { learner.places.filter { $0.name != nil || $0.suggested } }
    func snoozeDeparture() {
        departure.snoozedUntil = Date().addingTimeInterval(86400)
        UserDefaults.standard.set(departure.snoozedUntil, forKey: "departureSnoozedUntil")
    }
    private func resetDeparture() {
        automaticDeparture = HomeTransitionGate()
        departure = DepartureGate(lastNotice: UserDefaults.standard.object(forKey: "lastDepartureNotice") as? Date ?? .distantPast,
                                  snoozedUntil: UserDefaults.standard.object(forKey: "departureSnoozedUntil") as? Date ?? .distantPast)
    }
    func confirmPlace(_ id: UUID, kind: String, name: String) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !trimmed.isEmpty, let index = learner.places.firstIndex(where: { $0.id == id }) else { return }
        if kind == "home" {
            let p = learner.places[index]
            let value = SavedHome(latitude: p.latitude, longitude: p.longitude, accuracy: p.accuracy)
            guard store.write(value, name: "home.json") else { problem = "storage"; return }
            home = value; resetDeparture()
            for i in learner.places.indices where learner.places[i].kind == "home" { learner.places[i].kind = "place" }
        }
        if learner.places[index].kind == "home" && kind != "home" {
            guard store.remove("home.json") else { problem = "storage"; return }
            home = nil; presence = .unknown; departure = DepartureGate()
        }
        learner.places[index].name = trimmed; learner.places[index].kind = kind
        _ = store.write(learner, name: "places-v3.json"); recompute()
    }
    func dismissPlace(_ id: UUID) {
        guard let index = learner.places.firstIndex(where: { $0.id == id }) else { return }
        learner.places[index].dismissed = true; _ = store.write(learner, name: "places-v3.json")
    }
    func forgetPlaces() {
        if let onForgetPlaces, !onForgetPlaces() { problem = "storage"; return }
        guard store.remove("places-v3.json"), store.remove("home.json") else { problem = "storage"; return }
        learner = PlaceLearner(); home = nil; resetDeparture(); presence = .unknown; lastLocation = nil; manualPosition = nil
    }
    func saveCurrentPlace(kind: String, name: String) {
        guard canSaveHome, let p = currentPosition else { problem = "accuracy"; return }
        if !learner.places.contains(where: { PlaceLearner.distance(p.coordinate.latitude, p.coordinate.longitude, $0) < 200 }) {
            guard learner.places.count < 30 else { problem = "capacity"; return }
            learner.places.append(FamiliarPlace(latitude: p.coordinate.latitude, longitude: p.coordinate.longitude, accuracy: p.horizontalAccuracy, lastSeen: p.timestamp))
        }
        if let nearest = learner.places.min(by: { PlaceLearner.distance(p.coordinate.latitude, p.coordinate.longitude, $0) < PlaceLearner.distance(p.coordinate.latitude, p.coordinate.longitude, $1) }) { confirmPlace(nearest.id, kind: kind, name: name) }
    }
    @Published var radius: Double { didSet { UserDefaults.standard.set(radius, forKey: "homeRadius"); recompute() } }
    var onForgetPlaces: (() -> Bool)?
    var onLeaveHome: (() -> Void)?
    var onAutomaticDeparture: (() -> Void)?
    private let manager = CLLocationManager()
    private let store: LocalStore
    private var lastRequest = Date.distantPast
    private var retry = LocationBackoff()
    private var lastConfirmed: HomePresence = .unknown
    private var lastDeparture = Date.distantPast
    private var timeout: DispatchWorkItem?
    init(store: LocalStore) {
        self.store = store
        radius = UserDefaults.standard.object(forKey: "homeRadius") == nil ? 300 : max(150, min(1000, UserDefaults.standard.double(forKey: "homeRadius")))
        home = store.read("home.json", as: SavedHome.self)
        learner = store.read("places-v3.json", as: PlaceLearner.self) ?? PlaceLearner()
        super.init(); resetDeparture()
        if let home, !learner.places.contains(where: { $0.kind == "home" }) {
            var place = FamiliarPlace(latitude: home.latitude, longitude: home.longitude, accuracy: home.accuracy, lastSeen: Date())
            place.name = "Home"; place.kind = "home"; learner.places.append(place)
        }
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        authorization = manager.authorizationStatus
    }
    var canSaveHome: Bool {
        guard let point = currentPosition, enabled || usingManual else { return false }
        return point.horizontalAccuracy >= 0 && point.horizontalAccuracy <= 100 && (usingManual || abs(point.timestamp.timeIntervalSinceNow) < 120)
    }
    func setEnabled(_ value: Bool) {
        enabled = value; UserDefaults.standard.set(value, forKey: "locationEnabled")
        if value { requestPermission() }
        else { timeout?.cancel(); manager.stopUpdatingLocation(); lastLocation = nil; resetDeparture(); presence = .unknown; lastConfirmed = .unknown; locating = false; problem = nil }
    }
    func suspend() {
        timeout?.cancel(); timeout = nil; manager.stopUpdatingLocation()
        if locating { locating = false }
    }
    func request(force: Bool = false) {
        guard enabled, !usingManual else { return }
        recompute()
        guard force || Date().timeIntervalSince(lastRequest) >= retry.interval else { return }
        guard !locating else { return }
        lastRequest = Date()
        if authorization != manager.authorizationStatus { authorization = manager.authorizationStatus }
        switch authorization {
        case .notDetermined:
            problem = "permission"
        case .authorizedAlways, .authorizedWhenInUse:
            guard !locating else { return }
            locating = true; problem = nil; lastRequest = Date()
            manager.requestLocation()
            timeout?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.locating else { return }
                self.locating = false; self.problem = "unavailable"; self.retry.failed(); self.manager.stopUpdatingLocation(); self.recompute()
            }
            timeout = work; DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: work)
        case .denied, .restricted:
            problem = "denied"; presence = .unknown; lastConfirmed = .unknown; lastLocation = nil
        @unknown default: problem = "unavailable"
        }
    }
    @discardableResult func saveHome() -> Bool {
        guard canSaveHome, let p = currentPosition else { problem = "accuracy"; return false }
        let value = SavedHome(latitude: p.coordinate.latitude, longitude: p.coordinate.longitude, accuracy: p.horizontalAccuracy)
        guard store.write(value, name: "home.json") else { problem = "storage"; return false }
        home = value; lastConfirmed = .unknown; recompute(); return true
    }
    func forgetHome() {
        guard store.remove("home.json") else { problem = "storage"; return }
        home = nil; presence = .unknown; lastConfirmed = .unknown; resetDeparture()
    }
    func recompute() {
        guard let home, let point = currentPosition else { presence = .unknown; return }
        let distance = point.distance(from: CLLocation(latitude: home.latitude, longitude: home.longitude))
        let value = HomeClassifier.classify(distance: distance, accuracy: point.horizontalAccuracy, homeAccuracy: home.accuracy, radius: radius, age: usingManual ? 0 : -point.timestamp.timeIntervalSinceNow)
        if presence != value { presence = value }
        if enabled && !usingManual && automaticDeparture.ingest(value, fix: point.timestamp, now: Date()) { onAutomaticDeparture?() }
        if !usingManual && departure.ingest(value, fix: point.timestamp, now: Date()) {
            UserDefaults.standard.set(departure.lastNotice, forKey: "lastDepartureNotice")
            if departureAlerts { onLeaveHome?() }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if enabled { request(force: true) }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        timeout?.cancel(); locating = false
        guard enabled, !usingManual, let newest = locations.last, newest.horizontalAccuracy >= 0, abs(newest.timestamp.timeIntervalSinceNow) < 600 else { return }
        retry.succeeded()
        lastLocation = newest; problem = newest.horizontalAccuracy > 250 ? "accuracy" : nil
        learner.observe(latitude: newest.coordinate.latitude, longitude: newest.coordinate.longitude, accuracy: newest.horizontalAccuracy, date: newest.timestamp)
        if !store.write(learner, name: "places-v3.json") { problem = "storage" }
        recompute()
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        timeout?.cancel(); locating = false; retry.failed(); problem = "unavailable"; recompute()
    }
    func status(_ l: Language) -> String {
        if usingManual { return l.text("Position you entered", "Posición indicada por ti") }
        if !enabled { return l.text("Automatic location off", "Ubicación automática desactivada") }
        if authorization == .denied || authorization == .restricted { return l.text("Location permission needed", "Falta permiso de ubicación") }
        if let point = lastLocation, abs(point.timestamp.timeIntervalSinceNow) < 600, point.horizontalAccuracy <= 100,
           let place = learner.places.first(where: { $0.name != nil && PlaceLearner.distance(point.coordinate.latitude, point.coordinate.longitude, $0) + point.horizontalAccuracy + $0.accuracy < radius }) {
            if place.kind == "home" { return l.text("At home", "En casa") }
            if place.kind == "work" { return l.text("At work", "En el trabajo") }
            return place.name ?? ""
        }
        if home == nil { return l.text("Learning your places", "Conociendo tus lugares") }
        switch presence {
        case .home: return l.text("At home", "En casa")
        case .away: return l.text("Away from home", "Fuera de casa")
        case .unknown: return l.text("Location uncertain", "Ubicación incierta")
        }
    }
    func detail(_ l: Language) -> String {
        if usingManual { return l.text("Manual position is valid for 30 minutes. It does not track your movement.", "La posición manual vale 30 minutos. No detecta tus desplazamientos.") }
        if !enabled { return l.text("Akku cannot detect where you are. You can still enter a temporary position manually.", "Akku no puede detectar dónde estás. Puedes indicar una posición manual temporal.") }
        if locating { return l.text("Finding a fresh location…", "Buscando una ubicación reciente…") }
        switch problem {
        case "coordinates": return l.text("Enter valid latitude (−90…90) and longitude (−180…180).", "Introduce latitud (−90…90) y longitud (−180…180) válidas.")
        case "capacity": return l.text("You have reached the 30-place limit.", "Alcanzaste el límite de 30 lugares.")
        case "permission": return l.text("Allow location in the macOS prompt.", "Permite la ubicación en el aviso de macOS.")
        case "denied": return l.text("Enable Akku in Privacy & Security → Location Services.", "Activa Akku en Privacidad y seguridad → Localización.")
        case "accuracy": return l.text("Location is too imprecise. Try again near a Wi-Fi connection.", "La ubicación es imprecisa. Inténtalo cerca de una conexión wifi.")
        case "storage": return l.text("Could not save changes locally.", "No se pudieron guardar los cambios localmente.")
        case "unavailable": return l.text("macOS couldn't provide a fresh location. Try again later.", "macOS no pudo obtener una ubicación reciente. Inténtalo luego.")
        default: return l.text("Checks about every 5 minutes while awake. Saves frequent places and visit counts locally, never a route.", "Consulta aproximadamente cada 5 minutos mientras está despierta. Guarda lugares frecuentes y visitas en este Mac, sin recorridos.")
        }
    }
}

final class AlertCenter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var enabled = UserDefaults.standard.bool(forKey: "alertsEnabled")
    @Published private(set) var allowed = false
    @Published private(set) var issue = false
    var onOpen: (() -> Void)?
    var onSnooze: (() -> Void)?
    override init() { super.init(); UNUserNotificationCenter.current().delegate = self
        let l = Language(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .initial
        let snooze = UNNotificationAction(identifier: "snooze", title: l.text("Remind me in 20 minutes", "Posponer 20 minutos"))
        UNUserNotificationCenter.current().setNotificationCategories([UNNotificationCategory(identifier: "forecast", actions: [snooze], intentIdentifiers: [])]); refresh() }
    func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
                if self?.allowed != allowed { self?.allowed = allowed }
            }
        }
    }
    func setEnabled(_ value: Bool) {
        enabled = value; UserDefaults.standard.set(value, forKey: "alertsEnabled")
        if value {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { [weak self] granted, error in
                DispatchQueue.main.async { self?.allowed = granted; self?.issue = error != nil || !granted }
            }
        } else { UNUserNotificationCenter.current().removeAllPendingNotificationRequests() }
    }
    func send(title: String, body: String, id: String) {
        guard enabled, allowed else { return }
        let content = UNMutableNotificationContent(); content.title = title; content.body = body; content.sound = nil; if id.hasPrefix("forecast-") { content.categoryIdentifier = "forecast" }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) { [weak self] error in
            if error != nil { DispatchQueue.main.async { self?.issue = true } }
        }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { completionHandler([.banner]) }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in if response.actionIdentifier == "snooze" { self?.onSnooze?() } else { self?.onOpen?() } }; completionHandler()
    }
}

final class LoginController: ObservableObject {
    @Published private(set) var status = SMAppService.mainApp.status
    @Published private(set) var failed = false
    var enabled: Bool { status == .enabled || status == .requiresApproval }
    func refresh() { let next = SMAppService.mainApp.status; if status != next { status = next } }
    func setEnabled(_ value: Bool) {
        do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; failed = false }
        catch { failed = true }
        refresh()
    }
    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
