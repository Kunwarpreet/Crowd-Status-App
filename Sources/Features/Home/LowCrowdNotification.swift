import Foundation

enum MarketNotificationReadState {
    static func unreadIDs(notificationIDs: [String], seen: Data, cleared: Data) -> Set<String> {
        Set(notificationIDs).subtracting(ids(in: seen)).subtracting(ids(in: cleared))
    }

    static func markingSeen(notificationIDs: [String], seen: Data) -> Data {
        let updated = ids(in: seen).union(notificationIDs)
        return (try? JSONEncoder().encode(updated.sorted())) ?? seen
    }

    private static func ids(in data: Data) -> Set<String> {
        Set((try? JSONDecoder().decode([String].self, from: data)) ?? [])
    }
}

struct LowCrowdNotification: Codable, Identifiable {
    let id: String
    let marketName: String
    var placeID: String? = nil
    let savedAt: Date

    var notificationID: String { "lowCrowd|\(id)" }
    private static let storageKey = "lowCrowdNotificationConfirmations"

    static func allSaved(defaults: UserDefaults = .standard) -> [Self] {
        var confirmations = defaults.data(forKey: storageKey)
            .flatMap { try? JSONDecoder().decode([Self].self, from: $0) } ?? []
        // Include preferences saved by the earlier version of the detail popup.
        let legacyNames = defaults.data(forKey: "lowCrowdNotificationMarkets")
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        let missing = Set(legacyNames).subtracting(confirmations.flatMap { [$0.marketName] + [$0.placeID].compactMap { $0 } })
        for name in missing.sorted() {
            confirmations.append(Self(id: UUID().uuidString, marketName: name, savedAt: Date()))
        }
        if !missing.isEmpty, let data = try? JSONEncoder().encode(confirmations) {
            defaults.set(data, forKey: storageKey)
        }
        return confirmations
    }

    static func save(for marketName: String, placeID: String? = nil, legacyMarketNames: [String] = [], defaults: UserDefaults = .standard) {
        var confirmations = allSaved(defaults: defaults)
        confirmations.removeAll { record in
            if let placeID {
                return record.placeID == placeID || (record.placeID == nil && (record.marketName == marketName || legacyMarketNames.contains(record.marketName)))
            }
            return record.placeID == nil && (record.marketName == marketName || legacyMarketNames.contains(record.marketName))
        }
        confirmations.append(Self(id: UUID().uuidString, marketName: marketName, placeID: placeID, savedAt: Date()))
        if let data = try? JSONEncoder().encode(confirmations) {
            defaults.set(data, forKey: storageKey)
        }
    }

    static func remove(for marketName: String, placeID: String? = nil, legacyMarketNames: [String] = [], defaults: UserDefaults = .standard) {
        let preferencesKey = "lowCrowdNotificationMarkets"
        var enabledMarkets = defaults.data(forKey: preferencesKey)
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        enabledMarkets.removeAll { $0 == (placeID ?? marketName) || $0 == marketName || legacyMarketNames.contains($0) }
        let confirmations = allSaved(defaults: defaults).filter {
            if let placeID { return $0.placeID != placeID && !($0.placeID == nil && ($0.marketName == marketName || legacyMarketNames.contains($0.marketName))) }
            return $0.marketName != marketName
        }
        guard let preferencesData = try? JSONEncoder().encode(enabledMarkets),
              let confirmationsData = try? JSONEncoder().encode(confirmations) else { return }
        // Remove both records so legacy migration cannot restore a disabled alert.
        defaults.set(preferencesData, forKey: preferencesKey)
        defaults.set(confirmationsData, forKey: storageKey)
    }
}

// Navigation metadata carried by an actual provider's APNs alert payload.
struct MarketPushRoute: Identifiable, Hashable {
    let placeID: String
    let marketName: String
    var id: String { placeID }

    init?(userInfo: [AnyHashable: Any]) {
        guard let placeID = userInfo["placeID"] as? String,
              let marketName = userInfo["marketName"] as? String else { return nil }
        let id = placeID.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = marketName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !name.isEmpty else { return nil }
        self.placeID = id
        self.marketName = name
    }
}

struct MarketAlertWindow: Codable {
    let marketName: String
    let fromMinutes: Int
    let toMinutes: Int
    var placeID: String? = nil
    var savedAt: Date? = Date()

    var notificationID: String {
        "\(placeID ?? marketName)|\(fromMinutes)|\(toMinutes)|\(savedAt?.timeIntervalSince1970 ?? 0)"
    }

    /// Resolve once from the save timestamp, never from the next app launch.
    func oneTimeInterval(timeZoneID: String) -> DateInterval? {
        guard let savedAt, (0..<1440).contains(fromMinutes), (1...1440).contains(toMinutes),
              fromMinutes < toMinutes else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(identifier: "Asia/Kolkata")!
        func interval(on day: Date) -> DateInterval? {
            guard let start = calendar.date(bySettingHour: fromMinutes / 60, minute: fromMinutes % 60, second: 0, of: day) else { return nil }
            let end: Date?
            if toMinutes == 1440 { end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) }
            else { end = calendar.date(bySettingHour: toMinutes / 60, minute: toMinutes % 60, second: 0, of: day) }
            guard let end, start < end else { return nil }
            return DateInterval(start: start, end: end)
        }
        guard let today = interval(on: savedAt) else { return nil }
        return savedAt < today.end ? today : nil
    }

    func save() {
        let key = "marketAlertWindows"
        let existing = UserDefaults.standard.data(forKey: key)
        var windows = existing.flatMap { try? JSONDecoder().decode([Self].self, from: $0) } ?? []
        windows.removeAll { record in
            if let placeID {
                return record.placeID == placeID || (record.placeID == nil && record.marketName == marketName)
            }
            return record.placeID == nil && record.marketName == marketName
        }
        windows.append(self)
        if let data = try? JSONEncoder().encode(windows) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func allSaved() -> [Self] {
        guard let data = UserDefaults.standard.data(forKey: "marketAlertWindows"),
              var windows = try? JSONDecoder().decode([Self].self, from: data) else { return [] }
        // Freeze legacy undated records once so reopening cannot roll them forward.
        if windows.contains(where: { $0.savedAt == nil }) {
            for index in windows.indices where windows[index].savedAt == nil { windows[index].savedAt = Date() }
            if let encoded = try? JSONEncoder().encode(windows) { UserDefaults.standard.set(encoded, forKey: "marketAlertWindows") }
        }
        return windows
    }

    static func saved(for marketName: String, placeID: String? = nil) -> Self? {
        let windows = allSaved()
        if let placeID, let saved = windows.first(where: { $0.placeID == placeID }) { return saved }
        return windows.first { $0.placeID == nil && $0.marketName == marketName }
    }
}
