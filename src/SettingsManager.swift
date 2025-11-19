import Foundation
import ServiceManagement
import os.log

/// Manages application settings and preferences
/// Provides UserDefaults-based persistence for user preferences
class SettingsManager {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        // Note: Hotkey settings are managed by KeyboardShortcuts library
    }

    // MARK: - Properties

    private let defaults = UserDefaults.standard

    // MARK: - Initialization

    init() {
        // Register default values on first launch
        registerDefaults()
    }

    // MARK: - Default Values

    /// Register default preference values
    private func registerDefaults() {
        let defaultValues: [String: Any] = [
            Keys.launchAtLogin: false
        ]

        defaults.register(defaults: defaultValues)
    }

    // MARK: - Launch at Login

    /// Get launch at login preference
    var launchAtLogin: Bool {
        get {
            return defaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)

            // Update login item status
            updateLoginItemStatus(enabled: newValue)

            os_log("✅ Launch at login preference saved: %{public}@", log: .settings, type: .info, newValue ? "true" : "false")
        }
    }

    /// Update macOS login item status
    /// - Parameter enabled: Whether to launch at login
    private func updateLoginItemStatus(enabled: Bool) {
        // macOS 13+ (Ventura) uses new SMAppService API
        if #available(macOS 13.0, *) {
            do {
                let service = SMAppService.mainApp

                if enabled {
                    // Register login item
                    if service.status != .enabled {
                        try service.register()
                        os_log("✅ Registered as login item", log: .settings, type: .info)
                    }
                } else {
                    // Unregister login item
                    if service.status == .enabled {
                        try service.unregister()
                        os_log("✅ Unregistered as login item", log: .settings, type: .info)
                    }
                }
            } catch {
                os_log("❌ Failed to update login item status: %{public}@", log: .settings, type: .error, error.localizedDescription)
            }
        } else {
            // macOS 12 and earlier - use deprecated API
            // Note: This is a simplified implementation
            // For production, you'd use SMLoginItemSetEnabled
            os_log("⚠️  Launch at login requires macOS 13+", log: .settings, type: .info)
        }
    }

    // MARK: - Settings Restore

    /// Apply saved settings to application components
    func restoreSettings() {
        os_log("📋 Restoring saved settings...", log: .settings, type: .info)

        // Restore launch at login status
        // (Already applied via property getter)
        os_log("   Launch at login: %{public}@", log: .settings, type: .debug, launchAtLogin ? "true" : "false")

        // Hotkey settings are automatically restored by KeyboardShortcuts library
        os_log("   Hotkey: Managed by KeyboardShortcuts library", log: .settings, type: .debug)

        os_log("✅ Settings restored successfully", log: .settings, type: .info)
    }

    // MARK: - Settings Reset

    /// Reset all settings to default values
    func resetToDefaults() {
        os_log("🔄 Resetting all settings to defaults...", log: .settings, type: .info)

        // Reset launch at login
        launchAtLogin = false

        // Reset hotkey (KeyboardShortcuts library)
        // Note: KeyboardShortcuts doesn't have a built-in reset
        // User can manually change it in settings

        os_log("✅ Settings reset to defaults", log: .settings, type: .info)
    }

    // MARK: - Settings Export/Import (Future Enhancement)

    /// Export settings as dictionary (for backup/sync)
    func exportSettings() -> [String: Any] {
        return [
            Keys.launchAtLogin: launchAtLogin
        ]
    }

    /// Import settings from dictionary
    /// - Parameter settings: Settings dictionary to import
    func importSettings(_ settings: [String: Any]) {
        if let launchAtLogin = settings[Keys.launchAtLogin] as? Bool {
            self.launchAtLogin = launchAtLogin
        }

        os_log("✅ Settings imported successfully", log: .settings, type: .info)
    }
}
