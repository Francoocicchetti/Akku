import AppKit
import Combine
import CoreGraphics
import IOKit
import IOKit.ps
import IOKit.graphics

struct BatterySnapshot: Equatable {
    var percent: Double?
    var connected = false
    var charging = false
    var health: String?
    static func read() -> BatterySnapshot {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return BatterySnapshot() }
        for source in sources {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = d[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = d[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
            return BatterySnapshot(percent: min(100, max(0, Double(current) / Double(maximum) * 100)),
                                   connected: d[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                                   charging: d[kIOPSIsChargingKey] as? Bool ?? false,
                                   health: (d[kIOPSBatteryHealthConditionKey] as? String).flatMap { $0 == kIOPSCheckBatteryValue || $0 == kIOPSPermanentFailureValue ? $0 : nil } ?? d[kIOPSBatteryHealthKey] as? String)
        }
        return BatterySnapshot()
    }
}

// Public IOKit brightness control. Unsupported displays are reported, never simulated.
final class BrightnessController {
    private var originals: [(io_service_t, Float)] = []
    func dim() -> Bool {
        guard originals.isEmpty else { return true }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator) == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(iterator) }
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            var level: Float = 0
            if IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &level) == KERN_SUCCESS,
               IODisplaySetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, min(level, 0.35)) == KERN_SUCCESS {
                originals.append((service, level))
            } else { IOObjectRelease(service) }
        }
        return !originals.isEmpty
    }
    @discardableResult func restore() -> Bool {
        var success = true
        for (service, level) in originals {
            if IODisplaySetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, level) != KERN_SUCCESS { success = false }
            IOObjectRelease(service)
        }
        originals.removeAll()
        return success
    }
    deinit { restore() }
}

struct LearningArchive: Codable {
    let hardware: String
    var samples: [DischargeSample]
}
struct ReopenItem: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
}

final class BatteryModel: ObservableObject {
    @Published var snapshot = BatterySnapshot.read()
    @Published var usageSession = UsageSession()
    @Published var gentleReminders = UserDefaults.standard.object(forKey: "gentleReminders") == nil ? true : UserDefaults.standard.bool(forKey: "gentleReminders") { didSet { UserDefaults.standard.set(gentleReminders, forKey: "gentleReminders") } }
    @Published var breakMinutes = UserDefaults.standard.object(forKey: "breakMinutes") == nil ? 50.0 : max(30, min(120, UserDefaults.standard.double(forKey: "breakMinutes"))) { didSet { UserDefaults.standard.set(breakMinutes, forKey: "breakMinutes") } }
    @Published var quietUntil = UserDefaults.standard.object(forKey: "akkuQuietUntil") as? Date ?? Date.distantPast
    @Published var showWelcome = !UserDefaults.standard.bool(forKey: "akkuWelcomeComplete")
    @Published var returnMinutes = 30.0
    @Published var hasReturnTime = false
    @Published var workBeforeHome = 30.0
    @Published var useWhileReturning = false
    @Published var contextDate = Date()
    var companionContext: CompanionContext {
        CompanionContext(battery: snapshot.percent, charging: snapshot.charging, connected: snapshot.connected,
                         hour: Calendar.current.component(.hour, from: contextDate), away: location.presence == .away,
                         activeMinutes: usageSession.seconds / 60, breakThreshold: breakMinutes,
                         reminders: gentleReminders, quiet: quietUntil > contextDate,
                         busy: screenSharing || (activeTrip?.isPaused == false && currentActivity == .meeting) || selectedActivity == Activity.meeting.rawValue)
    }
    var returnPlan: ReturnPlan {
        ReturnPlan(battery: snapshot.percent, connected: snapshot.connected, presence: location.presence,
                   distance: location.homeDistance, returnMinutes: hasReturnTime ? returnMinutes : nil,
                   workMinutes: workBeforeHome, reserve: reserve, highRate: estimate(currentActivity ?? .browsing).highRate,
                   usageDuringTravel: useWhileReturning)
    }
    func quietCompanion() { quietUntil = Date().addingTimeInterval(3600); UserDefaults.standard.set(quietUntil, forKey: "akkuQuietUntil") }
    func finishWelcome() { showWelcome = false; UserDefaults.standard.set(true, forKey: "akkuWelcomeComplete") }

