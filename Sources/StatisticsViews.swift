import SwiftUI

struct StatisticsPage: View {
    @ObservedObject var model: BatteryModel
    @State private var history = false
    private var stats: WeeklyStatistics { model.weeklyStatistics }
    private var recentSamples: [DischargeSample] {
        let start = stats.days.first?.day ?? model.contextDate
        return model.samples.filter { $0.valid && $0.date >= start && $0.date <= model.contextDate }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.t("Your week, understood.", "Tu semana, a tu manera.")).font(.system(size: 27, weight: .semibold, design: .default))
                    Detail(text: model.t("LAST 7 DAYS · UPDATED AUTOMATICALLY", "ÚLTIMOS 7 DÍAS · ACTUALIZACIÓN AUTOMÁTICA"))
                }
                Spacer(minLength: 8)
                Image(systemName: "chart.bar.xaxis").font(.system(size: 27)).foregroundStyle(Palette.mint).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 12) {
                Label(model.automaticStatus, systemImage: model.learningEnabled ? "sparkles" : "pause.circle").fontWeight(.semibold).foregroundStyle(Palette.mint)
                Detail(text: model.t("Unplug or leave home: Akku takes care of recording. No start button. Charging closes the session after one minute; sleep and missing readings are excluded.", "Desconecta el cargador o sal de casa: Akku se ocupa del registro. Sin botón de inicio. Al conectar el cargador, cierra la sesión tras un minuto; excluye el reposo y las lecturas ausentes."))
                if let active = model.automaticArchive.active {
                    HStack {
                        Text(model.t("Current session", "Sesión actual")).font(.system(size: 12))
                        Spacer()
                        Text(duration(active.minutes)).font(.system(size: 19, weight: .semibold, design: .default)).monospacedDigit()
                    }
                    Detail(text: trigger(active))
                }
                if !model.login.enabled {
                    Detail(text: model.t("I learn while Akku is running. Enable Launch at login in Settings to keep it available each day.", "Aprendo mientras Akku está abierta. Activa «Abrir al iniciar sesión» en Ajustes para tenerla disponible cada día."))
                }
            }.panel()
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    metric(duration(stats.minutes), model.t("observed on battery", "observados con batería"))
                    Spacer()
                    metric(String(format: "%.0f pp", stats.drop), model.t("charge consumed", "de carga consumidos"))
                }
                HStack { Detail(text: model.t("\(stats.sessions.count) sessions · \(stats.observedDays) days with ≥10 min", "\(stats.sessions.count) sesiones · \(stats.observedDays) días con ≥10 min")); Spacer() }
                chart
                Detail(text: model.t("pp = percentage points, summed across sessions. These may exceed 100 after recharging. Awake battery time can include unattended work.", "pp = puntos porcentuales, sumados entre sesiones. Pueden superar 100 tras recargar. El tiempo despierto con batería puede incluir trabajo sin interacción."))
            }.panel()
            VStack(alignment: .leading, spacing: 12) {
                Label(model.t("What I'm learning about you", "Lo que aprendo de ti"), systemImage: "leaf").font(.system(size: 17, weight: .semibold, design: .default))
                if stats.enoughForPattern {
                    let typical = stats.days.filter { $0.minutes >= 10 }.reduce(0) { $0 + $1.minutes } / Double(max(1, stats.observedDays))
                    Text(model.t("About \(duration(typical)) on battery per observed day.", "Unos \(duration(typical)) con batería por día observado.")).font(.system(size: 18, weight: .semibold, design: .default))
                    Detail(text: model.t("Based on \(stats.observedDays) days this week. This describes observed use, not a guarantee of runtime.", "Basado en \(stats.observedDays) días de esta semana. Describe el uso observado; no garantiza una autonomía."))
                } else {
                    Text(model.t("Getting to know your rhythm", "Conociendo tu ritmo")).font(.system(size: 18, weight: .semibold, design: .default))
                    Detail(text: model.t("\(stats.observedDays) of 3 days · \(Int(stats.minutes)) of 90 minutes needed for a first pattern. Each day needs at least 10 observed minutes. No action needed.", "\(min(3, stats.observedDays)) de 3 días · \(min(90, Int(stats.minutes))) de 90 minutos para un primer patrón. Cada día necesita al menos 10 minutos observados. No necesitas hacer nada."))
                }
                Detail(text: model.t("The weekly summary updates as readings arrive. I don't wait a week to learn, and I don't send weekly pop-ups.", "El resumen semanal se actualiza al llegar nuevas lecturas. No espero una semana para aprender ni envío ventanas emergentes semanales."))
            }.panel()
            DailyAppsCard(model: model)
            locationBreakdown
            activityPatterns
            if !model.automaticArchive.completed.isEmpty {
                DisclosureGroup(model.t("Automatically recorded sessions", "Sesiones registradas automáticamente"), isExpanded: $history) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(model.automaticArchive.completed.suffix(12).reversed())) { session in
                            Divider()
                            HStack { Text(session.startedAt, style: .date); Spacer(); Text(duration(session.minutes)).monospacedDigit() }.fontWeight(.medium)
                            Detail(text: trigger(session) + " · " + String(format: "%.0f pp", session.drop))
                            if session.interrupted { Detail(text: model.t("Includes pauses or gaps; only observed intervals are counted.", "Incluye pausas o interrupciones; se cuentan solo los intervalos observados.")) }
                        }
                    }.padding(.top, 12)
                }.tint(Palette.mint).panel()
            }
            if !model.outcomes.isEmpty {
                DisclosureGroup(model.t("Previous planned-session comparisons", "Comparaciones de los planes anteriores")) { HistoryCard(model: model).padding(.top, 12) }.tint(Palette.mint)
            }
            Detail(text: model.t("Local statistics, specific to this Mac. No location permission? Battery learning still works; places stay unknown. A manual location never claims an automatic departure.", "Estadísticas locales de este Mac. Sin permiso de ubicación, el aprendizaje de batería sigue funcionando y los lugares quedan desconocidos. Una posición manual no se presenta como una salida detectada."))
        }
    }
    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.system(size: 29, weight: .semibold, design: .default)).foregroundStyle(Palette.mint).minimumScaleFactor(0.7).lineLimit(1)
            Detail(text: label)
        }
    }
    private var chart: some View {
        let peak = max(60, stats.days.map(\.minutes).max() ?? 0)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(stats.days) { day in
                VStack(spacing: 8) {
                    Text(day.minutes > 0 ? duration(day.minutes) : "—").font(.system(size: 9)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                    RoundedRectangle(cornerRadius: 6).fill(day.minutes > 0 ? Palette.mint.opacity(0.8) : Palette.line)
                        .frame(height: max(4, 76 * day.minutes / peak))
                    Text(dayLabel(day.day)).font(.system(size: 10)).foregroundStyle(Palette.secondary)
                }.frame(maxWidth: .infinity).accessibilityElement(children: .ignore).accessibilityLabel(day.day.formatted(date: .complete, time: .omitted) + ": " + duration(day.minutes))
            }
        }.frame(height: 118, alignment: .bottom)
    }
    private var locationBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(model.t("Where you use your battery", "Dónde usas tu batería"), systemImage: "house.and.flag").font(.system(size: 17, weight: .semibold, design: .default))
            placeRow(model.t("At home", "En casa"), stats.homeMinutes)
            placeRow(model.t("Away from home", "Fuera de casa"), stats.awayMinutes)
            placeRow(model.t("Location unknown", "Sin ubicación confirmada"), stats.unknownMinutes)
            Detail(text: model.t("Only automatic, recent locations are used here. No route is stored. Changing or uncertain locations count as unknown.", "Aquí solo se usan posiciones automáticas y recientes. No se guarda el recorrido. Los cambios de lugar o ubicaciones inciertas cuentan como desconocidos."))
        }.panel()
    }
    private func placeRow(_ name: String, _ minutes: Double) -> some View {
        HStack { Text(name); Spacer(); Text(duration(minutes)).monospacedDigit().foregroundStyle(Palette.mint) }
    }
    private var activityPatterns: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(model.t("Observed activity patterns", "Patrones de actividad observados"), systemImage: "square.grid.2x2").font(.system(size: 17, weight: .semibold, design: .default))
            if recentSamples.isEmpty {
                Detail(text: model.t("Rates will appear after measurable, uninterrupted battery intervals. Keep using your Mac as usual.", "Los ritmos de consumo aparecerán tras intervalos de batería medibles y continuos. Sigue usando tu Mac normalmente."))
            }
            ForEach(Activity.allCases) { activity in
                let values = recentSamples.filter { $0.activity == activity }
                let minutes = values.reduce(0) { $0 + $1.minutes }
                if !values.isEmpty {
                    HStack {
                        Label(activity.name(model.language), systemImage: activity.symbol)
                        Spacer()
                        Text(duration(minutes)).monospacedDigit().foregroundStyle(Palette.mint)
                    }
                    if values.count >= 3 && minutes >= 45 {
                        Detail(text: model.t("Observed Mac consumption: ", "Consumo observado del Mac: ") + String(format: "%.1f pp/h", values.reduce(0) { $0 + $1.drop } / minutes * 60))
                    } else { Detail(text: model.t("Few observations · collecting more data", "Pocas observaciones · reuniendo más datos")) }
                }
            }
            Detail(text: model.t("Activities are inferred automatically from the foreground app. An open FaceTime app doesn't prove a call is active. Rates describe the whole Mac, not each app's exact energy.", "Las actividades se infieren automáticamente de la app en primer plano. FaceTime abierto no demuestra una llamada activa. Los ritmos describen el Mac completo, no la energía exacta de cada app."))
            ContextCard(model: model)
        }.panel()
    }
    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = model.language.locale; f.dateFormat = "EE"; return f.string(from: date)
    }
    private func trigger(_ session: AutomaticSession) -> String {
        if session.leftHome { return model.t("Departure from home detected", "Salida de casa detectada") }
        return session.trigger == "unplugged" ? model.t("Charger disconnected", "Cargador desconectado") : model.t("Found the Mac running on battery", "Mac detectado funcionando con batería")
    }
}
