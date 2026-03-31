import SwiftUI
import FocusCore

// MARK: - FocusModeFormContent

/// Shared form content for both create and edit focus mode views.
/// Contains name field, icon picker, and color picker.
struct FocusModeFormContent: View {
    @Bindable var viewModel: FocusModeFormViewModel

    var body: some View {
        Form {
            // MARK: Name Section
            Section {
                TextField("Focus mode name", text: $viewModel.name)
                    .accessibilityIdentifier("NameTextField")
            } header: {
                Text("Name")
            }

            // MARK: Icon Section
            Section {
                iconPickerGrid
            } header: {
                Text("Icon")
            }

            // MARK: Color Section
            Section {
                colorPickerGrid
            } header: {
                Text("Color")
            }

            // MARK: Preview Section
            Section {
                previewRow
            } header: {
                Text("Preview")
            }

            // MARK: Error Section
            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                        .accessibilityIdentifier("ErrorMessage")
                }
            }
        }
        .accessibilityIdentifier("FocusModeForm")
    }

    // MARK: - Icon Picker

    private var iconPickerGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
            ForEach(FocusModeFormViewModel.availableIcons, id: \.self) { icon in
                Button {
                    viewModel.iconName = icon
                } label: {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .background(
                            viewModel.iconName == icon
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    viewModel.iconName == icon
                                        ? Color.accentColor
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("IconOption_\(icon)")
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("IconPicker")
    }

    // MARK: - Color Picker

    private var colorPickerGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
            ForEach(FocusModeFormViewModel.availableColors, id: \.self) { color in
                Button {
                    viewModel.colorHex = color
                } label: {
                    Circle()
                        .fill(Color(hex: color) ?? .blue)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(
                                    viewModel.colorHex == color
                                        ? Color.primary
                                        : Color.clear,
                                    lineWidth: 3
                                )
                                .padding(2)
                        )
                        .overlay(
                            viewModel.colorHex == color
                                ? Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                : nil
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("ColorOption_\(color)")
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("ColorPicker")
    }

    // MARK: - Preview

    private var previewRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: viewModel.colorHex) ?? .blue)
                    .frame(width: 40, height: 40)

                Image(systemName: viewModel.iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("PreviewIcon")

            Text(viewModel.name.isEmpty ? "Focus Mode" : viewModel.name)
                .font(.headline)
                .foregroundStyle(viewModel.name.isEmpty ? .secondary : .primary)
                .accessibilityIdentifier("PreviewName")
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("PreviewRow")
    }
}
