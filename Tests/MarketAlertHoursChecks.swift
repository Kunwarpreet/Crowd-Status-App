import Foundation

@main
struct MarketAlertHoursChecks {
    static func main() throws {
        let now = ISO8601DateFormatter().date(from: "2026-10-12T06:00:00Z")!
        func hours(_ json: String) throws -> MarketAlertHours {
            let periods = try JSONDecoder().decode([MarketOpeningPeriod].self, from: Data(json.utf8))
            var status = MarketOpeningStatus(isOpen: true, nextOpening: nil, nextClosing: nil, expiresAt: now)
            status.regularPeriods = periods
            return MarketAlertHours(status: status, now: now)!
        }
        let daytime = try hours("""
        [{"open":{"day":1,"hour":10},"close":{"day":1,"hour":21}}]
        """)
        precondition(daytime.hours == Array(10...21))
        precondition(daytime.label == "10am – 9pm")
        precondition(daytime.permits(from: 600, to: 1260))
        precondition(daytime.permits(from: 615, to: 1259))
        precondition(!daytime.permits(from: 599, to: 1260))
        precondition(!daytime.permits(from: 600, to: 1261))
        precondition(!daytime.permits(from: 700, to: 700))
        precondition(!daytime.permits(from: 800, to: 700))
        precondition(daytime.adjusted(130) == 600)
        precondition(daytime.adjusted(1440) == 1260)
        precondition(daytime.adjusted(615) == 615)

        let split = try hours("""
        [{"open":{"day":1,"hour":10,"minute":30},"close":{"day":1,"hour":12}},
         {"open":{"day":1,"hour":14},"close":{"day":1,"hour":21,"minute":15}}]
        """)
        precondition(split.hours == [10, 11, 12] + Array(14...21))
        precondition(!split.permits(from: 600, to: 700))
        precondition(!split.permits(from: 660, to: 900))
        precondition(split.permits(from: 840, to: 1275))
        precondition(!split.permits(from: 840, to: 1276))

        let overnight = try hours("""
        [{"open":{"day":0,"hour":22},"close":{"day":1,"hour":2}},
         {"open":{"day":1,"hour":22},"close":{"day":2,"hour":2}}]
        """)
        precondition(overnight.hours == [0, 1, 2, 22, 23])
        precondition(overnight.permits(from: 0, to: 120))
        precondition(overnight.permits(from: 1320, to: 1439))
        precondition(!overnight.permits(from: 60, to: 1380))
        let allDay = try hours("""
        [{"open":{"day":0,"hour":0}}]
        """)
        precondition(allDay.hours == Array(0...23))
        let closed = try hours("[]")
        precondition(closed.hours.isEmpty)
        let unknown = MarketOpeningStatus(isOpen: nil, nextOpening: nil, nextClosing: nil, expiresAt: now)
        precondition(MarketAlertHours(status: unknown, now: now) == nil)
        let lunchtime = ISO8601DateFormatter().date(from: "2026-10-12T07:00:00Z")! // 12:30pm in India
        let remaining = daytime.remaining(after: lunchtime, timeZoneID: "Asia/Kolkata")
        precondition(remaining.startMinutes.first == 751)
        precondition(!remaining.startMinutes.contains(600) && !remaining.startMinutes.contains(660))
        precondition(!remaining.startMinutes.contains(750))
        precondition(remaining.startMinutes.allSatisfy { $0 > 750 && $0 < 1260 })
        precondition(!remaining.permits(from: 600, to: 660))
        precondition(remaining.permits(from: 751, to: 810))
        precondition(remaining.endMinutes(after: 751).first == 752)
        precondition(remaining.endMinutes(after: 1260).isEmpty)
        precondition(remaining.endMinutes(after: 700).isEmpty)
        let breakRemaining = split.remaining(after: lunchtime, timeZoneID: "Asia/Kolkata")
        precondition(breakRemaining.startMinutes.first == 840)
        precondition(!breakRemaining.startMinutes.contains(780))
        let late = ISO8601DateFormatter().date(from: "2026-10-12T16:00:00Z")! // 9:30pm in India
        precondition(daytime.remaining(after: late, timeZoneID: "Asia/Kolkata").ranges.isEmpty)
        precondition(daytime.remaining(after: lunchtime, timeZoneID: "UTC").startMinutes.first == 600)
        let laterMinute = lunchtime.addingTimeInterval(60)
        precondition(!daytime.remaining(after: laterMinute, timeZoneID: "Asia/Kolkata").permits(from: 751, to: 810))
        print("Market alert hours checks passed")
    }
}
