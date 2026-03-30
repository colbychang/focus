# ActivityKit & SwiftData Technical Reference (iOS 17+, 2025-2026)

## Table of Contents
1. [ActivityKit (Live Activities & Dynamic Island)](#activitykit)
2. [SwiftData](#swiftdata)

---

# ActivityKit

## Overview
ActivityKit is Apple's framework for creating **Live Activities** — real-time, glanceable UI that appears on the Lock Screen, Dynamic Island, StandBy, CarPlay, and paired Apple Watch/Mac. Introduced in iOS 16.1, significantly expanded in iOS 17+.

**Framework import:** `import ActivityKit`

Live Activities live inside a **Widget Extension** target (not the main app target). The main app starts/updates/ends activities via ActivityKit APIs, while the widget extension provides the SwiftUI views.

---

## 1. Defining Activity Attributes and Content State

Every Live Activity requires a data model conforming to `ActivityAttributes`:

```swift
import ActivityKit

struct DeliveryAttributes: ActivityAttributes {
    
    // ContentState: Dynamic data that changes over the activity's lifetime
    public struct ContentState: Codable, Hashable {
        var currentStatus: String
        var estimatedArrival: Date
        var progress: Double
    }
    
    // Static data: Set once when activity starts, never changes
    var orderNumber: String
    var restaurantName: String
}
```

**Key rules:**
- `ContentState` must conform to `Codable` and `Hashable`
- Static properties (outside `ContentState`) are set at creation and cannot change
- Dynamic properties (inside `ContentState`) are updated via `update()` calls
- The entire `ActivityAttributes` struct must be shared between the app target and widget target (use shared file with both targets selected)
- Total data payload for `ContentState` must be under **4KB**

---

## 2. Starting a Live Activity

```swift
func startLiveActivity() {
    // 1. Check if Live Activities are supported & enabled
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        print("Live Activities not enabled")
        return
    }
    
    // 2. Create attributes (static data)
    let attributes = DeliveryAttributes(
        orderNumber: "ORD-12345",
        restaurantName: "Pizza Palace"
    )
    
    // 3. Create initial content state (dynamic data)
    let initialState = DeliveryAttributes.ContentState(
        currentStatus: "Order confirmed",
        estimatedArrival: Date().addingTimeInterval(1800),
        progress: 0.1
    )
    
    // 4. Request the activity
    do {
        let activity = try Activity.request(
            attributes: attributes,
            content: ActivityContent(state: initialState, staleDate: nil),
            pushType: nil  // Use .token for push notification updates
        )
        print("Live Activity started: \(activity.id)")
    } catch {
        print("Error starting Live Activity: \(error)")
    }
}
```

**Parameters:**
- `staleDate`: Optional `Date` after which the system considers the content stale
- `pushType`: Set to `.token` if you want to update via push notifications; `nil` for app-only updates

---

## 3. Updating a Live Activity

```swift
func updateLiveActivity(activity: Activity<DeliveryAttributes>) {
    let updatedState = DeliveryAttributes.ContentState(
        currentStatus: "Driver en route",
        estimatedArrival: Date().addingTimeInterval(900),
        progress: 0.6
    )
    
    Task {
        await activity.update(
            ActivityContent(state: updatedState, staleDate: nil)
        )
    }
}

// With alert configuration (shows notification-style alert)
func updateWithAlert(activity: Activity<DeliveryAttributes>) {
    let updatedState = DeliveryAttributes.ContentState(
        currentStatus: "Driver arriving!",
        estimatedArrival: Date().addingTimeInterval(60),
        progress: 0.95
    )
    
    let alertConfig = AlertConfiguration(
        title: "Almost there!",
        body: "Your delivery is arriving now.",
        sound: .default
    )
    
    Task {
        await activity.update(
            ActivityContent(state: updatedState, staleDate: nil),
            alertConfiguration: alertConfig
        )
    }
}
```

---

## 4. Ending a Live Activity

```swift
func endLiveActivity(activity: Activity<DeliveryAttributes>) {
    let finalState = DeliveryAttributes.ContentState(
        currentStatus: "Delivered!",
        estimatedArrival: Date(),
        progress: 1.0
    )
    
    Task {
        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .default
        )
    }
}
```

**Dismissal policies:**
- `.default` — System removes after ~4 hours or user dismisses
- `.immediate` — Removed instantly
- `.after(Date)` — Removed after a specific date (max 4 hours after ending)

---

## 5. Dynamic Island Layouts

The Dynamic Island has **three** presentation modes defined via `ActivityConfiguration`:

```swift
struct DeliveryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeliveryAttributes.self) { context in
            // LOCK SCREEN presentation (always required)
            LockScreenView(context: context)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // EXPANDED presentation (user long-presses the island)
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "box.truck")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.currentStatus)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.restaurantName)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress)
                }
            } compactLeading: {
                // COMPACT leading (small pill, left side)
                Image(systemName: "box.truck")
            } compactTrailing: {
                // COMPACT trailing (small pill, right side)
                Text("\(Int(context.state.progress * 100))%")
            } minimal: {
                // MINIMAL (when multiple activities compete, smallest form)
                Image(systemName: "box.truck")
            }
        }
    }
}
```

### Compact Presentation
- Shown when your app's Live Activity is the primary one on Dynamic Island
- Split into **leading** and **trailing** regions around the camera cutout
- Very limited space; use icons or short text

### Minimal Presentation
- Shown when another app's activity takes priority
- Appears as a small detached circle on the opposite side of the island
- Extremely limited space; typically a single icon or small circular indicator

### Expanded Presentation
- Shown when user **long-presses** the Dynamic Island
- Has four regions: `.leading`, `.trailing`, `.center`, `.bottom`
- Most space available; can include progress bars, detailed text, buttons

---

## 6. Timer/Countdown Support

Live Activities support **real-time countdown timers** using SwiftUI's `Text` view with `timerInterval`:

```swift
// Countdown timer that updates every second WITHOUT needing activity updates
Text(timerInterval: context.state.estimatedArrival...Date(), countsDown: true)
    .font(.headline)
    .monospacedDigit()
```

This is the **recommended** approach for showing time-based information because:
- The timer updates in real-time on the device without needing ActivityKit update calls
- It doesn't consume your limited update budget
- It works even when the app is in the background

You can also use `Date` range formatting:
```swift
Text(Date.now...context.state.estimatedArrival)
```

---

## 7. Limitations

### Max Active Activities
- **~5 simultaneous** Live Activities per app (system-enforced, not formally documented)
- The system may limit this further based on memory pressure
- Across all apps, a reasonable number can coexist

### Update Frequency
- **iOS 17:** Up to once per second was possible for in-app updates
- **iOS 18+:** Apple throttled updates — practical limit is **every 5-15 seconds** for push-based updates
- In-app updates when the app is in the foreground are less restricted
- Use `Text(timerInterval:)` for real-time countdowns instead of frequent updates

### Duration Limits
- A Live Activity can run for up to **8 hours** (system may end it after that)
- After ending, it remains visible on Lock Screen for up to **4 hours** before auto-dismissal
- Stale activities may be dimmed or removed by the system

### Push Notification Updates
- Require Apple Push Notification service (APNs) with `pushType: .token`
- Push payload must be under **4KB**
- Use `Activity.pushTokenUpdates` to observe push token changes
- Push updates are subject to system throttling (budget-based)

### Other Constraints
- Live Activities **cannot** access the network, GPS, or other system services
- No access to `HealthKit`, `CoreLocation`, cameras, or microphone
- Animations are limited (basic SwiftUI transitions only)
- Interactive buttons are supported (via `Button` with App Intents in iOS 17+)

---

## 8. Required Info.plist & Entitlements

### Info.plist (Main App Target)
Add the following key to your app's `Info.plist`:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

Or in Xcode: Go to app target → Info tab → add "Supports Live Activities" = YES

### For Push-Based Updates
Also add:
```xml
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
```

### Widget Extension
- The Widget Extension target must include the `ActivityConfiguration` in its `WidgetBundle`
- If you have existing widgets, use `WidgetBundle` to declare both:

```swift
@main
struct MyWidgetBundle: WidgetBundle {
    var body: some Widget {
        MyRegularWidget()
        DeliveryLiveActivity()
    }
}
```

### Entitlements
- No special entitlements are required beyond the standard widget/app entitlements
- Push notifications require the standard APN entitlement (`aps-environment`)

---

# SwiftData

## Overview
SwiftData is Apple's modern, Swift-native persistence framework introduced at WWDC 2023 (iOS 17+). It replaces/wraps Core Data with a declarative, macro-based API that integrates natively with SwiftUI and Swift concurrency.

**Framework import:** `import SwiftData`

---

## 1. Model Definition with @Model Macro

```swift
import SwiftData

@Model
final class ScreenTimeEntry {
    var date: Date
    var appName: String
    var duration: TimeInterval  // seconds
    var category: String?
    
    // Computed properties are NOT persisted
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    init(date: Date, appName: String, duration: TimeInterval, category: String? = nil) {
        self.date = date
        self.appName = appName
        self.duration = duration
        self.category = category
    }
}
```

**Supported property types:**
- Basic types: `String`, `Int`, `Double`, `Float`, `Bool`, `Date`, `Data`, `UUID`, `URL`
- Optional versions of all the above
- Collections: `Array` of supported types
- `Codable` structs/enums (stored as transformable)
- Relationships to other `@Model` types

**Property wrappers / macros:**
- `@Attribute(.unique)` — Enforces uniqueness (upsert behavior)
- `@Attribute(.externalStorage)` — Stores large data externally (e.g., images)
- `@Attribute(.spotlight)` — Indexes for Spotlight search
- `@Attribute(.encrypt)` — Encrypts the attribute (iOS 18+)
- `@Attribute(originalName: "oldName")` — Maps to a previous property name (for migrations)
- `@Transient` — Property is NOT persisted

---

## 2. Relationships and Cascading Deletes

### One-to-Many Relationship
```swift
@Model
final class User {
    var name: String
    
    // One user has many sessions; deleting user deletes all sessions
    @Relationship(deleteRule: .cascade, inverse: \ScreenTimeSession.user)
    var sessions: [ScreenTimeSession]
    
    init(name: String, sessions: [ScreenTimeSession] = []) {
        self.name = name
        self.sessions = sessions
    }
}

@Model
final class ScreenTimeSession {
    var date: Date
    var totalDuration: TimeInterval
    var user: User  // Non-optional when inverse is specified
    
    init(date: Date, totalDuration: TimeInterval, user: User) {
        self.date = date
        self.totalDuration = totalDuration
        self.user = user
    }
}
```

### Delete Rules
- `.nullify` (default) — Sets the relationship to `nil`; related objects remain
- `.cascade` — Deletes all related objects (and cascades further if those also have `.cascade`)
- `.deny` — Prevents deletion if related objects exist
- `.noAction` — Does nothing (can leave orphaned references)

### Many-to-Many
```swift
@Model
final class App {
    var name: String
    var categories: [Category]
    
    init(name: String, categories: [Category] = []) {
        self.name = name
        self.categories = categories
    }
}

@Model
final class Category {
    var name: String
    var apps: [App]
    
    init(name: String, apps: [App] = []) {
        self.name = name
        self.apps = apps
    }
}
```

### Gotcha: Cascade Deletes
- Cascade deletes in SwiftData can sometimes crash if the deletion triggers access to already-freed objects during UI observation
- Workaround: Delete in a background context or ensure UI is not observing the deleted objects during deletion
- Always test cascade delete chains thoroughly

---

## 3. ModelContainer and ModelContext

### ModelContainer
The container manages the database schema, storage location, and configuration:

```swift
// Simple setup (in-memory or on-disk)
let container = try ModelContainer(for: User.self, ScreenTimeSession.self)

// With configuration
let config = ModelConfiguration(
    "MyStore",
    schema: Schema([User.self, ScreenTimeSession.self]),
    isStoredInMemoryOnly: false,
    allowsSave: true,
    groupContainer: .identifier("group.com.myapp.shared") // For app groups
)
let container = try ModelContainer(
    for: User.self, ScreenTimeSession.self,
    configurations: config
)
```

### SwiftUI Integration
```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [User.self, ScreenTimeSession.self])
    }
}
```

### ModelContext
The context is your interface for CRUD operations:

```swift
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScreenTimeSession.date, order: .reverse) var sessions: [ScreenTimeSession]
    
    var body: some View {
        List(sessions) { session in
            Text(session.date.formatted())
        }
    }
    
    func addSession() {
        let session = ScreenTimeSession(date: .now, totalDuration: 3600, user: currentUser)
        modelContext.insert(session)
        // Auto-saves by default; explicit save:
        // try? modelContext.save()
    }
    
    func deleteSession(_ session: ScreenTimeSession) {
        modelContext.delete(session)
    }
}
```

### Background Context
```swift
let container = try ModelContainer(for: User.self)
let backgroundContext = ModelContext(container)

// Perform work on background
Task.detached {
    let context = ModelContext(container)
    // ... do heavy work
    try context.save()
}
```

**Important:** `ModelContext` is **NOT** Sendable. Each context must be used on the thread/actor it was created on. Use `@ModelActor` for background work:

```swift
@ModelActor
actor DataManager {
    func importData(_ entries: [RawEntry]) throws {
        for entry in entries {
            let model = ScreenTimeEntry(date: entry.date, appName: entry.app, duration: entry.duration)
            modelContext.insert(model)
        }
        try modelContext.save()
    }
}
```

---

## 4. CloudKit Sync Setup

SwiftData syncs automatically with CloudKit when configured correctly.

### Requirements
1. **Apple Developer Program membership** (required for CloudKit)
2. **iCloud capability** enabled in Xcode (with CloudKit checked)
3. **Background Modes** capability with "Remote notifications" enabled
4. A **CloudKit container** identifier (e.g., `iCloud.com.yourapp.data`)

### Xcode Setup
1. Select your app target → Signing & Capabilities
2. Add **iCloud** capability → Check **CloudKit** → Add your container
3. Add **Background Modes** → Check **Remote notifications**

### Code Setup
```swift
// CloudKit sync is AUTOMATIC when you use the default ModelContainer
// Just ensure iCloud + CloudKit capabilities are configured
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [User.self, ScreenTimeSession.self])
    }
}
```

### CloudKit Schema Constraints
For CloudKit compatibility, your models must follow these rules:
- **All properties must be optional OR have default values** (CloudKit requires this)
- **No unique constraints** (`@Attribute(.unique)` is incompatible with CloudKit)
- **Relationships must be optional** on at least one side
- **No ordered relationships** (CloudKit doesn't support ordered sets)
- **Model names and property names** automatically become CloudKit record types and fields

### Monitoring Sync Events
```swift
// Use NSPersistentCloudKitContainer events (from CoreData interop)
NotificationCenter.default.addObserver(
    forName: NSPersistentCloudKitContainer.eventChangedNotification,
    object: nil,
    queue: .main
) { notification in
    if let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationKey] 
        as? NSPersistentCloudKitContainer.Event {
        print("CloudKit event: \(event.type), succeeded: \(event.succeeded)")
    }
}
```

### Known CloudKit Sync Issues
- Sync does **NOT** happen in real-time; it's eventually consistent
- Remote notifications only trigger sync on scene phase changes (foreground/background transitions)
- Large initial syncs can be slow
- Conflict resolution defaults to "last writer wins" — no custom merge policies
- Debugging sync issues requires checking CloudKit Dashboard

---

## 5. Migration Strategies

### VersionedSchema
Always define your models inside versioned schemas from the start:

```swift
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [ScreenTimeEntry.self]
    
    @Model
    final class ScreenTimeEntry {
        var date: Date
        var appName: String
        var duration: TimeInterval
        
        init(date: Date, appName: String, duration: TimeInterval) {
            self.date = date
            self.appName = appName
            self.duration = duration
        }
    }
}

enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] = [ScreenTimeEntry.self]
    
    @Model
    final class ScreenTimeEntry {
        var date: Date
        var appName: String
        var duration: TimeInterval
        var category: String?  // NEW optional field
        
        init(date: Date, appName: String, duration: TimeInterval, category: String? = nil) {
            self.date = date
            self.appName = appName
            self.duration = duration
            self.category = category
        }
    }
}

// Use typealias for the "current" model
typealias ScreenTimeEntry = AppSchemaV2.ScreenTimeEntry
```

### SchemaMigrationPlan

```swift
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [
        AppSchemaV1.self,
        AppSchemaV2.self
    ]
    
    static var stages: [MigrationStage] = [migrateV1toV2]
    
    // Lightweight migration (adding optional field)
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: AppSchemaV1.self,
        toVersion: AppSchemaV2.self
    )
}

// Wire up the migration plan
let container = try ModelContainer(
    for: ScreenTimeEntry.self,
    migrationPlan: AppMigrationPlan.self
)
```

### Lightweight vs Custom Migrations

**Lightweight (automatic):**
- Adding optional properties
- Removing properties
- Making a property optional (non-optional → optional)
- Renaming with `@Attribute(originalName:)`

**Custom (manual) — requires `MigrationStage.custom`:**
- Adding non-optional properties without defaults
- Changing property types
- Merging/splitting entities
- Data transformations (dedup, normalization)
- Any change where SwiftData can't infer the mapping

```swift
static let migrateV1toV2 = MigrationStage.custom(
    fromVersion: AppSchemaV1.self,
    toVersion: AppSchemaV2.self,
    willMigrate: { context in
        // Runs BEFORE schema change; access OLD model types
        // Good for: deduplication, cleanup
    },
    didMigrate: { context in
        // Runs AFTER schema change; access NEW model types
        // Good for: assigning default values, populating new fields
        let entries = try context.fetch(FetchDescriptor<AppSchemaV2.ScreenTimeEntry>())
        for entry in entries {
            entry.category = "Uncategorized"
        }
        try context.save()
    }
)
```

### Bridge Version Strategy (Complex Migrations)
When you need to reshape data (e.g., extract fields into a new model):
1. **V2 (bridge):** Keep old fields with `@Attribute(originalName:)`, add new relationship
2. **V3 (cleanup):** Remove legacy fields after data is migrated

---

## 6. Performance Considerations for Large Datasets

### Potential Issues
- **Months of screen time data** (thousands of records) can cause performance issues
- SwiftUI `@Query` with large result sets triggers expensive UI updates
- Batch inserts (5,000+ records) can be very slow without optimization

### Best Practices

**Fetch in batches:**
```swift
var descriptor = FetchDescriptor<ScreenTimeEntry>(
    predicate: #Predicate { $0.date > startDate },
    sortBy: [SortDescriptor(\.date, order: .reverse)]
)
descriptor.fetchLimit = 100  // Paginate
descriptor.fetchOffset = currentPage * 100
```

**Use `@ModelActor` for background operations:**
```swift
@ModelActor
actor DataImporter {
    func importEntries(_ raw: [RawData]) throws {
        for batch in raw.chunked(into: 500) {
            for item in batch {
                let entry = ScreenTimeEntry(...)
                modelContext.insert(entry)
            }
            try modelContext.save()
        }
    }
}
```

**Avoid fetching entire object graphs:**
- Use `#Predicate` to filter at the database level
- Avoid loading relationships you don't need
- SwiftData lazily faults relationships, but accessing them in a list can cause N+1 queries

**Index frequently queried properties:**
```swift
@Model
final class ScreenTimeEntry {
    @Attribute(.indexed) var date: Date  // iOS 18+ only? check availability
    var appName: String
    // ...
}
```

**Aggregate on background threads:**
- Don't compute sums/averages in SwiftUI views
- Pre-compute daily/weekly summaries and store them

---

## 7. Known Limitations and Gotchas

### General SwiftData Issues
1. **Maturity:** As of 2025, SwiftData is still maturing. Community consensus is it works well for simple use cases but has rough edges at scale
2. **Observation limitations:** `@Query` is the ONLY way to observe database changes in SwiftUI; manual `ModelContext` observation is limited
3. **No partial updates:** Updating a single property re-faults the entire object
4. **Thread safety:** `ModelContext` is NOT Sendable; use `@ModelActor` for concurrent access
5. **No composite unique constraints:** Only single-property `@Attribute(.unique)` is supported
6. **Predicate limitations:** `#Predicate` doesn't support all Swift expressions; complex filtering may need to happen in memory
7. **No NSFetchedResultsController equivalent:** For UIKit apps, SwiftData integration is less mature

### CloudKit-Specific Gotchas
1. **No unique constraints with CloudKit** — `.unique` is incompatible
2. **All properties must be optional or have defaults** for CloudKit compatibility
3. **Sync is eventually consistent** — not real-time
4. **No custom conflict resolution** — last writer wins
5. **Sync debugging is difficult** — limited logging; use CloudKit Dashboard
6. **Initial sync of large datasets is slow**
7. **Cannot share private data between users** (need CloudKit sharing APIs separately)

### Performance Gotchas
1. **Large `@Query` results cause UI jank** — use `fetchLimit` and pagination
2. **Batch inserts are slow** — insert in chunks of 500, save between batches
3. **Cascade deletes can be slow** for large relationship trees
4. **Memory usage** — SwiftData keeps objects in memory aggressively; watch for memory warnings with large datasets
5. **Migration on large stores** can take significant time — test with realistic data volumes
6. **SwiftData wraps Core Data** — underlying SQLite performance characteristics apply

### Migration Gotchas
1. **Always use VersionedSchema from day one** — retrofitting is risky
2. **Test migrations with real on-disk data** — simulator data may differ
3. **Default values in Swift init ≠ database defaults** — a Swift default doesn't automatically backfill existing rows
4. **`willMigrate` uses OLD model types; `didMigrate` uses NEW model types** — don't mix them up
5. **Users can skip app versions** — migration plan must handle V1→V3 jumps (SwiftData chains stages automatically)

---

## Source References

### ActivityKit
- Apple Developer Documentation: [Displaying live data with Live Activities](https://developer.apple.com/documentation/ActivityKit/displaying-live-data-with-live-activities)
- Apple Developer Documentation: [ActivityKit](https://developer.apple.com/documentation/activitykit)
- Apple WWDC23: [Meet ActivityKit](https://developer.apple.com/videos/play/wwdc2023/10184/)
- Create with Swift: [Implementing Live Activities in a SwiftUI app](https://www.createwithswift.com/implementing-live-activities-in-a-swiftui-app/) (May 2025)
- Sparrow Code: [Live Activity & Dynamic Island Tutorial](https://sparrowcode.io/en/tutorials/live-activities)
- Canopas: [Integrating Live Activity and Dynamic Island in iOS](https://canopas.com/integrating-live-activity-and-dynamic-island-in-i-os-a-complete-guide) (Nov 2024)
- 9to5Mac: [Live Activities refresh frequency limits in iOS 18](https://9to5mac.com/2024/08/31/live-activities-ios-18/) (Aug 2024)
- AppCoda: [Developing Live Activities in SwiftUI Apps](https://www.appcoda.com/live-activities/) (Aug 2025)

### SwiftData
- Apple Developer Documentation: [SwiftData](https://developer.apple.com/documentation/swiftdata)
- Apple Developer Documentation: [Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- Donny Wals: [A Deep Dive into SwiftData migrations](https://www.donnywals.com/a-deep-dive-into-swiftdata-migrations/) (Jan 2026)
- Hacking with Swift: [How to create cascade deletes using relationships](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-cascade-deletes-using-relationships)
- Medium/Mushthak Ebrahim: [SwiftData at Scale: 7 Production Pitfalls](https://medium.com/@musmein/swiftdata-at-scale-7-production-pitfalls-that-break-real-apps-and) (Feb 2026)
- Jacob Bartlett: [High Performance SwiftData Apps](https://levelup.gitconnected.com/high-performance-swiftdata-apps-4ba2ddcd296b) (Aug 2025)
- Reddit r/SwiftUI: [How mature is SwiftData now?](https://www.reddit.com/r/SwiftUI/comments/1mo753v/how_mature_is_swiftdata_now/) (Aug 2025)
- AzamSharp: [If You Are Not Versioning Your SwiftData Schema](https://azamsharp.com/2026/02/14/if-you-are-not-versioning-your-swiftdata-schema) (Feb 2026)
