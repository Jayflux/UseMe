import WidgetKit
import SwiftUI
import Charts
import AppIntents

// MARK: - Timeline Entry
struct UsageEntry: TimelineEntry {
    let date: Date
    let summary: UsageSummary
}

// MARK: - Static Timeline Provider
struct UsageTimelineProvider: TimelineProvider {
    let timeframe: UsageTimeframe

    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), summary: UsageSummary.mock(for: timeframe))
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        let summary = SharedDataManager.shared.loadSummary(for: timeframe)
        let entry = UsageEntry(date: Date(), summary: summary)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let summary = SharedDataManager.shared.loadSummary(for: timeframe)
        let currentDate = Date()
        let entry = UsageEntry(date: currentDate, summary: summary)

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate.addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - AppIntent Configurable Timeline Provider
struct ConfigurableUsageTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = UsageEntry
    typealias Intent = SelectTimeframeIntent

    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), summary: UsageSummary.mock(for: .daily))
    }

    private func activeTimeframe(for configuration: SelectTimeframeIntent) -> UsageTimeframe {
        if let stored = UserDefaults(suiteName: SharedDataManager.appGroupIdentifier)?.string(forKey: "useme_widget_active_timeframe") {
            if stored == "daily" { return .daily }
            if stored == "weekly" { return .weekly }
            if stored == "monthly" { return .monthly }
        }
        return configuration.timeframe.toUsageTimeframe
    }

    func snapshot(for configuration: SelectTimeframeIntent, in context: Context) async -> UsageEntry {
        let timeframe = activeTimeframe(for: configuration)
        let summary = SharedDataManager.shared.loadSummary(for: timeframe)
        return UsageEntry(date: Date(), summary: summary)
    }

    func timeline(for configuration: SelectTimeframeIntent, in context: Context) async -> Timeline<UsageEntry> {
        let timeframe = activeTimeframe(for: configuration)
        let summary = SharedDataManager.shared.loadSummary(for: timeframe)
        let currentDate = Date()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate.addingTimeInterval(900)
        return Timeline(entries: [UsageEntry(date: currentDate, summary: summary)], policy: .after(nextUpdate))
    }
}

// MARK: - Widgets Definition

