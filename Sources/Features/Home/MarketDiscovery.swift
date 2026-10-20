import Foundation
import Combine
import CoreLocation
import SwiftUI
import MapKit

struct GoogleMarketPlace: Decodable, Hashable, Identifiable {
    struct LocalizedText: Decodable, Hashable { let text: String }
    struct Coordinate: Decodable, Hashable { let latitude: Double; let longitude: Double }
    struct Viewport: Decodable, Hashable { let low: Coordinate; let high: Coordinate }
    struct Photo: Decodable, Hashable, Identifiable {
        struct Author: Decodable, Hashable { let displayName: String; let uri: String? }
        let name: String
        let authorAttributions: [Author]?
        var id: String { name }
    }
    let id: String
    let displayName: LocalizedText?
    let formattedAddress: String?
    let location: Coordinate?
    let viewport: Viewport?
    let types: [String]?
    let rating: Double?
    let userRatingCount: Int?
    let nationalPhoneNumber: String?
    let internationalPhoneNumber: String?
    let editorialSummary: LocalizedText?
    let photos: [Photo]?

    var name: String { displayName?.text ?? "Market" }
    var isMarket: Bool {
        let categories = Set(types ?? [])
        if !categories.isDisjoint(with: ["market", "farmers_market", "flea_market"]) { return true }
        let words = name.lowercased()
        let hasMarketName = words.range(of: #"(^|[\s-])(market|bazaar|bazar)([\s-]|$)"#, options: .regularExpression) != nil
        let transitTypes: Set<String> = ["bus_stop", "bus_station", "subway_station", "train_station", "transit_station", "parking"]
        return hasMarketName && categories.isDisjoint(with: transitTypes)
    }
    var isHomeMarket: Bool {
        let categories = Set(types ?? [])
        if !categories.isDisjoint(with: ["market", "farmers_market", "flea_market"]) { return true }
        let unrelated: Set<String> = ["restaurant", "food_store", "grocery_store", "supermarket", "general_store", "clothing_store", "book_store", "transportation_service", "parking", "hotel", "lodging"]
        return isMarket && categories.isDisjoint(with: unrelated)
    }
    var phoneURL: URL? {
        guard let number = internationalPhoneNumber ?? nationalPhoneNumber else { return nil }
        let normalized = number.filter { $0.isNumber || $0 == "+" }
        return normalized.isEmpty ? nil : URL(string: "tel:\(normalized)")
    }
    func distance(from location: CLLocation?) -> String? {
        guard let origin = location, let coordinate = self.location else { return nil }
        let meters = origin.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        return MarketJourney.distanceLabel(meters)
    }
}

struct MarketJourney {
    let distance: Double
    let travelTime: TimeInterval
    static func distanceLabel(_ meters: Double) -> String {
        String(format: meters < 1000 ? "%.2f km" : "%.1f km", meters / 1000)
    }
    var distanceLabel: String { Self.distanceLabel(distance) }
    var timeLabel: String {
        let minutes = max(1, Int(ceil(travelTime / 60)))
        return minutes < 60 ? "\(minutes) min drive" : "\(minutes / 60) hr\(minutes % 60 == 0 ? "" : " \(minutes % 60) min") drive"
    }
}

@MainActor
final class MarketJourneyStore: ObservableObject {
    static let shared = MarketJourneyStore()
    @Published private(set) var journeys: [String: MarketJourney] = [:]
    private var origin: CLLocation?
    private var updatedAt: Date = .distantPast
    private var generation = UUID()

    func distanceLabel(for place: GoogleMarketPlace, from location: CLLocation?) -> String? {
        guard let location else { return nil }
        if let origin, location.distance(from: origin) < 100, let journey = journeys[place.id] {
            return journey.distanceLabel
        }
        return place.distance(from: location)
    }

    func refresh(places: [GoogleMarketPlace], location: CLLocation?) async {
        guard let location else { generation = UUID(); journeys = [:]; origin = nil; return }
        let moved = origin.map { location.distance(from: $0) >= 100 } ?? true
        if moved || Date().timeIntervalSince(updatedAt) >= 300 {
            generation = UUID()
            journeys = [:]
            origin = location
            updatedAt = Date()
        }
        let requestGeneration = generation
        for place in places where journeys[place.id] == nil {
            guard !Task.isCancelled, let destination = place.location else { continue }
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)))
            request.transportType = .automobile
            request.departureDate = Date()
            let directions = MKDirections(request: request)
            do {
                let eta = try await withTaskCancellationHandler {
                    try await directions.calculateETA()
                } onCancel: { directions.cancel() }
                try Task.checkCancellation()
                guard generation == requestGeneration else { return }
                journeys[place.id] = MarketJourney(distance: eta.distance, travelTime: eta.expectedTravelTime)
            } catch {
                // Keep the real straight-line distance if routing is unavailable; never invent an ETA.
                if Task.isCancelled { return }
            }
        }
    }
}

