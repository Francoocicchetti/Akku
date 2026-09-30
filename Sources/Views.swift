import SwiftUI
import AppKit

enum Palette {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.045)
    static let card = Color(red: 0.072, green: 0.095, blue: 0.082)
    static let mint = Color(red: 0.12, green: 0.91, blue: 0.56)
    static let secondary = Color(red: 0.63, green: 0.69, blue: 0.65)
    static let ink = Color(red: 0.94, green: 0.97, blue: 0.94)
    static let line = Color(red: 0.16, green: 0.21, blue: 0.18)
    static let amber = Color(red: 1, green: 0.72, blue: 0.36)
    static let peach = Color(red: 0.10, green: 0.19, blue: 0.14)
}
struct Panel: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Palette.card).clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))
    }
}
extension View { func panel() -> some View { modifier(Panel()) } }
struct Detail: View {
    var text: String
    var body: some View { Text(text).font(.system(size: 12)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true).lineSpacing(2) }
}
struct PrimaryButton: View {
    let title: String
    var icon = "arrow.right"
    let action: () -> Void
    var body: some View {
        Button(action: action) { HStack { Text(title).fontWeight(.semibold); Spacer(); Image(systemName: icon) }.padding(13).foregroundStyle(Palette.background).background(Palette.mint).clipShape(RoundedRectangle(cornerRadius: 11)) }.buttonStyle(.plain)
    }
}
struct MinuteStepper: View {
    @Binding var minutes: Int
    let language: Language
    var body: some View {
        HStack(spacing: 12) {
            Button { minutes = max(15, minutes - 15) } label: { Image(systemName: "minus.circle.fill").font(.system(size: 23)).foregroundStyle(Palette.secondary) }
                .buttonStyle(.plain).disabled(minutes <= 15).accessibilityLabel(language.text("15 minutes less", "15 minutos menos"))
            Text(duration(Double(minutes))).font(.system(size: 17, weight: .semibold, design: .default)).monospacedDigit().frame(minWidth: 66)
            Button { minutes = min(480, minutes + 15) } label: { Image(systemName: "plus.circle.fill").font(.system(size: 23)).foregroundStyle(Palette.mint) }
                .buttonStyle(.plain).disabled(minutes >= 480).accessibilityLabel(language.text("15 minutes more", "15 minutos más"))
        }
    }
}

