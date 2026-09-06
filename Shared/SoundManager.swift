import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Native macOS Sound Alert Manager
/// Plays system sound cues (Glass, Ping, Basso, Hero) when Pomodoro finishes or limits are exceeded.
public final class SoundManager {
    public static let shared = SoundManager()

    private let soundEnabledKey = "useme_sound_effects_enabled"
    private let defaults = UserDefaults(suiteName: SharedDataManager.appGroupIdentifier)

    public var isSoundEnabled: Bool {
        get {
            if defaults?.object(forKey: soundEnabledKey) == nil {
                return true
            }
            return defaults?.bool(forKey: soundEnabledKey) ?? true
        }
        set {
            defaults?.set(newValue, forKey: soundEnabledKey)
        }
    }

    private init() {}

    public func play(named soundName: String) {
        guard isSoundEnabled else { return }
        #if canImport(AppKit)
        DispatchQueue.main.async {
            NSSound(named: NSSound.Name(soundName))?.play()
        }
        #endif
    }

    public func playPomodoroComplete() {
        play(named: "Glass")
    }

    public func playBreakComplete() {
        play(named: "Ping")
    }

    public func playLimitExceeded() {
        play(named: "Basso")
    }

    public func playGoalReached() {
        play(named: "Hero")
    }

    public func playTestSound() {
        play(named: "Glass")
    }
}