enum GoogleMarketDiscovery {
    struct Page: Decodable { let places: [GoogleMarketPlace]?; let nextPageToken: String? }
    enum RequestError: LocalizedError {
        case configuration, response, cityNotFound, wrongPlace
        var errorDescription: String? {
            switch self {
            case .configuration: "Market search is not configured."
            case .response: "Couldn’t load markets. Please try again."
            case .cityNotFound: "Couldn’t find this city. Try a city and country, such as Bengaluru, India."
            case .wrongPlace: "Couldn’t load this market’s details."
            }
        }
    }
    static func request(url: URL, fields: String? = nil) throws -> URLRequest {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GooglePlacesAPIKey") as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !key.contains("$(") else {
            throw RequestError.configuration
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        if let fields { request.setValue(fields, forHTTPHeaderField: "X-Goog-FieldMask") }
        return request
    }
    static func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw RequestError.response }
        return data
    }
    static func search(body: [String: Any], fields: String) async throws -> Page {
        var request = try request(url: URL(string: "https://places.googleapis.com/v1/places:searchText")!, fields: fields)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try JSONDecoder().decode(Page.self, from: await data(for: request))
    }
    static func cityViewport(_ city: String) async throws -> GoogleMarketPlace.Viewport {
        let page = try await search(body: ["textQuery": city, "includedType": "locality", "strictTypeFiltering": true, "pageSize": 1], fields: "places.id,places.viewport")
        guard let viewport = page.places?.first?.viewport else { throw RequestError.cityNotFound }
        return viewport
    }
    static func markets(city: String, query: String, viewport: GoogleMarketPlace.Viewport, pageToken: String?) async throws -> Page {
        var body: [String: Any] = [
            "textQuery": query.isEmpty ? "markets in \(city)" : "\(query) market in \(city)",
            "languageCode": "en", "pageSize": 20,
            "locationRestriction": ["rectangle": [
                "low": ["latitude": viewport.low.latitude, "longitude": viewport.low.longitude],
                "high": ["latitude": viewport.high.latitude, "longitude": viewport.high.longitude]
            ]]
        ]
        if let pageToken { body["pageToken"] = pageToken }
        return try await search(body: body, fields: "places.id,places.displayName,places.formattedAddress,places.location,places.types,places.rating,places.userRatingCount,places.photos,nextPageToken")
    }
    static func nearbyMarkets(location: CLLocation) async throws -> Page {
        try await search(body: [
            "textQuery": "markets", "languageCode": "en", "pageSize": 20,
            "rankPreference": "DISTANCE", "includedType": "market", "strictTypeFiltering": true,
            "locationBias": ["circle": [
                "center": ["latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude],
                "radius": 8000.0
            ]]
        ], fields: "places.id,places.displayName,places.formattedAddress,places.location,places.types,places.rating,places.userRatingCount,places.photos")
    }
    static func nearby(_ places: [GoogleMarketPlace], from origin: CLLocation) -> [GoogleMarketPlace] {
        merging([], places).filter(\.isHomeMarket).filter { place in
            guard let coordinate = place.location else { return false }
            return origin.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) <= 8000
        }.sorted {
            func distance(_ place: GoogleMarketPlace) -> Double {
                guard let coordinate = place.location else { return .infinity }
                return origin.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            }
            return distance($0) == distance($1) ? $0.id < $1.id : distance($0) < distance($1)
        }
    }
    static func popular(_ places: [GoogleMarketPlace]) -> [GoogleMarketPlace] {
        merging([], places).filter(\.isHomeMarket).sorted {
            if ($0.userRatingCount ?? 0) != ($1.userRatingCount ?? 0) {
                return ($0.userRatingCount ?? 0) > ($1.userRatingCount ?? 0)
            }
            if ($0.rating ?? 0) != ($1.rating ?? 0) { return ($0.rating ?? 0) > ($1.rating ?? 0) }
            return $0.id < $1.id
        }
    }
    static func details(placeID: String) async throws -> (GoogleMarketPlace, MarketOpeningStatus) {
        let request = try request(url: URL(string: "https://places.googleapis.com/v1/places/\(placeID)?languageCode=en")!, fields: "id,displayName,formattedAddress,location,types,rating,nationalPhoneNumber,internationalPhoneNumber,editorialSummary,photos,businessStatus,currentOpeningHours,regularOpeningHours,timeZone")
        let data = try await data(for: request)
        let place = try JSONDecoder().decode(GoogleMarketPlace.self, from: data)
        guard place.id == placeID else { throw RequestError.wrongPlace }
        return (place, try GoogleMarketHours.detailsStatus(from: data, expectedPlaceID: placeID))
    }
    static func photoData(name: String) async throws -> Data {
        struct PhotoResponse: Decodable { let photoUri: String }
        let request = try request(url: URL(string: "https://places.googleapis.com/v1/\(name)/media?maxWidthPx=1200&skipHttpRedirect=true")!)
        let response = try JSONDecoder().decode(PhotoResponse.self, from: await data(for: request))
        guard let url = URL(string: response.photoUri), url.scheme == "https" else { throw RequestError.response }
        return try await data(for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
    }
    static func merging(_ existing: [GoogleMarketPlace], _ incoming: [GoogleMarketPlace]) -> [GoogleMarketPlace] {
        var seen = Set(existing.map(\.id))
        return existing + incoming.filter { $0.isMarket && seen.insert($0.id).inserted }
    }
}

