# Testing Patterns & Quirks

**What belongs here:** Discovered testing behaviors, UI test patterns, simulator quirks, and testing infrastructure conventions.

---

## XCUITest: Launch Arguments for Test Configuration

Use `ProcessInfo.processInfo.arguments` in the app to configure test state at launch. This is the preferred pattern for UI test scenarios requiring specific initial conditions.

**Pattern (app side):**
```swift
// In FocusApp.swift (or equivalent setup point)
func configureService() -> ServiceProtocol {
    let args = ProcessInfo.processInfo.arguments
    if args.contains("--auth-status") {
        let idx = args.firstIndex(of: "--auth-status")!
        let status = args[idx + 1]
        // Configure based on status string
    }
    return MockService(...)
}
```

**Pattern (test side):**
```swift
let app = XCUIApplication()
app.launchArguments = ["--auth-status", "denied"]
app.launch()
```

**Discovered in:** `foundation-app-shell` — `Focus/FocusApp.swift` `configureAuthorizationService()` and `FocusUITests/AppShellUITests.swift`.

---

## XCUITest: VStack/HStack `.accessibilityIdentifier` Overrides Children

Applying `.accessibilityIdentifier()` to a SwiftUI container (`VStack`, `HStack`, `ZStack`) overrides all child element identifiers in the XCUITest accessibility hierarchy. The container's identifier replaces the children's identifiers, making individual child elements unreachable by identifier.

**Fix:** Apply `.accessibilityIdentifier()` to individual leaf elements (Text, Button, Image), not their parent containers.

```swift
// BAD — child identifiers are overridden
VStack {
    Text("Title").accessibilityIdentifier("Title")
    Button("Action") { }.accessibilityIdentifier("ActionButton")
}
.accessibilityIdentifier("MyContainer")  // ← overrides children

// GOOD — apply to individual elements only
VStack {
    Text("Title").accessibilityIdentifier("Title")
    Button("Action") { }.accessibilityIdentifier("ActionButton")
}
```

**Discovered in:** `foundation-app-shell` worker handoff (discoveredIssues[0]).

---

## Swift Testing + SwiftData: Use `.serialized` Trait to Prevent Crashes

Swift Testing runs tests in parallel by default. When `@MainActor` test suites use a SwiftData `ModelContext`, parallel execution causes EXC_BAD_ACCESS crashes because multiple tests access the same context concurrently.

**Fix:** Apply the `.serialized` suite trait to any test suite that uses `@MainActor` with a SwiftData `ModelContext`.

```swift
// Required for SwiftData + @MainActor test suites
@Suite("FocusModeService Tests", .serialized)
struct FocusModeServiceTests {
    var container: ModelContainer!
    var context: ModelContext!

    init() throws {
        container = try ModelContainer(
            for: FocusMode.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
    }
    // ...
}
```

**Discovered in:** `focus-mode-profile-crud` — tests crashed without `.serialized`; fixing it stabilized the entire suite.

---

## XCUITest: `--use-in-memory-store` Launch Argument for Clean SwiftData State

UI tests need a clean persistent store on each launch to avoid flaky cross-test contamination. Use a launch argument to switch to an in-memory SwiftData container.

**Pattern (app side — FocusApp.swift):**
```swift
let useInMemory = ProcessInfo.processInfo.arguments.contains("--use-in-memory-store")
let config = ModelConfiguration(isStoredInMemoryOnly: useInMemory)
modelContainer = try ModelContainer(for: FocusMode.self, ..., configurations: config)
```

**Pattern (test side):**
```swift
let app = XCUIApplication()
app.launchArguments = ["--auth-status", "approved", "--use-in-memory-store"]
app.launch()
```

This ensures each UI test starts with an empty store, making tests independent and idempotent.

**Discovered in:** `focus-mode-profile-crud` — established the pattern; adopted across all focus mode UI tests.

---

## xcodebuild: `** TEST FAILED **` False Positive with Swift Testing

