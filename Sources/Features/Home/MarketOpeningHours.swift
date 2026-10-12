import Foundation
import Combine

struct MarketOpeningStatus {
    let isOpen: Bool?
    let nextOpening: Date?
    let nextClosing: Date?
    let expiresAt: Date

    static var unavailable: Self {
        Self(isOpen: nil, nextOpening: nil, nextClosing: nil, expiresAt: Date().addingTimeInterval(30))
    }

    var label: String {
        label(at: Date())
    }

    func label(at now: Date) -> String {
        guard let isOpen else { return "Hours unavailable" }
        guard let transition = isOpen ? nextClosing : nextOpening else {
            return isOpen ? "Open" : "Closed"
        }
        let prefix = isOpen ? "Open till" : "Closed till"

        // These markets are in Bengaluru; don't format hours in the device's timezone.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = calendar.component(.minute, from: transition) == 0 ? "ha" : "h:mma"
        let time = formatter.string(from: transition).lowercased()
        if calendar.isDate(transition, inSameDayAs: now) {
            return "\(prefix) \(time)"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(transition, inSameDayAs: tomorrow) {
            return "\(prefix) tomorrow \(time)"
        }
        formatter.dateFormat = "EEE"
        return "\(prefix) \(formatter.string(from: transition)) \(time)"
    }
}

@MainActor
final class MarketOpeningHoursStore: ObservableObject {
    @Published private(set) var statuses: [String: MarketOpeningStatus] = [:]
    private var isRefreshing = false

    func refresh(markets: [(String, String)], force: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let pending = markets.filter { force || (statuses[$0.0]?.expiresAt ?? .distantPast) <= Date() }
        await withTaskGroup(of: (String, MarketOpeningStatus).self) { group in
            for (id, name) in pending {
                // Never continue showing an expired open/closed state during a refresh.
                statuses[id] = nil
                group.addTask {
                    do {
                        return (id, try await GoogleMarketHours.fetch(marketName: name))
                    } catch {
                        return (id, .unavailable)
                    }
                }
            }
            for await (id, status) in group {
                guard !Task.isCancelled else { continue }
                statuses[id] = status
            }
        }
    }
}

enum GoogleMarketHours {
    // Confirmed listing on MF Norrona St, Shivaji Nagar. Place IDs survive name changes.
    static let russellPlaceID = "ChIJwQdZj2EWrjsRvUuO1AgrS18"
    private struct SearchResponse: Decodable {
        let places: [Place]?
    }

    private struct Place: Decodable {
        struct DisplayName: Decodable { let text: String }
        struct Hours: Decodable {
            let openNow: Bool?
            let nextOpenTime: String?
            let nextCloseTime: String?
        }
        let id: String?
        let displayName: DisplayName?
        let businessStatus: String?
        let currentOpeningHours: Hours?
    }

    private enum FetchError: Error {
        case missingConfiguration, requestFailed, ambiguousPlace
    }

    static func fetch(marketName: String) async throws -> MarketOpeningStatus {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GooglePlacesAPIKey") as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !key.contains("$(") else { throw FetchError.missingConfiguration }

        var request = URLRequest(url: URL(string: "https://places.googleapis.com/v1/places:searchText")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        request.setValue(
            "places.displayName,places.businessStatus,places.currentOpeningHours",
            forHTTPHeaderField: "X-Goog-FieldMask"
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "textQuery": "\(marketName), Bengaluru, Karnataka, India",
            "languageCode": "en",
            "regionCode": "IN",
            "locationRestriction": ["rectangle": [
                "low": ["latitude": 12.8, "longitude": 77.4],
                "high": ["latitude": 13.2, "longitude": 77.8]
            ]]
        ])
        if marketName == "Russell Market" {
            request.url = URL(string: "https://places.googleapis.com/v1/places/\(russellPlaceID)?languageCode=en")!
            request.httpMethod = "GET"
            request.httpBody = nil
            request.setValue("id,businessStatus,currentOpeningHours", forHTTPHeaderField: "X-Goog-FieldMask")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FetchError.requestFailed
        }
        if marketName == "Russell Market" {
            return try detailsStatus(from: data)
        }
        return try status(from: data, marketName: marketName)
    }

    static func detailsStatus(from data: Data, now: Date = Date()) throws -> MarketOpeningStatus {
        let place = try JSONDecoder().decode(Place.self, from: data)
        guard place.id == russellPlaceID else { throw FetchError.ambiguousPlace }
        return openingStatus(for: place, now: now)
    }

    static func status(from data: Data, marketName: String, now: Date = Date()) throws -> MarketOpeningStatus {
        let result = try JSONDecoder().decode(SearchResponse.self, from: data)
        // Google's Russell Market listing includes its neighborhood in the name.
        let listingNames = marketName == "Russell Market"
            ? [marketName, "Russell Market, Shivajinagar"] : [marketName]
        let matches = (result.places ?? []).filter { place in
            listingNames.contains { name in
                place.displayName?.text.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
        }
        // Generic names can match unrelated shops. Only accept one exact local match.
        guard matches.count == 1, let place = matches.first else { throw FetchError.ambiguousPlace }
        return openingStatus(for: place, now: now)
    }

    private static func openingStatus(for place: Place, now: Date) -> MarketOpeningStatus {
        if place.businessStatus == "CLOSED_PERMANENTLY" || place.businessStatus == "CLOSED_TEMPORARILY" {
            return MarketOpeningStatus(isOpen: false, nextOpening: nil, nextClosing: nil, expiresAt: now.addingTimeInterval(300))
        }
        guard let hours = place.currentOpeningHours, let openNow = hours.openNow else {
            return .unavailable
        }
        let nextOpen = timestamp(hours.nextOpenTime)
        let nextClose = timestamp(hours.nextCloseTime)
        let transition = openNow ? nextClose : nextOpen
        return MarketOpeningStatus(
            isOpen: openNow,
            nextOpening: nextOpen,
            nextClosing: nextClose,
            expiresAt: min(now.addingTimeInterval(300), transition ?? .distantFuture)
        )
    }

    private static func timestamp(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}