struct RootView: View {
    @ObservedObject var model: BatteryModel
    @State private var tab = 0
    @State private var emergencyPage = false
    @State private var surfaceVisible = false
    @State private var surfaceID = UUID()
    let openWindow: () -> Void
    let isPopover: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: BrandAssets.logo).resizable().scaledToFit().frame(width: 34, height: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Akku").font(.system(size: 18, weight: .semibold, design: .default))
                    Text(model.t("Your energy. Your companion.", "Tu energía. Tu compañero.")).font(.system(size: 11)).foregroundStyle(Palette.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                LanguageMenu(model: model)
                Menu {
                    if isPopover { Button(model.t("Open window", "Abrir ventana"), action: openWindow) }
                    Button(model.t("Refresh", "Actualizar")) { model.refresh() }
                    Divider()
                    Button(model.t("Quit Akku", "Salir de Akku")) { NSApp.terminate(nil) }.keyboardShortcut("q")
                } label: { Image(systemName: "ellipsis").frame(width: 18, height: 20) }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            }.padding(.horizontal, 20).padding(.vertical, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if surfaceVisible {
                    if let message = model.statusMessage {
                        HStack(alignment: .top) { Detail(text: message); Spacer(); Button { model.statusMessage = nil } label: { Image(systemName: "xmark.circle") }.buttonStyle(.plain).accessibilityLabel(model.t("Dismiss message", "Descartar mensaje")) }.padding(11).background(Palette.amber.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    if emergencyPage { EmergencyPage(model: model) }
                    else {
                        switch tab {
                        case 1: StatisticsHome(model: model)
                        case 2: PlacesPage(model: model)
                        case 3: AppsPage(model: model)
                        case 4: SettingsPage(model: model)
                        default: OverviewPage(model: model, openTrip: { tab = 1 }, openSettings: { tab = 2 })
                        }
                    }
                    }
                }.padding(.horizontal, 20).padding(.bottom, 20).frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 3) {
                tabButton(0, "Akku", "heart")
                tabButton(1, model.t("Statistics", "Estadísticas"), "chart.bar.xaxis")
                tabButton(2, model.t("Places", "Lugares"), "mappin")
                tabButton(3, model.t("Apps", "Apps"), "square.grid.2x2")
                tabButton(4, model.t("Settings", "Ajustes"), "slider.horizontal.3")
            }.padding(5).background(Palette.card).clipShape(RoundedRectangle(cornerRadius: 17)).padding(.horizontal, 16).padding(.vertical, 9)
            Divider().overlay(Palette.line)
            HStack {
                Button { emergencyPage.toggle() } label: {
                    Label(model.emergency ? model.t("Emergency mode on", "Emergencia activa") : model.t("Emergency mode", "Modo de emergencia"), systemImage: "bolt.shield.fill").font(.system(size: 11, weight: .medium)).foregroundStyle(model.emergency ? Palette.mint : Palette.amber)
                }.buttonStyle(.plain)
                Spacer()
                Image(systemName: model.snapshot.connected ? "powerplug.fill" : "battery.75percent").foregroundStyle(Palette.mint)
                Text(model.snapshot.percent.map { "\(Int($0.rounded()))%" } ?? "—").monospacedDigit().font(.system(size: 11, weight: .medium)).accessibilityLabel(model.t("Battery", "Batería") + " " + (model.snapshot.percent.map { "\(Int($0.rounded()))%" } ?? model.t("unavailable", "no disponible")))
            }.padding(.horizontal, 20).padding(.vertical, 10)
        }.frame(minWidth: 380, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity).background(Palette.background).foregroundStyle(Palette.ink).preferredColorScheme(.dark).tint(Palette.mint).environment(\.locale, model.language.locale).font(.system(size: 13))
        .background(WindowVisibilityReader(visible: $surfaceVisible))
        .onChange(of: surfaceVisible) { value in model.setPresentation(surfaceID, visible: value, needsCPU: tab == 3 || emergencyPage) }
        .onChange(of: tab) { _ in model.setPresentation(surfaceID, visible: surfaceVisible, needsCPU: tab == 3 || emergencyPage) }
        .onChange(of: emergencyPage) { _ in model.setPresentation(surfaceID, visible: surfaceVisible, needsCPU: tab == 3 || emergencyPage) }
        .onDisappear { model.setPresentation(surfaceID, visible: false, needsCPU: false) }
        .sheet(isPresented: Binding(get: { model.showWelcome && !isPopover }, set: { if !$0 { model.finishWelcome() } })) { AkkuWelcome(model: model).interactiveDismissDisabled() }
    }
    private func tabButton(_ index: Int, _ title: String, _ icon: String) -> some View {
        Button { tab = index; emergencyPage = false } label: {
            VStack(spacing: 5) { Image(systemName: icon).font(.system(size: 17, weight: .medium)); Text(title).font(.system(size: 10, weight: .medium)).lineLimit(1).minimumScaleFactor(0.75) }.frame(maxWidth: .infinity).padding(.vertical, 10).foregroundStyle(tab == index && !emergencyPage ? Palette.background : Palette.secondary).background(tab == index && !emergencyPage ? Palette.mint : .clear).clipShape(RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
    }
}

struct OverviewPage: View {
    @ObservedObject var model: BatteryModel
    let openTrip: () -> Void
    let openSettings: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if model.departureNotice {
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.t("Heading out?", "¿Has salido?")).font(.system(size: 20, weight: .semibold, design: .default))
                    Detail(text: model.t("I'm recording your battery use automatically. No action needed.", "Estoy registrando tu consumo automáticamente. No necesitas hacer nada."))
                    HStack {
                        Button(model.t("View statistics", "Ver estadísticas")) { model.departureNotice = false; openTrip() }
                        Button(model.t("Not now", "Ahora no")) { model.departureNotice = false; model.location.snoozeDeparture() }
                    }.buttonStyle(.bordered)
                }.panel()
            }
            BuddyHero(model: model)
            Button(action: openTrip) {
                HStack {
                    Image(systemName: "sparkles")
                    Text(model.automaticStatus)
                    Spacer(); Image(systemName: "chart.bar.xaxis")
                }.foregroundStyle(Palette.mint).padding(14).background(Palette.mint.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 14))
            }.buttonStyle(.plain)
            RoutineAutonomyCard(model: model)
            ReturnHomeCard(model: model)
        }
    }
}