enum HomeMarketPresentation {
    static func locationLabel(area: String?, city: String) -> String {
        let city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let area = area?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return area.isEmpty || area.caseInsensitiveCompare(city) == .orderedSame ? city : "\(area), \(city)"
    }
    static func hasAvailableData(place: GoogleMarketPlace?, status: MarketOpeningStatus?) -> Bool {
        guard let place, let status, status.isOpen != nil,
              let name = place.displayName?.text, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let address = place.formattedAddress, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return status.todayOpenIntervals() != nil
    }
}

@MainActor
final class MarketCityStore: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    static let shared = MarketCityStore()
    @Published private(set) var city = "Bengaluru, India"
    @Published private(set) var hasResolvedCity = false
    @Published private(set) var areaName: String?
    @Published private(set) var cityName = ""
    var homeLocationLabel: String { HomeMarketPresentation.locationLabel(area: areaName, city: cityName) }
    @Published private(set) var location: CLLocation?
    @Published private(set) var isLocating = false
    @Published private(set) var locationMessage: String?
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var hasManualCity = false
    private var generation = 0
    private var trackingOwners: Set<String> = []
    private var isTracking: Bool { !trackingOwners.isEmpty }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
    }
    func startTracking(owner: String = "home") {
        guard !hasManualCity else { return }
        trackingOwners.insert(owner)
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.startUpdatingLocation()
        default: break
        }
        detectCity(automatically: true)
    }
    func stopTracking(owner: String = "home") {
        trackingOwners.remove(owner)
        if !isTracking { manager.stopUpdatingLocation() }
    }
    func useCity(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        generation += 1
        hasManualCity = true
        trackingOwners.removeAll()
        manager.stopUpdatingLocation()
        geocoder.cancelGeocode()
        hasResolvedCity = true
        areaName = nil
        cityName = trimmed.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
        city = trimmed
        location = nil
        isLocating = false
        locationMessage = nil
    }
    func detectCity(automatically: Bool = false) {
        if isLocating || (automatically && (hasManualCity || location != nil)) { return }
        if !automatically { hasManualCity = false }
        isLocating = true
        locationMessage = nil
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            if isTracking { manager.startUpdatingLocation() } else { manager.requestLocation() }
        default:
            isLocating = false
            locationMessage = "Location is unavailable. Enter your city below."
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isLocating else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if isTracking { manager.startUpdatingLocation() } else { manager.requestLocation() }
        case .denied, .restricted:
            isLocating = false
            locationMessage = "Location is unavailable. Enter your city below."
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard (isLocating || isTracking), !hasManualCity, let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        if !isLocating, let previous = self.location, previous.distance(from: location) < 100 { return }
        let requestGeneration = generation
        Task { @MainActor in
            do {
                guard let placemark = try await geocoder.reverseGeocodeLocation(location).first,
                      let city = placemark.locality else { throw GoogleMarketDiscovery.RequestError.cityNotFound }
                guard requestGeneration == generation else { return }
                cityName = city
                areaName = placemark.subLocality ?? placemark.thoroughfare
                self.city = [city, placemark.country].compactMap { $0 }.joined(separator: ", ")
                self.location = location
                hasResolvedCity = true
                locationMessage = nil
            } catch {
                guard requestGeneration == generation else { return }
                locationMessage = "Couldn’t detect your city. Enter it below."
            }
            isLocating = false
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard isLocating else { return }
        isLocating = false
        locationMessage = "Couldn’t detect your city. Enter it below."
    }
}

