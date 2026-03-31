import SwiftUI
import FocusCore

// MARK: - FocusModeCreateView

/// Form view for creating a new focus mode profile.
/// Presents name, icon picker, and color picker fields.
struct FocusModeCreateView: View {
    @Bindable var viewModel: FocusModeFormViewModel
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            FocusModeFormContent(viewModel: viewModel)
                .navigationTitle("New Focus Mode")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            onDismiss()
                        }
                        .accessibilityIdentifier("CancelButton")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            viewModel.save()
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
        }
        .accessibilityIdentifier("FocusModeCreateView")
    }
}