struct QuickVerdict: View {
    @ObservedObject var model: BatteryModel
    let items: [TripItem]
    var compact = false
    var body: some View {
        let verdict = model.verdict(items)
        let good = verdict == .comfortable
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: good ? "checkmark.circle.fill" : "powerplug.fill").foregroundStyle(good ? Palette.mint : Palette.amber).font(.system(size: 20))
            VStack(alignment: .leading, spacing: 4) {
                Text(verdict.title(model.language)).font(.system(size: 17, weight: .semibold, design: .default))
                if !compact {
                Detail(text: good ? model.t("Your plan fits even with the conservative estimate and reserve.", "Tu plan cabe incluso con la estimación conservadora y la reserva.") : model.t("Your planned time may use the reserve or outlast the battery.", "El tiempo previsto puede consumir la reserva o superar la batería."))
                }
            }
        }
    }
}

struct AppsPage: View {
    @ObservedObject var model: BatteryModel
    @State private var search = ""
    @State private var includeMenuApps = true
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(model.t("Really running. Right now.", "Abiertas. De verdad.")) .font(.system(size: 26, weight: .semibold, design: .default))
                Spacer()
                Button { model.loadApps() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).accessibilityLabel(model.t("Refresh apps", "Actualizar apps"))
            }
            Detail(text: model.t("Your open apps, as reported by macOS. Includes Safari, FaceTime, ChatGPT, WhatsApp and other installed apps.", "Tus apps abiertas, según macOS. Incluye Safari, FaceTime, ChatGPT, WhatsApp y otras apps instaladas."))
            VStack(alignment: .leading, spacing: 12) {
                Label(model.t("Automatic activity recognition", "Reconocimiento automático de actividad"), systemImage: "waveform.path").fontWeight(.medium)
                Detail(text: model.t("Inferred now: ", "Inferencia actual: ") + (model.currentActivity?.name(model.language) ?? model.t("Not classified", "Sin clasificar")))
                Detail(text: model.t("Akku observes the foreground app automatically. You do not need to describe your activity. Open time and foreground use are shown separately; calls and content are not inspected.", "Akku observa automáticamente la app en primer plano. No necesitas describir tu actividad. Separa tiempo abierta y uso en primer plano; no inspecciona llamadas ni contenido."))
            }.panel()
            DailyAppsCard(model: model)
            ContextCard(model: model)
            TextField(model.t("Search open apps", "Buscar apps abiertas"), text: $search).textFieldStyle(.roundedBorder)
            Toggle(model.t("Include menu-bar apps", "Incluir apps de la barra de menú"), isOn: $includeMenuApps).font(.system(size: 11)).toggleStyle(.switch).controlSize(.small)
            let list = model.nativeApps.apps.filter { app in
                (includeMenuApps || app.application.activationPolicy == .regular) && (search.isEmpty || app.name.localizedCaseInsensitiveContains(search) || app.bundleID.localizedCaseInsensitiveContains(search))
            }
            Detail(text: model.t("\(list.count) apps detected · updates on launch, quit and focus", "\(list.count) apps detectadas · se actualiza al abrir, cerrar y cambiar de app"))
            AppList(model: model, apps: list)
            Detail(text: model.t("CPU is measured for the main process, not all helper processes. 100% means one CPU core. It is not a per-app energy measurement. A dash means unavailable or waiting for a second sample.", "La CPU se mide en el proceso principal, sin sumar todos los auxiliares. El 100% equivale a un núcleo. No es una medición de energía por app. Un guion indica dato no disponible o pendiente de otra muestra."))
        }.onAppear { model.loadApps() }
    }
}

