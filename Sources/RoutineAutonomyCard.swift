import SwiftUI

struct RoutineAutonomyCard: View {
    @ObservedObject var model: BatteryModel
    var body: some View {
        let routine = model.routineAutonomy
        VStack(alignment: .leading, spacing: 14) {
            Label(model.t("A full charge, your routine", "Una carga completa, tu rutina"), systemImage: "battery.100percent")
                .font(.system(size: 21, weight: .semibold))
            if let estimate = routine.estimate {
                Text(estimate.range).font(.system(size: 30, weight: .medium)).monospacedDigit()
                    .foregroundStyle(Palette.mint).fixedSize(horizontal: false, vertical: true)
                Text(estimate.confidence.name(model.language)).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.secondary)
                Detail(text: model.t("With the mix of apps and habits observed over \(routine.observedDays) days · \(duration(routine.minutes)) on battery.", "Con la combinación de apps y hábitos observada durante \(routine.observedDays) días · \(duration(routine.minutes)) con batería."))
                Detail(text: model.t("100% to 0% · awake use. Charging and sleep are excluded; your safety reserve is not deducted.", "Del 100% al 0% · uso con el Mac despierto. Excluye carga y reposo; no descuenta tu reserva de seguridad."))
                Detail(text: model.t("Based on the last 7 days. A different workload or accessories can change this range.", "Basado en los últimos 7 días. Otra carga de trabajo o accesorios pueden cambiar este rango."))
            } else {
                Text(model.t("I'm learning your daily rhythm", "Estoy aprendiendo tu ritmo diario"))
                    .font(.system(size: 20, weight: .medium)).foregroundStyle(Palette.mint)
                Detail(text: model.t("Use your Mac as usual. I'll estimate full-charge battery life from your real consumption, without asking you to choose activities.", "Usa tu Mac como siempre. Estimaré la duración de una carga completa con tu consumo real, sin pedirte que elijas actividades."))
                Detail(text: model.t("\(min(3, routine.observedDays))/3 days · \(min(90, Int(routine.minutes)))/90 minutes · \(min(5, Int(routine.drop)))/5 battery points observed.", "\(min(3, routine.observedDays))/3 días · \(min(90, Int(routine.minutes)))/90 minutos · \(min(5, Int(routine.drop)))/5 puntos de batería observados."))
                Detail(text: model.t("Each day needs at least 10 observed minutes on battery. Charging and sleep don't count.", "Cada día necesita al menos 10 minutos observados con batería. La carga y el reposo no cuentan."))
            }
            if !model.learningEnabled {
                Label(model.t("Learning paused in Settings", "Aprendizaje pausado en Ajustes"), systemImage: "pause.circle")
                    .font(.system(size: 12)).foregroundStyle(Palette.amber)
            }
        }.panel()
    }
}
