import AppKit
import SwiftUI
import MapKit

struct EnergyPin: Identifiable {
    var id: String
    var latitude: Double
    var longitude: Double
    var title: String
    var detail: String
    var kind: String
    var weight: Double = 0
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}
final class EnergyAnnotation: NSObject, MKAnnotation {
    let pin: EnergyPin
    init(_ pin: EnergyPin) { self.pin = pin }
    var coordinate: CLLocationCoordinate2D { pin.coordinate }
    var title: String? { pin.title }
    var subtitle: String? { pin.detail }
}
private enum EnergyMapCache { static var region: MKCoordinateRegion? }
struct NativeEnergyMap: NSViewRepresentable {
    var pins: [EnergyPin]
    var recenter: Int
    var usageLayer: Bool
    var onSelect: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsZoomControls = true; map.showsCompass = true
        map.isRotateEnabled = false; map.isPitchEnabled = false
        map.pointOfInterestFilter = .excludingAll
        let savedRegion = EnergyMapCache.region
        context.coordinator.hasPosition = savedRegion != nil
        context.coordinator.recenter = recenter
        map.setRegion(savedRegion ?? MKCoordinateRegion(center: .init(latitude: 15, longitude: 0), span: .init(latitudeDelta: 120, longitudeDelta: 300)), animated: false)
        map.setAccessibilityLabel("Akku · Apple Maps")
        return map
    }
    func updateNSView(_ map: MKMapView, context: Context) {
        let c = context.coordinator; c.parent = self
        let signature = pins.map { "\($0.id)|\($0.latitude)|\($0.longitude)|\($0.title)|\($0.detail)|\($0.kind)|\($0.weight)" }.joined() + "\(usageLayer)"
        if c.signature != signature {
            c.signature = signature
            map.removeAnnotations(map.annotations)
            map.addAnnotations(pins.map(EnergyAnnotation.init))
            map.removeOverlays(map.overlays)
            if usageLayer {
                for pin in pins where pin.weight > 0 && pin.kind != "current" {
                    map.addOverlay(MKCircle(center: pin.coordinate, radius: min(2000, 120 + sqrt(pin.weight / 60) * 75)))
                }
            }
        }
        if c.recenter != recenter || (!c.hasPosition && !pins.isEmpty) {
            c.recenter = recenter; c.hasPosition = !pins.isEmpty
            if pins.count == 1, let first = pins.first {
                map.setRegion(.init(center: first.coordinate, latitudinalMeters: 2200, longitudinalMeters: 2200), animated: false)
            } else if !pins.isEmpty {
                let rect = pins.reduce(MKMapRect.null) { partial, pin in
                    let p = MKMapPoint(pin.coordinate)
                    return partial.union(MKMapRect(x: p.x - 1500, y: p.y - 1500, width: 3000, height: 3000))
                }
                map.setVisibleMapRect(rect, edgePadding: NSEdgeInsets(top: 45, left: 45, bottom: 45, right: 45), animated: false)
            }
        }
    }
    static func dismantleNSView(_ map: MKMapView, coordinator: Coordinator) {
        EnergyMapCache.region = map.region
        map.delegate = nil; map.removeAnnotations(map.annotations); map.removeOverlays(map.overlays)
    }
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: NativeEnergyMap
        var signature = ""
        var recenter = -1
        var hasPosition = false
        init(_ parent: NativeEnergyMap) { self.parent = parent }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let a = annotation as? EnergyAnnotation else { return nil }
            let view = MKMarkerAnnotationView(annotation: a, reuseIdentifier: "energy")
            view.canShowCallout = true
            view.displayPriority = a.pin.kind == "current" ? .required : .defaultHigh
            switch a.pin.kind {
            case "current": view.markerTintColor = .systemBlue; view.glyphImage = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: nil)
            case "last": view.markerTintColor = .systemGray; view.glyphImage = NSImage(systemSymbolName: "clock", accessibilityDescription: nil)
            case "charge": view.markerTintColor = .systemGreen; view.glyphImage = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)
            case "low": view.markerTintColor = .systemRed; view.glyphImage = NSImage(systemSymbolName: "battery.0percent", accessibilityDescription: nil)
            case "use": view.markerTintColor = .systemOrange; view.glyphImage = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: nil)
            default: view.markerTintColor = .systemTeal; view.glyphImage = NSImage(systemSymbolName: "mappin", accessibilityDescription: nil)
            }
            return view
        }
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let a = view.annotation as? EnergyAnnotation else { return }
            DispatchQueue.main.async { self.parent.onSelect(a.pin.id) }
        }
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = NSColor.systemOrange.withAlphaComponent(0.16)
                renderer.strokeColor = NSColor.systemOrange.withAlphaComponent(0.45); renderer.lineWidth = 1
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

