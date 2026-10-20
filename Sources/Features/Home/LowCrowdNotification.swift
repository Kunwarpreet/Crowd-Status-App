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
