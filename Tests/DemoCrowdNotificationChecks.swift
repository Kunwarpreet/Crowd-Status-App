import Foundation

@main
struct DemoCrowdNotificationChecks {
    static func main() throws {
        let now = ISO8601DateFormatter().date(from: "2026-10-25T18:30:00Z")!
        let zone = "Asia/Kolkata"
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        let intervals = [DateInterval(start: now, end: now.addingTimeInterval(DemoCrowdNotificationPlan.horizon))]
        func subscription(_ id: String, always: Bool = true, windows: [DemoCrowdAlertWindow] = [],
                          open: [DateInterval]? = nil, delivered: Date? = nil) -> DemoCrowdAlertSubscription {
            .init(placeID: id, marketName: "City Market", timeZoneID: zone, openIntervals: open ?? intervals,
                  alwaysEnabled: always, windows: windows, lastDeliveredAt: delivered)
        }
        let bell = subscription("demo-market")
        let events = DemoCrowdNotificationPlan.events(for: bell, now: now)
        precondition(!events.isEmpty && events.count <= 3)
        precondition(events == DemoCrowdNotificationPlan.events(for: bell, now: now))
        for event in events {
            let displayed = MarketCrowdData.demo(marketID: bell.placeID, timeZoneID: zone, now: event.fireDate)
            precondition(event.simulatedPercent == displayed.currentPercent && event.simulatedPercent < 35)
            precondition(event.fireDate >= now.addingTimeInterval(5))
            precondition(event.fireDate < now.addingTimeInterval(DemoCrowdNotificationPlan.horizon))
        }
        for (first, next) in zip(events, events.dropFirst()) {
            precondition(next.fireDate.timeIntervalSince(first.fireDate) >= 3600)
        }
        let selected = subscription("window-market", always: false, windows: [.init(fromMinutes: 60, toMinutes: 120,
                                                                                          occurrence: DateInterval(start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200)))])
        let windowEvents = DemoCrowdNotificationPlan.events(for: selected, now: now)
        precondition(!windowEvents.isEmpty)
        precondition(windowEvents.allSatisfy {
            let minute = calendar.component(.hour, from: $0.fireDate) * 60 + calendar.component(.minute, from: $0.fireDate)
            return (60..<120).contains(minute)
        })
        // This window never recurs tomorrow, including after a relaunch/replan.
        let tomorrow = now.addingTimeInterval(24 * 3600)
        precondition(DemoCrowdNotificationPlan.events(for: selected, now: tomorrow).isEmpty)
        let bellAndWindow = subscription("window-market", always: true, windows: selected.windows)
        precondition(DemoCrowdNotificationPlan.events(for: bellAndWindow, now: now) == windowEvents)
        precondition(DemoCrowdNotificationPlan.events(for: bellAndWindow, now: tomorrow).isEmpty)
        let saved = MarketAlertWindow(marketName: "City Market", fromMinutes: 60, toMinutes: 120,
                                      placeID: "window-market", savedAt: now)
        let occurrence = saved.oneTimeInterval(timeZoneID: zone)!
        precondition(occurrence.start == now.addingTimeInterval(3600))
        precondition(occurrence.end == now.addingTimeInterval(7200))
        let restored = try JSONDecoder().decode(MarketAlertWindow.self, from: JSONEncoder().encode(saved))
        precondition(restored.oneTimeInterval(timeZoneID: zone) == occurrence)
        let duringWindow = MarketAlertWindow(marketName: "City Market", fromMinutes: 60, toMinutes: 120,
                                             savedAt: now.addingTimeInterval(90 * 60))
        precondition(duringWindow.oneTimeInterval(timeZoneID: zone) == occurrence)
        let afterWindow = MarketAlertWindow(marketName: "City Market", fromMinutes: 60, toMinutes: 120,
                                            savedAt: now.addingTimeInterval(3 * 3600))
        precondition(afterWindow.oneTimeInterval(timeZoneID: zone) == nil)
        let undated = MarketAlertWindow(marketName: "City Market", fromMinutes: 60, toMinutes: 120, savedAt: nil)
        precondition(undated.oneTimeInterval(timeZoneID: zone) == nil)
        precondition(DemoCrowdNotificationPlan.events(for: subscription("closed", open: []), now: now).isEmpty)
        precondition(DemoCrowdNotificationPlan.events(for: subscription("off", always: false), now: now).isEmpty)
        precondition(DemoCrowdNotificationPlan.events(for: subscription("invalid", always: false, windows: [.init(fromMinutes: 120, toMinutes: 60)]), now: now).isEmpty)
        let shortOpening = [DateInterval(start: now.addingTimeInterval(30 * 60), end: now.addingTimeInterval(45 * 60))]
        let duringOpening = DemoCrowdNotificationPlan.events(for: subscription("short", open: shortOpening), now: now)
        precondition(!duringOpening.isEmpty)
        precondition(duringOpening.allSatisfy { shortOpening[0].start <= $0.fireDate && $0.fireDate < shortOpening[0].end })
        let last = now.addingTimeInterval(-10 * 60)
        let cooled = DemoCrowdNotificationPlan.events(for: subscription("cooldown", delivered: last), now: now)
        precondition(cooled.allSatisfy { $0.fireDate.timeIntervalSince(last) >= 3600 })
        let many = (0..<20).map { subscription("market-\($0)") }
        let capped = DemoCrowdNotificationPlan.events(for: many, now: now)
        precondition(capped.count <= 48 && Set(capped.map(\.placeID)).count == 20)
        precondition(Set(capped.map(\.id)).count == capped.count)
        precondition(DemoCrowdNotificationPlan.events(for: [], now: now).isEmpty)
        print("Demo low-crowd notification planning checks passed")
    }
}
