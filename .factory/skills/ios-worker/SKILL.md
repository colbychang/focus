---
name: ios-worker
description: Builds iOS features for the Focus app — models, ViewModels, UI, extensions, and tests
---

# iOS Worker

NOTE: Startup and cleanup are handled by `worker-base`. This skill defines the WORK PROCEDURE.

## When to Use This Skill

All implementation features for the Focus iOS app: SwiftData models, protocol abstractions, ViewModels, SwiftUI views, extension targets, unit tests, UI tests, business logic, and analytics calculations.

## Required Skills

None — all testing is via xcodebuild command line.

## Work Procedure

### 1. Read Feature Context
- Read the feature description, preconditions, expectedBehavior, and verificationSteps from the assigned feature
- Read `.factory/library/architecture.md` for system design context
- Read `.factory/library/environment.md` for platform constraints
- Read `SCREEN_TIME_API_REFERENCE.md` and `ACTIVITYKIT_SWIFTDATA_REFERENCE.md` for API patterns (if the feature touches Screen Time or ActivityKit)

### 2. Plan Implementation
- Identify all files that need to be created or modified
- Check existing code structure to match patterns already established
- For new files: determine correct target membership (main app, FocusCore, extension, test target)

### 3. Write Tests First (TDD)
- Create test file(s) in FocusTests/ (unit tests using Swift Testing: `import Testing`, `@Test`, `#expect`)
- Write failing tests that cover the feature's expectedBehavior
- For UI flows: create XCUITest file(s) in FocusUITests/ (using XCTest: `XCUIApplication`, `XCTAssert`)
- Use in-memory `ModelConfiguration(isStoredInMemoryOnly: true)` for all SwiftData tests
- Use mock protocol implementations for all Screen Time API dependencies
- Run tests to confirm they fail: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Focus -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing FocusTests CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`

### 4. Implement
- Create/modify production code to make tests pass
- Follow existing patterns in the codebase (check how other files are structured)
- SwiftData models go in FocusCore (shared package)
- Protocol abstractions and mocks go in FocusCore
- ViewModels go in the main app target (or FocusCore if shared)
- SwiftUI views go in the main app target
- Extension code goes in the respective extension target
- IMPORTANT: When creating new files, verify the file is in the correct Xcode target
- IMPORTANT: All Screen Time API usage must go through protocol abstractions, never direct API calls
- IMPORTANT: All shared state in UserDefaults must use flag + timestamp pattern (never boolean alone)

### 5. Verify
- Run unit tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Focus -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing FocusTests CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
- Run UI tests (if applicable): `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Focus -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing FocusUITests CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
- Build the full project (catches cross-target issues): `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme Focus -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
- For each feature behavior: verify manually that the code implements what's described

### 6. Interactive Checks
- For UI features: describe what the UI should look like and how it behaves
- For model features: describe the data flow and persistence behavior
- For each verification step in the feature: execute it and record the result

## Example Handoff

```json
{
  "salientSummary": "Implemented FocusMode SwiftData model with VersionedSchema, CRUD operations via FocusModeService, and MockShieldService protocol abstraction. All 12 unit tests pass (create, fetch, update, delete, predicate query, cascade delete, empty name validation, duplicate name check). Build succeeds for all targets.",
  "whatWasImplemented": "FocusMode @Model with properties (id, name, icon, colorHex, schedule, serializedTokens, isActive, createdAt). FocusModeService with create/update/delete/fetch/activate/deactivate methods. ShieldServiceProtocol with applyShields/clearShields/isShielding. MockShieldService with call recording for test verification. Unit tests covering all CRUD operations and validation edge cases.",
  "whatWasLeftUndone": "",
  "verification": {
    "commandsRun": [
      {
        "command": "DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Focus -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing FocusTests/FocusModeTests CODE_SIGN_IDENTITY=\"\" CODE_SIGNING_REQUIRED=NO",
        "exitCode": 0,
        "observation": "12 tests executed, 12 passed, 0 failed. Test suite completed in 4.2 seconds."
      },
      {
        "command": "DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme Focus -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet",
        "exitCode": 0,
        "observation": "BUILD SUCCEEDED. All targets compiled including extensions."
      }
    ],
    "interactiveChecks": [
      {
        "action": "Reviewed FocusMode model properties against architecture.md requirements",
        "observed": "All required properties present: name, icon, color, schedule (days/start/end), serialized tokens, isActive flag, UUID identifier"
      },
      {
        "action": "Verified MockShieldService records all method calls for test assertions",
        "observed": "Mock tracks: applyShields call count and arguments, clearShields call count and store name, isShielding responses per store name"
      }
    ]
  },
  "tests": {
    "added": [
      {
        "file": "FocusTests/FocusModeTests.swift",
        "cases": [
          { "name": "testCreateFocusMode", "verifies": "Model creation with all required fields" },
          { "name": "testFetchByName", "verifies": "Predicate-based querying" },
          { "name": "testUpdateName", "verifies": "Property updates persist" },
          { "name": "testDelete", "verifies": "Deletion removes from store" },
          { "name": "testEmptyNameRejected", "verifies": "Validation prevents empty names" },
          { "name": "testDuplicateNameRejected", "verifies": "Uniqueness enforcement" }
        ]
      }
    ]
  },
  "discoveredIssues": []
}
```

## When to Return to Orchestrator

- Xcode project structure doesn't exist yet or is broken (missing targets, misconfigured schemes)
- A dependency on another feature's implementation that doesn't exist yet
- Simulator runtime not available (tests can't run)
- Build errors in code from other features that block your work
- Ambiguous requirements that significantly affect implementation direction
- Need to modify Xcode project settings (adding targets, changing build settings) that could affect other features