    @Published var language: Language { didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") } }
    @Published var baseline: Double { didSet { UserDefaults.standard.set(baseline, forKey: "baseline") } }
    @Published var reserve: Double { didSet { UserDefaults.standard.set(reserve, forKey: "reserve") } }
    @Published var trip: [TripItem] { didSet { if let data = try? JSONEncoder().encode(trip) { UserDefaults.standard.set(data, forKey: "trip") } } }
    @Published var learningEnabled: Bool { didSet { UserDefaults.standard.set(learningEnabled, forKey: "learningEnabled"); accumulator.reset(); chargeAccumulator.reset(); historyTracker.interrupt(); batteryHistoryTracker.interrupt(); if !learningEnabled { automaticTracker.stop(at: Date()); persistAutomatic(force: true); persistPlaceHistory(force: true); persistBatteryHistory(force: true) }; scheduleTimer() } }
    @Published var selectedActivity: String = "auto" { didSet { accumulator.reset() } }
    @Published var automaticArchive = SessionArchive(hardware: "")
    private var automaticTracker = AutomaticSessionTracker(hardware: "")
    private var pendingDeparture = false
    private var powerSource: CFRunLoopSource?
    private var checkpoints = CheckpointGate()
    private var presentations: [UUID: Bool] = [:]
    private var lastRefreshUptime = -Double.infinity
    private var lastPermissionRefresh = -Double.infinity
    private var scheduledInterval: TimeInterval?
    var hasVisiblePresentation: Bool { !presentations.isEmpty }
    func setPresentation(_ id: UUID, visible: Bool, needsCPU: Bool) {
        let wasVisible = hasVisiblePresentation
        if visible { presentations[id] = needsCPU } else { presentations.removeValue(forKey: id) }
        nativeApps.cpuMonitoringEnabled = presentations.values.contains(true)
        scheduleTimer()
        if visible {
            if !wasVisible { refresh(force: true) }
            if needsCPU { nativeApps.refresh() }
        } else if wasVisible && !hasVisiblePresentation {
            persistAutomatic(force: true); persistPlaceHistory(force: true); persistBatteryHistory(force: true)
        }
    }
    var weeklyStatistics: WeeklyStatistics { WeeklyStatistics(archive: automaticArchive, now: contextDate) }
    var routineAutonomy: RoutineAutonomy { RoutineAutonomy(days: weeklyStatistics.days, now: contextDate) }
    var automaticStatus: String {
        if !learningEnabled { return t("Learning paused in Settings", "Aprendizaje pausado en Ajustes") }
        if snapshot.percent == nil { return t("Waiting for battery data", "Esperando datos de batería") }
        if sleeping { return t("Resting with your Mac", "En pausa con tu Mac") }
        if snapshot.connected { return t("Ready for your next unplug", "Listo para cuando desconectes el cargador") }
        return t("Learning automatically", "Aprendiendo automáticamente")
    }
    private func persistAutomatic(force: Bool = false) {
        automaticArchive = automaticTracker.archive
        let now = ProcessInfo.processInfo.systemUptime
        guard checkpoints.due("sessions", uptime: now, force: force) else { return }
        if store.write(automaticArchive, name: "automatic-v5.json") { checkpoints.committed("sessions", uptime: now) }
        else { statusMessage = t("Statistics could not be saved. They remain in memory until you quit.", "No se pudieron guardar las estadísticas. Permanecen en memoria hasta cerrar la app.") }
    }
    @Published var placeHistory = PlaceHistoryArchive(hardware: "")
    private var historyTracker = PlaceHistoryTracker(hardware: "")
    private func recordPlaceHistory(persist: Bool = false) {
        guard learningEnabled, !sleeping else { return }
        let now = Date(), battery = snapshot
        let previousEvent = historyTracker.archive.events.last?.id
        let apps = nativeApps.apps.filter { $0.application.activationPolicy == .regular && !$0.bundleID.isEmpty }
        let names = Dictionary(apps.map { ($0.bundleID, $0.name) }, uniquingKeysWith: { first, _ in first })
        let front = nativeApps.foregroundID.flatMap { names[$0] == nil ? nil : $0 }
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
        historyTracker.ingest(HistoryReading(date: now, uptime: ProcessInfo.processInfo.systemUptime, percent: battery.percent,
            connected: battery.connected, charging: battery.charging, awake: !sleeping, idleSeconds: idle,
            foreground: front, apps: names, fix: location.automaticFix, placeID: location.automaticPlaceID))
        placeHistory = historyTracker.archive
        if persist || historyTracker.archive.events.last?.id != previousEvent { persistPlaceHistory(force: historyTracker.archive.events.last?.id != previousEvent) }
    }
    private func persistPlaceHistory(force: Bool = false) {
        placeHistory = historyTracker.archive
        let now = ProcessInfo.processInfo.systemUptime
        guard checkpoints.due("places", uptime: now, force: force) else { return }
        if store.write(placeHistory, name: "place-history-v6.json") { checkpoints.committed("places", uptime: now) }
        else {
            statusMessage = t("Place and app history could not be saved locally.", "No se pudo guardar el historial local de lugares y apps.")
        }
    }
    @Published var batteryHistory = BatteryHistoryArchive(hardware: "")
    private var batteryHistoryTracker = BatteryHistoryTracker(hardware: "")
    private func recordBatteryHistory(_ reading: BatterySnapshot? = nil) {
        guard learningEnabled, !sleeping else { return }
        let battery = reading ?? snapshot
        batteryHistoryTracker.ingest(BatteryHistoryReading(date: Date(), uptime: ProcessInfo.processInfo.systemUptime,
            percent: battery.percent, connected: battery.connected, charging: battery.charging, screenOn: true))
        batteryHistory = batteryHistoryTracker.archive
    }
    private func persistBatteryHistory(force: Bool = false) {
        let now = ProcessInfo.processInfo.systemUptime
        guard checkpoints.due("battery-panel", uptime: now, force: force) else { return }
        if store.write(batteryHistoryTracker.archive, name: "battery-history-v1.json") { checkpoints.committed("battery-panel", uptime: now) }
        else { statusMessage = t("Battery history could not be saved locally.", "No se pudo guardar el historial de batería.") }
    }
    @Published var samples: [DischargeSample] = []
    @Published var routines: [Routine] = []
    @Published var activeTrip: ActiveTrip?
    @Published var samplingMinutes: Double = 0
    @Published var emergency = false
    @Published var dimmed = false
    @Published var restoreFailed = false
    @Published var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Published var statusMessage: String?
    @Published var closedApps: [ReopenItem] = []
    @Published var departureNotice = false
    @Published var forecastWarning = false
    @Published var outcomes: [TripOutcome] = []
    @Published var chargeSamples: [ChargeSample] = []
    @Published var context = UsageContext()
    @Published var performance = PerformanceMonitor()
    @Published var screenSharing = false { didSet { refresh() } }
    @Published var pauseOnSleep = UserDefaults.standard.object(forKey: "pauseOnSleep") == nil ? true : UserDefaults.standard.bool(forKey: "pauseOnSleep") { didSet { UserDefaults.standard.set(pauseOnSleep, forKey: "pauseOnSleep") } }
    @Published var animateBuddy = UserDefaults.standard.object(forKey: "animateBuddy") == nil ? true : UserDefaults.standard.bool(forKey: "animateBuddy") { didSet { UserDefaults.standard.set(animateBuddy, forKey: "animateBuddy") } }
    private let conditions = ConditionsMonitor()
    private var chargeAccumulator = ChargeAccumulator()
    private var adapterSession = UUID().uuidString
    private var wasConnected = false
    private var sleepReasons = Set<String>()
    var adapterKey: String { (ConditionsMonitor.adapter ?? adapterSession) + "-" + context.environmentKey }
    var calibration: Calibration { Calibration(outcomes: outcomes) }
    func correction(_ items: [TripItem]) -> Double { calibration.factor(items: items, context: context) }
    func tripCost(_ items: [TripItem], conservative: Bool) -> Double { engine.tripCost(items, conservative: conservative) * correction(items) }
    func chargeTarget(_ items: [TripItem]) -> ChargeTarget { .make(cost: tripCost(items, conservative: true), reserve: reserve) }
    func chargeETA(_ items: [TripItem]) -> ChargeETA? {
        guard snapshot.charging, let percent = snapshot.percent else { return nil }
        return .estimate(from: percent, target: chargeTarget(items).requestedPercent, adapter: adapterKey, samples: chargeSamples)
    }
    let hardware: HardwareProfile
    let nativeApps = NativeAppMonitor()
    let store = LocalStore()
    let location: HomeLocation
    let alerts = AlertCenter()
    let login = LoginController()
    private let brightness = BrightnessController()
    private var accumulator = DischargeAccumulator()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var workspaceTokens: [NSObjectProtocol] = []
    private var quitRequests: [pid_t: ReopenItem] = [:]
    private var sleeping = false
    var onUpdate: (() -> Void)?
    var mode: String { "\(lowPower ? "low" : "normal")-\(dimmed ? "dim" : "screen")" }
    var budget: Budget { Budget(batteryPercent: snapshot.percent ?? 0, baselineHours: baseline, reservePercent: reserve) }
    var engine: ForecastEngine { ForecastEngine(samples: samples, baselineHours: baseline, mode: mode, context: context) }
    var currentActivity: Activity? {
        if let chosen = Activity(rawValue: selectedActivity) { return chosen }
        return nativeApps.foregroundID.flatMap { AppCategory.suggestedActivity(bundleID: $0) }
    }
    var confirmedActivity: Bool { Activity(rawValue: selectedActivity) != nil }
    var apps: [NSRunningApplication] { nativeApps.apps.filter(\.canQuit).map(\.application) }
    var observedMinutes: Double { samples.reduce(0) { $0 + $1.minutes } }
    var learningStatus: String {
        if !learningEnabled { return t("Learning paused", "Aprendizaje pausado") }
        if snapshot.percent == nil { return t("Battery unavailable", "Batería no disponible") }
        if snapshot.connected { return t("Learning waits until you unplug", "Aprende cuando desconectes el cargador") }
        return t("Learning from real discharge · \(Int(samplingMinutes))m in this interval", "Aprendiendo del consumo real · \(Int(samplingMinutes))m en este intervalo")
    }
    init() {
        let prefs = UserDefaults.standard
        hardware = .read(hasBattery: BatterySnapshot.read().percent != nil)
        location = HomeLocation(store: store)
        language = Language(rawValue: prefs.string(forKey: "language") ?? "") ?? .initial
        baseline = prefs.object(forKey: "baseline") == nil ? 10 : min(24, max(3, prefs.double(forKey: "baseline")))
        reserve = prefs.object(forKey: "reserve") == nil ? 15 : min(30, max(5, prefs.double(forKey: "reserve")))
        learningEnabled = prefs.object(forKey: "learningEnabled") == nil ? true : prefs.bool(forKey: "learningEnabled")
        if let data = prefs.data(forKey: "trip"), let saved = try? JSONDecoder().decode([TripItem].self, from: data) {
            trip = Array(saved.prefix(12)).map { TripItem(id: $0.id, activity: $0.activity, minutes: min(480, max(15, $0.minutes))) }
        } else { trip = [TripItem(activity: .meeting, minutes: 120)] }
        if let archive = store.read("learning-v2.json", as: LearningArchive.self), archive.hardware == hardware.identifier {
            samples = archive.samples.filter { $0.valid && Date().timeIntervalSince($0.date) >= 0 && Date().timeIntervalSince($0.date) < 60 * 86400 }.suffix(400)
        }
        routines = store.read("routines.json", as: [Routine].self) ?? []
        outcomes = store.read("outcomes-v3.json", as: [TripOutcome].self) ?? []
        chargeSamples = store.read("charge-v3.json", as: [ChargeSample].self) ?? []
        automaticTracker = AutomaticSessionTracker(hardware: hardware.identifier, saved: store.read("automatic-v5.json", as: SessionArchive.self))
        automaticArchive = automaticTracker.archive
        historyTracker = PlaceHistoryTracker(hardware: hardware.identifier, saved: store.read("place-history-v6.json", as: PlaceHistoryArchive.self))
        placeHistory = historyTracker.archive
        batteryHistoryTracker = BatteryHistoryTracker(hardware: hardware.identifier, saved: store.read("battery-history-v1.json", as: BatteryHistoryArchive.self))
        batteryHistory = batteryHistoryTracker.archive
        // Preserve a previous manual outing as an interrupted historical result.
        if var saved = store.read("active-trip.json", as: ActiveTrip.self) {
            saved.hadGap = true
            let outcome = TripOutcome.make(saved, endedAt: saved.lastObserved ?? saved.startedAt, battery: saved.lastBattery)
            let next = Array((outcomes.filter { $0.id != outcome.id } + [outcome]).suffix(200))
            if store.write(next, name: "outcomes-v3.json") { outcomes = next; _ = store.remove("active-trip.json") }
        }
        [nativeApps.objectWillChange, location.objectWillChange, alerts.objectWillChange, login.objectWillChange].forEach { publisher in
            publisher.receive(on: DispatchQueue.main).sink { [weak self] _ in if self?.hasVisiblePresentation == true { self?.objectWillChange.send() } }.store(in: &cancellables)
        }
        nativeApps.onFocusChange = { [weak self] in self?.recordPlaceHistory() }
        location.onForgetPlaces = { [weak self] in
            guard let self, self.store.remove("place-history-v6.json") else { return false }
            self.historyTracker.forgetPlaces(); self.persistPlaceHistory(force: true); return true
        }
        nativeApps.onTerminate = { [weak self] app in
            guard let self, let item = self.quitRequests.removeValue(forKey: app.processIdentifier) else { return }
            self.closedApps.append(item)
        }
        location.onAutomaticDeparture = { [weak self] in
            guard let self, self.learningEnabled else { return }
            self.pendingDeparture = true
            // Avoid re-entering refresh while Core Location is being recomputed.
            DispatchQueue.main.async { [weak self] in self?.refresh() }
        }
        location.onLeaveHome = { [weak self] in
            guard let self, self.learningEnabled else { return }
            self.departureNotice = true
            self.alerts.send(title: self.t("Heading out?", "¿Has salido?"), body: self.t("Akku is already learning from your battery use. No action needed.", "Akku ya está aprendiendo de tu consumo. No necesitas hacer nada."), id: "departure")
        }
        alerts.onSnooze = { [weak self] in self?.snoozeForecast() }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            workspaceTokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.handleSleep(name.rawValue, sleeping: true) })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            workspaceTokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.handleSleep(name == NSWorkspace.didWakeNotification ? NSWorkspace.willSleepNotification.rawValue : NSWorkspace.screensDidSleepNotification.rawValue, sleeping: false) })
        }
        powerSource = IOPSNotificationCreateRunLoopSource({ pointer in
            guard let pointer else { return }
            Unmanaged<BatteryModel>.fromOpaque(pointer).takeUnretainedValue().refresh(force: true)
        }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue()
        if let powerSource { CFRunLoopAddSource(CFRunLoopGetMain(), powerSource, .commonModes) }
        scheduleTimer(); refresh()
    }
    func t(_ en: LocalizedPhrase, _ es: String) -> String { language.text(en, es) }
    func estimate(_ activity: Activity, recent: Bool = true) -> RuntimeEstimate {
        let e = engine.estimate(activity: activity, battery: snapshot.percent ?? 0, reserve: reserve, includeRecent: recent)
        let f = correction([.init(activity: activity, minutes: 60)])
        return RuntimeEstimate(lowerMinutes: e.lowerMinutes / f, upperMinutes: e.upperMinutes / f, centralRate: e.centralRate * f, highRate: e.highRate * f, lowRate: e.lowRate * f, confidence: e.confidence, sampleCount: e.sampleCount, observedMinutes: e.observedMinutes, usingRecent: e.usingRecent, contextMatched: e.contextMatched)
    }
    func verdict(_ items: [TripItem]) -> TripVerdict {
        TripVerdict.evaluate(battery: snapshot.percent, reserve: reserve, centralCost: tripCost(items, conservative: false), conservativeCost: tripCost(items, conservative: true))
    }
    func refresh(force: Bool = false) {
        guard !sleeping else { return }
        let uptime = ProcessInfo.processInfo.systemUptime
        guard force || uptime - lastRefreshUptime >= 2 else { return }
        lastRefreshUptime = uptime
        contextDate = Date()
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
        usageSession.tick(uptime: ProcessInfo.processInfo.systemUptime, idleSeconds: idle, asleep: sleeping)
        let reading = BatterySnapshot.read(), newLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        if snapshot != reading { snapshot = reading }
        if lowPower != newLowPower { lowPower = newLowPower; scheduleTimer() }
        if nativeApps.cpuMonitoringEnabled { nativeApps.refresh() }
        location.recompute(); location.request()
        if uptime - lastPermissionRefresh >= 300 { login.refresh(); alerts.refresh(); lastPermissionRefresh = uptime }
        let nextContext = conditions.read(apps: nativeApps.apps, lowPower: lowPower, sharing: screenSharing)
        if context != nextContext { context = nextContext }
        let connectionChanged = snapshot.connected != wasConnected
        if snapshot.connected && !wasConnected { adapterSession = UUID().uuidString }
        wasConnected = snapshot.connected
        if learningEnabled {
            let oldSession = automaticTracker.archive.active?.id
            automaticTracker.ingest(SessionReading(date: contextDate, percent: snapshot.percent, connected: snapshot.connected,
                asleep: sleeping, presence: location.usingManual ? .unknown : location.presence), departed: pendingDeparture)
            pendingDeparture = false; persistAutomatic(force: connectionChanged || automaticTracker.archive.active?.id != oldSession)
        } else { pendingDeparture = false }
        if activeTrip != nil && pauseOnSleep, let closed = ConditionsMonitor.lidClosed {
            if closed && activeTrip?.isPaused == false { pauseTrip(reason: "sleep") }
            else if !closed && !sleeping && activeTrip?.pauseReason == "sleep" { resumeTrip() }
        }
        if learningEnabled && !sleeping, let charge = chargeAccumulator.ingest(date: Date(), percent: snapshot.percent, charging: snapshot.charging, adapter: adapterKey) {
            chargeSamples = Array((chargeSamples + [charge]).filter { Date().timeIntervalSince($0.date) < 30 * 86400 }.suffix(400))
            _ = store.write(chargeSamples, name: "charge-v3.json")
        }
        if var active = activeTrip {
            if snapshot.connected { active.hadCharging = true }
            if active.context?.sameConditions(as: context) == false { active.conditionsChanged = true }
            if !active.isPaused, let last = active.lastObserved, Date().timeIntervalSince(last) > 95 { active.hadGap = true }
            active.lastObserved = Date(); active.lastBattery = snapshot.percent
            activeTrip = active; _ = store.write(active, name: "active-trip.json")
        }
        let fresh = samples.filter { Date().timeIntervalSince($0.date) >= 0 && Date().timeIntervalSince($0.date) < 60 * 86400 }
        if fresh.count != samples.count { samples = fresh; _ = store.write(LearningArchive(hardware: hardware.identifier, samples: fresh), name: "learning-v2.json") }
        if let activeTrip, activeTrip.remaining(at: Date()).isEmpty { endTrip(); statusMessage = t("Your planned time is complete.", "Terminó el tiempo de tu salida.") }
        if learningEnabled && !sleeping {
            let observation = Observation(date: Date(), percent: snapshot.percent, onBattery: !snapshot.connected && !snapshot.charging,
                                          activity: currentActivity, appID: nativeApps.foregroundID, confirmed: confirmedActivity, mode: mode, context: context)
            if let sample = accumulator.ingest(observation) {
                samples = Array((samples + [sample]).filter { Date().timeIntervalSince($0.date) < 60 * 86400 }.suffix(400))
                if !store.write(LearningArchive(hardware: hardware.identifier, samples: samples), name: "learning-v2.json") { statusMessage = t("Learning could not be saved.", "No se pudo guardar el aprendizaje.") }
                checkForecast(sample)
            }
            samplingMinutes = accumulator.minutes
        }
        if let last = samples.last, !snapshot.connected { checkForecast(last) }
        recordBatteryHistory(); persistBatteryHistory(force: connectionChanged)
        recordPlaceHistory(persist: true)
        if connectionChanged { persistPlaceHistory(force: true) }
        performance.sample(); onUpdate?()
    }
    private func checkForecast(_ sample: DischargeSample) {
        guard var active = activeTrip, let battery = snapshot.percent, !snapshot.connected, sample.mode == mode,
              sample.date.addingTimeInterval(-sample.minutes * 60) >= active.startedAt else { return }
        let remaining = active.remaining(at: Date())
        let rate = max(sample.rate, engine.tripCost(remaining, conservative: true) / max(1, Double(remaining.reduce(0) { $0 + $1.minutes })) * 60)
        let shortfall = Double(remaining.reduce(0) { $0 + $1.minutes }) - max(0, battery - reserve) / max(0.1, rate) * 60
        var state = active.alertState ?? SmartAlertState()
        if state.evaluate(sample: sample, at: Date(), shortfallMinutes: shortfall, isPaused: active.isPaused) {
            active.warned = true; forecastWarning = true
            alerts.send(title: t("Your battery may fall short", "La batería podría no alcanzar"), body: t("At this pace you may fall short before finishing. Connect a charger or shorten your plan.", "Con este ritmo podrías quedarte corto antes de terminar. Conecta el cargador o acorta tu plan."), id: "forecast-\(active.id.uuidString)")
        }
        active.alertState = state; activeTrip = active; _ = store.write(active, name: "active-trip.json")
    }
    func snoozeForecast() {
        guard var active = activeTrip else { return }
        var state = active.alertState ?? SmartAlertState(); state.snooze(at: Date()); active.alertState = state
        activeTrip = active; forecastWarning = false; _ = store.write(active, name: "active-trip.json")
    }
    private func handleSleep(_ reason: String, sleeping value: Bool) {
        if value && !sleeping { recordBatteryHistory(BatterySnapshot.read()) }
        batteryHistoryTracker.interrupt(); persistBatteryHistory(force: true)
        if value { sleepReasons.insert(reason) } else { sleepReasons.remove(reason) }
        sleeping = !sleepReasons.isEmpty; scheduleTimer(); if sleeping { location.suspend() }; historyTracker.interrupt(); persistPlaceHistory(force: true); automaticTracker.interrupt(); persistAutomatic(force: true); accumulator.reset(); chargeAccumulator.reset(); if sleeping { usageSession.reset() }
        if sleeping && pauseOnSleep { pauseTrip(reason: "sleep") }
        if sleeping && !pauseOnSleep, var active = activeTrip { active.hadGap = true; activeTrip = active; _ = store.write(active, name: "active-trip.json") }
        if !sleeping && activeTrip?.pauseReason == "sleep" && ConditionsMonitor.lidClosed != true { resumeTrip() }
        if !sleeping { refresh(force: true) }
    }
    func pauseTrip(reason: String = "manual") {
        guard var active = activeTrip, !active.isPaused else { return }
        active.pause(at: Date(), reason: reason); active.alertState?.consecutive = 0; activeTrip = active
        accumulator.reset(); _ = store.write(active, name: "active-trip.json")
    }
    func resumeTrip() {
        guard var active = activeTrip, active.isPaused else { return }
        active.resume(at: Date()); activeTrip = active
        accumulator.reset(); _ = store.write(active, name: "active-trip.json")
    }
    private func scheduleTimer() {
        let interval = EnergyPolicy.interval(visible: hasVisiblePresentation, learning: learningEnabled, lowPower: lowPower, emergency: emergency, sleeping: sleeping)
        guard interval != scheduledInterval || (timer == nil && interval != nil) else { return }
        timer?.invalidate(); timer = nil; scheduledInterval = interval
        guard let interval else { return }
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.refresh() }
        newTimer.tolerance = EnergyPolicy.tolerance(for: interval)
        RunLoop.main.add(newTimer, forMode: .common); timer = newTimer
    }
    func toggleEmergency() {
        emergency.toggle(); restoreFailed = false; accumulator.reset()
        if emergency { dimmed = brightness.dim() }
        else { restoreFailed = !brightness.restore(); dimmed = false }
        scheduleTimer(); refresh()
    }
    func restoreOnExit() { recordBatteryHistory(); batteryHistoryTracker.interrupt(); persistBatteryHistory(force: true); historyTracker.interrupt(); persistPlaceHistory(force: true); automaticTracker.interrupt(); persistAutomatic(force: true); brightness.restore() }
    func loadApps() { nativeApps.refresh() }
    func quit(_ app: NSRunningApplication) {
        guard let candidate = nativeApps.apps.first(where: { $0.id == app.processIdentifier }), candidate.canQuit else { return }
        if let url = app.bundleURL { quitRequests[app.processIdentifier] = ReopenItem(name: app.localizedName ?? "App", url: url) }
        let accepted = app.terminate()
        if !accepted { quitRequests.removeValue(forKey: app.processIdentifier) }
        statusMessage = accepted ? t("Quit requested. Save changes if the app asks. Reopen becomes available after it closes.", "Cierre solicitado. Guarda los cambios si la app lo pide. Podrás reabrirla cuando cierre.") : t("The app didn't accept the quit request.", "La app no aceptó la solicitud de cierre.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            if app.isTerminated, let item = self.quitRequests.removeValue(forKey: app.processIdentifier) { self.closedApps.append(item) }
            self.loadApps()
        }
    }
    func reopen(_ item: ReopenItem) {
        NSWorkspace.shared.openApplication(at: item.url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            DispatchQueue.main.async {
                if error == nil { self?.closedApps.removeAll { $0.id == item.id } }
                else { self?.statusMessage = self?.t("Could not reopen the app.", "No se pudo reabrir la app.") }
            }
        }
    }
    func openSettings(_ pane: String) { if let url = URL(string: "x-apple.systempreferences:\(pane)") { NSWorkspace.shared.open(url) } }
    func saveRoutine(name: String) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard !trimmed.isEmpty, !trip.isEmpty, routines.count < 30 else { return }
        let next = routines + [Routine(name: trimmed, items: trip)]
        if store.write(next, name: "routines.json") { routines = next }
        else { statusMessage = t("Routine could not be saved.", "No se pudo guardar la rutina.") }
    }
    func removeRoutine(_ id: UUID) {
        let next = routines.filter { $0.id != id }
        if store.write(next, name: "routines.json") { routines = next }
    }
    func startTrip(_ items: [TripItem], validation: String? = nil) {
        guard activeTrip == nil, !items.isEmpty, snapshot.percent != nil else { return }
        let total = Double(items.reduce(0) { $0 + $1.minutes })
        let factor = correction(items)
        let rates = items.map { item -> FrozenRate in
            let e = engine.estimate(activity: item.activity, battery: 100, reserve: 0, includeRecent: true)
            return FrozenRate(activity: item.activity, central: e.centralRate * factor, high: e.highRate * factor, low: e.lowRate * factor, raw: e.centralRate)
        }
        var value = ActiveTrip(startedAt: Date(), items: items, initialRate: tripCost(items, conservative: false) / total * 60)
        value.initialBattery = snapshot.percent; value.rates = rates; value.context = context
        value.lastObserved = Date(); value.lastBattery = snapshot.percent; value.hadCharging = snapshot.connected
        value.validationLabel = validation
        guard store.write(value, name: "active-trip.json") else { statusMessage = t("Trip could not be saved.", "No se pudo guardar la salida."); return }
        activeTrip = value; forecastWarning = false; departureNotice = false; selectedActivity = "auto"; accumulator.reset()
    }
    func endTrip() {
        guard let active = activeTrip else { return }
        let outcome = TripOutcome.make(active, endedAt: Date(), battery: BatterySnapshot.read().percent)
        let next = Array((outcomes + [outcome]).suffix(200))
        guard store.write(next, name: "outcomes-v3.json") else { statusMessage = t("Could not save the result. Try again.", "No se pudo guardar el resultado. Inténtalo otra vez."); return }
        outcomes = next; activeTrip = nil; forecastWarning = false
        _ = store.remove("active-trip.json"); accumulator.reset()
    }
    func clearLearning() {
        checkpoints.reset()
        for file in ["learning-v2.json", "charge-v3.json", "outcomes-v3.json", "automatic-v5.json", "place-history-v6.json", "battery-history-v1.json"] {
            guard store.remove(file) else { statusMessage = t("Could not delete all learning data.", "No se pudo borrar todo el aprendizaje."); return }
        }
        automaticTracker = AutomaticSessionTracker(hardware: hardware.identifier); automaticArchive = automaticTracker.archive; pendingDeparture = false
        historyTracker = PlaceHistoryTracker(hardware: hardware.identifier); placeHistory = historyTracker.archive
        batteryHistoryTracker = BatteryHistoryTracker(hardware: hardware.identifier); batteryHistory = batteryHistoryTracker.archive
        samples = []; chargeSamples = []; outcomes = []; accumulator.reset(); chargeAccumulator.reset(); samplingMinutes = 0
    }
    func exportResults() {
        persistPlaceHistory(force: true); persistAutomatic(force: true); persistBatteryHistory(force: true)
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Akku-statistics.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        struct Report: Encodable { let model: String; let chip: String; let exportedAt: Date; let outcomes: [TripOutcome]; let samples: [DischargeSample]; let performance: [PerformanceSample]; let automatic: SessionArchive; let dailyApps: [AppDayUsage]; let batteryHistory: BatteryHistoryArchive }
        let report = Report(model: hardware.identifier, chip: hardware.chip, exportedAt: Date(), outcomes: outcomes, samples: samples, performance: performance.samples, automatic: automaticArchive, dailyApps: placeHistory.apps.map { row in var clean = row; clean.places = [:]; return clean }, batteryHistory: batteryHistory)
        do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; try encoder.encode(report).write(to: url, options: .atomic) }
        catch { statusMessage = t("Export failed.", "No se pudo exportar.") }
    }
    func preset(_ index: Int) {
        switch index {
        case 1: trip = [.init(activity: .video, minutes: 120), .init(activity: .reading, minutes: 45)]
        case 2: trip = [.init(activity: .writing, minutes: 60), .init(activity: .browsing, minutes: 30), .init(activity: .reading, minutes: 30)]
        default: trip = [.init(activity: .browsing, minutes: 90), .init(activity: .writing, minutes: 30)]
        }
    }
    deinit { if let powerSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .commonModes) }; for token in workspaceTokens { NSWorkspace.shared.notificationCenter.removeObserver(token) }; timer?.invalidate() }
}
