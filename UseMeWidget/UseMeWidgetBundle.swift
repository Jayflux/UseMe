import WidgetKit
import SwiftUI

@main
struct UseMeWidgetBundle: WidgetBundle {
    var body: some Widget {
        UseMeInteractiveWidget()
        UseMeDailyWidget()
        UseMeWeeklyWidget()
        UseMeMonthlyWidget()
    }
}
