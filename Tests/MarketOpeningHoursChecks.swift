import Foundation

// Run with the command documented in README; no Google key or network needed.
@main
struct MarketOpeningHoursChecks {
    static func main() throws {
        let now = ISO8601DateFormatter().date(from: "2026-10-12T17:00:00Z")! // 10:30 PM in Bengaluru
        func status(_ fields: String) throws -> MarketOpeningStatus {
            let json = """
            {"places":[{"displayName":{"text":"Russell Market"},\(fields)}]}
            """
            return try GoogleMarketHours.status(from: Data(json.utf8), marketName: "Russell Market", now: now)
        }
        func check(_ condition: Bool) { precondition(condition) }
        let open = try status("\"currentOpeningHours\":{\"openNow\":true,\"nextCloseTime\":\"2026-10-12T17:01:00Z\"}")
        precondition(open.label(at: now) == "Open till 10:31pm")
        precondition(open.expiresAt == now.addingTimeInterval(60))
        let earlier = ISO8601DateFormatter().date(from: "2026-10-12T12:00:00Z")!
        let eveningClosing = try status("\"currentOpeningHours\":{\"openNow\":true,\"nextCloseTime\":\"2026-10-12T15:30:00Z\"}")
        precondition(eveningClosing.label(at: earlier) == "Open till 9pm")
        let overnight = try status("\"currentOpeningHours\":{\"openNow\":true,\"nextCloseTime\":\"2026-10-12T19:30:00Z\"}")
        precondition(overnight.label(at: now) == "Open till tomorrow 1am")
        let officialRussellListing = Data("""
        {"places":[{"displayName":{"text":"Russell Market, Shivajinagar"},"currentOpeningHours":{"openNow":true}},
        {"displayName":{"text":"RUSELL Mart"},"currentOpeningHours":{"openNow":false}}]}
        """.utf8)
        let russell = try GoogleMarketHours.status(from: officialRussellListing, marketName: "Russell Market", now: now)
        precondition(russell.label == "Open")
        // A direct Place ID lookup must work even if Google renames the listing.
        let directListing = Data("""
        {"id":"\(GoogleMarketHours.russellPlaceID)","displayName":{"text":"Updated Russell listing name"},
         "currentOpeningHours":{"openNow":true,"nextCloseTime":"2026-10-12T17:30:00Z"}}
        """.utf8)
        let directRussell = try GoogleMarketHours.detailsStatus(from: directListing, now: now)
        precondition(directRussell.label(at: now) == "Open till 11pm")
        do {
            _ = try GoogleMarketHours.detailsStatus(from: Data("{\"id\":\"unrelated-place\"}".utf8), now: now)
            preconditionFailure("Do not use hours from the wrong Place ID")
        } catch { }
        let closed = try status("\"currentOpeningHours\":{\"openNow\":false,\"nextOpenTime\":\"2026-10-13T03:30:00.000Z\"}")
        precondition(closed.label(at: now) == "Closed till tomorrow 9am")
        precondition(closed.expiresAt == now.addingTimeInterval(300))
        let sameDay = try status("\"currentOpeningHours\":{\"openNow\":false,\"nextOpenTime\":\"2026-10-12T17:30:00Z\"}")
        precondition(sameDay.label(at: now) == "Closed till 11pm")
        let later = try status("\"currentOpeningHours\":{\"openNow\":false,\"nextOpenTime\":\"2026-10-18T03:30:00Z\"}")
        precondition(later.label(at: now) == "Closed till Sun 9am")
        try check(status("\"currentOpeningHours\":{\"openNow\":false}").label == "Closed")
        try check(status("\"businessStatus\":\"OPERATIONAL\"").label == "Hours unavailable")
        try check(status("\"currentOpeningHours\":{}").isOpen == nil)
        try check(status("\"businessStatus\":\"CLOSED_PERMANENTLY\",\"currentOpeningHours\":{\"openNow\":true}").label == "Closed")
        for json in [
            "{}",
            "{\"places\":[{\"displayName\":{\"text\":\"Unrelated shop\"}}]}",
            "{\"places\":[{\"displayName\":{\"text\":\"Russell Market\"}},{\"displayName\":{\"text\":\"Russell Market\"}}]}"
        ] {
            do {
                _ = try GoogleMarketHours.status(from: Data(json.utf8), marketName: "Russell Market", now: now)
                preconditionFailure("Unresolved or ambiguous listings must not supply hours")
            } catch { }
        }
        print("Opening-hours checks passed")
    }
}
