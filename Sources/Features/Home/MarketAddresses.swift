import Foundation
import Combine

@MainActor
final class MarketAddressStore: ObservableObject {
    static let shared = MarketAddressStore()

    @Published private var addresses: [String: String] = [:]
    @Published private var failures: Set<String> = []
    private var loading: Set<String> = []
    private var expiresAt: [String: Date] = [:]

    func address(for marketName: String) -> String? { addresses[marketName] }

    func label(for marketName: String) -> String {
        addresses[marketName] ?? (failures.contains(marketName) ? "Address unavailable" : "Loading address…")
    }

    func load(marketName: String) async {
        guard !loading.contains(marketName),
              (expiresAt[marketName] ?? .distantPast) <= Date() else { return }
        loading.insert(marketName)
        defer { loading.remove(marketName) }
        // Keep the shared request alive when a search row disappears during navigation.
        // The detail screen observes the same store and receives its completed address.
        let request = Task { try await GoogleMarketAddresses.fetch(marketName: marketName) }
        do {
            let address = try await request.value
            addresses[marketName] = address
            failures.remove(marketName)
            expiresAt[marketName] = Date().addingTimeInterval(300)
        } catch is CancellationError {
            // Allow the next appearance to retry if the request itself was cancelled.
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            if addresses[marketName] == nil { failures.insert(marketName) }
            expiresAt[marketName] = Date().addingTimeInterval(30)
        }
    }
}

enum GoogleMarketAddresses {
    // Verified Google listings; only Place IDs are stored, not address responses.
    static let placeIDs: [String: String] = [
        "Raja Market": "ChIJPc7ToDMXrjsRe8YoBeRWLA4",
        "KR Market": "ChIJ_xC6VOEVrjsRy_ZNwGx87Ac",
        "Chickpet Market": "ChIJU7WvbgAXrjsR0EVUMCsL4EQ",
        "Russell Market": GoogleMarketHours.russellPlaceID,
        "Jayanagar Market": "ChIJU7PCQbwVrjsRQapyxEblmF0",
        "Sunday Market": "ChIJ6UjQKAgWrjsRyMaQpOJo2V4"
    ]

    private struct Place: Decodable {
        let id: String?
        let formattedAddress: String?
    }

    private enum AddressError: Error {
        case missingConfiguration, missingListing, requestFailed, missingAddress
    }

    static func fetch(marketName: String) async throws -> String {
        guard let placeID = placeIDs[marketName] else { throw AddressError.missingListing }
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GooglePlacesAPIKey") as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !key.contains("$(") else { throw AddressError.missingConfiguration }
        var request = URLRequest(url: URL(string: "https://places.googleapis.com/v1/places/\(placeID)?languageCode=en")!)
        request.timeoutInterval = 20
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        request.setValue("id,formattedAddress", forHTTPHeaderField: "X-Goog-FieldMask")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AddressError.requestFailed
        }
        return try address(from: data, expectedPlaceID: placeID)
    }

    static func address(from data: Data, expectedPlaceID: String) throws -> String {
        let place = try JSONDecoder().decode(Place.self, from: data)
        guard place.id == expectedPlaceID,
              let address = place.formattedAddress?.trimmingCharacters(in: .whitespacesAndNewlines),
              !address.isEmpty else { throw AddressError.missingAddress }
        return address
    }
}
