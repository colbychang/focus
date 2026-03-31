import SwiftUI
import FocusCore

// MARK: - FocusModeListView

/// Displays a list of focus mode profiles with empty state, swipe-to-delete,
/// and navigation to create/edit views.
struct FocusModeListView: View {
    @Bindable var viewModel: FocusModeListViewModel
    let service: FocusModeService

    @State private var showCreateSheet = false

    var body: some View {
        Group {
            if viewModel.isEmpty {
                emptyStateView
            } else {
                profileListView
            }
        }
        .onAppear {
            viewModel.loadProfiles()
        }
        .alert(
            "Delete Focus Mode",
            isPresented: $viewModel.showDeleteConfirmation,
            presenting: viewModel.profileToDelete
        ) { profile in
            Button("Delete", role: .destructive) {
                viewModel.confirmDelete()
            }
            .accessibilityIdentifier("ConfirmDeleteButton")
            Button("Cancel", role: .cancel) {
                viewModel.cancelDelete()
            }
            .accessibilityIdentifier("CancelDeleteButton")
        } message: { profile in
            Text("Are you sure you want to delete \"\(profile.name)\"? This action cannot be undone.")
        }
        .sheet(isPresented: $showCreateSheet) {
            FocusModeCreateView(
                viewModel: FocusModeFormViewModel(service: service),
                onDismiss: {
                    showCreateSheet = false
                    viewModel.loadProfiles()
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("CreateFocusModeButton")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("EmptyStateIcon")

            Text("No focus modes yet. Create one to get started.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .accessibilityIdentifier("EmptyStateText")

            Button {
                showCreateSheet = true
            } label: {
                Label("Create Focus Mode", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .accessibilityIdentifier("EmptyStateCreateButton")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Profile List

    private var profileListView: some View {
        List {
            ForEach(viewModel.profiles, id: \.id) { profile in
                NavigationLink {
                    FocusModeEditView(
                        viewModel: FocusModeFormViewModel(service: service, profile: profile),
                        onDismiss: {
                            viewModel.loadProfiles()
                        }
                    )
                } label: {
                    FocusModeRow(profile: profile)
                }
                .accessibilityIdentifier("FocusModeRow_\(profile.name)")
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.requestDelete(profile: profile)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .accessibilityIdentifier("DeleteSwipeAction_\(profile.name)")
                }
            }
        }
        .accessibilityIdentifier("FocusModeList")
    }
}

// MARK: - FocusModeRow

/// A single row in the focus mode profile list.
struct FocusModeRow: View {
    let profile: FocusMode

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator circle with icon
            ZStack {
                Circle()
                    .fill(Color(hex: profile.colorHex) ?? .blue)
                    .frame(width: 40, height: 40)

                Image(systemName: profile.iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("ProfileIcon_\(profile.name)")

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.headline)
                    .accessibilityIdentifier("ProfileName_\(profile.name)")

                if profile.isActive {
                    Text("Active")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("ActiveBadge_\(profile.name)")
                }
            }

            Spacer()

            if profile.isActive {
                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
                    .accessibilityIdentifier("ActiveIndicator_\(profile.name)")
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Color Extension

extension Color {
    /// Initialize a Color from a hex string (e.g., "#4A90D9").
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
