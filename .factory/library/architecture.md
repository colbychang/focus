# Architecture

## System Overview

Focault (bundle ID: com.colbychang.focus) is a native iOS app (iOS 17.0+) for focus mode management and screen time analytics. The display name is "Focault" but the bundle ID, scheme name, and code references use "Focus". It uses Apple's Screen Time API for OS-level app blocking, SwiftData for persistence, and ActivityKit for Dynamic Island integration.

## Target Structure

```
Focus.xcodeproj
├── Focus (Main App)                    -- SwiftUI app, all UI, ViewModels
├── FocusCore (Swift Package)           -- Shared models, protocols, utilities
├── DeviceActivityMonitorExtension      -- Handles scheduled focus mode start/end
├── ShieldConfigurationExtension        -- Custom blocked-app shield UI
├── ShieldActionExtension               -- Handles shield button taps
├── DeviceActivityReportExtension       -- Custom screen time report views
├── FocusWidgets (Widget Extension)     -- Live Activities for Dynamic Island
├── FocusTests (Unit Tests)             -- Swift Testing framework
└── FocusUITests (UI Tests)             -- XCUITest
```

## Package Architecture

**FocusCore** is the shared Swift Package imported by ALL targets. It contains:
- SwiftData models (VersionedSchema)
- Protocol abstractions for Screen Time services
- Mock implementations for testing
- Shared constants (App Group ID, store names)
- Business logic (timer, trend detection, averages)

## Data Flow

### Cross-Process Communication
Extensions run in separate processes. The ONLY reliable communication mechanism is **App Group UserDefaults** (`group.com.colbychang.focus.shared`).

```
Main App ←→ UserDefaults(suiteName: appGroupID) ←→ Extensions
```

All shared state uses **flag + timestamp** pattern (never boolean alone) to prevent stale state from crashes.

### Persistence Layers
- **SwiftData** (main app only): Focus mode profiles, deep focus sessions, screen time entries, analytics data. Uses in-memory containers for tests.
- **App Group UserDefaults**: Cross-extension state (active sessions, blocking status, serialized tokens).
- **ManagedSettingsStore**: OS-level shield persistence (survives reboots). Named stores per focus mode profile.

## Key Patterns

### Protocol Abstraction Layer
All Screen Time APIs are accessed through protocols:
- `AuthorizationServiceProtocol` → Real: `AuthorizationCenter.shared` / Mock: `MockAuthorizationService`
- `ShieldServiceProtocol` → Real: `ManagedSettingsStore` / Mock: `MockShieldService`
- `MonitoringServiceProtocol` → Real: `DeviceActivityCenter` / Mock: `MockMonitoringService`
- `LiveActivityServiceProtocol` → Real: ActivityKit `Activity` / Mock: `MockLiveActivityService`

This enables full testability without the Family Controls entitlement.

### Triple-Blocking Architecture
Focus mode enforcement uses three independent layers:
1. **Shield Extension** — OS-level intercept when user opens a blocked app
2. **DeviceActivityMonitor** — Scheduled background checks for re-blocking
3. **Main App foreground check** — Re-apply blocking on app activation

### Named ManagedSettingsStore per Profile
Each focus mode profile gets its own named `ManagedSettingsStore` (named by profile UUID). This ensures:
- Independent shield management per profile
- Deactivating one doesn't affect others
- Clean cleanup on profile deletion

### Deep Focus Session State Machine
```
.idle → .active → .completed
           ↓           ↑
       .onBreak ────────┘
           ↓           ↑
     .bypassing ────────┘
           ↓
      .abandoned
```

### Timer Architecture
- Main session timer: counts down `remainingSeconds`, pauses during breaks
- Bypass countdown: independent 60-second timer, runs alongside main timer
- Break timer: independent, shown in Dynamic Island via Live Activity using `Text(timerInterval:)`
- Background handling: record timestamp on background, compute elapsed on foreground

## Data Model Overview

### FocusMode
Profile with name, icon, color, schedule (days/times), app selection (serialized tokens), isActive flag.

### DeepFocusSession
Session record: start time, duration, remaining time, status (active/onBreak/bypassing/completed/abandoned), bypass count, break count, total break duration, allowed apps config.

### ScreenTimeEntry
Per-app or per-category usage record linked to a session, used for analytics.

### BlockedAppGroup
Named group of app tokens for category-based analytics aggregation.

## Cross-Process Real-Time Signaling (Extension → Foreground App)

Extensions run in separate processes and cannot call into the main app directly. For **one-time data persistence** (session records, state flags), writing to App Group UserDefaults is sufficient — the main app reads it the next time it becomes active.

