import SwiftUI

struct StatisticsHome: View {
    @ObservedObject var model: BatteryModel
    @State private var section = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker(model.t("Statistics view", "Vista de estadísticas"), selection: $section) {
                Text(model.t("Battery", "Batería")).tag(0)
                Text(model.t("Your habits", "Tus hábitos")).tag(1)
            }.pickerStyle(.segmented).labelsHidden()
            if section == 0 { BatteryPanel(model: model) }
            else { StatisticsPage(model: model) }
        }
    }
}

struct BatteryPanel: View {
    @ObservedObject var model: BatteryModel
    @State private var period = BatteryHistoryPeriod.hours24
    @State private var selected: Date?
    private var status: String {
        if model.snapshot.percent == nil { return model.t("Battery data unavailable", "Datos de batería no disponibles") }
        if model.snapshot.charging { return model.t("Charging", "Cargando") }
        if model.snapshot.connected { return model.t("Connected · not charging", "Conectado · sin cargar") }
        return model.t("Running on battery", "Funcionando con batería")
    }
    var body: some View {
        let summary = BatteryHistorySummary(archive: model.batteryHistory, period: period, now: model.contextDate)
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(model.t("Your battery, over time.", "Tu batería, a lo largo del día.")).font(.system(size: 24, weight: .semibold, design: .default))
                    Label(status, systemImage: model.snapshot.charging ? "bolt.fill" : model.snapshot.connected ? "powerplug.fill" : "battery.75percent").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                }
                Spacer(minLength: 12)
                Text(model.snapshot.percent.map { "\(Int($0.rounded()))%" } ?? "—").font(.system(size: 32, weight: .semibold, design: .default)).monospacedDigit().foregroundStyle(Palette.mint)
            }
            VStack(spacing: 13) {
                infoRow(model.t("Low Power Mode", "Modo de bajo consumo"), model.lowPower ? model.t("On", "Activado") : model.t("Off", "Desactivado"), "leaf")
                Divider()
                infoRow(model.t("Battery condition", "Condición de la batería"), health, "heart")
                Divider()
                HStack {
                    Text(model.t("Charging", "Recarga"))
                    Spacer()
                    Button(model.t("Manage in macOS", "Gestionar en macOS")) { model.openSettings("com.apple.preference.battery") }.buttonStyle(.link)
                }
            }.font(.system(size: 12)).panel()
            VStack(alignment: .leading, spacing: 17) {
                Picker(model.t("Battery history period", "Período del historial de batería"), selection: $period) {
                    Text(model.t("Last 24 hours", "Últimas 24 horas")).tag(BatteryHistoryPeriod.hours24)
                    Text(model.t("Last 10 days", "Últimos 10 días")).tag(BatteryHistoryPeriod.days10)
                }.pickerStyle(.segmented).labelsHidden().onChange(of: period) { _ in selected = nil }
                HStack {
                    Label(model.learningEnabled ? (summary.observedSeconds < 3600 ? model.t("First readings · building your history", "Primeras lecturas · creando tu historial") : model.t("Recorded automatically", "Registro automático")) : model.t("Recording paused", "Registro pausado"), systemImage: model.learningEnabled ? "clock.arrow.circlepath" : "pause.circle").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    Spacer()
                    Text(model.contextDate, style: .time).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }
                Divider()
                Text(model.t("Battery level", "Nivel de batería")).font(.system(size: 15, weight: .semibold))
                EnergyHistoryChart(columns: summary.levels, start: summary.start, end: summary.end, battery: true, daily: period == .days10, language: model.language, selected: selection(summary), select: { select($0, summary) })
                    .frame(height: 171)
                HStack(spacing: 14) {
                    legend(.green, model.t("Level", "Nivel"), "circle.fill")
                    legend(.green, model.t("Charging", "Cargando"), "bolt.fill")
                    legend(Palette.secondary, model.t("Connected", "Conectado"), "powerplug.fill")
                }
                Divider()
                Text(model.t("Screen-on use", "Uso con pantalla encendida")).font(.system(size: 15, weight: .semibold))
                EnergyHistoryChart(columns: summary.usage, start: summary.start, end: summary.end, battery: false, daily: period == .days10, language: model.language, selected: selection(summary), select: { select($0, summary) })
                    .frame(height: 157)
                HStack(alignment: .top) {
                    total(time(summary.screenSeconds), model.t("screen on", "pantalla encendida"))
                    Spacer(minLength: 10)
                    total(time(summary.connectedSeconds), model.t("connected", "conectado"))
                }
                if summary.levels.allSatisfy({ $0.level == nil }) {
                    Label(model.t("Your history starts here.", "Tu historial empieza aquí."), systemImage: "sparkles").fontWeight(.medium)
                    Detail(text: model.t("Keep using your Mac. Readings will appear automatically; earlier hours stay empty.", "Sigue usando tu Mac. Las lecturas aparecerán automáticamente; las horas anteriores quedan vacías."))
                }
                if let first = summary.usage.first {
                    Picker(model.t("Inspect an interval", "Consultar un intervalo"), selection: Binding(get: { selected ?? summary.usage.last?.start ?? first.start }, set: { selected = $0 })) {
                        ForEach(summary.usage) { column in Text(intervalLabel(column)).tag(column.start) }
                    }.font(.system(size: 11))
                    if let column = selection(summary) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(intervalLabel(column)).font(.system(size: 11, weight: .semibold))
                            Detail(text: column.level.map { model.t("Observed level: ", "Nivel observado: ") + String(format: "%.0f–%.0f%%", column.minimum ?? $0, column.maximum ?? $0) } ?? model.t("No battery reading in this interval.", "Sin lecturas de batería en este intervalo."))
                            Detail(text: column.observed > 0 ? model.t("Screen on: ", "Pantalla encendida: ") + time(column.screen) + " · " + model.t("Observed: ", "Observado: ") + time(column.observed) : model.t("No continuous time recorded.", "Sin tiempo continuo registrado."))
                        }.padding(11).frame(maxWidth: .infinity, alignment: .leading).background(Palette.peach).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                Detail(text: model.t("Blank areas mean no observations. Levels use 5-minute groups; 10 days shows their daily average and range. Time is approximate and counts only intervals observed by Akku, including use while plugged in. An awake screen doesn't prove attention. Sleep, app closure and gaps are excluded.", "Los espacios vacíos indican falta de observaciones. El nivel se agrupa cada 5 minutos; en 10 días muestra su media diaria y rango. El tiempo es aproximado y cuenta solo intervalos observados por Akku, también con cargador. Una pantalla encendida no demuestra atención. Se excluyen reposo, cierre de la app e interrupciones."))
            }.panel()
            Detail(text: model.t("Stored locally for 10 days of display. Uses the existing battery readings, with no extra timer. Charging limits and system settings are managed by macOS.", "Historial local para mostrar 10 días. Usa las lecturas de batería existentes, sin un temporizador adicional. Los límites de carga y ajustes del sistema se gestionan en macOS."))
        }
    }
    private func time(_ seconds: Double) -> String {
        guard seconds > 0 else { return "0 min" }
        if seconds < 60 { return "<1 min" }
        let minutes = Int(seconds / 60)
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }
    private var health: String {
        switch model.snapshot.health {
        case "Good": return model.t("Normal", "Normal")
        case "Fair": return model.t("Limited capacity", "Capacidad reducida")
        case "Poor", "Check Battery", "Permanent Battery Failure": return model.t("Service recommended", "Revisión recomendada")
        default: return model.t("Not reported", "No informada")
        }
    }
    private func infoRow(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack { Text(title); Spacer(minLength: 10); Text(value).foregroundStyle(Palette.secondary); Image(systemName: symbol).foregroundStyle(Palette.secondary).accessibilityHidden(true) }
    }
    private func total(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) { Text(value).font(.system(size: 22, weight: .semibold, design: .default)).monospacedDigit(); Detail(text: title) }
    }
    private func legend(_ color: Color, _ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol).font(.system(size: 10)).foregroundStyle(color == .green ? Palette.mint : color)
    }
    private func selection(_ summary: BatteryHistorySummary) -> BatteryHistoryColumn? {
        summary.usage.first { $0.start == selected } ?? summary.usage.last
    }
    private func select(_ date: Date, _ summary: BatteryHistorySummary) {
        selected = summary.usage.first { date >= $0.start && date <= $0.end }?.start
    }
    private func intervalLabel(_ column: BatteryHistoryColumn) -> String {
        let f = DateFormatter(); f.locale = model.language.locale
        f.dateFormat = period == .days10 ? "EEE d MMM" : "d MMM · HH:mm"
        let start = f.string(from: column.start)
        if period == .days10 { return start }
        f.dateFormat = "HH:mm"; return start + "–" + f.string(from: column.end)
    }
}

