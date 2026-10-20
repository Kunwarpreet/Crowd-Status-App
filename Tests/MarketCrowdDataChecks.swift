import Foundation

@main
struct MarketCrowdDataChecks {
    static func main() throws {
        let now = ISO8601DateFormatter().date(from: "2026-10-13T10:00:00Z")!
        let first = MarketCrowdData.demo(marketID: "russell", timeZoneID: "Asia/Kolkata", now: now)
        let repeated = MarketCrowdData.demo(marketID: "russell", timeZoneID: "Asia/Kolkata", now: now.addingTimeInterval(30))
        precondition(first == repeated)
        precondition(first.samples.map(\.hour) == Array(0..<24))
        precondition(first.samples.allSatisfy { (5...98).contains($0.percent) })
        precondition(first.currentHour == 15)
        precondition(first.currentPercent == first.samples[15].percent)
        precondition(first.sourceLabel == "Demo data")
        precondition(["Low crowd", "Moderate crowd", "High crowd"].contains(first.levelTitle))
        let other = MarketCrowdData.demo(marketID: "jayanagar", timeZoneID: "Asia/Kolkata", now: now)
        precondition(first.samples != other.samples)
        let nextDay = MarketCrowdData.demo(marketID: "russell", timeZoneID: "Asia/Kolkata", now: now.addingTimeInterval(86400))
        precondition(first.samples != nextDay.samples)
        let nextBucket = MarketCrowdData.demo(marketID: "russell", timeZoneID: "Asia/Kolkata", now: now.addingTimeInterval(600))
        precondition(nextBucket.generatedAt == first.generatedAt.addingTimeInterval(600))
        for hour in 0..<24 where hour != first.currentHour {
            precondition(first.samples[hour] == nextBucket.samples[hour])
        }
        let newYork = MarketCrowdData.demo(marketID: "city-market", timeZoneID: "America/New_York", now: now)
        precondition(newYork.currentHour == 6)
        precondition(MarketCrowdSnapshot.hourLabel(0) == "12am")
        precondition(MarketCrowdSnapshot.hourLabel(12) == "12pm")
        func schedule(_ periods: String, current: String? = nil) throws -> MarketOpeningStatus {
            let json = """
            {"id":"schedule", "timeZone":{"id":"Asia/Kolkata"},
             "currentOpeningHours":{\(current ?? "\"openNow\":true")},
             "regularOpeningHours":{"periods":\(periods)}}
            """
            return try GoogleMarketHours.detailsStatus(from: Data(json.utf8), expectedPlaceID: "schedule", now: now)
        }
        let daytime = try schedule("""
        [{"open":{"day":2,"hour":7},"close":{"day":2,"hour":23}}]
        """)
        let active = MarketCrowdData.demo(marketID: "russell", timeZoneID: daytime.timeZoneID, now: now, openIntervals: daytime.todayOpenIntervals(at: now)!)
        precondition(active.samples.map(\.hour) == Array(7..<23))
        precondition(active.samples.first!.startMinute == 420 && active.samples.last!.endMinute == 1380)
        precondition(active.axisMinutes.first == 420 && active.axisMinutes.last == 1380)
        precondition(active.openHoursLabel == "7am – 11pm")
        let partial = try schedule("""
        [{"open":{"day":2,"hour":9,"minute":30},"close":{"day":2,"hour":21,"minute":15}}]
        """)
        let partialGraph = MarketCrowdData.demo(marketID: "partial", timeZoneID: partial.timeZoneID, now: now, openIntervals: partial.todayOpenIntervals(at: now)!)
        precondition(partialGraph.samples.first!.startMinute == 570)
        precondition(partialGraph.samples.last!.endMinute == 1275)
        precondition(MarketCrowdSnapshot.timeLabel(570) == "9:30am")
        let beforeOpening = ISO8601DateFormatter().date(from: "2026-10-13T03:45:00Z")! // 9:15am
        let early = MarketCrowdData.demo(marketID: "partial", timeZoneID: partial.timeZoneID, now: beforeOpening, openIntervals: partial.todayOpenIntervals(at: beforeOpening)!)
        precondition(!early.isOpenNow && early.levelTitle == "Closed now")
        let split = try schedule("""
        [{"open":{"day":2,"hour":9},"close":{"day":2,"hour":12}},
         {"open":{"day":2,"hour":14},"close":{"day":2,"hour":18}}]
        """)
        let splitGraph = MarketCrowdData.demo(marketID: "split", timeZoneID: split.timeZoneID, now: now, openIntervals: split.todayOpenIntervals(at: now)!)
        precondition(splitGraph.samples.map(\.hour) == [9,10,11,14,15,16,17])
        precondition(splitGraph.openHoursLabel == "9am – 12pm, 2pm – 6pm")
        let overnight = try schedule("""
        [{"open":{"day":1,"hour":22},"close":{"day":2,"hour":6}},
         {"open":{"day":2,"hour":22},"close":{"day":3,"hour":6}}]
        """)
        let nightGraph = MarketCrowdData.demo(marketID: "night", timeZoneID: overnight.timeZoneID, now: now, openIntervals: overnight.todayOpenIntervals(at: now)!)
        precondition(nightGraph.samples.map(\.hour) == [0,1,2,3,4,5,22,23])
        precondition(!nightGraph.isOpenNow)
        let allDay = try schedule("[{\"open\":{\"day\":0,\"hour\":0}}]")
        let allDayGraph = MarketCrowdData.demo(marketID: "always", timeZoneID: allDay.timeZoneID, now: now, openIntervals: allDay.todayOpenIntervals(at: now)!)
        precondition(allDayGraph.samples.count == 24)
        let closed = try schedule("[]")
        precondition(closed.todayOpenIntervals(at: now) == [])
        precondition(MarketOpeningStatus.unavailable.todayOpenIntervals(at: now) == nil)
        let holiday = try schedule("""
        [{"open":{"day":2,"hour":7},"close":{"day":2,"hour":23}}]
        """, current: """
        "openNow":false,"periods":[],"weekdayDescriptions":["Tuesday: Closed"]
        """)
        precondition(holiday.todayOpenIntervals(at: now) == [])
        let dated = try schedule("[]", current: """
        "openNow":true,"periods":[
          {"open":{"date":{"year":2026,"month":10,"day":13},"hour":10},
           "close":{"date":{"year":2026,"month":10,"day":13},"hour":16,"minute":30}}]
        """)
        let datedGraph = MarketCrowdData.demo(marketID: "special", timeZoneID: dated.timeZoneID, now: now, openIntervals: dated.todayOpenIntervals(at: now)!)
        precondition(datedGraph.samples.first!.startMinute == 600 && datedGraph.samples.last!.endMinute == 990)
        let fourPM = ISO8601DateFormatter().date(from: "2026-10-13T10:30:00Z")!
        let history = MarketCrowdData.demo(marketID: "russell", timeZoneID: daytime.timeZoneID, now: fourPM, openIntervals: daytime.todayOpenIntervals(at: fourPM)!)
        precondition(history.visibleSamples.map(\.hour) == Array(7...16))
        precondition(history.visibleSamples.last!.hour == 16 && history.isCurrent(history.visibleSamples.last!))
        precondition(history.axisMinutes.first == 420 && history.axisMinutes.last == 1380)
        precondition(early.visibleSamples.isEmpty && early.axisMinutes.first == 570 && early.axisMinutes.last == 1275)
        precondition(nightGraph.visibleSamples.map(\.hour) == [0,1,2,3,4,5])
        precondition(nightGraph.axisMinutes.last == 1440)
        let breakTime = ISO8601DateFormatter().date(from: "2026-10-13T07:30:00Z")! // 1pm
        let breakGraph = MarketCrowdData.demo(marketID: "split", timeZoneID: split.timeZoneID, now: breakTime, openIntervals: split.todayOpenIntervals(at: breakTime)!)
        precondition(breakGraph.visibleSamples.map(\.hour) == [9,10,11])
        precondition(!breakGraph.isOpenNow && breakGraph.axisMinutes.last == 1080)
        let afterClosing = ISO8601DateFormatter().date(from: "2026-10-13T18:00:00Z")! // 11:30pm
        let finished = MarketCrowdData.demo(marketID: "russell", timeZoneID: daytime.timeZoneID, now: afterClosing, openIntervals: daytime.todayOpenIntervals(at: afterClosing)!)
        precondition(finished.visibleSamples == finished.samples && !finished.isOpenNow)
        precondition(finished.axisMinutes.last == 1380)
        let tenToEightThirty = try schedule("""
        [{"open":{"day":2,"hour":10},"close":{"day":2,"hour":20,"minute":30}}]
        """)
        let bounded = MarketCrowdData.demo(marketID: "market-example", timeZoneID: tenToEightThirty.timeZoneID, now: fourPM, openIntervals: tenToEightThirty.todayOpenIntervals(at: fourPM)!)
        precondition(bounded.samples.first!.startMinute == 600 && bounded.samples.last!.endMinute == 1230)
        precondition(bounded.axisMinutes.first == 600 && bounded.axisMinutes.last == 1230)
        precondition(bounded.axisMinutes.allSatisfy { (600...1230).contains($0) })
        precondition(bounded.visibleSamples.map(\.hour) == Array(10...16))
        precondition(MarketCrowdSnapshot.timeLabel(bounded.axisMinutes.last!) == "8:30pm")
        precondition(bounded.scrollStart == 600 && bounded.scrollEnd == 1230)
        precondition(bounded.scrollWindow == 480)
        precondition(bounded.preferredScrollPosition >= bounded.scrollStart && bounded.preferredScrollPosition <= bounded.maxScrollPosition)
        let currentBar = bounded.visibleSamples.first(where: bounded.isCurrent)!
        precondition(Double(currentBar.startMinute) >= bounded.preferredScrollPosition)
        precondition(Double(currentBar.endMinute) <= bounded.preferredScrollPosition + bounded.scrollWindow)
        precondition(finished.preferredScrollPosition == finished.maxScrollPosition)
        print("Crowd demo data checks passed")
    }
}
