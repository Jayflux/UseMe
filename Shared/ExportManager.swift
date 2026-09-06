import Foundation
import AppKit
import UniformTypeIdentifiers

public final class ExportManager {
    public static let shared = ExportManager()

    public func generateCSV() -> String {
        let records = SharedDataManager.shared.loadDailyRecords()
        var csv = "Tanggal,Aplikasi,Bundle ID,Kategori,Durasi Detik,Durasi Format\n"

        for record in records.sorted(by: { $0.dateString < $1.dateString }) {
            for (bundleId, duration) in record.appUsage.sorted(by: { $0.value > $1.value }) {
                let name = record.appNames[bundleId] ?? bundleId
                let category = AppCategory.classify(bundleIdentifier: bundleId, appName: name).displayName
                let formatted = UsageFormatter.format(seconds: duration)

                // Escape commas and quotes for CSV
                let safeName = name.replacingOccurrences(of: "\"", with: "\"\"")
                let safeBundleId = bundleId.replacingOccurrences(of: "\"", with: "\"\"")

                csv += "\"\(record.dateString)\",\"\(safeName)\",\"\(safeBundleId)\",\"\(category)\",\(Int(duration)),\"\(formatted)\"\n"
            }
        }
        return csv
    }

    public func generateJSON() -> String? {
        let records = SharedDataManager.shared.loadDailyRecords()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(records) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    public func exportCSV() {
        let csvContent = generateCSV()
        let savePanel = NSSavePanel()
        savePanel.title = "Ekspor Riwayat Penggunaan (CSV)"
        savePanel.nameFieldStringValue = "UseMe_ScreenTime_\(currentDateString()).csv"
        if #available(macOS 11.0, *) {
            savePanel.allowedContentTypes = [UTType.commaSeparatedText]
        } else {
            savePanel.allowedFileTypes = ["csv"]
        }

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? csvContent.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    public func exportJSON() {
        guard let jsonContent = generateJSON() else { return }
        let savePanel = NSSavePanel()
        savePanel.title = "Ekspor Riwayat Penggunaan (JSON)"
        savePanel.nameFieldStringValue = "UseMe_ScreenTime_\(currentDateString()).json"
        if #available(macOS 11.0, *) {
            savePanel.allowedContentTypes = [UTType.json]
        } else {
            savePanel.allowedFileTypes = ["json"]
        }

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? jsonContent.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
