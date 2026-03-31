import SwiftUI
import FocusCore

// MARK: - FocusModeEditView

/// Form view for editing an existing focus mode profile.
/// Pre-populated with the profile's current values.
/// When saving an active profile, shields are refreshed immediately.
struct FocusModeEditView: View {
    @Bindable var viewModel: FocusModeFormViewModel
    var activationService: FocusModeActivationService?
    let onDismiss: () -> Void

    var body: some View {
        FocusModeFormContent(viewModel: viewModel)
            .navigationTitle("Edit Focus Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save()
                        // If the profile is active and save succeeded,
                        // refresh shields immediately
                        if viewModel.didSave {
                            viewModel.refreshShieldsIfActive(using: activationService)
                        }
                    }
                    .disabled(viewModel.isSaving)
                    .accessibilityIdentifier("SaveButton")
                }
            }
            .onChange(of: viewModel.didSave) { _, didSave in
                if didSave {
                    onDismiss()
                }
            }
            .accessibilityIdentifier("FocusModeEditView")
    }
}
