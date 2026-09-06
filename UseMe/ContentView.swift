import SwiftUI
import Charts

struct ContentView: View {
    @EnvironmentObject var appState: AppStateManager
    @EnvironmentObject var tracker: ActivityTracker
    @EnvironmentObject var focusManager: FocusSessionManager
    @StateObject private var goalManager = GoalManager.shared
    @StateObject private var launchAtLogin = LaunchAtLoginManager.shared
    @StateObject private var ignoreManager = AppIgnoreManager.shared
    @StateObject private var limitManager = AppLimitManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            headerView
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Live Tracker Banner
                    liveTrackerCard

                    // Focus Mode (Pomodoro) Card
                    focusModeCard

                    // Timeframe Picker & Historical Date Browser
                    timeframePickerSection

                    // Key Metric Cards
                    metricsOverview

                    // Productivity Insight & Trend Card
                    productivityInsightCard

                    // Activity Chart
                    chartSection

                    // Category Breakdown Section
                    categorySection

                    // Top Apps Breakdown
                    topAppsSection

                    // Per-App Usage Limits Section
                    appLimitsSection

                    // Goal & Notification Settings
                    goalSettingsSection

                    // App Preferences & Data Export
                    preferencesAndExportSection
                }
                .padding(24)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .center, spacing: 14) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text("Use Me")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Pelacak Penggunaan Laptop & Widget Manager")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                AppDelegate.shared.isMenuBarOnly.toggle()
            }) {
                Label(
                    AppDelegate.shared.isMenuBarOnly ? "Menu Bar Saja" : "Tampil di Dock",
                    systemImage: AppDelegate.shared.isMenuBarOnly ? "menubar.dock.rectangle" : "macwindow"
                )
            }
            .buttonStyle(.bordered)
            .help("Klik untuk beralih antara Mode Menu Bar Saja (sembunyi dari Dock) atau Mode Normal")

            Button(action: {
                appState.refresh()
            }) {
                Label("Segarkan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Live Tracker Card
    private var liveTrackerCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(tracker.statusBadgeColor))
                        .frame(width: 10, height: 10)
                    Text(tracker.statusBadgeText)
                        .font(.headline)
                        .foregroundColor(Color(tracker.statusBadgeColor))

                    Spacer()

                    Text("Waktu Aktif Hari Ini: \(UsageFormatter.format(seconds: tracker.todayActiveSeconds))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }

                HStack(spacing: 16) {
                    Label("Aplikasi: \(tracker.currentAppName)", systemImage: "macwindow")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label("Idle: \(Int(tracker.idleSeconds))d (Batas: \(Int(tracker.idleThresholdSeconds))d)", systemImage: "timer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Picker("Idle Timeout", selection: $tracker.idleThresholdSeconds) {
                    Text("1 Mnt").tag(60.0)
                    Text("3 Mnt").tag(180.0)
                    Text("5 Mnt").tag(300.0)
                }
                .frame(width: 110)

                Button(tracker.isRunning ? "Jeda" : "Lanjutkan") {
                    tracker.toggleTracking()
                }
                .buttonStyle(.borderedProminent)
                .tint(tracker.isRunning ? .orange : .green)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(tracker.statusBadgeColor).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Focus Mode (Pomodoro) Card
    private var focusModeCard: some View {
        HStack(spacing: 24) {
            // Circular Progress & Countdown
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: CGFloat(focusManager.progress))
                    .stroke(
                        focusManager.isWorkPhase ? Color.accentColor : Color.orange,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: focusManager.progress)

                VStack(spacing: 2) {
                    Image(systemName: focusManager.isWorkPhase ? "target" : "cup.and.saucer.fill")
                        .font(.title3)
                        .foregroundColor(focusManager.isWorkPhase ? .accentColor : .orange)

                    Text(focusManager.formattedRemaining)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text(focusManager.phaseLabel)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Mode Fokus (Pomodoro)")
                        .font(.headline)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(focusManager.dailySessionCount) Sesi Selesai")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }

                Text(focusManager.isWorkPhase
                     ? "Sesi kerja mendalam 25 menit. Singkirkan distraksi dan fokus pada tugas Anda."
                     : "Waktu istirahat 5 menit! Regangkan badan, minum air putih, dan istirahatkan mata sejenak.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                HStack(spacing: 10) {
                    Button(action: {
                        focusManager.toggleStartPause()
                    }) {
                        Label(
                            focusManager.isActive ? "Jeda" : (focusManager.progress > 0 ? "Lanjutkan" : "Mulai Fokus (25m)"),
                            systemImage: focusManager.isActive ? "pause.fill" : "play.fill"
                        )
                        .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(focusManager.isActive ? .orange : (focusManager.isWorkPhase ? .accentColor : .green))

                    Button(action: {
                        focusManager.skipPhase()
                    }) {
                        Label("Lewati", systemImage: "forward.fill")
                    }
                    .buttonStyle(.bordered)
                    .help("Lewati ke fase berikutnya")

                    Button(action: {
                        focusManager.reset()
                    }) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!focusManager.isActive && focusManager.remainingSeconds == FocusSessionManager.workDuration && focusManager.isWorkPhase)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(focusManager.isActive ? (focusManager.isWorkPhase ? Color.accentColor.opacity(0.4) : Color.orange.opacity(0.4)) : Color.clear, lineWidth: 1.5)
        )
    }

    // MARK: - Timeframe Picker & Date Navigator
    private var timeframePickerSection: some View {
        VStack(spacing: 10) {
            Picker("Periode", selection: Binding(
                get: { appState.selectedTimeframe },
                set: { appState.selectTimeframe($0) }
            )) {
                ForEach(UsageTimeframe.allCases) { timeframe in
                    Label(timeframe.displayName, systemImage: timeframe.systemImage)
                        .tag(timeframe)
                }
            }
            .pickerStyle(.segmented)

            // Historical Date Browser for Daily View
            if appState.selectedTimeframe == .daily {
                HStack(spacing: 12) {
                    Button(action: {
                        if let prev = Calendar.current.date(byAdding: .day, value: -1, to: appState.selectedHistoricalDate) {
                            appState.selectDate(prev)
                        }
                    }) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { appState.selectedHistoricalDate },
                            set: { appState.selectDate($0) }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)

                    Button(action: {
                        if let next = Calendar.current.date(byAdding: .day, value: 1, to: appState.selectedHistoricalDate), next <= Date() {
                            appState.selectDate(next)
                        }
                    }) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                    .disabled(Calendar.current.isDateInToday(appState.selectedHistoricalDate))

                    if !Calendar.current.isDateInToday(appState.selectedHistoricalDate) {
                        Button("Kembali ke Hari Ini") {
                            appState.selectDate(Date())
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }

                    Spacer()

                    Text(formattedSelectedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale(identifier: "id_ID")
        return formatter.string(from: appState.selectedHistoricalDate)
    }

    // MARK: - Metrics Overview
    private var metricsOverview: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Total Penggunaan",
                value: (appState.selectedTimeframe == .daily && Calendar.current.isDateInToday(appState.selectedHistoricalDate))
                    ? UsageFormatter.format(seconds: tracker.todayActiveSeconds)
                    : appState.currentSummary.formattedDuration,
                subtitle: appState.selectedTimeframe.subtitle,
                icon: "clock.fill",
                tint: .blue
            )

            StatCard(
                title: "Target Periode",
                value: appState.currentSummary.progressPercentageString,
                subtitle: "Target \(UsageFormatter.format(seconds: appState.currentSummary.goalSeconds))",
                icon: "target",
                tint: appState.currentSummary.progress >= 1.0 ? .red : (appState.currentSummary.progress >= 0.8 ? .orange : .green)
            )

            StatCard(
                title: "Status Widget",
                value: "Tersinkronisasi",
                subtitle: SharedDataManager.appGroupIdentifier,
                icon: "checkmark.seal.fill",
                tint: .purple
            )
        }
    }

    // MARK: - Productivity Insight Card
    private var productivityInsightCard: some View {
        HStack(spacing: 20) {
            // Left: Score Ring
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: CGFloat(appState.currentSummary.productivityScore) / 100.0)
                        .stroke(
                            appState.currentSummary.productivityScore >= 80 ? Color.green : (appState.currentSummary.productivityScore >= 60 ? Color.blue : Color.orange),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Text("\(appState.currentSummary.productivityScore)")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.heavy)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Skor Produktivitas")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(ProductivityInsightManager.shared.scoreLabel(for: appState.currentSummary.productivityScore))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(appState.currentSummary.productivityScore >= 80 ? .green : (appState.currentSummary.productivityScore >= 60 ? .blue : .orange))
                }
            }

            Divider()

            // Middle: Trend Badge
            VStack(alignment: .leading, spacing: 3) {
                Text("Tren Penggunaan")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: appState.currentSummary.trendPercentage >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundColor(appState.currentSummary.trendPercentage >= 0 ? .blue : .purple)
                    Text(appState.currentSummary.trendDescription)
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
            }
            .frame(minWidth: 140, alignment: .leading)

            Divider()

            // Right: Insight Text
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(.yellow)
                Text(appState.currentSummary.insightText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Aktivitas \(appState.selectedTimeframe.displayName)")
                    .font(.headline)
                Spacer()
                Text("Diperbarui \(appState.currentSummary.lastUpdated, style: .time)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !appState.currentSummary.intervals.isEmpty {
                Chart(appState.currentSummary.intervals) { item in
                    BarMark(
                        x: .value("Waktu", item.label),
                        y: .value("Jam", item.hours)
                    )
                    .foregroundStyle(LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .bottom,
                        endPoint: .top
                    ))
                    .cornerRadius(4)
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text("\(String(format: "%.1f", doubleValue))j")
                                    .font(.caption2)
                            }
                        }
                    }
                }
            } else {
                Text("Belum ada data aktivitas untuk periode ini.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(height: 100)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Category Section
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distribusi Kategori Aplikasi")
                .font(.headline)

            if !appState.currentSummary.categoryBreakdown.isEmpty {
                GeometryReader { geo in
                    HStack(spacing: 3) {
                        ForEach(appState.currentSummary.categoryBreakdown) { cat in
                            Rectangle()
                                .fill(cat.category.color)
                                .frame(width: max(geo.size.width * CGFloat(cat.percentage), 8))
                        }
                    }
                    .cornerRadius(6)
                }
                .frame(height: 12)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(appState.currentSummary.categoryBreakdown) { cat in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(cat.category.color)
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(cat.category.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("\(cat.formattedDuration) (\(cat.percentageString))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 4)
            } else {
                Text("Belum ada kategori yang tercatat.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Top Apps Section
    private var topAppsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Aplikasi Terbanyak Digunakan")
                    .font(.headline)
                Spacer()
                Text("Gunakan ikon di kanan untuk mengabaikan atau mengatur batas")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if appState.currentSummary.topApps.isEmpty {
                Text("Belum ada aplikasi yang tercatat.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(appState.currentSummary.topApps) { app in
                        let isIgnored = ignoreManager.isIgnored(bundleId: app.bundleIdentifier)
                        let hasLimit = limitManager.hasLimit(for: app.bundleIdentifier)
                        let progress = limitManager.usageProgress(for: app.bundleIdentifier, currentSeconds: app.durationInSeconds)
                        let isExceeded = hasLimit && progress >= 1.0

                        HStack(spacing: 12) {
                            Image(systemName: app.iconSystemName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundColor(isIgnored ? .gray : app.category.color)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(app.appName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .strikethrough(isIgnored)

                                    if isIgnored {
                                        Text("(Diabaikan)")
                                            .font(.caption2)
                                            .foregroundColor(.purple)
                                    } else if isExceeded {
                                        Text("(Batas Terlampaui)")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.red)
                                    }
                                }
                                Text(app.category.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(app.formattedDuration)
                                    .font(.body)
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)

                                if hasLimit {
                                    Text("Batas: \(String(format: "%.1fj", limitManager.limitHours(for: app.bundleIdentifier)))")
                                        .font(.caption2)
                                        .foregroundColor(isExceeded ? .red : .secondary)
                                }
                            }

                            Button(action: {
                                ignoreManager.toggle(bundleId: app.bundleIdentifier)
                                appState.refresh()
                            }) {
                                Image(systemName: isIgnored ? "eye.fill" : "eye.slash")
                                    .foregroundColor(isIgnored ? .purple : .secondary)
                            }
                            .buttonStyle(.plain)
                            .help(isIgnored ? "Batal abaikan aplikasi ini" : "Abaikan aplikasi ini dari perhitungan")
                        }
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - App Limits Section
    private var appLimitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Batas Penggunaan Aplikasi (App Limits)")
                        .font(.headline)
                    Text("Tentukan batas waktu harian untuk aplikasi agar screen time tetap terkendali.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            if appState.currentSummary.topApps.isEmpty {
                Text("Belum ada aplikasi yang tercatat untuk dibatasi.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(appState.currentSummary.topApps) { app in
                        let limitHours = limitManager.limitHours(for: app.bundleIdentifier)
                        let hasLimit = limitManager.hasLimit(for: app.bundleIdentifier)
                        let currentProgress = limitManager.usageProgress(for: app.bundleIdentifier, currentSeconds: app.durationInSeconds)
                        let isExceeded = hasLimit && currentProgress >= 1.0

                        HStack(spacing: 12) {
                            Image(systemName: app.iconSystemName)
                                .font(.title3)
                                .foregroundColor(app.category.color)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(app.appName)
                                        .font(.body)
                                        .fontWeight(.medium)

                                    if isExceeded {
                                        Text("⚠️ Melebihi Batas")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Color.red.opacity(0.18))
                                            .foregroundColor(.red)
                                            .cornerRadius(4)
                                    } else if hasLimit {
                                        Text("\(Int(currentProgress * 100))%")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(currentProgress >= 0.8 ? .orange : .secondary)
                                    }
                                }

                                if hasLimit {
                                    ProgressView(value: min(currentProgress, 1.0))
                                        .progressViewStyle(.linear)
                                        .tint(isExceeded ? .red : (currentProgress >= 0.8 ? .orange : .blue))
                                        .frame(width: 160)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(app.formattedDuration)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()

                                if hasLimit {
                                    Text("Batas: \(String(format: "%.1fj", limitHours))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            // Menu to set limit
                            Menu {
                                Button("Tanpa Batas") {
                                    limitManager.removeLimit(for: app.bundleIdentifier)
                                }
                                Divider()
                                Button("30 Menit") {
                                    limitManager.setLimit(for: app.bundleIdentifier, hours: 0.5)
                                }
                                Button("1 Jam") {
                                    limitManager.setLimit(for: app.bundleIdentifier, hours: 1.0)
                                }
                                Button("1.5 Jam") {
                                    limitManager.setLimit(for: app.bundleIdentifier, hours: 1.5)
                                }
                                Button("2 Jam") {
                                    limitManager.setLimit(for: app.bundleIdentifier, hours: 2.0)
                                }
                                Button("3 Jam") {
                                    limitManager.setLimit(for: app.bundleIdentifier, hours: 3.0)
                                }
                                Button("4 Jam") {
                                    limitManager.setLimit(for: app.bundleIdentifier, hours: 4.0)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: hasLimit ? "hourglass.badge.plus" : "hourglass")
                                    Text(hasLimit ? "\(String(format: "%.1f", limitHours))j" : "Atur Limit")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                            }
                            .menuStyle(.borderedButton)
                            .tint(hasLimit ? (isExceeded ? .red : .accentColor) : .secondary)
                        }

                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Goal Settings Section
    private var goalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Target Harian & Notifikasi Istirahat")
                .font(.headline)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Screen Time Harian: \(Int(goalManager.dailyGoalHours)) Jam")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Slider(value: $goalManager.dailyGoalHours, in: 2...14, step: 1)
                        .frame(width: 240)
                }

                Divider()

                Toggle("Aktifkan Notifikasi", isOn: $goalManager.notificationsEnabled)
                    .toggleStyle(.switch)

                Spacer()

                Button("Kirim Uji Coba Notifikasi") {
                    goalManager.sendTestNotification()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Preferences & Export Section
    private var preferencesAndExportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Preferensi Aplikasi & Ekspor Data")
                .font(.headline)

            HStack(spacing: 24) {
                // Launch at Login Toggle
                Toggle(isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mulai Otomatis saat Login")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Aplikasi otomatis berjalan di background saat MacBook boot.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Spacer()

                // Export Buttons
                HStack(spacing: 10) {
                    Button(action: {
                        ExportManager.shared.exportCSV()
                    }) {
                        Label("Ekspor CSV", systemImage: "tablecells")
                    }
                    .buttonStyle(.bordered)

                    Button(action: {
                        ExportManager.shared.exportJSON()
                    }) {
                        Label("Ekspor JSON", systemImage: "curlybraces")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()

            // Menu Bar Only Mode Setting
            HStack(spacing: 24) {
                Toggle(isOn: Binding(
                    get: { AppDelegate.shared.isMenuBarOnly },
                    set: { AppDelegate.shared.isMenuBarOnly = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mode Menu Bar Saja (Sembunyikan dari Dock)")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Aplikasi berjalan murni di bilah menu atas tanpa menampilkan ikon di Dock macOS.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Spacer()
            }

            Divider()

            // Sound Effects Setting
            HStack(spacing: 24) {
                Toggle(isOn: Binding(
                    get: { SoundManager.shared.isSoundEnabled },
                    set: { SoundManager.shared.isSoundEnabled = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Efek Suara Sistem macOS")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Bunyikan nada dering native saat sesi Pomodoro selesai atau limit tercapai.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Spacer()

                Button(action: {
                    SoundManager.shared.playTestSound()
                }) {
                    Label("Uji Suara", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Helper Views
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: icon)
                    .foregroundColor(tint)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}
