import Testing
import Foundation
@testable import FocusCore

// MARK: - AllowedAppsConfig Tests

@Suite("AllowedAppsConfig Tests")
struct AllowedAppsConfigTests {

    // MARK: - Helpers

    private func makeApp(name: String, category: AppCategory = .other) -> AllowedApp {
        AllowedApp(
            tokenData: name.data(using: .utf8)!,
            displayName: name,
            category: category
        )
    }

    // MARK: - Initialization

    @Test("Empty config has no apps")
    func emptyConfig() {
        let config = AllowedAppsConfig()
        #expect(config.isEmpty)
        #expect(config.count == 0)
        #expect(config.apps.isEmpty)
        #expect(config.allTokenData.isEmpty)
    }

    @Test("Config with apps initializes correctly")
    func configWithApps() {
        let apps = [
            makeApp(name: "Messages", category: .communication),
            makeApp(name: "Slack", category: .work)
        ]
        let config = AllowedAppsConfig(apps: apps)
        #expect(config.count == 2)
        #expect(!config.isEmpty)
    }

    // MARK: - Adding Apps

    @Test("Add app increases count")
    func addApp() {
        var config = AllowedAppsConfig()
        config.addApp(makeApp(name: "Messages"))
        #expect(config.count == 1)
    }

    @Test("Adding duplicate app is no-op")
    func addDuplicateApp() {
        var config = AllowedAppsConfig()
        let app = makeApp(name: "Messages")
        config.addApp(app)
        config.addApp(app)
        #expect(config.count == 1)
    }

    @Test("Adding different apps increases count")
    func addDifferentApps() {
        var config = AllowedAppsConfig()
        config.addApp(makeApp(name: "Messages"))
        config.addApp(makeApp(name: "Slack"))
        #expect(config.count == 2)
    }

    // MARK: - Removing Apps

    @Test("Remove app decreases count")
    func removeApp() {
        var config = AllowedAppsConfig()
        let app = makeApp(name: "Messages")
        config.addApp(app)
        config.removeApp(withTokenData: app.tokenData)
        #expect(config.count == 0)
        #expect(config.isEmpty)
    }

    @Test("Remove non-existent app is no-op")
    func removeNonExistentApp() {
        var config = AllowedAppsConfig()
        config.addApp(makeApp(name: "Messages"))
        config.removeApp(withTokenData: "NonExistent".data(using: .utf8)!)
        #expect(config.count == 1)
    }

    // MARK: - Token Data

    @Test("allTokenData returns all token data")
    func allTokenData() {
        let config = AllowedAppsConfig(apps: [
            makeApp(name: "Messages"),
            makeApp(name: "Slack")
        ])
        #expect(config.allTokenData.count == 2)
        #expect(config.allTokenData.contains("Messages".data(using: .utf8)!))
        #expect(config.allTokenData.contains("Slack".data(using: .utf8)!))
    }

    // MARK: - Serialization

    @Test("Config serializes and deserializes correctly")
    func serialization() {
        let original = AllowedAppsConfig(apps: [
            makeApp(name: "Messages", category: .communication),
            makeApp(name: "Slack", category: .work),
            makeApp(name: "Spotify", category: .music)
        ])

        let data = original.serialize()
        #expect(data != nil)

        let decoded = AllowedAppsConfig.deserialize(from: data!)
        #expect(decoded != nil)
        #expect(decoded == original)
    }

    @Test("Deserialize from invalid data returns nil")
    func deserializeInvalid() {
        let badData = "not json".data(using: .utf8)!
        let result = AllowedAppsConfig.deserialize(from: badData)
        #expect(result == nil)
    }

    @Test("Empty config serializes and deserializes")
    func emptyConfigSerialization() {
        let original = AllowedAppsConfig()
        let data = original.serialize()
        #expect(data != nil)
        let decoded = AllowedAppsConfig.deserialize(from: data!)
        #expect(decoded != nil)
        #expect(decoded!.isEmpty)
    }
}

// MARK: - AppCategoryGrouper Tests

