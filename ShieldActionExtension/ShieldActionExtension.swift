import ManagedSettings
import FocusCore

class ShieldActionExtension: ShieldActionDelegate {

    /// The action handler from FocusCore.
    private let actionHandler = ShieldActionHandler()

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let actionType = shieldActionType(from: action)
        let response = actionHandler.handle(action: actionType)
        completionHandler(shieldActionResponse(from: response))
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let actionType = shieldActionType(from: action)
        let response = actionHandler.handle(action: actionType)
        completionHandler(shieldActionResponse(from: response))
    }

    // MARK: - Mapping Helpers

    /// Converts a `ShieldAction` to a `ShieldActionType` (FocusCore abstraction).
    private func shieldActionType(from action: ShieldAction) -> ShieldActionType {
        switch action {
        case .primaryButtonPressed:
            return .primaryButtonPressed
        case .secondaryButtonPressed,
             .firstSecondarySubmenuItemPressed,
             .secondSecondarySubmenuItemPressed,
             .thirdSecondarySubmenuItemPressed:
            return .secondaryButtonPressed
        @unknown default:
            return .secondaryButtonPressed
        }
    }

    /// Converts a `ShieldActionResponseType` (FocusCore abstraction) to a `ShieldActionResponse`.
    private func shieldActionResponse(from response: ShieldActionResponseType) -> ShieldActionResponse {
        switch response {
        case .close:
            return .close
        case .none:
            return .none
        }
    }
}