@MainActor
final class MarketSearchStore: ObservableObject {
    @Published private(set) var markets: [GoogleMarketPlace] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var nextPageToken: String?
    private var generation = UUID()
    private var city = ""
    private var query = ""
    private var viewport: GoogleMarketPlace.Viewport?
    private var viewportCity = ""

    func search(city: String, query: String) async {
        let generation = UUID()
        self.generation = generation
        self.city = city
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        markets = []
        nextPageToken = nil
        errorMessage = nil
        isLoading = true
        do {
            try await Task.sleep(for: .milliseconds(350))
            let viewport: GoogleMarketPlace.Viewport
            if viewportCity == city, let cached = self.viewport { viewport = cached }
            else { viewport = try await GoogleMarketDiscovery.cityViewport(city) }
            try Task.checkCancellation()
            guard self.generation == generation else { return }
            self.viewport = viewport
            viewportCity = city
            let page = try await GoogleMarketDiscovery.markets(city: city, query: self.query, viewport: viewport, pageToken: nil)
            try Task.checkCancellation()
            guard self.generation == generation else { return }
            markets = GoogleMarketDiscovery.merging([], page.places ?? [])
            nextPageToken = page.nextPageToken
            isLoading = false
        } catch {
            guard self.generation == generation else { return }
            isLoading = false
            if !(error is CancellationError) { errorMessage = error.localizedDescription }
        }
    }
    func loadMore() async {
        guard !isLoading, let token = nextPageToken, let viewport else { return }
        let generation = self.generation
        isLoading = true
        errorMessage = nil
        do {
            let page = try await GoogleMarketDiscovery.markets(city: city, query: query, viewport: viewport, pageToken: token)
            try Task.checkCancellation()
            guard self.generation == generation else { return }
            markets = GoogleMarketDiscovery.merging(markets, page.places ?? [])
            nextPageToken = page.nextPageToken
        } catch {
            guard self.generation == generation else { return }
            if !(error is CancellationError) { errorMessage = error.localizedDescription }
        }
        if self.generation == generation { isLoading = false }
    }
}

struct HomeMarketContext {
    let city: String
    let location: CLLocation?
    func matches(city: String, location: CLLocation?) -> Bool {
        guard self.city == city else { return false }
        switch (self.location, location) {
        case (nil, nil): return true
        case let (previous?, current?): return previous.distance(from: current) < 100
        default: return false
        }
    }
}

@MainActor
final class HomeMarketStore: ObservableObject {
    static let shared = HomeMarketStore()
    @Published private(set) var nearby: [GoogleMarketPlace] = []
    @Published private(set) var popular: [GoogleMarketPlace] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private var generation = UUID()
    private var loadedContext: HomeMarketContext?

    func refresh(city: String, location: CLLocation?, hasResolvedCity: Bool, force: Bool = false) async {
        guard hasResolvedCity else { return }
        if !force, loadedContext?.matches(city: city, location: location) == true { return }
        let generation = UUID()
        self.generation = generation
        errorMessage = nil
        isLoading = true
        defer { if self.generation == generation { isLoading = false } }
        do {
            let viewport = try await GoogleMarketDiscovery.cityViewport(city)
            var all: [GoogleMarketPlace] = []
            var token: String?
            repeat {
                let page = try await GoogleMarketDiscovery.markets(city: city, query: "", viewport: viewport, pageToken: token)
                try Task.checkCancellation()
                guard self.generation == generation else { return }
                all = GoogleMarketDiscovery.merging(all, page.places ?? [])
                token = page.nextPageToken
            } while token != nil && all.count < 60
            let popularCandidates = GoogleMarketDiscovery.popular(all)
            let availablePopular = try await availableMarkets(popularCandidates, limit: 8)
            guard self.generation == generation else { return }
            var availableNearby: [GoogleMarketPlace] = []
            if let location {
                // Circle bias can return places outside its radius; filter explicitly.
                let page = try await GoogleMarketDiscovery.nearbyMarkets(location: location)
                try Task.checkCancellation()
                guard self.generation == generation else { return }
                let nearbyCandidates = GoogleMarketDiscovery.nearby(GoogleMarketDiscovery.merging(all, page.places ?? []), from: location)
                availableNearby = try await availableMarkets(nearbyCandidates, limit: 4)
                guard self.generation == generation else { return }
            }
            try Task.checkCancellation()
            guard self.generation == generation else { return }
            // Commit both lists together; navigation back keeps the last successful result.
            popular = availablePopular
            nearby = availableNearby
            loadedContext = HomeMarketContext(city: city, location: location)
        } catch {
            guard self.generation == generation, !(error is CancellationError) else { return }
            errorMessage = error.localizedDescription
        }
    }
    private func availableMarkets(_ candidates: [GoogleMarketPlace], limit: Int) async throws -> [GoogleMarketPlace] {
        var available: [GoogleMarketPlace] = []
        for candidate in candidates {
            try Task.checkCancellation()
            await MarketDetailsStore.shared.load(placeID: candidate.id)
            try Task.checkCancellation()
            if MarketDetailsStore.shared.isAvailableForHome(placeID: candidate.id) {
                available.append(MarketDetailsStore.shared.places[candidate.id] ?? candidate)
                if available.count == limit { break }
            }
        }
        return available
    }

}

