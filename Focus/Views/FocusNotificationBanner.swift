import SwiftUI
import FocusCore

// MARK: - FocusNotificationBanner

/// An in-app banner overlay that shows focus mode lifecycle notifications.
/// Appears at the top of the screen with animation and auto-dismisses.
struct FocusNotificationBanner: View {
    let notification: FocusNotification
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: notification.isActivation ? "moon.fill" : "moon")
                    .font(.title3)
                    .foregroundStyle(notification.isActivation ? .green : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.message)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("BannerMessage")

                    Text(notification.isActivation ? "Focus mode is now active" : "Focus mode has ended")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("BannerSubtitle")
                }

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("BannerDismissButton")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("FocusNotificationBanner")

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Notification Banner Modifier

/// View modifier that overlays focus notification banners on any view.
struct FocusNotificationOverlay: ViewModifier {
    let notificationService: FocusNotificationService

    func body(content: Content) -> some View {
        content
            .overlay {
                if let notification = notificationService.currentNotification {
                    FocusNotificationBanner(
                        notification: notification,
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                notificationService.dismiss()
                            }
                        }
                    )
                    .animation(.spring(duration: 0.4), value: notification.id)
                }
            }
    }
}

extension View {
    /// Adds focus mode notification banner overlay to this view.
    func focusNotificationOverlay(service: FocusNotificationService) -> some View {
        modifier(FocusNotificationOverlay(notificationService: service))
    }
}
