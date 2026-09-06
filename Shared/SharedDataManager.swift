import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

public final class SharedDataManager {
    public static let shared = SharedDataManager()

    public static let appGroupIdentifier = "group.com.juan.UseMe"
    private let dailyRecordsKey = "useme_daily_records"

    private let userDefaults: UserDefaults

    public init(appGroup: String = appGroupIdentifier) {
        if let sharedDefaults = UserDefaults(suiteName: appGroup) {
            self.userDefaults = sharedDefaults
        } else {
            self.userDefaults = .standard
        }
    }

    private func key(for timeframe: UsageTimeframe) -> String {
        return "usage_summary_\(timeframe.rawValue)"
    }

    public func saveSummary(_ summary: UsageSummary) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(summary) {
            userDefaults.set(encoded, forKey: key(for: summary.timeframe))
            userDefaults.synchronize()
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }

    public func loadSummary(for timeframe: UsageTimeframe) -> UsageSummary {
        let decoder = JSONDecoder()
        if let data = userDefaults.data(forKey: key(for: timeframe)),
           let summary = try? decoder.decode(UsageSummary.self, from: data) {
            return summary
        }
        return UsageSummary.mock(for: timeframe)
    }

    // MARK: - Daily Records Persistence

    public func loadDailyRecords() -> [DailyUsageRecord] {
        guard let data = userDefaults.data(forKey: dailyRecordsKey) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([DailyUsageRecord].self, from: data)) ?? []
    }

    public func saveDailyRecords(_ records: [DailyUsageRecord]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(records) {
            userDefaults.set(data, forKey: dailyRecordsKey)
            userDefaults.synchronize()
        }
    }

    public func recordActiveTime(
        seconds: TimeInterval,
        appBundleId: String,
        appName: String,
        date: Date = Date()
    ) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: date)
        let hour = Calendar.current.component(.hour, from: date)

        var records = loadDailyRecords()
        if let index = records.firstIndex(where: { $0.dateString == todayStr }) {
            records[index].addActiveTime(seconds: seconds, hour: hour, appBundleId: appBundleId, appName: appName)
        } else {
            var newRecord = DailyUsageRecord(dateString: todayStr)
            newRecord.addActiveTime(seconds: seconds, hour: hour, appBundleId: appBundleId, appName: appName)
            records.append(newRecord)
        }

        // Keep last 60 days
        if records.count > 60 {
            records = Array(records.suffix(60))
        }

        saveDailyRecords(records)
        recalculateSummaries(from: records, referenceDate: date)
    }

    public func recalculateSummaries(from records: [DailyUsageRecord]? = nil, referenceDate: Date = Date()) {
        let allRecords = records ?? loadDailyRecords()
        for timeframe in UsageTimeframe.allCases {
            let summary = UsageSummary.buildSummary(from: allRecords, for: timeframe, referenceDate: referenceDate)
            saveSummary(summary)
        }
    }

    public func seedInitialDataIfNeeded() {
        var records = loadDailyRecords()
        if records.isEmpty {
            let calendar = Calendar.current
            let now = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            // Seed 7 days of realistic history
            for dayOffset in (1...7).reversed() {
                guard let pastDate = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
                let dateStr = formatter.string(from: pastDate)
                var daily = DailyUsageRecord(dateString: dateStr)
                let hours = [9, 10, 11, 14, 15, 16, 17]
                for h in hours {
                    daily.addActiveTime(seconds: 2800, hour: h, appBundleId: "com.apple.dt.Xcode", appName: "Xcode")
                    daily.addActiveTime(seconds: 1200, hour: h, appBundleId: "com.apple.Safari", appName: "Safari")
                }
                records.append(daily)
            }

            // Seed today
            let todayStr = formatter.string(from: now)
            let currentHour = calendar.component(.hour, from: now)
            var today = DailyUsageRecord(dateString: todayStr)
            today.addActiveTime(seconds: 1800, hour: currentHour, appBundleId: "com.apple.dt.Xcode", appName: "Xcode")
            records.append(today)

            saveDailyRecords(records)
            recalculateSummaries(from: records, referenceDate: now)
        }
    }
}