struct AppList: View {
    @ObservedObject var model: BatteryModel
    let apps: [RunningApp]
    @State private var pending: RunningApp?
    var body: some View {
        VStack(spacing: 0) {
            if apps.isEmpty { Detail(text: model.t("No matching open apps.", "No hay apps abiertas que coincidan.")) }
            ForEach(apps) { app in
                HStack(spacing: 10) {
                    if let icon = app.application.icon { Image(nsImage: icon).resizable().frame(width: 29, height: 29).accessibilityHidden(true) }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text(app.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                            if app.foreground { Text(model.t("Active", "Activa")).font(.system(size: 9, weight: .medium)).foregroundStyle(Palette.mint) }
                        }
                        Text(app.bundleID).font(.system(size: 9)).foregroundStyle(Palette.secondary).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer(minLength: 4)
                    Text(app.cpu.map { String(format: "%.0f%%", $0) } ?? "—").font(.system(size: 11, weight: .medium)).monospacedDigit().foregroundStyle((app.cpu ?? 0) > 20 ? Palette.amber : Palette.secondary).accessibilityLabel(model.t("Main process CPU", "CPU del proceso principal") + " " + (app.cpu.map { String(format: "%.0f%%", $0) } ?? model.t("unavailable", "no disponible")))
                    if app.canQuit { Button { pending = app } label: { Image(systemName: "xmark.circle") }.buttonStyle(.plain).foregroundStyle(Palette.secondary).accessibilityLabel(model.t("Request quit", "Solicitar cierre") + " " + app.name) }
                }.padding(.vertical, 11)
                if app.id != apps.last?.id { Divider().overlay(Palette.line) }
            }
        }
        .alert(model.t("Close this app?", "¿Cerrar esta app?"), isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button(model.t("Cancel", "Cancelar"), role: .cancel) { pending = nil }
            Button(model.t("Request quit", "Solicitar cierre")) { if let app = pending { model.quit(app.application) }; pending = nil }
        } message: { Text(model.t("Akku asks \(pending?.name ?? "the app") to quit normally. Save changes if prompted. Closing may end calls or stop uploads.", "Akku solicita a \(pending?.name ?? "la app") un cierre normal. Guarda los cambios si lo pide. Cerrar puede terminar llamadas o detener subidas.")) }
    }
}

