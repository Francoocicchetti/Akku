import Foundation
import Darwin

struct HardwareProfile {
    let identifier: String
    let chip: String
    let name: String
    let supported: Bool
    // Identifiers from Apple's Air / Pro model identification pages, September 2026.
    static let models: [String: String] = [
        "MacBookAir10,1": "MacBook Air 13″ · M1", "Mac14,2": "MacBook Air 13″ · M2", "Mac14,15": "MacBook Air 15″ · M2",
        "Mac15,12": "MacBook Air 13″ · M3", "Mac15,13": "MacBook Air 15″ · M3",
        "Mac16,12": "MacBook Air 13″ · M4", "Mac16,13": "MacBook Air 15″ · M4",
        "Mac17,3": "MacBook Air 13″ · M5", "Mac17,4": "MacBook Air 15″ · M5",
        "MacBookPro17,1": "MacBook Pro 13″ · M1", "MacBookPro18,3": "MacBook Pro 14″ · M1", "MacBookPro18,4": "MacBook Pro 14″ · M1",
        "MacBookPro18,1": "MacBook Pro 16″ · M1", "MacBookPro18,2": "MacBook Pro 16″ · M1",
        "Mac14,7": "MacBook Pro 13″ · M2", "Mac14,5": "MacBook Pro 14″ · M2", "Mac14,9": "MacBook Pro 14″ · M2",
        "Mac14,6": "MacBook Pro 16″ · M2", "Mac14,10": "MacBook Pro 16″ · M2",
        "Mac15,3": "MacBook Pro 14″ · M3", "Mac15,6": "MacBook Pro 14″ · M3", "Mac15,8": "MacBook Pro 14″ · M3", "Mac15,10": "MacBook Pro 14″ · M3",
        "Mac15,7": "MacBook Pro 16″ · M3", "Mac15,9": "MacBook Pro 16″ · M3", "Mac15,11": "MacBook Pro 16″ · M3",
        "Mac16,1": "MacBook Pro 14″ · M4", "Mac16,6": "MacBook Pro 14″ · M4", "Mac16,8": "MacBook Pro 14″ · M4",
        "Mac16,7": "MacBook Pro 16″ · M4", "Mac16,5": "MacBook Pro 16″ · M4",
        "Mac17,2": "MacBook Pro 14″ · M5", "Mac17,7": "MacBook Pro 14″ · M5", "Mac17,9": "MacBook Pro 14″ · M5",
        "Mac17,6": "MacBook Pro 16″ · M5", "Mac17,8": "MacBook Pro 16″ · M5"
    ]
    static func identify(identifier: String, chip: String, hasBattery: Bool) -> HardwareProfile {
        if let name = models[identifier] { return .init(identifier: identifier, chip: chip, name: name, supported: true) }
        // Neo has an A18 Pro, not an M-series chip. Read the actual CPU rather than guessing an M generation.
        if hasBattery && chip.contains("Apple A18 Pro") { return .init(identifier: identifier, chip: chip, name: "MacBook Neo · A18 Pro", supported: false) }
        return .init(identifier: identifier, chip: chip, name: identifier, supported: false)
    }
    static func read(hasBattery: Bool) -> HardwareProfile {
        identify(identifier: sysctlString("hw.model"), chip: sysctlString("machdep.cpu.brand_string"), hasBattery: hasBattery)
    }
    private static func sysctlString(_ key: String) -> String {
        var count = 0
        guard sysctlbyname(key, nil, &count, nil, 0) == 0, count > 0 else { return "Unknown" }
        var bytes = [CChar](repeating: 0, count: count)
        guard sysctlbyname(key, &bytes, &count, nil, 0) == 0 else { return "Unknown" }
        return String(cString: bytes)
    }
}

struct AppCategory {
    static func suggestedActivity(bundleID: String) -> Activity? {
        switch bundleID.lowercased() {
        case "com.apple.facetime", "us.zoom.xos", "com.microsoft.teams2", "com.microsoft.teams": return .meeting
        case "com.apple.safari", "com.google.chrome", "org.mozilla.firefox", "com.microsoft.edgemac", "company.thebrowser.browser": return .browsing
        case "com.openai.chat", "com.openai.chatgpt", "com.openai.codex", "com.anthropic.claudefordesktop", "net.whatsapp.whatsapp", "com.whatsapp.whatsapp", "com.apple.notes", "com.apple.iwork.pages", "com.microsoft.word", "notion.id": return .writing
        case "com.apple.preview", "com.adobe.reader": return .reading
        case "com.apple.tv", "org.videolan.vlc", "com.colliderli.iina": return .video
        case "com.apple.dt.xcode", "com.microsoft.vscode", "com.todesktop.230313mzl4w4u92": return .coding
        default: return nil
        }
    }
}
