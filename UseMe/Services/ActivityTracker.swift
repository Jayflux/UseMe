import Foundation
import AppKit
import CoreGraphics
import Combine

public final class ActivityTracker: ObservableObject {
    public static let shared = ActivityTracker()

    // MARK: - Published State
    @Published public var isRunning: Bool = true
    @Published public var isIdle: Bool = false
    @Published public var isSleeping: Bool = false
    @Published public var isLocked: Bool = false
    @Published public var currentAppName: String = "Finder"
    @Published public var currentAppBundleId: String = "com.apple.finder"
    @Published public var idleSeconds: Double = 0.0
    @Published public var idleThresholdSeconds: Double = 180.0 // Default 3 minutes
    @Published public var todayActiveSeconds: TimeInterval = 0.0

    // MARK: - Internal Storage
    private var timer: AnyCancellable?
    private var bufferedSeconds: TimeInterval = 0.0
    private var lastRecordedAppBundleId: String = ""
    private var lastRecordedAppName: String = ""
    private var flushCounter: Int = 0

    public init() {
        setupSystemObservers()
        refreshTodaySeconds()
        startTracking()
    }

    deinit {
        flushBuffer()
        timer?.cancel()
    }

    // MARK: - System Notifications
    private func setupSystemObservers() {
        let wsCenter = NSWorkspace.shared.notificationCenter
        let distCenter = DistributedNotificationCenter.default()

        // Sleep / Wake
        wsCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        wsCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // Session Active / Resign
        wsCenter.addObserver(
            self,
            selector: #selector(handleSessionResign),
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil
        )
        wsCenter.addObserver(
            self,
            selector: #selector(handleSessionBecomeActive),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )

        // Screen Lock / Unlock
        distCenter.addObserver(
            self,
            selector: #selector(handleScreenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        distCenter.addObserver(
            self,
            selector: #selector(handleScreenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )

        // App Termination
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    // MARK: - Handlers
    @objc private func handleSleep() {
        DispatchQueue.main.async {
            self.flushBuffer()
            self.isSleeping = true
        }
    }

    @objc private func handleWake() {
        DispatchQueue.main.async {
            self.isSleeping = false
        }
    }

    @objc private func handleSessionResign() {
        DispatchQueue.main.async {
            self.flushBuffer()
            self.isLocked = true
        }
    }

    @objc private func handleSessionBecomeActive() {
        DispatchQueue.main.async {
            self.isLocked = false
        }
    }

    @objc private func handleScreenLocked() {
        DispatchQueue.main.async {
            self.flushBuffer()
            self.isLocked = true
        }
    }

    @objc private func handleScreenUnlocked() {
        DispatchQueue.main.async {
            self.isLocked = false
        }
    }

    @objc private func handleAppWillTerminate() {
        flushBuffer()
    }

    // MARK: - Tracking Loop
    public func startTracking() {
        isRunning = true
        timer?.cancel()
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    public func pauseTracking() {
        flushBuffer()
        isRunning = false
    }

    public func resumeTracking() {
        isRunning = true
    }

    public func toggleTracking() {
        if isRunning {
            pauseTracking()
        } else {
            resumeTracking()
        }
    }

    private func tick() {
        guard isRunning, !isSleeping, !isLocked else { return }

        // Check Idle Time
        let idleSec = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: CGEventType(rawValue: ~0)!
        )
        self.idleSeconds = idleSec

        let wasIdle = self.isIdle
        let nowIdle = idleSec >= idleThresholdSeconds
        self.isIdle = nowIdle

        // Detect frontmost app
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            self.currentAppName = frontApp.localizedName ?? "Unknown"
            self.currentAppBundleId = frontApp.bundleIdentifier ?? "unknown"
        }

        // If user transitions from active to idle, flush immediately
        if !wasIdle && nowIdle {
            flushBuffer()
            return
        }

        // If user is idle, do not accumulate active seconds
        guard !nowIdle else { return }

        // If current frontmost app is in ignore list, skip accumulation
        if AppIgnoreManager.shared.isIgnored(bundleId: currentAppBundleId) {
            return
        }

        // Increment active time
        bufferedSeconds += 1.0
        todayActiveSeconds += 1.0
        lastRecordedAppBundleId = currentAppBundleId
        lastRecordedAppName = currentAppName
        flushCounter += 1

        // Flush buffer every 5 seconds to reduce write frequency
        if flushCounter >= 5 {
            flushBuffer()
            flushCounter = 0
        }
    }

    public func flushBuffer() {
        guard bufferedSeconds > 0 else { return }
        let sec = bufferedSeconds
        let bId = lastRecordedAppBundleId.isEmpty ? currentAppBundleId : lastRecordedAppBundleId
        let name = lastRecordedAppName.isEmpty ? currentAppName : lastRecordedAppName

        bufferedSeconds = 0.0
        SharedDataManager.shared.recordActiveTime(seconds: sec, appBundleId: bId, appName: name)
        refreshTodaySeconds()
        GoalManager.shared.checkGoalThreshold(todayActiveSeconds: todayActiveSeconds)

        // Check per-app daily limits
        let records = SharedDataManager.shared.loadDailyRecords()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        if let todayRecord = records.first(where: { $0.dateString == todayStr }) {
            AppLimitManager.shared.checkLimits(appUsage: todayRecord.appUsage, appNames: todayRecord.appNames)
        }
    }

    public func refreshTodaySeconds() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        let records = SharedDataManager.shared.loadDailyRecords()
        let todayRecord = records.first(where: { $0.dateString == todayStr })
        self.todayActiveSeconds = (todayRecord?.totalActiveSeconds ?? 0) + bufferedSeconds
    }

    public var statusBadgeText: String {
        if !isRunning {
            return "Dijeda"
        } else if isSleeping {
            return "Tidur (Sleep)"
        } else if isLocked {
            return "Terkunci"
        } else if AppIgnoreManager.shared.isIgnored(bundleId: currentAppBundleId) {
            return "Aplikasi Diabaikan"
        } else if isIdle {
            return "Idle (\(Int(idleSeconds))d)"
        } else {
            return "Aktif Melacak"
        }
    }

    public var statusBadgeColor: NSColor {
        if !isRunning {
            return .systemGray
        } else if isSleeping || isLocked {
            return .systemOrange
        } else if AppIgnoreManager.shared.isIgnored(bundleId: currentAppBundleId) {
            return .systemPurple
        } else if isIdle {
            return .systemYellow
        } else {
            return .systemGreen
        }
    }
}
