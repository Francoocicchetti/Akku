import SwiftUI

struct ChargeCard: View {
    @ObservedObject var model: BatteryModel
    let items: [TripItem]
    var body: some View {
        let target = model.chargeTarget(items)
        VStack(alignment: .leading, spacing: 7) {
            Divider().padding(.vertical, 3)
            Label(model.t("Before you go", "Antes de salir"), systemImage: "powerplug").fontWeight(.semibold)
            if target.reachable {
                Text(model.t("Charge to about \(target.percent)%", "Carga hasta aproximadamente el \(target.percent)%")).foregroundStyle(Palette.mint).fontWeight(.medium)
                Detail(text: model.t("Conservative target, including your reserve. It changes as I learn.", "Objetivo conservador, incluida tu reserva. Se ajusta mientras aprendo."))
                if let current = model.snapshot.percent, current >= Double(target.percent) {
                    Detail(text: model.t("You're already at the target.", "Ya alcanzaste el objetivo."))
                } else if let eta = model.chargeETA(items) {
                    Detail(text: model.t("Estimated charge time: ", "Tiempo de carga estimado: ") + eta.range)
                } else {
                    Detail(text: model.t("Charge time appears after enough measurements with this charger and conditions. Charging may slow down or pause.", "El tiempo aparecerá cuando haya suficientes mediciones con este cargador y condiciones. La carga puede ralentizarse o pausarse."))
                }
            } else {
                Text(model.t("Even 100% may not cover this plan and reserve.", "Incluso el 100% podría no cubrir este plan y la reserva.")).foregroundStyle(Palette.amber)
                Detail(text: model.t("Plan a charging stop or reduce the duration.", "Prepara una parada para cargar o reduce la duración."))
            }
        }.font(.system(size: 12))
    }
}
struct HistoryCard: View {
    @ObservedObject var model: BatteryModel
    @State private var expanded = false
    var body: some View {
        if !model.outcomes.isEmpty {
            VStack(alignment: .leading, spacing: 13) {
                Label(model.t("What really happened", "Lo que pasó de verdad"), systemImage: "clock.arrow.circlepath").font(.system(size: 17, weight: .semibold, design: .default))
                if let last = model.outcomes.last { row(last) }
                let calibration = model.calibration
                if let error = calibration.meanAbsoluteError, let coverage = calibration.coverage {
                    Detail(text: model.t("\(calibration.eligible.count) comparable outings · average absolute error \(String(format: "%.1f", error)) percentage points · \(Int((coverage * 100).rounded()))% inside the range.", "\(calibration.eligible.count) salidas comparables · error absoluto medio de \(String(format: "%.1f", error)) puntos porcentuales · \(Int((coverage * 100).rounded()))% dentro del rango."))
                    Detail(text: model.t("Observed coverage is not a promised probability. Correction starts after 3 comparable outings; little data means low confidence.", "La cobertura observada no es una probabilidad garantizada. La corrección empieza con 3 salidas comparables; pocos datos implican confianza baja."))
                } else { Detail(text: model.t("No comparable outings yet. I need at least 15 minutes, measurable discharge and stable conditions.", "Todavía no hay salidas comparables. Necesito al menos 15 minutos, descarga medible y condiciones estables.")) }
                if model.outcomes.count > 1 {
                    DisclosureGroup(model.t("Earlier outings", "Salidas anteriores"), isExpanded: $expanded) {
                        VStack(alignment: .leading, spacing: 14) { ForEach(Array(model.outcomes.dropLast().suffix(15).reversed())) { value in Divider(); row(value) } }.padding(.top, 12)
                    }
                }
            }.panel()
        }
    }
    private func row(_ outcome: TripOutcome) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(outcome.endedAt, style: .date).font(.system(size: 11)).foregroundStyle(Palette.secondary)
            if let predicted = outcome.predictedBattery, let actual = outcome.actualBattery {
                Text(model.t("We estimated \(Int(predicted.rounded()))%. You finished with \(Int(actual.rounded()))%.", "Estimamos un \(Int(predicted.rounded()))%. Terminaste con un \(Int(actual.rounded()))%.")).font(.system(size: 16, weight: .semibold, design: .default))
                if let low = outcome.lowerBattery, let high = outcome.upperBattery {
                    Detail(text: model.t("Expected range: ", "Rango previsto: ") + "\(Int(low.rounded()))–\(Int(high.rounded()))% · " + duration(outcome.activeMinutes))
                }
            } else { Detail(text: model.t("This older outing has no saved starting forecast.", "Esta salida anterior no tiene un pronóstico inicial guardado.")) }
            if !outcome.completed { Detail(text: model.t("Finished early: compared only the active portion of your plan.", "Terminaste antes: se compara solo la parte activa del plan.")) }
            if outcome.eligible {
                Detail(text: outcome.inRange == true ? model.t("Inside the range. Used to improve future estimates.", "Dentro del rango. Se usa para mejorar futuras estimaciones.") : model.t("Outside the range. Used to correct future estimates.", "Fuera del rango. Se usa para corregir futuras estimaciones."))
            } else { Detail(text: exclusion(outcome.exclusion)) }
        }
    }
    private func exclusion(_ value: String?) -> String {
        let reason: String
        switch value {
        case "charging": reason = model.t("the Mac was plugged in", "el Mac estuvo conectado")
        case "paused": reason = model.t("the outing included pauses and battery could drain during them", "hubo pausas y la batería pudo consumirse durante ellas")
        case "conditions": reason = model.t("conditions changed", "cambiaron las condiciones")
        case "gap": reason = model.t("readings were interrupted", "se interrumpieron las lecturas")
        case "short": reason = model.t("not enough duration or discharge", "faltó duración o descarga medible")
        default: reason = model.t("missing measurements", "faltan mediciones")
        }
        return model.t("Saved but not used for calibration: ", "Guardada, sin usar para calibrar: ") + reason + "."
    }
}
struct ContextCard: View {
    @ObservedObject var model: BatteryModel
    var matching: [DischargeSample] { model.samples.filter { $0.valid && $0.context?.combinationKey == model.context.combinationKey && $0.context?.sameConditions(as: model.context) == true } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(model.t("Together, on your Mac", "Juntas, en tu Mac"), systemImage: "square.stack.3d.up").fontWeight(.semibold)
            let names = model.nativeApps.apps.filter { model.context.apps.contains($0.bundleID) }.map(\.name)
            Text(names.isEmpty ? model.t("No app combination yet", "Sin combinación de apps") : names.joined(separator: " + ")).font(.system(size: 12, weight: .medium)).fixedSize(horizontal: false, vertical: true)
            if matching.count >= 3 {
                let rate = matching.reduce(0) { $0 + $1.drop } / matching.reduce(0) { $0 + $1.minutes } * 60
                Text(model.t("Observed together: ", "Consumo observado del conjunto: ") + String(format: "%.1f", rate) + model.t(" battery points/hour", " puntos de batería/hora")).foregroundStyle(Palette.mint)
                Detail(text: model.t("\(matching.count) intervals with these apps open. Total Mac consumption, including all other work.", "\(matching.count) intervalos con estas apps abiertas. Consumo total del Mac, incluido el resto del trabajo."))
            } else { Detail(text: model.t("Still learning this combination. Apps being open does not prove they caused the discharge.", "Aún aprendo esta combinación. Que las apps estén abiertas no demuestra que causaran la descarga.")) }
            HStack { Label("\(model.context.externalDisplays)", systemImage: "display"); Text(model.lowPower ? model.t("Low power", "Bajo consumo") : model.t("Normal power", "Consumo normal")); Spacer() }.font(.system(size: 11)).foregroundStyle(Palette.secondary)
            if model.context.heavyLoad { Detail(text: model.t("Sustained processing or thermal pressure detected. Forecast uncertainty increases without comparable observations.", "Se detectó procesamiento sostenido o presión térmica. La incertidumbre aumenta si no hay observaciones comparables.")) }
            Detail(text: model.t("App and energy observations are automatic. Call state, screen sharing and content are not inspected.", "Las observaciones de apps y energía son automáticas. No se inspecciona el estado de llamadas, pantalla compartida ni contenidos."))
        }.panel()
    }
}
struct PlacesPage: View {
    @ObservedObject var model: BatteryModel
    @State private var selected: FamiliarPlace?
    @State private var kind = "place"
    @State private var name = ""
    @State private var namingCurrent = false
    @State private var manualEntry = false
    @State private var erasing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(model.t("The places in your day.", "Los lugares de tu día.")).font(.system(size: 27, weight: .semibold, design: .default))
            Detail(text: model.t("Your energy, on the map. Places and app patterns appear as I observe them; naming a place is optional.", "Tu energía, en el mapa. Los lugares y patrones de apps aparecen al observarlos; ponerles nombre es opcional."))
            EnergyMapCard(model: model)
            VStack(alignment: .leading, spacing: 13) {
                LocationToggle(model: model)
                Label(model.location.status(model.language), systemImage: "mappin.and.ellipse").foregroundStyle(Palette.mint).fontWeight(.semibold)
                Detail(text: model.location.detail(model.language))
                if model.location.enabled {
                    HStack {
                        Button(model.t("Locate now", "Ubicar ahora")) { model.location.request(force: true) }.disabled(model.location.locating)
                        Button(model.t("Name this place", "Nombrar este lugar")) { kind = "place"; name = ""; namingCurrent = true }.disabled(!model.location.canSaveHome)
                    }.buttonStyle(.bordered)
                    if model.location.problem == "denied" { Button(model.t("Open location permissions", "Abrir permisos de ubicación")) { model.openSettings("com.apple.preference.security?Privacy_LocationServices") } }
                }
            }.panel()
            Button(model.t("Enter a location manually", "Introducir ubicación manual")) { manualEntry = true }.buttonStyle(.bordered)
            if model.location.usingManual {
                Detail(text: model.t("Automatic readings resume when the manual position expires, if enabled.", "Las lecturas automáticas vuelven cuando caduque la posición manual, si están activadas."))
                Button(model.t("Clear manual position", "Quitar posición manual")) { model.location.clearManualPosition() }
            }
            ReturnHomeCard(model: model)
            if model.location.places.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "house.and.flag").font(.system(size: 34)).foregroundStyle(Palette.mint)
                    Text(model.t("Getting to know your world", "Conociendo tu mundo")).font(.system(size: 18, weight: .semibold, design: .default))
                    Detail(text: model.t("A suggestion needs at least two visits and 45 observed minutes. Home or work hints need patterns on several days. You can also name your current location now.", "Una sugerencia necesita al menos dos visitas y 45 minutos observados. Las pistas de casa o trabajo requieren patrones de varios días. También puedes nombrar tu ubicación actual."))
                }.panel()
            }
            ForEach(model.location.places) { place in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: place.kind == "home" ? "house.fill" : place.kind == "work" ? "briefcase.fill" : "mappin.circle.fill").foregroundStyle(Palette.mint)
                        Text(place.name ?? model.t("A place you return to", "Un lugar al que vuelves")).fontWeight(.semibold)
                        Spacer()
                        Button(model.t("Name", "Nombrar")) { selected = place; kind = place.kind ?? place.suggestion; name = place.name ?? suggestedName(kind) }
                    }
                    if place.name == nil {
                        Detail(text: place.suggestion == "home" ? model.t("Could this be home? Your repeated evening visits suggest it.", "¿Podría ser tu casa? Lo sugieren tus visitas nocturnas repetidas.") : place.suggestion == "work" ? model.t("Could this be work? You often return on weekdays.", "¿Podría ser tu trabajo? Vuelves a menudo en días laborales.") : model.t("Would you like to save this place?", "¿Quieres guardar este lugar?"))
                        Button(model.t("Dismiss suggestion", "Descartar sugerencia")) { model.location.dismissPlace(place.id) }.buttonStyle(.plain).foregroundStyle(Palette.secondary)
                    }
                    Detail(text: model.t("\(place.visits) visits · \(duration(place.dwellMinutes)) observed", "\(place.visits) visitas · \(duration(place.dwellMinutes)) observados"))
                }.panel()
            }
            VStack(alignment: .leading, spacing: 12) {
                Toggle(model.t("A gentle “Heading out?”", "Un «¿Has salido?» discreto"), isOn: Binding(get: { model.location.departureAlerts }, set: { model.location.departureAlerts = $0 })).toggleStyle(.switch)
                Detail(text: model.t("After two accurate outside readings, separated by at least two minutes. No sound, no more than once every four hours. macOS notifications also need the Alerts setting.", "Tras dos lecturas precisas fuera de casa, separadas por al menos dos minutos. Sin sonido, máximo una vez cada cuatro horas. Las notificaciones de macOS también necesitan activar Avisos."))
                Button(model.t("Quiet for today", "Silencio por hoy")) { model.location.snoozeDeparture(); model.departureNotice = false }
                HStack { Text(model.t("Home boundary", "Radio de casa")); Spacer(); Text("\(Int(model.location.radius)) m") }
                Slider(value: Binding(get: { model.location.radius }, set: { model.location.radius = $0 }), in: 150...1000, step: 50).tint(Palette.mint)
            }.panel()
            Detail(text: model.t("Coordinates, battery events and app-by-place aggregates stay locally on this Mac. No route is saved. Apple Maps loads the map from Apple services. You can disable learning or erase all places. macOS may use Apple's services to determine location.", "Las coordenadas, eventos de batería y agregados de apps por lugar se guardan en este Mac. No se guardan recorridos. Mapas de Apple carga el mapa desde los servicios de Apple. Puedes desactivar el aprendizaje o borrar los lugares. macOS puede usar servicios de Apple para ubicarte."))
            Button(model.t("Forget all places…", "Olvidar todos los lugares…")) { erasing = true }.buttonStyle(.bordered)
        }
        .sheet(isPresented: $manualEntry) { ManualPlaceSheet(model: model) }
        .sheet(isPresented: Binding(get: { selected != nil || namingCurrent }, set: { if !$0 { selected = nil; namingCurrent = false } })) {
            VStack(alignment: .leading, spacing: 18) {
                Text(model.t("Give this place a name", "Dale un nombre a este lugar")).font(.system(size: 22, weight: .semibold, design: .default))
                Picker(model.t("Place type", "Tipo de lugar"), selection: $kind) {
                    Text(model.t("Home", "Casa")).tag("home"); Text(model.t("Work", "Trabajo")).tag("work"); Text(model.t("Another place", "Otro lugar")).tag("place")
                }.onChange(of: kind) { value in if name.isEmpty || ["Home", "Casa", "Work", "Trabajo"].contains(name) { name = suggestedName(value) } }
                TextField(model.t("Name", "Nombre"), text: $name).textFieldStyle(.roundedBorder)
                Detail(text: model.t("Choosing Home replaces the home used for departure notices.", "Elegir Casa reemplaza la casa usada para los avisos al salir."))
                HStack { Button(model.t("Cancel", "Cancelar")) { selected = nil; namingCurrent = false }; Spacer(); Button(model.t("Save place", "Guardar lugar")) {
                    if let selected { model.location.confirmPlace(selected.id, kind: kind, name: name) }
                    else { model.location.saveCurrentPlace(kind: kind, name: name) }
                    selected = nil; namingCurrent = false
                }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }.padding(28).frame(width: 360).background(Palette.background).foregroundStyle(Palette.ink).preferredColorScheme(.dark)
        }
        .alert(model.t("Forget all places?", "¿Olvidar todos los lugares?"), isPresented: $erasing) {
            Button(model.t("Cancel", "Cancelar"), role: .cancel) {}
            Button(model.t("Forget", "Olvidar"), role: .destructive) { model.location.forgetPlaces() }
        }
    }
    private func suggestedName(_ kind: String) -> String { kind == "home" ? model.t("Home", "Casa") : kind == "work" ? model.t("Work", "Trabajo") : "" }
}
struct ValidationCard: View {
    @ObservedObject var model: BatteryModel
    @State private var activity = Activity.browsing
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(model.t("A real-world check", "Una prueba real"), systemImage: "checkmark.seal").fontWeight(.semibold)
            Detail(text: model.t("Repeat 30 minutes unplugged with fixed brightness and the same apps. Start above 50%. Repeat on different days; export results to compare models.", "Repite 30 minutos sin cargador, con brillo y apps constantes. Empieza sobre el 50%. Repite en distintos días y exporta los resultados para comparar modelos."))
            Detail(text: model.t("Recording starts automatically when you unplug. No test-start button is needed.", "El registro comienza automáticamente al desconectar el cargador. No necesitas iniciar una prueba."))
            Detail(text: model.t("Run the activity yourself; this does not start a call or play a video. Other MacBook Air and Pro M1–M5 models need physical testing. Recognition is not validation.", "Realiza tú la actividad; esto no inicia llamadas ni reproduce videos. Los demás MacBook Air y Pro M1–M5 necesitan pruebas físicas. Reconocerlos no equivale a validarlos."))
            if let cpu = model.performance.averageCPU, let latest = model.performance.samples.last {
                Detail(text: model.t("Akku this session: ", "Akku en esta sesión: ") + String(format: "%.2f%% CPU · %.0f MiB", cpu, latest.residentMiB))
                Detail(text: model.t("CPU relative to one core and resident memory; these are not direct energy measurements. Export includes visibility at each interval's endpoints.", "CPU respecto a un núcleo y memoria residente; no son mediciones directas de energía. La exportación incluye la visibilidad en los extremos de cada intervalo."))
            }
            Button(model.t("Export observations & results…", "Exportar observaciones y resultados…")) { model.exportResults() }
            Detail(text: model.t("The JSON includes app identifiers and battery observations, without places or coordinates.", "El JSON incluye identificadores de apps y observaciones de batería, sin lugares ni coordenadas."))
        }.panel()
    }
}
