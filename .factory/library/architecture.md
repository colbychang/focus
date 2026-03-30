# Architecture

## System Overview

Focus is a native iOS app (iOS 17.0+) for focus mode management and screen time analytics. It uses Apple's Screen Time API for OS-level app blocking, SwiftData for persistence, and ActivityKit for Dynamic Island integration.

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

## Key Constraints

1. **No Family Controls entitlement yet** — all Screen Time calls go through protocol mocks
2. **Extensions cannot share databases** — UserDefaults only for cross-process state
3. **Max 20 DeviceActivity schedules** — schedule architecture must be conservative
4. **DeviceActivity schedules unreliable >45 min** — chain shorter schedules
5. **Opaque tokens** — cannot determine which specific app a token represents
6. **Shield extension memory limit ~6MB** — keep extension code minimal
7. **Simulator limitations** — Screen Time callbacks don't fire, test via mocks