// Static Canvas: no animation, display link, network request or per-bar view tree.
struct EnergyHistoryChart: View {
    let columns: [BatteryHistoryColumn]
    let start: Date
    let end: Date
    let battery: Bool
    let daily: Bool
    let language: Language
    let selected: BatteryHistoryColumn?
    let select: (Date) -> Void
    private var ceiling: Double { battery ? 100 : daily ? max(4, ceil((columns.map { $0.screen / 3600 }.max() ?? 0) / 4) * 4) : 60 }
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let width = max(1, size.width - 43), height = size.height - 41
                context.translateBy(x: 0, y: 7)
                let span = max(1, end.timeIntervalSince(start))
                func x(_ date: Date) -> Double { max(0, min(width, date.timeIntervalSince(start) / span * width)) }
                if let selected {
                    context.fill(Path(CGRect(x: x(selected.start), y: 0, width: max(1, x(selected.end) - x(selected.start)), height: height)), with: .color(Palette.mint.opacity(0.06)))
                }
                for fraction in [0.0, 0.5, 1.0] {
                    let y = height * (1 - fraction)
                    var line = Path(); line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: width, y: y))
                    context.stroke(line, with: .color(Palette.line), lineWidth: 0.7)
                    let unit = battery ? "%" : daily ? " h" : " min"
                    context.draw(Text("\(Int(ceiling * fraction))" + unit).font(.system(size: 9)).foregroundColor(Palette.secondary), at: CGPoint(x: width + 5, y: y), anchor: .leading)
                }
                let green = Color(red: 0.18, green: 0.74, blue: 0.35), blue = Color(red: 0.12, green: 0.52, blue: 0.94)
                for column in columns {
                    let left = x(column.start), right = x(column.end), width = max(1, right - left - (daily || !battery ? 3 : 1))
                    let value = battery ? column.level : (column.observed > 0 ? column.screen / (daily ? 3600 : 60) : nil)
                    if let value {
                        let barHeight = height * min(1, max(0, value / ceiling))
                        context.fill(Path(roundedRect: CGRect(x: left, y: height - max(1, barHeight), width: width, height: max(1, barHeight)), cornerRadius: min(3, width / 2)), with: .color(battery ? green : blue))
                        if battery && daily, let lo = column.minimum, let hi = column.maximum {
                            var range = Path(); range.move(to: CGPoint(x: left + width / 2, y: height * (1 - hi / 100))); range.addLine(to: CGPoint(x: left + width / 2, y: height * (1 - lo / 100)))
                            context.stroke(range, with: .color(Palette.mint), lineWidth: 2)
                        }
                    }
                    if battery && column.connected > 0 {
                        context.fill(Path(roundedRect: CGRect(x: left, y: height + 5, width: width, height: 3), cornerRadius: 1.5), with: .color(Palette.secondary.opacity(0.5)))
                        if column.charging > 0 { context.fill(Path(CGRect(x: left, y: height + 5, width: width * min(1, column.charging / max(1, column.observed)), height: 3)), with: .color(green)) }
                    }
                }
                let formatter = DateFormatter(); formatter.locale = language.locale; formatter.dateFormat = daily ? "d MMM" : "HH:mm"
                for tick in 0...4 {
                    let fraction = Double(tick) / 4
                    let date = start.addingTimeInterval(span * fraction)
                    context.draw(Text(formatter.string(from: date)).font(.system(size: 9)).foregroundColor(Palette.secondary), at: CGPoint(x: fraction * width, y: height + 22), anchor: tick == 0 ? .leading : tick == 4 ? .trailing : .center)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let fraction = max(0, min(1, value.location.x / max(1, geometry.size.width - 43)))
                select(start.addingTimeInterval(end.timeIntervalSince(start) * fraction))
            })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(language.text(battery ? "Battery level history" : "Screen-on history", battery ? "Historial del nivel de batería" : "Historial de pantalla encendida"))
            .accessibilityHint(language.text("Use Inspect an interval below for exact readings.", "Usa Consultar un intervalo debajo para leer los valores."))
        }
    }
}