@MainActor
final class MarketDetailsStore: ObservableObject {
    static let shared = MarketDetailsStore()
    @Published private(set) var places: [String: GoogleMarketPlace] = [:]
    @Published private(set) var statuses: [String: MarketOpeningStatus] = [:]
    @Published private(set) var failures: Set<String> = []
    private var loading: Set<String> = []
    private var expires: [String: Date] = [:]
    func isAvailableForHome(placeID: String) -> Bool {
        !failures.contains(placeID) && HomeMarketPresentation.hasAvailableData(place: places[placeID], status: statuses[placeID])
    }
    func load(placeID: String) async {
        guard !loading.contains(placeID), (expires[placeID] ?? .distantPast) <= Date() else { return }
        loading.insert(placeID)
        defer { loading.remove(placeID) }
        do {
            let (place, status) = try await GoogleMarketDiscovery.details(placeID: placeID)
            places[placeID] = place
            statuses[placeID] = status
            failures.remove(placeID)
            expires[placeID] = status.expiresAt
        } catch {
            statuses[placeID] = .unavailable
            failures.insert(placeID)
            expires[placeID] = Date().addingTimeInterval(30)
        }
    }
}

#if os(iOS)
@MainActor
final class MarketPhotoStore: ObservableObject {
    static let shared = MarketPhotoStore()
    @Published private(set) var images: [String: UIImage] = [:]
    @Published private(set) var failures: Set<String> = []
    private var loading: [String: Task<Void, Never>] = [:]

    func load(name: String) async {
        guard images[name] == nil else { return }
        if let task = loading[name] {
            await task.value
            return
        }
        // The shared request survives navigation and serves Home and detail views.
        let task = Task {
            defer { loading[name] = nil }
            failures.remove(name)
            do {
                let data = try await GoogleMarketDiscovery.photoData(name: name)
                guard let image = UIImage(data: data) else {
                    failures.insert(name)
                    return
                }
                images[name] = image
            } catch {
                failures.insert(name)
            }
        }
        loading[name] = task
        await task.value
    }
}

struct GoogleMarketPhotoView: View {
    let photo: GoogleMarketPlace.Photo
    var compact = false
    var showsAuthorAttributions = true
    @ObservedObject private var photos = MarketPhotoStore.shared
    private var image: UIImage? { photos.images[photo.name] }
    private var failed: Bool { photos.failures.contains(photo.name) }
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else {
                    Color(.systemGray6)
                    if failed { Image(systemName: "storefront").font(.system(size: 36)).foregroundStyle(.secondary) }
                    else { ProgressView() }
                }
                if showsAuthorAttributions, image != nil, let authors = photo.authorAttributions, !authors.isEmpty {
                    HStack(spacing: 4) {
                        if !compact { Text("Photo:") }
                        ForEach(Array(authors.enumerated()), id: \.offset) { _, author in
                            if let uri = author.uri, let url = URL(string: uri.hasPrefix("//") ? "https:\(uri)" : uri) {
                                Link(author.displayName, destination: url)
                            } else { Text(author.displayName) }
                        }
                    }
                    .font(.system(size: compact ? 7 : 10)).foregroundStyle(.white).tint(.white)
                    .lineLimit(compact ? 1 : nil)
                    .padding(compact ? 3 : 6).background(.black.opacity(0.65))
                    .padding(.bottom, compact ? 0 : 36)
                }
            }
        }
        .task(id: photo.id) {
            await photos.load(name: photo.name)
        }
    }
}

#endif
