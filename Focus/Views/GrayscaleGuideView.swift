import SwiftUI

// MARK: - GrayscaleGuideView

/// A multi-step instructional view that walks users through enabling the
/// Accessibility Shortcut for grayscale (Color Filters).
///
/// Steps:
/// 1. Open Settings > Accessibility
/// 2. Display & Text Size
/// 3. Color Filters → Grayscale
/// 4. Accessibility Shortcut setup
///
/// The view is dismissible via an "X" button or "Done" button on the last step.
struct GrayscaleGuideView: View {
    @Environment(\.dismiss) private var dismiss

    /// The current step index (0-based).
    @State private var currentStep = 0

    /// All guide steps.
    private let steps = GrayscaleGuideStep.allSteps

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step progress indicator
                stepProgressView

                // Step content
                TabView(selection: $currentStep) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        stepContentView(for: step, at: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)

                // Navigation buttons
                navigationButtons
            }
            .navigationTitle("Grayscale Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("GrayscaleGuideDismissButton")
                }
            }
        }
        .accessibilityIdentifier("GrayscaleGuideView")
    }

    // MARK: - Step Progress

    private var stepProgressView: some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .accessibilityIdentifier("StepIndicator_\(index)")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .accessibilityIdentifier("StepProgressView")
    }

    // MARK: - Step Content

    private func stepContentView(for step: GrayscaleGuideStep, at index: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Step icon
            Image(systemName: step.iconName)
                .font(.system(size: 64))
                .foregroundStyle(step.iconColor)
                .accessibilityIdentifier("StepIcon_\(index)")

            // Step number
            Text("Step \(index + 1) of \(steps.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
                .accessibilityIdentifier("StepNumber_\(index)")

            // Step title
            Text(step.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("StepTitle_\(index)")

            // Step instruction
            Text(step.instruction)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .accessibilityIdentifier("StepInstruction_\(index)")

            Spacer()
        }
        .padding()
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // Back button (hidden on first step)
            if currentStep > 0 {
                Button {
                    withAnimation {
                        currentStep -= 1
                    }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("GrayscaleGuideBackButton")
            }

            // Next / Done button
            Button {
                if currentStep < steps.count - 1 {
                    withAnimation {
                        currentStep += 1
                    }
                } else {
                    dismiss()
                }
            } label: {
                HStack {
                    Text(currentStep < steps.count - 1 ? "Next" : "Done")
                    if currentStep < steps.count - 1 {
                        Image(systemName: "chevron.right")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(
                currentStep < steps.count - 1 ? "GrayscaleGuideNextButton" : "GrayscaleGuideDoneButton"
            )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

// MARK: - GrayscaleGuideStep

/// Represents a single step in the grayscale setup guide.
struct GrayscaleGuideStep {
    let title: String
    let instruction: String
    let iconName: String
    let iconColor: Color

    /// All steps in the grayscale setup guide.
    static let allSteps: [GrayscaleGuideStep] = [
        GrayscaleGuideStep(
            title: "Open Accessibility",
            instruction: "Go to Settings > Accessibility on your device. This is where display and interaction options are configured.",
            iconName: "accessibility",
            iconColor: .blue
        ),
        GrayscaleGuideStep(
            title: "Display & Text Size",
            instruction: "Tap \"Display & Text Size\" in the Accessibility settings. This section controls visual display preferences.",
            iconName: "textformat.size",
            iconColor: .purple
        ),
        GrayscaleGuideStep(
            title: "Enable Color Filters",
            instruction: "Turn on \"Color Filters\" and select \"Grayscale\". This removes color from your screen, reducing the visual appeal of distracting apps.",
            iconName: "circle.lefthalf.filled",
            iconColor: .gray
        ),
        GrayscaleGuideStep(
            title: "Set Up Accessibility Shortcut",
            instruction: "Go back to Accessibility > Accessibility Shortcut (at the bottom). Enable \"Color Filters\" so you can triple-click the side button to quickly toggle grayscale on and off.",
            iconName: "hand.tap.fill",
            iconColor: .green
        ),
        GrayscaleGuideStep(
            title: "You're All Set!",
            instruction: "Triple-click the side button anytime to toggle grayscale mode. Use it during focus sessions to make your phone less visually stimulating.",
            iconName: "checkmark.circle.fill",
            iconColor: .green
        )
    ]
}
