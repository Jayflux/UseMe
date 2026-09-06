import AppIntents
import WidgetKit

public enum TimeframeAppEnum: String, AppEnum {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Periode Penggunaan"
    public static var caseDisplayRepresentations: [TimeframeAppEnum: DisplayRepresentation] = [
        .daily: DisplayRepresentation(title: "Harian", subtitle: "Waktu aktif hari ini"),
        .weekly: DisplayRepresentation(title: "Mingguan", subtitle: "7 hari terakhir"),
        .monthly: DisplayRepresentation(title: "Bulanan", subtitle: "30 hari terakhir")
    ]

    public var toUsageTimeframe: UsageTimeframe {
        switch self {
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        }
    }
}

/// AppIntent for in-widget interactive timeframe switching
/// Used with Button(intent:) on medium & large widget surfaces
public struct ChangeWidgetTimeframeIntent: AppIntent {
    public static var title: LocalizedStringResource = "Ubah Periode Widget"
    public static var description = IntentDescription("Ganti periode tampilan widget antara Harian, Mingguan, atau Bulanan langsung dari widget.")

    @Parameter(title: "Periode")
    public var timeframe: TimeframeAppEnum

    public init() {
        self.timeframe = .daily
    }

    public init(timeframe: TimeframeAppEnum) {
        self.timeframe = timeframe
    }

    public func perform() async throws -> some IntentResult {
        // Save chosen timeframe to App Group so widget provider reads it
        let defaults = UserDefaults(suiteName: SharedDataManager.appGroupIdentifier)
        defaults?.set(timeframe.rawValue, forKey: "useme_widget_active_timeframe")

        // Reload all widget timelines
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
