import Foundation
import Combine

public final class AppIgnoreManager: ObservableObject {
    public static let shared = AppIgnoreManager()

    private let key = "useme_ignored_bundle_ids"
    private let userDefaults: UserDefaults

    @Published public var ignoredBundleIds: Set<String>

    public init() {
        let defaults = UserDefaults(suiteName: SharedDataManager.appGroupIdentifier) ?? .standard
        self.userDefaults = defaults
        if let array = defaults.stringArray(forKey: key) {
            self.ignoredBundleIds = Set(array)
        } else {
            // Default ignored system applications
            self.ignoredBundleIds = [
                "com.apple.ScreenSaver.Engine",
                "com.apple.loginwindow",
                "com.apple.SecurityAgent"
            ]
        }
    }

    public func isIgnored(bundleId: String) -> Bool {
        return ignoredBundleIds.contains(bundleId)
    }

    public func ignore(bundleId: String) {
        ignoredBundleIds.insert(bundleId)
        save()
    }

    public func unignore(bundleId: String) {
        ignoredBundleIds.remove(bundleId)
        save()
    }

    public func toggle(bundleId: String) {
        if isIgnored(bundleId: bundleId) {
            unignore(bundleId: bundleId)
        } else {
            ignore(bundleId: bundleId)
        }
    }

    private func save() {
        userDefaults.set(Array(ignoredBundleIds), forKey: key)
        userDefaults.synchronize()
        SharedDataManager.shared.recalculateSummaries()
    }
}