struct EnergyMapCard: View {
    @ObservedObject var model: BatteryModel
    @State private var layer = "all"
    @State private var days = 30
    @State private var chosen: UUID?
    @State private var recenter = 0
    private var since: Date { Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: model.contextDate))! }
    private var places: [FamiliarPlace] { model.location.learner.places.filter { !$0.dismissed } }
    private var selected: FamiliarPlace? { places.first { $0.id == chosen } }
    private func name(_ place: FamiliarPlace) -> String {
        place.name ?? model.t("Place \((places.firstIndex { $0.id == place.id } ?? 0) + 1)", "Lugar \((places.firstIndex { $0.id == place.id } ?? 0) + 1)")
    }
    private func summary(_ id: UUID) -> PlaceUsageSummary { model.placeHistory.summary(placeID: id, since: since) }
    private var pins: [EnergyPin] {
        var result: [EnergyPin] = places.compactMap { place in
            let s = summary(place.id)
            let low = model.placeHistory.events.contains { $0.placeID == place.id && $0.date >= since && $0.kind != .charge }
            if layer == "charge" && s.charges == 0 { return nil }
            if layer == "low" && !low { return nil }
            if layer == "use" && s.activeSeconds < 60 { return nil }
            let kind = layer == "use" ? "use" : low ? "low" : s.charges > 0 ? "charge" : "place"
            let detail = duration(s.activeSeconds / 60) + model.t(" foreground · ", " en primer plano · ") + "\(s.charges) " + model.t("charging observations", "cargas observadas")
            return EnergyPin(id: place.id.uuidString, latitude: place.latitude, longitude: place.longitude, title: name(place), detail: detail, kind: kind, weight: layer == "use" ? s.activeSeconds : 0)
        }
        if model.location.usingManual, let manual = model.location.manualPosition {
            result.append(EnergyPin(id: "manual", latitude: manual.latitude, longitude: manual.longitude, title: model.t("Position you entered", "Posición indicada por ti"), detail: model.t("Manual · excluded from automatic history", "Manual · excluida del historial automático"), kind: "last"))
        } else if let fix = model.location.automaticFix {
            result.append(EnergyPin(id: "current", latitude: fix.latitude, longitude: fix.longitude, title: model.t("This Mac · recent location", "Este Mac · ubicación reciente"), detail: "±\(Int(fix.accuracy)) m · " + fix.date.formatted(date: .omitted, time: .shortened), kind: "current"))
        } else if let fix = model.placeHistory.lastKnown {
            result.append(EnergyPin(id: "last", latitude: fix.latitude, longitude: fix.longitude, title: model.t("Last observed location", "Última ubicación observada"), detail: fix.date.formatted(date: .abbreviated, time: .shortened), kind: "last"))
        }
        return result
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label(model.t("Your energy map", "Tu mapa de energía"), systemImage: "map").font(.system(size: 20, weight: .semibold, design: .default))
                Spacer()
                Picker(model.t("Period", "Período"), selection: $days) { Text(model.t("7 days", "7 días")).tag(7); Text(model.t("30 days", "30 días")).tag(30) }.labelsHidden().frame(width: 105)
            }
            Picker(model.t("Map layer", "Capa del mapa"), selection: $layer) {
                Text(model.t("All", "Todo")).tag("all")
                Text(model.t("Charging", "Cargas")).tag("charge")
                Text(model.t("Low battery", "Batería baja")).tag("low")
                Text(model.t("Usage", "Uso")).tag("use")
            }.pickerStyle(.segmented)
            NativeEnergyMap(pins: pins, recenter: recenter, usageLayer: layer == "use") { id in
                if let uuid = UUID(uuidString: id) { chosen = uuid }
                else if id == "current" { chosen = model.location.automaticPlaceID }
            }.frame(height: 285).clipShape(RoundedRectangle(cornerRadius: 14))
            HStack {
                Detail(text: model.t("Blue: recent Mac position · gray: manual or last known", "Azul: posición reciente del Mac · gris: manual o última conocida"))
                Spacer(minLength: 5)
                Button(model.t("Recenter", "Centrar")) { recenter += 1 }.buttonStyle(.bordered)
            }
            if layer == "use" { Detail(text: model.t("Larger circles mean more observed foreground time. They are not geographic coverage or a prediction.", "Los círculos grandes indican más tiempo observado en primer plano. No representan cobertura geográfica ni una predicción.")) }
            if pins.filter({ UUID(uuidString: $0.id) != nil }).isEmpty {
                Detail(text: model.t("No places recorded for this layer yet. They appear automatically as Akku observes your Mac. Missing or inaccurate locations are never guessed.", "Todavía no hay lugares registrados para esta capa. Aparecen automáticamente al observar tu Mac. No se inventan posiciones ausentes o imprecisas."))
            }
            if !places.isEmpty {
                Picker(model.t("Inspect a place", "Consultar un lugar"), selection: $chosen) {
                    Text(model.t("Choose a pin or place", "Elige un punto o lugar")).tag(nil as UUID?)
                    ForEach(places) { place in Text(name(place)).tag(Optional(place.id)) }
                }
            }
            if let selected { placeDetail(selected) }
            let unknown = model.placeHistory.events.filter { $0.date >= since && $0.placeID == nil }.count
            if unknown > 0 { Detail(text: model.t("\(unknown) energy events have no reliable location and are not plotted.", "\(unknown) eventos de energía no tienen ubicación fiable y no se dibujan en el mapa.")) }
            Detail(text: model.t("The map uses Apple Maps. History stays on this Mac. Akku shows its own observations while running; it cannot track a powered-off or lost Mac remotely.", "El mapa usa Mapas de Apple. El historial queda en este Mac. Akku muestra sus observaciones mientras funciona; no localiza a distancia un Mac apagado o perdido."))
        }.panel()
    }
    private func placeDetail(_ place: FamiliarPlace) -> some View {
        let s = summary(place.id)
        let events = model.placeHistory.events.filter { $0.placeID == place.id && $0.date >= since }
        let apps = model.placeHistory.appSummary(since: since, placeID: place.id)
        return VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text(name(place)).font(.system(size: 20, weight: .semibold, design: .default))
            HStack { metric(duration(s.activeSeconds / 60), model.t("foreground use", "uso en primer plano")); Spacer(); metric("\(s.charges)", model.t("charging observations", "cargas observadas")) }
            Detail(text: model.t("Observed battery: ", "Batería observada: ") + String(format: "−%.0f pp · +%.0f pp", s.batteryDrop, s.chargeGain) + model.t(" charged", " cargados"))
            if s.hasLowPattern {
                Label(model.t("Low battery repeats here", "Aquí se repite la batería baja"), systemImage: "battery.25percent").foregroundStyle(Palette.amber).fontWeight(.semibold)
                Detail(text: model.t("\(s.lowDays) of \(s.observedDays) observed battery days included ≤10%. Consider charging here before a long session. This pattern is not a shutdown prediction.", "\(s.lowDays) de \(s.observedDays) días observados con batería incluyeron ≤10%. Considera cargar aquí antes de una sesión larga. Este patrón no predice un apagado."))
            } else { Detail(text: model.t("Not enough repeated low-battery days to establish a pattern. Requires 3 days and 90 observed battery minutes.", "Aún no hay suficientes días repetidos de batería baja para establecer un patrón. Requiere 3 días y 90 minutos observados con batería.")) }
            Text(model.t("Apps used here", "Apps usadas aquí")).fontWeight(.semibold)
            if apps.isEmpty { Detail(text: model.t("I haven't observed foreground use here yet.", "Todavía no observé uso en primer plano aquí.")) }
            ForEach(Array(apps.prefix(6))) { app in HStack { Text(app.name); Spacer(); Text(duration(app.foregroundSeconds / 60)).monospacedDigit().foregroundStyle(Palette.mint) } }
            if !events.isEmpty {
                Text(model.t("Recent energy events", "Eventos de energía recientes")).fontWeight(.semibold)
                ForEach(Array(events.suffix(6).reversed())) { event in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(eventTitle(event)).foregroundStyle(event.kind == .charge ? Palette.mint : Palette.amber)
                        Text(event.date, style: .date).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    }
                }
            }
            Detail(text: model.t("Charging requires a measured increase. Low = ≤10%; critical = ≤3%. Even a 0% reading does not prove the computer shut down. Foreground time is approximate and excludes 5-minute inactivity and sleep; whole-Mac battery use cannot be assigned exactly to an app.", "Una carga requiere un aumento medido. Baja = ≤10%; crítica = ≤3%. Incluso una lectura del 0% no demuestra que se apagó. El tiempo en primer plano es aproximado y excluye inactividad de 5 minutos y reposo; el consumo del Mac no se asigna exactamente a cada app."))
        }
    }
    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(value).font(.system(size: 23, weight: .semibold, design: .default)).foregroundStyle(Palette.mint); Detail(text: label) }
    }
    private func eventTitle(_ event: EnergyEvent) -> String {
        let label: String
        switch event.kind {
        case .charge: label = model.t("Charging observed", "Carga observada")
        case .low: label = model.t("Low battery observed", "Batería baja observada")
        case .critical: label = model.t("Critical battery observed", "Batería crítica observada")
        case .zero: label = model.t("0% reported by macOS", "macOS informó un 0%")
        }
        return label + " · \(Int(event.percent.rounded()))%"
    }
}

