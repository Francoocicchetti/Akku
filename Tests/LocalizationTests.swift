import Foundation
@main struct LocalizationTests {
    static func main() throws {
        var checks = 0
        func check(_ condition: Bool, _ label: String) {
            checks += 1
            if !condition { fputs("FAIL: \(label)\n", stderr); exit(1) }
        }
        check(Language.initial == .en, "New installations always start in English")
        check(Language.allCases.count == 6, "Six selectable languages")
        for language in Language.allCases {
            let data = try JSONEncoder().encode(language)
            check(try JSONDecoder().decode(Language.self, from: data) == language, "Saved language survives restart")
            check(!language.displayName.isEmpty && !language.badge.isEmpty, "Selector labels")
        }
        check(Language.es.text("Home", "Casa") == "Casa", "Existing Spanish remains intact")
        check(Language.zh.text("Home", "Casa") == "家", "Chinese is actually translated")
        check(Language.fr.text("Home in \(30) minutes", "En casa en 30 minutos") == "À la maison dans 30 minutes", "French dynamic time")
        check(Language.de.text("We estimated \(45)%. You finished with \(38)%.", "") == "Wir hatten 45 % geschätzt. Am Ende waren es 38 %.", "Two values retained in German")
        check(Language.pt.text("including a \(15)% reserve", "") == "incluindo reserva de 15%", "Portuguese reserve value")
        check(Language.zh.text("Learning automatically", "") == "正在自动学习", "Computed model status is translated")
        let payload = "Café {1}"
        let phrase: LocalizedPhrase = "\(payload) / \(7)"
        check(phrase.render("{1} / {0}") == "7 / Café {1}", "User values cannot become format placeholders")
        check(Language.fr.text("Unknown \(7)", "") == "Unknown 7", "Safe fallback retains dynamic values")
        let regex = try NSRegularExpression(pattern: #"\{\d+\}"#)
        func tokens(_ value: String) -> [String] {
            regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).map { String(value[Range($0.range, in: value)!]) }.sorted()
        }
        for (key, values) in TranslationCatalog.entries {
            check(values.count == 4, "Four extra languages for every template")
            for value in values {
                check(!value.isEmpty && tokens(key) == tokens(value), "Translation preserves all numeric placeholders")
            }
        }
        print("PASS: \(checks) language persistence, dynamic values and translation completeness checks")
    }
}
