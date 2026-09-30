import SwiftUI
struct LanguageMenu: View {
    @ObservedObject var model: BatteryModel
    var body: some View {
        Menu {
            ForEach(Language.allCases, id: \.self) { language in
                Toggle(language.displayName, isOn: Binding(get: { model.language == language }, set: { if $0 { model.language = language } }))
            }
        } label: {
            HStack(spacing: 5) { Image(systemName: "globe"); Text(model.language.badge) }
                .font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.mint)
                .padding(.horizontal, 9).padding(.vertical, 7).background(Palette.card).clipShape(Capsule())
        }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().accessibilityLabel(model.t("Language", "Idioma"))
    }
}
