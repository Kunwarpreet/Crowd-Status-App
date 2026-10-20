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
        precondition(open.label(at: now) == "Open · Closes at 10:31pm")
        precondition(open.expiresAt == now.addingTimeInterval(60))
        let earlier = ISO8601DateFormatter().date(from: "2026-10-12T12:00:00Z")!
        let eveningClosing = try status("\"currentOpeningHours\":{\"openNow\":true,\"nextCloseTime\":\"2026-10-12T15:30:00Z\"}")
        precondition(eveningClosing.label(at: earlier) == "Open · Closes at 9pm")
        let overnight = try status("\"currentOpeningHours\":{\"openNow\":true,\"nextCloseTime\":\"2026-10-12T19:30:00Z\"}")
        precondition(overnight.label(at: now) == "Open · Closes tomorrow at 1am")
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
        precondition(directRussell.label(at: now) == "Open · Closes at 11pm")
        do {
            _ = try GoogleMarketHours.detailsStatus(from: Data("{\"id\":\"unrelated-place\"}".utf8), now: now)
            preconditionFailure("Do not use hours from the wrong Place ID")
        } catch { }
        let closed = try status("\"currentOpeningHours\":{\"openNow\":false,\"nextOpenTime\":\"2026-10-13T03:30:00.000Z\"}")
        precondition(closed.label(at: now) == "Closed · Opens tomorrow at 9am")
        precondition(closed.expiresAt == now.addingTimeInterval(300))
        let sameDay = try status("\"currentOpeningHours\":{\"openNow\":false,\"nextOpenTime\":\"2026-10-12T17:30:00Z\"}")
        precondition(sameDay.label(at: now) == "Closed · Opens at 11pm")
        let later = try status("\"currentOpeningHours\":{\"openNow\":false,\"nextOpenTime\":\"2026-10-18T03:30:00Z\"}")
        precondition(later.label(at: now) == "Closed · Opens Sun at 9am")
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
        // Every market uses its pinned listing, including aliases such as KR Market.
        for (name, placeID) in GoogleMarketHours.placeIDs {
            let data = Data("""
            {"id":"\(placeID)","currentOpeningHours":{"openNow":true,"nextCloseTime":"2026-10-12T17:30:00Z"},
             "regularOpeningHours":{"weekdayDescriptions":["Monday: 7:00 AM – 11:00 PM"]}}
            """.utf8)
            let result = try GoogleMarketHours.detailsStatus(from: data, expectedPlaceID: placeID, now: now)
            precondition(result.label(at: now) == "Open · Closes at 11pm", name)
            precondition(result.weekdayDescriptions == ["Monday: 7:00 AM – 11:00 PM"])
        }
        let noPublishedHours = try GoogleMarketHours.detailsStatus(
            from: Data("{\"id\":\"\(GoogleMarketHours.placeIDs["Gandhi Bazaar Flower Market"]!)\"}".utf8),
            expectedPlaceID: GoogleMarketHours.placeIDs["Gandhi Bazaar Flower Market"]!, now: now)
        precondition(noPublishedHours.label == "Hours unavailable")
        precondition(noPublishedHours.weekdayDescriptions.isEmpty)
        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        var schedule = MarketOpeningStatus.unavailable
        schedule.weekdayDescriptions = weekdays.map { "\($0): 9:00 AM – 9:00 PM" }
        precondition(schedule.scheduleRows.count == 1)
        precondition(schedule.scheduleRows[0].days == "Mon-Sun")
        precondition(schedule.scheduleRows[0].hours == "9am - 9pm")
        schedule.weekdayDescriptions[6] = "Sunday: Closed"
        precondition(schedule.scheduleRows[0].days == "Mon-Sat")
        schedule.weekdayDescriptions[6] = "Sunday: 10:30 AM – 6:00 PM"
        precondition(schedule.scheduleRows.count == 2)
        precondition(schedule.scheduleRows[1].days == "Sun")
        precondition(schedule.scheduleRows[1].hours == "10:30am - 6pm")
        schedule.weekdayDescriptions[1] = "Tuesday: 10:00 AM – 9:00 AM"
        precondition(schedule.scheduleRows[0].days == "Mon, Wed-Sat")
        precondition(schedule.scheduleRows[1].hours == "10am - 9am")
        schedule.weekdayDescriptions = ["Monday: 9:00 AM – 12:00 PM, 2:00 PM – 9:00 PM"]
        precondition(schedule.scheduleRows[0].hours == "9am - 12pm, 2pm - 9pm")
        schedule.weekdayDescriptions = []
        precondition(schedule.scheduleRows.isEmpty)
        let tuesdayInBengaluru = ISO8601DateFormatter().date(from: "2026-10-12T20:00:00Z")!
        schedule.weekdayDescriptions = weekdays.map { "\($0): 10:00 AM – 9:00 PM" }
        schedule.weekdayDescriptions[0] = "Monday: Closed"
        let week = schedule.weeklyHours(at: tuesdayInBengaluru)
        precondition(week.map(\.day) == ["Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday", "Monday"])
        precondition(week[0].isToday && week.filter(\.isToday).count == 1)
        precondition(week[0].hours == "10am - 9pm")
        precondition(week[6].hours == "Closed")
        schedule.weekdayDescriptions = []
        precondition(schedule.weeklyHours(at: now).count == 7)
        precondition(schedule.weeklyHours(at: now).allSatisfy { $0.hours == "Unavailable" })
        print("Opening-hours checks passed")
    }
}
