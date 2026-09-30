import SwiftUI
import CoreLocation

struct LocationToggle: View {
    @ObservedObject var model: BatteryModel
    @State private var warning = false
    var body: some View {
        Toggle(model.t("Automatic location", "Ubicación automática"), isOn: Binding(get: { model.location.enabled }, set: { value in
            if value { model.location.setEnabled(true) } else { warning = true }
        })).toggleStyle(.switch)
        .alert(model.t("Turn off location?", "¿Desactivar la ubicación?"), isPresented: $warning) {
            Button(model.t("Keep enabled", "Mantener activada"), role: .cancel) {}
            Button(model.t("Turn off", "Desactivar")) { model.location.setEnabled(false); model.departureNotice = false }
        } message: { Text(model.t("Akku will no longer detect where you are, learn new visits, or measure your automatic distance from home. Battery features still work. You can enter a temporary manual position.", "Akku dejará de detectar dónde estás, aprender nuevas visitas y medir automáticamente la distancia a casa. La batería seguirá funcionando. Podrás indicar una posición manual temporal.")) }
        if model.location.enabled && model.location.authorization == .notDetermined {
            Button(model.t("Allow location in macOS…", "Permitir ubicación en macOS…")) { model.location.requestPermission() }.buttonStyle(.bordered)
        }
        if model.location.enabled && (model.location.authorization == .denied || model.location.authorization == .restricted) {
            Button(model.t("Review macOS location permission", "Revisar permiso de ubicación de macOS")) { model.openSettings("com.apple.preference.security?Privacy_LocationServices") }.buttonStyle(.bordered)
        }
    }
}
struct AkkuWelcome: View {
    @ObservedObject var model: BatteryModel
    @State private var requested = false
    var authorized: Bool { model.location.authorization == .authorizedAlways }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Spacer(); LanguageMenu(model: model) }
            HStack(spacing: 15) {
                Image(nsImage: BrandAssets.logo).resizable().scaledToFit().frame(width: 74, height: 84)
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.t("Hello. I'm Akku.", "Hola. Soy Akku.")).font(.system(size: 28,weight: .semibold,design: .default))
                    Detail(text: model.t("A little companion for your energy.", "Un pequeño compañero para tu energía."))
                }
            }
            Text(model.t("Let's start with your location", "Empecemos por tu ubicación")).font(.system(size: 19,weight: .semibold))
            Detail(text: model.t("Location starts enabled. macOS asks for your permission so I can recognize places and show how far home is. You can turn it off later in Settings.", "La ubicación empieza activada. macOS pide tu permiso para que pueda reconocer lugares y mostrar qué tan lejos está casa. Después puedes desactivarla en Ajustes."))
            Detail(text: model.t("Your places stay on this Mac. I don't record a route or read your messages. I only speak when there's something useful, and you can ask me to be quiet.", "Tus lugares quedan en este Mac. No registro recorridos ni leo tus mensajes. Te acompaño con mensajes útiles y puedes pedirme silencio."))
            if authorized && model.location.enabled {
                Label(model.t("Location is ready", "La ubicación está lista"), systemImage: "checkmark.circle.fill").foregroundStyle(Palette.mint)
                PrimaryButton(title: model.t("Meet Akku", "Conocer a Akku")) { model.finishWelcome() }
            } else {
                PrimaryButton(title: model.t("Enable location", "Activar ubicación"), icon: "location.fill") { requested = true; model.location.requestPermission() }
                if model.location.authorization == .denied || model.location.authorization == .restricted {
                    Detail(text: model.t("macOS has location blocked. I can't change that permission for you.", "macOS tiene la ubicación bloqueada. No puedo cambiar ese permiso por ti."))
                    Button(model.t("Open macOS location settings", "Abrir Localización de macOS")) { model.openSettings("com.apple.preference.security?Privacy_LocationServices") }
                }
                if requested || model.location.authorization == .denied || model.location.authorization == .restricted || !model.location.enabled {
                    Button(model.t("Continue without automatic detection", "Continuar sin detección automática")) { model.location.setEnabled(false); model.finishWelcome() }.buttonStyle(.plain).foregroundStyle(Palette.secondary)
                    Detail(text: model.t("Without permission, Akku cannot detect where you are. You can enter your position manually in Places.", "Sin permiso, Akku no puede detectar dónde estás. Puedes indicar tu posición manualmente en Lugares."))
                }
            }
        }.padding(28).frame(width: 370).background(Palette.background).foregroundStyle(Palette.ink).preferredColorScheme(.dark).tint(Palette.mint).environment(\.locale, model.language.locale)
    }
}
struct ManualPlaceSheet: View {
    @ObservedObject var model: BatteryModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var search = AddressSearch()
    @State private var query = ""
    @State private var selected: AddressCandidate?
    @State private var purpose = "current"
    @State private var name = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var coordinates = false
    @State private var error = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(model.t("Tell Akku where", "Dile a Akku dónde")).font(.system(size: 24,weight: .semibold,design: .default))
                Picker(model.t("Use this location for", "Usar esta ubicación como"), selection: $purpose) {
                    Text(model.t("Where I am now", "Donde estoy ahora")).tag("current")
                    Text(model.t("My home", "Mi casa")).tag("home")
                    Text(model.t("My work", "Mi trabajo")).tag("work")
                    Text(model.t("Another saved place", "Otro lugar guardado")).tag("place")
                }
                HStack {
                    TextField(model.t("Address, city or place", "Dirección, ciudad o lugar"), text: $query).textFieldStyle(.roundedBorder)
                    Button(model.t("Search", "Buscar")) { search.find(query); selected = nil }.disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 || search.searching)
                }
                Detail(text: model.t("Search sends the text to Apple Maps. Check the result before saving. Coordinates below also work offline.", "La búsqueda envía el texto a Mapas de Apple. Revisa el resultado antes de guardarlo. También puedes usar coordenadas sin conexión."))
                if search.searching { ProgressView().controlSize(.small) }
                if search.failed { Detail(text: model.t("No result. Try a more specific address or enter coordinates.", "No hubo resultados. Prueba una dirección más concreta o introduce coordenadas.")) }
                ForEach(search.results) { result in
                    Button {
                        selected = result; latitude = String(result.latitude); longitude = String(result.longitude)
                        if name.isEmpty { name = result.title }; error = false
                    } label: {
                        HStack(alignment: .top) {
                            Image(systemName: selected?.id == result.id ? "checkmark.circle.fill" : "mappin.circle").foregroundStyle(Palette.mint)
                            VStack(alignment: .leading, spacing: 3) { Text(result.title).fontWeight(.medium); Detail(text: result.detail) }
                            Spacer()
                        }.padding(10).background(selected?.id == result.id ? Palette.mint.opacity(0.10) : Palette.card).clipShape(RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain)
                }
                DisclosureGroup(model.t("Enter coordinates", "Introducir coordenadas"), isExpanded: $coordinates) {
                    VStack(alignment: .leading, spacing: 9) {
                        TextField(model.t("Latitude (−90 to 90)", "Latitud (−90 a 90)"), text: $latitude)
                        TextField(model.t("Longitude (−180 to 180)", "Longitud (−180 a 180)"), text: $longitude)
                        Detail(text: model.t("Decimal degrees. A comma or dot can be used as the decimal separator.", "Grados decimales. Puedes usar coma o punto decimal."))
                    }.textFieldStyle(.roundedBorder).padding(.top, 10)
                }
                TextField(model.t("Place name (optional for current position)", "Nombre (opcional para posición actual)"), text: $name).textFieldStyle(.roundedBorder)
                Detail(text: purpose == "current" ? model.t("Your indicated position lasts 30 minutes, is not tracked and does not trigger automatic departure alerts.", "La posición indicada dura 30 minutos, no sigue tus movimientos y no dispara avisos automáticos de salida.") : purpose == "home" ? model.t("This replaces your saved home. Use your actual home location.", "Esto reemplaza tu casa guardada. Usa la ubicación real de tu casa.") : model.t("This saves a place; it does not claim you are currently there.", "Esto guarda un lugar; no afirma que estés allí ahora."))
                if error { Text(model.t("Check the coordinates and try again.", "Revisa las coordenadas e inténtalo otra vez.")).foregroundStyle(Palette.amber) }
                HStack {
                    Button(model.t("Cancel", "Cancelar")) { dismiss() }
                    Spacer()
                    Button(model.t("Use this location", "Usar esta ubicación"), action: save).buttonStyle(.borderedProminent).tint(Palette.mint)
                }
            }.padding(25)
        }.frame(width: 410, height: 540).background(Palette.background).foregroundStyle(Palette.ink).preferredColorScheme(.dark).tint(Palette.mint).environment(\.locale, model.language.locale).onDisappear { search.cancel() }
    }
    private func save() {
        let lat = Double(latitude.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
        let lon = Double(longitude.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
        guard let lat, let lon, ManualPosition.validCoordinates(lat, lon) else { error = true; return }
        let text = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if purpose == "current" { model.location.setManualPosition(latitude: lat, longitude: lon, label: text); dismiss() }
        else {
            let fallback = purpose == "home" ? model.t("Home", "Casa") : purpose == "work" ? model.t("Work", "Trabajo") : model.t("My place", "Mi lugar")
            if model.location.saveManualPlace(latitude: lat, longitude: lon, name: text.isEmpty ? fallback : text, kind: purpose) { dismiss() } else { error = true }
        }
    }
}
struct ReturnHomeCard: View {
    @ObservedObject var model: BatteryModel
    @State private var expand = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(model.t("Charge here or at home?", "¿Cargar aquí o en casa?"), systemImage: "house.and.flag").font(.system(size: 17,weight: .semibold,design: .default))
            if let distance = model.location.homeDistance {
                Text(distance.text(model.language)).foregroundStyle(Palette.mint).fontWeight(.semibold)
                Detail(text: model.t("Straight-line distance, not a route. ", "Distancia en línea recta, no un recorrido. ") + (distance.manual ? model.t("Based on your manual position.", "Basada en tu posición manual.") : model.t("Based on a recent macOS location.", "Basada en una ubicación reciente de macOS.")))
                Text(model.returnPlan.message(model.language)).font(.system(size: 13,weight: .medium)).fixedSize(horizontal: false, vertical: true)
                DisclosureGroup(model.t("Adjust my return plan", "Ajustar mi regreso"), isExpanded: $expand) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(model.t("I know approximately when I'll be home", "Sé aproximadamente cuándo llegaré a casa"), isOn: $model.hasReturnTime)
                        if model.hasReturnTime {
                            Stepper(model.t("Home in \(Int(model.returnMinutes)) minutes", "En casa en \(Int(model.returnMinutes)) minutos"), value: $model.returnMinutes, in: 5...480, step: 5)
                        }
                        Stepper(model.t("Work before leaving: \(Int(model.workBeforeHome)) minutes", "Trabajo antes de salir: \(Int(model.workBeforeHome)) minutos"), value: $model.workBeforeHome, in: 0...480, step: 15)
                        Toggle(model.t("I'll use my Mac on the way", "Usaré el Mac durante el trayecto"), isOn: $model.useWhileReturning)
                        Detail(text: model.t("Uses the conservative rate for your current activity (browsing if unknown), plus your reserve. With the Mac closed, a provisional allowance of 2 battery points/hour is used; actual sleep drain may differ.", "Usa el consumo conservador de tu actividad (navegación si es desconocida), más la reserva. Con el Mac cerrado se presupuestan provisionalmente 2 puntos de batería/hora; el reposo real puede consumir más o menos."))
                        Detail(text: model.t("Distance alone never guarantees you can wait. Over 5 km is described as far; the decision also needs your time and workload.", "La distancia sola nunca garantiza que puedas esperar. Más de 5 km se describe como lejos; la decisión también necesita tu tiempo y actividad."))
                    }.font(.system(size: 12)).padding(.top, 10)
                }
            } else {
                Detail(text: model.t("Set your home in Places and provide a fresh automatic or manual position. Akku won't guess where you are.", "Configura tu casa en Lugares y una posición reciente automática o manual. Akku no adivinará dónde estás."))
            }
        }.panel()
    }
}
struct CompanionSettings: View {
    @ObservedObject var model: BatteryModel
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(model.t("Akku, your way", "Akku, a tu manera"), systemImage: "heart").fontWeight(.semibold)
            LocationToggle(model: model)
            if !model.location.enabled { Detail(text: model.t("Automatic position and distance are unavailable. Manual positions remain possible.", "La posición y distancia automáticas no están disponibles. Puedes usar posiciones manuales.")) }
            Toggle(model.t("Gentle break suggestions", "Sugerencias discretas de descanso"), isOn: $model.gentleReminders).toggleStyle(.switch)
            Stepper(model.t("After about \(Int(model.breakMinutes)) minutes of use", "Después de unos \(Int(model.breakMinutes)) minutos de uso"), value: $model.breakMinutes, in: 30...120, step: 10)
            Detail(text: model.t("Only inside Akku, with no sound or popup. Usage is approximate; it does not inspect calls or read keystrokes.", "Solo dentro de Akku, sin sonido ni ventanas emergentes. El uso es aproximado; no inspecciona llamadas ni lee teclas."))
            Button(model.t("Quiet for one hour", "Silencio por una hora")) { model.quietCompanion() }
            if model.quietUntil > model.contextDate { Detail(text: model.t("Quiet company is on. Battery warnings still remain visible.", "La compañía silenciosa está activa. Las alertas de batería siguen visibles.")) }
        }.panel()
    }
}
