import DeviceActivity
import Foundation
import FocusCore

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    /// Session recorder for writing session boundaries to App Group UserDefaults.
    private lazy var sessionRecorder = FocusSessionRecorder()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        // Extract profile UUID from activity name (format: "focus_UUID" or just UUID)
        let activityString = activity.rawValue
        let profileIdString = activityString.hasPrefix("focus_")
            ? String(activityString.dropFirst("focus_".count))
            : activityString

        guard let profileId = UUID(uuidString: profileIdString) else { return }

        // Record session start with profile info
        // The profile name is stored as the activity name prefix for simplicity
        sessionRecorder.recordSessionStart(
            profileId: profileId,
            profileName: profileIdString
        )
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        // Extract profile UUID from activity name
        let activityString = activity.rawValue
        let profileIdString = activityString.hasPrefix("focus_")
            ? String(activityString.dropFirst("focus_".count))
            : activityString

        guard let profileId = UUID(uuidString: profileIdString) else { return }

        // Record session end
        sessionRecorder.recordSessionEnd(profileId: profileId)
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
    }
}
