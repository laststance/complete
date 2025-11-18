import Cocoa
import os.log

/// Main application delegate
/// Manages app lifecycle for LSUIElement background agent
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Managed Dependencies (Dependency Injection)

    /// Settings manager (owned instance, not singleton)
    private let settingsManager: SettingsManaging

    /// Completion engine (owned instance, not singleton)
    private let completionEngine: CompletionProviding

    /// Accessibility manager (owned instance, not singleton)
    private let accessibilityManager: AccessibilityManaging

    // MARK: - Properties

    /// Status bar menu icon (provides access to settings when dock icon is hidden)
    private var statusItem: NSStatusItem?

    /// Main menu for status bar
    private var statusMenu: NSMenu?

    // MARK: - Initialization

    override init() {
        // Initialize managed dependencies
        // Note: We still use .shared here as a temporary bridge during migration
        // Future work: Create new instances and inject them throughout the app
        self.settingsManager = SettingsManager.shared
        self.completionEngine = CompletionEngine.shared
        self.accessibilityManager = AccessibilityManager.shared

        super.init()
    }

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        os_log("✅ Complete app launched as LSUIElement background agent", log: .app, type: .info)

        // Set up status bar menu (required since LSUIElement = YES hides dock icon)
        setupStatusBarMenu()

        // Verify LSUIElement configuration
        verifyBackgroundAgentStatus()

        // Check and request accessibility permissions
        checkAccessibilityPermissions()

        // Restore saved settings
        settingsManager.restoreSettings()

        os_log("✅ Application initialization complete", log: .app, type: .info)
    }

    // MARK: - Accessibility Permissions

    /// Check accessibility permissions and request if needed
    private func checkAccessibilityPermissions() {
        // Use owned accessibility manager instance
        // Test permissions in debug mode
        #if DEBUG
        accessibilityManager.testPermissions()
        #endif

        // Verify and request if needed
        let permissionsGranted = accessibilityManager.verifyAndRequestIfNeeded()

        if permissionsGranted {
            // Permissions granted - set up hotkey manager
            setupHotkeyManager()
        } else {
            os_log("⚠️  Accessibility permissions not granted", log: .app, type: .error)
            os_log("   App functionality will be limited until permissions are granted", log: .app, type: .info)
            os_log("   Hotkey registration delayed until permissions are granted", log: .app, type: .info)
        }
    }

    // MARK: - Hotkey Setup

    /// Set up global hotkey manager
    /// Only called after accessibility permissions are verified
    private func setupHotkeyManager() {
        // HotkeyManager auto-initializes in init()
        _ = HotkeyManager.shared

        os_log("✅ Hotkey manager initialized", log: .app, type: .info)
    }

    func applicationWillTerminate(_ notification: Notification) {
        os_log("👋 Complete app terminating", log: .app, type: .info)
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
            os_log("⚠️  Failed to create status bar item", log: .app, type: .error)
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

        os_log("✅ Status bar menu created", log: .app, type: .info)
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
            os_log("⚠️  WARNING: App running as regular app (dock icon visible)", log: .app, type: .error)
            os_log("⚠️  LSUIElement configuration may not be working", log: .app, type: .info)
        case .accessory:
            os_log("✅ App running as accessory (no dock icon)", log: .app, type: .info)
        case .prohibited:
            os_log("⚠️  App activation prohibited", log: .app, type: .error)
        @unknown default:
            os_log("⚠️  Unknown activation policy", log: .app, type: .error)
        }

        // Verify menu bar is accessible
        if statusItem != nil {
            os_log("✅ Status bar menu accessible", log: .app, type: .info)
        } else {
            os_log("❌ Status bar menu not accessible", log: .app, type: .error)
        }
    }
}