When the test scheme includes both Swift Testing (`FocusTests`) and XCTest (`FocusUITests`) targets, xcodebuild sometimes prints `** TEST FAILED **` even when all Swift Testing tests pass and the exit code is 0. This is a known xcodebuild + Swift Testing interaction artifact.

**How to distinguish false positive from real failure:**
- Real failure: exit code is non-zero (65 for test failures)
- False positive: exit code is 0, Swift Testing runner output shows all tests passing

**Reliable check:**
```bash
# Check Swift Testing output specifically
DEVELOPER_DIR=... xcodebuild test -scheme Focus ... 2>&1 | grep -E "Test run with .* (passed|failed)"
```

If the line says `passed`, all tests passed regardless of the `** TEST FAILED **` message.

**Discovered in:** `rename-app-to-focault` — worker spent time re-investigating what turned out to be a benign artifact.

---

## Deep Focus UI Tests: --deep-focus-test-seconds Launch Argument

For UI tests that need an active deep focus session without waiting for real time to pass, use the `--deep-focus-test-seconds` launch argument to start a session with a short custom duration.

**Pattern (app side — DurationSelectionView.swift):**
```swift
// DurationSelectionView reads this to start a test-mode session
private var testDurationSeconds: Int? {
    let args = ProcessInfo.processInfo.arguments
    if let idx = args.firstIndex(of: "--deep-focus-test-seconds") {
        return Int(args[idx + 1])
    }
    return nil
}
```

**Pattern (test side):**
```swift
app.launchArguments = ["--auth-status", "approved", "--use-in-memory-store", "--deep-focus-test-seconds", "3600"]
app.launch()
// Navigate to Deep Focus tab and tap Start to begin a 60-minute test session
```

Note: `DeepFocusSessionManager.startTestSession(durationSeconds:)` bypasses the 5-minute minimum validation. It is a `public` method in production FocusCore (no `#if DEBUG` guard); the safety net is the launch-argument check at the callsite in `DurationSelectionView`.

**Discovered in:** `deep-focus-navigation-integration` worker.

---

## Swift Testing: Timer-Based Services Require deinit for Test Exit

`@MainActor @Observable` services that use `Timer.scheduledTimer` must invalidate their timer in `deinit`. If the timer is not stopped, the run loop stays alive after the test completes and the test process never exits (xcodebuild eventually times out).

**Fix:** Add `deinit` with `nonisolated(unsafe)` on the timer property:

```swift
@MainActor
@Observable
public final class SomeService {
    nonisolated(unsafe) private var timer: Timer?

    deinit {
        timer?.invalidate()
        timer = nil
    }
    // ...
}
```

Note: `nonisolated(unsafe)` is required to access the property in a `nonisolated deinit` (even though the compiler warns it "has no effect" — it does suppress the actor isolation error). This applies to `DeepFocusSessionManager.timer` and `BreakFlowManager.breakTimer`.

**Discovered in:** `scrutiny-validator-deep-focus` — tests using `DeepFocusSessionManager` and `BreakFlowManager` hung indefinitely without this fix.

---

## Swift Package Build: Do NOT Use `swift build` Inside FocusCore

Running `swift build` (or `swift test`) directly inside the `FocusCore/` directory targets **macOS** by default. SwiftData is unavailable on macOS without AppKit, causing compilation errors even though the package is correct for iOS.

**Always use `xcodebuild` targeting the iOS Simulator:**
```bash
# Correct: build and test via the main scheme
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
    -scheme Focus \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
    -scheme Focus \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing FocusTests \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# Wrong: will fail for SwiftData
cd FocusCore && swift build  # ← DO NOT DO THIS
```

Note: The `FocusCoreTests` test target (in `FocusCore/Package.swift`) IS covered by the standard `test-unit` command because Xcode resolves the package dependency and includes those tests.

**Discovered in:** `foundation-protocol-abstractions` worker — encountered SwiftData compilation errors when using `swift build` targeting macOS.
