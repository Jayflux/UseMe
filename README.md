# Use Me — Laptop Usage & Screen Time Tracker for macOS 💻⏱️

A modern, native macOS screen time tracking and productivity app built with **SwiftUI**, **WidgetKit**, **AppIntents**, and **Swift Charts**.

![macOS 14+](https://img.shields.io/badge/macOS-14.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![Xcode](https://img.shields.io/badge/Xcode-15%2B-informational)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 🌟 Key Features

1. **Interactive Desktop Widgets (macOS 14+ / Sonoma & Sequoia)**
   - Small, Medium, and Large widgets with native dark/light styling.
   - **In-Widget One-Click Switcher**: Change timeframe between Daily, Weekly, and Monthly directly on the desktop surface using `AppIntents` and `Button(intent:)`.
   - Dynamic progress ring colored by daily goal completion.

2. **Core Activity Engine**
   - 1-second interval tracking with automatic idle detection (`CGEventSource.secondsSinceLastEventType`).
   - Sleep / Wake and Screen Lock / Unlock system observers.
   - Per-app active duration tracking via `NSWorkspace.frontmostApplication`.

3. **Productivity Mode & Pomodoro Timer**
   - Deep work timer: 25 minutes focus + 5 minutes break.
   - Live countdown in Menu Bar (`💻 2j 15m • 🎯 24:50`).
   - Sound alerts (`NSSound` Glass, Ping, Basso, Hero) on phase completion.
   - Daily completed session counter.

4. **Per-App Usage Limits**
   - Set daily duration limits on specific apps (e.g. max 1 hour on browsers or games).
   - Real-time warnings and local notifications when limits are exceeded.

5. **Analytics & Productivity Score**
   - Automatic 0–100 productivity score based on 6 app categories (*Development*, *Productivity*, *Design*, *Utilities*, *Browsing*, *Entertainment*).
   - Historical trend comparison (e.g. `↑ 12% vs yesterday`).
   - Contextual productivity insights in Indonesian.

6. **Historical Date Browser & Data Export**
   - Calendar navigator to inspect any past day's hourly activity breakdown.
   - Export records to structured **CSV** (for Excel/Google Sheets) and **JSON** with native `NSSavePanel`.

7. **Production Convenience**
   - **Launch at Login**: Auto-starts at boot via Apple's modern `SMAppService.mainApp`.
   - **Menu Bar Only Mode**: Option to hide from macOS Dock and run purely as a status bar utility.
   - **App Ignore List**: Exclude background or utility apps from active time calculations.

---

## 🏗️ Architecture

- **`UseMe/`**: Native SwiftUI application with WindowGroup, MenuBarExtra, and background tracking services.
- **`UseMeWidget/`**: WidgetKit extension with `AppIntentConfiguration` and `StaticConfiguration`.
- **`Shared/`**: Shared data layer connecting the app and widget extensions via App Group `group.com.juan.UseMe`.

---

## 🚀 Building & Running

### Requirements
- macOS 14.0 or newer
- Xcode 15.0 or newer

### Command Line Build
```bash
# Build main application
xcodebuild -project UseMe.xcodeproj -scheme UseMe -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build

# Build widget extension
xcodebuild -project UseMe.xcodeproj -scheme UseMeWidgetExtension -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

---

## 📄 License
MIT License. Created by Juan.
