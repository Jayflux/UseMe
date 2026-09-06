import Foundation

public struct AppUsageItem: Identifiable, Codable {
    public var id: String { bundleIdentifier }
    public let bundleIdentifier: String
    public let appName: String
    public let durationInSeconds: TimeInterval
    public let iconSystemName: String
    public let category: AppCategory

    public init(
        bundleIdentifier: String,
        appName: String,
        durationInSeconds: TimeInterval,
        iconSystemName: String = "app.fill",
        category: AppCategory? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.durationInSeconds = durationInSeconds
        self.iconSystemName = iconSystemName
        self.category = category ?? AppCategory.classify(bundleIdentifier: bundleIdentifier, appName: appName)
    }

    public var formattedDuration: String {
        UsageFormatter.format(seconds: durationInSeconds)
    }
}

public struct TimeIntervalData: Identifiable, Codable {
    public var id: String { label }
    public let label: String
    public let date: Date
    public let durationInSeconds: TimeInterval

    public init(label: String, date: Date, durationInSeconds: TimeInterval) {
        self.label = label
        self.date = date
        self.durationInSeconds = durationInSeconds
    }

    public var hours: Double {
        durationInSeconds / 3600.0
    }
}

public struct DailyUsageRecord: Codable {
    public let dateString: String // Format: yyyy-MM-dd
    public var hourlyBuckets: [Int: TimeInterval] // Hour 0...23 -> seconds
    public var appUsage: [String: TimeInterval] // BundleID -> seconds
    public var appNames: [String: String] // BundleID -> App Name

    public init(
        dateString: String,
        hourlyBuckets: [Int: TimeInterval] = [:],
        appUsage: [String: TimeInterval] = [:],
        appNames: [String: String] = [:]
    ) {
        self.dateString = dateString
        self.hourlyBuckets = hourlyBuckets
        self.appUsage = appUsage
        self.appNames = appNames
    }

    public var totalActiveSeconds: TimeInterval {
        hourlyBuckets.values.reduce(0, +)
    }

    public mutating func addActiveTime(
        seconds: TimeInterval,
        hour: Int,
        appBundleId: String,
        appName: String
    ) {
        hourlyBuckets[hour, default: 0] += seconds
        if !appBundleId.isEmpty {
            appUsage[appBundleId, default: 0] += seconds
            appNames[appBundleId] = appName
        }
    }
}

public struct UsageSummary: Codable {
    public let timeframe: UsageTimeframe
    public let totalActiveSeconds: TimeInterval
    public let goalSeconds: TimeInterval
    public let intervals: [TimeIntervalData]
    public let topApps: [AppUsageItem]
    public let categoryBreakdown: [CategoryUsageSummary]
    public let productivityScore: Int
    public let trendPercentage: Double
    public let trendDescription: String
    public let insightText: String
    public let lastUpdated: Date

    public init(
        timeframe: UsageTimeframe,
        totalActiveSeconds: TimeInterval,
        goalSeconds: TimeInterval = 8 * 3600,
        intervals: [TimeIntervalData] = [],
        topApps: [AppUsageItem] = [],
        categoryBreakdown: [CategoryUsageSummary] = [],
        productivityScore: Int = 80,
        trendPercentage: Double = 0.0,
        trendDescription: String = "Stabil",
        insightText: String = "",
        lastUpdated: Date = Date()
    ) {
        self.timeframe = timeframe
        self.totalActiveSeconds = totalActiveSeconds
        self.goalSeconds = goalSeconds
        self.intervals = intervals
        self.topApps = topApps
        self.categoryBreakdown = categoryBreakdown
        self.productivityScore = productivityScore
        self.trendPercentage = trendPercentage
        self.trendDescription = trendDescription
        self.insightText = insightText
        self.lastUpdated = lastUpdated
    }

    public var formattedDuration: String {
        UsageFormatter.format(seconds: totalActiveSeconds)
    }

    public var progress: Double {
        guard goalSeconds > 0 else { return 0.0 }
        return min(totalActiveSeconds / goalSeconds, 1.0)
    }

