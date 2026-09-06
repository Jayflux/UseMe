import Foundation

public enum UsageTimeframe: String, CaseIterable, Codable, Identifiable {
    case daily
    case weekly
    case monthly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .daily:
            return "Harian"
        case .weekly:
            return "Mingguan"
        case .monthly:
            return "Bulanan"
        }
    }

    public var subtitle: String {
        switch self {
        case .daily:
            return "Penggunaan Hari Ini"
        case .weekly:
            return "7 Hari Terakhir"
        case .monthly:
            return "30 Hari Terakhir"
        }
    }

    public var systemImage: String {
        switch self {
        case .daily:
            return "clock.fill"
        case .weekly:
            return "calendar"
        case .monthly:
            return "calendar.badge.clock"
        }
    }
}
