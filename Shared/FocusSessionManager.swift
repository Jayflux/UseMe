import Foundation
import UserNotifications
import Combine

/// Focus Mode (Pomodoro) Engine
/// Work: 25 minutes, Break: 5 minutes
/// Tracks daily completed sessions and sends notifications
final class FocusSessionManager: ObservableObject {
    static let shared = FocusSessionManager()

    // MARK: - Constants
    static let workDuration: TimeInterval = 25 * 60   // 25 minutes
    static let breakDuration: TimeInterval = 5 * 60    // 5 minutes

    // MARK: - Published State
    @Published var isActive: Bool = false
    @Published var isWorkPhase: Bool = true
    @Published var remainingSeconds: TimeInterval = FocusSessionManager.workDuration
    @Published var dailySessionCount: Int = 0

    // MARK: - Internal
    private var timer: Timer?
    private let defaults = UserDefaults(suiteName: SharedDataManager.appGroupIdentifier)

    var totalDuration: TimeInterval {
        isWorkPhase ? Self.workDuration : Self.breakDuration
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1.0 - (remainingSeconds / totalDuration)
    }

    var formattedRemaining: String {
        let mins = Int(remainingSeconds) / 60
        let secs = Int(remainingSeconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var phaseLabel: String {
        isWorkPhase ? "Fokus" : "Istirahat"
    }

    var statusText: String {
        if !isActive {
            return "Siap Mulai"
        }
        return isWorkPhase ? "🎯 Sesi Fokus" : "☕ Istirahat"
    }

    // MARK: - Init
    private init() {
        loadDailyCount()
    }

    // MARK: - Controls
    func start() {
        guard !isActive else { return }
        isActive = true
        startTimer()
    }

    func pause() {
        isActive = false
        timer?.invalidate()
        timer = nil
    }

    func toggleStartPause() {
        if isActive {
            pause()
        } else {
            start()
        }
    }

    func reset() {
        pause()
        isWorkPhase = true
        remainingSeconds = Self.workDuration
    }

    func skipPhase() {
        timer?.invalidate()
        timer = nil
        transitionToNextPhase()
    }

    // MARK: - Timer
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // Allow timer to fire during UI tracking
        RunLoop.current.add(timer!, forMode: .common)
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            transitionToNextPhase()
            return
        }
        remainingSeconds -= 1

        if remainingSeconds <= 0 {
            transitionToNextPhase()
        }
    }

    private func transitionToNextPhase() {
        timer?.invalidate()
        timer = nil

        if isWorkPhase {
            // Work session completed → increment counter
            dailySessionCount += 1
            saveDailyCount()
            SoundManager.shared.playPomodoroComplete()
            sendNotification(
                title: "Sesi Fokus Selesai! 🎉",
                body: "Kerja bagus! Saatnya istirahat 5 menit. Sesi hari ini: \(dailySessionCount)"
            )
            // Switch to break
            isWorkPhase = false
            remainingSeconds = Self.breakDuration
        } else {
            // Break done → back to work
            SoundManager.shared.playBreakComplete()
            sendNotification(
                title: "Istirahat Selesai ☕",
                body: "Waktunya kembali fokus! Mulai sesi baru."
            )
            isWorkPhase = true
            remainingSeconds = Self.workDuration
        }

        // Auto-continue
        if isActive {
            startTimer()
        }
    }

    // MARK: - Notifications
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "FocusSession_\(UUID().uuidString)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[FocusSessionManager] Notification error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Daily Count Persistence
    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "useme_focus_sessions_\(formatter.string(from: Date()))"
    }

    private func loadDailyCount() {
        dailySessionCount = defaults?.integer(forKey: todayKey) ?? 0
    }

    private func saveDailyCount() {
        defaults?.set(dailySessionCount, forKey: todayKey)
    }
}
