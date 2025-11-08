import SwiftUI
import KeyboardShortcuts

/// SwiftUI view for application settings
struct SettingsView: View {

    // MARK: - Properties

    @ObservedObject private var settingsManager = SettingsManagerObservable.shared

    // MARK: - Constants

    private let formWidth: CGFloat = 450
    private let labelWidth: CGFloat = 140

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Settings content
            Form {
                // General Section
                Section {
                    generalSettings
                } header: {
                    Text("General")
                        .font(.headline)
                }

                // Hotkey Section
                Section {
                    hotkeySettings
                } header: {
                    Text("Keyboard Shortcut")
                        .font(.headline)
                }

                // Appearance Section
                Section {
                    appearanceSettings
                } header: {
                    Text("Appearance")
                        .font(.headline)
                }
            }
            .formStyle(.grouped)
            .frame(width: formWidth)

            Divider()

            // Footer with reset button
            HStack {
                Spacer()

                Button("Reset to Defaults") {
                    resetSettings()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(width: formWidth, height: 400)
    }

    // MARK: - Settings Sections

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Launch at Login", isOn: $settingsManager.launchAtLogin)
                .help("Automatically start Complete when you log in")
        }
    }

    private var hotkeySettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trigger Shortcut:")
                    .frame(width: labelWidth, alignment: .trailing)

                KeyboardShortcuts.Recorder(for: .completionTrigger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .help("Press keys to set a new shortcut for triggering completions")

            Text("Default: ⌃I (Control+I)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, labelWidth + 8)
        }
    }

    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Window Position:", selection: $settingsManager.windowPosition) {
                Text("Below Cursor").tag(WindowPosition.bottom)
                Text("Above Cursor").tag(WindowPosition.top)
            }
            .pickerStyle(.radioGroup)
            .frame(width: formWidth - 40)
            .help("Choose where the completion window appears relative to the cursor")

            Text("The completion window will appear at the selected position relative to your cursor.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
        }
    }

    // MARK: - Actions

    private func resetSettings() {
        // Show confirmation alert
        let alert = NSAlert()
        alert.messageText = "Reset Settings"
        alert.informativeText = "Are you sure you want to reset all settings to their default values?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            SettingsManager.shared.resetToDefaults()

            // Update observable
            settingsManager.refreshFromManager()
        }
    }
}

// MARK: - Observable Wrapper

/// Observable wrapper for SettingsManager
/// Provides SwiftUI bindings for settings
@MainActor
class SettingsManagerObservable: ObservableObject {

    static let shared = SettingsManagerObservable()

    @Published var windowPosition: WindowPosition {
        didSet {
            SettingsManager.shared.windowPosition = windowPosition
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            SettingsManager.shared.launchAtLogin = launchAtLogin
        }
    }

    private init() {
        // Initialize from SettingsManager
        self.windowPosition = SettingsManager.shared.windowPosition
        self.launchAtLogin = SettingsManager.shared.launchAtLogin
    }

    /// Refresh values from SettingsManager (after reset)
    func refreshFromManager() {
        windowPosition = SettingsManager.shared.windowPosition
        launchAtLogin = SettingsManager.shared.launchAtLogin
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .frame(width: 450, height: 400)
    }
}
#endif