@Suite("AppCategoryGrouper Tests")
struct AppCategoryGrouperTests {

    // MARK: - Helpers

    private func makeApp(name: String, category: AppCategory) -> AllowedApp {
        AllowedApp(
            tokenData: name.data(using: .utf8)!,
            displayName: name,
            category: category
        )
    }

    // MARK: - Grouping

    @Test("Groups apps into correct categories")
    func groupsByCategory() {
        let config = AllowedAppsConfig(apps: [
            makeApp(name: "Messages", category: .communication),
            makeApp(name: "Slack", category: .work),
            makeApp(name: "Spotify", category: .music),
            makeApp(name: "Calculator", category: .other)
        ])

        let groups = AppCategoryGrouper.group(config: config)

        #expect(groups.count == 4)
        #expect(groups[0].category == .communication)
        #expect(groups[0].apps.count == 1)
        #expect(groups[0].apps[0].displayName == "Messages")

        #expect(groups[1].category == .work)
        #expect(groups[1].apps.count == 1)

        #expect(groups[2].category == .music)
        #expect(groups[2].apps.count == 1)

        #expect(groups[3].category == .other)
        #expect(groups[3].apps.count == 1)
    }

    @Test("Empty categories are excluded")
    func emptyCategories() {
        let config = AllowedAppsConfig(apps: [
            makeApp(name: "Messages", category: .communication),
            makeApp(name: "Calculator", category: .other)
        ])

        let groups = AppCategoryGrouper.group(config: config)

        #expect(groups.count == 2)
        #expect(groups[0].category == .communication)
        #expect(groups[1].category == .other)
    }

    @Test("Apps sorted alphabetically within category")
    func sortedWithinCategory() {
        let config = AllowedAppsConfig(apps: [
            makeApp(name: "Zoom", category: .work),
            makeApp(name: "Slack", category: .work),
            makeApp(name: "Asana", category: .work)
        ])

        let groups = AppCategoryGrouper.group(config: config)

        #expect(groups.count == 1)
        #expect(groups[0].apps[0].displayName == "Asana")
        #expect(groups[0].apps[1].displayName == "Slack")
        #expect(groups[0].apps[2].displayName == "Zoom")
    }

    @Test("Categories appear in standard order")
    func standardOrder() {
        let config = AllowedAppsConfig(apps: [
            makeApp(name: "Calculator", category: .other),
            makeApp(name: "Spotify", category: .music),
            makeApp(name: "Messages", category: .communication),
            makeApp(name: "Slack", category: .work)
        ])

        let groups = AppCategoryGrouper.group(config: config)

        #expect(groups.count == 4)
        #expect(groups[0].category == .communication)
        #expect(groups[1].category == .work)
        #expect(groups[2].category == .music)
        #expect(groups[3].category == .other)
    }

    @Test("Multiple apps in same category grouped together")
    func multipleAppsInCategory() {
        let config = AllowedAppsConfig(apps: [
            makeApp(name: "Messages", category: .communication),
            makeApp(name: "FaceTime", category: .communication),
            makeApp(name: "WhatsApp", category: .communication)
        ])

        let groups = AppCategoryGrouper.group(config: config)

        #expect(groups.count == 1)
        #expect(groups[0].category == .communication)
        #expect(groups[0].apps.count == 3)
    }

    @Test("Empty config returns empty groups")
    func emptyConfig() {
        let config = AllowedAppsConfig()
        let groups = AppCategoryGrouper.group(config: config)
        #expect(groups.isEmpty)
    }

    @Test("Group from serialized data works")
    func groupFromSerializedData() {
        let config = AllowedAppsConfig(apps: [
            makeApp(name: "Messages", category: .communication),
            makeApp(name: "Slack", category: .work)
        ])

        let data = config.serialize()
        let groups = AppCategoryGrouper.group(fromSerializedData: data)

        #expect(groups.count == 2)
    }

    @Test("Group from nil data returns empty")
    func groupFromNilData() {
        let groups = AppCategoryGrouper.group(fromSerializedData: nil)
        #expect(groups.isEmpty)
    }

