import Foundation

@main
struct LowCrowdNotificationChecks {
    static func main() throws {
        let suiteName = "CrowdStatus.NotificationChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        precondition(LowCrowdNotification.allSaved(defaults: defaults).isEmpty)
        defaults.set(try JSONEncoder().encode(["Russell Market"]), forKey: "lowCrowdNotificationMarkets")
        let migrated = LowCrowdNotification.allSaved(defaults: defaults)
        precondition(migrated.count == 1 && migrated[0].marketName == "Russell Market")
        precondition(LowCrowdNotification.allSaved(defaults: defaults)[0].id == migrated[0].id)
        LowCrowdNotification.save(for: "Jayanagar Market", defaults: defaults)
        precondition(LowCrowdNotification.allSaved(defaults: defaults).count == 2)
        let previous = LowCrowdNotification.allSaved(defaults: defaults).first { $0.marketName == "Jayanagar Market" }!
        let clearedIDs = Set([previous.notificationID])
        precondition(LowCrowdNotification.allSaved(defaults: defaults).filter { !clearedIDs.contains($0.notificationID) }.count == 1)
        LowCrowdNotification.save(for: "Jayanagar Market", defaults: defaults)
        let savedAgain = LowCrowdNotification.allSaved(defaults: defaults)
        precondition(savedAgain.count == 2)
        precondition(savedAgain.filter { !clearedIDs.contains($0.notificationID) }.count == 2)
        defaults.set(try JSONEncoder().encode(["Russell Market", "Jayanagar Market"]), forKey: "lowCrowdNotificationMarkets")
        defaults.set(Data("unrelated alert window".utf8), forKey: "marketAlertWindows")
        LowCrowdNotification.remove(for: "Russell Market", defaults: defaults)
        let remaining = LowCrowdNotification.allSaved(defaults: defaults)
        precondition(remaining.count == 1 && remaining[0].id == savedAgain.first { $0.marketName == "Jayanagar Market" }!.id)
        let enabled = try JSONDecoder().decode([String].self, from: defaults.data(forKey: "lowCrowdNotificationMarkets")!)
        precondition(enabled == ["Jayanagar Market"])
        precondition(defaults.data(forKey: "marketAlertWindows") == Data("unrelated alert window".utf8))
        LowCrowdNotification.remove(for: "Russell Market", defaults: defaults)
        precondition(LowCrowdNotification.allSaved(defaults: defaults).count == 1)
        LowCrowdNotification.save(for: "Russell Market", defaults: defaults)
        precondition(LowCrowdNotification.allSaved(defaults: defaults).count == 2)
        // Same-name markets in different cities have independent Place ID preferences.
        LowCrowdNotification.save(for: "City Market", placeID: "city-one", defaults: defaults)
        LowCrowdNotification.save(for: "City Market", placeID: "city-two", defaults: defaults)
        defaults.set(try JSONEncoder().encode(["city-one", "city-two"]), forKey: "lowCrowdNotificationMarkets")
        precondition(LowCrowdNotification.allSaved(defaults: defaults).filter { $0.marketName == "City Market" }.count == 2)
        LowCrowdNotification.remove(for: "City Market", placeID: "city-one", defaults: defaults)
        let cityAlerts = LowCrowdNotification.allSaved(defaults: defaults).filter { $0.marketName == "City Market" }
        precondition(cityAlerts.count == 1 && cityAlerts[0].placeID == "city-two")
        let cityPreferences = try JSONDecoder().decode([String].self, from: defaults.data(forKey: "lowCrowdNotificationMarkets")!)
        precondition(cityPreferences == ["city-two"])
        defaults.set(try JSONEncoder().encode(["Russell Market"]), forKey: "lowCrowdNotificationMarkets")
        LowCrowdNotification.save(for: "Russell Market, Shivajinagar", placeID: "russell-id", legacyMarketNames: ["Russell Market"], defaults: defaults)
        defaults.set(try JSONEncoder().encode(["russell-id"]), forKey: "lowCrowdNotificationMarkets")
        precondition(!LowCrowdNotification.allSaved(defaults: defaults).contains { $0.marketName == "Russell Market" })
        LowCrowdNotification.remove(for: "Russell Market, Shivajinagar", placeID: "russell-id", legacyMarketNames: ["Russell Market"], defaults: defaults)
        precondition(!LowCrowdNotification.allSaved(defaults: defaults).contains { $0.placeID == "russell-id" || $0.marketName == "Russell Market" })
        // Both custom alerts and low-crowd confirmations share persistent read state.
        let notificationIDs = ["custom-alert", "lowCrowd|first"]
        let unread = MarketNotificationReadState.unreadIDs(notificationIDs: notificationIDs, seen: Data(), cleared: Data())
        precondition(unread == Set(notificationIDs))
        let seen = MarketNotificationReadState.markingSeen(notificationIDs: notificationIDs, seen: Data())
        defaults.set(seen, forKey: "seenMarketNotifications")
        let restoredSeen = defaults.data(forKey: "seenMarketNotifications")!
        precondition(MarketNotificationReadState.unreadIDs(notificationIDs: notificationIDs, seen: restoredSeen, cleared: Data()).isEmpty)
        let newIDs = notificationIDs + ["lowCrowd|new"]
        precondition(MarketNotificationReadState.unreadIDs(notificationIDs: newIDs, seen: restoredSeen, cleared: Data()) == ["lowCrowd|new"])
        let cleared = try JSONEncoder().encode(["lowCrowd|new"])
        precondition(MarketNotificationReadState.unreadIDs(notificationIDs: newIDs, seen: restoredSeen, cleared: cleared).isEmpty)
        let seenAgain = MarketNotificationReadState.markingSeen(notificationIDs: ["lowCrowd|new"], seen: restoredSeen)
        precondition(MarketNotificationReadState.unreadIDs(notificationIDs: newIDs, seen: seenAgain, cleared: Data()).isEmpty)
        precondition(MarketNotificationReadState.unreadIDs(notificationIDs: [], seen: Data(), cleared: Data()).isEmpty)
        let route = MarketPushRoute(userInfo: ["placeID": "market-one", "marketName": "City Market"])
        precondition(route?.id == "market-one" && route?.marketName == "City Market")
        precondition(MarketPushRoute(userInfo: ["placeID": "", "marketName": "City Market"]) == nil)
        precondition(MarketPushRoute(userInfo: ["placeID": "market-one"]) == nil)
        precondition(MarketPushRoute(userInfo: ["placeID": 123, "marketName": "City Market"]) == nil)
        precondition(MarketPushRoute(userInfo: ["placeID": "market-one", "marketName": "  "]) == nil)
        let trimmedRoute = MarketPushRoute(userInfo: ["placeID": " market-two ", "marketName": " City Market "])
        precondition(trimmedRoute?.id == "market-two" && trimmedRoute?.marketName == "City Market")
        print("Low crowd notification checks passed")
    }
}
