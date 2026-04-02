import ActivityKit
import WidgetKit
import SwiftUI
import FocusCore

// MARK: - BreakAttributes (ActivityKit)

/// ActivityAttributes for the break timer Live Activity.
/// Uses the static data (sessionID, sessionStartTime) and dynamic ContentState (breakEndTime).
struct BreakAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// The date when the break ends — used by `Text(timerInterval:)` for real-time countdown.
        var breakEndDate: Date
        /// Session context for display.
        var sessionName: String
    }

    /// The break duration in minutes (static, set at creation).
    var breakDurationMinutes: Int
    /// The unique session ID (static, for identification).
    var sessionID: String?
    /// The session start time (static, for context display).
    var sessionStartTime: Date?
}

// MARK: - BreakLiveActivity

/// Widget configuration for the break timer Live Activity.
/// Provides lock screen, compact (leading + trailing), expanded, and minimal presentations.
struct FocusWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BreakAttributes.self) { context in
            // LOCK SCREEN presentation
            VStack(spacing: 8) {
                Text("Break Time")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(timerInterval: Date.now...context.state.breakEndDate, countsDown: true)
                    .font(.system(size: 36, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.orange)

                Text(context.state.sessionName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let startTime = context.attributes.sessionStartTime {
                    Text("Session started at \(startTime.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.8))

        } dynamicIsland: { context in
            DynamicIsland {
                // EXPANDED presentation (user long-presses the island)
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...context.state.breakEndDate, countsDown: true)
                        .font(.title3)
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Break Time")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.sessionName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(context.attributes.breakDurationMinutes) min break")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                // COMPACT leading — timer icon
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                // COMPACT trailing — countdown timer
                Text(timerInterval: Date.now...context.state.breakEndDate, countsDown: true)
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                    .frame(minWidth: 36)
            } minimal: {
                // MINIMAL — timer icon only (when multiple activities compete)
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundStyle(.orange)
            }
        }
    }
}