// 1. Interactive Configurable Widget (Allows user to edit timeframe or click buttons on surface)
struct UseMeInteractiveWidget: Widget {
    let kind: String = "UseMeInteractiveWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectTimeframeIntent.self,
            provider: ConfigurableUsageTimelineProvider()
        ) { entry in
            UsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Use Me - Fleksibel")
        .description("Widget dinamis dengan tombol satu-klik periode (Harian, Mingguan, Bulanan) langsung di widget.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// 2. Daily Widget
struct UseMeDailyWidget: Widget {
    let kind: String = "UseMeDailyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageTimelineProvider(timeframe: .daily)) { entry in
            UsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Penggunaan Harian")
        .description("Pantau durasi aktif MacBook Anda sepanjang hari ini.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// 3. Weekly Widget
struct UseMeWeeklyWidget: Widget {
    let kind: String = "UseMeWeeklyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageTimelineProvider(timeframe: .weekly)) { entry in
            UsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Penggunaan Mingguan")
        .description("Ringkasan dan tren durasi aktif 7 hari terakhir.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// 4. Monthly Widget
struct UseMeMonthlyWidget: Widget {
    let kind: String = "UseMeMonthlyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageTimelineProvider(timeframe: .monthly)) { entry in
            UsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Penggunaan Bulanan")
        .description("Total dan akumulasi mingguan dalam 30 hari terakhir.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Entry View
struct UsageWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: UsageEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(summary: entry.summary)
            case .systemMedium:
                MediumWidgetView(summary: entry.summary)
            case .systemLarge:
                LargeWidgetView(summary: entry.summary)
            default:
                SmallWidgetView(summary: entry.summary)
            }
        }
        .containerBackground(for: .widget) {
            Color(NSColor.windowBackgroundColor)
        }
    }
}

// MARK: - Small Widget View
struct SmallWidgetView: View {
    let summary: UsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(summary.timeframe.displayName, systemImage: summary.timeframe.systemImage)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "laptopcomputer")
                    .font(.caption2)
                    .foregroundColor(ringColor)
            }

            Spacer()

            ZStack(alignment: .center) {
                Circle()
                    .stroke(ringColor.opacity(0.18), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(summary.progress))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [ringColor.opacity(0.7), ringColor]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(summary.formattedDuration)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(summary.progressPercentageString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 72, height: 72)
            .frame(maxWidth: .infinity, alignment: .center)

            Spacer()

            Text("Target: \(UsageFormatter.format(seconds: summary.goalSeconds))")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(4)
    }

    private var ringColor: Color {
        if summary.progress >= 1.0 {
            return .red
        } else if summary.progress >= 0.8 {
            return .orange
        } else {
            return .blue
        }
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    let summary: UsageSummary

    var body: some View {
        HStack(spacing: 16) {
            // Left Column: Summary & Controls
            VStack(alignment: .leading, spacing: 5) {
                // In-Widget Interactive Switcher Bar
                HStack(spacing: 2) {
                    ForEach([("Hari", TimeframeAppEnum.daily), ("Mgg", TimeframeAppEnum.weekly), ("Bln", TimeframeAppEnum.monthly)], id: \.0) { item in
                        Button(intent: ChangeWidgetTimeframeIntent(timeframe: item.1)) {
                            Text(item.0)
                                .font(.system(size: 8, weight: summary.timeframe.rawValue == item.1.rawValue ? .bold : .regular))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(summary.timeframe.rawValue == item.1.rawValue ? Color.blue.opacity(0.25) : Color.secondary.opacity(0.1))
                                .foregroundColor(summary.timeframe.rawValue == item.1.rawValue ? .blue : .secondary)
                                .cornerRadius(3)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(summary.formattedDuration)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.heavy)

                ProgressView(value: summary.progress)
                    .progressViewStyle(.linear)
                    .tint(summary.progress >= 1.0 ? .red : (summary.progress >= 0.8 ? .orange : .blue))

                Text("Target: \(UsageFormatter.format(seconds: summary.goalSeconds)) (\(summary.progressPercentageString))")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                // Bottom row: Top category pill + Productivity Score
                HStack(spacing: 4) {
                    if let topCat = summary.categoryBreakdown.first {
                        Circle()
                            .fill(topCat.category.color)
                            .frame(width: 6, height: 6)
                        Text(topCat.category.displayName)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text("🎯 \(summary.productivityScore)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            .frame(maxWidth: 130, alignment: .leading)

            Divider()

            // Right Column: Mini Bar Chart
            VStack(alignment: .leading, spacing: 4) {
                Text("Aktivitas \(summary.timeframe.displayName)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                if !summary.intervals.isEmpty {
                    Chart(summary.intervals) { item in
                        BarMark(
                            x: .value("Waktu", item.label),
                            y: .value("Jam", item.hours)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .cornerRadius(2)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisValueLabel {
                                if let text = value.as(String.self) {
                                    Text(text)
                                        .font(.system(size: 8))
                                }
                            }
                        }
                    }
                    .chartYAxis(.hidden)
                } else {
                    Text("Belum ada data")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(6)
    }
}

// MARK: - Large Widget View
struct LargeWidgetView: View {
    let summary: UsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with Interactive Switcher
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Use Me")
                            .font(.headline)
                        Text("🎯 \(summary.productivityScore)")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }

                    HStack(spacing: 4) {
                        ForEach([("Harian", TimeframeAppEnum.daily), ("Mingguan", TimeframeAppEnum.weekly), ("Bulanan", TimeframeAppEnum.monthly)], id: \.0) { item in
                            Button(intent: ChangeWidgetTimeframeIntent(timeframe: item.1)) {
                                Text(item.0)
                                    .font(.system(size: 9, weight: summary.timeframe.rawValue == item.1.rawValue ? .bold : .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(summary.timeframe.rawValue == item.1.rawValue ? Color.blue : Color.secondary.opacity(0.15))
                                    .foregroundColor(summary.timeframe.rawValue == item.1.rawValue ? .white : .primary)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(summary.formattedDuration)
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Target \(summary.progressPercentageString)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Main Bar Chart
            if !summary.intervals.isEmpty {
                Chart(summary.intervals) { item in
                    BarMark(
                        x: .value("Waktu", item.label),
                        y: .value("Jam", item.hours)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(3)
                }
                .frame(height: 96)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let h = value.as(Double.self) {
                                Text("\(Int(h))j")
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }

            Divider()

            // Category Distribution Bar
            if !summary.categoryBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Distribusi Kategori")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(summary.categoryBreakdown) { cat in
                                Rectangle()
                                    .fill(cat.category.color)
                                    .frame(width: max(geo.size.width * CGFloat(cat.percentage), 4))
                            }
                        }
                        .cornerRadius(3)
                    }
                    .frame(height: 6)

                    HStack(spacing: 8) {
                        ForEach(summary.categoryBreakdown.prefix(3)) { cat in
                            HStack(spacing: 3) {
                                Circle().fill(cat.category.color).frame(width: 5, height: 5)
                                Text("\(cat.category.displayName) (\(cat.percentageString))")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            // Top Apps List
            VStack(spacing: 4) {
                ForEach(summary.topApps.prefix(3)) { app in
                    HStack {
                        Image(systemName: app.iconSystemName)
                            .font(.caption)
                            .foregroundColor(app.category.color)
                            .frame(width: 14)
                        Text(app.appName)
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        Text(app.formattedDuration)
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(8)
    }
}
