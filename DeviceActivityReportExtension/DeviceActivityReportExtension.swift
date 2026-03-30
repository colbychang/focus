import DeviceActivity
import SwiftUI
import FocusCore

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "Total Activity")

    let content: (String) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> String {
        return "Screen Time Report"
    }

    var body: some DeviceActivityReportScene {
        TotalActivityReport { text in
            TotalActivityView(text: text)
        }
    }
}

struct TotalActivityView: View {
    let text: String

    var body: some View {
        Text(text)
    }
}
