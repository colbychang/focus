import Testing
import SwiftData
@testable import FocusCore
@testable import Focus

// MARK: - DependencyContainer Tests

@Suite("DependencyContainer Tests")
struct DependencyContainerTests {

    @Test("Mock factory creates container with all mock services")
    func mockFactoryCreatesAllServices() {
        let container = DependencyContainer.mock()

        #expect(container.authorizationService is MockAuthorizationService)
        #expect(container.shieldService is MockShieldService)
        #expect(container.monitoringService is MockMonitoringService)
        #expect(container.liveActivityService is MockLiveActivityService)
    }

    @Test("Mock factory allows custom mock injection")
    func mockFactoryAcceptsCustomMocks() {
        let mockAuth = MockAuthorizationService(initialStatus: .approved)
        let container = DependencyContainer.mock(authorizationService: mockAuth)

        let auth = container.authorizationService as? MockAuthorizationService
        #expect(auth?.authorizationStatus == .approved)
    }

    @Test("Custom initialization with all services")
    func customInitialization() {
        let auth = MockAuthorizationService(initialStatus: .denied)
        let shield = MockShieldService()
        let monitoring = MockMonitoringService()
        let liveActivity = MockLiveActivityService()
        let sharedState = SharedStateService()

        let container = DependencyContainer(
            authorizationService: auth,
            shieldService: shield,
            monitoringService: monitoring,
            liveActivityService: liveActivity,
            sharedStateService: sharedState
        )

        #expect(container.authorizationService is MockAuthorizationService)
        let resolvedAuth = container.authorizationService as? MockAuthorizationService
        #expect(resolvedAuth?.authorizationStatus == .denied)
    }
}

// MARK: - AuthorizationViewModel Tests

@Suite("AuthorizationViewModel Tests")
struct AuthorizationViewModelTests {

    @Test("Initial status reflects service status — notDetermined")
    @MainActor
    func initialStatusNotDetermined() {
        let mockAuth = MockAuthorizationService(initialStatus: .notDetermined)
        let viewModel = AuthorizationViewModel(authorizationService: mockAuth)

        #expect(viewModel.authorizationStatus == .notDetermined)
        #expect(viewModel.isRequesting == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Initial status reflects service status — approved")
    @MainActor
    func initialStatusApproved() {
        let mockAuth = MockAuthorizationService(initialStatus: .approved)
        let viewModel = AuthorizationViewModel(authorizationService: mockAuth)

        #expect(viewModel.authorizationStatus == .approved)
    }

    @Test("Request authorization — approve path")
    @MainActor
    func requestAuthorizationApprove() async {
        let mockAuth = MockAuthorizationService(
            initialStatus: .notDetermined,
            shouldApprove: true
        )
        let viewModel = AuthorizationViewModel(authorizationService: mockAuth)

        await viewModel.requestAuthorization()

        #expect(viewModel.authorizationStatus == .approved)
        #expect(viewModel.isRequesting == false)
        #expect(viewModel.errorMessage == nil)
        #expect(mockAuth.requestAuthorizationCallCount == 1)
    }

    @Test("Request authorization — deny path")
    @MainActor
    func requestAuthorizationDeny() async {
        let mockAuth = MockAuthorizationService(
            initialStatus: .notDetermined,
            shouldApprove: false
        )
        let viewModel = AuthorizationViewModel(authorizationService: mockAuth)

        await viewModel.requestAuthorization()

        #expect(viewModel.authorizationStatus == .denied)
        #expect(viewModel.isRequesting == false)
        #expect(viewModel.errorMessage == nil)
        #expect(mockAuth.requestAuthorizationCallCount == 1)
    }

    @Test("Request authorization — error path")
    @MainActor
    func requestAuthorizationError() async {
        let mockAuth = MockAuthorizationService(
            initialStatus: .notDetermined,
            shouldApprove: nil
        )
        let viewModel = AuthorizationViewModel(authorizationService: mockAuth)

        await viewModel.requestAuthorization()

        #expect(viewModel.isRequesting == false)
        #expect(viewModel.errorMessage != nil)
        #expect(mockAuth.requestAuthorizationCallCount == 1)
    }

    @Test("Refresh status updates from service")
    @MainActor
    func refreshStatus() async {
        let mockAuth = MockAuthorizationService(
            initialStatus: .notDetermined,
            shouldApprove: true
        )
        let viewModel = AuthorizationViewModel(authorizationService: mockAuth)

        // Simulate approval externally
        try? await mockAuth.requestAuthorization()

        // ViewModel should still be notDetermined until refresh
        #expect(viewModel.authorizationStatus == .notDetermined)

        viewModel.refreshStatus()

        #expect(viewModel.authorizationStatus == .approved)
    }

    @Test("Multiple authorization requests increment call count")
    @MainActor
    func multipleRequests() async {
        let mockAuth = MockAuthorizationService(
            initialStatus: .notDetermined,
            shouldApprove: false
        )
        let viewModel = AuthorizationViewModel(authorizationService: mockAuth)

        await viewModel.requestAuthorization()
        #expect(viewModel.authorizationStatus == .denied)

        // Change behavior for retry
        mockAuth.shouldApprove = true
        await viewModel.requestAuthorization()

        #expect(viewModel.authorizationStatus == .approved)
        #expect(mockAuth.requestAuthorizationCallCount == 2)
    }
}

// MARK: - ModelContainer Tests

@Suite("ModelContainer Setup Tests")
struct ModelContainerSetupTests {

    @Test("ModelContainer initializes with all 4 model types")
    func modelContainerInitialization() throws {
        let schema = Schema(AppSchemaV1.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: AppMigrationPlan.self,
            configurations: config
        )

        let context = ModelContext(container)

        // Verify we can insert all 4 model types
        let focusMode = FocusMode(name: "Test Mode")
        context.insert(focusMode)

        let session = DeepFocusSession()
        context.insert(session)

        let entry = ScreenTimeEntry()
        context.insert(entry)

        let group = BlockedAppGroup(name: "Test Group")
        context.insert(group)

        try context.save()

        // Fetch and verify
        let focusModes = try context.fetch(FetchDescriptor<FocusMode>())
        #expect(focusModes.count == 1)

        let sessions = try context.fetch(FetchDescriptor<DeepFocusSession>())
        #expect(sessions.count == 1)

        let entries = try context.fetch(FetchDescriptor<ScreenTimeEntry>())
        #expect(entries.count == 1)

        let groups = try context.fetch(FetchDescriptor<BlockedAppGroup>())
        #expect(groups.count == 1)
    }
}
