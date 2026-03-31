import SwiftUI
import FocusCore

// MARK: - AuthorizationDeniedView

/// Shown when the user has denied Screen Time authorization.
/// Displays an explanation and a retry option.
struct AuthorizationDeniedView: View {
    let viewModel: AuthorizationViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange)
                .accessibilityIdentifier("DeniedIcon")

            Text("Screen Time Access Denied")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("DeniedTitle")

            Text("Without Screen Time access, Focault cannot block distracting apps. You can grant access in Settings or try again below.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .accessibilityIdentifier("DeniedDescription")

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task {
                        await viewModel.requestAuthorization()
                    }
                } label: {
                    Text("Try Again")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRequesting)
                .accessibilityIdentifier("RetryAuthorizationButton")

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("OpenSettingsButton")
            }
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 40)
        }
    }
}
