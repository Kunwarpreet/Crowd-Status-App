import Foundation

@main
struct PopularMarketDiscoveryChecks {
    @MainActor
    static func main() async throws {
        func place(_ id: String, reviews: Int) throws -> GoogleMarketPlace {
            try JSONDecoder().decode(GoogleMarketPlace.self, from: Data("""
            {"id":"\(id)","displayName":{"text":"\(id) Market"},"types":["market"],"userRatingCount":\(reviews)}
            """.utf8))
        }
        func available(_ candidates: [GoogleMarketPlace]) async throws -> [GoogleMarketPlace] {
            // Simulate a listing failing the existing hours/phone validation.
            Array(candidates.filter { $0.id != "unavailable" }.prefix(8))
        }
        let nearby = try place("nearby", reviews: 1000)
        let alternative = try place("alternative", reviews: 100)
        let higherRanked = try place("higher-ranked", reviews: 200)
        let unavailable = try place("unavailable", reviews: 500)
        var requests: [String] = []
        let results = try await HomePopularMarketDiscovery.load(
            candidates: [nearby], excluding: [nearby.id],
            search: { query, token in
                requests.append("\(query)|\(token ?? "first")")
                switch (query, token) {
                case ("popular", nil):
                    return .init(places: [nearby, alternative, unavailable], nextPageToken: "second")
                case ("popular", "second"):
                    return .init(places: [alternative, higherRanked], nextPageToken: nil)
                default:
                    return .init(places: [], nextPageToken: nil)
                }
            }, available: available
        )
        precondition(results.map(\.id) == [higherRanked.id, alternative.id])
        precondition(requests == ["popular|first", "popular|second", "bazaar|first", "farmers|first", "flea|first", "wholesale|first", "vegetable|first", "flower|first", "cloth|first"])

        let full = try (0..<8).map { try place("other-\($0)", reviews: $0) }
        requests = []
        let fullResults = try await HomePopularMarketDiscovery.load(
            candidates: full + [nearby], excluding: [nearby.id],
            search: { query, _ in
                requests.append(query)
                return .init(places: [], nextPageToken: nil)
            }, available: available
        )
        precondition(fullResults.count == 8 && requests.isEmpty)

        // Stop supplemental requests once enough unique eligible results exist.
        requests = []
        let filled = try await HomePopularMarketDiscovery.load(
            candidates: [nearby], excluding: [nearby.id],
            search: { query, _ in
                requests.append(query)
                return .init(places: full + [nearby, unavailable], nextPageToken: "unused")
            }, available: available
        )
        precondition(filled.map(\.id) == fullResults.map(\.id))
        precondition(requests == ["popular"])

        // Errors on supplemental requests retain already loaded alternatives.
        let preserved = try await HomePopularMarketDiscovery.load(
            candidates: [nearby, alternative], excluding: [nearby.id],
            search: { _, _ in throw GoogleMarketDiscovery.RequestError.response },
            available: available
        )
        precondition(preserved.map(\.id) == [alternative.id])

        // Even repeated tokens cannot cause an unbounded request loop.
        var count = 0
        _ = try await HomePopularMarketDiscovery.load(
            candidates: [], excluding: [],
            search: { _, _ in
                count += 1
                return .init(places: [], nextPageToken: "same-token")
            }, available: available
        )
        precondition(count == 24)

        // Known multi-shop markets can have a shopping-area category, no phone,
        // and no opening hours. Fill from two to six without duplicating Nearby.
        for city in ["Amritsar, India", "Bengaluru, India"] {
            let names = Array(PopularMarketCatalog.queries(city: city).prefix(10))
            let listings = try names.enumerated().map { index, name in
                try JSONDecoder().decode(GoogleMarketPlace.self, from: JSONSerialization.data(withJSONObject: [
                    "id": "destination-\(index)", "displayName": ["text": name],
                    "formattedAddress": "Centre, \(city)", "types": ["shopping_mall"],
                    "primaryType": "shopping_mall", "userRatingCount": 100 - index
                ]))
            }
            let nearbyIDs = Set(listings.prefix(4).map(\.id))
            let destinations = try await HomePopularMarketDiscovery.load(
                candidates: Array(listings.prefix(6)), city: city, excluding: nearbyIDs,
                search: { query, _ in
                    .init(places: zip(names, listings).filter { $0.0 == query }.map { $0.1 }, nextPageToken: nil)
                },
                available: { candidates in
                    Array(candidates.filter { HomeMarketPresentation.hasAvailablePopularData(place: $0) }.prefix(8))
                }
            )
            precondition(destinations.count == 6)
            precondition(Set(destinations.map(\.id)).isDisjoint(with: nearbyIDs))
            precondition(destinations.allSatisfy { $0.phoneURL == nil && $0.isPopularMarket })
        }
        precondition(PopularMarketCatalog.queries(city: "Bangalore, India") == PopularMarketCatalog.queries(city: "Bengaluru, India"))
        precondition(PopularMarketCatalog.queries(city: "Unlisted City").isEmpty)

        do {
            _ = try await HomePopularMarketDiscovery.load(
                candidates: [], excluding: [],
                search: { _, _ in throw CancellationError() }, available: available
            )
            preconditionFailure("Cancellation must stop discovery")
        } catch is CancellationError { }
        print("Popular market discovery fallback checks passed")
    }
}
