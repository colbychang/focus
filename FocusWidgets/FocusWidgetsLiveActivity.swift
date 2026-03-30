import ActivityKit
import WidgetKit
import SwiftUI
import FocusCore

struct BreakAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var breakEndDate: Date
        var sessionName: String
    }

    var breakDurationMinutes: Int
}

struct FocusWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BreakAttributes.self) { context in
            // Lock screen presentation
            VStack {
                Text("Break Time")
                    .font(.headline)
                Text(timerInterval: Date.now...context.state.breakEndDate, countsDown: true)
                    .font(.title)
                    .monospacedDigit()
                Text(context.state.sessionName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "pause.circle.fill")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...context.state.breakEndDate, countsDown: true)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Break Time")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.sessionName)
                        .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "pause.circle.fill")
            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.breakEndDate, countsDown: true)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "pause.circle.fill")
            }
        }
    }
}