struct SettingsPage: View {
    @ObservedObject var model: BatteryModel
    @State private var eraseLearning = false
    @State private var eraseHome = false
    @State private var replaceHome = false
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text(model.t("Built around your Mac.", "A la medida de tu Mac.")) .font(.system(size: 26, weight: .semibold, design: .default))
            VStack(alignment: .leading, spacing: 10) {
                Label(model.hardware.name, systemImage: "laptopcomputer").font(.system(size: 14, weight: .semibold))
                Detail(text: "\(model.hardware.chip) · \(model.hardware.identifier)")
                Detail(text: model.hardware.supported ? model.t("Recognized model. Learning is specific to this Mac's real battery, workload and wear.", "Modelo reconocido. El aprendizaje se adapta a la batería real, el uso y el desgaste de este Mac.") : model.t("Unlisted model. Battery features are available when macOS exposes them; validate on this hardware.", "Modelo no incluido en el catálogo. Las funciones dependen de los datos que exponga macOS; requiere validación en este equipo."))
                Detail(text: model.t("This release is intended for MacBook Air and Pro with M1–M5, including Pro/Max variants. Only a MacBook Air M5 has been physically tested; other models need validation.", "Esta versión está destinada a MacBook Air y Pro con M1–M5, incluidas variantes Pro/Max. Solo se ha probado físicamente en un MacBook Air M5; los demás modelos necesitan validación."))
            }.panel()
            VStack(alignment: .leading, spacing: 14) {
                Picker(model.t("Language", "Idioma"), selection: $model.language) { ForEach(Language.allCases, id: \.self) { Text($0.displayName).tag($0) } }
                Divider()
                HStack { Text(model.t("Battery reserve", "Reserva de batería")); Spacer(); Text("\(Int(model.reserve))%").foregroundStyle(Palette.mint).monospacedDigit() }
                Slider(value: $model.reserve, in: 5...30, step: 5).tint(Palette.mint).accessibilityLabel(model.t("Battery reserve", "Reserva de batería"))
                Detail(text: model.t("Used for return-home advice. Your full-charge routine estimate does not deduct this reserve.", "Se usa al aconsejarte sobre el regreso a casa. La estimación de tu rutina con carga completa no descuenta esta reserva."))
                HStack { Text(model.t("Starting baseline", "Autonomía base inicial")); Spacer(); Text(String(format: "%.1fh", model.baseline)).foregroundStyle(Palette.mint) }
                Slider(value: $model.baseline, in: 3...24, step: 0.5).tint(Palette.mint).accessibilityLabel(model.t("Full-charge browsing hours", "Horas de navegación con carga completa"))
                Detail(text: model.t("Initial browsing assumption for return-home advice, replaced as activity data grows. Your daily-routine estimate uses only observed consumption.", "Supuesto inicial de navegación para aconsejarte sobre el regreso; se reemplaza al aprender de cada actividad. La estimación de tu rutina diaria usa solo consumo observado."))
            }.panel()
            CompanionSettings(model: model)
            learningCard
            VStack(alignment: .leading, spacing: 14) {
                Label(model.t("Sleep is excluded automatically", "El reposo se excluye automáticamente"), systemImage: "moon.zzz")
                Detail(text: model.t("Recording resumes on wake. If the app was closed, missing time and discharge are excluded.", "El registro se reanuda al despertar. Si la app estuvo cerrada, se excluyen el tiempo y consumo sin observar."))
                Toggle(model.t("Animate my buddy", "Animar a mi compañero"), isOn: $model.animateBuddy).toggleStyle(.switch)
                Detail(text: model.t("Akku animates when shown and when its mood changes, then briefly every 20 seconds. Pauses when hidden, in Low Power Mode, Emergency mode or Reduce Motion.", "Akku se anima al aparecer y al cambiar de estado; después, brevemente cada 20 segundos. Se pausa al ocultarse, con Bajo consumo, Emergencia o Reducir movimiento."))
            }.panel()
            ValidationCard(model: model)
            VStack(alignment: .leading, spacing: 13) {
                Toggle(model.t("Gentle leaving-home alerts", "Avisos discretos al salir de casa"), isOn: Binding(get: { model.alerts.enabled }, set: { model.alerts.setEnabled($0) })).toggleStyle(.switch)
                Detail(text: model.t("Optional, silent departure notices. Recording and statistics work even with notifications off.", "Avisos opcionales y silenciosos al salir. El registro y las estadísticas funcionan aunque desactives las notificaciones."))
                if model.alerts.enabled && !model.alerts.allowed {
                    Detail(text: model.t("Notifications are not authorized in macOS yet. In-app warnings still work.", "macOS aún no autorizó las notificaciones. Los avisos dentro de la app siguen funcionando."))
                    Button(model.t("Open notification settings", "Abrir ajustes de notificaciones")) { model.openSettings("com.apple.preference.notifications") }.buttonStyle(.bordered)
                }
                if model.alerts.issue { Detail(text: model.t("macOS couldn't authorize or deliver a notification. Review its settings.", "macOS no pudo autorizar o entregar una notificación. Revisa sus ajustes.")) }
                Divider()
                Toggle(model.t("Launch at login", "Abrir al iniciar sesión"), isOn: Binding(get: { model.login.enabled }, set: { model.login.setEnabled($0) })).toggleStyle(.switch)
                Detail(text: model.t("Keep the app in Applications before enabling. Login launches quietly in the menu bar.", "Guarda la app en Aplicaciones antes de activarlo. Al iniciar sesión aparece discretamente en la barra de menú."))
                if model.login.failed || model.login.status == .requiresApproval {
                    Detail(text: model.t("macOS approval or a properly signed installation is required.", "Hace falta aprobación de macOS o una instalación con firma válida."))
                    Button(model.t("Open login items", "Abrir ítems de inicio")) { model.login.openSettings() }.buttonStyle(.bordered)
                }
            }.panel()
            Detail(text: model.t("Everything is kept on this Mac: up to 400 discharge intervals (60 days), 400 charging intervals (30 days), 400 automatic sessions (60 days), previous planned results and 30 frequent places. Battery charts retain up to 11 days of compact observations to display 10 days. No account, analytics, messages or browsing contents. Exports include app identifiers, never coordinates.", "Todo queda en este Mac: hasta 400 intervalos de descarga (60 días), 400 de carga (30 días), 400 sesiones automáticas (60 días), resultados de planes anteriores y 30 lugares frecuentes. Los gráficos de batería conservan hasta 11 días de observaciones compactas para mostrar 10 días. Sin cuenta, analíticas, mensajes ni contenido de navegación. Al exportar se incluyen identificadores de apps, nunca coordenadas."))
            Text("AKKU  /  " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "7.0.0")).font(.system(size: 10, weight: .medium)).tracking(1.5).foregroundStyle(Palette.secondary)
        }
        .alert(model.t("Reset learning?", "¿Borrar el aprendizaje?"), isPresented: $eraseLearning) {
            Button(model.t("Cancel", "Cancelar"), role: .cancel) {}
            Button(model.t("Delete observations", "Borrar observaciones"), role: .destructive) { model.clearLearning() }
        } message: { Text(model.t("Estimates will return to the starting baseline. Routines and your home stay saved.", "Las estimaciones volverán a la autonomía inicial. Se conservan tus rutinas y tu casa.")) }
        .alert(model.t("Forget your home?", "¿Olvidar tu casa?"), isPresented: $eraseHome) {
            Button(model.t("Cancel", "Cancelar"), role: .cancel) {}
            Button(model.t("Forget", "Olvidar"), role: .destructive) { model.location.forgetHome() }
        }
        .alert(model.t("Use this location as home?", "¿Usar esta ubicación como casa?"), isPresented: $replaceHome) {
            Button(model.t("Cancel", "Cancelar"), role: .cancel) {}
            Button(model.t("Save home", "Guardar casa")) { _ = model.location.saveHome() }
        } message: { Text(model.t("Only choose this while physically at home. It replaces any saved home location.", "Elige esto solo cuando estés físicamente en casa. Reemplaza cualquier ubicación de casa guardada.")) }
    }
    private var learningCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(model.t("Learn from battery use", "Aprender del consumo de batería"), isOn: $model.learningEnabled).toggleStyle(.switch)
            Text(model.learningStatus).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.mint)
            Detail(text: model.t("\(model.samples.count) intervals · \(duration(model.observedMinutes)) of real discharge", "\(model.samples.count) intervalos · \(duration(model.observedMinutes)) de descarga real"))
            Detail(text: model.t("Requires awake, unplugged intervals of 10–45 minutes with a measurable drop. Charging, sleep and interrupted readings are excluded. High confidence needs consistent data across several days and confirmed activities. Ranges are practical uncertainty bands, not statistical guarantees.", "Necesita intervalos de 10–45 minutos despierto, sin cargador y con una caída medible. Excluye carga, reposo y lecturas interrumpidas. La confianza alta requiere datos estables de varios días y actividades confirmadas. Los rangos son márgenes orientativos, no garantías estadísticas."))
            Button(model.t("Reset learning…", "Borrar aprendizaje…")) { eraseLearning = true }.buttonStyle(.bordered).disabled(model.samples.isEmpty && model.outcomes.isEmpty && model.chargeSamples.isEmpty && model.automaticArchive.completed.isEmpty && model.automaticArchive.active == nil)
        }.panel()
    }

}

