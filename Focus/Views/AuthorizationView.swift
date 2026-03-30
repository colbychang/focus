import SwiftUI
import FocusCore

// MARK: - AuthorizationView

/// The onboarding screen that requests Screen Time authorization.
/// Shown when authorization status is `.notDetermined`.
struct AuthorizationView: View {
    let viewModel: AuthorizationViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "hourglass.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .accessibilityIdentifier("AuthorizationIcon")

            Text("Screen Time Access")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityIdentifier("AuthorizationTitle")

            Text("Focus needs Screen Time access to block distracting apps and help you stay focused.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .accessibilityIdentifier("AuthorizationDescription")

            Spacer()

            Button {
                Task {
                    await viewModel.requestAuthorization()
                }
            } label: {
                if viewModel.isRequesting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text("Allow Screen Time Access")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isRequesting)
            .padding(.horizontal, 32)
            .accessibilityIdentifier("AllowScreenTimeAccessButton")

            Spacer()
                .frame(height: 40)
        }
    }
}
