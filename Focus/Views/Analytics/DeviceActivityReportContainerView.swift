import SwiftUI
import DeviceActivity

// MARK: - DeviceActivityReportContainerView

/// Container view that embeds a DeviceActivityReport for Screen Time data.
/// The report content is system-rendered — this view only provides the container.
///
/// The DeviceActivityReport requires the DeviceActivityReportExtension to provide
/// the rendering context. Since the Family Controls entitlement is not yet available,
/// this serves as the integration point that will work once the entitlement is enabled.
struct DeviceActivityReportContainerView: View {
    /// The date range filter for the report.
    private let filter: DeviceActivityFilter

    init() {
        // Default to showing the past 7 days
        let now = Date()
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        self.filter = DeviceActivityFilter(
            segment: .daily(
                during: DateInterval(start: oneWeekAgo, end: now)
            )
        )
    }

    var body: some View {
        VStack {
            DeviceActivityReport(
                DeviceActivityReport.Context(rawValue: "Total Activity"),
                filter: filter
            )
        }
        .accessibilityIdentifier("DeviceActivityReportContainer")
    }
}
