import Foundation

@main
struct MarketSearchChecks {
    @MainActor
    static func main() async throws {
        func place(_ id: String, name: String, type: String = "market") throws -> GoogleMarketPlace {
            try JSONDecoder().decode(GoogleMarketPlace.self, from: JSONSerialization.data(withJSONObject: [
                "id": id, "displayName": ["text": name], "types": [type],
                "primaryType": type, "formattedAddress": "Amritsar, Punjab, India"
            ]))
        }
        let hall = try place("hall", name: "Hall Bazaar", type: "shopping_mall")
        let guru = try place("guru", name: "Guru Bazaar")
        let shop = try place("shop", name: "Punjabi kheti Store")
        let viewport = GoogleMarketPlace.Viewport(low: .init(latitude: 31.5, longitude: 74.8),
                                                 high: .init(latitude: 31.7, longitude: 75.0))
        let city = "Amritsar, India"
        precondition(hall.phoneURL == nil && guru.phoneURL == nil)
        precondition(GoogleMarketDiscovery.marketSearchText(city: city, query: "  Hall   Bazaar  ") == "Hall Bazaar in Amritsar, India")
        precondition(GoogleMarketDiscovery.marketSearchText(city: city, query: "KR Market") == "KR Market in Amritsar, India")
        precondition(GoogleMarketDiscovery.marketSearchText(city: city, query: "cloth") == "cloth market in Amritsar, India")
        precondition(GoogleMarketDiscovery.marketSearchText(city: city, query: "  ") == "markets in Amritsar, India")

        var viewportRequests: [String] = []
        var pageRequests: [String] = []
        let service = MarketSearchService(
            viewport: { city in viewportRequests.append(city); return viewport },
            page: { city, query, _, token in
                pageRequests.append("\(city)|\(query)|\(token ?? "first")")
                if query == "empty" { return .init(places: [shop], nextPageToken: nil) }
                switch token {
                case nil: return .init(places: [shop], nextPageToken: "second")
                case "second": return .init(places: [hall, hall], nextPageToken: "third")
                default: return .init(places: [hall, guru], nextPageToken: nil)
                }
            },
            resolve: { HomeMarketPresentation.hasAvailablePopularData(place: $0) ? $0 : nil }
        )
        let store = MarketSearchStore(service: service)
        await store.search(city: city, query: " Hall Bazaar ")
        // Auto-skip the shops-only page. Missing phone and hours do not hide Hall.
        precondition(store.markets.map(\.id) == [hall.id])
        precondition(store.nextPageToken == "third" && !store.isLoading && store.errorMessage == nil)
        precondition(pageRequests == ["Amritsar, India|Hall Bazaar|first", "Amritsar, India|Hall Bazaar|second"])
        await store.loadMore()
        precondition(store.markets.map(\.id) == [hall.id, guru.id])
        precondition(store.nextPageToken == nil && !store.isLoading)
        await store.search(city: city, query: "empty")
        precondition(store.markets.isEmpty && store.nextPageToken == nil && store.errorMessage == nil)
        precondition(viewportRequests == [city])
        await store.search(city: "Bengaluru, India", query: "empty")
        precondition(viewportRequests == [city, "Bengaluru, India"])

        // Results from a slow earlier search cannot replace a more recent query.
        let (started, signal) = AsyncStream<Void>.makeStream()
        var oldResponse: CheckedContinuation<GoogleMarketDiscovery.Page, Never>?
        let delayed = MarketSearchService(
            viewport: { _ in viewport },
            page: { _, query, _, _ in
                if query == "old" {
                    return await withCheckedContinuation { continuation in
                        oldResponse = continuation
                        signal.yield(())
                    }
                }
                return .init(places: [guru], nextPageToken: nil)
            },
            resolve: { HomeMarketPresentation.hasAvailablePopularData(place: $0) ? $0 : nil }
        )
        let newest = MarketSearchStore(service: delayed)
        let older = Task { await newest.search(city: city, query: "old") }
        for await _ in started { break }
        await newest.search(city: city, query: "new")
        precondition(newest.markets.map(\.id) == [guru.id])
        oldResponse?.resume(returning: .init(places: [hall], nextPageToken: nil))
        await older.value
        signal.finish()
        precondition(newest.markets.map(\.id) == [guru.id] && !newest.isLoading)

        let failing = MarketSearchStore(service: .init(
            viewport: { _ in throw GoogleMarketDiscovery.RequestError.cityNotFound },
            page: { _, _, _, _ in preconditionFailure("A failed city lookup must not search") },
            resolve: { $0 }
        ))
        await failing.search(city: "Missing city", query: "Hall Bazaar")
        precondition(failing.markets.isEmpty && failing.errorMessage != nil && !failing.isLoading)
        print("Market search checks passed")
    }
}
