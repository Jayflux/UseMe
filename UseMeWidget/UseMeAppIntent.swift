import AppIntents
import WidgetKit

public struct SelectTimeframeIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "Pilih Periode Penggunaan"
    public static var description = IntentDescription("Pilih apakah widget menampilkan ringkasan Harian, Mingguan, atau Bulanan.")

    @Parameter(title: "Periode", default: .daily)
    public var timeframe: TimeframeAppEnum

    public init() {
        self.timeframe = .daily
    }

    public init(timeframe: TimeframeAppEnum) {
        self.timeframe = timeframe
    }
}
