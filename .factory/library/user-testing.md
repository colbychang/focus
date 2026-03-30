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