    @Test("Group from invalid data returns empty")
    func groupFromInvalidData() {
        let groups = AppCategoryGrouper.group(fromSerializedData: "bad".data(using: .utf8))
        #expect(groups.isEmpty)
    }

    @Test("CategoryGroup isEmpty reflects its apps")
    func categoryGroupIsEmpty() {
        let emptyGroup = CategoryGroup(category: .work, apps: [])
        #expect(emptyGroup.isEmpty)

        let nonEmptyGroup = CategoryGroup(
            category: .work,
            apps: [AllowedApp(tokenData: Data(), displayName: "Test")]
        )
        #expect(!nonEmptyGroup.isEmpty)
    }
}

// MARK: - DeepFocusBlockingService Tests

@Suite("DeepFocusBlockingService Tests")
struct DeepFocusBlockingServiceTests {

    // MARK: - Helpers

    private func makeService() -> (DeepFocusBlockingService, MockShieldService) {
        let mockShield = MockShieldService()
        let service = DeepFocusBlockingService(shieldService: mockShield)
        return (service, mockShield)
    }

    // MARK: - Apply Blocking

    @Test("Apply blocking calls applyShields with correct store name")
    func applyBlockingStoreName() {
        let (service, mock) = makeService()

        service.applyBlocking(allowedTokens: nil)

        #expect(mock.applyShieldsCalls.count == 1)
        #expect(mock.applyShieldsCalls[0].storeName == "deep_focus")
    }

    @Test("Apply blocking sets all three dimensions")
    func applyBlockingAllDimensions() {
        let (service, mock) = makeService()
        let tokens: Set<Data> = [Data([1, 2, 3]), Data([4, 5, 6])]

        service.applyBlocking(allowedTokens: tokens)

        #expect(mock.applyShieldsCalls.count == 1)
        let call = mock.applyShieldsCalls[0]
        // All three dimensions should be set with the allowed tokens as exceptions
        #expect(call.applications == tokens)
        #expect(call.categories == tokens)
        #expect(call.webDomains == tokens)
    }

    @Test("Apply blocking with nil tokens blocks everything")
    func applyBlockingNilTokens() {
        let (service, mock) = makeService()

        service.applyBlocking(allowedTokens: nil)

        #expect(mock.applyShieldsCalls.count == 1)
        let call = mock.applyShieldsCalls[0]
        #expect(call.applications == nil)
        #expect(call.categories == nil)
        #expect(call.webDomains == nil)
    }

    @Test("Apply blocking sets isBlocking to true")
    func applyBlockingUpdatesState() {
        let (service, _) = makeService()

        #expect(service.isBlocking == false)
        service.applyBlocking(allowedTokens: nil)
        #expect(service.isBlocking == true)
    }

    @Test("Apply blocking stores current allowed tokens")
    func applyBlockingStoresTokens() {
        let (service, _) = makeService()
        let tokens: Set<Data> = [Data([1, 2, 3])]

        service.applyBlocking(allowedTokens: tokens)

        #expect(service.currentAllowedTokens == tokens)
    }

    // MARK: - Clear Blocking

    @Test("Clear blocking calls clearShields with correct store name")
    func clearBlockingStoreName() {
        let (service, mock) = makeService()

        service.applyBlocking(allowedTokens: nil)
        service.clearBlocking()

        #expect(mock.clearShieldsCalls.count == 1)
        #expect(mock.clearShieldsCalls[0] == "deep_focus")
    }

    @Test("Clear blocking sets isBlocking to false")
    func clearBlockingUpdatesState() {
        let (service, _) = makeService()

        service.applyBlocking(allowedTokens: nil)
        #expect(service.isBlocking == true)

        service.clearBlocking()
        #expect(service.isBlocking == false)
    }

    @Test("Clear blocking clears stored tokens")
    func clearBlockingClearsTokens() {
        let (service, _) = makeService()
        let tokens: Set<Data> = [Data([1, 2, 3])]

        service.applyBlocking(allowedTokens: tokens)
        #expect(service.currentAllowedTokens != nil)

        service.clearBlocking()
        #expect(service.currentAllowedTokens == nil)
    }

