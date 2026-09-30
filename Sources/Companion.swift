import Foundation

enum AkkuMood: String, CaseIterable {
    case ready, full, charging, low, exhausted, breakTime, evening, away
    func name(_ l: Language) -> String {
        switch self {
        case .ready: return l.text("Ready to help", "Listo para acompañarte")
        case .full: return l.text("Full of energy", "Lleno de energía")
        case .charging: return l.text("Feeding time", "Recargando energía")
        case .low: return l.text("A little tired", "Un poco cansado")
        case .exhausted: return l.text("Very little energy", "Muy poca energía")
        case .breakTime: return l.text("Time for a breather", "Momento de una pausa")
        case .evening: return l.text("A quiet companion", "Compañía tranquila")
        case .away: return l.text("Out with you", "Contigo fuera de casa")
        }
    }
}
struct CompanionContext {
    var battery: Double?
    var charging = false
    var connected = false
    var hour = 12
    var away = false
    var activeMinutes = 0.0
    var breakThreshold = 50.0
    var reminders = true
    var quiet = false
    var busy = false
    var mood: AkkuMood {
        if charging { return .charging }
        if let battery, battery <= 10 && !connected { return .exhausted }
        if let battery, battery < 25 && !connected { return .low }
        if reminders && !quiet && !busy && activeMinutes >= breakThreshold { return .breakTime }
        if hour >= 22 || hour < 6 { return .evening }
        if let battery, battery >= 90 { return .full }
        return away ? .away : .ready
    }
    func message(_ l: Language) -> String {
        if quiet && mood != .exhausted && mood != .low && !charging { return l.text("I'm here. No rush.", "Estoy aquí. Sin prisas.") }
        switch mood {
        case .charging: return l.text("Yum. A little more energy!", "Ñam. ¡Un poco más de energía!")
        case .exhausted: return l.text("I'm running on crumbs. Charger time?", "Me quedan miguitas. ¿Buscamos el cargador?")
        case .low: return l.text("I'm getting sleepy. Shall we feed me?", "Me está dando sueño. ¿Me alimentas?")
        case .breakTime: return l.text("We've been here a while. A little break?", "Llevamos un buen rato. ¿Una pequeña pausa?")
        case .evening: return l.text("It's late. I'll keep you quiet company.", "Ya es tarde. Te acompaño sin hacer ruido.")
        case .full: return l.text("Full of energy. Where shall we go?", "Estoy lleno de energía. ¿Adónde vamos?")
        case .away: return l.text("Away from home, together. Let's make it last.", "Fuera de casa, juntos. Hagamos rendir la energía.")
        case .ready:
            if connected { return l.text("Plugged in and keeping you company.", "Conectado y haciéndote compañía.") }
            return hour < 12 ? l.text("Good morning. What are we doing today?", "Buen día. ¿Qué hacemos hoy?") : l.text("I'm Akku. Let's take care of our energy.", "Soy Akku. Cuidemos nuestra energía.")
        }
    }
}
struct UsageSession {
    private var lastUptime: Double?
    private(set) var seconds = 0.0
    mutating func tick(uptime: Double, idleSeconds: Double, asleep: Bool) {
        guard uptime.isFinite, idleSeconds.isFinite, idleSeconds >= 0 else { lastUptime = nil; return }
        defer { lastUptime = uptime }
        guard !asleep, idleSeconds < 300 else { seconds = 0; return }
        guard let lastUptime else { return }
        let gap = uptime - lastUptime
        guard gap > 0 && gap <= 95 else { seconds = 0; return }
        seconds += gap
    }
    mutating func reset() { seconds = 0; lastUptime = nil }
}
struct ManualPosition: Codable {
    let latitude: Double
    let longitude: Double
    let label: String
    let date: Date
    func valid(at now: Date) -> Bool { Self.validCoordinates(latitude, longitude) && now.timeIntervalSince(date) >= 0 && now.timeIntervalSince(date) < 1800 }
    static func validCoordinates(_ latitude: Double, _ longitude: Double) -> Bool { latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude) }
}
struct HomeDistance {
    let meters: Double
    let uncertainty: Double
    let manual: Bool
    var lower: Double { max(0, meters - uncertainty) }
    var upper: Double { meters + uncertainty }
    var far: Bool { lower >= 5000 }
    func text(_ l: Language) -> String {
        let value = meters >= 1000 ? String(format: "%.1f km", meters / 1000) : "\(Int((meters / 50).rounded()) * 50) m"
        return l.text("About \(value) from home", "Aproximadamente a \(value) de casa")
    }
}
enum ReturnAdvice: Equatable { case unknown, atHome, connected, chargeNearby, probablyHome, askReturnTime }
struct ReturnPlan {
    var battery: Double?
    var connected = false
    var presence: HomePresence = .unknown
    var distance: HomeDistance?
    var returnMinutes: Double? = nil
    var workMinutes = 30.0
    var reserve = 15.0
    var highRate: Double
    // Evaluate active-use time separately; distance is not a route or an ETA.
    var usageDuringTravel = false
    var advice: ReturnAdvice {
        if connected { return .connected }
        guard let battery, battery.isFinite else { return .unknown }
        if presence == .home { return .atHome }
        guard distance != nil else { return .unknown }
        if battery <= max(10, reserve) { return .chargeNearby }
        let available = max(0, battery - reserve)
        if highRate * workMinutes / 60 > available { return .chargeNearby }
        guard let returnMinutes, returnMinutes > 0 else { return .askReturnTime }
        // With the Mac closed, use a conservative 2 points/hour allowance, not an asserted measured sleep rate.
        let travelCost = returnMinutes / 60 * (usageDuringTravel ? highRate : 2)
        let cost = highRate * workMinutes / 60 + travelCost
        return cost <= available ? .probablyHome : .chargeNearby
    }
    func message(_ l: Language) -> String {
        switch advice {
        case .unknown: return l.text("Set home and a recent position to compare your options.", "Define casa y una posición reciente para comparar tus opciones.")
        case .connected: return l.text("We're already plugged in. Let's recharge here.", "Ya estamos conectados. Recarguemos aquí.")
        case .atHome: return l.text("We're home. Your charger can wait here for you.", "Estamos en casa. Puedes cargar aquí cuando lo necesites.")
        case .chargeNearby:
            return distance?.far == true ? l.text("Home is a long way away and energy is tight. Better charge where you are.", "Casa está lejos y vamos justos de energía. Mejor cargar donde estás.") : l.text("Better charge here before you continue. The conservative estimate uses your reserve.", "Mejor cargar aquí antes de continuar. La estimación conservadora llega a tu reserva.")
        case .probablyHome: return l.text("You could probably charge at home with this plan. Keep the reserve in mind.", "Con este plan, probablemente puedas cargar al llegar a casa. Conserva el margen de reserva.")
        case .askReturnTime: return distance?.far == true ? l.text("We're far from home. How long until you're back?", "Estamos lejos de casa. ¿Cuánto falta para volver?") : l.text("How long until home, and how much more work first?", "¿Cuánto falta para volver y cuánto trabajo queda antes?")
        }
    }
}
