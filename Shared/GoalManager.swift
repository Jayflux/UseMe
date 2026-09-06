import Foundation
import UserNotifications
import Combine

public final class GoalManager: ObservableObject {
    public static let shared = GoalManager()

    private let goalKey = "useme_daily_goal_hours"
    private let notificationsKey = "useme_notifications_enabled"
    private let userDefaults: UserDefaults

    @Published public var dailyGoalHours: Double {
        didSet {
            userDefaults.set(dailyGoalHours, forKey: goalKey)
            SharedDataManager.shared.recalculateSummaries()
        }
    }

    @Published public var notificationsEnabled: Bool {
        didSet {
            userDefaults.set(notificationsEnabled, forKey: notificationsKey)
            if notificationsEnabled {
                requestNotificationPermission()
            }
        }
    }

    private var alerted80PercentDateStr: String = ""
    private var alerted100PercentDateStr: String = ""

    public init() {
        let defaults = UserDefaults(suiteName: SharedDataManager.appGroupIdentifier) ?? .standard
        self.userDefaults = defaults
        let savedGoal = defaults.double(forKey: goalKey)
        self.dailyGoalHours = savedGoal > 0 ? savedGoal : 8.0
        self.notificationsEnabled = defaults.object(forKey: notificationsKey) as? Bool ?? true
    }

    public var dailyGoalSeconds: TimeInterval {
        dailyGoalHours * 3600.0
    }

    public func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func checkGoalThreshold(todayActiveSeconds: TimeInterval) {
        guard notificationsEnabled else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())

        let goal = dailyGoalSeconds
        guard goal > 0 else { return }

        let ratio = todayActiveSeconds / goal

        // 80% Notification
        if ratio >= 0.8 && ratio < 1.0 && alerted80PercentDateStr != todayStr {
            alerted80PercentDateStr = todayStr
            sendNotification(
                title: "Use Me - 80% Target Tercapai",
                body: "Anda telah menggunakan MacBook selama \(UsageFormatter.format(seconds: todayActiveSeconds)). Target harian: \(Int(dailyGoalHours)) jam."
            )
        }

        // 100% Notification
        if ratio >= 1.0 && alerted100PercentDateStr != todayStr {
            alerted100PercentDateStr = todayStr
            sendNotification(
                title: "Use Me - Target Harian Terlampaui",
                body: "Penggunaan MacBook Anda hari ini telah mencapai target \(Int(dailyGoalHours)) jam (\(UsageFormatter.format(seconds: todayActiveSeconds))). Luangkan waktu sejenak untuk istirahat!"
            )
        }
    }

    public func sendTestNotification() {
        requestNotificationPermission()
        sendNotification(
            title: "Use Me - Pengingat Istirahat",
            body: "Ini adalah notifikasi uji coba dari Use Me. Target harian Anda saat ini adalah \(Int(dailyGoalHours)) jam."
        )
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
