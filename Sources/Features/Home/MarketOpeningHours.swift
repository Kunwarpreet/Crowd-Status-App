import Foundation
import Combine

struct MarketScheduleRow: Identifiable {
    let days: String
    let hours: String
    var id: String { days }

    static func compactHours(_ hours: String) -> String {
        if hours.caseInsensitiveCompare("Closed") == .orderedSame { return "Closed" }
        return hours
            .replacingOccurrences(of: #"\s*(AM|PM)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: ":00", with: "")
            .replacingOccurrences(of: #"\s*[–—]\s*"#, with: " - ", options: .regularExpression)
            .lowercased()
    }
}

struct MarketWeekdayHours: Identifiable {
    let day: String
    let hours: String
    let isToday: Bool
    var id: String { day }
}

/// Alert selections use the market's local time and today's verified schedule.
struct MarketAlertHours: Equatable {
    let ranges: [ClosedRange<Int>]

    init?(status: MarketOpeningStatus, now: Date = Date()) {
        guard let intervals = status.todayOpenIntervals(at: now) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: status.timeZoneID) ?? TimeZone(identifier: "Asia/Kolkata")!
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        func minute(_ date: Date) -> Int {
            if date >= dayEnd { return 1439 }
            return calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        }
        ranges = intervals.map { minute($0.start)...minute($0.end) }
    }

    var hours: [Int] {
        Array(Set(ranges.flatMap { Array(($0.lowerBound / 60)...($0.upperBound / 60)) })).sorted()
    }

    func adjusted(_ minutes: Int) -> Int {
        guard !ranges.contains(where: { $0.contains(minutes) }) else { return minutes }
        return ranges.flatMap { [$0.lowerBound, $0.upperBound] }
            .min { abs($0 - minutes) < abs($1 - minutes) } ?? minutes
    }

    func permits(from: Int, to: Int) -> Bool {
        from < to && ranges.contains { $0.contains(from) && $0.contains(to) }
    }

    var label: String {
        ranges.map {
            "\(MarketScheduleRow.compactHours(Self.timeLabel($0.lowerBound))) – \(MarketScheduleRow.compactHours(Self.timeLabel($0.upperBound)))"
        }.joined(separator: ", ")
    }

    private static func timeLabel(_ minute: Int) -> String {
        let hour = minute / 60
        return String(format: "%d:%02d %@", hour % 12 == 0 ? 12 : hour % 12, minute % 60, hour < 12 ? "AM" : "PM")
    }
}

struct MarketOpeningPeriod: Decodable {
    struct Point: Decodable {
        struct LocalDate: Decodable { let year: Int; let month: Int; let day: Int }
        let day: Int?
        let hour: Int?
        let minute: Int?
        let date: LocalDate?
    }
    let open: Point
    let close: Point?
}

struct MarketOpeningStatus {
    let isOpen: Bool?
    let nextOpening: Date?
    let nextClosing: Date?
    let expiresAt: Date
    var weekdayDescriptions: [String] = []
    var timeZoneID: String = "Asia/Kolkata"
    var currentPeriods: [MarketOpeningPeriod]? = nil
    var regularPeriods: [MarketOpeningPeriod]? = nil
    var currentWeekdayDescriptions: [String]? = nil

