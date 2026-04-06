# Environment

Environment variables, external dependencies, and setup notes.

**What belongs here:** Required env vars, external API keys/services, dependency quirks, platform-specific notes.
**What does NOT belong here:** Service ports/commands (use `.factory/services.yaml`).

---

## Platform
- iOS 17.0+ deployment target
- Swift 6.2, SwiftUI
- Xcode 26.4 at /Applications/Xcode.app

## Bundle Identifiers
- Main app: `com.colbychang.focus`
- DeviceActivityMonitor: `com.colbychang.focus.DeviceActivityMonitor`
- ShieldConfiguration: `com.colbychang.focus.ShieldConfiguration`
- ShieldAction: `com.colbychang.focus.ShieldAction`
- DeviceActivityReport: `com.colbychang.focus.DeviceActivityReport`
- Widget Extension: `com.colbychang.focus.FocusWidgets`

## App Group
- ID: `group.com.colbychang.focus.shared`
- Must be added to main app + all extension targets

## Entitlements
- Family Controls (Development) — NOT YET AVAILABLE. All Screen Time API calls go through protocol abstractions with mock implementations.
- App Groups — Required for cross-extension UserDefaults

## Dependencies
- No third-party package dependencies for production code
- Swift Package Manager only (no CocoaPods/Carthage)

## Known Limitations
- Simulator cannot test: ManagedSettingsStore blocking, DeviceActivityMonitor callbacks, Shield extension UI
- xcode-select must point to Xcode.app (not CommandLineTools)
- iOS simulator runtime must be downloaded separately

## Simulator Selection for UI Tests

The **primary iPhone 17 Pro simulator** (device ID `03BD412B-FD96-4E2F-A1C0-9A1C680D3A18`) consistently fails UI tests with `"Timed out waiting for AX loaded notification"`. Use the **iPhone 17 Pro Fresh** simulator (device ID `8FC9FB2D-...`) instead for reliable UI test execution.

If UI tests fail with AX notification timeouts, try a different simulator variant before debugging the test logic.

**Discovered in:** `analytics-dashboard-history` worker (all 8 UI tests initially failed with AX timeout on primary simulator; switching to Fresh resolved them).
