# Apple Screen Time API Technical Reference (iOS 16–17+, 2025–2026)

## Table of Contents
1. [Overview & Architecture](#overview--architecture)
2. [The Three Frameworks](#the-three-frameworks)
3. [Authorization Flow (FamilyControls)](#authorization-flow-familycontrols)
4. [App Blocking with ManagedSettingsStore](#app-blocking-with-managedsettingsstore)
5. [Device Activity Monitoring](#device-activity-monitoring-deviceactivitymonitor)
6. [Shield Configuration Extension](#shield-configuration-extension-shieldconfigurationdatasource)
7. [Shield Action Extension](#shield-action-extension-shieldactiondelegate)
8. [App & Token Identification System](#app--token-identification-system)
9. [Required Entitlements & Info.plist](#required-entitlements--infoplist)
10. [Xcode Project Structure](#xcode-project-structure-extension-targets)
11. [Data Sharing Between Extensions](#data-sharing-between-extensions)
12. [iOS 16+ Changes (Individual Authorization)](#ios-16-changes-individual-authorization)
13. [Known Limitations & Gotchas](#known-limitations--gotchas)
14. [Code Patterns & Best Practices](#code-patterns--best-practices)
15. [Entitlement Approval Process](#entitlement-approval-process)
16. [Key References](#key-references)

---

## Overview & Architecture

Apple's "Screen Time API" is not a single framework but a suite of three separate frameworks that work together to enable parental controls and self-control / digital wellness features:

- **FamilyControls** – Authorization gatekeeper
- **ManagedSettings** – Enforces restrictions (app blocking/shielding)
- **DeviceActivity** – Schedules and monitors usage events

The API was introduced in **iOS 15** (WWDC 2021) for parental controls only (child devices in Family Sharing). In **iOS 16**, Apple added `.individual` authorization, allowing users to control their *own* device — enabling self-control / digital wellness apps. **iOS 17** continued refinements.

The blocking is enforced **at the OS level**. When a shield is applied via `ManagedSettingsStore`, users cannot bypass it by:
- Force-quitting the blocking app
- Restarting the device
- Switching user accounts

The only way to remove a shield is through your app's code.

---

## The Three Frameworks

### FamilyControls
- **Purpose**: Authorization to access Screen Time APIs
- **Key Classes**: `AuthorizationCenter`, `FamilyActivityPicker`, `FamilyActivitySelection`
- **Import**: `import FamilyControls`

### ManagedSettings
- **Purpose**: Apply and manage device restrictions/shields
- **Key Classes**: `ManagedSettingsStore`, `ShieldSettings`, `ShieldActionDelegate`, `ShieldConfigurationDataSource`
- **Import**: `import ManagedSettings`

### DeviceActivity
- **Purpose**: Schedule and monitor device activity events
- **Key Classes**: `DeviceActivityCenter`, `DeviceActivityMonitor`, `DeviceActivitySchedule`, `DeviceActivityEvent`
- **Import**: `import DeviceActivity`

### ManagedSettingsUI
- **Purpose**: Customize shield appearance
- **Key Classes**: `ShieldConfigurationDataSource`
- **Import**: `import ManagedSettingsUI`

---

## Authorization Flow (FamilyControls)

### Step 1: Request Authorization

```swift
import FamilyControls

// For individual (self-control) apps — iOS 16+
let center = AuthorizationCenter.shared
do {
    try await center.requestAuthorization(for: .individual)
} catch {
    print("Failed to get authorization: \(error)")
}

// For parental control apps (child in Family Sharing) — iOS 15+
// try await center.requestAuthorization(for: .child)
```

### Authorization Types
- **`.individual`** (iOS 16+): User authorizes control over their own device. Shows a system prompt asking the user to allow Screen Time access. Used for self-control / digital wellness apps.
- **`.child`** (iOS 15+): Parent authorizes restrictions on a child's device within Family Sharing. Requires the device to be in a Family Sharing group.

### Checking Authorization Status

```swift
let status = AuthorizationCenter.shared.authorizationStatus
// .notDetermined, .denied, .approved
```

### Step 2: Present FamilyActivityPicker

After authorization, present a system picker so users can select which apps/categories/websites to restrict:

```swift
import SwiftUI
import FamilyControls

struct AppSelectionView: View {
    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false

    var body: some View {
        Button("Select Apps") { showPicker = true }
            .familyActivityPicker(
                isPresented: $showPicker,
                selection: $selection
            )
    }
}
```

**`FamilyActivitySelection`** contains:
- `applicationTokens: Set<ApplicationToken>` — opaque tokens for selected apps
- `categoryTokens: Set<ActivityCategoryToken>` — opaque tokens for categories
- `webDomainTokens: Set<WebDomainToken>` — opaque tokens for web domains

The `FamilyActivityPicker` is also available as a standalone SwiftUI view:
```swift
FamilyActivityPicker(selection: $selection)
```

---

## App Blocking with ManagedSettingsStore

### Basic Blocking

```swift
import ManagedSettings
import FamilyControls

class ShieldManager: ObservableObject {
    @Published var selection = FamilyActivitySelection()
    private let store = ManagedSettingsStore()

    func shieldActivities() {
        // Clear previous settings
        store.clearAllSettings()

        let apps = selection.applicationTokens
        let categories = selection.categoryTokens

        // Block individual apps
        store.shield.applications = apps.isEmpty ? nil : apps

        // Block app categories
        store.shield.applicationCategories = categories.isEmpty
            ? nil
            : .specific(categories)

        // Block web domain categories (IMPORTANT: don't forget this!)
        store.shield.webDomainCategories = categories.isEmpty
            ? nil
            : .specific(categories)

        // Block specific web domains
        store.shield.webDomains = selection.webDomainTokens.isEmpty
            ? nil
            : selection.webDomainTokens
    }

    func unshieldActivities() {
        store.clearAllSettings()
    }
}
```

### Named Stores
You can create multiple named stores for different blocking contexts:

```swift
let focusStore = ManagedSettingsStore(named: .init("focus"))
let bedtimeStore = ManagedSettingsStore(named: .init("bedtime"))

// Each store independently manages its own shields
focusStore.shield.applications = someApps
bedtimeStore.shield.applications = otherApps

// Clearing one doesn't affect the other
focusStore.clearAllSettings()
// bedtimeStore shields remain active
```

### Blocking All Apps (with exceptions)

```swift
// Block ALL apps except specific ones
store.shield.applicationCategories = .all(except: allowedCategoryTokens)

// Block ALL web domains except specific ones
store.shield.webDomainCategories = .all(except: allowedCategoryTokens)
```

### Important: Block All Three Dimensions
When applying shields, you MUST set all three properties to prevent bypasses:
1. `store.shield.applications` — blocks individual apps
2. `store.shield.applicationCategories` — blocks app categories
3. `store.shield.webDomains` — blocks web domains

If you forget web domains, users can access blocked apps through Safari.

---

## Device Activity Monitoring (DeviceActivityMonitor)

### Creating a DeviceActivityMonitor Extension

The `DeviceActivityMonitor` runs as a **separate app extension process**. It does NOT run in your main app.

```swift
import DeviceActivity
import ManagedSettings

class MyDeviceActivityMonitor: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // Called when a scheduled monitoring interval starts
        // Example: Apply shields when bedtime starts
        let store = ManagedSettingsStore()
        // Apply blocking...
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Called when a scheduled monitoring interval ends
        // Example: Remove shields when bedtime ends
        let store = ManagedSettingsStore()
        store.clearAllSettings()
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        // Called when a usage threshold is reached
        // Example: User used Instagram for 30 minutes
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        // Called before an interval starts (warning period)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        // Called before an interval ends (warning period)
    }
}
```

### Starting Monitoring from the Main App

```swift
import DeviceActivity

let center = DeviceActivityCenter()

// Define a schedule
let schedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 22, minute: 0),  // 10 PM
    intervalEnd: DateComponents(hour: 7, minute: 0),      // 7 AM
    repeats: true,
    warningTime: DateComponents(minute: 15)               // 15 min warning
)

// Define events (usage thresholds)
let event = DeviceActivityEvent(
    applications: selectedAppTokens,
    categories: selectedCategoryTokens,
    webDomains: selectedWebDomainTokens,
    threshold: DateComponents(minute: 30)  // 30 minutes of usage
)

// Start monitoring
do {
    try center.startMonitoring(
        .init("bedtime"),
        during: schedule,
        events: [.init("usageLimit"): event]
    )
} catch {
    print("Failed to start monitoring: \(error)")
}

// Stop monitoring
center.stopMonitoring([.init("bedtime")])
```

---

## Shield Configuration Extension (ShieldConfigurationDataSource)

This extension customizes the shield UI shown when a user tries to open a blocked app.

### Extension Target Setup
- **Extension Point Identifier**: `com.apple.ManagedSettingsUI.shield-configuration`
- **Principal Class**: `$(PRODUCT_MODULE_NAME).ShieldConfigurationExtension`

```swift
import ManagedSettingsUI
import ManagedSettings

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // Customize shield for a specific app
    override func configuration(
        shielding application: Application
    ) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            backgroundColor: .white,
            icon: UIImage(named: "AppIcon"),
            title: ShieldConfiguration.Label(
                text: "App Blocked",
                color: .black
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Complete your tasks first!",
                color: .gray
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Unlock",
                color: .white
            ),
            primaryButtonBackgroundColor: .blue,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Close",
                color: .gray
            )
        )
    }

    // Customize shield for a web domain
    override func configuration(
        shielding webDomain: WebDomain
    ) -> ShieldConfiguration {
        return ShieldConfiguration(
            // ... same as above
        )
    }

    // Customize shield for an app via ApplicationToken (iOS 17.5+)
    override func configuration(
        shielding application: Application,
        in category: ActivityCategory?
    ) -> ShieldConfiguration {
        // More specific override available in newer iOS versions
        return ShieldConfiguration()
    }
}
```

### Info.plist for Shield Configuration Extension
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.ManagedSettingsUI.shield-configuration</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShieldConfigurationExtension</string>
</dict>
```

---

## Shield Action Extension (ShieldActionDelegate)

This extension handles user taps on shield buttons (primary and secondary).

### Extension Target Setup
- **Extension Point Identifier**: `com.apple.ManagedSettings.shield-action`
- **Principal Class**: `$(PRODUCT_MODULE_NAME).ShieldActionExtension`

```swift
import ManagedSettings

class ShieldActionExtension: ShieldActionDelegate {

    // Handle action for a shielded application
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            // Example: Write unlock request to shared UserDefaults
            let defaults = UserDefaults(suiteName: "group.com.yourapp.shared")
            defaults?.set(true, forKey: "unlockRequested")
            completionHandler(.close)

        case .secondaryButtonPressed:
            completionHandler(.close)

        @unknown default:
            completionHandler(.none)
        }
    }

    // Handle action for a shielded web domain
    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }
}
```

### ShieldActionResponse Options
- **`.none`** — Does nothing; the shield remains visible
- **`.close`** — Closes the shielded app and returns to the home screen
- **`.defer`** — Reloads the `ShieldConfiguration` (re-calls `ShieldConfigurationDataSource`)

### ⚠️ Critical Limitation
There is **NO** `.openParentApp` option. You cannot programmatically open your main app from a shield extension. The common workaround is:
1. Write an "unlock request" to shared `UserDefaults` (App Group)
2. Send a local notification prompting the user to open your app
3. When user opens your app, read the flag and perform the unlock flow

### Info.plist for Shield Action Extension
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.ManagedSettings.shield-action</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShieldActionExtension</string>
</dict>
```

---

## App & Token Identification System

### Opaque Tokens (Privacy-First Design)

Apple's Screen Time API uses **opaque, privacy-preserving tokens** instead of bundle identifiers. Your app **never knows** which specific apps the user selected.

- **`ApplicationToken`** — Represents a single app (opaque)
- **`ActivityCategoryToken`** — Represents a category of apps (opaque)
- **`WebDomainToken`** — Represents a web domain (opaque)

These tokens:
- Are **Codable** (can be serialized/deserialized)
- Can be used in SwiftUI `Label` views to show the app name/icon to the user
- Can be passed to `ManagedSettingsStore` for blocking
- **Cannot** be used to determine the app's bundle ID
- **Cannot** be used to open the target app
- **May change randomly** without warning (known bug — see Limitations)

### FamilyActivitySelection

```swift
let selection = FamilyActivitySelection()
// After user picks from FamilyActivityPicker:
selection.applicationTokens   // Set<ApplicationToken>
selection.categoryTokens      // Set<ActivityCategoryToken>
selection.webDomainTokens     // Set<WebDomainToken>
```

### Serializing Tokens for Cross-Extension Sharing

Since tokens are `Codable`, you can serialize them to share via App Groups:

```swift
// Encode
let data = try JSONEncoder().encode(Array(selection.applicationTokens))
let defaults = UserDefaults(suiteName: "group.com.yourapp.shared")
defaults?.set(data, forKey: "blockedAppTokens")

// Decode
if let data = defaults?.data(forKey: "blockedAppTokens"),
   let tokens = try? JSONDecoder().decode([ApplicationToken].self, from: data) {
    let tokenSet = Set(tokens)
}
```

---

## Required Entitlements & Info.plist

### 1. Family Controls Entitlement (REQUIRED)

This is a **privileged entitlement** that must be approved by Apple.

In your app's `.entitlements` file:
```xml
<key>com.apple.developer.family-controls</key>
<true/>
```

There are **two** entitlement variants:
- **`Family Controls (Development)`** — For development and testing on real devices. Cannot be used with a free/Personal Team Apple ID.
- **`Family Controls (Distribution)`** — Required for TestFlight and App Store distribution. Must be [requested from Apple](https://developer.apple.com/contact/request/family-controls-distribution).

### 2. App Groups (REQUIRED for extension communication)

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.yourcompany.yourapp.shared</string>
</array>
```

Must be added to:
- Main app target
- Every extension target that needs shared data

### 3. Extension Info.plist Entries

**DeviceActivityMonitor Extension:**
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.DeviceActivity.monitor</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension</string>
</dict>
```

**Shield Configuration Extension:**
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.ManagedSettingsUI.shield-configuration</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShieldConfigurationExtension</string>
</dict>
```

**Shield Action Extension:**
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.ManagedSettings.shield-action</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShieldActionExtension</string>
</dict>
```

---

## Xcode Project Structure (Extension Targets)

A complete Screen Time API app typically requires **4 targets**:

```
YourApp/                          ← Main App Target
├── YourApp.entitlements          (Family Controls + App Groups)
├── Info.plist
├── App.swift                     (Authorization + FamilyActivityPicker)
├── ShieldManager.swift           (ManagedSettingsStore logic)
│
DeviceActivityMonitorExtension/   ← Extension Target 1
├── DeviceActivityMonitorExtension.entitlements (Family Controls + App Groups)
├── Info.plist                    (NSExtensionPointIdentifier: com.apple.DeviceActivity.monitor)
├── DeviceActivityMonitorExtension.swift
│
ShieldConfigurationExtension/     ← Extension Target 2
├── ShieldConfigurationExtension.entitlements (Family Controls)
├── Info.plist                    (NSExtensionPointIdentifier: com.apple.ManagedSettingsUI.shield-configuration)
├── ShieldConfigurationExtension.swift
│
ShieldActionExtension/            ← Extension Target 3
├── ShieldActionExtension.entitlements (Family Controls + App Groups)
├── Info.plist                    (NSExtensionPointIdentifier: com.apple.ManagedSettings.shield-action)
├── ShieldActionExtension.swift
```

### Adding Extension Targets in Xcode
1. **File → New → Target**
2. Select the appropriate template:
   - "Shield Action Extension" (for ShieldActionDelegate)
   - "Shield Configuration Extension" (for ShieldConfigurationDataSource)
   - "Device Activity Monitor Extension" (for DeviceActivityMonitor)
3. When prompted to activate the scheme, do so
4. Edit each extension's scheme → Run → Info → Executable → select your main app's `.app`
5. Add the **Family Controls** entitlement to each extension target
6. Add the **App Groups** capability to targets that need shared data

### Shared Code
Files that are used across multiple targets (e.g., shared data models, UserDefaults keys) should be added to a shared framework or have their **Target Membership** set to include all relevant targets.

---

## Data Sharing Between Extensions

Extensions (Shield Action, Shield Configuration, DeviceActivityMonitor) and the main app all run as **separate processes**. They **cannot** share:
- Core Data databases
- SwiftData model containers
- In-memory state

### The Only Reliable Method: UserDefaults via App Groups

```swift
// Shared constants
let appGroupID = "group.com.yourcompany.yourapp.shared"

// Write from any target
let defaults = UserDefaults(suiteName: appGroupID)
defaults?.set(true, forKey: "isCurrentlyBlocked")
defaults?.set(Date().timeIntervalSince1970, forKey: "blockEndTimestamp")

// Read from any target
let defaults = UserDefaults(suiteName: appGroupID)
let isBlocked = defaults?.bool(forKey: "isCurrentlyBlocked") ?? false
let endTime = defaults?.double(forKey: "blockEndTimestamp") ?? 0
```

### Minimum Shared State You'll Need
- `isCurrentlyUnlocked: Bool` — whether an unlock session is active
- `unlockEndTimestamp: TimeInterval` — when the unlock timer expires
- `serializedAppTokens: Data` — encoded ApplicationTokens (base64/JSON)
- `serializedCategoryTokens: Data` — encoded ActivityCategoryTokens
- `serializedWebDomainTokens: Data` — encoded WebDomainTokens
- `lastDayCheck: String` — date of last new-day check

### ⚠️ Serialization Safety
Always validate decoded data before overwriting. If token data fails to decode and you write an empty set back to UserDefaults, you permanently destroy your blocking data.

---

## iOS 16+ Changes (Individual Authorization)

### iOS 15 (Original Release)
- Only `.child` authorization (Family Sharing required)
- Parent must approve on their device
- Designed exclusively for parental controls

### iOS 16 (Major Update)
- Added **`.individual` authorization** — users can control their own device
- Enabled self-control / digital wellness apps
- `ManagedSettingsStore` became accessible from extensions (shared access between host app and extensions)
- Shield extensions can access the store directly

### iOS 17+ (Refinements)
- Continued API availability on iOS 17 and visionOS
- `FamilyActivityPicker` improvements
- Bug fixes (though many remain)
- Extended platform support

---

## Known Limitations & Gotchas

### 1. DeviceActivity Schedules Unreliable Beyond ~45 Minutes
Schedules set more than 45 minutes in the future may fire early, late, or not at all. **Workaround**: Chain shorter schedules (15–44 minute intervals) together.

### 2. Maximum 20 DeviceActivitySchedule Objects Per App
Attempting to register more than 20 active schedules will fail. Plan your schedule architecture accordingly.

### 3. `startMonitoring()` Triggers `intervalDidEnd` as Side Effect
Calling `startMonitoring()` for a `DeviceActivityName` that is already being monitored first internally calls `stopMonitoring()`, which triggers `intervalDidEnd`. This can cause unexpected re-blocking. **Workaround**: Guard your `intervalDidEnd` handler — check timestamps, don't assume it means the user's time is up.

### 4. Random Token Changes (Known Apple Bug)
iOS occasionally provides new, unknown tokens to `ShieldConfigurationDataSource` and `ShieldActionDelegate` that don't match previously stored tokens. This makes it impossible to determine which blocking context a shield belongs to.

### 5. Cannot Open Parent App from Shield Extension
`ShieldActionResponse` only supports `.none`, `.close`, and `.defer`. There is no `.openParentApp`. **Workaround**: Use local notifications or write to shared UserDefaults and have the user manually open your app.

### 6. Cannot Open Target App from ApplicationToken
There's no API to launch a blocked app from its token. URL schemes require manual user configuration per app.

### 7. Screen Time API Does NOT Work in Simulator
Always test on a **real device**. The simulator has severe limitations and many features simply don't function.

### 8. Personal Team (Free Apple ID) Cannot Test on Device
The `Family Controls (Development)` entitlement requires a **paid** Apple Developer Program membership ($99/year). You cannot test on a real device with a free/Personal Team.

### 9. Extensions Cannot Share Databases
No Core Data, SwiftData, or SQLite sharing between extension processes. Use UserDefaults via App Groups only.

### 10. Stale Boolean Flags
If your main app sets `isUnlocked = true` and starts a timer, but the user backgrounds your app, the timer stops. The flag stays `true` forever. **Workaround**: Always check both the boolean flag AND the timestamp. If the timestamp is in the past, the session has expired regardless of the flag.

### 11. Minute vs. Second Precision
`DeviceActivitySchedule` uses `DateComponents` which operates in **minute** precision. If you need second-level accuracy (e.g., a 90-second unlock), you cannot rely on DeviceActivity schedules alone.

### 12. Shield UI Not Updated When Moving Tokens Between Stores
If a token is removed from one `ManagedSettingsStore` and added to another, the shield UI may not update and may show stale configuration from the previous store.

### 13. `DeviceActivityMonitor` Extension May Fail to Launch
The extension sometimes fails to launch for scheduled events or threshold events. This is a known reliability issue. **Workaround**: Use redundant blocking mechanisms (see Best Practices).

### 14. Async Code in Extensions Gets Suspended
If you use `async/await` in shield extensions for re-blocking logic, iOS may suspend the extension before the async work completes. **Workaround**: Keep extension code synchronous where possible.

### 15. Distribution Entitlement Approval Takes 2-6 Weeks
The `Family Controls (Distribution)` entitlement must be manually approved by Apple. Typical wait times are 2–6 weeks. Plan for this in your release timeline.

### 16. Screen Time Permissions Easily Revoked
Even if the user has Screen Time locked with a passcode, third-party app Screen Time permissions can be toggled off in iOS Settings without the passcode. Apple's native Screen Time lock does not extend to third-party app permissions.

---

## Code Patterns & Best Practices

### 1. Triple-Blocking Architecture (Most Robust)
Use three independent systems to enforce blocking:

1. **Shield Extension** — Synchronous check when user opens a blocked app. First line of defense.
2. **DeviceActivityMonitor** — Scheduled background checks to re-block when unlock sessions expire.
3. **Main App foreground check** — When your app comes to foreground, immediately check and re-block if needed.

Each covers the gaps of the others.

### 2. Always Check Both Flag AND Timestamp

```swift
func shouldBeBlocked() -> Bool {
    let defaults = UserDefaults(suiteName: appGroupID)
    let isUnlocked = defaults?.bool(forKey: "isCurrentlyUnlocked") ?? false
    let endTimestamp = defaults?.double(forKey: "unlockEndTimestamp") ?? 0
    let endDate = Date(timeIntervalSince1970: endTimestamp)

    // If flag says unlocked but timestamp is past, session has expired
    if isUnlocked && endDate < Date() {
        return true // Should re-block
    }
    return !isUnlocked
}
```

### 3. Chain Short DeviceActivity Schedules

```swift
// Instead of one 90-minute schedule, chain 15-44 min checks
func scheduleNextCheck(slotIndex: Int) {
    let slots = ["reblockChain_0", "reblockChain_1", "reblockChain_2", "reblockChain_3", "reblockChain_4"]
    let name = DeviceActivityName(slots[slotIndex % slots.count])

    let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
    let futureDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
    let end = Calendar.current.dateComponents([.hour, .minute], from: futureDate)

    let schedule = DeviceActivitySchedule(
        intervalStart: now,
        intervalEnd: end,
        repeats: false
    )

    try? DeviceActivityCenter().startMonitoring(name, during: schedule)
}
```

### 4. Synchronous First Check on App Launch

```swift
@main
struct MyApp: App {
    init() {
        // SYNCHRONOUS check before anything else
        let defaults = UserDefaults(suiteName: "group.com.yourapp.shared")
        let isUnlocked = defaults?.bool(forKey: "isCurrentlyUnlocked") ?? false
        let endTimestamp = defaults?.double(forKey: "unlockEndTimestamp") ?? 0

        if isUnlocked && Date(timeIntervalSince1970: endTimestamp) < Date() {
            // Session expired while app was backgrounded — re-block immediately
            reapplyBlocking()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 5. Guard `intervalDidEnd` Against False Triggers

```swift
override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)

    let defaults = UserDefaults(suiteName: appGroupID)
    let isUnlocked = defaults?.bool(forKey: "isCurrentlyUnlocked") ?? false
    let endTimestamp = defaults?.double(forKey: "unlockEndTimestamp") ?? 0

    // Only re-block if unlock session is truly expired
    guard !isUnlocked || Date(timeIntervalSince1970: endTimestamp) < Date() else {
        return // Active unlock session — don't re-block
    }

    reapplyBlocking()
}
```

### 6. Validate Before Overwriting Token Data

```swift
func safelyUpdateTokens(_ newData: Data?) {
    guard let data = newData,
          let tokens = try? JSONDecoder().decode([ApplicationToken].self, from: data),
          !tokens.isEmpty else {
        // Don't overwrite — would destroy blocking data
        return
    }
    let defaults = UserDefaults(suiteName: appGroupID)
    defaults?.set(data, forKey: "blockedAppTokens")
}
```

---

## Entitlement Approval Process

### Development Entitlement
1. Sign in to your Apple Developer account
2. In Xcode: Target → Signing & Capabilities → + Capability → Family Controls
3. Select "Family Controls (Development)"
4. Requires paid Apple Developer Program membership

### Distribution Entitlement (for TestFlight / App Store)
1. Submit a request at: https://developer.apple.com/contact/request/family-controls-distribution
2. Provide:
   - App name and description
   - How you plan to use Screen Time APIs
   - Target audience
3. Wait for Apple's approval (typically **2–6 weeks**)
4. Once approved, switch from Development to Distribution entitlement
5. Without this, your app will be **rejected** during App Store review

---

## Key References

### Apple Developer Documentation
- [FamilyControls Framework](https://developer.apple.com/documentation/familycontrols)
- [ManagedSettings Framework](https://developer.apple.com/documentation/managedsettings)
- [ManagedSettingsStore](https://developer.apple.com/documentation/managedsettings/managedsettingsstore)
- [ShieldSettings](https://developer.apple.com/documentation/managedsettings/shieldsettings)
- [DeviceActivity Framework](https://developer.apple.com/documentation/deviceactivity)
- [DeviceActivityMonitor](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor)
- [ManagedSettingsUI / ShieldConfigurationDataSource](https://developer.apple.com/documentation/ManagedSettingsUI/ShieldConfigurationDataSource)
- [ShieldActionDelegate](https://developer.apple.com/documentation/managedsettings/shieldactiondelegate)
- [Configuring Family Controls (Xcode setup)](https://developer.apple.com/documentation/xcode/configuring-family-controls)
- [Screen Time Technology Frameworks](https://developer.apple.com/documentation/screentimeapidocumentation)

### WWDC Videos
- [WWDC21: Meet the Screen Time API](https://developer.apple.com/videos/play/wwdc2021/10123/)
- [WWDC22: What's new in Screen Time API](https://developer.apple.com/videos/play/wwdc2022/10009/)

### Tutorials & Guides
- [Pedro Ésli: Using Screen Time API to block apps](http://pedroesli.com/2023-11-13-screen-time-api/)
- [hsb.horse: A Design Guide to Building an iOS Self-Control App with the Screen Time API (2026)](https://hsb.horse/en/blog/ios-screen-time-api-self-control-app-guide/)
- [Habit Doom: Apple's Screen Time API — How It Broke Me (2026)](https://habitdoom.com/blog/apple-screen-time-api-guide)
- [Frederik Riedel / one sec: Apple's Screen Time API has some major issues (2024)](https://riedel.wtf/state-of-the-screen-time-api-2024/)

### Apple Entitlement Request
- [Request Family Controls Distribution Entitlement](https://developer.apple.com/contact/request/family-controls-distribution)

### Community / Forums
- [Apple Developer Forums: Family Controls](https://developer.apple.com/forums/tags/family-controls)
- [Apple Developer Forums: Device Activity](https://developer.apple.com/forums/tags/device-activity)
- [Apple Developer Forums: Screen Time](https://developer.apple.com/forums/tags/screen-time)