struct DailyAppsCard: View {
    @ObservedObject var model: BatteryModel
    @State private var offset = 0
    private var day: Date { Calendar.current.date(byAdding: .day, value: -offset, to: Calendar.current.startOfDay(for: model.contextDate))! }
    private var rows: [AppUsageSummary] {
        var archive = model.placeHistory
        archive.apps = archive.apps.filter { $0.day == day }
        return archive.appSummary(since: day)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(model.t("Your daily apps", "Tus apps cada día"), systemImage: "calendar").font(.system(size: 18, weight: .semibold, design: .default))
                Spacer()
                Button { offset = min(59, offset + 1) } label: { Image(systemName: "chevron.left") }.disabled(offset >= 59).accessibilityLabel(model.t("Previous day", "Día anterior"))
                Button { offset = max(0, offset - 1) } label: { Image(systemName: "chevron.right") }.disabled(offset == 0).accessibilityLabel(model.t("Next day", "Día siguiente"))
            }
            Text(day, style: .date).foregroundStyle(Palette.secondary)
            if rows.isEmpty { Detail(text: model.t("No app time recorded for this day yet. Observation is automatic while Akku runs, with or without a charger.", "Aún no hay tiempo de apps registrado este día. La observación es automática mientras Akku funciona, con o sin cargador.")) }
            ForEach(rows) { app in
                HStack(alignment: .top) {
                    Text(app.name).fontWeight(.medium)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(duration(app.foregroundSeconds / 60) + model.t(" foreground", " en primer plano")).foregroundStyle(Palette.mint)
                        Text(duration(app.openSeconds / 60) + model.t(" open", " abierta")).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    }.monospacedDigit()
                }
            }
            Detail(text: model.t("Foreground time with recent activity, not just an open window. Background calls, reading without input, or split-screen work may be undercounted. No messages, tabs or document contents are read.", "Tiempo en primer plano con actividad reciente, no solo una ventana abierta. Las llamadas en segundo plano, lectura sin interacción o pantalla dividida pueden quedar subestimadas. No se leen mensajes, pestañas ni documentos."))
        }.panel()
    }
}
