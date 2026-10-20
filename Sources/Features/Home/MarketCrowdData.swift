import Foundation

struct MarketCrowdSample: Identifiable, Equatable {
    let hour: Int
    let percent: Int
    var startMinute: Int
    var endMinute: Int
    var id: Int { startMinute }
    init(hour: Int, percent: Int, startMinute: Int? = nil, endMinute: Int? = nil) {
        self.hour = hour
        self.percent = percent
        self.startMinute = startMinute ?? hour * 60
        self.endMinute = endMinute ?? (hour + 1) * 60
    }
}

struct MarketCrowdSnapshot: Equatable {
    let marketID: String
    let samples: [MarketCrowdSample]
    let currentHour: Int
    let generatedAt: Date
    var currentMinute: Int = 0
    // No real crowd provider is configured: every snapshot is explicitly simulated.
    let sourceLabel = "Demo data"
    let sourceDescription = "Generated sample data, not measured crowd levels."

    func isCurrent(_ sample: MarketCrowdSample) -> Bool {
        sample.startMinute <= currentMinute && currentMinute < sample.endMinute
    }
    // A current-hour bar represents the latest value for that hour, not a forecast.
    // Later hours and later opening intervals within this hour are never displayed.
    var visibleSamples: [MarketCrowdSample] { samples.filter { $0.startMinute <= currentMinute } }
    var scrollStart: Double { Double(samples.first?.startMinute ?? 0) }
    var scrollEnd: Double { Double(samples.last?.endMinute ?? 60) }
    var scrollWindow: Double { min(480, scrollEnd - scrollStart) }
    var maxScrollPosition: Double { max(scrollStart, scrollEnd - scrollWindow) }
    var preferredScrollPosition: Double {
        let latest = visibleSamples.first(where: isCurrent) ?? visibleSamples.last
        let center = latest.map { Double($0.startMinute + $0.endMinute) / 2 } ?? scrollStart
        // Keep the current bar comfortably inside the viewport, with earlier hours visible.
        return min(maxScrollPosition, max(scrollStart, center - scrollWindow * 0.75))
    }
    var isOpenNow: Bool { samples.contains(where: isCurrent) }
    var currentPercent: Int { samples.first(where: isCurrent)?.percent ?? 0 }
    var openRanges: [Range<Int>] {
        var ranges: [Range<Int>] = []
        for sample in samples {
            if let last = ranges.last, last.upperBound == sample.startMinute {
                ranges[ranges.count - 1] = last.lowerBound..<sample.endMinute
            } else { ranges.append(sample.startMinute..<sample.endMinute) }
        }
        return ranges
    }
    var openHoursLabel: String {
        openRanges.map { "\(Self.timeLabel($0.lowerBound)) – \(Self.timeLabel($0.upperBound))" }.joined(separator: ", ")
    }
    var axisMinutes: [Int] {
        // The axis represents today's opening window; visibleSamples independently
        // prevents crowd values for future hours from appearing on the graph.
        guard let first = samples.first, let last = samples.last else { return [] }
        let endpoint = last.endMinute
        let step = endpoint - first.startMinute <= 240 ? 60 : 120
        var ticks = [first.startMinute]
        var tick = ((first.startMinute / step) + 1) * step
        while tick < endpoint {
            if samples.contains(where: { $0.startMinute <= tick && tick < $0.endMinute }),
               tick - ticks.last! >= 45, endpoint - tick >= 45 { ticks.append(tick) }
            tick += step
        }
        ticks.append(endpoint)
        ticks += openRanges.flatMap { [$0.lowerBound, $0.upperBound] }
        return Array(Set(ticks)).sorted()
    }
    var levelTitle: String {
        if !isOpenNow { return "Closed now" }
        if currentPercent < 35 { return "Low crowd" }
        if currentPercent < 65 { return "Moderate crowd" }
        return "High crowd"
    }
    static func hourLabel(_ hour: Int) -> String {
        timeLabel(hour * 60)
    }
    static func timeLabel(_ minutes: Int) -> String {
        let minuteOfDay = minutes % 1440
        let hour = minuteOfDay / 60
        let minute = minuteOfDay % 60
        let value = hour % 12
        let fraction = minute == 0 ? "" : String(format: ":%02d", minute)
        return "\(value == 0 ? 12 : value)\(fraction)\(hour < 12 ? "am" : "pm")"
    }
}

enum MarketCrowdData {
    static let refreshInterval: TimeInterval = 600

    static func demo(marketID: String, timeZoneID: String, now: Date = Date(), openIntervals: [DateInterval]? = nil) -> MarketCrowdSnapshot {
        let timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(identifier: "Asia/Kolkata")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: now)
        let hour = calendar.component(.hour, from: now)
        let bucket = Int64(floor(now.timeIntervalSince1970 / refreshInterval))
        var random = Generator(seed: "\(marketID)|\(date)")
        let morningPeak = 8 + random.unit() * 4
        let afternoonPeak = 13 + random.unit() * 3
        let eveningPeak = 18 + random.unit() * 3
        let morningStrength = 0.15 + random.unit() * 0.3
        let afternoonStrength = 0.2 + random.unit() * 0.4
        let eveningStrength = 0.15 + random.unit() * 0.35
        var currentRandom = Generator(seed: "\(marketID)|\(date)|\(bucket)")
        let variation = Int(currentRandom.unit() * 17) - 8
        let wholeDaySamples = (0..<24).map { sampleHour in
            func peak(at center: Double, strength: Double) -> Double {
                strength * exp(-pow(Double(sampleHour) - center, 2) / 8)
            }
            let value = 0.07 + random.unit() * 0.14
                + peak(at: morningPeak, strength: morningStrength)
                + peak(at: afternoonPeak, strength: afternoonStrength)
                + peak(at: eveningPeak, strength: eveningStrength)
            let percent = Int((value * 100).rounded()) + (sampleHour == hour ? variation : 0)
            return MarketCrowdSample(hour: sampleHour, percent: min(98, max(5, percent)))
        }
        let samples: [MarketCrowdSample]
        if let openIntervals {
            let start = calendar.startOfDay(for: now)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: start)!
            func minute(_ date: Date) -> Int {
                if date >= nextDay { return 1440 }
                return calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
            }
            samples = wholeDaySamples.flatMap { sample in
                openIntervals.compactMap { interval in
                    let lower = max(sample.startMinute, minute(interval.start))
                    let upper = min(sample.endMinute, minute(interval.end))
                    guard lower < upper else { return nil }
                    return MarketCrowdSample(hour: sample.hour, percent: sample.percent, startMinute: lower, endMinute: upper)
                }
            }
        } else { samples = wholeDaySamples }
        return MarketCrowdSnapshot(
            marketID: marketID, samples: samples, currentHour: hour,
            generatedAt: Date(timeIntervalSince1970: Double(bucket) * refreshInterval),
            currentMinute: hour * 60 + calendar.component(.minute, from: now)
        )
    }

    private struct Generator {
        var state: UInt64 = 14695981039346656037
        init(seed: String) {
            for byte in seed.utf8 {
                state = (state ^ UInt64(byte)) &* 1099511628211
            }
        }
        mutating func unit() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / 9007199254740992
        }
    }
}