For **real-time foreground notifications** (e.g., "show a banner when a focus session starts"), App Group UserDefaults alone is NOT enough. The main app needs an IPC signal to observe the change immediately. Two patterns are available:

1. **Darwin notifications** (recommended for real-time):
   - Extension posts: `CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), "com.colbychang.focus.sessionStarted" as CFNotificationName, nil, nil, true)`
   - Main app observes: `CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), ...)` or wrap in a `DarwinNotificationObserver` actor.
   - The notification carries no payload; the main app reads the actual data from UserDefaults when it receives the notification.

2. **UserDefaults KVO / `.task` polling** (simpler but less immediate):
   - Main app polls UserDefaults for a "pendingNotification" key in a `.task` background loop.
   - Less responsive but avoids Darwin notification boilerplate.

**Profile metadata in extensions:** Extensions do not have SwiftData access. If an extension needs a profile's display name (for analytics records, notifications, etc.), that metadata must be mirrored into App Group UserDefaults at profile-creation/update time. Use the shared constant `FocusModeService.profileNameKeyPrefix` to construct the key in both the main app and extensions — format: `profileNameKeyPrefix + uuid.uuidString`. Avoid hardcoding the key string in more than one place.

**Last-event metadata pattern for Darwin notifications:** Darwin notifications carry no payload. When the main app receives a notification, it reads associated data from UserDefaults. However, if UserDefaults state associated with the event was updated *before* the notification was posted (e.g., a session record moved from `activeSessionStarts` to `pendingRecords` in `recordSessionEnd`), the receiving handler may not find it under the expected key. To avoid this, write a dedicated "last event metadata" entry to UserDefaults *immediately before* posting the Darwin notification, with both the profile UUID and event type. Example keys: `last_focus_event_profile_uuid`, `last_focus_event_type`. The main app then reads from these stable keys regardless of other state transitions.

## Deep Focus State Machine Constraints

### Break/Bypass Interaction Protocol
`BreakFlowManager.startBreak()` guards `sessionStatus == .active` and throws `.invalidSessionState` if the session is in `.bypassing`. The correct cleanup sequence when starting a break during a bypass countdown is:
1. `BypassFlowManager.handleBreakStarted()` must call `sessionManager.resumeFromBypassing()` to return the session to `.active` **before** `BreakFlowManager.startBreak()` is called.
2. Only after `handleBreakStarted()` returns can `startBreak()` be safely invoked.

### Recovery Call Sequence (App Launch)
When recovering from app termination, these two methods must be called in order:
1. `BreakFlowManager.recoverBreakState()` — sets up break state and starts break timer if on break
2. `DeepFocusSessionManager.recoverOrphanedSession()` — recovers session state

**Critical**: If a break was active at termination, `recoverBreakState()` starts the break timer and sets `breakState = .active`. Then `recoverOrphanedSession()` must NOT start the main session timer (it should check `sharedStateService.isOnBreak()` and skip `startTimer()` when on break). The current implementation has a bug: `recoverOrphanedSession()` calls `startTimer()` for `.onBreak` sessions, causing both timers to run simultaneously.

### ShieldServiceProtocol.applyShields — Two Distinct Semantics
The same `applyShields(storeName:applications:categories:webDomains:)` call carries different semantics depending on the caller:
- **Focus mode** (`FocusModeActivationService`): passes the tokens **to block** (specific blocking). Real implementation uses `.specific(tokens)`.
- **Deep focus** (`DeepFocusBlockingService`): passes **allowed** (exception) tokens. Real implementation uses `.all(except: tokens)`.

When implementing the real `ShieldServiceProtocol`, each use site must be handled differently. The `MockShieldService` does not distinguish these semantics — it simply records what it received. A dedicated deep-focus shield service method (e.g., `applyBlockAllExcept`) would be cleaner.

### suspendBlocking() vs clearBlocking() in DeepFocusBlockingService
- `clearBlocking()`: Removes all shields AND clears `currentAllowedTokens`. Use when session ends.
- `suspendBlocking()`: Removes shields but preserves `currentAllowedTokens` for re-application. Use during breaks (so `reapplyBlocking()` can restore the correct config after the break).
Using `clearBlocking()` during a break would prevent correct re-application after break ends.

## Key Constraints

1. **No Family Controls entitlement yet** — all Screen Time calls go through protocol mocks
2. **Extensions cannot share databases** — UserDefaults only for cross-process state
3. **Max 20 DeviceActivity schedules** — schedule architecture must be conservative
4. **DeviceActivity schedules unreliable >45 min** — chain shorter schedules
5. **Opaque tokens** — cannot determine which specific app a token represents
6. **Shield extension memory limit ~6MB** — keep extension code minimal
7. **Simulator limitations** — Screen Time callbacks don't fire, test via mocks
