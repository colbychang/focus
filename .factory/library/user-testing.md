# User Testing

Testing surface, required testing tools, and resource cost classification.

---

## Validation Surface

**Primary surface:** iOS Simulator via xcodebuild test

This is a native iOS app with no web surface. Validation runs via:
- **Unit tests (Swift Testing):** Business logic, models, ViewModels, algorithms
- **UI tests (XCUITest):** User flow validation on iOS Simulator

**No agent-browser surface** — this is a native iOS app, not a web app.

**Tool:** `xcodebuild test` (both unit and UI tests)

## Testing Limitations
- Screen Time API integration cannot be validated until Family Controls entitlement is available
- DeviceActivityMonitor callbacks do not fire in simulator
- Shield extension UI only testable on real device with entitlement
- Live Activity rendering in Dynamic Island only visible on real device (but logic is testable)
- All Screen Time interactions tested via protocol mocks

## Validation Concurrency

**Surface: xcodebuild test**
- Machine: 10 CPU cores, 24 GB RAM
- xcodebuild test parallelism: configured to 4 workers (`-parallel-testing-worker-count 4`)
- Each simulator instance uses ~1-2 GB RAM
- Max concurrent validators: **2** (each runs xcodebuild which spawns parallel test workers internally)
- Rationale: 2 validators × 4 parallel test workers = 8 worker processes × ~500MB = ~4GB. Plus simulator overhead (~2GB each) = ~8GB total. Well within 24GB budget at 70% headroom (~17GB).

## Setup Requirements
- iOS simulator runtime must be downloaded
- xcode-select must point to Xcode.app
- Project must build successfully before tests can run

## Flow Validator Guidance: xcodebuild test

**Surface:** iOS Simulator via xcodebuild test (unit and UI tests)

**Key environment variables required in every command:**
```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
CODE_SIGN_IDENTITY=""
CODE_SIGNING_REQUIRED=NO
```

**Simulator target:** `'platform=iOS Simulator,name=iPhone 17 Pro'`

**Unit test command:**
```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Focus -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing FocusTests CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -100
```

**UI test command:**
```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Focus -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing FocusUITests CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -100
```

**Build command (for build-only assertions):**
```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme Focus -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -50
```

**Isolation rules:**
- Unit tests and UI tests use different test bundles (FocusTests vs FocusUITests) and can run concurrently
- Each xcodebuild process allocates its own simulator clone from the device pool
- Do not modify shared simulator state between validators
- Use `-quiet` flag to suppress verbose output unless debugging failures

**Determining pass/fail from xcodebuild output:**
- Exit code 0 = tests passed
- Exit code 65 = test execution errors or failures (look for "Test FAILED" or "** TEST FAILED **")
- Look for: `Test Suite '...' passed` or `** TEST SUCCEEDED **` for pass
- Look for: `** TEST FAILED **` or specific test failure messages for fail
- Individual test methods are reported as: `✓ <testName>` (pass) or `✗ <testName>` (fail)

**Mapping tests to assertions:**
- VAL-FOUND-001: Build succeeds (xcodebuild build exit 0)
- VAL-FOUND-002: Tests in FocusTests covering FocusMode/DeepFocusSession/BlockedAppGroup/ScreenTimeEntry CRUD
- VAL-FOUND-003: Tests in FocusTests covering AuthorizationService, ShieldService, MonitoringService protocols and mocks
- VAL-FOUND-004: UI tests in FocusUITests covering tab navigation (4 tabs)
- VAL-FOUND-005: UI tests in FocusUITests covering authorization flow (approve/deny)
- VAL-FOUND-006: Tests in FocusTests covering App Group UserDefaults
- VAL-FOUND-007: Tests in FocusTests covering token serialization validation
- VAL-FOUND-008: Tests in FocusTests covering VersionedSchema / SchemaMigrationPlan
- VAL-CROSS-013: Tests in FocusTests covering timestamp-based expiry of shared state flags
