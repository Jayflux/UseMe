import Foundation

/// Productivity & Trend Analytics Manager
/// Calculates a 0-100 productivity score, computes trend vs previous period,
/// and produces actionable Indonesian insights.
public final class ProductivityInsightManager {
    public static let shared = ProductivityInsightManager()

    private init() {}

    // MARK: - Productivity Score Calculation

    /// Calculates productivity score from 0 to 100 based on category breakdown
    public func calculateScore(from breakdown: [CategoryUsageSummary]) -> Int {
        guard !breakdown.isEmpty else { return 80 } // Default baseline if empty

        let totalSeconds = breakdown.reduce(0) { $0 + $1.durationInSeconds }
        guard totalSeconds > 0 else { return 80 }

        var weightedScore: Double = 0.0

        for item in breakdown {
            let weight = item.category.productivityWeight
            weightedScore += item.durationInSeconds * weight
        }

        let normalizedScore = (weightedScore / totalSeconds) * 100.0
        return max(10, min(100, Int(normalizedScore)))
    }

    /// Evaluates productivity level label
    public func scoreLabel(for score: Int) -> String {
        switch score {
        case 85...100:
            return "Sangat Produktif"
        case 70..<85:
            return "Produktif"
        case 50..<70:
            return "Seimbang"
        default:
            return "Banyak Distraksi"
        }
    }

    // MARK: - Trend Analysis

    /// Compares usage of reference date against previous period
    /// Returns (trendPercentage: Double, description: String)
    public func calculateTrend(
        from records: [DailyUsageRecord],
        timeframe: UsageTimeframe,
        referenceDate: Date = Date()
    ) -> (trendPct: Double, description: String) {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        switch timeframe {
        case .daily:
            // Compare today vs yesterday
            let todayStr = formatter.string(from: referenceDate)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate
            let yesterdayStr = formatter.string(from: yesterday)

            let todaySec = records.first(where: { $0.dateString == todayStr })?.totalActiveSeconds ?? 0
            let yesterdaySec = records.first(where: { $0.dateString == yesterdayStr })?.totalActiveSeconds ?? 0

            guard yesterdaySec > 0 else {
                return (0.0, "Belum ada data kemarin")
            }

            let diff = (todaySec - yesterdaySec) / yesterdaySec
            let pct = Int(abs(diff * 100))
            let arrow = diff >= 0 ? "↑" : "↓"
            let desc = "\(arrow) \(pct)% vs kemarin"
            return (diff, desc)

        case .weekly:
            // Compare last 7 days vs previous 7 days
            var thisWeekSec: TimeInterval = 0
            var prevWeekSec: TimeInterval = 0

            for i in 0..<7 {
                if let d = calendar.date(byAdding: .day, value: -i, to: referenceDate) {
                    thisWeekSec += records.first(where: { $0.dateString == formatter.string(from: d) })?.totalActiveSeconds ?? 0
                }
            }

            for i in 7..<14 {
                if let d = calendar.date(byAdding: .day, value: -i, to: referenceDate) {
                    prevWeekSec += records.first(where: { $0.dateString == formatter.string(from: d) })?.totalActiveSeconds ?? 0
                }
            }

            guard prevWeekSec > 0 else {
                return (0.0, "Belum ada data minggu lalu")
            }

            let diff = (thisWeekSec - prevWeekSec) / prevWeekSec
            let pct = Int(abs(diff * 100))
            let arrow = diff >= 0 ? "↑" : "↓"
            let desc = "\(arrow) \(pct)% vs minggu lalu"
            return (diff, desc)

        case .monthly:
            // Compare last 30 days vs previous 30 days
            var thisMonthSec: TimeInterval = 0
            var prevMonthSec: TimeInterval = 0

            for i in 0..<30 {
                if let d = calendar.date(byAdding: .day, value: -i, to: referenceDate) {
                    thisMonthSec += records.first(where: { $0.dateString == formatter.string(from: d) })?.totalActiveSeconds ?? 0
                }
            }

            for i in 30..<60 {
                if let d = calendar.date(byAdding: .day, value: -i, to: referenceDate) {
                    prevMonthSec += records.first(where: { $0.dateString == formatter.string(from: d) })?.totalActiveSeconds ?? 0
                }
            }

            guard prevMonthSec > 0 else {
                return (0.0, "Belum ada data bulan lalu")
            }

            let diff = (thisMonthSec - prevMonthSec) / prevMonthSec
            let pct = Int(abs(diff * 100))
            let arrow = diff >= 0 ? "↑" : "↓"
            let desc = "\(arrow) \(pct)% vs bulan lalu"
            return (diff, desc)
        }
    }

    // MARK: - Insight Text Generator

    public func generateInsight(score: Int, topApps: [AppUsageItem], breakdown: [CategoryUsageSummary]) -> String {
        let topCat = breakdown.first
        let topAppName = topApps.first?.appName ?? "Aplikasi utama"

        if score >= 80 {
            if let cat = topCat {
                return "Performa luar biasa! Waktu Anda didominasi kategori \(cat.category.displayName) (\(cat.percentageString))."
            }
            return "Fokus kerja sangat baik! Teruskan ritme produktif Anda hari ini."
        } else if score >= 60 {
            return "Keseimbangan aktivitas cukup baik dengan \(topAppName) sebagai aplikasi paling banyak digunakan."
        } else {
            return "Penggunaan kategori non-produktif cukup tinggi hari ini. Coba gunakan Mode Fokus untuk meminimalkan distraksi."
        }
    }
}

// MARK: - Productivity Weight on AppCategory
extension AppCategory {
    public var productivityWeight: Double {
        switch self {
        case .development:
            return 1.0
        case .productivity:
            return 1.0
        case .design:
            return 0.9
        case .utilities:
            return 0.7
        case .browsing:
            return 0.5
        case .entertainment:
            return 0.15
        }
    }
}
