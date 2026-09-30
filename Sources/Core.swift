import Foundation

enum Language: String, CaseIterable, Codable {
    case en, es, fr, zh = "zh-Hans", de, pt = "pt-BR"
    static var initial: Language { .en }
    var displayName: String {
        switch self {
        case .en: return "English"
        case .es: return "Español"
        case .fr: return "Français"
        case .zh: return "简体中文"
        case .de: return "Deutsch"
        case .pt: return "Português (Brasil)"
        }
    }
    var locale: Locale { Locale(identifier: rawValue) }
    var badge: String {
        switch self {
        case .zh: return "中文"
        case .pt: return "PT"
        default: return rawValue.uppercased()
        }
    }
    func text(_ english: LocalizedPhrase, _ spanish: String) -> String {
        if self == .es { return spanish }
        let index: Int?
        switch self { case .fr: index = 0; case .zh: index = 1; case .de: index = 2; case .pt: index = 3; default: index = nil }
        let translated = index.flatMap { TranslationCatalog.entries[english.key]?[$0] } ?? english.key
        return english.render(translated)
    }
}

enum Activity: String, CaseIterable, Codable, Identifiable {
    case browsing, meeting, video, reading, writing, coding
    var id: String { rawValue }
    var multiplier: Double {
        switch self {
        case .browsing: return 1
        case .meeting: return 1.9
        case .video: return 0.85
        case .reading: return 0.6
        case .writing: return 0.8
        case .coding: return 1.4
        }
    }
    var symbol: String {
        switch self {
        case .browsing: return "safari"
        case .meeting: return "video"
        case .video: return "play.rectangle"
        case .reading: return "doc.richtext"
        case .writing: return "square.and.pencil"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        }
    }
    func name(_ l: Language) -> String {
        switch self {
        case .browsing: return l.text("Web browsing", "Navegar por internet")
        case .meeting: return l.text("Video calls", "Videollamadas")
        case .video: return l.text("Watching a movie", "Ver una película")
        case .reading: return l.text("Reading PDFs", "Leer PDF")
        case .writing: return l.text("Writing & notes", "Escribir y tomar notas")
        case .coding: return l.text("Coding", "Programar")
        }
    }
    func detail(_ l: Language) -> String {
        switch self {
        case .browsing: return l.text("Tabs, email, a little exploring", "Pestañas, correo y un poco de todo")
        case .meeting: return l.text("Camera and microphone on", "Cámara y micrófono encendidos")
        case .video: return l.text("Streaming at standard brightness", "Streaming con brillo moderado")
        case .reading: return l.text("Quiet time with your documents", "Un rato tranquilo con tus documentos")
        case .writing: return l.text("Documents, notes and ideas", "Documentos, apuntes e ideas")
        case .coding: return l.text("Editor and light development", "Editor y desarrollo ligero")
        }
    }
}

struct TripItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var activity: Activity
    var minutes: Int
}

struct Budget {
    let batteryPercent: Double
    let baselineHours: Double
    let reservePercent: Double
    var usablePercent: Double { max(0, min(100, batteryPercent) - reservePercent) }
    func minutes(for activity: Activity) -> Double {
        guard baselineHours > 0 else { return 0 }
        return usablePercent / 100 * baselineHours * 60 / activity.multiplier
    }
    func cost(of items: [TripItem]) -> Double {
        guard baselineHours > 0 else { return .infinity }
        return items.reduce(0) { $0 + Double(max(0, $1.minutes)) / (baselineHours * 60) * 100 * $1.activity.multiplier }
    }
    func remaining(after items: [TripItem]) -> Double { batteryPercent - cost(of: items) }
    func fits(_ items: [TripItem]) -> Bool { !items.isEmpty && cost(of: items) <= usablePercent + 0.000001 }
}

func duration(_ rawMinutes: Double) -> String {
    guard rawMinutes.isFinite, rawMinutes > 0 else { return "0m" }
    if rawMinutes < 5 { return "<5m" }
    let minutes = Int(floor(rawMinutes / 5) * 5)
    let hours = minutes / 60
    let rest = minutes % 60
    return hours > 0 ? (rest > 0 ? "\(hours)h \(rest)m" : "\(hours)h") : "\(rest)m"
}
