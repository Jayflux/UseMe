import Foundation
import SwiftUI

public enum AppCategory: String, CaseIterable, Codable, Identifiable {
    case development = "development"
    case browsing = "browsing"
    case productivity = "productivity"
    case design = "design"
    case entertainment = "entertainment"
    case utilities = "utilities"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .development: return "Pengembangan"
        case .browsing: return "Web Browsing"
        case .productivity: return "Produktivitas"
        case .design: return "Desain & Kreatif"
        case .entertainment: return "Hiburan & Media"
        case .utilities: return "Utilitas & Sistem"
        }
    }

    public var iconSystemName: String {
        switch self {
        case .development: return "hammer.fill"
        case .browsing: return "safari.fill"
        case .productivity: return "briefcase.fill"
        case .design: return "paintpalette.fill"
        case .entertainment: return "play.tv.fill"
        case .utilities: return "wrench.and.screwdriver.fill"
        }
    }

    public var color: Color {
        switch self {
        case .development: return .blue
        case .browsing: return .teal
        case .productivity: return .green
        case .design: return .purple
        case .entertainment: return .orange
        case .utilities: return .gray
        }
    }

    public static func classify(bundleIdentifier: String, appName: String) -> AppCategory {
        let b = bundleIdentifier.lowercased()
        let n = appName.lowercased()

        // Development
        if b.contains("xcode") || n.contains("xcode") ||
           b.contains("terminal") || n.contains("terminal") ||
           b.contains("iterm") || n.contains("iterm") ||
           b.contains("vscode") || n.contains("visual studio") ||
           b.contains("sublime") || b.contains("pycharm") ||
           b.contains("intellij") || b.contains("github") ||
           b.contains("cursor") || b.contains("antigravity") {
            return .development
        }

        // Web Browsing
        if b.contains("safari") || n.contains("safari") ||
           b.contains("chrome") || n.contains("chrome") ||
           b.contains("firefox") || n.contains("firefox") ||
           b.contains("arc") || n.contains("arc") ||
           b.contains("brave") || b.contains("edge") ||
           b.contains("opera") {
            return .browsing
        }

        // Design & Creative
        if b.contains("figma") || n.contains("figma") ||
           b.contains("sketch") || n.contains("sketch") ||
           b.contains("photoshop") || b.contains("illustrator") ||
           b.contains("canva") || b.contains("blender") ||
           b.contains("finalcut") || b.contains("imovie") {
            return .design
        }

        // Productivity & Communication
        if b.contains("slack") || n.contains("slack") ||
           b.contains("notion") || n.contains("notion") ||
           b.contains("obsidian") || n.contains("obsidian") ||
           b.contains("teams") || b.contains("zoom") ||
           b.contains("mail") || b.contains("pages") ||
           b.contains("numbers") || b.contains("keynote") ||
           b.contains("microsoft") || b.contains("excel") ||
           b.contains("word") || b.contains("calendar") ||
           b.contains("notes") || b.contains("reminders") {
            return .productivity
        }

        // Entertainment & Media
        if b.contains("spotify") || n.contains("spotify") ||
           b.contains("music") || b.contains("podcasts") ||
           b.contains("tv") || b.contains("netflix") ||
           b.contains("youtube") || b.contains("vlc") ||
           b.contains("discord") || b.contains("steam") {
            return .entertainment
        }

        // Utilities
        return .utilities
    }
}

public struct CategoryUsageSummary: Identifiable, Codable {
    public var id: String { category.rawValue }
    public let category: AppCategory
    public let durationInSeconds: TimeInterval
    public let percentage: Double

    public init(category: AppCategory, durationInSeconds: TimeInterval, percentage: Double) {
        self.category = category
        self.durationInSeconds = durationInSeconds
        self.percentage = percentage
    }

    public var formattedDuration: String {
        UsageFormatter.format(seconds: durationInSeconds)
    }

    public var percentageString: String {
        "\(Int(percentage * 100))%"
    }
}
