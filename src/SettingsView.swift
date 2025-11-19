import SwiftUI
import KeyboardShortcuts

/// SwiftUI view for application settings
struct SettingsView: View {

    // MARK: - Properties

    @ObservedObject private var settingsManager: SettingsManagerObservable

    // MARK: - Initialization

    init(settingsManager: SettingsManagerObservable) {
        self.settingsManager = settingsManager
    }

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
            Text("The completion window will appear above your cursor.")
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
            settingsManager.resetToDefaults()
        }
    }
}

// MARK: - Observable Wrapper

/// Observable wrapper for SettingsManager
/// Provides SwiftUI bindings for settings
@MainActor
class SettingsManagerObservable: ObservableObject {

    private let settingsManager: SettingsManaging

    @Published var launchAtLogin: Bool {
        didSet {
            settingsManager.launchAtLogin = launchAtLogin
        }
    }

    init(settingsManager: SettingsManaging) {
        self.settingsManager = settingsManager
        // Initialize from SettingsManager
        self.launchAtLogin = settingsManager.launchAtLogin
    }

    /// Refresh values from SettingsManager (after reset)
    func refreshFromManager() {
        launchAtLogin = settingsManager.launchAtLogin
    }

    /// Reset to default values
    func resetToDefaults() {
        settingsManager.resetToDefaults()
        refreshFromManager()
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let manager = SettingsManager()
        let observable = SettingsManagerObservable(settingsManager: manager)
        SettingsView(settingsManager: observable)
            .frame(width: 450, height: 400)
    }
}
#endif