    /// Today's real opening intervals, clipped to the market's local calendar day.
    /// nil means no reliable schedule; an empty array means closed all day.
    func todayOpenIntervals(at now: Date = Date()) -> [DateInterval]? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(identifier: "Asia/Kolkata")!
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let weekday = calendar.component(.weekday, from: now) - 1
        let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        if currentWeekdayDescriptions?.contains("\(weekdayNames[weekday]): Closed") == true { return [] }
        guard let periods = currentPeriods ?? regularPeriods else {
            return weekdayDescriptions.contains("\(weekdayNames[weekday]): Closed") ? [] : nil
        }
        var intervals: [DateInterval] = []
        for period in periods {
            let openHour = period.open.hour ?? 0
            let openMinute = period.open.minute ?? 0
            guard (0..<24).contains(openHour), (0..<60).contains(openMinute) else { return nil }
            let start: Date
            let end: Date
            if let date = period.open.date {
                guard let value = calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day, hour: openHour, minute: openMinute)) else { return nil }
                start = value
                if let close = period.close, let date = close.date {
                    guard let value = calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day, hour: close.hour ?? 0, minute: close.minute ?? 0)) else { return nil }
                    end = value
                } else if period.close == nil {
                    end = max(dayEnd, start)
                } else { return nil }
            } else {
                guard let close = period.close else {
                    // Google's documented 24/7 sentinel has no closing point.
                    if (period.open.day ?? 0) == 0 && openHour == 0 && openMinute == 0 {
                        return [DateInterval(start: dayStart, end: dayEnd)]
                    }
                    return nil
                }
                let openDay = period.open.day ?? 0
                let closeDay = close.day ?? 0
                guard (0..<7).contains(openDay), (0..<7).contains(closeDay) else { return nil }
                let daysBack = (weekday - openDay + 7) % 7
                let startDay = calendar.date(byAdding: .day, value: -daysBack, to: dayStart)!
                start = calendar.date(bySettingHour: openHour, minute: openMinute, second: 0, of: startDay)!
                var daysUntilClose = (closeDay - openDay + 7) % 7
                if daysUntilClose == 0 && (close.hour ?? 0) * 60 + (close.minute ?? 0) <= openHour * 60 + openMinute { daysUntilClose = 7 }
                let closeDate = calendar.date(byAdding: .day, value: daysUntilClose, to: startDay)!
                guard let value = calendar.date(bySettingHour: close.hour ?? 0, minute: close.minute ?? 0, second: 0, of: closeDate) else { return nil }
                end = value
            }
            let clippedStart = max(dayStart, start)
            let clippedEnd = min(dayEnd, end)
            if clippedStart < clippedEnd { intervals.append(DateInterval(start: clippedStart, end: clippedEnd)) }
        }
        var merged: [DateInterval] = []
        for interval in intervals.sorted(by: { $0.start < $1.start }) {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else { merged.append(interval) }
        }
        return merged
    }

    func weeklyHours(at now: Date = Date()) -> [MarketWeekdayHours] {
        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(identifier: "Asia/Kolkata")!
        let today = (calendar.component(.weekday, from: now) + 5) % 7
        var hoursByDay: [String: String] = [:]
        for description in weekdayDescriptions {
            guard let separator = description.firstIndex(of: ":") else { continue }
            let day = String(description[..<separator])
            let hours = description[description.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !hours.isEmpty { hoursByDay[day] = MarketScheduleRow.compactHours(hours) }
        }
        return (0..<7).map { offset in
            let day = weekdays[(today + offset) % 7]
            return MarketWeekdayHours(day: day, hours: hoursByDay[day] ?? "Unavailable", isToday: offset == 0)
        }
    }

    var scheduleRows: [MarketScheduleRow] {
        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        var groups: [(hours: String, days: [Int])] = []
        for description in weekdayDescriptions {
            guard let separator = description.firstIndex(of: ":"),
                  let day = weekdays.firstIndex(of: String(description[..<separator])) else { continue }
            let hours = description[description.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !hours.isEmpty, hours.caseInsensitiveCompare("Closed") != .orderedSame else { continue }
            if let index = groups.firstIndex(where: { $0.hours == hours }) {
                groups[index].days.append(day)
            } else {
                groups.append((hours, [day]))
            }
        }
        return groups.map { group in
            let days = Array(Set(group.days)).sorted()
            var ranges: [String] = []
            var index = 0
            while index < days.count {
                let first = days[index]
                var last = first
                while index + 1 < days.count, days[index + 1] == last + 1 {
                    index += 1
                    last = days[index]
                }
                let start = String(weekdays[first].prefix(3))
                ranges.append(first == last ? start : "\(start)-\(weekdays[last].prefix(3))")
                index += 1
            }
            // Keep Google's intervals, including split and overnight hours, in compact form.
            let hours = MarketScheduleRow.compactHours(group.hours)
            return MarketScheduleRow(days: ranges.joined(separator: ", "), hours: hours)
        }
    }

    static var unavailable: Self {
        Self(isOpen: nil, nextOpening: nil, nextClosing: nil, expiresAt: Date().addingTimeInterval(30))
    }

    var label: String {
        label(at: Date())
    }

    func label(at now: Date) -> String {
        guard let isOpen else { return "Hours unavailable" }
        guard let transition = isOpen ? nextClosing : nextOpening else {
            return isOpen ? "Open" : "Closed"
        }
        let prefix = isOpen ? "Open · Closes" : "Closed · Opens"

        // These markets are in Bengaluru; don't format hours in the device's timezone.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(identifier: "Asia/Kolkata")!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = calendar.component(.minute, from: transition) == 0 ? "ha" : "h:mma"
        let time = formatter.string(from: transition).lowercased()
        if calendar.isDate(transition, inSameDayAs: now) {
            return "\(prefix) at \(time)"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(transition, inSameDayAs: tomorrow) {
            return "\(prefix) tomorrow at \(time)"
        }
        formatter.dateFormat = "EEE"
        return "\(prefix) \(formatter.string(from: transition)) at \(time)"
    }
}

@MainActor
final class MarketOpeningHoursStore: ObservableObject {
    @Published private(set) var statuses: [String: MarketOpeningStatus] = [:]
    private var isRefreshing = false

    func refresh(markets: [(String, String)], force: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let pending = markets.filter { force || (statuses[$0.0]?.expiresAt ?? .distantPast) <= Date() }
        await withTaskGroup(of: (String, MarketOpeningStatus).self) { group in
            for (id, name) in pending {
                // Never continue showing an expired open/closed state during a refresh.
                statuses[id] = nil
                group.addTask {
                    do {
                        return (id, try await GoogleMarketHours.fetch(marketName: name))
                    } catch {
                        return (id, .unavailable)
                    }
                }
            }
            for await (id, status) in group {
                guard !Task.isCancelled else { continue }
                statuses[id] = status
            }
        }
    }
}

enum GoogleMarketHours {
    // Shared with addresses and directions so hours always refer to the same listing.
    static let russellPlaceID = "ChIJwQdZj2EWrjsRvUuO1AgrS18"
    static let placeIDs: [String: String] = [
        "Raja Market": "ChIJPc7ToDMXrjsRe8YoBeRWLA4",
        "KR Market": "ChIJ_xC6VOEVrjsRy_ZNwGx87Ac",
        "Gandhi Bazaar Flower Market": "ChIJrSid6fIVrjsRbF8xr-ITHSw",
        "Russell Market": russellPlaceID,
        "Jayanagar Market": "ChIJU7PCQbwVrjsRQapyxEblmF0",
        "Sunday Market": "ChIJ6UjQKAgWrjsRyMaQpOJo2V4"
    ]
    private struct SearchResponse: Decodable {
        let places: [Place]?
    }

    private struct Place: Decodable {
        struct DisplayName: Decodable { let text: String }
        struct Hours: Decodable {
            let openNow: Bool?
            let nextOpenTime: String?
            let nextCloseTime: String?
            let weekdayDescriptions: [String]?
            let periods: [MarketOpeningPeriod]?
        }
        let id: String?
        let displayName: DisplayName?
        let businessStatus: String?
        let currentOpeningHours: Hours?
        let regularOpeningHours: Hours?
        struct PlaceTimeZone: Decodable { let id: String }
        let timeZone: PlaceTimeZone?
    }

    private enum FetchError: Error {
        case missingConfiguration, requestFailed, ambiguousPlace
    }

    static func fetch(marketName: String) async throws -> MarketOpeningStatus {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GooglePlacesAPIKey") as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !key.contains("$(") else { throw FetchError.missingConfiguration }

        guard let placeID = placeIDs[marketName] else { throw FetchError.ambiguousPlace }
        var request = URLRequest(url: URL(string: "https://places.googleapis.com/v1/places/\(placeID)?languageCode=en")!)
        request.timeoutInterval = 20
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        request.setValue("id,businessStatus,currentOpeningHours,regularOpeningHours", forHTTPHeaderField: "X-Goog-FieldMask")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FetchError.requestFailed
        }
        return try detailsStatus(from: data, expectedPlaceID: placeID)
    }

    static func detailsStatus(from data: Data, expectedPlaceID: String = russellPlaceID, now: Date = Date()) throws -> MarketOpeningStatus {
        let place = try JSONDecoder().decode(Place.self, from: data)
        guard place.id == expectedPlaceID else { throw FetchError.ambiguousPlace }
        return openingStatus(for: place, now: now)
    }

    static func status(from data: Data, marketName: String, now: Date = Date()) throws -> MarketOpeningStatus {
        let result = try JSONDecoder().decode(SearchResponse.self, from: data)
        // Google's Russell Market listing includes its neighborhood in the name.
        let listingNames = marketName == "Russell Market"
            ? [marketName, "Russell Market, Shivajinagar"] : [marketName]
        let matches = (result.places ?? []).filter { place in
            listingNames.contains { name in
                place.displayName?.text.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
        }
        // Generic names can match unrelated shops. Only accept one exact local match.
        guard matches.count == 1, let place = matches.first else { throw FetchError.ambiguousPlace }
        return openingStatus(for: place, now: now)
    }

    private static func openingStatus(for place: Place, now: Date) -> MarketOpeningStatus {
        if place.businessStatus == "CLOSED_PERMANENTLY" || place.businessStatus == "CLOSED_TEMPORARILY" {
            return MarketOpeningStatus(isOpen: false, nextOpening: nil, nextClosing: nil, expiresAt: now.addingTimeInterval(300), currentPeriods: [], regularPeriods: [])
        }
        guard let hours = place.currentOpeningHours, let openNow = hours.openNow else {
            return MarketOpeningStatus(isOpen: nil, nextOpening: nil, nextClosing: nil, expiresAt: now.addingTimeInterval(30), weekdayDescriptions: place.regularOpeningHours?.weekdayDescriptions ?? [], timeZoneID: place.timeZone?.id ?? "Asia/Kolkata", currentPeriods: place.currentOpeningHours?.periods, regularPeriods: place.regularOpeningHours?.periods, currentWeekdayDescriptions: place.currentOpeningHours?.weekdayDescriptions)
        }
        let nextOpen = timestamp(hours.nextOpenTime)
        let nextClose = timestamp(hours.nextCloseTime)
        let transition = openNow ? nextClose : nextOpen
        return MarketOpeningStatus(
            isOpen: openNow,
            nextOpening: nextOpen,
            nextClosing: nextClose,
            expiresAt: min(now.addingTimeInterval(300), transition ?? .distantFuture),
            weekdayDescriptions: place.regularOpeningHours?.weekdayDescriptions ?? [],
            timeZoneID: place.timeZone?.id ?? "Asia/Kolkata",
            currentPeriods: place.currentOpeningHours?.periods,
            regularPeriods: place.regularOpeningHours?.periods,
            currentWeekdayDescriptions: place.currentOpeningHours?.weekdayDescriptions
        )
    }

    private static func timestamp(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}
