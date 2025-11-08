import Cocoa

/// Main application delegate
/// Manages app lifecycle for LSUIElement background agent
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    /// Status bar menu icon (provides access to settings when dock icon is hidden)
    private var statusItem: NSStatusItem?

    /// Main menu for status bar
    private var statusMenu: NSMenu?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("✅ Complete app launched as LSUIElement background agent")

        // Set up status bar menu (required since LSUIElement = YES hides dock icon)
        setupStatusBarMenu()

        // Verify LSUIElement configuration
        verifyBackgroundAgentStatus()

        // Check and request accessibility permissions
        checkAccessibilityPermissions()

        // Restore saved settings
        SettingsManager.shared.restoreSettings()

        print("✅ Application initialization complete")
    }

    // MARK: - Accessibility Permissions

    /// Check accessibility permissions and request if needed
    private func checkAccessibilityPermissions() {
        let manager = AccessibilityManager.shared

        // Test permissions in debug mode
        #if DEBUG
        manager.testPermissions()
        #endif

        // Verify and request if needed
        let permissionsGranted = manager.verifyAndRequestIfNeeded()

        if permissionsGranted {
            // Permissions granted - set up hotkey manager
            setupHotkeyManager()
        } else {
            print("⚠️  Accessibility permissions not granted")
            print("   App functionality will be limited until permissions are granted")
            print("   Hotkey registration delayed until permissions are granted")
        }
    }

    // MARK: - Hotkey Setup

    /// Set up global hotkey manager
    /// Only called after accessibility permissions are verified
    private func setupHotkeyManager() {
        let hotkeyManager = HotkeyManager.shared

        // Set up hotkey listeners
        hotkeyManager.setup()

        // Test in debug mode
        #if DEBUG
        Task { @MainActor in
            hotkeyManager.testHotkey()
        }
        #endif

        print("✅ Hotkey manager initialized")
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("👋 Complete app terminating")
        // Cleanup will be implemented in later phases
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Status Bar Menu Setup

    /// Set up status bar menu icon and menu items
    /// Required for user access since LSUIElement hides dock icon
    private func setupStatusBarMenu() {
        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let statusItem = statusItem else {
            print("⚠️  Failed to create status bar item")
            return
        }

        // Set up menu bar icon
        if let button = statusItem.button {
            // Use SF Symbol for completion icon
            button.image = NSImage(systemSymbolName: "text.cursor", accessibilityDescription: "Complete")
            button.toolTip = "Complete - Text Autocomplete"
        }

        // Create menu
        statusMenu = NSMenu()

        // Add menu items
        statusMenu?.addItem(NSMenuItem(title: "Complete v0.1.0", action: nil, keyEquivalent: ""))
        statusMenu?.addItem(NSMenuItem.separator())

        // Settings menu item (will be implemented in Phase 7)
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        statusMenu?.addItem(settingsItem)

        statusMenu?.addItem(NSMenuItem.separator())

        // About menu item
        let aboutItem = NSMenuItem(title: "About Complete", action: #selector(showAbout), keyEquivalent: "")
        statusMenu?.addItem(aboutItem)

        statusMenu?.addItem(NSMenuItem.separator())

        // Quit menu item
        let quitItem = NSMenuItem(title: "Quit Complete", action: #selector(quitApp), keyEquivalent: "q")
        statusMenu?.addItem(quitItem)

        // Assign menu to status item
        statusItem.menu = statusMenu

        print("✅ Status bar menu created")
    }

    // MARK: - Menu Actions

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Complete v0.1.0"
        alert.informativeText = """
        System-wide text autocomplete for macOS

        Trigger: Ctrl+I (customizable)

        © 2025 Laststance
        """
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Verification

    /// Verify that app is running as background agent (LSUIElement)
    private func verifyBackgroundAgentStatus() {
        // Check if running as agent (no dock icon)
        let activationPolicy = NSApplication.shared.activationPolicy()

        switch activationPolicy {
        case .regular:
            print("⚠️  WARNING: App running as regular app (dock icon visible)")
            print("⚠️  LSUIElement configuration may not be working")
        case .accessory:
            print("✅ App running as accessory (no dock icon)")
        case .prohibited:
            print("⚠️  App activation prohibited")
        @unknown default:
            print("⚠️  Unknown activation policy")
        }

        // Verify menu bar is accessible
        if statusItem != nil {
            print("✅ Status bar menu accessible")
        } else {
            print("❌ Status bar menu not accessible")
        }
    }
}
