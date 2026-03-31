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
