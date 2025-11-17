import Foundation
import ServiceManagement

/// Manages application settings and preferences
/// Provides UserDefaults-based persistence for user preferences
class SettingsManager {

    // MARK: - Singleton

    static let shared = SettingsManager()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        // Note: Hotkey settings are managed by KeyboardShortcuts library
    }

    // MARK: - Properties

    private let defaults = UserDefaults.standard

    // MARK: - Initialization

    private init() {
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

            print("✅ Launch at login preference saved: \(newValue)")
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
                        print("✅ Registered as login item")
                    }
                } else {
                    // Unregister login item
                    if service.status == .enabled {
                        try service.unregister()
                        print("✅ Unregistered as login item")
                    }
                }
            } catch {
                print("❌ Failed to update login item status: \(error.localizedDescription)")
            }
        } else {
            // macOS 12 and earlier - use deprecated API
            // Note: This is a simplified implementation
            // For production, you'd use SMLoginItemSetEnabled
            print("⚠️  Launch at login requires macOS 13+")
        }
    }

    // MARK: - Settings Restore

    /// Apply saved settings to application components
    func restoreSettings() {
        print("📋 Restoring saved settings...")

        // Restore launch at login status
        // (Already applied via property getter)
        print("   Launch at login: \(launchAtLogin)")

        // Hotkey settings are automatically restored by KeyboardShortcuts library
        print("   Hotkey: Managed by KeyboardShortcuts library")

        print("✅ Settings restored successfully")
    }

    // MARK: - Settings Reset

    /// Reset all settings to default values
    func resetToDefaults() {
        print("🔄 Resetting all settings to defaults...")

        // Reset launch at login
        launchAtLogin = false

        // Reset hotkey (KeyboardShortcuts library)
        // Note: KeyboardShortcuts doesn't have a built-in reset
        // User can manually change it in settings

        print("✅ Settings reset to defaults")
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

        print("✅ Settings imported successfully")
    }
}
