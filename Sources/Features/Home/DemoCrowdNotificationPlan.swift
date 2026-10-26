import Foundation

struct DemoCrowdAlertWindow: Equatable {
    let fromMinutes: Int
    let toMinutes: Int
    var occurrence: DateInterval? = nil

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        guard let occurrence, occurrence.start <= date, date < occurrence.end else { return false }
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        return (0..<1440).contains(fromMinutes) && (1...1440).contains(toMinutes)
            && fromMinutes < toMinutes && fromMinutes <= minute && minute < toMinutes
    }
}

struct DemoCrowdAlertSubscription {
    let placeID: String
    let marketName: String
    let timeZoneID: String
    let openIntervals: [DateInterval]
    let alwaysEnabled: Bool
    let windows: [DemoCrowdAlertWindow]
    var lastDeliveredAt: Date? = nil
}

struct DemoCrowdAlertEvent: Equatable, Identifiable {
    let placeID: String
    let marketName: String
    let fireDate: Date
    let simulatedPercent: Int
    var id: String { "demo-low|\(placeID)|\(Int(fireDate.timeIntervalSince1970))" }
}

enum DemoCrowdNotificationPlan {
    static let horizon: TimeInterval = 3 * 24 * 60 * 60
    static let requestLimit = 48

    static func events(for subscriptions: [DemoCrowdAlertSubscription], now: Date = Date()) -> [DemoCrowdAlertEvent] {
        let events = subscriptions.flatMap { events(for: $0, now: now) }
        // Prefer each market's first alert before spending capacity on repeats.
        let grouped = Dictionary(grouping: events, by: \.placeID)
        let first = grouped.values.compactMap(\.first).sorted(by: ordered)
        let firstIDs = Set(first.map(\.id))
        let remaining = events.filter { !firstIDs.contains($0.id) }.sorted(by: ordered)
        return Array((first + remaining).prefix(requestLimit))
    }

    static func events(for subscription: DemoCrowdAlertSubscription, now: Date) -> [DemoCrowdAlertEvent] {
        guard !subscription.placeID.isEmpty else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: subscription.timeZoneID) ?? TimeZone(identifier: "Asia/Kolkata")!
        let earliest = now.addingTimeInterval(5)
        let end = now.addingTimeInterval(horizon)
        var dates: Set<Date> = [earliest]
        var bucket = ceil(earliest.timeIntervalSince1970 / MarketCrowdData.refreshInterval) * MarketCrowdData.refreshInterval
        while bucket < end.timeIntervalSince1970 {
            dates.insert(Date(timeIntervalSince1970: bucket))
            bucket += MarketCrowdData.refreshInterval
        }
        for interval in subscription.openIntervals where interval.start >= earliest && interval.start < end {
            dates.insert(interval.start)
        }
        for window in subscription.windows {
            if let date = window.occurrence?.start, date >= earliest, date < end { dates.insert(date) }
        }
        var result: [DemoCrowdAlertEvent] = []
        var wasLow = false
        var lastFire = subscription.lastDeliveredAt ?? .distantPast
        for date in dates.sorted() {
            let open = subscription.openIntervals.contains { $0.start <= date && date < $0.end }
            let inWindow = subscription.windows.isEmpty
                ? subscription.alwaysEnabled
                : subscription.windows.contains { $0.contains(date, calendar: calendar) }
            let snapshot = MarketCrowdData.demo(marketID: subscription.placeID, timeZoneID: subscription.timeZoneID, now: date)
            let isLow = open && inWindow && snapshot.currentPercent < 35
            if isLow && !wasLow && date.timeIntervalSince(lastFire) >= 3600 {
                result.append(.init(placeID: subscription.placeID, marketName: subscription.marketName,
                                    fireDate: date, simulatedPercent: snapshot.currentPercent))
                lastFire = date
                if result.count == 3 { break }
            }
            wasLow = isLow
        }
        return result
    }

    private static func ordered(_ lhs: DemoCrowdAlertEvent, _ rhs: DemoCrowdAlertEvent) -> Bool {
        lhs.fireDate == rhs.fireDate ? lhs.placeID < rhs.placeID : lhs.fireDate < rhs.fireDate
    }
}
