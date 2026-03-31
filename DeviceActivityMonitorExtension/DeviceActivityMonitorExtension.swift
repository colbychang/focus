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

        // Look up human-readable profile name from App Group UserDefaults
        let profileName = lookupProfileName(for: profileIdString) ?? profileIdString

        // Record session start with profile info
        sessionRecorder.recordSessionStart(
            profileId: profileId,
            profileName: profileName
        )

        // Post Darwin notification so foreground app can show banner
        DarwinNotificationPoster.post(name: DarwinNotificationName.focusModeStarted)
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

        // Post Darwin notification so foreground app can show banner
        DarwinNotificationPoster.post(name: DarwinNotificationName.focusModeEnded)
    }

    // MARK: - Helpers

    /// Looks up the human-readable profile name from App Group UserDefaults.
    /// Profile names are mirrored at creation/update time with key "profile_name_<uuid>".
    private func lookupProfileName(for profileUUID: String) -> String? {
        let defaults = UserDefaults(suiteName: FocusCore.appGroupIdentifier)
        return defaults?.string(forKey: "profile_name_\(profileUUID)")
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
    }
}
