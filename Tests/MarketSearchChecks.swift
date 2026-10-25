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

        // Opening Search shows seven genuine suggestions, filters immediately,
        // and clearing restores them without another request.
        let suggested = try (0..<9).map { try place("suggested-\($0)", name: "Local \($0) Market") }
        var suggestionRequests = 0
        let presearch = MarketSearchStore(service: .init(
            viewport: { _ in viewport },
            page: { _, _, _, _ in
                suggestionRequests += 1
                return .init(places: [], nextPageToken: nil)
            },
            resolve: { HomeMarketPresentation.hasAvailablePopularData(place: $0) ? $0 : nil }
        ))
        presearch.seedSuggestions([hall, guru, shop] + suggested, city: city)
        precondition(presearch.matchingMarkets(city: city, query: "").count == 7)
        precondition(!presearch.suggestions.contains { $0.id == shop.id })
        precondition(presearch.matchingMarkets(city: city, query: " hall bazar ").map(\.id) == [hall.id])
        precondition(presearch.matchingMarkets(city: city, query: "GURU").map(\.id) == [guru.id])
        precondition(presearch.matchingMarkets(city: city, query: "unknown").isEmpty)
        precondition(presearch.matchingMarkets(city: "Bengaluru, India", query: "").isEmpty)
        await presearch.search(city: city, query: "")
        precondition(presearch.markets.count == 7 && !presearch.isLoading && suggestionRequests == 0)
        await presearch.search(city: city, query: "Hall")
        precondition(presearch.matchingMarkets(city: city, query: "Hall").map(\.id) == [hall.id])
        await presearch.search(city: city, query: "  ")
        precondition(presearch.markets.count == 7 && suggestionRequests == 1)
        precondition(presearch.nextPageToken == nil)

        // A cold Search without Home data fills seven suggestions across pages.
        var initialPages = 0
        let cold = MarketSearchStore(service: .init(
            viewport: { _ in viewport },
            page: { _, _, _, token in
                initialPages += 1
                return token == nil
                    ? .init(places: Array(suggested.prefix(3)), nextPageToken: "more")
                    : .init(places: Array(suggested.dropFirst(3)), nextPageToken: nil)
            },
            resolve: { HomeMarketPresentation.hasAvailablePopularData(place: $0) ? $0 : nil }
        ))
        await cold.search(city: city, query: "")
        precondition(cold.markets.count == 7 && cold.suggestions.count == 7 && initialPages == 2)
        precondition(cold.nextPageToken == nil)
        let spaced = try place("kr", name: "K R Market")
        cold.seedSuggestions([spaced], city: "Bengaluru, India")
        precondition(cold.matchingMarkets(city: "Bengaluru, India", query: "KR").map(\.id) == [spaced.id])
        precondition(cold.matchingMarkets(city: city, query: "").isEmpty)

        // Partial and multi-keyword names search the entire city cache, beyond
        // the seven visible pre-search suggestions.
        let chheharta = try place("chheharta", name: "Chheharta Bazar")
        let partial = MarketSearchStore(service: .init(
            viewport: { _ in viewport },
            page: { _, query, _, _ in
                .init(places: query == "chh" ? [chheharta, shop] : [], nextPageToken: nil)
            },
            resolve: { HomeMarketPresentation.hasAvailablePopularData(place: $0) ? $0 : nil }
        ))
        partial.seedSuggestions(suggested, city: city)
        await partial.search(city: city, query: "chh")
        precondition(partial.matchingMarkets(city: city, query: "chh").map(\.id) == [chheharta.id])
        precondition(partial.matchingMarkets(city: city, query: "CHH BAZ").map(\.id) == [chheharta.id])
        precondition(partial.matchingMarkets(city: city, query: "baz chh").map(\.id) == [chheharta.id])
        precondition(partial.matchingMarkets(city: city, query: "chheharta bazaar").map(\.id) == [chheharta.id])
        precondition(partial.matchingMarkets(city: city, query: "").count == 7)
        // A later full-text miss must not erase a market learned from autocomplete.
        await partial.search(city: city, query: "chhe")
        precondition(partial.matchingMarkets(city: city, query: "chhe").map(\.id) == [chheharta.id])
        precondition(partial.matchingMarkets(city: "Bengaluru, India", query: "chh").isEmpty)

        let autocomplete = try JSONDecoder().decode(GoogleMarketDiscovery.AutocompleteResponse.self, from: Data("""
        {"suggestions":[
          {"placePrediction":{"placeId":"chheharta","types":["market"],
          "structuredFormat":{"mainText":{"text":"Chheharta Bazar"},"secondaryText":{"text":"Amritsar, India"}}}},
          {"queryPrediction":{"text":{"text":"chh"}}}
        ]}
        """.utf8))
        precondition(autocomplete.candidates.map(\.id) == [chheharta.id])
        precondition(autocomplete.candidates.first?.name == chheharta.name)
        precondition(autocomplete.candidates.first?.formattedAddress == city)
        let body = GoogleMarketDiscovery.autocompleteBody(query: "  chh  ", viewport: viewport)
        precondition(body["input"] as? String == "chh")
        precondition(body["locationRestriction"] != nil && body["locationBias"] == nil)
        precondition((body["includedPrimaryTypes"] as? [String])?.count == 5)

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
