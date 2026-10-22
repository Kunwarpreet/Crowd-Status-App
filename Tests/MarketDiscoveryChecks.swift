import Foundation
import CoreLocation

@main
struct MarketDiscoveryChecks {
    static func main() throws {
        func place(_ id: String, _ name: String, _ types: String = "\"market\"") throws -> GoogleMarketPlace {
            try JSONDecoder().decode(GoogleMarketPlace.self, from: Data("""
            {"id":"\(id)","displayName":{"text":"\(name)"},"types":[\(types)],
            "formattedAddress":"Market Road","location":{"latitude":12.97,"longitude":77.59},
            "rating":4.2,"internationalPhoneNumber":"+91 97426 38865"}
            """.utf8))
        }
        let first = try place("one", "City Market")
        let second = try place("two", "City Market")
        let transit = try place("bus", "KR Market", "\"bus_stop\"")
        let mall = try place("mall", "Jayanagar Market", "\"shopping_mall\"")
        let untyped = try place("plain", "Malleshwaram Market", "\"point_of_interest\"")
        let shop = try place("shop", "Supermarket", "\"supermarket\"")
        let merged = GoogleMarketDiscovery.merging([first], [first, second, transit, mall, untyped, shop])
        precondition(merged.map(\.id) == ["one", "two", "mall", "plain"])
        precondition(first.phoneURL?.absoluteString == "tel:+919742638865")
        precondition(first.distance(from: nil) == nil)
        precondition(first.distance(from: CLLocation(latitude: 12.97, longitude: 77.59)) == "0.00 km")
        let unavailable = try JSONDecoder().decode(GoogleMarketPlace.self, from: Data("{\"id\":\"missing\"}".utf8))
        precondition(unavailable.phoneURL == nil && unavailable.rating == nil && unavailable.photos == nil)
        func rankedPlace(_ id: String, latitude: Double, reviews: Int, rating: Double) throws -> GoogleMarketPlace {
            try JSONDecoder().decode(GoogleMarketPlace.self, from: Data("""
            {"id":"\(id)","types":["market"],"location":{"latitude":\(latitude),"longitude":77.59},"rating":\(rating),"userRatingCount":\(reviews)}
            """.utf8))
        }
        let close = try rankedPlace("close", latitude: 12.971, reviews: 10, rating: 5)
        let busy = try rankedPlace("busy", latitude: 13.0, reviews: 200, rating: 4)
        let far = try rankedPlace("far", latitude: 14.0, reviews: 1000, rating: 4.5)
        let origin = CLLocation(latitude: 12.97, longitude: 77.59)
        let withinRadius = try rankedPlace("within-radius", latitude: 13.041, reviews: 20, rating: 4)
        let outsideRadius = try rankedPlace("outside-radius", latitude: 13.043, reviews: 20, rating: 4)
        precondition(GoogleMarketDiscovery.nearby([outsideRadius, withinRadius, close], from: origin).map(\.id) == ["close", "within-radius"])
        precondition(GoogleMarketDiscovery.nearby([far, busy, close, close, unavailable], from: origin).map(\.id) == ["close", "busy"])
        precondition(GoogleMarketDiscovery.popular([close, far, busy, busy]).map(\.id) == ["far", "busy", "close"])
        let restaurant = try place("restaurant", "The Market", "\"restaurant\"")
        let parking = try place("parking", "KR Market parking", "\"transportation_service\"")
        let grocery = try place("grocery", "SUPER MARKET", "\"general_store\"")
        precondition(GoogleMarketDiscovery.nearby([restaurant, parking, grocery, close], from: origin).map(\.id) == ["close"])
        precondition(GoogleMarketDiscovery.popular([restaurant, parking, grocery, busy]).map(\.id) == ["busy"])
        let tied = try rankedPlace("tied", latitude: 13, reviews: 200, rating: 4.8)
        precondition(GoogleMarketDiscovery.popular([busy, tied]).map(\.id) == ["tied", "busy"])
        precondition(HomeMarketPresentation.locationLabel(area: "Shivaji Nagar", city: "Bengaluru") == "Shivaji Nagar, Bengaluru")
        precondition(HomeMarketPresentation.locationLabel(area: nil, city: "Bengaluru") == "Bengaluru")
        precondition(HomeMarketPresentation.locationLabel(area: " Bengaluru ", city: "Bengaluru") == "Bengaluru")
        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let knownClosed = MarketOpeningStatus(isOpen: false, nextOpening: nil, nextClosing: nil, expiresAt: .distantFuture, weekdayDescriptions: weekdays.map { "\($0): Closed" }, currentPeriods: [], regularPeriods: [])
        precondition(HomeMarketPresentation.hasAvailableData(place: first, status: knownClosed))
        precondition(!HomeMarketPresentation.hasAvailableData(place: first, status: .unavailable))
        precondition(!HomeMarketPresentation.hasAvailableData(place: unavailable, status: knownClosed))
        precondition(!HomeMarketPresentation.hasAvailableData(place: first, status: nil))
        let noSchedule = MarketOpeningStatus(isOpen: true, nextOpening: nil, nextClosing: nil, expiresAt: .distantFuture)
        precondition(!HomeMarketPresentation.hasAvailableData(place: first, status: noSchedule))
        let noPhone = try JSONDecoder().decode(GoogleMarketPlace.self, from: Data("""
        {"id":"no-phone","displayName":{"text":"No Phone Market"},"formattedAddress":"Market Road"}
        """.utf8))
        precondition(!HomeMarketPresentation.hasAvailableData(place: noPhone, status: knownClosed))
        let invalidPhone = try JSONDecoder().decode(GoogleMarketPlace.self, from: Data("""
        {"id":"bad-phone","internationalPhoneNumber":"+","nationalPhoneNumber":"123"}
        """.utf8))
        precondition(invalidPhone.phoneURL == nil)
        let nationalPhone = try JSONDecoder().decode(GoogleMarketPlace.self, from: Data("""
        {"id":"national-phone","internationalPhoneNumber":"","nationalPhoneNumber":"0183 234 5678"}
        """.utf8))
        precondition(nationalPhone.phoneURL?.absoluteString == "tel:01832345678")
        let partialSchedule = MarketOpeningStatus(isOpen: false, nextOpening: nil, nextClosing: nil, expiresAt: .distantFuture, weekdayDescriptions: ["Monday: Closed"], currentPeriods: [])
        precondition(!HomeMarketPresentation.hasAvailableData(place: first, status: partialSchedule))
        precondition(MarketJourney.distanceLabel(1200) == "1.2 km")
        precondition(MarketJourney.distanceLabel(450) == "0.45 km")
        precondition(MarketJourney(distance: 1200, travelTime: 601).timeLabel == "11 min drive")
        precondition(MarketJourney(distance: 1200, travelTime: 0).timeLabel == "1 min drive")
        precondition(MarketJourney(distance: 1200, travelTime: 3660).timeLabel == "1 hr 1 min drive")
        let cachedContext = HomeMarketContext(city: "Bengaluru, India", location: origin)
        precondition(cachedContext.matches(city: "Bengaluru, India", location: origin))
        precondition(cachedContext.matches(city: "Bengaluru, India", location: CLLocation(latitude: 12.97001, longitude: 77.59)))
        precondition(!cachedContext.matches(city: "Bengaluru, India", location: CLLocation(latitude: 13.0, longitude: 77.59)))
        precondition(!cachedContext.matches(city: "Amritsar, India", location: origin))
        precondition(!cachedContext.matches(city: "Bengaluru, India", location: nil))
        precondition(HomeMarketContext(city: "Bengaluru, India", location: nil).matches(city: "Bengaluru, India", location: nil))
        let page = try JSONDecoder().decode(GoogleMarketDiscovery.Page.self, from: Data("{\"places\":[],\"nextPageToken\":\"next\"}".utf8))
        precondition(page.nextPageToken == "next")
        let listing = Data("""
        {"id":"one","timeZone":{"id":"America/New_York"},"currentOpeningHours":{"openNow":true,"nextCloseTime":"2026-10-13T01:00:00Z"}}
        """.utf8)
        let status = try GoogleMarketHours.detailsStatus(from: listing, expectedPlaceID: "one")
        let now = ISO8601DateFormatter().date(from: "2026-10-12T23:00:00Z")!
        precondition(status.label(at: now) == "Open · Closes at 9pm")
        precondition(status.weeklyHours(at: now)[0].day == "Monday")
        print("Market discovery checks passed")
    }
}