    public var progressPercentageString: String {
        let pct = Int(progress * 100)
        return "\(pct)%"
    }

    public static func buildSummary(
        from records: [DailyUsageRecord],
        for timeframe: UsageTimeframe,
        referenceDate: Date = Date()
    ) -> UsageSummary {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: referenceDate)
        let savedGoalHours = UserDefaults(suiteName: SharedDataManager.appGroupIdentifier)?.double(forKey: "useme_daily_goal_hours") ?? 8.0
        let goalSec: TimeInterval = (savedGoalHours > 0 ? savedGoalHours : 8.0) * (timeframe == .daily ? 3600 : (timeframe == .weekly ? 5 * 3600 : 20 * 3600))

        switch timeframe {
        case .daily:
            let todayRecord = records.first(where: { $0.dateString == todayStr })
            let total = todayRecord?.totalActiveSeconds ?? 0

            var hourly: [TimeIntervalData] = []
            for hour in 0...23 {
                let sec = todayRecord?.hourlyBuckets[hour] ?? 0
                let label = String(format: "%02d:00", hour)
                hourly.append(TimeIntervalData(label: label, date: referenceDate, durationInSeconds: sec))
            }

            var apps: [AppUsageItem] = []
            if let record = todayRecord {
                for (bundleId, duration) in record.appUsage.sorted(by: { $0.value > $1.value }) {
                    let name = record.appNames[bundleId] ?? bundleId
                    let icon = iconForApp(bundleId: bundleId, name: name)
                    let cat = AppCategory.classify(bundleIdentifier: bundleId, appName: name)
                    apps.append(AppUsageItem(bundleIdentifier: bundleId, appName: name, durationInSeconds: duration, iconSystemName: icon, category: cat))
                }
            }

            let categories = computeCategories(from: apps, totalSeconds: total)

            if total == 0 && apps.isEmpty {
                return mock(for: .daily)
            }

            let score = ProductivityInsightManager.shared.calculateScore(from: categories)
            let trend = ProductivityInsightManager.shared.calculateTrend(from: records, timeframe: .daily, referenceDate: referenceDate)
            let insight = ProductivityInsightManager.shared.generateInsight(score: score, topApps: apps, breakdown: categories)

            return UsageSummary(
                timeframe: .daily,
                totalActiveSeconds: total,
                goalSeconds: goalSec,
                intervals: hourly.filter { $0.durationInSeconds > 0 || ($0.label >= "08:00" && $0.label <= "20:00") },
                topApps: apps,
                categoryBreakdown: categories,
                productivityScore: score,
                trendPercentage: trend.trendPct,
                trendDescription: trend.description,
                insightText: insight,
                lastUpdated: referenceDate
            )

        case .weekly:
            let daySymbols = ["Min", "Sen", "Sel", "Rab", "Kam", "Jum", "Sab"]
            var weeklyIntervals: [TimeIntervalData] = []
            var aggregatedApps: [String: TimeInterval] = [:]
            var appNames: [String: String] = [:]
            var weeklyTotal: TimeInterval = 0

            for i in (0..<7).reversed() {
                guard let dayDate = calendar.date(byAdding: .day, value: -i, to: referenceDate) else { continue }
                let dayStr = formatter.string(from: dayDate)
                let dayRecord = records.first(where: { $0.dateString == dayStr })
                let daySec = dayRecord?.totalActiveSeconds ?? 0
                weeklyTotal += daySec

                let weekdayIndex = calendar.component(.weekday, from: dayDate) - 1
                let label = daySymbols[max(0, min(weekdayIndex, 6))]
                weeklyIntervals.append(TimeIntervalData(label: label, date: dayDate, durationInSeconds: daySec))

                if let r = dayRecord {
                    for (bId, dur) in r.appUsage {
                        aggregatedApps[bId, default: 0] += dur
                        if let name = r.appNames[bId] {
                            appNames[bId] = name
                        }
                    }
                }
            }

            var apps: [AppUsageItem] = []
            for (bId, dur) in aggregatedApps.sorted(by: { $0.value > $1.value }) {
                let name = appNames[bId] ?? bId
                let icon = iconForApp(bundleId: bId, name: name)
                let cat = AppCategory.classify(bundleIdentifier: bId, appName: name)
                apps.append(AppUsageItem(bundleIdentifier: bId, appName: name, durationInSeconds: dur, iconSystemName: icon, category: cat))
            }

            let categories = computeCategories(from: apps, totalSeconds: weeklyTotal)

            if weeklyTotal == 0 && apps.isEmpty {
                return mock(for: .weekly)
            }

            let score = ProductivityInsightManager.shared.calculateScore(from: categories)
            let trend = ProductivityInsightManager.shared.calculateTrend(from: records, timeframe: .weekly, referenceDate: referenceDate)
            let insight = ProductivityInsightManager.shared.generateInsight(score: score, topApps: apps, breakdown: categories)

            return UsageSummary(
                timeframe: .weekly,
                totalActiveSeconds: weeklyTotal,
                goalSeconds: goalSec,
                intervals: weeklyIntervals,
                topApps: apps,
                categoryBreakdown: categories,
                productivityScore: score,
                trendPercentage: trend.trendPct,
                trendDescription: trend.description,
                insightText: insight,
                lastUpdated: referenceDate
            )

        case .monthly:
            var monthIntervals: [TimeIntervalData] = []
            var aggregatedApps: [String: TimeInterval] = [:]
            var appNames: [String: String] = [:]
            var monthlyTotal: TimeInterval = 0

            for weekIndex in 1...4 {
                var weekSec: TimeInterval = 0
                let weekLabel = "Mgg \(weekIndex)"
                let startOffset = (4 - weekIndex) * 7
                let endOffset = startOffset - 6

                for dayOffset in stride(from: startOffset, through: max(endOffset, 0), by: -1) {
                    if let d = calendar.date(byAdding: .day, value: -dayOffset, to: referenceDate) {
                        let dStr = formatter.string(from: d)
                        if let r = records.first(where: { $0.dateString == dStr }) {
                            weekSec += r.totalActiveSeconds
                            for (bId, dur) in r.appUsage {
                                aggregatedApps[bId, default: 0] += dur
                                if let name = r.appNames[bId] {
                                    appNames[bId] = name
                                }
                            }
                        }
                    }
                }

                monthlyTotal += weekSec
                monthIntervals.append(TimeIntervalData(label: weekLabel, date: referenceDate, durationInSeconds: weekSec))
            }

            var apps: [AppUsageItem] = []
            for (bId, dur) in aggregatedApps.sorted(by: { $0.value > $1.value }) {
                let name = appNames[bId] ?? bId
                let icon = iconForApp(bundleId: bId, name: name)
                let cat = AppCategory.classify(bundleIdentifier: bId, appName: name)
                apps.append(AppUsageItem(bundleIdentifier: bId, appName: name, durationInSeconds: dur, iconSystemName: icon, category: cat))
            }

            let categories = computeCategories(from: apps, totalSeconds: monthlyTotal)

            if monthlyTotal == 0 && apps.isEmpty {
                return mock(for: .monthly)
            }

            let score = ProductivityInsightManager.shared.calculateScore(from: categories)
            let trend = ProductivityInsightManager.shared.calculateTrend(from: records, timeframe: .monthly, referenceDate: referenceDate)
            let insight = ProductivityInsightManager.shared.generateInsight(score: score, topApps: apps, breakdown: categories)

            return UsageSummary(
                timeframe: .monthly,
                totalActiveSeconds: monthlyTotal,
                goalSeconds: goalSec,
                intervals: monthIntervals,
                topApps: apps,
                categoryBreakdown: categories,
                productivityScore: score,
                trendPercentage: trend.trendPct,
                trendDescription: trend.description,
                insightText: insight,
                lastUpdated: referenceDate
            )
        }
    }

    private static func computeCategories(from apps: [AppUsageItem], totalSeconds: TimeInterval) -> [CategoryUsageSummary] {
        guard totalSeconds > 0 else { return [] }
        var dict: [AppCategory: TimeInterval] = [:]
        for app in apps {
            dict[app.category, default: 0] += app.durationInSeconds
        }
        return dict.map { cat, dur in
            CategoryUsageSummary(category: cat, durationInSeconds: dur, percentage: dur / totalSeconds)
        }.sorted(by: { $0.durationInSeconds > $1.durationInSeconds })
    }

    private static func iconForApp(bundleId: String, name: String) -> String {
        let b = bundleId.lowercased()
        let n = name.lowercased()
        if b.contains("xcode") || n.contains("xcode") { return "hammer.fill" }
        if b.contains("safari") || n.contains("safari") { return "safari.fill" }
        if b.contains("chrome") || n.contains("chrome") { return "globe" }
        if b.contains("terminal") || n.contains("terminal") || b.contains("iterm") { return "terminal.fill" }
        if b.contains("vscode") || n.contains("code") { return "chevron.left.forwardslash.chevron.right" }
        if b.contains("slack") || n.contains("slack") { return "bubble.left.and.bubble.right.fill" }
        if b.contains("figma") || n.contains("figma") { return "paintpalette.fill" }
        if b.contains("music") || n.contains("spotify") { return "music.note" }
        if b.contains("finder") { return "folder.fill" }
        return "app.fill"
    }

    public static func mock(for timeframe: UsageTimeframe) -> UsageSummary {
        let calendar = Calendar.current
        let now = Date()

        switch timeframe {
        case .daily:
            var hourly: [TimeIntervalData] = []
            for hour in 8...18 {
                let label = String(format: "%02d:00", hour)
                let duration: TimeInterval = (hour % 2 == 0) ? 3200 : 1800
                hourly.append(TimeIntervalData(label: label, date: now, durationInSeconds: duration))
            }
            let apps = [
                AppUsageItem(bundleIdentifier: "com.apple.dt.Xcode", appName: "Xcode", durationInSeconds: 3 * 3600 + 15 * 60, iconSystemName: "hammer.fill", category: .development),
                AppUsageItem(bundleIdentifier: "com.apple.Safari", appName: "Safari", durationInSeconds: 1 * 3600 + 45 * 60, iconSystemName: "safari.fill", category: .browsing),
                AppUsageItem(bundleIdentifier: "com.google.Chrome", appName: "Google Chrome", durationInSeconds: 45 * 60, iconSystemName: "globe", category: .browsing),
                AppUsageItem(bundleIdentifier: "com.apple.Terminal", appName: "Terminal", durationInSeconds: 30 * 60, iconSystemName: "terminal.fill", category: .development)
            ]
            let total: TimeInterval = 5 * 3600 + 42 * 60
            let categories = [
                CategoryUsageSummary(category: .development, durationInSeconds: 3 * 3600 + 45 * 60, percentage: 0.65),
                CategoryUsageSummary(category: .browsing, durationInSeconds: 1 * 3600 + 30 * 60, percentage: 0.26),
                CategoryUsageSummary(category: .productivity, durationInSeconds: 27 * 60, percentage: 0.09)
            ]
            return UsageSummary(
                timeframe: .daily,
                totalActiveSeconds: total,
                goalSeconds: 8 * 3600,
                intervals: hourly,
                topApps: apps,
                categoryBreakdown: categories,
                productivityScore: 82,
                trendPercentage: 0.12,
                trendDescription: "↑ 12% vs kemarin",
                insightText: "Performa luar biasa! Waktu Anda didominasi kategori Pengembangan (65%).",
                lastUpdated: now
            )

        case .weekly:
            let days = ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"]
            var dailyData: [TimeIntervalData] = []
            let durations: [TimeInterval] = [6.2, 7.5, 8.1, 5.8, 6.9, 3.4, 2.5].map { $0 * 3600 }
            for (index, day) in days.enumerated() {
                let date = calendar.date(byAdding: .day, value: -(6 - index), to: now) ?? now
                dailyData.append(TimeIntervalData(label: day, date: date, durationInSeconds: durations[index]))
            }
            let apps = [
                AppUsageItem(bundleIdentifier: "com.apple.dt.Xcode", appName: "Xcode", durationInSeconds: 18 * 3600, iconSystemName: "hammer.fill", category: .development),
                AppUsageItem(bundleIdentifier: "com.apple.Safari", appName: "Safari", durationInSeconds: 11 * 3600, iconSystemName: "safari.fill", category: .browsing),
                AppUsageItem(bundleIdentifier: "com.google.Chrome", appName: "Chrome", durationInSeconds: 6 * 3600, iconSystemName: "globe", category: .browsing)
            ]
            let total = durations.reduce(0, +)
            let categories = [
                CategoryUsageSummary(category: .development, durationInSeconds: 24 * 3600, percentage: 0.60),
                CategoryUsageSummary(category: .browsing, durationInSeconds: 12 * 3600, percentage: 0.30),
                CategoryUsageSummary(category: .productivity, durationInSeconds: 4 * 3600, percentage: 0.10)
            ]
            return UsageSummary(
                timeframe: .weekly,
                totalActiveSeconds: total,
                goalSeconds: 40 * 3600,
                intervals: dailyData,
                topApps: apps,
                categoryBreakdown: categories,
                productivityScore: 85,
                trendPercentage: 0.08,
                trendDescription: "↑ 8% vs minggu lalu",
                insightText: "Fokus kerja sangat baik! Teruskan ritme produktif Anda minggu ini.",
                lastUpdated: now
            )

        case .monthly:
            var weeks: [TimeIntervalData] = []
            let weekDurations: [TimeInterval] = [38, 42, 35, 40].map { $0 * 3600 }
            for i in 1...4 {
                let date = calendar.date(byAdding: .day, value: -(28 - (i * 7)), to: now) ?? now
                weeks.append(TimeIntervalData(label: "Mgg \(i)", date: date, durationInSeconds: weekDurations[i - 1]))
            }
            let apps = [
                AppUsageItem(bundleIdentifier: "com.apple.dt.Xcode", appName: "Xcode", durationInSeconds: 70 * 3600, iconSystemName: "hammer.fill", category: .development),
                AppUsageItem(bundleIdentifier: "com.apple.Safari", appName: "Safari", durationInSeconds: 45 * 3600, iconSystemName: "safari.fill", category: .browsing),
                AppUsageItem(bundleIdentifier: "com.figma.Desktop", appName: "Figma", durationInSeconds: 22 * 3600, iconSystemName: "paintpalette.fill", category: .design)
            ]
            let total = weekDurations.reduce(0, +)
            let categories = [
                CategoryUsageSummary(category: .development, durationInSeconds: 90 * 3600, percentage: 0.58),
                CategoryUsageSummary(category: .browsing, durationInSeconds: 45 * 3600, percentage: 0.29),
                CategoryUsageSummary(category: .design, durationInSeconds: 20 * 3600, percentage: 0.13)
            ]
            return UsageSummary(
                timeframe: .monthly,
                totalActiveSeconds: total,
                goalSeconds: 160 * 3600,
                intervals: weeks,
                topApps: apps,
                categoryBreakdown: categories,
                productivityScore: 78,
                trendPercentage: -0.05,
                trendDescription: "↓ 5% vs bulan lalu",
                insightText: "Keseimbangan aktivitas cukup baik dengan Xcode dan Safari mendominasi.",
                lastUpdated: now
            )
        }
    }
}

public enum UsageFormatter {
    public static func format(seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)j \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    public static func formatDetailed(seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return "\(hours) jam \(minutes) mnt"
        } else if minutes > 0 {
            return "\(minutes) mnt \(secs) dtk"
        } else {
            return "\(secs) dtk"
        }
    }
}
