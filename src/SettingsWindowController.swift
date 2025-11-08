import Cocoa
import SwiftUI

/// Window controller for the settings/preferences window
class SettingsWindowController: NSWindowController {

    // MARK: - Singleton

    static let shared = SettingsWindowController()

    // MARK: - Properties

    private var hostingController: NSHostingController<SettingsView>?

    // MARK: - Initialization

    private init() {
        // Create settings window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        // Configure window
        window.title = "Complete Preferences"
        window.center()
        window.isReleasedWhenClosed = false

        // Set minimum size
        window.minSize = NSSize(width: 450, height: 400)
        window.maxSize = NSSize(width: 450, height: 400)

        super.init(window: window)

        // Set up SwiftUI content
        setupSwiftUIContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    /// Set up SwiftUI hosting controller
    private func setupSwiftUIContent() {
        let settingsView = SettingsView()
        let hosting = NSHostingController(rootView: settingsView)

        window?.contentViewController = hosting
        hostingController = hosting
    }

    // MARK: - Public API

    /// Show settings window
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        print("⚙️  Settings window opened")
    }

    /// Hide settings window
    func hide() {
        window?.close()

        print("⚙️  Settings window closed")
    }

    /// Toggle settings window visibility
    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }
}
