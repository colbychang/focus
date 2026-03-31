# User Testing Knowledge — Focault iOS App

## Overview

This is a pure iOS app with no backend services. Testing is performed via xcodebuild running Swift Testing unit tests and XCUITest UI tests on the iOS Simulator.

## Simulator

- **Device:** iPhone 17 Pro (simulator ID: 03BD412B-FD96-4E2F-A1C0-9A1C680D3A18)
- **OS:** iOS 26.4
- **Status:** Pre-booted and available

## Environment Setup

No services to start — this is a pure on-device iOS app. The simulator is pre-booted.

**Critical env var required for all xcodebuild commands:**
```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

**Code signing must be disabled for tests:**
```
CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

## Test Commands

**Unit tests:**
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -scheme Focus \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing FocusTests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1
```

**UI tests:**
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -scheme Focus \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing FocusUITests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1
```

**Individual test class:**
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -scheme Focus \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing FocusTests/FocusModeServiceTests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1
```

## Test File → Assertion Mapping

### Unit Tests (FocusTests/)

| File | Assertions |
|------|-----------|
| FocusModeServiceTests.swift | VAL-FOCUS-001, VAL-FOCUS-002, VAL-FOCUS-010 |
| ScheduleTests.swift | VAL-FOCUS-003, VAL-FOCUS-004, VAL-FOCUS-008, VAL-FOCUS-011, VAL-FOCUS-014 |
| FocusModeActivationTests.swift | VAL-FOCUS-006, VAL-FOCUS-007, VAL-FOCUS-012, VAL-FOCUS-014 |
| ShieldExtensionTests.swift | VAL-FOCUS-013 |
| CrossAreaTests.swift | VAL-CROSS-003, VAL-CROSS-006, VAL-CROSS-007, VAL-CROSS-009 |
| ScrutinyFixTests.swift | Scrutiny fixes (VAL-FOCUS-011 V2 schema) |
| SwiftDataModelTests.swift | Foundation tests |
| ProtocolAbstractionTests.swift | Foundation tests |
| AppShellTests.swift | Foundation tests |

### UI Tests (FocusUITests/)

| File | Assertions |
|------|-----------|
| FocusModeUITests.swift | VAL-FOCUS-001, VAL-FOCUS-002, VAL-FOCUS-010 |
| FocusModeActivationUITests.swift | VAL-FOCUS-006 (UI) |
| GrayscaleGuideUITests.swift | VAL-FOCUS-009 |
| FocusNotificationUITests.swift | VAL-CROSS-008 |
| AppShellUITests.swift | Foundation tests |

### Missing UI Tests

- VAL-FOCUS-005: FamilyActivityPicker is not testable in simulator (requires entitlement) — unit test covers token persistence
- VAL-FOCUS-009: Grayscale guide (GrayscaleGuideUITests.swift covers this)

## Validation Concurrency

### Surface: xcodebuild test (iOS Simulator)

**Max concurrent validators: 1**

Reason: All tests share the same iOS Simulator instance. Running multiple xcodebuild test processes simultaneously causes conflicts, crashes, and false failures. Tests must run serially.

**Strategy:** Run unit tests first, then UI tests in a separate session.

## Flow Validator Guidance: xcodebuild-unit-tests

- Run `xcodebuild test -only-testing FocusTests` to test all unit assertions
- Tests are self-contained with in-memory SwiftData containers — no shared mutable state between test cases
- Parallel test execution within a single run is safe (xcodebuild handles this)
- Parse test output for pass/fail results per test class and function
- Look for "Test Suite ... passed" / "Test Suite ... failed" in output
- Each test class maps to specific assertions as shown in the mapping table above

## Flow Validator Guidance: xcodebuild-ui-tests

- Run `xcodebuild test -only-testing FocusUITests` to test all UI assertions
- UI tests require the app to be running in the simulator
- Must run AFTER unit tests complete (shared simulator)
- Look for XCTest pass/fail output
- If a test fails, capture the failure message and screenshot path from output
- UI tests for FamilyActivityPicker (VAL-FOCUS-005) cannot be run due to FamilyControls entitlement restriction — this is a known limitation documented in the mission README

## Known Limitations

1. FamilyActivityPicker: Cannot be presented in simulator without Family Controls entitlement. VAL-FOCUS-005 picker presentation UI test is blocked. Unit tests for token persistence cover the testable aspects.
2. DeviceActivityMonitor callbacks: Cannot be triggered in simulator. All DeviceActivity integration is tested via mock protocols.
3. Shield UI: Only testable via protocol mocks (ShieldConfigurationExtension and ShieldActionExtension mock tests).
