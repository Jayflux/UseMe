import Foundation
import UserNotifications

/// Manages per-app daily usage limits
/// Stores limits as [BundleID: seconds] in App Group UserDefaults
final class AppLimitManager: ObservableObject {
    static let shared = AppLimitManager()

    private let defaults = UserDefaults(suiteName: SharedDataManager.appGroupIdentifier)
    private let limitsKey = "useme_app_limits"
    private let notifiedKey = "useme_limit_notified"

    /// Limits dictionary: bundleIdentifier → max daily seconds
    @Published var limits: [String: TimeInterval] = [:]

    private init() {
        loadLimits()
    }

    // MARK: - CRUD

    func setLimit(for bundleId: String, hours: Double) {
        let seconds = hours * 3600
        if seconds > 0 {
            limits[bundleId] = seconds
        } else {
            limits.removeValue(forKey: bundleId)
        }
        saveLimits()
    }

    func removeLimit(for bundleId: String) {
        limits.removeValue(forKey: bundleId)
        saveLimits()
    }

    func limitHours(for bundleId: String) -> Double {
        guard let secs = limits[bundleId] else { return 0 }
        return secs / 3600
    }

    func hasLimit(for bundleId: String) -> Bool {
        return limits[bundleId] != nil
    }

    // MARK: - Progress Checking

    /// Returns usage progress (0.0 – 1.0+) for a given app
    func usageProgress(for bundleId: String, currentSeconds: TimeInterval) -> Double {
        guard let limit = limits[bundleId], limit > 0 else { return 0 }
        return currentSeconds / limit
    }

    /// Checks all apps against their limits and sends notifications if exceeded
    func checkLimits(appUsage: [String: TimeInterval], appNames: [String: String]) {
        let today = todayString()
        var notifiedToday = loadNotifiedSet(for: today)

        for (bundleId, usedSeconds) in appUsage {
            guard let limitSeconds = limits[bundleId] else { continue }
            guard usedSeconds >= limitSeconds else { continue }
            guard !notifiedToday.contains(bundleId) else { continue }

            // Exceeded! Send notification
            let appName = appNames[bundleId] ?? bundleId
            let usedFormatted = UsageFormatter.format(seconds: usedSeconds)
            let limitFormatted = UsageFormatter.format(seconds: limitSeconds)

            sendLimitNotification(
                appName: appName,
                usedFormatted: usedFormatted,
                limitFormatted: limitFormatted
            )
            notifiedToday.insert(bundleId)
        }

        saveNotifiedSet(notifiedToday, for: today)
    }

    // MARK: - Notification

    private func sendLimitNotification(appName: String, usedFormatted: String, limitFormatted: String) {
        SoundManager.shared.playLimitExceeded()

        let content = UNMutableNotificationContent()
        content.title = "⚠️ Batas Penggunaan Tercapai"
        content.body = "\(appName) sudah digunakan \(usedFormatted). Batas harian: \(limitFormatted)."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "AppLimit_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[AppLimitManager] Notification error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Persistence

    private func saveLimits() {
        let encoded = limits.mapValues { Int($0) }
        defaults?.set(encoded, forKey: limitsKey)
    }

    private func loadLimits() {
        guard let dict = defaults?.dictionary(forKey: limitsKey) as? [String: Int] else { return }
        limits = dict.mapValues { TimeInterval($0) }
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func loadNotifiedSet(for dateKey: String) -> Set<String> {
        let key = "\(notifiedKey)_\(dateKey)"
        guard let arr = defaults?.stringArray(forKey: key) else { return [] }
        return Set(arr)
    }

    private func saveNotifiedSet(_ set: Set<String>, for dateKey: String) {
        let key = "\(notifiedKey)_\(dateKey)"
        defaults?.set(Array(set), forKey: key)
    }
}
