import SwiftUI
import AppKit

@main
struct UseMeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppStateManager()
    @StateObject private var tracker = ActivityTracker.shared
    @StateObject private var focusManager = FocusSessionManager.shared

    init() {
        SharedDataManager.shared.seedInitialDataIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(tracker)
                .environmentObject(focusManager)
                .background(WindowAccessor { window in
                    AppDelegate.shared.registerMainWindow(window)
                })
                .frame(minWidth: 720, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Sembunyikan ke Menu Bar") {
                    AppDelegate.shared.closeDashboardWindow()
                }
                .keyboardShortcut("q", modifiers: .command)

                Button("Tutup Jendela") {
                    AppDelegate.shared.closeDashboardWindow()
                }
                .keyboardShortcut("w", modifiers: .command)

                Divider()

                Button("Keluar dari Use Me Sepenuhnya") {
                    ActivityTracker.shared.flushBuffer()
                    NSApplication.shared.terminate(nil)
                }
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(tracker)
                .environmentObject(focusManager)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: menuBarIcon)
                Text(UsageFormatter.format(seconds: tracker.todayActiveSeconds))
                    .font(.system(.body, design: .rounded).monospacedDigit())

                if focusManager.isActive {
                    Text("•")
                        .foregroundColor(.secondary)
                    Image(systemName: focusManager.isWorkPhase ? "target" : "cup.and.saucer.fill")
                    Text(focusManager.formattedRemaining)
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .foregroundColor(focusManager.isWorkPhase ? .accentColor : .orange)
                }
            }
        }
    }

    private var menuBarIcon: String {
        if !tracker.isRunning {
            return "pause.circle"
        } else if tracker.isIdle {
            return "moon.zzz"
        } else {
            return "laptopcomputer"
        }
    }
}

// MARK: - App Delegate & Window Management
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, ObservableObject {
    static let shared = AppDelegate()
    private weak var mainWindow: NSWindow?

    @Published var isMenuBarOnly: Bool = UserDefaults(suiteName: SharedDataManager.appGroupIdentifier)?.bool(forKey: "useme_menu_bar_only") ?? false {
        didSet {
            UserDefaults(suiteName: SharedDataManager.appGroupIdentifier)?.set(isMenuBarOnly, forKey: "useme_menu_bar_only")
            updateActivationPolicy()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateActivationPolicy()
    }

    func updateActivationPolicy() {
        DispatchQueue.main.async {
            if self.isMenuBarOnly {
                NSApp.setActivationPolicy(.accessory)
            } else {
                NSApp.setActivationPolicy(.regular)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Crucial: Keep the app and Menu Bar Extra running in background
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openDashboardWindow()
        }
        return true
    }

    // Intercept window close (red 'X' button or Cmd+W)
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        self.mainWindow = sender
        // Hide window instead of terminating app
        sender.orderOut(nil)
        return false
    }

    func registerMainWindow(_ window: NSWindow) {
        self.mainWindow = window
        window.delegate = self
    }

    func closeDashboardWindow() {
        if let window = mainWindow {
            window.orderOut(nil)
        } else if let first = NSApp.windows.first(where: { $0.canBecomeMain }) {
            first.orderOut(nil)
        }
    }

    func openDashboardWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
        } else if let first = NSApp.windows.first(where: { $0.canBecomeMain }) {
            first.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - Window Accessor
struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                callback(window)
            }
        }
    }
}

// MARK: - App State Manager
final class AppStateManager: ObservableObject {
    @Published var selectedTimeframe: UsageTimeframe = .daily
    @Published var selectedHistoricalDate: Date = Date()
    @Published var currentSummary: UsageSummary

    init() {
        self.currentSummary = SharedDataManager.shared.loadSummary(for: .daily)
    }

    func selectTimeframe(_ timeframe: UsageTimeframe) {
        self.selectedTimeframe = timeframe
        refresh()
    }

    func selectDate(_ date: Date) {
        self.selectedHistoricalDate = date
        refresh()
    }

    func refresh() {
        ActivityTracker.shared.flushBuffer()
        let records = SharedDataManager.shared.loadDailyRecords()
        let isToday = Calendar.current.isDateInToday(selectedHistoricalDate)

        if selectedTimeframe == .daily && !isToday {
            self.currentSummary = UsageSummary.buildSummary(from: records, for: .daily, referenceDate: selectedHistoricalDate)
        } else {
            self.currentSummary = SharedDataManager.shared.loadSummary(for: selectedTimeframe)
        }
    }
}

// MARK: - Menu Bar View
struct MenuBarView: View {
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var tracker: ActivityTracker
    @EnvironmentObject var focusManager: FocusSessionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Use Me")
                    .font(.headline)
                Spacer()
                Text(tracker.statusBadgeText)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(tracker.statusBadgeColor).opacity(0.2))
                    .foregroundColor(Color(tracker.statusBadgeColor))
                    .cornerRadius(4)
            }

            Divider()

            HStack {
                Text("Hari Ini:")
                Spacer()
                Text(UsageFormatter.format(seconds: tracker.todayActiveSeconds))
                    .bold()
                    .monospacedDigit()
            }

            HStack {
                Text("Aplikasi:")
                Spacer()
                Text(tracker.currentAppName)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Divider()

            // Mode Fokus (Pomodoro) Section
            HStack {
                Label(focusManager.statusText, systemImage: focusManager.isWorkPhase ? "target" : "cup.and.saucer.fill")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text(focusManager.formattedRemaining)
                    .font(.caption)
                    .monospacedDigit()
                    .bold()
            }

            HStack {
                Button(focusManager.isActive ? "Jeda Fokus" : "Mulai Fokus (25m)") {
                    focusManager.toggleStartPause()
                }
                if focusManager.isActive || focusManager.remainingSeconds < FocusSessionManager.workDuration {
                    Button("Reset") {
                        focusManager.reset()
                    }
                }
            }

            Divider()

            Button(tracker.isRunning ? "Jeda Pelacakan" : "Lanjutkan Pelacakan") {
                tracker.toggleTracking()
            }

            Button("Segarkan Data") {
                appState.refresh()
            }

            Divider()

            Button(AppDelegate.shared.isMenuBarOnly ? "✓ Mode: Hanya Menu Bar (Aktif)" : "Mode: Sembunyikan dari Dock") {
                AppDelegate.shared.isMenuBarOnly.toggle()
            }

            Button("Buka Dashboard") {
                AppDelegate.shared.openDashboardWindow()
            }

            Button("Keluar Sepenuhnya") {
                ActivityTracker.shared.flushBuffer()
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
    }
}