    // MARK: - Reapply Blocking

    @Test("Reapply blocking uses stored tokens")
    func reapplyBlockingUsesStoredTokens() {
        let (service, mock) = makeService()
        let tokens: Set<Data> = [Data([1, 2, 3])]

        service.applyBlocking(allowedTokens: tokens)
        mock.reset()

        service.reapplyBlocking()

        #expect(mock.applyShieldsCalls.count == 1)
        #expect(mock.applyShieldsCalls[0].applications == tokens)
        #expect(mock.applyShieldsCalls[0].categories == tokens)
        #expect(mock.applyShieldsCalls[0].webDomains == tokens)
    }

    @Test("Reapply with no stored tokens applies full blocking")
    func reapplyWithNoTokens() {
        let (service, mock) = makeService()

        // Don't apply first — no stored tokens
        service.reapplyBlocking()

        #expect(mock.applyShieldsCalls.count == 1)
        #expect(mock.applyShieldsCalls[0].applications == nil)
    }

    // MARK: - Session Lifecycle

    @Test("Full session lifecycle: apply on start, clear on end")
    func fullSessionLifecycle() {
        let (service, mock) = makeService()
        let tokens: Set<Data> = [Data([1, 2, 3]), Data([4, 5, 6])]

        // Session start: apply blocking
        service.applyBlocking(allowedTokens: tokens)
        #expect(service.isBlocking == true)
        #expect(mock.applyShieldsCalls.count == 1)

        // Session end: clear blocking
        service.clearBlocking()
        #expect(service.isBlocking == false)
        #expect(mock.clearShieldsCalls.count == 1)
    }

    @Test("Blocking uses independent store from focus modes")
    func independentStoreName() {
        #expect(DeepFocusBlockingService.storeName == "deep_focus")
        // Focus mode stores use profile UUIDs, so "deep_focus" never conflicts
    }

    @Test("Apply blocking called on session start sets applicationCategories")
    func applicationCategoriesSetOnStart() {
        let (service, mock) = makeService()
        let tokens: Set<Data> = [Data([10, 20])]

        service.applyBlocking(allowedTokens: tokens)

        let call = mock.applyShieldsCalls[0]
        // VAL-DEEP-003: Both applicationCategories and webDomainCategories are set
        #expect(call.categories == tokens)
        #expect(call.webDomains == tokens)
        #expect(call.applications == tokens)
    }

    @Test("Clear blocking called on session end via clearAllSettings")
    func clearAllSettingsOnEnd() {
        let (service, mock) = makeService()

        service.applyBlocking(allowedTokens: Set<Data>([Data([1])]))
        service.clearBlocking()

        // Verify clearShields was called (maps to clearAllSettings on the real store)
        #expect(mock.clearShieldsCalls.count == 1)
        #expect(mock.clearShieldsCalls[0] == DeepFocusBlockingService.storeName)
    }
}

// MARK: - AppCategory Tests

@Suite("AppCategory Tests")
struct AppCategoryTests {

    @Test("All categories have display names")
    func displayNames() {
        for category in AppCategory.allCases {
            #expect(!category.displayName.isEmpty)
        }
    }

    @Test("All categories have icon names")
    func iconNames() {
        for category in AppCategory.allCases {
            #expect(!category.iconName.isEmpty)
        }
    }

    @Test("Categories have expected raw values")
    func rawValues() {
        #expect(AppCategory.communication.rawValue == "Communication")
        #expect(AppCategory.work.rawValue == "Work")
        #expect(AppCategory.music.rawValue == "Music")
        #expect(AppCategory.other.rawValue == "Other")
    }

    @Test("Category order is Communication, Work, Music, Other")
    func categoryOrder() {
        let allCases = AppCategory.allCases
        #expect(allCases[0] == .communication)
        #expect(allCases[1] == .work)
        #expect(allCases[2] == .music)
        #expect(allCases[3] == .other)
    }
}
