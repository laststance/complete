import Foundation
import ServiceManagement

/// Manages application settings and preferences
/// Provides UserDefaults-based persistence for user preferences
class SettingsManager {

    // MARK: - Singleton

    static let shared = SettingsManager()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let windowPosition = "windowPosition"
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
            Keys.windowPosition: WindowPosition.bottom.rawValue,
            Keys.launchAtLogin: false
        ]

        defaults.register(defaults: defaultValues)
    }

    // MARK: - Window Position

    /// Get window position preference
    var windowPosition: WindowPosition {
        get {
            let rawValue = defaults.string(forKey: Keys.windowPosition) ?? WindowPosition.bottom.rawValue
            return WindowPosition(rawValue: rawValue) ?? .bottom
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.windowPosition)

            // Update CompletionWindowController
            CompletionWindowController.shared.positionPreference = newValue

            print("✅ Window position preference saved: \(newValue)")
        }
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

        // Restore window position
        CompletionWindowController.shared.positionPreference = windowPosition
        print("   Window position: \(windowPosition)")

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

        // Reset window position
        windowPosition = .bottom

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
            Keys.windowPosition: windowPosition.rawValue,
            Keys.launchAtLogin: launchAtLogin
        ]
    }

    /// Import settings from dictionary
    /// - Parameter settings: Settings dictionary to import
    func importSettings(_ settings: [String: Any]) {
        if let positionRaw = settings[Keys.windowPosition] as? String,
           let position = WindowPosition(rawValue: positionRaw) {
            windowPosition = position
        }

        if let launchAtLogin = settings[Keys.launchAtLogin] as? Bool {
            self.launchAtLogin = launchAtLogin
        }

        print("✅ Settings imported successfully")
    }
}

// MARK: - WindowPosition Extension

extension WindowPosition: RawRepresentable {
    typealias RawValue = String

    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "top":
            self = .top
        case "bottom":
            self = .bottom
        default:
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .top:
            return "top"
        case .bottom:
            return "bottom"
        }
    }
}
