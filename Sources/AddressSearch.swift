import MapKit
import Combine

struct AddressCandidate: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let latitude: Double
    let longitude: Double
}
final class AddressSearch: ObservableObject {
    @Published var searching = false
    @Published var results: [AddressCandidate] = []
    @Published var failed = false
    private var search: MKLocalSearch?
    func find(_ query: String) {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 3 else { return }
        search?.cancel(); searching = true; results = []; failed = false
        let request = MKLocalSearch.Request(); request.naturalLanguageQuery = text
        request.resultTypes = [.address, .pointOfInterest]
        let operation = MKLocalSearch(request: request); search = operation
        operation.start { [weak self, weak operation] response, error in
            DispatchQueue.main.async {
                guard let self, self.search === operation else { return }
                self.searching = false; self.failed = error != nil || response?.mapItems.isEmpty != false
                self.results = Array((response?.mapItems ?? []).prefix(8)).map { item in
                    let p = item.placemark
                    return AddressCandidate(title: item.name ?? p.title ?? text,
                                            detail: [p.thoroughfare, p.subThoroughfare, p.locality, p.administrativeArea, p.country].compactMap { $0 }.joined(separator: ", "),
                                            latitude: p.coordinate.latitude, longitude: p.coordinate.longitude)
                }
            }
        }
    }
    func cancel() { search?.cancel(); search = nil; searching = false }
}