struct EmergencyPage: View {
    @ObservedObject var model: BatteryModel
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text(model.t("Every minute matters.", "Cada minuto cuenta.")) .font(.system(size: 27, weight: .semibold, design: .default))
            Detail(text: model.t("See what changed, what needs your help, and what can be undone. Savings are never guaranteed.", "Mira qué cambió, qué necesita tu ayuda y qué puedes deshacer. El ahorro nunca está garantizado."))
            PrimaryButton(title: model.emergency ? model.t("Undo automatic changes", "Deshacer cambios automáticos") : model.t("Activate emergency mode", "Activar modo de emergencia"), icon: model.emergency ? "arrow.uturn.backward" : "bolt.shield.fill") { model.toggleEmergency() }
            VStack(alignment: .leading, spacing: 16) {
                status("sun.min", model.t("Screen brightness", "Brillo de pantalla"), model.dimmed ? model.t("Applied", "Aplicado") : model.t("Manual / compatible displays", "Manual / pantallas compatibles"), model.dimmed ? model.t("Reduced to 35% or lower. Undo restores the previous value.", "Reducido al 35% o menos. Deshacer restaura el valor anterior.") : model.t("Automatic dimming is attempted on compatible displays. Otherwise use Displays.", "Se intenta reducir automáticamente en pantallas compatibles. En las demás, usa Pantallas."), model.dimmed)
                if !model.dimmed { Button(model.t("Open Displays", "Abrir Pantallas")) { model.openSettings("com.apple.preference.displays") }.buttonStyle(.bordered) }
                if model.restoreFailed { Detail(text: model.t("Restoration failed. Adjust brightness in Displays.", "Falló la restauración. Ajusta el brillo en Pantallas.")) }
                Divider()
                status("timer", model.t("Akku polling", "Consultas de Akku"), model.emergency ? model.t("Applied", "Aplicado") : model.t("Ready", "Listo"), model.emergency ? model.t("Checks once a minute. Hidden Akku already uses this reduced rate.", "Consulta una vez por minuto. Akku oculta ya utiliza esta frecuencia reducida.") : model.t("Reduces this app's own background checks.", "Reduce las consultas en segundo plano de esta app."), model.emergency)
                Divider()
                status("leaf", model.t("Low Power Mode", "Modo de bajo consumo"), model.lowPower ? model.t("Enabled in macOS", "Activo en macOS") : model.t("Manual", "Manual"), model.t("Managed in Battery settings. Undo does not change a setting you enabled yourself.", "Se gestiona en Batería. Deshacer no cambia un ajuste que activaste por tu cuenta."), model.lowPower)
                Button(model.t("Open Battery", "Abrir Batería")) { model.openSettings("com.apple.preference.battery") }.buttonStyle(.bordered)
                Divider()
                status("arrow.triangle.2.circlepath", model.t("Cloud sync & uploads", "Sincronización y subidas"), model.t("Manual", "Manual"), model.t("Pause them from each app's menu. Akku does not claim they were paused.", "Páusalas desde el menú de cada app. Akku no afirma haberlas pausado."), false)
            }.panel()
            if !model.closedApps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.t("Apps closed from Akku", "Apps cerradas desde Akku")).fontWeight(.medium)
                    ForEach(model.closedApps) { item in HStack { Text(item.name); Spacer(); Button(model.t("Reopen", "Reabrir")) { model.reopen(item) }.buttonStyle(.bordered) } }
                    Detail(text: model.t("Reopening doesn't restore unsaved work or reconnect a call.", "Reabrir no recupera trabajo sin guardar ni reconecta una llamada."))
                }.panel()
            }
            Text(model.t("Review open apps", "Revisar apps abiertas")).font(.system(size: 16, weight: .semibold))
            Detail(text: model.t("Highest observed main-process CPU first. Close only what you don't need. Each request asks for confirmation.", "Primero, la mayor CPU observada en el proceso principal. Cierra solo lo que no necesites. Cada solicitud pide confirmación."))
            AppList(model: model, apps: model.nativeApps.apps.filter(\.canQuit).sorted { ($0.cpu ?? -1) > ($1.cpu ?? -1) })
        }.onAppear { model.refresh() }
    }
    private func status(_ icon: String, _ title: String, _ state: String, _ detail: String, _ applied: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(applied ? Palette.mint : Palette.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(state).font(.system(size: 10, weight: .semibold)).foregroundStyle(applied ? Palette.mint : Palette.amber)
                Detail(text: detail)
            }
        }
    }
}
