import Foundation
import ServiceManagement
import Combine

public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()

    @Published public var isEnabled: Bool = false

    public init() {
        checkStatus()
    }

    public func checkStatus() {
        if #available(macOS 13.0, *) {
            self.isEnabled = (SMAppService.mainApp.status == .enabled)
        }
    }

    public func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
                self.isEnabled = (SMAppService.mainApp.status == .enabled)
            } catch {
                print("LaunchAtLogin toggle failed: \(error)")
                // Revert state if registration failed (e.g. in ad-hoc dev builds)
                self.isEnabled = (SMAppService.mainApp.status == .enabled)
            }
        }
    }
}
