import SwiftUI
import SwiftData
import FocusCore

// MARK: - FocusTabView

/// The Focus tab, showing the focus mode profile list.
/// Injects dependencies from the environment.
struct FocusTabView: View {
    @Environment(\.modelContext) private var modelContext

    /// Shield service injected from parent.
    var shieldService: ShieldServiceProtocol = MockShieldService()
    /// Monitoring service injected from parent.
    var monitoringService: MonitoringServiceProtocol = MockMonitoringService()

    var body: some View {
        NavigationStack {
            FocusTabContentView(
                modelContext: modelContext,
                shieldService: shieldService,
                monitoringService: monitoringService
            )
            .navigationTitle("Focus")
        }
        .accessibilityIdentifier("FocusTabContent")
    }
}

// MARK: - FocusTabContentView

/// Inner content view that creates the service and view model eagerly.
struct FocusTabContentView: View {
    let service: FocusModeService
    @State var viewModel: FocusModeListViewModel

    init(
        modelContext: ModelContext,
        shieldService: ShieldServiceProtocol,
        monitoringService: MonitoringServiceProtocol
    ) {
        let svc = FocusModeService(
            modelContext: modelContext,
            shieldService: shieldService,
            monitoringService: monitoringService
        )
        self.service = svc
        self._viewModel = State(initialValue: FocusModeListViewModel(service: svc))
    }

    var body: some View {
        FocusModeListView(viewModel: viewModel, service: service)
    }
}
